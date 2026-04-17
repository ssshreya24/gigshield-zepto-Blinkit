// ═══════════════════════════════════════════════════════════════
// mlClient.js — Insurify ML Service Client
// Drop this into Backend/ folder and require it in server.js
//
// Usage:
//   const ml = require('./mlClient');
//   const risk   = await ml.predictRisk({ zone, plan_type, tenure_weeks });
//   const income = await ml.predictIncome({ avg_daily_income, zone, ... });
//   const fraud  = await ml.predictFraud({ worker_id, claims_this_week, ... });
//   const next   = await ml.predictNextWeek({ zone });
// ═══════════════════════════════════════════════════════════════

const axios = require('axios');

// Your deployed ML service URL — update after Render deploy
const ML_URL = process.env.ML_SERVICE_URL || 'https://insurify-ml.onrender.com';

// Timeout — Render free tier cold starts take ~15s
const TIMEOUT = 20000;

// ── Fallback values when ML service is down ────────────────────
const FALLBACKS = {
  risk: (zone, plan_type) => {
    const riskMap = { 'Koramangala': 72, 'HSR Layout': 65, 'Marathahalli': 55 };
    const baseMap = { basic: 29, standard: 49, pro: 79 };
    const payMap  = { basic: 500, standard: 900, pro: 1500 };
    const score   = riskMap[zone] || 50;
    return {
      risk_score: score,
      risk_level: score > 60 ? 'HIGH' : score > 35 ? 'MEDIUM' : 'LOW',
      max_payout: payMap[plan_type] || 900,
      premium: {
        base: baseMap[plan_type] || 49,
        zone_adjustment: Math.round(score / 100 * 20),
        weather_adjustment: 5,
        tenure_discount: 0,
        final: (baseMap[plan_type] || 49) + Math.round(score / 100 * 20) + 5,
      },
      top_risk_factors: [],
      model: 'fallback'
    };
  },
  income: (avg_daily) => ({
    expected_income: Math.round(avg_daily * 0.9),
    actual_income:   0,
    income_loss:     Math.round(avg_daily * 0.9),
    loss_percentage: 90,
    confidence:      0.75,
    model: 'fallback'
  }),
  fraud: () => ({
    fraud_probability: 0.05,
    fraud_level: 'LOW',
    action: 'APPROVE',
    allow_payout: true,
    reason_codes: [],
    model: 'fallback'
  }),
};

// ── Generic POST helper ────────────────────────────────────────
async function mlPost(endpoint, body) {
  try {
    const res = await axios.post(`${ML_URL}${endpoint}`, body, {
      timeout: TIMEOUT,
      headers: { 'Content-Type': 'application/json' },
    });
    return res.data;
  } catch (err) {
    console.error(`[ML] ${endpoint} failed:`, err.message);
    return null;
  }
}

// ── Risk prediction ────────────────────────────────────────────
async function predictRisk({ zone, plan_type, tenure_weeks = 1, rainfall_7d = 0, temp_avg = 28, aqi_avg = 100 }) {
  const result = await mlPost('/predict/risk', {
    zone, plan_type, tenure_weeks, rainfall_7d, temp_avg, aqi_avg,
    season: getCurrentSeason(),
  });
  return result || FALLBACKS.risk(zone, plan_type);
}

// ── Income prediction ──────────────────────────────────────────
async function predictIncome({ avg_daily_income, zone, platform = 'Zepto', tenure_weeks = 1, rainfall = 0, temperature = 28, aqi = 100 }) {
  const result = await mlPost('/predict/income', {
    avg_daily_income, zone, platform, tenure_weeks,
    day_of_week: new Date().getDay(),
    hours_worked: 8,
    rainfall, temperature, aqi,
  });
  return result || FALLBACKS.income(avg_daily_income);
}

// ── Fraud detection ────────────────────────────────────────────
async function predictFraud({ worker_id, claims_this_week, days_since_signup, gps_distance_jump_km = 0, trigger_overlap_count = 0, income_ratio = 1.0 }) {
  const result = await mlPost('/predict/fraud', {
    worker_id, claims_this_week, days_since_signup,
    avg_claim_interval: claims_this_week > 0 ? 7 / claims_this_week : 7,
    login_before_trigger_minutes: 60,
    gps_distance_jump_km,
    trigger_overlap_count,
    income_ratio,
  });
  return result || FALLBACKS.fraud();
}

// ── Next-week forecast ─────────────────────────────────────────
async function predictNextWeek({ zone }) {
  const result = await mlPost('/predict/next-week', { zone, week_offset: 1 });
  return result || {
    zone,
    predicted_risk: 50,
    risk_level: 'MEDIUM',
    trigger_forecasts: [],
    expected_claims: 10,
    expected_payout_inr: 7500,
    model: 'fallback',
  };
}

// ── Health check ───────────────────────────────────────────────
async function checkHealth() {
  try {
    const res = await axios.get(`${ML_URL}/health`, { timeout: 5000 });
    return res.data;
  } catch {
    return { status: 'unreachable', model: 'fallback' };
  }
}

// ── Utility ───────────────────────────────────────────────────
function getCurrentSeason() {
  const m = new Date().getMonth() + 1;
  if ([12, 1, 2].includes(m)) return 0;  // winter
  if ([3, 4, 5].includes(m))  return 1;  // summer
  if ([6, 7, 8, 9].includes(m)) return 2; // monsoon
  return 3;                               // autumn
}

module.exports = { predictRisk, predictIncome, predictFraud, predictNextWeek, checkHealth };
