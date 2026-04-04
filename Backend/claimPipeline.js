const pool = require('./db');

const PAYOUT_PERCENT = { T1: 0.25, T2: 0.50, T3: 1.00 };

async function processClaimsForTrigger(triggerId, zone, severity) {
  console.log(`Processing claims for trigger ${triggerId} in ${zone} (${severity})`);

  const workers = await pool.query(
    `SELECT w.id, w.avg_daily_income, p.max_payout
     FROM workers w
     JOIN policies p ON p.worker_id = w.id
     WHERE w.zone = $1 AND p.active = TRUE`,
    [zone]
  );

  console.log(`Found ${workers.rows.length} active workers in ${zone}`);

  for (const worker of workers.rows) {

    // Fraud check — duplicate claim for same trigger
    const dup = await pool.query(
      `SELECT id FROM claims WHERE worker_id=$1 AND trigger_id=$2`,
      [worker.id, triggerId]
    );
    if (dup.rows.length > 0) {
      console.log(`Duplicate claim blocked for worker ${worker.id}`);
      continue;
    }

    // Income loss calculation
    const expectedIncome = Math.round(worker.avg_daily_income * 0.75);
    const actualIncome   = Math.round(expectedIncome * 0.1);
    const payoutPercent  = PAYOUT_PERCENT[severity] || 0.25;
    const payoutAmount   = Math.round(worker.max_payout * payoutPercent);

    // Insert claim
    const claim = await pool.query(
      `INSERT INTO claims
         (worker_id, trigger_id, expected_income, actual_income, payout_amount, status)
       VALUES ($1,$2,$3,$4,$5,'approved') RETURNING id`,
      [worker.id, triggerId, expectedIncome, actualIncome, payoutAmount]
    );

    // Insert payout
    await pool.query(
      `INSERT INTO payouts (claim_id, amount, status, processed_at)
       VALUES ($1,$2,'completed', NOW())`,
      [claim.rows[0].id, payoutAmount]
    );

    console.log(`Payout Rs.${payoutAmount} approved for worker ${worker.id}`);
  }
}

module.exports = { processClaimsForTrigger };
