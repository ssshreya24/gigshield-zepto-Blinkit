// GigShield Config Service
// All business thresholds & settings loaded from DB — nothing hardcoded.

const pool = require('./db');
require('dotenv').config();

// In-memory cache — refreshed from DB every 5 minutes
let _cache = null;
let _lastFetch = 0;
const CACHE_TTL_MS = 5 * 60 * 1000; // 5 minutes

// Default config — used ONLY as initial DB seed or if DB is down
const DEFAULTS = {
  // Trigger thresholds
  rain_threshold_mm:        10,
  flood_threshold_mm:       50,
  heat_threshold_c:         40,
  aqi_threshold:            200,
  wind_threshold_kmh:       60,
  rain_trigger_t3_mm:       50,
  heat_trigger_t2_c:        45,
  aqi_trigger_t3:           300,
  wind_trigger_t3_kmh:      90,

  // Weather trigger (weatherTrigger.js)
  weather_rain_threshold:   7.5,
  weather_flood_code_min:   900,
  weather_flood_code_max:   910,

  // Payout percentages
  payout_t1_pct:            0.25,
  payout_t2_pct:            0.50,
  payout_t3_pct:            1.00,

  // Fraud detection
  fraud_claims_per_week:    3,
  fraud_login_ratio:        0.8,

  // Income loss calculation
  income_loss_expected_pct: 0.75,
  income_loss_actual_pct:   0.10,

  // ML service
  ml_service_url:           process.env.ML_SERVICE_URL || 'http://localhost:8001',

  // Cron interval (minutes)
  cron_interval_minutes:    30,

  // Dedup window (hours)
  trigger_dedup_hours:      2,

  // Risk multiplier fallback (when ML is down)
  risk_multiplier_fallback: 1.2,
};

// Load config from DB
async function loadConfig() {
  const now = Date.now();
  if (_cache && (now - _lastFetch) < CACHE_TTL_MS) {
    return _cache;
  }

  try {
    const { rows } = await pool.query(
      `SELECT key, value FROM app_config`
    );

    const config = { ...DEFAULTS };
    for (const row of rows) {
      // Parse numeric values
      const num = parseFloat(row.value);
      config[row.key] = isNaN(num) ? row.value : num;
    }

    _cache = config;
    _lastFetch = now;
    return config;
  } catch (err) {
    console.warn('[CONFIG] DB load failed, using defaults:', err.message);
    _cache = { ...DEFAULTS };
    _lastFetch = now;
    return _cache;
  }
}

// Get a single config value
async function getConfig(key) {
  const config = await loadConfig();
  return config[key] ?? DEFAULTS[key];
}

// Get payout map { T1: 0.25, T2: 0.50, T3: 1.00 }
async function getPayoutMap() {
  const config = await loadConfig();
  return {
    T1: config.payout_t1_pct,
    T2: config.payout_t2_pct,
    T3: config.payout_t3_pct,
  };
}

// Get all trigger thresholds
async function getTriggerThresholds() {
  const config = await loadConfig();
  return {
    rain_mm:       config.rain_threshold_mm,
    flood_mm:      config.flood_threshold_mm,
    heat_c:        config.heat_threshold_c,
    aqi:           config.aqi_threshold,
    wind_kmh:      config.wind_threshold_kmh,
    rain_t3_mm:    config.rain_trigger_t3_mm,
    heat_t2_c:     config.heat_trigger_t2_c,
    aqi_t3:        config.aqi_trigger_t3,
    wind_t3_kmh:   config.wind_trigger_t3_kmh,
    weather_rain:  config.weather_rain_threshold,
    flood_code_min: config.weather_flood_code_min,
    flood_code_max: config.weather_flood_code_max,
  };
}

// Force refresh cache
function invalidateCache() {
  _cache = null;
  _lastFetch = 0;
}

module.exports = {
  loadConfig,
  getConfig,
  getPayoutMap,
  getTriggerThresholds,
  invalidateCache,
  DEFAULTS,
};
