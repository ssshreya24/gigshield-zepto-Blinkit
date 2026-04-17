CREATE TABLE IF NOT EXISTS premium_payments (
  id             SERIAL PRIMARY KEY,
  worker_id      INTEGER REFERENCES workers(id) ON DELETE CASCADE,
  policy_id      INTEGER REFERENCES policies(id) ON DELETE CASCADE,
  amount         INTEGER NOT NULL,
  payment_method VARCHAR(20) DEFAULT 'UPI',
  upi_id         VARCHAR(100),
  status         VARCHAR(20) DEFAULT 'completed',
  created_at     TIMESTAMP DEFAULT NOW()
);
