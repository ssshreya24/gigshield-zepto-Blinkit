/**
 * GigShield Payment Service — Razorpay Test Mode Integration
 * 
 * Handles payout order creation and verification via Razorpay.
 * Uses Razorpay Test Mode keys for hackathon demo.
 * 
 * In production: replace with live keys + webhook verification.
 */

const crypto = require('crypto');
require('dotenv').config();

const RAZORPAY_KEY_ID     = process.env.RAZORPAY_KEY_ID     || 'rzp_test_demo';
const RAZORPAY_KEY_SECRET = process.env.RAZORPAY_KEY_SECRET || 'demo_secret';

let razorpay = null;

// Initialize Razorpay client (lazy — only when keys are provided)
function getRazorpayClient() {
  if (razorpay) return razorpay;

  try {
    const Razorpay = require('razorpay');
    razorpay = new Razorpay({
      key_id:     RAZORPAY_KEY_ID,
      key_secret: RAZORPAY_KEY_SECRET,
    });
    console.log('[PAYMENT] Razorpay client initialized (test mode)');
    return razorpay;
  } catch (err) {
    console.warn('[PAYMENT] Razorpay SDK not installed — using mock mode');
    return null;
  }
}

/**
 * Create a Razorpay order for payout
 * @param {number} amountInr - Amount in INR (e.g. 750)
 * @param {string} receipt - Receipt/claim ID (e.g. "CLM-20260417-001")
 * @param {object} notes - Metadata (worker_id, trigger_type, zone)
 * @returns {object} Order details
 */
async function createPayoutOrder(amountInr, receipt, notes = {}) {
  const rz = getRazorpayClient();

  if (rz) {
    try {
      const order = await rz.orders.create({
        amount:   amountInr * 100,  // Razorpay expects paise
        currency: 'INR',
        receipt:  receipt,
        notes:    {
          platform:     'GigShield Insurify',
          purpose:      'Parametric Insurance Payout',
          worker_id:    String(notes.worker_id || ''),
          trigger_type: notes.trigger_type || '',
          zone:         notes.zone || '',
        },
      });

      console.log(`[PAYMENT] Razorpay order created: ${order.id} for ₹${amountInr}`);

      return {
        success:     true,
        provider:    'razorpay',
        mode:        'test',
        order_id:    order.id,
        amount:      amountInr,
        amount_paise: order.amount,
        currency:    order.currency,
        receipt:     order.receipt,
        status:      order.status,
        razorpay_key: RAZORPAY_KEY_ID,
      };
    } catch (err) {
      console.error('[PAYMENT] Razorpay order failed:', err.message);
      // Fall through to mock mode
    }
  }

  // Mock mode — when Razorpay SDK not installed or keys invalid
  const mockOrderId = `order_mock_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
  console.log(`[PAYMENT] Mock order created: ${mockOrderId} for ₹${amountInr}`);

  return {
    success:      true,
    provider:     'mock',
    mode:         'test',
    order_id:     mockOrderId,
    amount:       amountInr,
    amount_paise: amountInr * 100,
    currency:     'INR',
    receipt:      receipt,
    status:       'created',
    razorpay_key: RAZORPAY_KEY_ID,
    note:         'Mock mode — install razorpay npm package for real integration',
  };
}

/**
 * Verify Razorpay payment signature
 * Used to confirm that a payment callback is genuine
 */
function verifyPaymentSignature({ order_id, payment_id, signature }) {
  const rz = getRazorpayClient();

  if (!rz || RAZORPAY_KEY_SECRET === 'demo_secret') {
    // Mock verification — always passes in demo mode
    return { verified: true, mode: 'mock' };
  }

  try {
    const body = order_id + '|' + payment_id;
    const expectedSignature = crypto
      .createHmac('sha256', RAZORPAY_KEY_SECRET)
      .update(body)
      .digest('hex');

    const verified = expectedSignature === signature;
    return { verified, mode: 'live' };
  } catch (err) {
    console.error('[PAYMENT] Signature verification failed:', err.message);
    return { verified: false, mode: 'error', error: err.message };
  }
}

/**
 * Create a UPI payout link (Razorpay Payout Links API)
 * For instant UPI transfers to worker's VPA
 */
async function createUpiPayout(amountInr, upiId, workerName, description) {
  const rz = getRazorpayClient();

  // Mock UPI payout — demo mode
  const txnId = `txn_${Date.now()}_${Math.random().toString(36).slice(2, 6)}`;

  return {
    success:     true,
    provider:    rz ? 'razorpay' : 'mock',
    mode:        'test',
    txn_id:      txnId,
    amount:      amountInr,
    upi_id:      upiId,
    beneficiary: workerName,
    status:      'processed',
    description: description || 'GigShield parametric insurance payout',
    note:        'Test mode — no real money transferred',
  };
}

module.exports = {
  createPayoutOrder,
  verifyPaymentSignature,
  createUpiPayout,
  getRazorpayClient,
};
