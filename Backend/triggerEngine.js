const axios  = require('axios');
const cron   = require('node-cron');
const pool   = require('./db');
const { checkWeatherTriggers } = require('./weatherTrigger');
const { getAllZones, geocodeZone, syncZonesFromWorkers } = require('./zoneService');
const { getTriggerThresholds, getPayoutMap, getConfig } = require('./configService');
require('dotenv').config();

// ── Fetch real weather for one zone ──────────────────────
async function checkWeather(zone) {
  try {
    const lat = zone.lat;
    const lon = zone.lon;

    if (!lat || !lon) {
      const coords = await geocodeZone(zone.name);
      zone.lat = coords.lat;
      zone.lon = coords.lon;
    }

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
      aqi:         0,
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
    const aqiMap = { 1: 25, 2: 75, 3: 150, 4: 250, 5: 350 };
    return aqiMap[aqi] ?? 0;
  } catch (err) {
    return 0;
  }
}

// ── Evaluate triggers using DB-configured thresholds ─────
async function evaluateTriggers(weatherData) {
  const triggers = [];
  const zone     = weatherData.zone;
  const th       = await getTriggerThresholds();

  // 1. Heavy Rain
  if (weatherData.rainfall > th.rain_mm) {
    triggers.push({
      zone,
      trigger_type: 'heavy_rain',
      severity:     weatherData.rainfall > th.rain_t3_mm ? 'T3' : 'T2',
      value:        weatherData.rainfall,
      unit:         'mm/hr',
    });
    console.log(`  [TRIGGER] Heavy Rain in ${zone}: ${weatherData.rainfall}mm`);
  }

  // 2. Extreme Heat
  if (weatherData.temperature > th.heat_c) {
    triggers.push({
      zone,
      trigger_type: 'extreme_heat',
      severity:     weatherData.temperature > th.heat_t2_c ? 'T2' : 'T1',
      value:        weatherData.temperature,
      unit:         'celsius',
    });
    console.log(`  [TRIGGER] Extreme Heat in ${zone}: ${weatherData.temperature}°C`);
  }

  // 3. Severe AQI
  if (weatherData.aqi > th.aqi) {
    triggers.push({
      zone,
      trigger_type: 'severe_aqi',
      severity:     weatherData.aqi > th.aqi_t3 ? 'T3' : 'T2',
      value:        weatherData.aqi,
      unit:         'AQI',
    });
    console.log(`  [TRIGGER] Severe AQI in ${zone}: ${weatherData.aqi}`);
  }

  // 4. Storm / High Wind
  if (weatherData.windSpeed > th.wind_kmh) {
    triggers.push({
      zone,
      trigger_type: 'storm',
      severity:     weatherData.windSpeed > th.wind_t3_kmh ? 'T3' : 'T2',
      value:        weatherData.windSpeed,
      unit:         'km/h',
    });
    console.log(`  [TRIGGER] Storm in ${zone}: ${weatherData.windSpeed}km/h wind`);
  }

  // 5. Flood
  if (weatherData.rainfall > th.flood_mm) {
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
    const dedupHours = await getConfig('trigger_dedup_hours');

    const existing = await pool.query(
      `SELECT id FROM trigger_events
       WHERE zone = $1
       AND trigger_type = $2
       AND created_at > NOW() - INTERVAL '${dedupHours} hours'
       AND status = 'active'`,
      [trigger.zone, trigger.trigger_type]
    );

    if (existing.rows.length > 0) {
      console.log(`  [SKIP] ${trigger.trigger_type} in ${trigger.zone} already active`);
      return;
    }

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

    await fireClaimsForZone(triggerId, trigger);

  } catch (err) {
    console.error('Error saving trigger:', err.message);
  }
}

// ── Auto-create claims for workers in zone ───────────────
// Delegates to claimPipeline.js which handles 4-layer fraud detection
async function fireClaimsForZone(triggerId, trigger) {
  try {
    const { processClaimsForTrigger } = require('./claimPipeline');
    await processClaimsForTrigger(
      triggerId,
      trigger.zone,
      trigger.severity,
      trigger.trigger_type  // passes trigger type for weather cross-verification
    );
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

  const zones = await getAllZones();

  if (zones.length === 0) {
    console.log('[WEATHER CHECK] No zones found in DB. Register workers to auto-detect zones.');
    return;
  }

  console.log(`[WEATHER CHECK] Monitoring ${zones.length} zones: ${zones.map(z => z.name).join(', ')}`);

  for (const zone of zones) {
    const result = await checkWeatherTriggers(zone.name);
    for (const trigger of result.triggers) {
      console.log(`REAL TRIGGER: ${trigger.type} in ${zone.name}`);
      await saveTriggerAndFireClaims({
        zone: zone.name,
        trigger_type: trigger.type,
        severity: trigger.severity,
        value: trigger.value,
      });
    }
  }

  for (const zone of zones) {
    const weather = await checkWeather(zone);
    if (!weather) continue;

    weather.aqi = await checkAQI(zone);

    console.log(`  ${zone.name}: ${weather.temperature}°C, rain:${weather.rainfall}mm, AQI:${weather.aqi}`);

    const triggers = await evaluateTriggers(weather);
    for (const trigger of triggers) {
      await saveTriggerAndFireClaims(trigger);
    }
  }
  console.log('[WEATHER CHECK] Done.\n');
}

// ── Start cron job ────────────────────────────────────────
async function startCron() {
  console.log('[CRON] Weather trigger engine started');

  await syncZonesFromWorkers();

  runWeatherCheck();

  const interval = await getConfig('cron_interval_minutes');
  console.log(`[CRON] Checking every ${interval} minutes`);

  cron.schedule(`*/${interval} * * * *`, () => {
    runWeatherCheck();
  });
}

module.exports = { fireTrigger, startCron, checkWeather, runWeatherCheck };
