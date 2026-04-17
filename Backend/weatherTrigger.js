// GigShield Weather Trigger
// Thresholds loaded from configService — nothing hardcoded.

const { getLiveWeather } = require('./zoneService');
const { getTriggerThresholds } = require('./configService');

async function checkWeatherTriggers(zoneName) {
  try {
    const weather = await getLiveWeather(zoneName);
    if (!weather) {
      return { zone: zoneName, triggers: [], error: 'Weather data unavailable' };
    }

    const rain      = weather.rainfall;
    const temp      = weather.temperature;
    const weatherId = weather.weatherId;
    const triggers  = [];

    // Load thresholds from DB config
    const th = await getTriggerThresholds();

    if (rain > th.weather_rain) {
      triggers.push({ type: 'HEAVY_RAIN', severity: 'T2', value: rain, unit: 'mm/hr' });
    }
    if (weatherId >= th.flood_code_min && weatherId < th.flood_code_max) {
      triggers.push({ type: 'FLOOD_ALERT', severity: 'T3', value: weatherId });
    }
    if (temp > th.heat_c) {
      triggers.push({ type: 'EXTREME_HEAT', severity: 'T1', value: temp, unit: 'C' });
    }

    return { zone: zoneName, triggers, raw: { rain, temp } };
  } catch (err) {
    console.error('Weather Trigger error:', err.message);
    return { zone: zoneName, triggers: [], error: err.message };
  }
}

module.exports = { checkWeatherTriggers };
