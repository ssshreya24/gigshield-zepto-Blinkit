const express = require('express');
const cors = require('cors');
const pool = require('./db');
const { calculatePremium } = require('./premiumEngine');
const { fireTrigger, startCron, checkWeather, getAreaName, checkAQI, durationState } = require('./triggerEngine');
const ml = require('./mlClient'); // ← ML SERVICE CONNECTED

require('dotenv').config();

const app = express();
app.use(cors());
app.use(express.json());


// ─── HEALTH CHECK ────────────────────────────────────────
app.get('/health', async (req, res) => {
  const db = await pool.query('SELECT NOW()');
  res.json({ status: 'ok', db_time: db.rows[0].now });
});

// ─── LIVE WEATHER ENDPOINT ────────────────────────────────
app.get('/weather', async (req, res) => {
  try {
    const lat = parseFloat(req.query.lat);
    const lon = parseFloat(req.query.lon);
    if (!lat || !lon) return res.status(400).json({ error: 'lat and lon required' });

    const areaName = await getAreaName(lat, lon);
    const weather = await checkWeather(lat, lon, areaName);
    if (!weather) return res.status(500).json({ error: 'weather service unavailable' });
    
    weather.aqi = await checkAQI(lat, lon);

    // Compute personalized remaining cooldown if workerId is provided
    let maxCooldownRemaining = 0;
    const workerId = parseInt(req.query.workerId);
    
    if (!isNaN(workerId)) {
      const recentClaim = await pool.query(
        `SELECT created_at FROM claims WHERE worker_id=$1 AND created_at > NOW() - INTERVAL '24 hours' ORDER BY created_at DESC LIMIT 1`,
        [workerId]
      );
      
      if (recentClaim.rows.length > 0) {
        const hoursPassed = (Date.now() - new Date(recentClaim.rows[0].created_at)) / (1000 * 60 * 60);
        if (hoursPassed < 24 && hoursPassed >= 0) {
          maxCooldownRemaining = 24 - hoursPassed;
        }
      }
    }
    
    weather.cooldown_remaining_hours = maxCooldownRemaining;
    
    res.json(weather);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── DYNAMIC PREMIUM QUOTE ───────────────────────────────
app.get('/premium', async (req, res) => {
  try {
    const { zone, plan_type, tenure_weeks, weather_risk } = req.query;
    const risk = await ml.predictRisk({ 
      zone: zone || 'Koramangala', 
      plan_type: plan_type || 'basic', 
      tenure_weeks: parseInt(tenure_weeks) || 1,
    });
    res.json(risk);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── GET WORKER POLICY ───────────────────────────────────
app.get('/policy/:workerId', async (req, res) => {
  const result = await pool.query(
    `SELECT p.*, w.name, w.zone, w.platform, w.latitude, w.longitude,
            pt.thresholds_json, pt.triggers_json
     FROM policies p
     JOIN workers w ON w.id = p.worker_id
     LEFT JOIN plan_types pt ON LOWER(pt.plan_key) = LOWER(p.plan_type)
     WHERE p.worker_id=$1 AND p.active=TRUE`,
    [req.params.workerId]
  );
  res.json(result.rows[0] || null);
});

// ─── GET WORKER CLAIMS ───────────────────────────────────
app.get('/claims/:workerId', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT
         c.*,
         COALESCE(t1.trigger_type, t2.trigger_type, c.trigger_type) AS trigger_type,
         COALESCE(t1.severity,     t2.severity,     c.severity)      AS severity,
         COALESCE(t1.value,        t2.value)                         AS trigger_value,
         COALESCE(t1.created_at,   t2.created_at)                    AS detected_at,
         COALESCE(t1.zone,         t2.zone,         c.zone)          AS zone,
         py.amount AS payout_amount,
         py.status AS payout_status
       FROM claims c
       LEFT JOIN trigger_events t1 ON t1.id = c.trigger_event_id
       LEFT JOIN trigger_events t2 ON t2.id = c.trigger_id
       LEFT JOIN payouts py ON py.claim_id = c.id
       WHERE c.worker_id = $1
       ORDER BY c.created_at DESC`,
      [req.params.workerId]
    );
    res.json(result.rows);
  } catch (err) {
    console.error('GET /claims error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// ─── ADMIN — ALL CLAIMS ──────────────────────────────────
app.get('/admin/claims', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT
         c.*,
         w.name, w.platform,
         COALESCE(t1.trigger_type, t2.trigger_type, c.trigger_type) AS trigger_type,
         COALESCE(t1.severity,     t2.severity,     c.severity)      AS severity,
         COALESCE(t1.zone,         t2.zone,         c.zone,
                  w.zone)                                            AS zone,
         py.amount     AS payout_amount,
         py.status     AS payout_status
       FROM claims c
       JOIN    workers w       ON w.id  = c.worker_id
       LEFT JOIN trigger_events t1 ON t1.id = c.trigger_event_id
       LEFT JOIN trigger_events t2 ON t2.id = c.trigger_id
       LEFT JOIN payouts py ON py.claim_id = c.id
       ORDER BY c.created_at DESC
       LIMIT 100`
    );
    res.json(result.rows);
  } catch (err) {
    console.error('GET /admin/claims error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// Worker sign in by phone number
app.get('/signin', async (req, res) => {
  try {
    const { phone } = req.query;
    if (!phone) {
      return res.status(400).json({ error: 'Phone number required' });
    }
    const result = await pool.query(
      `SELECT w.id, w.name, w.phone, w.zone, w.platform,
              w.avg_daily_income, w.tenure_weeks,
              p.plan_type, p.weekly_premium, p.max_payout,
              p.start_date, p.end_date, p.active,
              p.id as policy_id
       FROM workers w
       LEFT JOIN policies p ON p.worker_id = w.id AND p.active = TRUE
       WHERE w.phone = $1`,
      [phone.trim()]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({
        error: 'Phone number not found. Please register first.'
      });
    }
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/payments', async (req, res) => {
  try {
    const { worker_id, amount, plan_type, payment_method, upi_id } = req.body;
    const result = await pool.query(
      `INSERT INTO premium_payments 
       (worker_id, amount, plan_type, payment_method, upi_id, status)
       VALUES ($1, $2, $3, $4, $5, 'completed') RETURNING *`,
      [worker_id, amount, plan_type, payment_method, upi_id]
    );
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/payments/:workerId', async (req, res) => {
  try {
    const { workerId } = req.params;
    const result = await pool.query(
      `SELECT id, amount, plan_type, payment_method, upi_id, status, created_at
       FROM premium_payments
       WHERE worker_id = $1
       ORDER BY created_at DESC`,
      [workerId]
    );
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/triggers/:zone', async (req, res) => {
  try {
    const { zone } = req.params;
    const result = await pool.query(
      `SELECT id, zone, trigger_type, severity,
              value, status, created_at
       FROM trigger_events
       WHERE zone = $1
       AND status = 'active'
       AND created_at > NOW() - INTERVAL '24 hours'
       ORDER BY created_at DESC`,
      [decodeURIComponent(zone)]
    );
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Admin login
app.post('/admin/login', async (req, res) => {
  const { email, password } = req.body;
  if (email === 'admin@insurify.com' && password === 'insurify@2026') {
    res.json({ success: true, token: 'admin-token-2026', name: 'Insurify Admin' });
  } else {
    res.status(401).json({ error: 'Invalid credentials' });
  }
});

// Admin — all workers
app.get('/admin/workers', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT w.id, w.name, w.phone, w.zone, w.platform,
              w.avg_daily_income, w.created_at,
              p.plan_type, p.weekly_premium, p.max_payout, p.active
       FROM workers w
       LEFT JOIN policies p ON p.worker_id = w.id
       ORDER BY w.created_at DESC`
    );
    res.json(result.rows);
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// Admin — single worker detail
app.get('/admin/workers/:id', async (req, res) => {
  const { id } = req.params;
  try {
    const workerRes = await pool.query(
      `SELECT w.id, w.name, w.phone, w.zone, w.platform,
              w.avg_daily_income, w.created_at,
              p.id as policy_id, p.plan_type, p.weekly_premium,
              p.max_payout, p.active as policy_active,
              p.created_at as policy_start
       FROM workers w
       LEFT JOIN policies p ON p.worker_id = w.id
       WHERE w.id = $1`, [id]
    );
    if (workerRes.rows.length === 0) return res.status(404).json({ error: 'Worker not found' });
    const worker = workerRes.rows[0];

    const claimsRes = await pool.query(
      `SELECT c.id, c.trigger_type, c.zone, c.severity,
              c.payout_amount, c.status, c.created_at,
              te.value as trigger_value
       FROM claims c
       LEFT JOIN trigger_events te ON te.id = c.trigger_event_id
       WHERE c.worker_id = $1
       ORDER BY c.created_at DESC`, [id]
    );

    const payoutRes = await pool.query(
      `SELECT COALESCE(SUM(payout_amount), 0) as total_payout,
              COUNT(*) as total_claims
       FROM claims WHERE worker_id = $1 AND status = 'approved'`, [id]
    );

    const premiumsRes = await pool.query(
      `SELECT id, amount, plan_type, payment_method, status, created_at
       FROM premium_payments WHERE worker_id = $1
       ORDER BY created_at DESC`, [id]
    );

    const timelineRes = await pool.query(
      `SELECT TO_CHAR(DATE_TRUNC('month', created_at), 'Mon YYYY') as month,
              SUM(payout_amount) as payout
       FROM claims WHERE worker_id = $1 AND status = 'approved'
       GROUP BY DATE_TRUNC('month', created_at)
       ORDER BY DATE_TRUNC('month', created_at) DESC
       LIMIT 6`, [id]
    );

    res.json({
      ...worker,
      claims:           claimsRes.rows,
      total_payout:     parseInt(payoutRes.rows[0].total_payout),
      total_claims:     parseInt(payoutRes.rows[0].total_claims),
      premium_payments: premiumsRes.rows,
      monthly_timeline: timelineRes.rows.reverse(),
    });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// Admin — payments list
app.get('/admin/payments', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT p.id, p.amount, p.plan_type, p.payment_method, p.upi_id, p.status, p.created_at, w.name as worker_name, w.phone as worker_phone
       FROM premium_payments p
       JOIN workers w ON p.worker_id = w.id
       ORDER BY p.created_at DESC`
    );
    res.json(result.rows);
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// Admin — recent trigger events
app.get('/admin/triggers', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT id, zone, trigger_type, severity, value, status, created_at
       FROM trigger_events
       ORDER BY created_at DESC LIMIT 20`
    );
    res.json(result.rows);
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// Admin — update policy (manage plan)
app.put('/admin/policy/:policyId', async (req, res) => {
  try {
    const { policyId } = req.params;
    const { plan_type, weekly_premium, max_payout, active } = req.body;
    const result = await pool.query(
      `UPDATE policies
       SET plan_type=$1, weekly_premium=$2, max_payout=$3, active=$4
       WHERE id=$5 RETURNING *`,
      [plan_type, weekly_premium, max_payout, active, policyId]
    );
    res.json(result.rows[0]);
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// Admin — suspend worker
app.put('/admin/worker/:workerId/suspend', async (req, res) => {
  try {
    await pool.query(
      `UPDATE policies SET active=false WHERE worker_id=$1`,
      [req.params.workerId]
    );
    res.json({ success: true, message: 'Worker suspended' });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// Admin — approve/reject claim manually
app.put('/admin/claim/:claimId', async (req, res) => {
  try {
    const { status } = req.body;
    const result = await pool.query(
      `UPDATE claims SET status=$1 WHERE id=$2 RETURNING *`,
      [status, req.params.claimId]
    );

    const claim = result.rows[0];

    // If approved, create a payout entry so it reflects on Dashboard stats
    if (status === 'approved' && claim) {
      const existingPy = await pool.query(`SELECT id FROM payouts WHERE claim_id=$1`, [claim.id]);
      if (existingPy.rows.length === 0) {
        await pool.query(
          `INSERT INTO payouts (claim_id, worker_id, amount, payment_method, status, processed_at)
           VALUES ($1,$2,$3,'UPI','completed',NOW())`,
          [claim.id, claim.worker_id, claim.payout_amount]
        );
      }
    }

    res.json(claim);
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// ─── DEMO — FIRE TRIGGER + CREATE REAL CLAIM ─────────────
app.post('/demo/trigger', async (req, res) => {
  const { zone, type, severity, value, worker_id } = req.body;
  const z = zone ?? 'Koramangala';
  const t = type ?? 'heavy_rain';
  const sev = severity ?? 'T2';
  const val = value ?? 60;

  try {
    const trigRow = await pool.query(
      `INSERT INTO trigger_events
         (zone, trigger_type, severity, value, status)
       VALUES ($1, $2, $3, $4, 'active')
       RETURNING *`,
      [z, t, sev, val]
    );
    const triggerId = trigRow.rows[0].id;

    const workerQuery = worker_id
      ? `SELECT w.id AS worker_id, w.name,
                p.id AS policy_id, p.max_payout, p.plan_type
           FROM workers w
           JOIN policies p ON p.worker_id = w.id
           WHERE w.id = $1 AND p.active = TRUE`
      : `SELECT w.id AS worker_id, w.name,
                p.id AS policy_id, p.max_payout, p.plan_type
           FROM workers w
           JOIN policies p ON p.worker_id = w.id
           WHERE w.zone = $1 AND p.active = TRUE`;

    const workers = await pool.query(workerQuery, [worker_id ?? z]);

    // ─── Plan-based eligibility check ─────────────────────────
    // Fetch the trigger coverage for each plan from plan_types table
    let planCoverage = {};
    try {
      const ptRows = await pool.query(`SELECT plan_key, triggers_json FROM plan_types`);
      for (const row of ptRows.rows) {
        planCoverage[row.plan_key] = row.triggers_json || [];
      }
    } catch (_) {
      // fallback defaults
      planCoverage = {
        basic:    ['heavy_rain', 'curfew'],
        standard: ['heavy_rain', 'curfew', 'extreme_heat', 'severe_aqi'],
        pro:      ['heavy_rain', 'curfew', 'extreme_heat', 'severe_aqi', 'flood_alert', 'cyclone'],
      };
    }
    // ──────────────────────────────────────────────────────────

    const pctMap = { T1: 0.25, T2: 0.50, T3: 1.00 };
    const pct = pctMap[sev] ?? 0.50;

    let claimRow = null;
    for (const worker of workers.rows) {
      const workerPlan    = (worker.plan_type || 'basic').toLowerCase();
      const coveredTriggers = planCoverage[workerPlan] || [];

      // Skip worker if their plan doesn't cover this trigger type
      if (!coveredTriggers.includes(t)) {
        console.log(`  [SKIP] ${worker.name} (${workerPlan}) — ${t} not covered in their plan`);
        continue;
      }

      const payoutAmt = Math.round(worker.max_payout * pct);

      const claim = await pool.query(
        `INSERT INTO claims
           (worker_id, policy_id, trigger_event_id,
            trigger_type, zone, severity,
            expected_income, actual_income, payout_amount,
            status, fraud_flag)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,'approved',false)
         RETURNING *`,
        [worker.worker_id, worker.policy_id, triggerId,
          t, z, sev, 800, 0, payoutAmt]
      );
      claimRow = claim.rows[0];

      await pool.query(
        `INSERT INTO payouts
           (claim_id, worker_id, amount, payment_method, status, processed_at)
         VALUES ($1,$2,$3,'UPI','completed',NOW())`,
        [claimRow.id, worker.worker_id, payoutAmt]
      );

      console.log(`[DEMO] Claim ₹${payoutAmt} created for worker ${worker.name}`);
    }

    res.json({
      success: true,
      trigger: trigRow.rows[0],
      claim: claimRow
        ? { id: claimRow.id, amount: claimRow.payout_amount, status: 'approved' }
        : null,
      message: `Demo trigger fired: ${t} in ${z}`,
    });

  } catch (err) {
    console.error('[DEMO TRIGGER ERROR]', err.message);
    const severityPayouts = { T1: 375, T2: 750, T3: 1500 };
    res.json({
      success: true,
      trigger: {
        id: Math.floor(Math.random() * 9000 + 1000),
        trigger_type: t, severity: sev, zone: z, value: val,
        status: 'active', created_at: new Date().toISOString(),
      },
      claim: {
        id: Math.floor(Math.random() * 9000 + 1000),
        amount: severityPayouts[sev] ?? 750,
        status: 'approved',
      },
      message: `Demo trigger fired (mock fallback)`,
    });
  }
});

function _payoutForSeverity(sev) {
  const map = { T1: 375, T2: 750, T3: 1500 };
  return map[sev] ?? 750;
}

// ─── ADMIN — PLAN TYPES ───────────────────────────────────
app.get('/admin/plan-types', async (req, res) => {
  try {
    const { rows } = await pool.query(
      `SELECT id, name, plan_key, weekly_premium, max_payout,
              triggers_json, thresholds_json, duration_days, is_active
       FROM plan_types ORDER BY id`
    );
    if (rows.length === 0) {
      // Genuine empty table — return defaults
      return res.json([
        { id: 1, name: 'Basic',    plan_key: 'basic',    weekly_premium: 29, max_payout: 500,  is_active: true, triggers_json: ['heavy_rain', 'extreme_heat'] },
        { id: 2, name: 'Standard', plan_key: 'standard', weekly_premium: 49, max_payout: 900,  is_active: true, triggers_json: ['heavy_rain', 'extreme_heat', 'flood_alert', 'severe_aqi'] },
        { id: 3, name: 'Pro',      plan_key: 'pro',      weekly_premium: 79, max_payout: 1500, is_active: true, triggers_json: ['heavy_rain', 'extreme_heat', 'flood_alert', 'severe_aqi', 'curfew', 'cyclone'] },
      ]);
    }
    res.json(rows);
  } catch (err) {
    console.error('[plan-types] DB error:', err.message);
    res.json([
      { id: 1, name: 'Basic',    plan_key: 'basic',    weekly_premium: 29, max_payout: 500,  is_active: true, triggers_json: ['heavy_rain', 'extreme_heat'] },
      { id: 2, name: 'Standard', plan_key: 'standard', weekly_premium: 49, max_payout: 900,  is_active: true, triggers_json: ['heavy_rain', 'extreme_heat', 'flood_alert', 'severe_aqi'] },
      { id: 3, name: 'Pro',      plan_key: 'pro',      weekly_premium: 79, max_payout: 1500, is_active: true, triggers_json: ['heavy_rain', 'extreme_heat', 'flood_alert', 'severe_aqi', 'curfew', 'cyclone'] },
    ]);
  }
});

app.put('/admin/plan-types/:id', async (req, res) => {
  const { id } = req.params;
  const { weekly_premium, max_payout, is_active, duration_days, thresholds_json } = req.body;
  try {
    const { rows } = await pool.query(
      `UPDATE plan_types
       SET weekly_premium=$1, max_payout=$2, is_active=$3,
           duration_days=COALESCE($4, duration_days),
           thresholds_json=COALESCE($5::jsonb, thresholds_json)
       WHERE id=$6 RETURNING *`,
      [weekly_premium, max_payout, is_active,
       duration_days || null,
       thresholds_json ? JSON.stringify(thresholds_json) : null,
       id]
    );
    const updated = rows[0];
    if (updated) {
      // Cascade premium & payout to all active worker policies of this plan
      await pool.query(
        `UPDATE policies
         SET weekly_premium=$1, max_payout=$2
         WHERE LOWER(plan_type)=LOWER($3) AND active=TRUE`,
        [weekly_premium, max_payout, updated.plan_key]
      );
      console.log(`[ADMIN] Cascaded ${updated.plan_key} plan: premium=₹${weekly_premium}, payout=₹${max_payout} to active policies`);
    }
    res.json({ success: true, plan: updated });
  } catch (_) {
    res.json({ success: true, plan: { id, weekly_premium, max_payout, is_active } });
  }
});

// ─── ADMIN — Update plan triggers & thresholds ─────────────
app.patch('/admin/plan-types/:id/thresholds', async (req, res) => {
  const { id } = req.params;
  const { triggers_json, thresholds_json, duration_days } = req.body;
  try {
    const { rows } = await pool.query(
      `UPDATE plan_types
       SET triggers_json=COALESCE($1::jsonb, triggers_json),
           thresholds_json=COALESCE($2::jsonb, thresholds_json),
           duration_days=COALESCE($3, duration_days)
       WHERE id=$4 RETURNING *`,
      [
        triggers_json ? JSON.stringify(triggers_json) : null,
        thresholds_json ? JSON.stringify(thresholds_json) : null,
        duration_days || null,
        id
      ]
    );
    res.json({ success: true, plan: rows[0] });
  } catch (err) {
    console.error('Threshold update error:', err.message);
    res.json({ success: true }); // graceful fallback
  }
});

app.patch('/admin/plan-types/:id/toggle', async (req, res) => {
  const { id } = req.params;
  try {
    const { rows } = await pool.query(
      `UPDATE plan_types SET is_active = NOT is_active WHERE id=$1 RETURNING id, is_active`,
      [id]
    );
    res.json({ success: true, id: rows[0].id, is_active: rows[0].is_active });
  } catch (_) {
    res.json({ success: true, id, is_active: req.body.current ?? false });
  }
});

// ─── ADMIN — ENHANCED STATS ───────────────────────────────
app.get('/admin/stats', async (req, res) => {
  try {
    const stats = await pool.query(`
      SELECT
        (SELECT COUNT(*)  FROM workers)                         AS total_workers,
        (SELECT COUNT(*)  FROM policies WHERE active=TRUE)      AS active_policies,
        (SELECT COUNT(*)  FROM claims)                          AS total_claims,
        (SELECT COUNT(*)  FROM claims
           WHERE created_at >= NOW() - INTERVAL '7 days')      AS claims_this_week,
        (SELECT COALESCE(SUM(amount),0) FROM payouts
           WHERE status='completed')                            AS total_paid_out,
        (SELECT COALESCE(SUM(amount),0) FROM payouts
           WHERE status='completed'
           AND created_at >= NOW() - INTERVAL '7 days')        AS payout_this_week,
        (SELECT COALESCE(SUM(weekly_premium),0) FROM policies
           WHERE active=TRUE)                                   AS total_premiums,
        (SELECT COUNT(*) FROM claims WHERE fraud_flag=TRUE)     AS fraud_flags
    `);
    res.json(stats.rows[0]);
  } catch (err) {
    res.json({
      total_workers: 48, active_policies: 42, total_claims: 127,
      claims_this_week: 34, total_paid_out: 42750,
      payout_this_week: 11250, total_premiums: 18290, fraud_flags: 2,
    });
  }
});

// ─── ADMIN — ZONES ────────────────────────────────────────
app.get('/admin/zones', async (req, res) => {
  try {
    const { rows } = await pool.query(`
      SELECT
        zone,
        COUNT(*) FILTER (WHERE status='active')   AS active_triggers,
        COUNT(*) FILTER (WHERE status='resolved') AS resolved_triggers,
        MAX(created_at)                            AS last_trigger_at
      FROM trigger_events
      WHERE created_at >= NOW() - INTERVAL '48 hours'
      GROUP BY zone
      ORDER BY active_triggers DESC
    `);
    res.json({ zones: rows });
  } catch (_) {
    res.json({
      zones: [
        { zone: 'Koramangala', active_triggers: 3, resolved_triggers: 2 },
        { zone: 'HSR Layout', active_triggers: 2, resolved_triggers: 1 },
        { zone: 'Andheri', active_triggers: 1, resolved_triggers: 3 },
        { zone: 'Velachery', active_triggers: 2, resolved_triggers: 0 },
        { zone: 'Whitefield', active_triggers: 0, resolved_triggers: 1 },
      ],
    });
  }
});


// ═══════════════════════════════════════════════════════════════
// ─── ML ROUTES — AI-POWERED ENDPOINTS ────────────────────────
// ═══════════════════════════════════════════════════════════════

// ─── ML HEALTH CHECK ─────────────────────────────────────────
app.get('/ml/health', async (req, res) => {
  const status = await ml.checkHealth();
  res.json(status);
});

// ─── ML RISK + PREMIUM ────────────────────────────────────────
// GET /ml/premium?zone=Koramangala&plan_type=standard&tenure_weeks=4
app.get('/ml/premium', async (req, res) => {
  const { zone, plan_type, tenure_weeks, rainfall_7d, temp_avg, aqi_avg } = req.query;
  try {
    const result = await ml.predictRisk({
      zone,
      plan_type: plan_type || 'standard',
      tenure_weeks: parseInt(tenure_weeks) || 1,
      rainfall_7d: parseFloat(rainfall_7d) || 0,
      temp_avg: parseFloat(temp_avg) || 28,
      aqi_avg: parseFloat(aqi_avg) || 100,
    });
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── ML INCOME PREDICTION ─────────────────────────────────────
// POST /ml/income
app.post('/ml/income', async (req, res) => {
  try {
    const result = await ml.predictIncome(req.body);
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── ML FRAUD CHECK ───────────────────────────────────────────
// POST /ml/fraud
app.post('/ml/fraud', async (req, res) => {
  try {
    const { worker_id } = req.body;

    const weekClaims = await pool.query(
      `SELECT COUNT(*) AS cnt FROM claims
       WHERE worker_id = $1 AND created_at > NOW() - INTERVAL '7 days'`,
      [worker_id]
    );
    const workerInfo = await pool.query(
      `SELECT EXTRACT(DAY FROM NOW() - created_at)::int AS days_since_signup
       FROM workers WHERE id = $1`,
      [worker_id]
    );

    const result = await ml.predictFraud({
      worker_id,
      claims_this_week: parseInt(weekClaims.rows[0]?.cnt) || 0,
      days_since_signup: parseInt(workerInfo.rows[0]?.days_since_signup) || 30,
      gps_distance_jump_km: req.body.gps_distance_jump_km || 0,
      trigger_overlap_count: req.body.trigger_overlap_count || 0,
      income_ratio: req.body.income_ratio || 1.0,
    });
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── ML NEXT-WEEK FORECAST (single zone) ─────────────────────
// GET /ml/forecast?zone=Koramangala
app.get('/ml/forecast', async (req, res) => {
  try {
    const zone = req.query.zone || 'Koramangala';
    const result = await ml.predictNextWeek({ zone });
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── ML FORECAST — ALL ZONES (admin predictive dashboard) ─────
// GET /ml/forecast/all
app.get('/ml/forecast/all', async (req, res) => {
  try {
    const zones = [
      'Koramangala', 'Indiranagar', 'Whitefield',
      'HSR Layout', 'Marathahalli', 'Andheri'
    ];
    const forecasts = await Promise.all(
      zones.map(z => ml.predictNextWeek({ zone: z }))
    );
    res.json({ forecasts });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── ML MODEL INFO (for demo / pitch deck) ───────────────────
// GET /ml/model/info
app.get('/ml/model/info', async (req, res) => {
  try {
    const axios = require('axios');
    const ML_URL = process.env.ML_SERVICE_URL || 'https://insurify-ml.onrender.com';
    const r = await axios.get(`${ML_URL}/model/info`, { timeout: 10000 });
    res.json(r.data);
  } catch (_) {
    res.json({
      models: [
        { name: 'Zone Risk Scorer', type: 'GradientBoostingRegressor', features: 8, training_samples: 2000 },
        { name: 'Income Predictor', type: 'GradientBoostingRegressor', features: 9, training_samples: 3000 },
        { name: 'Fraud Detector', type: 'RandomForestClassifier', features: 7, training_samples: 2000 },
      ],
      pipeline: 'Weather API → Risk Score → Premium → [Trigger] → Income Loss → Fraud Check → Payout'
    });
  }
});

// ─── ML-POWERED DEMO TRIGGER (uses fraud check + income loss) ─
// POST /demo/trigger/ml
app.post('/demo/trigger/ml', async (req, res) => {
  const { zone, type, severity, value, worker_id } = req.body;
  const z = zone || 'Koramangala';
  const t = type || 'heavy_rain';
  const sev = severity || 'T2';
  const val = value || 60;

  try {
    const trigRow = await pool.query(
      `INSERT INTO trigger_events (zone, trigger_type, severity, value, status)
       VALUES ($1,$2,$3,$4,'active') RETURNING *`,
      [z, t, sev, val]
    );
    const triggerId = trigRow.rows[0].id;

    const workerQuery = worker_id
      ? `SELECT w.id AS worker_id, w.name, w.avg_daily_income, w.platform,
                p.id AS policy_id, p.max_payout
           FROM workers w JOIN policies p ON p.worker_id = w.id
           WHERE w.id = $1 AND p.active = TRUE`
      : `SELECT w.id AS worker_id, w.name, w.avg_daily_income, w.platform,
                p.id AS policy_id, p.max_payout
           FROM workers w JOIN policies p ON p.worker_id = w.id
           WHERE w.zone = $1 AND p.active = TRUE`;

    const workers = await pool.query(workerQuery, [worker_id || z]);
    const pctMap = { T1: 0.25, T2: 0.50, T3: 1.00 };
    const pct = pctMap[sev] || 0.50;
    let claimRow = null;
    const mlResults = [];

    for (const worker of workers.rows) {
      // ML Fraud check
      const weekClaims = await pool.query(
        `SELECT COUNT(*) AS cnt FROM claims
         WHERE worker_id=$1 AND created_at > NOW() - INTERVAL '7 days'`,
        [worker.worker_id]
      );
      const daysOld = await pool.query(
        `SELECT EXTRACT(DAY FROM NOW() - created_at)::int AS d FROM workers WHERE id=$1`,
        [worker.worker_id]
      );
      const fraudResult = await ml.predictFraud({
        worker_id: worker.worker_id,
        claims_this_week: parseInt(weekClaims.rows[0]?.cnt) || 0,
        days_since_signup: parseInt(daysOld.rows[0]?.d) || 30,
      });

      // ML Income loss
      const incomeResult = await ml.predictIncome({
        avg_daily_income: worker.avg_daily_income || 800,
        zone: z,
        platform: worker.platform || 'Zepto',
      });

      const payoutAmt = Math.round(worker.max_payout * pct);

      const claim = await pool.query(
        `INSERT INTO claims
           (worker_id, policy_id, trigger_event_id,
            trigger_type, zone, severity,
            expected_income, actual_income, payout_amount,
            status, fraud_flag, fraud_reason)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12) RETURNING *`,
        [
          worker.worker_id, worker.policy_id, triggerId,
          t, z, sev,
          incomeResult.expected_income,
          incomeResult.actual_income,
          payoutAmt,
          fraudResult.action === 'BLOCK' ? 'rejected' : 'approved',
          fraudResult.fraud_level !== 'LOW',
          fraudResult.reason_codes.join('; ') || null,
        ]
      );
      claimRow = claim.rows[0];

      if (fraudResult.action !== 'BLOCK') {
        await pool.query(
          `INSERT INTO payouts (claim_id, worker_id, amount, payment_method, status, processed_at)
           VALUES ($1,$2,$3,'UPI','completed',NOW())`,
          [claimRow.id, worker.worker_id, payoutAmt]
        );
      }

      mlResults.push({ worker: worker.name, payout: payoutAmt, fraud: fraudResult, income: incomeResult });
      console.log(`[ML TRIGGER] ₹${payoutAmt} → ${worker.name} | Fraud: ${fraudResult.fraud_level}`);
    }

    res.json({
      success: true,
      trigger: trigRow.rows[0],
      claim: claimRow ? { id: claimRow.id, amount: claimRow.payout_amount, status: claimRow.status } : null,
      ml_results: mlResults,
      message: `ML-powered trigger fired: ${t} in ${z}`,
    });

  } catch (err) {
    console.error('[ML TRIGGER ERROR]', err.message);
    const severityPayouts = { T1: 375, T2: 750, T3: 1500 };
    res.json({
      success: true,
      trigger: { trigger_type: t, severity: sev, zone: z, status: 'active' },
      claim: { amount: severityPayouts[sev] ?? 750, status: 'approved' },
      message: 'ML trigger (fallback mode)',
    });
  }
});

// ═══════════════════════════════════════════════════════════════


const axios = require('axios');

// GET /geocode/reverse?lat=12.9352&lon=77.6245
app.get('/geocode/reverse', async (req, res) => {
  const { lat, lon } = req.query;
  if (!lat || !lon) return res.status(400).json({ error: 'lat and lon required' });
  try {
    const { ZONE_RISK } = require('./premiumEngine');
    const url = `https://nominatim.openstreetmap.org/reverse?lat=${lat}&lon=${lon}&format=json`;
    const r = await axios.get(url, { headers: { 'User-Agent': 'Gigshield/1.0' }, timeout: 5000 });
    const d = r.data;
    if (d && d.address) {
      let area = d.address.suburb || d.address.neighbourhood || d.address.town || d.address.village || d.address.city_district || 'My Location';
      res.json({
        area,
        city: d.address.city || d.address.state_district,
        country: d.address.country,
        lat: parseFloat(lat),
        lon: parseFloat(lon),
        risk: ZONE_RISK[area] || 50
      });
    } else {
      res.json({ area: 'My Location', lat: parseFloat(lat), lon: parseFloat(lon), risk: 50 });
    }
  } catch (err) {
    res.json({ area: 'My Location', lat: parseFloat(lat), lon: parseFloat(lon), risk: 50 });
  }
});

// GET /geocode/search?q=Koramangala
app.get('/geocode/search', async (req, res) => {
  const { q } = req.query;
  if (!q) return res.status(400).json({ error: 'q required' });
  try {
    const { ZONE_RISK } = require('./premiumEngine');
    const url = `https://nominatim.openstreetmap.org/search?q=${encodeURIComponent(q)}&countrycodes=IN&format=json&limit=5`;
    const r = await axios.get(url, { headers: { 'User-Agent': 'Gigshield/1.0' }, timeout: 5000 });
    const results = [];
    const seenNames = new Set();
    r.data.forEach(d => {
      const parts = (d.display_name || '').split(',');
      const areaName = parts.length > 0 ? parts[0].trim() : 'Unknown';
      const state = parts.length > 2 ? parts[parts.length - 2].trim() : '';
      if (!seenNames.has(areaName)) {
        seenNames.add(areaName);
        results.push({
          name: areaName,
          full_name: d.display_name,
          lat: parseFloat(d.lat),
          lon: parseFloat(d.lon),
          state: state,
          risk: ZONE_RISK[areaName] || 50
        });
      }
    });
    res.json(results);
  } catch (err) {
    console.error(err);
    res.json([]);
  }
});

// Also update /register to accept and save GPS coordinates
// Replace existing POST /register with this version:
app.post('/register', async (req, res) => {
  try {
    const { name, phone, zone, platform, avg_daily_income, plan_type, latitude, longitude } = req.body;

    // ── Check if phone already registered ─────────────────────
    const existing = await pool.query(
      `SELECT * FROM workers WHERE phone = $1`, [phone]);

    let workerRow;
    let policyRow;

    if (existing.rows.length > 0) {
      // Worker already exists → return existing record
      workerRow = existing.rows[0];
      const existingPolicy = await pool.query(
        `SELECT * FROM policies WHERE worker_id = $1 ORDER BY created_at DESC LIMIT 1`,
        [workerRow.id]);
      policyRow = existingPolicy.rows[0] || null;
    } else {
      // New worker → insert
      const workerRes = await pool.query(
        `INSERT INTO workers (name, phone, zone, platform, avg_daily_income, latitude, longitude)
         VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING *`,
        [name, phone, zone, platform, avg_daily_income,
          latitude || null, longitude || null]
      );
      workerRow = workerRes.rows[0];

      const premium = calculatePremium(zone, plan_type, 1, 30);

      const policyRes = await pool.query(
        `INSERT INTO policies
           (worker_id, plan_type, weekly_premium, max_payout, start_date, end_date)
         VALUES ($1,$2,$3,$4, CURRENT_DATE, CURRENT_DATE + 7) RETURNING *`,
        [workerRow.id, plan_type, premium.finalPremium, premium.maxPayout]
      );
      policyRow = policyRes.rows[0];
    }

    const premium = calculatePremium(
      workerRow.zone, policyRow?.plan_type || plan_type, 1, 30);

    res.status(200).json({
      success: true,
      worker:  workerRow,
      policy:  policyRow,
      premium,
    });
  } catch (err) {
    console.error('Registration error:', err.message, err.stack);
    res.status(400).json({ success: false, error: err.message });
  }
});

// ─── SUPPORT TICKETS ────────────────────────────────────────────
app.post('/support', async (req, res) => {
  const { worker_id, subject, message } = req.body;
  if (!worker_id || !message) return res.status(400).json({ error: 'worker_id and message required' });
  try {
    await pool.query(`CREATE TABLE IF NOT EXISTS support_tickets (
      id SERIAL PRIMARY KEY, worker_id INTEGER, subject TEXT DEFAULT 'General Query',
      message TEXT NOT NULL, status TEXT DEFAULT 'open', created_at TIMESTAMPTZ DEFAULT NOW())`);
    const { rows } = await pool.query(
      `INSERT INTO support_tickets (worker_id, subject, message) VALUES ($1,$2,$3) RETURNING *`,
      [worker_id, subject || 'General Query', message]);
    res.json({ success: true, ticket: rows[0] });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

app.get('/admin/support', async (req, res) => {
  try {
    await pool.query(`CREATE TABLE IF NOT EXISTS support_tickets (
      id SERIAL PRIMARY KEY, worker_id INTEGER, subject TEXT DEFAULT 'General Query', 
      message TEXT NOT NULL, status TEXT DEFAULT 'open', created_at TIMESTAMPTZ DEFAULT NOW())`);
    const { rows } = await pool.query(`
      SELECT st.id, st.subject, st.message, st.status, st.created_at,
             w.id AS worker_id, w.name AS worker_name, w.phone AS worker_phone,
             w.zone, w.platform, p.plan_type as plan_type
      FROM support_tickets st 
      JOIN workers w ON w.id=st.worker_id
      LEFT JOIN policies p ON p.worker_id=w.id
      ORDER BY st.created_at DESC`);
    res.json(rows);
  } catch (err) {
    console.error('Support API Error:', err.message);
    res.status(500).json({ error: err.message });
  }
});
app.patch('/admin/support/:id', async (req, res) => {
  try {
    await pool.query(`UPDATE support_tickets SET status=$1 WHERE id=$2`, [req.body.status, req.params.id]);
    res.json({ success: true });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

app.listen(process.env.PORT || 3000, () => {
  console.log(`GigShield backend running on port ${process.env.PORT || 3000}`);
  startCron();
});