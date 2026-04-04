// GigShield Premium Engine
// This is your AI risk model — zone scores are your "trained" values

const ZONE_RISK = {
  'Koramangala': 72,
  'Indiranagar':  45,
  'Whitefield':   30,
  'HSR Layout':   65,
  'Marathahalli': 55,
  'Bellandur':    48,
  'Default':      50,
};

const PLANS = {
  basic:    { base: 29, maxPayout: 500  },
  standard: { base: 49, maxPayout: 900  },
  pro:      { base: 79, maxPayout: 1500 },
};

function calculatePremium(zone, planType, tenureWeeks = 1, weatherRisk = 30) {
  const zoneScore  = ZONE_RISK[zone] || ZONE_RISK['Default'];
  const plan       = PLANS[planType] || PLANS['standard'];

  const zoneAdj    = Math.round((zoneScore / 100) * 20);
  const weatherAdj = Math.round((weatherRisk / 100) * 15);
  const tenureDisc = tenureWeeks > 8 ? 8 :
                     tenureWeeks > 4 ? 5 : 0;

  const finalPremium = plan.base + zoneAdj + weatherAdj - tenureDisc;

  return {
    zone,
    planType,
    basePremium:    plan.base,
    zoneAdjustment: zoneAdj,
    weatherRisk:    weatherAdj,
    tenureDiscount: tenureDisc,
    finalPremium,
    maxPayout:      plan.maxPayout,
    riskLevel:      zoneScore > 60 ? 'High' :
                    zoneScore > 40 ? 'Medium' : 'Low',
  };
}

module.exports = { calculatePremium, PLANS, ZONE_RISK };
