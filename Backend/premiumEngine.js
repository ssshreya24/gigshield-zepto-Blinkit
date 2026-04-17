// GigShield Premium Engine
// Plans loaded from DB, risk computed via live ML — nothing hardcoded.

const axios = require('axios');
const pool  = require('./db');
const { getZoneFeatures } = require('./zoneService');
const { getConfig } = require('./configService');

// Load plans from plan_types table (fallback to defaults only if DB is down)
async function getPlans() {
  try {
    const { rows } = await pool.query(
      `SELECT plan_key, weekly_premium, max_payout FROM plan_types WHERE is_active = TRUE`
    );
    if (rows.length > 0) {
      const plans = {};
      for (const r of rows) {
        plans[r.plan_key] = { base: r.weekly_premium, maxPayout: r.max_payout };
      }
      return plans;
    }
  } catch (err) {
    console.warn('[PREMIUM] DB plan fetch failed:', err.message);
  }
  // Fallback — should never hit once DB is running
  return {
    basic:    { base: 29, maxPayout: 500  },
    standard: { base: 49, maxPayout: 900  },
    pro:      { base: 79, maxPayout: 1500 },
  };
}

// Get ML-based risk multiplier by dynamically computing zone features
async function getZoneRiskMultiplier(zone) {
  try {
    const features = await getZoneFeatures(zone);
    const mlUrl = await getConfig('ml_service_url');
    const res = await axios.post(`${mlUrl}/predict-risk`, features);
    console.log(`[ML] Zone "${zone}" → risk=${res.data.risk_label}, multiplier=${res.data.premium_multiplier}`, features);
    return {
      multiplier: res.data.premium_multiplier,
      riskLabel:  res.data.risk_label,
      features,
    };
  } catch (err) {
    const fallback = await getConfig('risk_multiplier_fallback');
    console.warn(`ML service unavailable for zone "${zone}", using fallback multiplier ${fallback}`);
    return { multiplier: fallback, riskLabel: 'UNKNOWN', features: null };
  }
}

// Compute dynamic zone score from live conditions
async function getDynamicZoneScore(zone) {
  try {
    const features = await getZoneFeatures(zone);

    const rainScore    = Math.min(Math.round((features.avg_monthly_rain_mm / 300) * 30), 30);
    const floodScore   = Math.min(Math.round((features.flood_events_per_year / 10) * 25), 25);
    const aqiScore     = Math.min(Math.round((features.aqi_bad_days_per_month / 15) * 25), 25);
    const outageScore  = Math.min(Math.round((features.dark_store_outages_month / 5) * 20), 20);

    return rainScore + floodScore + aqiScore + outageScore;
  } catch (err) {
    console.warn(`Dynamic zone score failed for "${zone}", using default 50`);
    return 50;
  }
}

async function calculatePremium(zone, planType, tenureWeeks = 1, weatherRisk = 30) {
  const { multiplier: zoneMultiplier } = await getZoneRiskMultiplier(zone);
  const zoneScore = await getDynamicZoneScore(zone);
  const plans     = await getPlans();
  const plan      = plans[planType] || plans['standard'];

  const zoneAdj    = Math.round((zoneScore / 100) * 20 * zoneMultiplier);
  const weatherAdj = Math.round((weatherRisk / 100) * 15);
  const tenureDisc = tenureWeeks > 8 ? 8 :
                     tenureWeeks > 4 ? 5 : 0;

  const finalPremium = plan.base + zoneAdj + weatherAdj - tenureDisc;

  return {
    zone,
    planType,
    basePremium:    plan.base,
    zoneAdjustment: zoneAdj,
    zoneMultiplier,
    zoneScore,
    weatherRisk:    weatherAdj,
    tenureDiscount: tenureDisc,
    finalPremium,
    maxPayout:      plan.maxPayout,
    riskLevel:      zoneScore > 60 ? 'High' :
                    zoneScore > 40 ? 'Medium' : 'Low',
  };
}

module.exports = { calculatePremium, getZoneRiskMultiplier, getDynamicZoneScore, getPlans };
