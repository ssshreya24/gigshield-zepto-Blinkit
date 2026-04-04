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
  fraud_reason    VARCHAR(200),
  created_at      TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS payouts (
  id             SERIAL PRIMARY KEY,
  claim_id       INTEGER REFERENCES claims(id),
  worker_id      INTEGER REFERENCES workers(id),
  amount         INTEGER NOT NULL,
  method         VARCHAR(20) DEFAULT 'UPI',
  payment_method VARCHAR(20) DEFAULT 'UPI',
  status         VARCHAR(20) DEFAULT 'pending'
                 CHECK (status IN ('pending','completed','failed')),
  processed_at   TIMESTAMP,
  created_at     TIMESTAMP DEFAULT NOW()
);

-- Indexes for fast queries
CREATE INDEX IF NOT EXISTS idx_workers_zone     ON workers(zone);
CREATE INDEX IF NOT EXISTS idx_policies_worker  ON policies(worker_id);
CREATE INDEX IF NOT EXISTS idx_claims_worker    ON claims(worker_id);
CREATE INDEX IF NOT EXISTS idx_claims_trigger   ON claims(trigger_id);
CREATE INDEX IF NOT EXISTS idx_trigger_zone     ON trigger_events(zone);

-- Seed mock zone data for testing
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

-- PLAN TYPES TABLE (NEW)

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

-- DEFAULT DATA

INSERT INTO plan_types (name, plan_key, weekly_premium, max_payout, triggers_json)
VALUES
  ('Basic',    'basic',    29, 500,  '["heavy_rain","extreme_heat"]'),
  ('Standard', 'standard', 49, 900,  '["heavy_rain","extreme_heat","flood_alert","severe_aqi"]'),
  ('Pro',      'pro',      79, 1500, '["heavy_rain","extreme_heat","flood_alert","severe_aqi","curfew","cyclone"]')
ON CONFLICT (plan_key) DO NOTHING;