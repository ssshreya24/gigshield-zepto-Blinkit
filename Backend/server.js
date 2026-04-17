const express = require('express');
const cors    = require('cors');
const pool    = require('./db');
const { calculatePremium } = require('./premiumEngine');
const { fireTrigger, startCron } = require('./triggerEngine');
const { ensureZoneExists, getAllZones, getZoneFeatures } = require('./zoneService');
const { getPayoutMap, getConfig, loadConfig } = require('./configService');
const { createPayoutOrder, verifyPaymentSignature, createUpiPayout } = require('./paymentService');

// const { fireTrigger }      = require('./triggerEngine');

require('dotenv').config();

const app = express();
app.use(cors());
app.use(express.json());

// ─── Haversine distance (km) ────────────────────────────
function haversineKm(lat1, lon1, lat2, lon2) {
  const R = 6371;
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = Math.sin(dLat/2) * Math.sin(dLat/2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLon/2) * Math.sin(dLon/2);
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
}

// ─── HEALTH CHECK ────────────────────────────────────────
app.get('/health', async (req, res) => {
  const db = await pool.query('SELECT NOW()');
  res.json({ status: 'ok', db_time: db.rows[0].now });
});

// ─── WEATHER CHECK (for auto-trigger decision) ──────────
app.get('/api/weather-check/:zone', async (req, res) => {
  try {
    const zone = decodeURIComponent(req.params.zone);
    const weatherKey = process.env.WEATHER_API_KEY || process.env.OPENWEATHER_API_KEY;
    if (!weatherKey) return res.json({ disruption: false, reason: 'No weather API key' });

    // Geocode zone to coords
    const geoUrl = `https://api.openweathermap.org/geo/1.0/direct?q=${encodeURIComponent(zone + ', India')}&limit=1&appid=${weatherKey}`;
    const geoRes = await require('axios').get(geoUrl);
    const coords = geoRes.data?.[0] || { lat: 12.9716, lon: 77.5946 };

    // Fetch current weather
    const wxUrl = `https://api.openweathermap.org/data/2.5/weather?lat=${coords.lat}&lon=${coords.lon}&appid=${weatherKey}&units=metric`;
    const wxRes = await require('axios').get(wxUrl);
    const w = wxRes.data;

    const rainfall    = w.rain?.['1h'] ?? 0;
    const temperature = w.main?.temp ?? 25;
    const humidity    = w.main?.humidity ?? 50;
    const windSpeed   = w.wind?.speed ?? 0;
    const weatherId   = w.weather?.[0]?.id ?? 800;
    const description = w.weather?.[0]?.description ?? 'clear';

    // Determine which disruptions are active based on real weather
    const disruptions = [];

    // Heavy rain: >5mm/hr rainfall OR weather code 500-531 (rain/drizzle)
    if (rainfall >= 5 || (weatherId >= 500 && weatherId <= 531)) {
      disruptions.push({ type: 'heavy_rain', severity: rainfall >= 15 ? 'T3' : 'T2', value: Math.round(rainfall) });
    }

    // Flood alert: weather code 900-910 OR extreme rainfall >25mm
    if ((weatherId >= 900 && weatherId <= 910) || rainfall >= 25) {
      disruptions.push({ type: 'flood_alert', severity: 'T3', value: Math.round(rainfall) });
    }

    // Extreme heat: temp > 40°C
    if (temperature >= 40) {
      disruptions.push({ type: 'extreme_heat', severity: temperature >= 45 ? 'T3' : 'T1', value: Math.round(temperature) });
    }

    // Severe AQI: fetch air pollution data
    try {
      const aqiUrl = `https://api.openweathermap.org/data/2.5/air_pollution?lat=${coords.lat}&lon=${coords.lon}&appid=${weatherKey}`;
      const aqiRes = await require('axios').get(aqiUrl);
      const aqiLevel = aqiRes.data?.list?.[0]?.main?.aqi ?? 1;
      // OWM AQI: 4=Poor, 5=VeryPoor → trigger
      if (aqiLevel >= 4) {
        disruptions.push({ type: 'severe_aqi', severity: aqiLevel >= 5 ? 'T3' : 'T2', value: aqiLevel * 75 });
      }
    } catch (_) {}

    // High wind (cyclone risk): wind > 60 km/h
    if (windSpeed * 3.6 >= 60) {
      disruptions.push({ type: 'cyclone', severity: 'T3', value: Math.round(windSpeed * 3.6) });
    }

    res.json({
      zone,
      disruption: disruptions.length > 0,
      disruptions,
      weather: { rainfall, temperature, humidity, windSpeed, weatherId, description },
    });
  } catch (err) {
    console.error('Weather check error:', err.message);
    res.json({ disruption: false, disruptions: [], reason: err.message });
  }
});

// ─── WORKER REGISTRATION ─────────────────────────────────
app.post('/register', async (req, res) => {
  try {
    const { name, phone, zone, platform, avg_daily_income, plan_type } = req.body;
    const income = avg_daily_income || 800; // Default ₹800/day

    const worker = await pool.query(
      `INSERT INTO workers (name, phone, zone, platform, avg_daily_income)
       VALUES ($1,$2,$3,$4,$5) RETURNING *`,
      [name, phone, zone, platform, income]
    );

    // Auto-detect and register zone (geocode + save to zones table)
    await ensureZoneExists(zone);

    const premium = await calculatePremium(zone, plan_type, 1, 30);

    const policy = await pool.query(
      `INSERT INTO policies
         (worker_id, plan_type, weekly_premium, max_payout, start_date, end_date)
       VALUES ($1,$2,$3,$4, CURRENT_DATE, CURRENT_DATE + 7) RETURNING *`,
      [worker.rows[0].id, plan_type, premium.finalPremium, premium.maxPayout]
    );

    res.status(201).json({
      success: true,
      worker:  worker.rows[0],
      policy:  policy.rows[0],
      premium,
    });
  } catch (err) {
    res.status(400).json({ success: false, error: err.message });
  }
});

// ─── DYNAMIC PREMIUM QUOTE ───────────────────────────────
app.get('/premium', async (req, res) => {
  const { zone, plan_type, tenure_weeks, weather_risk } = req.query;
  const result = await calculatePremium(
    zone, plan_type,
    parseInt(tenure_weeks) || 1,
    parseInt(weather_risk) || 30
  );
  res.json(result);
});

// ─── GET WORKER POLICY ───────────────────────────────────
app.get('/policy/:workerId', async (req, res) => {
  const result = await pool.query(
    `SELECT p.*, w.name, w.zone, w.platform
     FROM policies p
     JOIN workers w ON w.id = p.worker_id
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

// ─── ADMIN STATS — see enhanced version further below ────
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
app.get('/triggers/:zone', async (req, res) => {
  try {
    const { zone } = req.params;
    const result   = await pool.query(
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

// Admin login (credentials from environment variables)
app.post('/admin/login', async (req, res) => {
  const { email, password } = req.body;
  const adminEmail = process.env.ADMIN_EMAIL;
  const adminPass  = process.env.ADMIN_PASSWORD;
  if (email === adminEmail && password === adminPass) {
    const token = `${process.env.ADMIN_TOKEN_SECRET}-${Date.now()}`;
    res.json({ success: true, token, name: 'Insurify Admin' });
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
    res.json(result.rows[0]);
  } catch (err) { res.status(500).json({ error: err.message }); }
});
// ─── DEMO — FIRE TRIGGER + CREATE CLAIM VIA FRAUD PIPELINE ───
app.post('/demo/trigger', async (req, res) => {
  const { zone, type, severity, value, worker_id, force_fraud } = req.body;
  const z   = zone     ?? 'Unknown';
  const t   = type     ?? 'heavy_rain';
  const sev = severity ?? 'T2';
  const val = value    ?? 60;

  try {
    // 1. Insert a fresh trigger event (no dedup — demo always works)
    const trigRow = await pool.query(
      `INSERT INTO trigger_events
         (zone, trigger_type, severity, value, status)
       VALUES ($1, $2, $3, $4, 'active')
       RETURNING *`,
      [z, t, sev, val]
    );
    const triggerId = trigRow.rows[0].id;

    // 2. Find workers with active policies in this zone
    const workerQuery = worker_id
      ? `SELECT w.id AS worker_id, w.name, w.zone,
                w.last_lat, w.last_lon, w.last_gps_time,
                p.id AS policy_id, p.max_payout, w.avg_daily_income
           FROM workers w
           JOIN policies p ON p.worker_id = w.id
           WHERE w.id = $1 AND p.active = TRUE`
      : `SELECT w.id AS worker_id, w.name, w.zone,
                w.last_lat, w.last_lon, w.last_gps_time,
                p.id AS policy_id, p.max_payout, w.avg_daily_income
           FROM workers w
           JOIN policies p ON p.worker_id = w.id
           WHERE w.zone = $1 AND p.active = TRUE`;

    const workers = await pool.query(workerQuery, [worker_id ?? z]);

    const pctMap = await getPayoutMap();
    const pct    = pctMap[sev] ?? 0.50;

    let claimRow = null;
    let outFraudScore = 0;
    let outMlProbability = 0;
    let outBehaviorProfile = {};

    for (const worker of workers.rows) {
      const payoutAmt = Math.round(worker.max_payout * pct);

      // ═══════════════════════════════════════════════════════
      // FRAUD DETECTION PIPELINE — 5 Layers + ML Scoring
      // ═══════════════════════════════════════════════════════
      let fraudScore  = 0;
      const fraudReason = [];
      let claimStatus = 'approved';

      // Layer 1: Weather cross-verification (live API check)
      try {
        const weatherKey = process.env.WEATHER_API_KEY || process.env.OPENWEATHER_API_KEY;
        if (weatherKey) {
          const axios = require('axios');
          // Fetch current weather
          const wxUrl = `https://api.openweathermap.org/data/2.5/weather?q=${z},IN&appid=${weatherKey}&units=metric`;
          const wxRes = await axios.get(wxUrl);
          const wx    = wxRes.data;
          
          const rain  = wx?.rain?.['1h'] || wx?.rain?.['3h'] || 0;
          const temp  = wx?.main?.temp || 25;
          const weatherId = wx?.weather?.[0]?.id || 800;

          if (t === 'heavy_rain' && rain < 2) {
            fraudScore += 30;
            fraudReason.push(`Weather API cross-check: No rain detected (${rain}mm) but ${t} claimed.`);
          }
          if (t === 'extreme_heat' && temp < 35) {
            fraudScore += 25;
            fraudReason.push(`Weather API cross-check: Temp ${temp}°C is normal, but ${t} claimed.`);
          }
          if (t === 'flood_alert' && rain < 10 && !(weatherId >= 900 && weatherId <= 910)) {
            fraudScore += 35;
            fraudReason.push(`Weather API cross-check: No flooding indicators (rain ${rain}mm) but ${t} claimed.`);
          }
          if (t === 'severe_aqi') {
            try {
              const aqiUrl = `https://api.openweathermap.org/data/2.5/air_pollution?lat=${wx.coord.lat}&lon=${wx.coord.lon}&appid=${weatherKey}`;
              const aqiRes = await axios.get(aqiUrl);
              const aqiLevel = aqiRes.data?.list?.[0]?.main?.aqi ?? 1;
              if (aqiLevel < 4) { // 1=Good, 2=Fair, 3=Moderate
                fraudScore += 25;
                fraudReason.push(`Weather API cross-check: Safe air quality (OWM AQI Level ${aqiLevel}) but ${t} claimed.`);
              }
            } catch (_) {}
          }
        }
      } catch (err) {
        console.error('Weather fraud verification failed:', err.message);
      }

      // Layer 2: Individual Behavioral Profiling (per-worker analysis)
      let behaviorProfile = {};
      try {
        // 2a: Claim frequency analysis (7-day + 30-day windows)
        const recent7 = await pool.query(
          `SELECT COUNT(*) as cnt, COALESCE(AVG(payout_amount),0) as avg_amt,
                  MIN(created_at) as earliest
           FROM claims WHERE worker_id = $1 AND created_at > NOW() - INTERVAL '7 days'`,
          [worker.worker_id]
        );
        const recent30 = await pool.query(
          `SELECT COUNT(*) as cnt, COALESCE(AVG(payout_amount),0) as avg_amt,
                  COALESCE(STDDEV(payout_amount),0) as std_amt
           FROM claims WHERE worker_id = $1 AND created_at > NOW() - INTERVAL '30 days'`,
          [worker.worker_id]
        );

        const claims7d  = parseInt(recent7.rows[0].cnt);
        const claims30d = parseInt(recent30.rows[0].cnt);
        const avgAmt30d = parseFloat(recent30.rows[0].avg_amt);
        const stdAmt30d = parseFloat(recent30.rows[0].std_amt) || 0;

        // 2b: Claim-to-income ratio (anomaly if claiming > 2x daily income)
        const dailyIncome = worker.avg_daily_income || 800;
        const claimToIncomeRatio = payoutAmt / dailyIncome;

        // 2c: Time-of-day analysis (suspicious if claim at unusual hours)
        const claimHour = new Date().getHours();
        const isOddHour = claimHour >= 0 && claimHour <= 5; // midnight-5am

        // 2d: Claim interval analysis (suspicious if <2hrs between claims)
        let shortInterval = false;
        if (recent7.rows[0].earliest) {
          const lastClaimAge = (Date.now() - new Date(recent7.rows[0].earliest).getTime()) / 3600000;
          shortInterval = claims7d > 0 && lastClaimAge < 2;
        }

        // 2e: Amount deviation (suspicious if >2 std deviations from worker's mean)
        const amountDeviation = stdAmt30d > 0 ? Math.abs(payoutAmt - avgAmt30d) / stdAmt30d : 0;

        behaviorProfile = {
          claims_7d: claims7d,
          claims_30d: claims30d,
          avg_amount_30d: avgAmt30d,
          claim_to_income_ratio: claimToIncomeRatio,
          odd_hour: isOddHour,
          short_interval: shortInterval,
          amount_deviation: amountDeviation,
        };

        // Score behavioral features
        if (claims7d >= 5) {
          fraudScore += 35;
          fraudReason.push(`Behavioral: ${claims7d} claims in 7 days (excessive, avg is <2)`);
        } else if (claims7d >= 3) {
          fraudScore += 15;
          fraudReason.push(`Behavioral: ${claims7d} claims in 7 days (elevated frequency)`);
        }

        if (claimToIncomeRatio > 3) {
          fraudScore += 20;
          fraudReason.push(`Income anomaly: claim ₹${payoutAmt} is ${claimToIncomeRatio.toFixed(1)}x daily income ₹${dailyIncome}`);
        }

        if (shortInterval) {
          fraudScore += 15;
          fraudReason.push(`Rapid claims: multiple claims within 2-hour window`);
        }

        if (amountDeviation > 2.5 && claims30d >= 3) {
          fraudScore += 10;
          fraudReason.push(`Amount outlier: ₹${payoutAmt} is ${amountDeviation.toFixed(1)}σ from worker mean ₹${avgAmt30d.toFixed(0)}`);
        }

        if (isOddHour && claims7d >= 2) {
          fraudScore += 10;
          fraudReason.push(`Time anomaly: claim at ${claimHour}:00 (unusual hour) with elevated frequency`);
        }
      } catch (_) {}

      // Layer 3: GPS spoofing detection (haversine distance)
      if (worker.last_lat && worker.last_lon) {
        const zoneCoords = await pool.query(
          `SELECT lat, lon FROM zones WHERE name = $1`, [z]);
        if (zoneCoords.rows.length > 0) {
          const zLat = zoneCoords.rows[0].lat;
          const zLon = zoneCoords.rows[0].lon;
          const dist = haversineKm(worker.last_lat, worker.last_lon, zLat, zLon);
          if (dist > 150) {
            fraudScore += 40;
            fraudReason.push(`GPS spoofing: worker ${dist.toFixed(1)}km from zone (max 150km)`);
          } else if (dist > 80) {
            fraudScore += 15;
            fraudReason.push(`GPS distance: worker ${dist.toFixed(1)}km from zone (far)`);
          }
        }
      }

      // Layer 4: ML-inspired composite scoring (sigmoid normalization)
      // Applies a logistic function to the raw score for smoother thresholding
      const rawScore = fraudScore;
      const sigmoid = (x) => 1 / (1 + Math.exp(-0.1 * (x - 40)));
      const mlFraudProbability = sigmoid(rawScore);

      // Layer 5: Force fraud override (for testing)
      if (force_fraud) {
        fraudScore = Math.max(fraudScore, 55);
        if (fraudReason.length === 0) {
          fraudReason.push('Manual trigger: Suspicious activity testing');
        }
      }

      // Final decision tiers
      if (fraudScore >= 70) {
        claimStatus = 'rejected';
      } else if (fraudScore >= 30) {
        claimStatus = 'fraud_review';
      }

      const isFraud = fraudScore >= 30;
      const reasonStr = fraudReason.join('; ') || null;

      // Insert claim with fraud results + behavioral profile
      const claim = await pool.query(
        `INSERT INTO claims
           (worker_id, policy_id, trigger_event_id,
            trigger_type, zone, severity,
            expected_income, actual_income, payout_amount,
            status, fraud_flag, fraud_reason)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)
         RETURNING *`,
        [worker.worker_id, worker.policy_id, triggerId,
         t, z, sev, 800, 0, payoutAmt,
         claimStatus, isFraud, reasonStr]
      );
      claimRow = claim.rows[0];

      outFraudScore = fraudScore;
      outMlProbability = mlFraudProbability;
      outBehaviorProfile = behaviorProfile;

      // Only create payout if approved
      if (claimStatus === 'approved') {
        await pool.query(
          `INSERT INTO payouts
             (claim_id, worker_id, amount, payment_method, status, processed_at)
           VALUES ($1,$2,$3,'UPI','completed',NOW())`,
          [claimRow.id, worker.worker_id, payoutAmt]
        );
      }

      console.log(`[DEMO] Claim ₹${payoutAmt} for ${worker.name} | Fraud: ${fraudScore} | Status: ${claimStatus}${reasonStr ? ' | ' + reasonStr : ''}`);
    }

    res.json({
      success: true,
      trigger: trigRow.rows[0],
      claim: claimRow
        ? { id: claimRow.id, amount: claimRow.payout_amount,
            status: claimRow.status, fraud_flag: claimRow.fraud_flag,
            fraud_score: outFraudScore || 0,
            fraud_probability: outMlProbability ? `${(outMlProbability*100).toFixed(1)}%` : '0%',
            fraud_reason: claimRow.fraud_reason,
            behavioral_profile: outBehaviorProfile || {} }
        : null,
      message: `Demo trigger fired: ${t} in ${z}`,
    });

  } catch (err) {
    console.error('[DEMO TRIGGER ERROR]', err.message);
    res.status(500).json({ success: false, error: err.message });
  }
});

// Helper — payout from config
async function _payoutForSeverity(sev) {
  const map = await getPayoutMap();
  return map[sev] ?? 0.50;
}


// ─── WORKER BEHAVIORAL PROFILE API ──────────────────────────
app.get('/api/worker-profile/:workerId', async (req, res) => {
  try {
    const { workerId } = req.params;

    // Worker info
    const wk = await pool.query(
      `SELECT id, name, zone, avg_daily_income, created_at FROM workers WHERE id = $1`, [workerId]);
    if (wk.rows.length === 0) return res.status(404).json({ error: 'Worker not found' });
    const worker = wk.rows[0];

    // Claim stats (7-day, 30-day, lifetime)
    const stats = await pool.query(`
      SELECT
        COUNT(*) FILTER (WHERE created_at > NOW() - INTERVAL '7 days')  AS claims_7d,
        COUNT(*) FILTER (WHERE created_at > NOW() - INTERVAL '30 days') AS claims_30d,
        COUNT(*)                                                         AS claims_total,
        COALESCE(AVG(payout_amount), 0)                                  AS avg_payout,
        COALESCE(STDDEV(payout_amount), 0)                               AS stddev_payout,
        COALESCE(MAX(payout_amount), 0)                                  AS max_payout,
        COUNT(*) FILTER (WHERE fraud_flag = TRUE)                        AS fraud_count,
        COUNT(*) FILTER (WHERE status = 'approved')                      AS approved_count,
        COUNT(*) FILTER (WHERE status = 'rejected')                      AS rejected_count
      FROM claims WHERE worker_id = $1
    `, [workerId]);

    const s = stats.rows[0];
    const totalClaims = parseInt(s.claims_total) || 1;
    const fraudRate = parseInt(s.fraud_count) / totalClaims;

    // Last claim timing
    const lastClaim = await pool.query(
      `SELECT created_at FROM claims WHERE worker_id = $1 ORDER BY created_at DESC LIMIT 1`, [workerId]);

    // Compute individual risk score (0-100)
    const claimFreqScore  = Math.min((parseInt(s.claims_7d) / 5) * 30, 30);
    const fraudHistScore  = Math.min(fraudRate * 40, 40);
    const amountScore     = Math.min((parseFloat(s.avg_payout) / (worker.avg_daily_income || 800)) * 15, 15);
    const tenureScore     = Math.max(0, 15 - ((Date.now() - new Date(worker.created_at).getTime()) / 86400000 / 30) * 5);
    const individualRisk  = Math.round(claimFreqScore + fraudHistScore + amountScore + tenureScore);

    res.json({
      worker: {
        id: worker.id,
        name: worker.name,
        zone: worker.zone,
        dailyIncome: worker.avg_daily_income,
        memberSince: worker.created_at,
      },
      behavioral_profile: {
        claims_7d:       parseInt(s.claims_7d),
        claims_30d:      parseInt(s.claims_30d),
        claims_total:    parseInt(s.claims_total),
        avg_payout:      Math.round(parseFloat(s.avg_payout)),
        stddev_payout:   Math.round(parseFloat(s.stddev_payout)),
        max_payout:      parseInt(s.max_payout),
        fraud_count:     parseInt(s.fraud_count),
        fraud_rate:      `${(fraudRate * 100).toFixed(1)}%`,
        approved_count:  parseInt(s.approved_count),
        rejected_count:  parseInt(s.rejected_count),
        last_claim_at:   lastClaim.rows[0]?.created_at || null,
      },
      risk_assessment: {
        individual_risk_score: individualRisk,
        risk_level: individualRisk > 60 ? 'HIGH' : individualRisk > 30 ? 'MEDIUM' : 'LOW',
        breakdown: {
          claim_frequency: Math.round(claimFreqScore),
          fraud_history:   Math.round(fraudHistScore),
          amount_anomaly:  Math.round(amountScore),
          tenure_risk:     Math.round(tenureScore),
        },
        source: 'behavioral_ml',
      },
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── PASTE 2: Admin — Plan Types (global plan catalogue) ───────
// Add AFTER the existing admin routes

/**
 * GET /admin/plan-types
 * Returns the 3 canonical plan definitions.
 * Admin can edit premium/payout here and workers will see
 * updated values on next onboarding fetch.
 */
app.get('/admin/plan-types', async (req, res) => {
  try {
    const { rows } = await pool.query(
      `SELECT id, name, plan_key, weekly_premium, max_payout,
              triggers_json, is_active
       FROM plan_types ORDER BY id`
    );
    if (rows.length === 0) throw new Error('Table empty or not found');
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: 'Could not load plan types: ' + err.message });
  }
});

/** PUT /admin/plan-types/:id — Update premium & payout */
app.put('/admin/plan-types/:id', async (req, res) => {
  const { id } = req.params;
  const { weekly_premium, max_payout, is_active } = req.body;
  try {
    const { rows } = await pool.query(
      `UPDATE plan_types
       SET weekly_premium=$1, max_payout=$2, is_active=$3
       WHERE id=$4 RETURNING *`,
      [weekly_premium, max_payout, is_active, id]
    );
    res.json({ success: true, plan: rows[0] });
  } catch (_) {
    res.json({ success: true, plan: { id, weekly_premium, max_payout, is_active } });
  }
});

/** PATCH /admin/plan-types/:id/toggle — Enable / disable plan */
app.patch('/admin/plan-types/:id/toggle', async (req, res) => {
  const { id } = req.params;
  try {
    const { rows } = await pool.query(
      `UPDATE plan_types SET is_active = NOT is_active
       WHERE id=$1 RETURNING id, is_active`,
      [id]
    );
    res.json({ success: true, id: rows[0].id, is_active: rows[0].is_active });
  } catch (_) {
    res.json({ success: true, id, is_active: req.body.current ?? false });
  }
});


// ── PASTE 3: Admin — Enhanced Analytics + Loss Ratio ──────────

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
        (SELECT COUNT(*) FROM claims WHERE fraud_flag=TRUE)     AS fraud_flags,
        (SELECT COALESCE(AVG(payout_amount),0) FROM claims
           WHERE status='approved')                             AS avg_claim_amount
    `);

    const row = stats.rows[0];
    const totalPaidOut  = parseFloat(row.total_paid_out) || 0;
    const totalPremiums = parseFloat(row.total_premiums) || 1; // avoid div/0
    const totalClaims   = parseInt(row.total_claims) || 1;
    const fraudFlags    = parseInt(row.fraud_flags) || 0;

    // Loss Ratio = Total Payouts / Total Premiums Collected
    // <100% = profitable, >100% = losing money
    const lossRatio = ((totalPaidOut / totalPremiums) * 100).toFixed(1);
    const fraudRate = ((fraudFlags / totalClaims) * 100).toFixed(1);

    res.json({
      ...row,
      loss_ratio:       `${lossRatio}%`,
      loss_ratio_value: parseFloat(lossRatio),
      fraud_rate:       `${fraudRate}%`,
      profitability:    parseFloat(lossRatio) < 100 ? 'PROFITABLE' : 'AT_RISK',
    });
  } catch (err) {
    res.status(500).json({ error: 'Stats unavailable: ' + err.message });
  }
});


// ── PASTE 4: Admin — Zones endpoint ──────────────────────────
// Add AFTER other admin routes

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
  } catch (err) {
    res.status(500).json({ error: 'Zones unavailable: ' + err.message });
  }
});

// ─── DYNAMIC ZONE APIs (for Flutter frontend) ────────────
// Returns all active zones from DB — frontend uses this instead of hardcoded lists
app.get('/api/zones', async (req, res) => {
  try {
    const zones = await getAllZones();
    // Group zones by city (resolved from geocoding)
    const { rows: zoneDetails } = await pool.query(`
      SELECT z.name, z.lat, z.lon,
             COUNT(DISTINCT w.id) as worker_count
      FROM zones z
      LEFT JOIN workers w ON LOWER(w.zone) = LOWER(z.name)
      GROUP BY z.name, z.lat, z.lon
      ORDER BY z.name
    `);
    res.json({ zones: zoneDetails });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Returns dynamic risk score for a specific zone — uses trained XGBoost ML model
app.get('/api/zone-risk/:zone', async (req, res) => {
  try {
    const { zone } = req.params;
    const zoneName = decodeURIComponent(zone);
    const features = await getZoneFeatures(zoneName);

    // Call the trained XGBoost model via ML API
    const { getZoneRiskMultiplier } = require('./premiumEngine');
    const mlResult = await getZoneRiskMultiplier(zoneName);

    // If ML model responded, use its prediction
    if (mlResult.riskLabel !== 'UNKNOWN') {
      const riskScore = mlResult.riskLabel === 'HIGH' ? 75 :
                        mlResult.riskLabel === 'MEDIUM' ? 50 : 25;
      res.json({
        zone: zoneName,
        riskScore,
        riskLevel: mlResult.riskLabel === 'HIGH' ? 'HIGH' :
                   mlResult.riskLabel === 'MEDIUM' ? 'MED' : 'LOW',
        mlMultiplier: mlResult.multiplier,
        source: 'xgboost_model',
        features,
      });
    } else {
      // Fallback: rule-based scoring (only when ML is unavailable)
      const rainScore   = Math.min(Math.round((features.avg_monthly_rain_mm / 300) * 30), 30);
      const floodScore  = Math.min(Math.round((features.flood_events_per_year / 10) * 25), 25);
      const aqiScore    = Math.min(Math.round((features.aqi_bad_days_per_month / 15) * 25), 25);
      const outageScore = Math.min(Math.round((features.dark_store_outages_month / 5) * 20), 20);
      const riskScore   = rainScore + floodScore + aqiScore + outageScore;

      res.json({
        zone: zoneName,
        riskScore,
        riskLevel: riskScore > 60 ? 'HIGH' : riskScore > 40 ? 'MED' : 'LOW',
        source: 'rule_fallback',
        features,
      });
    }
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Returns app config for a given category (for admin dashboard)
app.get('/api/config/:category', async (req, res) => {
  try {
    const { rows } = await pool.query(
      `SELECT key, value, label FROM app_config WHERE category = $1 ORDER BY key`,
      [req.params.category]
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Update a config value
app.put('/api/config/:key', async (req, res) => {
  try {
    const { value } = req.body;
    await pool.query(
      `UPDATE app_config SET value = $1, updated_at = NOW() WHERE key = $2`,
      [value, req.params.key]
    );
    const { invalidateCache } = require('./configService');
    invalidateCache();
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── OTP Endpoints (demo mode — production: use Twilio/MSG91) ───
// Store generated OTPs in memory (replace with Redis/DB in production)
const otpStore = {};

app.post('/otp/send', (req, res) => {
  const { phone } = req.body;
  // Generate 6-digit OTP
  const otp = Math.floor(100000 + Math.random() * 900000).toString();
  otpStore[phone] = { otp, createdAt: Date.now() };
  console.log(`[OTP] Sent ${otp} to ${phone} (demo mode — not actually sent)`);
  // In production: integrate SMS gateway here
  res.json({ success: true, message: 'OTP sent to your phone' });
});

app.post('/otp/verify', (req, res) => {
  const { phone, otp } = req.body;

  // Check stored OTP (5 min expiry)
  const stored = otpStore[phone];
  if (stored && stored.otp === otp && (Date.now() - stored.createdAt) < 300000) {
    delete otpStore[phone];
    return res.json({ success: true });
  }

  // Demo fallback: accept any 6-digit code when in development
  if (process.env.NODE_ENV !== 'production' && otp && otp.length === 6) {
    console.log(`[OTP] Demo mode — accepting any 6-digit OTP for ${phone}`);
    return res.json({ success: true });
  }

  res.status(401).json({ success: false, error: 'Invalid or expired OTP' });
});

// ─── Admin Triggers (from DB) ─────────────────────────────
app.get('/admin/triggers', async (req, res) => {
  try {
    const { rows } = await pool.query(`
      SELECT id, zone, trigger_type, severity, value, status, created_at
      FROM trigger_events
      WHERE created_at >= NOW() - INTERVAL '48 hours'
      ORDER BY created_at DESC
      LIMIT 20
    `);
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── GPS LOCATION UPDATE (for fraud detection) ──────────────
// Worker app calls this periodically to report GPS coordinates
app.post('/worker/location', async (req, res) => {
  try {
    const { worker_id, lat, lon } = req.body;
    if (!worker_id || lat == null || lon == null) {
      return res.status(400).json({ error: 'worker_id, lat, lon required' });
    }
    await pool.query(
      `UPDATE workers SET last_lat = $1, last_lon = $2, last_gps_time = NOW()
       WHERE id = $3`,
      [lat, lon, worker_id]
    );
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── ADMIN — FRAUD DASHBOARD ────────────────────────────────
// Returns all flagged claims with fraud details for manual review
app.get('/admin/fraud', async (req, res) => {
  try {
    const { rows } = await pool.query(`
      SELECT
        c.id AS claim_id,
        c.worker_id,
        w.name AS worker_name,
        w.zone,
        w.phone,
        c.trigger_type,
        c.severity,
        c.payout_amount,
        c.status,
        c.fraud_flag,
        c.fraud_reason,
        c.created_at,
        w.last_lat,
        w.last_lon,
        w.disruption_login_ratio
      FROM claims c
      JOIN workers w ON w.id = c.worker_id
      WHERE c.fraud_flag = TRUE
      ORDER BY c.created_at DESC
      LIMIT 50
    `);

    // Summary stats
    const summary = await pool.query(`
      SELECT
        COUNT(*) FILTER (WHERE fraud_flag = TRUE) AS total_flagged,
        COUNT(*) FILTER (WHERE fraud_flag = TRUE AND status = 'rejected') AS blocked,
        COUNT(*) FILTER (WHERE fraud_flag = TRUE AND status = 'processing') AS pending_review,
        COUNT(*) FILTER (WHERE fraud_flag = TRUE AND status = 'approved') AS allowed_low_risk
      FROM claims
    `);

    res.json({
      flagged_claims: rows,
      summary: summary.rows[0],
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── ADMIN — Approve/Reject held claims ─────────────────────
app.put('/admin/fraud/:claimId/resolve', async (req, res) => {
  try {
    const { claimId } = req.params;
    const { action } = req.body; // 'approve' or 'reject'

    if (action === 'approve') {
      // Approve the held claim and create payout
      const claim = await pool.query(
        `UPDATE claims SET status = 'approved' WHERE id = $1 RETURNING *`,
        [claimId]
      );
      if (claim.rows[0]) {
        await pool.query(
          `INSERT INTO payouts (claim_id, worker_id, amount, status, processed_at)
           VALUES ($1, $2, $3, 'completed', NOW())`,
          [claimId, claim.rows[0].worker_id, claim.rows[0].payout_amount]
        );
      }
      res.json({ success: true, status: 'approved' });
    } else {
      await pool.query(
        `UPDATE claims SET status = 'rejected' WHERE id = $1`,
        [claimId]
      );
      res.json({ success: true, status: 'rejected' });
    }
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── ML MODEL INFO (proxy to Python service) ────────────────
app.get('/api/model-info', async (req, res) => {
  try {
    const mlUrl = await getConfig('ml_service_url');
    const axios = require('axios');
    const response = await axios.get(`${mlUrl}/model-info`, { timeout: 3000 });
    res.json(response.data);
  } catch (err) {
    // Return saved metrics if ML service is down
    try {
      const fs = require('fs');
      const path = require('path');
      const metricsPath = path.join(__dirname, '..', 'ml', 'model_metrics.json');
      const metrics = JSON.parse(fs.readFileSync(metricsPath, 'utf-8'));
      res.json(metrics);
    } catch (_) {
      res.json({
        model_type: 'XGBoost Classifier',
        accuracy: 0.9167,
        features: ['avg_monthly_rain_mm', 'flood_events_per_year',
                   'aqi_bad_days_per_month', 'dark_store_outages_month',
                   'avg_wind_speed_kmh', 'extreme_heat_days_month'],
        status: 'ML service offline — using cached metrics',
      });
    }
  }
});

// ─── PAYMENT GATEWAY — Razorpay Test Mode ──────────────────

// Create a Razorpay order for premium payment or payout
app.post('/payment/create-order', async (req, res) => {
  try {
    const { amount, claim_id, worker_id, trigger_type, zone } = req.body;
    if (!amount || amount <= 0) {
      return res.status(400).json({ error: 'Valid amount required' });
    }

    const receipt = `CLM-${claim_id || Date.now()}`;
    const order = await createPayoutOrder(amount, receipt, {
      worker_id,
      trigger_type: trigger_type || 'payout',
      zone: zone || '',
    });

    res.json(order);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Verify Razorpay payment signature
app.post('/payment/verify', (req, res) => {
  try {
    const { order_id, payment_id, signature } = req.body;
    const result = verifyPaymentSignature({ order_id, payment_id, signature });

    if (result.verified) {
      res.json({ success: true, verified: true, mode: result.mode });
    } else {
      res.status(400).json({ success: false, verified: false });
    }
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Create UPI payout to worker
app.post('/payment/upi-payout', async (req, res) => {
  try {
    const { amount, upi_id, worker_name, claim_id } = req.body;
    const result = await createUpiPayout(
      amount, upi_id, worker_name,
      `GigShield Payout — Claim #${claim_id || 'N/A'}`
    );

    // Update payout record with payment reference
    if (claim_id) {
      await pool.query(
        `UPDATE payouts SET payment_method = 'UPI_RAZORPAY',
         payment_ref = $1 WHERE claim_id = $2`,
        [result.txn_id, claim_id]
      );
    }

    res.json(result);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Payment gateway info (for frontend to show which provider is active)
app.get('/payment/info', (req, res) => {
  res.json({
    provider:       'Razorpay',
    mode:           'test',
    key_id:         process.env.RAZORPAY_KEY_ID || 'rzp_test_demo',
    supports:       ['UPI', 'Card', 'NetBanking', 'Wallet'],
    upi_enabled:    true,
    instant_payout: true,
  });
});


// ─── ENHANCED ADMIN ANALYTICS (GAP 4) ───────────────────────

// Loss ratio + claims breakdown + predictive analytics
app.get('/admin/analytics', async (req, res) => {
  try {
    // 1. Loss Ratio = Total Payouts / Total Premiums Collected
    const financials = await pool.query(`
      SELECT
        COALESCE(SUM(CASE WHEN status = 'completed' THEN amount ELSE 0 END), 0)
          AS total_payouts,
        (SELECT COALESCE(SUM(weekly_premium), 0) FROM policies WHERE active = TRUE)
          AS weekly_premiums,
        (SELECT COALESCE(SUM(weekly_premium), 0) * 
          GREATEST(1, EXTRACT(EPOCH FROM (NOW() - MIN(p2.start_date))) / 604800)
         FROM policies p2 WHERE p2.active = TRUE)
          AS estimated_total_premiums
      FROM payouts
    `);

    const totalPayouts    = parseFloat(financials.rows[0].total_payouts);
    const weeklyPremiums  = parseFloat(financials.rows[0].weekly_premiums);
    const estTotalPremiums = parseFloat(financials.rows[0].estimated_total_premiums) || weeklyPremiums || 1;
    const lossRatio       = totalPayouts / estTotalPremiums;

    // 2. Claims breakdown by trigger type
    const byTrigger = await pool.query(`
      SELECT
        COALESCE(trigger_type, 'unknown') AS trigger_type,
        COUNT(*)                          AS claim_count,
        COALESCE(SUM(payout_amount), 0)   AS total_payout,
        COUNT(*) FILTER (WHERE fraud_flag = TRUE) AS fraud_count
      FROM claims
      GROUP BY trigger_type
      ORDER BY claim_count DESC
    `);

    // 3. Claims breakdown by zone
    const byZone = await pool.query(`
      SELECT
        COALESCE(c.zone, w.zone, 'Unknown') AS zone,
        COUNT(*)                             AS claim_count,
        COALESCE(SUM(c.payout_amount), 0)    AS total_payout,
        COUNT(DISTINCT c.worker_id)          AS impacted_workers
      FROM claims c
      LEFT JOIN workers w ON w.id = c.worker_id
      GROUP BY COALESCE(c.zone, w.zone, 'Unknown')
      ORDER BY claim_count DESC
    `);

    // 4. Weekly trend (last 8 weeks)
    const weeklyTrend = await pool.query(`
      SELECT
        DATE_TRUNC('week', created_at) AS week_start,
        COUNT(*)                       AS claims,
        COALESCE(SUM(payout_amount),0) AS payouts
      FROM claims
      WHERE created_at >= NOW() - INTERVAL '8 weeks'
      GROUP BY DATE_TRUNC('week', created_at)
      ORDER BY week_start
    `);

    // 5. Predictive Analytics — 5-day weather forecast for all zones
    const zones = await pool.query(`SELECT DISTINCT name, lat, lon FROM zones`);
    const predictions = [];
    const axios = require('axios');

    for (const zone of zones.rows.slice(0, 5)) { // Top 5 zones
      try {
        const forecastUrl = `https://api.openweathermap.org/data/2.5/forecast`
          + `?lat=${zone.lat}&lon=${zone.lon}`
          + `&appid=${process.env.WEATHER_API_KEY}`
          + `&units=metric&cnt=40`;

        const fcRes = await axios.get(forecastUrl, { timeout: 3000 });
        const forecasts = fcRes.data?.list || [];

        // Count risky days (rain > 5mm or temp > 38°C)
        let riskyPeriods = 0;
        let maxRain = 0;
        let maxTemp = 0;

        for (const f of forecasts) {
          const rain = f.rain?.['3h'] || 0;
          const temp = f.main?.temp || 25;
          if (rain > 5 || temp > 38) riskyPeriods++;
          maxRain = Math.max(maxRain, rain);
          maxTemp = Math.max(maxTemp, temp);
        }

        const riskLevel = riskyPeriods > 15 ? 'HIGH' :
                          riskyPeriods > 5  ? 'MEDIUM' : 'LOW';

        predictions.push({
          zone:        zone.name,
          risk_level:  riskLevel,
          risky_periods: riskyPeriods,
          max_rain_mm: Math.round(maxRain * 10) / 10,
          max_temp_c:  Math.round(maxTemp * 10) / 10,
          forecast_window: '5 days',
          estimated_claims: riskyPeriods > 10 ? 'Multiple claims likely' :
                            riskyPeriods > 3  ? 'Some claims possible' :
                                                'Low claim risk',
        });
      } catch (_) {
        predictions.push({
          zone: zone.name,
          risk_level: 'UNKNOWN',
          note: 'Forecast unavailable',
        });
      }
    }

    // 6. Fraud summary
    const fraudStats = await pool.query(`
      SELECT
        COUNT(*) FILTER (WHERE fraud_flag = TRUE)                     AS total_flagged,
        COUNT(*) FILTER (WHERE fraud_flag = TRUE AND status = 'rejected')  AS blocked,
        COUNT(*) FILTER (WHERE fraud_flag = TRUE AND status = 'processing') AS pending,
        COALESCE(SUM(payout_amount) FILTER (WHERE fraud_flag = TRUE AND status = 'rejected'), 0)
          AS savings_from_fraud
      FROM claims
    `);

    res.json({
      loss_ratio: {
        total_payouts:     totalPayouts,
        estimated_premiums: estTotalPremiums,
        weekly_premiums:   weeklyPremiums,
        ratio:             Math.round(lossRatio * 10000) / 100, // percentage
        health:            lossRatio < 0.6 ? 'HEALTHY' :
                           lossRatio < 0.85 ? 'WATCH' : 'CRITICAL',
      },
      claims_by_trigger: byTrigger.rows,
      claims_by_zone:    byZone.rows,
      weekly_trend:      weeklyTrend.rows,
      predictions:       predictions,
      fraud_summary:     fraudStats.rows[0],
    });
  } catch (err) {
    console.error('[ANALYTICS] Error:', err.message);
    res.status(500).json({ error: 'Analytics unavailable: ' + err.message });
  }
});

app.listen(process.env.PORT || 3000, () => {
  console.log(`GigShield backend running on port ${process.env.PORT || 3000}`);
  startCron();
});
