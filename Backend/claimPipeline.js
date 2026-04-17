const pool = require('./db');
const { getPayoutMap, getConfig } = require('./configService');
const { getLiveWeather, geocodeZone } = require('./zoneService');

// ─── Haversine distance (km) — for GPS spoofing detection ──────
function haversineKm(lat1, lon1, lat2, lon2) {
  const R = 6371; // Earth radius in km
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = Math.sin(dLat / 2) ** 2 +
            Math.cos(lat1 * Math.PI / 180) *
            Math.cos(lat2 * Math.PI / 180) *
            Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

async function processClaimsForTrigger(triggerId, zone, severity, triggerType) {
  console.log(`Processing claims for trigger ${triggerId} in ${zone} (${severity})`);

  const workers = await pool.query(
    `SELECT w.id, w.avg_daily_income, w.disruption_login_ratio,
            w.last_lat, w.last_lon, w.last_gps_time,
            p.max_payout, p.plan_type, p.id as policy_id
     FROM workers w
     JOIN policies p ON p.worker_id = w.id
     WHERE w.zone = $1 AND p.active = TRUE`,
    [zone]
  );

  console.log(`Found ${workers.rows.length} active workers in ${zone}`);

  // Load all thresholds from config (not hardcoded)
  const payoutMap       = await getPayoutMap();
  const fraudClaimLimit = await getConfig('fraud_claims_per_week');
  const fraudLoginRatio = await getConfig('fraud_login_ratio');
  const expectedPct     = await getConfig('income_loss_expected_pct');
  const actualPct       = await getConfig('income_loss_actual_pct');

  // ─── Layer 1: Weather Cross-Verification ─────────────────────
  // Verify that actual weather conditions match the trigger type
  let weatherVerified = true;
  let weatherNote = '';
  try {
    const liveWeather = await getLiveWeather(zone);
    if (liveWeather) {
      const rainThreshold  = parseFloat(await getConfig('weather_rain_threshold') || 5);
      const heatThresholdC = parseFloat(await getConfig('heat_threshold_c') || 40);
      const aqiThreshold   = parseFloat(await getConfig('aqi_threshold') || 200);

      switch (triggerType) {
        case 'heavy_rain':
          if (liveWeather.rainfall < rainThreshold * 0.5) {
            weatherVerified = false;
            weatherNote = `Weather API shows ${liveWeather.rainfall}mm rain vs trigger threshold ${rainThreshold}mm`;
          }
          break;
        case 'extreme_heat':
          if (liveWeather.temperature < heatThresholdC - 5) {
            weatherVerified = false;
            weatherNote = `Weather API shows ${liveWeather.temperature}°C vs trigger threshold ${heatThresholdC}°C`;
          }
          break;
        case 'severe_aqi':
          if (liveWeather.aqi < aqiThreshold * 0.5) {
            weatherVerified = false;
            weatherNote = `Weather API shows AQI ${liveWeather.aqi} vs trigger threshold ${aqiThreshold}`;
          }
          break;
        case 'flood_alert':
          // Floods are event-based — trust the trigger source
          weatherVerified = true;
          break;
      }
    }
  } catch (err) {
    console.warn(`Weather cross-check failed for ${zone}: ${err.message}`);
    // On API failure, proceed with claim (don't penalize worker for API issues)
    weatherVerified = true;
  }

  if (!weatherVerified) {
    console.log(`[FRAUD-WEATHER] Weather cross-check FAILED for ${zone}: ${weatherNote}`);
  }

  // Get zone coordinates for GPS distance check
  let zoneCoords = null;
  try {
    zoneCoords = await geocodeZone(zone);
  } catch (_) {}

  for (const worker of workers.rows) {

    // Fraud check — duplicate claim for same trigger
    const dup = await pool.query(
      `SELECT id FROM claims WHERE worker_id=$1 AND trigger_id=$2`,
      [worker.id, triggerId]
    );
    if (dup.rows.length > 0) {
      console.log(`Duplicate claim blocked for worker ${worker.id}`);
      continue;
    }

    // ─── MULTI-LAYER FRAUD DETECTION ─────────────────────────
    let fraudFlag = false;
    let fraudReason = '';
    let suspicionLevel = 'LOW';
    const fraudFlags = []; // Collect all flags

    // Layer 2: Behavioral Analysis — excessive claims
    const behaviorQuery = await pool.query(`
      SELECT 
        COUNT(*) FILTER (WHERE created_at > NOW() - INTERVAL '7 days') as claims_this_week,
        COUNT(*) FILTER (WHERE created_at > NOW() - INTERVAL '24 hours') as claims_today
      FROM claims 
      WHERE worker_id = $1
    `, [worker.id]);

    const claimsThisWeek = parseInt(behaviorQuery.rows[0]?.claims_this_week || 0);
    const claimsToday    = parseInt(behaviorQuery.rows[0]?.claims_today || 0);
    const loginRatio     = parseFloat(worker.disruption_login_ratio || 0);

    if (claimsThisWeek >= fraudClaimLimit) {
      fraudFlags.push(`Excessive claims this week (${claimsThisWeek} >= ${fraudClaimLimit})`);
      suspicionLevel = 'HIGH';
    }

    if (claimsToday >= 2) {
      fraudFlags.push(`Multiple claims today (${claimsToday})`);
      suspicionLevel = suspicionLevel === 'HIGH' ? 'HIGH' : 'MEDIUM';
    }

    if (loginRatio > fraudLoginRatio) {
      fraudFlags.push('Login pattern matches disruption-only behavior');
      suspicionLevel = suspicionLevel === 'HIGH' ? 'HIGH' : 'MEDIUM';
    }

    // Layer 3: GPS Spoofing Detection — distance from zone center
    if (worker.last_lat && worker.last_lon && zoneCoords) {
      const distKm = haversineKm(
        worker.last_lat, worker.last_lon,
        zoneCoords.lat, zoneCoords.lon
      );
      const GPS_MAX_DISTANCE_KM = 5; // Worker should be within 5km of zone center

      if (distKm > GPS_MAX_DISTANCE_KM) {
        fraudFlags.push(`GPS location ${distKm.toFixed(1)}km from zone (max ${GPS_MAX_DISTANCE_KM}km)`);
        suspicionLevel = 'HIGH';
      }

      // GPS teleportation check: if last GPS update was <60 seconds ago
      // and distance is >5km, it's a spoofing attempt
      if (worker.last_gps_time) {
        const gpsAge = (Date.now() - new Date(worker.last_gps_time).getTime()) / 1000;
        if (gpsAge < 60 && distKm > GPS_MAX_DISTANCE_KM) {
          fraudFlags.push(`GPS teleported ${distKm.toFixed(1)}km in ${Math.round(gpsAge)}s — spoofing detected`);
          suspicionLevel = 'HIGH';
        }
      }
    }

    // Layer 4: Weather cross-check result
    if (!weatherVerified) {
      fraudFlags.push(`Weather cross-check failed: ${weatherNote}`);
      suspicionLevel = suspicionLevel === 'LOW' ? 'MEDIUM' : suspicionLevel;
    }

    // Compile fraud result
    if (fraudFlags.length > 0) {
      fraudFlag = true;
      fraudReason = fraudFlags.join(' | ');
    }

    if (fraudFlag) {
      console.log(`[FRAUD] Worker ${worker.id}: ${fraudReason} (${suspicionLevel})`);
    }

    // ─── FRAUD RESPONSE TIERS ────────────────────────────────
    // HIGH   → Block: reject claim entirely
    // MEDIUM → Delay: create claim in 'manual_review' status
    // LOW    → Allow: auto-approve immediately
    let claimStatus = 'approved';

    if (suspicionLevel === 'HIGH') {
      console.log(`[FRAUD-BLOCK] Worker ${worker.id}: Claim REJECTED — ${fraudReason}`);

      // Insert rejected claim for audit trail
      await pool.query(
        `INSERT INTO claims
           (worker_id, policy_id, trigger_id, trigger_event_id, trigger_type, zone, severity,
            expected_income, actual_income, payout_amount, status, fraud_flag, fraud_reason)
         VALUES ($1,$2,$3,$3,$4,$5,$6,$7,$8,0,'rejected',TRUE,$9)`,
        [worker.id, worker.policy_id, triggerId, triggerType || 'unknown', zone, severity,
         Math.round(worker.avg_daily_income * expectedPct),
         Math.round(worker.avg_daily_income * expectedPct * actualPct),
         fraudReason]
      );
      continue; // Skip payout
    }

    if (suspicionLevel === 'MEDIUM') {
      claimStatus = 'processing'; // Held for manual review
      console.log(`[FRAUD-HOLD] Worker ${worker.id}: Claim held for review — ${fraudReason}`);
    }

    // Income loss calculation (from config, not hardcoded)
    const expectedIncome = Math.round(worker.avg_daily_income * expectedPct);
    const actualIncome   = Math.round(expectedIncome * actualPct);
    const payoutPercent  = payoutMap[severity] || payoutMap['T1'];
    const payoutAmount   = Math.round(worker.max_payout * payoutPercent);

    // Insert claim
    const claim = await pool.query(
      `INSERT INTO claims
         (worker_id, policy_id, trigger_id, trigger_event_id, trigger_type, zone, severity,
          expected_income, actual_income, payout_amount, status, fraud_flag, fraud_reason)
       VALUES ($1,$2,$3,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12) RETURNING id`,
      [worker.id, worker.policy_id, triggerId, triggerType || 'unknown', zone, severity,
       expectedIncome, actualIncome, payoutAmount, claimStatus, fraudFlag,
       fraudReason || null]
    );

    // Only create payout if approved (not if held for review)
    if (claimStatus === 'approved') {
      await pool.query(
        `INSERT INTO payouts (claim_id, worker_id, amount, status, processed_at)
         VALUES ($1,$2,$3,'completed', NOW())`,
        [claim.rows[0].id, worker.id, payoutAmount]
      );
      console.log(`Payout Rs.${payoutAmount} approved for worker ${worker.id}`);
    } else {
      console.log(`Claim Rs.${payoutAmount} held for manual review — worker ${worker.id}`);
    }
  }
}

module.exports = { processClaimsForTrigger };
