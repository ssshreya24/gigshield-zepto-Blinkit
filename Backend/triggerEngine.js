// ═══════════════════════════════════════════════════════════════
// triggerEngine.js — FULLY DYNAMIC GPS-BASED VERSION
// NO fixed zones — fetches weather for every worker's actual location
// Works anywhere in India automatically
// ═══════════════════════════════════════════════════════════════

const axios = require('axios');
const cron  = require('node-cron');
const pool  = require('./db');
require('dotenv').config();

const WEATHER_API_KEY = process.env.WEATHER_API_KEY;

// ── Reverse geocode lat/lon → area name using OpenWeatherMap ──
async function getAreaName(lat, lon) {
  try {
    const url = `https://api.openweathermap.org/geo/1.0/reverse`
      + `?lat=${lat}&lon=${lon}&limit=1&appid=${WEATHER_API_KEY}`;
    const res  = await axios.get(url, { timeout: 5000 });
    const data = res.data;
    if (data && data.length > 0) {
      // Returns suburb/area name if available, else city name
      return data[0].name || data[0].state || 'Unknown Area';
    }
    return `Zone_${lat.toFixed(2)}_${lon.toFixed(2)}`;
  } catch {
    return `Zone_${lat.toFixed(2)}_${lon.toFixed(2)}`;
  }
}

// ── Fetch real weather for any lat/lon ────────────────────────
async function checkWeather(lat, lon, zoneName) {
  try {
    const url = `https://api.openweathermap.org/data/2.5/weather`
      + `?lat=${lat}&lon=${lon}`
      + `&appid=${WEATHER_API_KEY}`
      + `&units=metric`;

    const res  = await axios.get(url, { timeout: 8000 });
    const data = res.data;

    return {
      zone:        zoneName,
      lat,
      lon,
      rainfall:    data.rain?.['1h'] ?? 0,
      temperature: data.main?.temp   ?? 25,
      humidity:    data.main?.humidity ?? 50,
      windSpeed:   data.wind?.speed  ?? 0,
      description: data.weather?.[0]?.description ?? '',
      aqi:         0,
    };
  } catch (err) {
    console.error(`Weather check failed for ${zoneName}:`, err.message);
    return null;
  }
}

// ── Fetch AQI for any lat/lon ─────────────────────────────────
async function checkAQI(lat, lon) {
  try {
    const url = `https://api.openweathermap.org/data/2.5/air_pollution`
      + `?lat=${lat}&lon=${lon}`
      + `&appid=${WEATHER_API_KEY}`;
    const res  = await axios.get(url, { timeout: 5000 });
    const aqi  = res.data?.list?.[0]?.main?.aqi ?? 0;
    const aqiMap = { 1: 25, 2: 75, 3: 150, 4: 250, 5: 350 };
    return aqiMap[aqi] ?? 0;
  } catch {
    return 0;
  }
}

const ml = require('./mlClient');

// In-memory state tracking to evaluate SAFE/DANGER states
const durationState = {};

// ── Evaluate triggers from weather data ───────────────────────
async function evaluateTriggers(weatherData) {
  const triggers = [];
  const zone     = weatherData.zone;
  
  if (!durationState[zone]) durationState[zone] = {};

  // Fetch lowest active thresholds dynamically (CRUD synced)
  const ptRows = await pool.query(`SELECT plan_key, thresholds_json FROM plan_types WHERE is_active=TRUE`);
  
  // Set safety defaults in case DB is being updated or empty
  let min_rain = 10, min_temp = 40, min_aqi = 200, min_storm = 60;
  
  if (ptRows.rows.length > 0) {
    let found_rain = 999, found_temp = 999, found_aqi = 9999, found_storm = 999;
    let anyValid = false;
    
    for (const p of ptRows.rows) {
      const th = p.thresholds_json || {};
      if (th.rain_mm != null) { found_rain = Math.min(found_rain, th.rain_mm); anyValid = true; }
      if (th.temp_c != null)  { found_temp = Math.min(found_temp, th.temp_c);   anyValid = true; }
      if (th.aqi != null)     { found_aqi  = Math.min(found_aqi, th.aqi);     anyValid = true; }
      if (th.storm_kmh != null){ found_storm = Math.min(found_storm, th.storm_kmh); anyValid = true; }
    }
    
    if (anyValid) {
       min_rain = found_rain; min_temp = found_temp; min_aqi = found_aqi; min_storm = found_storm;
    }
  }
  
  // DEBUG LOG
  console.log(`[TRIGGER DEBUG] Zone detection thresholds: Rain >= ${min_rain}, Temp >= ${min_temp}, AQI >= ${min_aqi}`);

  const conditions = {
    heavy_rain:   { met: weatherData.rainfall >= min_rain,   sev: weatherData.rainfall > min_rain + 20 ? 'T3' : 'T2', val: weatherData.rainfall },
    extreme_heat: { met: weatherData.temperature >= min_temp,sev: weatherData.temperature > min_temp + 2 ? 'T2' : 'T1', val: weatherData.temperature },
    severe_aqi:   { met: weatherData.aqi >= min_aqi,         sev: weatherData.aqi > min_aqi + 100 ? 'T3' : 'T2', val: weatherData.aqi },
    storm:        { met: weatherData.windSpeed >= min_storm, sev: weatherData.windSpeed > min_storm + 20 ? 'T3' : 'T2', val: weatherData.windSpeed }
  };

  for (const [type, state] of Object.entries(conditions)) {
    if (!durationState[zone][type]) durationState[zone][type] = { isDanger: false, lastFired: 0, lastEventId: null };
    const tracker = durationState[zone][type];

    if (state.met) {
      let shouldFireNew = false;
      if (!tracker.isDanger) {
        tracker.isDanger = true;
        tracker.lastFired = Date.now();
        shouldFireNew = true;
      } else {
        const hoursPassed = (Date.now() - tracker.lastFired) / (1000 * 60 * 60);
        if (hoursPassed > 24) {
          tracker.lastFired = Date.now();
          shouldFireNew = true;
        } else {
          console.log(`[COOLDOWN] ${zone}:${type} staying in danger, ${Math.round(24 - hoursPassed)}h remaining before repeat.`);
        }
      }

      // Always return the trigger info if it's danger, so we can re-check workers
      triggers.push({ 
        zone, 
        trigger_type: type, 
        severity: state.sev, 
        value: state.val, 
        isNew: shouldFireNew,
        existingId: tracker.lastEventId 
      });
    } else {
      if (tracker.isDanger) {
        console.log(`[RESET] ${zone}:${type} returned to SAFE state.`);
        tracker.isDanger = false;
        tracker.lastEventId = null;
      }
    }
  }

  return triggers;
}

// ── Save trigger + fire claims ────────────────────────────────
async function saveTriggerAndFireClaims(trigger, weatherData) {
  try {
    let triggerId = trigger.existingId;
    
    if (trigger.isNew || !triggerId) {
      const result = await pool.query(
        `INSERT INTO trigger_events (zone, trigger_type, severity, value, status)
         VALUES ($1,$2,$3,$4,'active') RETURNING id`,
        [trigger.zone, trigger.trigger_type, trigger.severity, trigger.value]
      );
      triggerId = result.rows[0].id;
      
      // Update the tracker so we don't insert again for 24h
      if (durationState[trigger.zone] && durationState[trigger.zone][trigger.trigger_type]) {
        durationState[trigger.zone][trigger.trigger_type].lastEventId = triggerId;
      }
      
      console.log(`  [SAVED] Trigger ${triggerId}: ${trigger.trigger_type} in ${trigger.zone}`);
    } else {
      // Zone is in cooldown danger state - just re-run claims for potential late joiners
      console.log(`  [RE-CHECK] Re-validating workers for active trigger ${triggerId} in ${trigger.zone}`);
    }
    
    await fireClaimsForZone(triggerId, trigger, weatherData);
  } catch (err) { console.error('Error saving trigger:', err.message); }
}

// ── Fire claims for all workers in a zone ────────────────────
async function fireClaimsForZone(triggerId, trigger, weatherData) {
  try {
    const workers = await pool.query(
      `SELECT w.id as worker_id, w.name, w.avg_daily_income, w.platform,
              p.id as policy_id, p.max_payout, p.plan_type,
              w.created_at as signup_date
       FROM workers w
       JOIN policies p ON p.worker_id = w.id
       WHERE w.zone = $1 AND p.active = TRUE`,
      [trigger.zone]
    );
    console.log(`  [CLAIMS] Processing ${workers.rows.length} workers in ${trigger.zone}`);

    const pctMap = { T1: 0.25, T2: 0.50, T3: 1.00 };
    const pct    = pctMap[trigger.severity] ?? 0.50;

    const ptRows = await pool.query(`SELECT plan_key, triggers_json, thresholds_json FROM plan_types WHERE is_active=TRUE`);
    const planConfig = {};
    for (const r of ptRows.rows) {
      planConfig[r.plan_key] = { triggers: r.triggers_json || [], thresholds: r.thresholds_json || {} };
    }

    for (const worker of workers.rows) {
      const workerPlan = (worker.plan_type || 'basic').toLowerCase();
      const planContext = planConfig[workerPlan] || { triggers: [], thresholds: {} };

      // Ensure the worker's plan covers this trigger
      if (!planContext.triggers.includes(trigger.trigger_type)) {
        console.log(`  [SKIP] ${worker.name} plan doesn't cover ${trigger.trigger_type}`);
        continue;
      }

      // Ensure the weather exactly crosses this specific worker's plan threshold
      let reqTh = 999;
      if (trigger.trigger_type === 'heavy_rain') reqTh = planContext.thresholds.rain_mm || 999;
      if (trigger.trigger_type === 'extreme_heat') reqTh = planContext.thresholds.temp_c || 999;
      if (trigger.trigger_type === 'severe_aqi') reqTh = planContext.thresholds.aqi || 9999;
      if (trigger.trigger_type === 'storm') reqTh = planContext.thresholds.storm_kmh || 999;

      if (trigger.value < reqTh) {
        console.log(`  [SKIP THRESHOLD] ${worker.name}: value ${trigger.value} missed plan requirement ${reqTh}`);
        continue;
      }
      // Date utility
      const signupDays = Math.floor((new Date() - new Date(worker.signup_date)) / (1000 * 60 * 60 * 24));
      
      // Dupe constraint: only fire once per trigger-type per 24 hours per worker!
      const dupe = await pool.query(
        `SELECT id FROM claims
         WHERE worker_id=$1 AND trigger_type=$2
         AND created_at > NOW() - INTERVAL '24 hours'`,
        [worker.worker_id, trigger.trigger_type]
      );
      if (dupe.rows.length > 0) continue;

      // Duplicate interval generic count
      const totalClaims = await pool.query(`SELECT count(id) FROM claims WHERE worker_id=$1`, [worker.worker_id]);
      const claimsThisWeek = parseInt(totalClaims.rows[0].count);

      // Gate 3: ML predicts income loss > 30%?
      const incomeAnalysis = await ml.predictIncome({
        avg_daily_income: worker.avg_daily_income,
        zone: trigger.zone,
        platform: worker.platform,
        rainfall: weatherData?.rainfall || 0,
        temperature: weatherData?.temperature || 25,
        aqi: weatherData?.aqi || 50,
      });

      if (incomeAnalysis.loss_percentage < 30) {
        console.log(`  [SKIP Gate 3] ${worker.name}: Income loss only ${Math.round(incomeAnalysis.loss_percentage)}%`);
        continue;
      }

      // Gate 4b: ML Fraud Check
      const fraudAnalysis = await ml.predictFraud({
        worker_id: worker.worker_id,
        claims_this_week: claimsThisWeek,
        days_since_signup: signupDays,
        gps_distance_jump_km: 0,
        trigger_overlap_count: 0,
        income_ratio: 1.0
      });

      if (!fraudAnalysis.allow_payout) {
        console.log(`  [SKIP Gate 4] ${worker.name}: Fraud check failed -> ${fraudAnalysis.fraud_level}`);
        continue;
      }

      const payoutAmt = Math.round(worker.max_payout * pct);
      const claim = await pool.query(
        `INSERT INTO claims
           (worker_id, policy_id, trigger_event_id,
            trigger_type, zone, severity,
            expected_income, actual_income, payout_amount,
            status, fraud_flag)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,'approved',false) RETURNING id`,
        [worker.worker_id, worker.policy_id, triggerId,
         trigger.trigger_type, trigger.zone, trigger.severity,
         worker.avg_daily_income, incomeAnalysis.actual_income || 0, payoutAmt]
      );
      await pool.query(
        `INSERT INTO payouts
           (claim_id, worker_id, amount, payment_method, status)
         VALUES ($1,$2,$3,'UPI','completed')`,
        [claim.rows[0].id, worker.worker_id, payoutAmt]
      );
      console.log(`  [PAYOUT] ${worker.name}: ₹${payoutAmt} -> ALL 4 GATES PASSED`);
    }
  } catch (err) {
    console.error('Error firing claims:', err.message);
  }
}

// ── MAIN: fetch all active worker locations from DB ───────────
async function runWeatherCheck() {
  console.log('\n[WEATHER CHECK] Starting...', new Date().toISOString());

  try {
    // Get all unique GPS locations from active workers
    const result = await pool.query(
      `SELECT DISTINCT
         w.zone,
         w.latitude,
         w.longitude
       FROM workers w
       JOIN policies p ON p.worker_id = w.id
       WHERE p.active = TRUE
       AND w.latitude IS NOT NULL
       AND w.longitude IS NOT NULL`
    );

    let locations = result.rows;

    if (locations.length === 0) {
      console.log('[WEATHER] No GPS data found, using static zone geocoding fallback...');
      const zones = await pool.query(`SELECT DISTINCT zone FROM workers WHERE zone IS NOT NULL`);
      for (const row of zones.rows) await checkByZoneName(row.zone);
      return;
    }

    const seen = new Set();
    for (const loc of locations) {
      const key = loc.zone;
      if (seen.has(key)) continue;
      seen.add(key);

      const areaName = loc.zone || await getAreaName(loc.latitude, loc.longitude);
      const weather  = await checkWeather(loc.latitude, loc.longitude, areaName);
      if (!weather) continue;

      weather.aqi = await checkAQI(loc.latitude, loc.longitude);
      console.log(`  ${areaName}: ${weather.temperature}°C, rain:${weather.rainfall}mm`);

      const triggers = await evaluateTriggers(weather);
      for (const trigger of triggers) {
        await saveTriggerAndFireClaims(trigger, weather);
      }
    }

  } catch (err) {
    console.error('[WEATHER CHECK ERROR]', err.message);
    // Fallback: check a few major cities if DB query fails
    await checkFallbackCities();
  }

  console.log('[WEATHER CHECK] Done.\n');
}

// ── Fallback: geocode a zone name to coordinates ──────────────
async function checkByZoneName(zoneName) {
  try {
    const url = `https://api.openweathermap.org/geo/1.0/direct`
      + `?q=${encodeURIComponent(zoneName + ',IN')}`
      + `&limit=1&appid=${WEATHER_API_KEY}`;
    const res = await axios.get(url, { timeout: 5000 });
    if (!res.data || res.data.length === 0) return;

    const { lat, lon } = res.data[0];
    const weather = await checkWeather(lat, lon, zoneName);
    if (!weather) return;

    weather.aqi = await checkAQI(lat, lon);
    console.log(`  ${zoneName}: ${weather.temperature}°C, rain:${weather.rainfall}mm`);

    const triggers = await evaluateTriggers(weather);
    for (const trigger of triggers) {
      await saveTriggerAndFireClaims(trigger);
    }
  } catch (err) {
    console.error(`Zone geocode failed for ${zoneName}:`, err.message);
  }
}

// ── Fallback cities if everything else fails ──────────────────
async function checkFallbackCities() {
  const cities = [
    { name: 'Bangalore', lat: 12.9716, lon: 77.5946 },
    { name: 'Mumbai',    lat: 19.0760, lon: 72.8777 },
    { name: 'Delhi',     lat: 28.6139, lon: 77.2090 },
    { name: 'Chennai',   lat: 13.0827, lon: 80.2707 },
    { name: 'Hyderabad', lat: 17.3850, lon: 78.4867 },
  ];
  for (const city of cities) {
    const weather = await checkWeather(city.lat, city.lon, city.name);
    if (!weather) continue;
    weather.aqi = await checkAQI(city.lat, city.lon);
    const triggers = await evaluateTriggers(weather);
    for (const trigger of triggers) {
      await saveTriggerAndFireClaims(trigger);
    }
  }
}

// ── Manual trigger fire ───────────────────────────────────────
async function fireTrigger({ zone, type, severity, value }) {
  const trigger = { zone, trigger_type: type, severity: severity ?? 'T2', value: value ?? 60 };
  await saveTriggerAndFireClaims(trigger);
  return trigger;
}

// ── Start cron — every 10 seconds for real-time simulation ────────
function startCron() {
  console.log('[CRON] Dynamic GPS weather engine started (10s interval)');
  runWeatherCheck();
  // Using interval for sub-minute precision if needed, but node-cron supports it
  cron.schedule('*/10 * * * * *', runWeatherCheck); 
}

module.exports = { fireTrigger, startCron, checkWeather, runWeatherCheck, checkAQI, getAreaName, durationState };
