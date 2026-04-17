-- GigShield Database Schema
-- Auto runs when Docker starts for the first time

CREATE TABLE IF NOT EXISTS workers (
  id        SERIAL PRIMARY KEY,
  name      VARCHAR(100)  NOT NULL,
  phone     VARCHAR(15)   UNIQUE NOT NULL,
  zone      VARCHAR(50)   NOT NULL,
  platform  VARCHAR(50)   NOT NULL,
  avg_daily_income INTEGER NOT NULL,
  tenure_weeks     INTEGER DEFAULT 1,
  disruption_login_ratio FLOAT DEFAULT 0,
  last_lat         DOUBLE PRECISION,
  last_lon         DOUBLE PRECISION,
  last_gps_time    TIMESTAMP,
  created_at       TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS policies (
  id             SERIAL PRIMARY KEY,
  worker_id      INTEGER REFERENCES workers(id) ON DELETE CASCADE,
  plan_type      VARCHAR(20) NOT NULL CHECK (plan_type IN ('basic','standard','pro')),
  weekly_premium INTEGER NOT NULL,
  max_payout     INTEGER NOT NULL,
  start_date     DATE NOT NULL,
  end_date       DATE NOT NULL,
  active         BOOLEAN DEFAULT TRUE,
  created_at     TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS trigger_events (
  id           SERIAL PRIMARY KEY,
  zone         VARCHAR(50) NOT NULL,
  trigger_type VARCHAR(50) NOT NULL,
  severity     VARCHAR(5)  NOT NULL CHECK (severity IN ('T1','T2','T3')),
  value        NUMERIC,
  status       VARCHAR(20) DEFAULT 'active',
  detected_at  TIMESTAMP DEFAULT NOW(),
  created_at   TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS claims (
  id              SERIAL PRIMARY KEY,
  worker_id       INTEGER REFERENCES workers(id),
  policy_id       INTEGER REFERENCES policies(id),
  trigger_id      INTEGER REFERENCES trigger_events(id),
  trigger_event_id INTEGER REFERENCES trigger_events(id),
  trigger_type    VARCHAR(50),
  zone            VARCHAR(50),
  severity        VARCHAR(5),
  expected_income INTEGER NOT NULL DEFAULT 0,
  actual_income   INTEGER NOT NULL DEFAULT 0,
  payout_amount   INTEGER NOT NULL DEFAULT 0,
  status          VARCHAR(20) DEFAULT 'processing'
                  CHECK (status IN ('processing','approved','rejected','paid')),
  fraud_flag      BOOLEAN DEFAULT FALSE,
  fraud_reason    VARCHAR(500),
  created_at      TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS payouts (
  id             SERIAL PRIMARY KEY,
  claim_id       INTEGER REFERENCES claims(id),
  worker_id      INTEGER REFERENCES workers(id),
  amount         INTEGER NOT NULL,
  method         VARCHAR(20) DEFAULT 'UPI',
  payment_method VARCHAR(30) DEFAULT 'UPI',
  payment_ref    VARCHAR(100),
  status         VARCHAR(20) DEFAULT 'pending'
                 CHECK (status IN ('pending','completed','failed')),
  processed_at   TIMESTAMP,
  created_at     TIMESTAMP DEFAULT NOW()
);

-- Dynamic zones table — auto-populated from worker registrations
CREATE TABLE IF NOT EXISTS zones (
  id         SERIAL PRIMARY KEY,
  name       VARCHAR(100) UNIQUE NOT NULL,
  lat        DOUBLE PRECISION,
  lon        DOUBLE PRECISION,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Indexes for fast queries
CREATE INDEX IF NOT EXISTS idx_workers_zone     ON workers(zone);
CREATE INDEX IF NOT EXISTS idx_policies_worker  ON policies(worker_id);
CREATE INDEX IF NOT EXISTS idx_claims_worker    ON claims(worker_id);
CREATE INDEX IF NOT EXISTS idx_claims_trigger   ON claims(trigger_id);
CREATE INDEX IF NOT EXISTS idx_trigger_zone     ON trigger_events(zone);
CREATE INDEX IF NOT EXISTS idx_zones_name       ON zones(name);

-- App config table — all business thresholds (replaces hardcoded values)
CREATE TABLE IF NOT EXISTS app_config (
  key        VARCHAR(100) PRIMARY KEY,
  value      VARCHAR(500) NOT NULL,
  category   VARCHAR(50)  DEFAULT 'general',
  label      VARCHAR(200),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Seed config values (trigger thresholds, payout %, fraud limits, etc.)
INSERT INTO app_config (key, value, category, label) VALUES
  -- Trigger thresholds
  ('rain_threshold_mm',        '10',    'triggers', 'Heavy rain threshold (mm/hr)'),
  ('flood_threshold_mm',       '50',    'triggers', 'Flood alert threshold (mm/hr)'),
  ('heat_threshold_c',         '40',    'triggers', 'Extreme heat threshold (°C)'),
  ('aqi_threshold',            '200',   'triggers', 'Severe AQI threshold'),
  ('wind_threshold_kmh',       '60',    'triggers', 'Storm wind threshold (km/h)'),
  ('rain_trigger_t3_mm',       '50',    'triggers', 'Rain T3 severity threshold (mm)'),
  ('heat_trigger_t2_c',        '45',    'triggers', 'Heat T2 severity threshold (°C)'),
  ('aqi_trigger_t3',           '300',   'triggers', 'AQI T3 severity threshold'),
  ('wind_trigger_t3_kmh',      '90',    'triggers', 'Wind T3 severity threshold (km/h)'),
  ('weather_rain_threshold',   '7.5',   'triggers', 'Weather check rain threshold (mm)'),
  ('weather_flood_code_min',   '900',   'triggers', 'OWM flood weather code min'),
  ('weather_flood_code_max',   '910',   'triggers', 'OWM flood weather code max'),
  -- Payout %
  ('payout_t1_pct',            '0.25',  'payouts',  'T1 payout percentage'),
  ('payout_t2_pct',            '0.50',  'payouts',  'T2 payout percentage'),
  ('payout_t3_pct',            '1.00',  'payouts',  'T3 payout percentage'),
  -- Fraud
  ('fraud_claims_per_week',    '3',     'fraud',    'Max claims per week before fraud flag'),
  ('fraud_login_ratio',        '0.8',   'fraud',    'Suspicious login ratio threshold'),
  ('income_loss_expected_pct', '0.75',  'fraud',    'Expected income loss percentage'),
  ('income_loss_actual_pct',   '0.10',  'fraud',    'Actual income during disruption percentage'),
  -- ML
  ('ml_service_url',           'http://localhost:8001', 'ml', 'ML prediction service URL'),
  ('risk_multiplier_fallback', '1.2',   'ml',       'Fallback risk multiplier when ML is down'),
  -- Cron
  ('cron_interval_minutes',    '30',    'cron',     'Weather check interval (minutes)'),
  ('trigger_dedup_hours',      '2',     'cron',     'Trigger deduplication window (hours)')
ON CONFLICT (key) DO NOTHING;

-- Seed test workers
INSERT INTO workers (name, phone, zone, platform, avg_daily_income) VALUES
  ('Ravi Kumar',  '9999999901', 'Koramangala', 'Zepto',   800),
  ('Priya Sharma','9999999902', 'Indiranagar',  'Blinkit', 950),
  ('Arjun Singh', '9999999903', 'Whitefield',   'Zepto',   750)
ON CONFLICT (phone) DO NOTHING;

INSERT INTO policies (worker_id, plan_type, weekly_premium, max_payout, start_date, end_date) VALUES
  (1, 'standard', 76, 900,  CURRENT_DATE, CURRENT_DATE + 7),
  (2, 'pro',      95, 1500, CURRENT_DATE, CURRENT_DATE + 7),
  (3, 'basic',    52, 500,  CURRENT_DATE, CURRENT_DATE + 7)
ON CONFLICT DO NOTHING;

-- Auto-seed zones from workers (dynamic — no hardcoded zone list)
INSERT INTO zones (name)
  SELECT DISTINCT zone FROM workers WHERE zone IS NOT NULL
ON CONFLICT (name) DO NOTHING;

-- PLAN TYPES TABLE
CREATE TABLE IF NOT EXISTS plan_types (
  id             SERIAL PRIMARY KEY,
  name           VARCHAR(50) NOT NULL,
  plan_key       VARCHAR(20) NOT NULL UNIQUE,
  weekly_premium INT NOT NULL DEFAULT 49,
  max_payout     INT NOT NULL DEFAULT 900,
  triggers_json  JSONB DEFAULT '[]',
  is_active      BOOLEAN DEFAULT TRUE,
  created_at     TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO plan_types (name, plan_key, weekly_premium, max_payout, triggers_json)
VALUES
  ('Basic',    'basic',    29, 500,  '["heavy_rain","extreme_heat"]'),
  ('Standard', 'standard', 49, 900,  '["heavy_rain","extreme_heat","flood_alert","severe_aqi"]'),
  ('Pro',      'pro',      79, 1500, '["heavy_rain","extreme_heat","flood_alert","severe_aqi","curfew","cyclone"]')
ON CONFLICT (plan_key) DO NOTHING;