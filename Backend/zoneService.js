// GigShield Zone Service
// Dynamically detects and manages zones — no hardcoded zone lists.
// Zone features are computed from live weather APIs + DB history.

const axios = require('axios');
const pool  = require('./db');
require('dotenv').config();

const WEATHER_API_KEY = process.env.WEATHER_API_KEY || process.env.OPENWEATHER_API_KEY;

// Geocode a zone name to lat/lon using OpenWeatherMap Geocoding API
async function geocodeZone(zoneName) {
  try {
    // First check if we already have coords in DB
    const cached = await pool.query(
      `SELECT lat, lon FROM zones WHERE LOWER(name) = LOWER($1)`,
      [zoneName]
    );
    if (cached.rows.length > 0 && cached.rows[0].lat) {
      return { lat: cached.rows[0].lat, lon: cached.rows[0].lon };
    }

    // Geocode via OpenWeatherMap — append ", India" for better accuracy
    const searchQuery = `${zoneName}, India`;
    const url = `https://api.openweathermap.org/geo/1.0/direct?q=${encodeURIComponent(searchQuery)}&limit=1&appid=${WEATHER_API_KEY}`;
    const res = await axios.get(url);

    if (res.data && res.data.length > 0) {
      const { lat, lon } = res.data[0];
      // Cache coords in DB
      await pool.query(
        `UPDATE zones SET lat = $1, lon = $2 WHERE LOWER(name) = LOWER($3)`,
        [lat, lon, zoneName]
      );
      return { lat, lon };
    }

    console.warn(`Could not geocode zone: ${zoneName}, using Bangalore center`);
    return { lat: 12.9716, lon: 77.5946 }; // Bangalore center fallback
  } catch (err) {
    console.error(`Geocoding error for ${zoneName}:`, err.message);
    return { lat: 12.9716, lon: 77.5946 };
  }
}

// Fetch live weather data for a zone
async function getLiveWeather(zoneName) {
  const coords = await geocodeZone(zoneName);

  try {
    const weatherUrl = `https://api.openweathermap.org/data/2.5/weather?lat=${coords.lat}&lon=${coords.lon}&appid=${WEATHER_API_KEY}&units=metric`;
    const weatherRes = await axios.get(weatherUrl);
    const w = weatherRes.data;

    // Also fetch AQI
    const aqiUrl = `https://api.openweathermap.org/data/2.5/air_pollution?lat=${coords.lat}&lon=${coords.lon}&appid=${WEATHER_API_KEY}`;
    const aqiRes = await axios.get(aqiUrl);
    const aqiLevel = aqiRes.data?.list?.[0]?.main?.aqi ?? 1;
    // OWM AQI: 1=Good 2=Fair 3=Moderate 4=Poor 5=VeryPoor
    const aqiMap = { 1: 25, 2: 75, 3: 150, 4: 250, 5: 350 };

    return {
      zone: zoneName,
      coords,
      rainfall:    w.rain?.['1h'] ?? 0,
      temperature: w.main?.temp ?? 25,
      humidity:    w.main?.humidity ?? 50,
      windSpeed:   w.wind?.speed ?? 0,
      weatherId:   w.weather?.[0]?.id ?? 800,
      description: w.weather?.[0]?.description ?? 'clear',
      aqi:         aqiMap[aqiLevel] ?? 25,
    };
  } catch (err) {
    console.error(`Weather fetch failed for ${zoneName}:`, err.message);
    return null;
  }
}

// Compute ML features for a zone dynamically from live data + DB history
async function getZoneFeatures(zoneName) {
  const weather = await getLiveWeather(zoneName);

  // Get historical trigger data from DB
  let floodEvents = 0;
  let aqiBadDays = 0;
  let outages = 0;

  try {
    // Count flood/heavy_rain triggers in the last 365 days
    const floodQuery = await pool.query(
      `SELECT COUNT(*) as cnt FROM trigger_events
       WHERE LOWER(zone) = LOWER($1)
       AND trigger_type IN ('heavy_rain', 'flood_alert')
       AND created_at > NOW() - INTERVAL '365 days'`,
      [zoneName]
    );
    floodEvents = parseInt(floodQuery.rows[0]?.cnt || 0);

    // Count severe AQI days in the last 30 days
    const aqiQuery = await pool.query(
      `SELECT COUNT(DISTINCT DATE(created_at)) as cnt FROM trigger_events
       WHERE LOWER(zone) = LOWER($1)
       AND trigger_type = 'severe_aqi'
       AND created_at > NOW() - INTERVAL '30 days'`,
      [zoneName]
    );
    aqiBadDays = parseInt(aqiQuery.rows[0]?.cnt || 0);

    // Count all disruption events (any trigger) in last 30 days as "outages"
    const outageQuery = await pool.query(
      `SELECT COUNT(*) as cnt FROM trigger_events
       WHERE LOWER(zone) = LOWER($1)
       AND created_at > NOW() - INTERVAL '30 days'`,
      [zoneName]
    );
    outages = parseInt(outageQuery.rows[0]?.cnt || 0);
  } catch (err) {
    console.warn(`DB history fetch failed for ${zoneName}:`, err.message);
  }

  // Compute avg_monthly_rain from live data (extrapolate current hourly rate)
  // rain mm/hr * 24hrs * 30 days — capped at reasonable max
  const currentRainMmHr = weather?.rainfall ?? 0;
  const estimatedMonthlyRain = Math.min(Math.round(currentRainMmHr * 24 * 30), 500);

  // Add AQI-based bad days estimate: if current AQI > 150, assume ~8 bad days/month
  const currentAqi = weather?.aqi ?? 25;
  const estimatedAqiBadDays = aqiBadDays > 0 ? aqiBadDays :
    currentAqi > 300 ? 10 :
    currentAqi > 200 ? 8  :
    currentAqi > 150 ? 5  :
    currentAqi > 100 ? 3  : 1;

  // Wind speed from live weather (km/h)
  const windSpeedKmh = weather?.windSpeed ?? 10;

  // Extreme heat days: count from DB or estimate from current temp
  let extremeHeatDays = 0;
  try {
    const heatQuery = await pool.query(
      `SELECT COUNT(DISTINCT DATE(created_at)) as cnt FROM trigger_events
       WHERE LOWER(zone) = LOWER($1)
       AND trigger_type = 'extreme_heat'
       AND created_at > NOW() - INTERVAL '30 days'`,
      [zoneName]
    );
    extremeHeatDays = parseInt(heatQuery.rows[0]?.cnt || 0);
  } catch (_) {}
  // Estimate from current temperature if no DB data
  const currentTemp = weather?.temperature ?? 25;
  if (extremeHeatDays === 0) {
    extremeHeatDays = currentTemp > 42 ? 10 :
                      currentTemp > 38 ? 6  :
                      currentTemp > 35 ? 3  : 1;
  }

  return {
    avg_monthly_rain_mm:      estimatedMonthlyRain > 0 ? estimatedMonthlyRain : (floodEvents > 0 ? 120 : 50),
    flood_events_per_year:    floodEvents,
    aqi_bad_days_per_month:   estimatedAqiBadDays,
    dark_store_outages_month: outages,
    avg_wind_speed_kmh:       windSpeedKmh,
    extreme_heat_days_month:  extremeHeatDays,
  };
}

// Get all active zones from DB (auto-detected from worker registrations)
async function getAllZones() {
  try {
    const result = await pool.query(
      `SELECT DISTINCT z.name, z.lat, z.lon
       FROM zones z
       ORDER BY z.name`
    );
    return result.rows;
  } catch (err) {
    console.error('Failed to fetch zones from DB:', err.message);
    return [];
  }
}

// Ensure a zone exists in zones table (called on worker registration)
async function ensureZoneExists(zoneName) {
  try {
    const existing = await pool.query(
      `SELECT id FROM zones WHERE LOWER(name) = LOWER($1)`,
      [zoneName]
    );

    if (existing.rows.length === 0) {
      // New zone — geocode it and insert
      const coords = await geocodeZone(zoneName);
      await pool.query(
        `INSERT INTO zones (name, lat, lon) VALUES ($1, $2, $3)
         ON CONFLICT (name) DO NOTHING`,
        [zoneName, coords.lat, coords.lon]
      );
      console.log(`[ZONE] Auto-detected new zone: ${zoneName} (${coords.lat}, ${coords.lon})`);
    }
  } catch (err) {
    console.error(`Failed to ensure zone ${zoneName}:`, err.message);
  }
}

// Sync zones table from existing workers (run once on startup)
async function syncZonesFromWorkers() {
  try {
    const workers = await pool.query(
      `SELECT DISTINCT zone FROM workers WHERE zone IS NOT NULL`
    );

    for (const row of workers.rows) {
      await ensureZoneExists(row.zone);
    }

    console.log(`[ZONE] Synced ${workers.rows.length} zones from workers table`);
  } catch (err) {
    console.error('Zone sync failed:', err.message);
  }
}

module.exports = {
  geocodeZone,
  getLiveWeather,
  getZoneFeatures,
  getAllZones,
  ensureZoneExists,
  syncZonesFromWorkers,
};
