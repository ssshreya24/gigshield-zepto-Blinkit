const axios  = require('axios');
const cron   = require('node-cron');
const pool   = require('./db');
require('dotenv').config();

const ZONES = [
  { name: 'Koramangala', lat: 12.9352, lon: 77.6245 },
  { name: 'Indiranagar',  lat: 12.9784, lon: 77.6408 },
  { name: 'Whitefield',   lat: 12.9698, lon: 77.7500 },
  { name: 'HSR Layout',   lat: 12.9116, lon: 77.6389 },
  { name: 'Marathahalli', lat: 12.9591, lon: 77.6974 },
  { name: 'Kothrud',      lat: 18.5074, lon: 73.8077 },
  { name: 'Baner',        lat: 18.5590, lon: 73.7868 },
  { name: 'Bellandur',    lat: 12.9259, lon: 77.6762 },
  { name: 'Jayanagar',    lat: 12.9308, lon: 77.5839 },
  { name: 'Andheri',      lat: 19.1136, lon: 72.8697 },
];

// ── Fetch real weather for one zone ──────────────────────
async function checkWeather(zone) {
  try {
    const url = `https://api.openweathermap.org/data/2.5/weather`
      + `?lat=${zone.lat}&lon=${zone.lon}`
      + `&appid=${process.env.WEATHER_API_KEY}`
      + `&units=metric`;

    const res  = await axios.get(url);
    const data = res.data;

    return {
      zone:        zone.name,
      rainfall:    data.rain?.['1h'] ?? 0,
      temperature: data.main?.temp   ?? 25,
      humidity:    data.main?.humidity ?? 50,
      windSpeed:   data.wind?.speed  ?? 0,
      description: data.weather?.[0]?.description ?? '',
      aqi:         0, // AQI needs separate API call below
    };
  } catch (err) {
    console.error(`Weather check failed for ${zone.name}:`, err.message);
    return null;
  }
}

// ── Fetch AQI for one zone ────────────────────────────────
async function checkAQI(zone) {
  try {
    const url = `https://api.openweathermap.org/data/2.5/air_pollution`
      + `?lat=${zone.lat}&lon=${zone.lon}`
      + `&appid=${process.env.WEATHER_API_KEY}`;

    const res  = await axios.get(url);
    const aqi  = res.data?.list?.[0]?.main?.aqi ?? 0;
    // OWM AQI: 1=Good 2=Fair 3=Moderate 4=Poor 5=VeryPoor
    // Convert to standard AQI scale approx
    const aqiMap = { 1: 25, 2: 75, 3: 150, 4: 250, 5: 350 };
    return aqiMap[aqi] ?? 0;
  } catch (err) {
    return 0;
  }
}

// ── Evaluate which triggers should fire ──────────────────
async function evaluateTriggers(weatherData) {
  const triggers = [];
  const zone     = weatherData.zone;

  // 1. Heavy Rain → rainfall > 10mm/hour
  if (weatherData.rainfall > 10) {
    triggers.push({
      zone,
      trigger_type: 'heavy_rain',
      severity:     weatherData.rainfall > 50 ? 'T3' : 'T2',
      value:        weatherData.rainfall,
      unit:         'mm/hr',
    });
    console.log(`  [TRIGGER] Heavy Rain in ${zone}: ${weatherData.rainfall}mm`);
  }

  // 2. Extreme Heat → temperature > 40°C
  if (weatherData.temperature > 40) {
    triggers.push({
      zone,
      trigger_type: 'extreme_heat',
      severity:     weatherData.temperature > 45 ? 'T2' : 'T1',
      value:        weatherData.temperature,
      unit:         'celsius',
    });
    console.log(`  [TRIGGER] Extreme Heat in ${zone}: ${weatherData.temperature}°C`);
  }

  // 3. Severe AQI → aqi > 200
  if (weatherData.aqi > 200) {
    triggers.push({
      zone,
      trigger_type: 'severe_aqi',
      severity:     weatherData.aqi > 300 ? 'T3' : 'T2',
      value:        weatherData.aqi,
      unit:         'AQI',
    });
    console.log(`  [TRIGGER] Severe AQI in ${zone}: ${weatherData.aqi}`);
  }

  // 4. Storm / High Wind → windSpeed > 60 km/h
  if (weatherData.windSpeed > 60) {
    triggers.push({
      zone,
      trigger_type: 'storm',
      severity:     weatherData.windSpeed > 90 ? 'T3' : 'T2',
      value:        weatherData.windSpeed,
      unit:         'km/h',
    });
    console.log(`  [TRIGGER] Storm in ${zone}: ${weatherData.windSpeed}km/h wind`);
  }

  // 5. Flood → rainfall > 50mm (heavy flooding threshold)
  if (weatherData.rainfall > 50) {
    triggers.push({
      zone,
      trigger_type: 'flood_alert',
      severity:     'T3',
      value:        weatherData.rainfall,
      unit:         'mm/hr',
    });
    console.log(`  [TRIGGER] Flood Alert in ${zone}: ${weatherData.rainfall}mm`);
  }

  return triggers;
}

// ── Save trigger to DB + auto-fire claims ────────────────
async function saveTriggerAndFireClaims(trigger) {
  try {
    // Check if same trigger already fired in last 2 hours
    const existing = await pool.query(
      `SELECT id FROM trigger_events
       WHERE zone = $1
       AND trigger_type = $2
       AND created_at > NOW() - INTERVAL '2 hours'
       AND status = 'active'`,
      [trigger.zone, trigger.trigger_type]
    );

    if (existing.rows.length > 0) {
      console.log(`  [SKIP] ${trigger.trigger_type} in ${trigger.zone} already active`);
      return;
    }

    // Save to DB
    const result = await pool.query(
      `INSERT INTO trigger_events
         (zone, trigger_type, severity, value, status)
       VALUES ($1, $2, $3, $4, 'active')
       RETURNING id`,
      [trigger.zone, trigger.trigger_type,
       trigger.severity, trigger.value]
    );

    const triggerId = result.rows[0].id;
    console.log(`  [SAVED] Trigger ${triggerId}: ${trigger.trigger_type} in ${trigger.zone}`);

    // Auto-fire claims for all workers in this zone
    await fireClaimsForZone(triggerId, trigger);

  } catch (err) {
    console.error('Error saving trigger:', err.message);
  }
}

// ── Auto-create claims for workers in zone ───────────────
async function fireClaimsForZone(triggerId, trigger) {
  try {
    // Get all workers with active policies in this zone
    const workers = await pool.query(
      `SELECT w.id as worker_id, w.name,
              p.id as policy_id, p.max_payout, p.plan_type
       FROM workers w
       JOIN policies p ON p.worker_id = w.id
       WHERE w.zone = $1 AND p.active = TRUE`,
      [trigger.zone]
    );

    console.log(`  [CLAIMS] Firing for ${workers.rows.length} workers in ${trigger.zone}`);

    // Payout % based on severity
    const pctMap = { 'T1': 0.25, 'T2': 0.50, 'T3': 1.00 };
    const pct    = pctMap[trigger.severity] ?? 0.50;

    for (const worker of workers.rows) {

      // Fraud check — no duplicate claim in last 24h
      const dupe = await pool.query(
        `SELECT id FROM claims
         WHERE worker_id = $1
         AND trigger_type = $2
         AND created_at > NOW() - INTERVAL '24 hours'`,
        [worker.worker_id, trigger.trigger_type]
      );

      if (dupe.rows.length > 0) {
        console.log(`  [FRAUD] Duplicate claim blocked for worker ${worker.worker_id}`);
        continue;
      }

      const payoutAmt = Math.round(worker.max_payout * pct);

      // Create claim
      const claim = await pool.query(
        `INSERT INTO claims
           (worker_id, policy_id, trigger_event_id,
            trigger_type, zone, severity,
            expected_income, actual_income, payout_amount,
            status, fraud_flag, created_at)
         VALUES ($1, $2, $3, $4, $5, $6,
                 $7, $8, $9, 'approved', false)
         RETURNING id`,
        [
          worker.worker_id, worker.policy_id, triggerId,
          trigger.trigger_type, trigger.zone, trigger.severity,
          800, 0, payoutAmt
        ]
      );

      const claimId = claim.rows[0].id;

      // Create payout record
      await pool.query(
        `INSERT INTO payouts
           (claim_id, worker_id, amount,
            payment_method, status)
         VALUES ($1, $2, $3, 'UPI', 'completed')`,
        [claimId, worker.worker_id, payoutAmt]
      );

      console.log(`  [PAYOUT] Worker ${worker.name}: ₹${payoutAmt} → ${trigger.trigger_type}`);
    }
  } catch (err) {
    console.error('Error firing claims:', err.message);
  }
}

// ── Manual trigger fire (for demo/admin) ─────────────────
async function fireTrigger({ zone, type, severity, value }) {
  const trigger = {
    zone,
    trigger_type: type,
    severity:     severity ?? 'T2',
    value:        value    ?? 60,
  };
  await saveTriggerAndFireClaims(trigger);
  return trigger;
}

// ── Main weather check loop ───────────────────────────────
async function runWeatherCheck() {
  console.log('\n[WEATHER CHECK] Starting...', new Date().toISOString());
  for (const zone of ZONES) {
    const weather = await checkWeather(zone);
    if (!weather) continue;

    // Also fetch AQI
    weather.aqi = await checkAQI(zone);

    console.log(`  ${zone.name}: ${weather.temperature}°C, rain:${weather.rainfall}mm, AQI:${weather.aqi}`);

    const triggers = await evaluateTriggers(weather);
    for (const trigger of triggers) {
      await saveTriggerAndFireClaims(trigger);
    }
  }
  console.log('[WEATHER CHECK] Done.\n');
}

// ── Start cron job — runs every 30 minutes ────────────────
function startCron() {
  console.log('[CRON] Weather trigger engine started');
  console.log('[CRON] Checking every 30 minutes');

  // Run immediately on startup
  runWeatherCheck();

  // Then every 30 minutes
  cron.schedule('*/30 * * * *', () => {
    runWeatherCheck();
  });
}

module.exports = { fireTrigger, startCron, checkWeather, runWeatherCheck };
