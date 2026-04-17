const { Pool } = require('pg');
const pool = new Pool({ connectionString: 'postgres://postgres:postgres@localhost:5432/gigshield' });
pool.query(`CREATE TABLE IF NOT EXISTS support_queries(id SERIAL PRIMARY KEY, worker_id INTEGER REFERENCES workers(id) ON DELETE CASCADE, message TEXT NOT NULL, status VARCHAR(20) DEFAULT 'open', created_at TIMESTAMP DEFAULT NOW());`)
  .then(() => { console.log('Done'); process.exit(0); })
  .catch(console.error);
