import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import 'home_screen.dart';

class PaymentScreen extends StatefulWidget {
  final Map<String, dynamic> workerData; // The result from /register API
  final Map<String, dynamic> planData;   // The selected plan dict

  const PaymentScreen({
    super.key,
    required this.workerData,
    required this.planData,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  static const bg    = Color(0xFFE8EDFF);
  static const navy  = Color(0xFF1A2E6E);
  static const gold  = Color(0xFFF5A623);
  static const gray  = Color(0xFF7A8BB0);
  static const bdr   = Color(0xFFCDD8F6);

  int _selectedMethod = 0; // 0=UPI, 1=Card, 2=NetBanking
  String _upiId = '';
  bool _loading = false;

  Future<void> _processPayment() async {
    if (_selectedMethod == 0 && _upiId.trim().isEmpty) return;
    setState(() => _loading = true);

    int wid = widget.workerData['worker']?['id'] ?? widget.workerData['id'];
    int amt = widget.planData['price'] ?? 49;

    try {
      await ApiService.recordPayment(
        workerId: wid,
        amount: amt,
        planType: widget.planData['id'],
        paymentMethod: _selectedMethod == 0 ? 'UPI' : _selectedMethod == 1 ? 'Card' : 'NetBanking',
        upiId: _upiId.trim(),
      );

      // Payment Success!
      HapticFeedback.heavyImpact();
      if (!mounted) return;
      _showSuccessPopup(wid);
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Payment failed. Try again.'), backgroundColor: Colors.red));
      }
    }
  }

  void _showSuccessPopup(int wid) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFF00C853).withOpacity(0.12), shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_rounded, color: Color(0xFF00C853), size: 50),
            ),
            const SizedBox(height: 16),
            const Text('Payment Successful!', style: TextStyle(color: navy, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Your policy is now active.', style: TextStyle(color: gray, fontSize: 14)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => HomeScreen(
                      workerId:    wid,
                      fromPayment: true, // 10-sec delay before trigger starts
                    )),
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: navy,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Go to Dashboard', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int price = widget.planData['price'] ?? 49;
    bool payEnabled = _selectedMethod != 0 || _upiId.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(color: navy, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.shield_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Activate your policy', style: TextStyle(color: navy, fontSize: 18, fontWeight: FontWeight.w800)),
                      Text('Pay weekly premium to start coverage', style: TextStyle(color: gray, fontSize: 13, fontWeight: FontWeight.w500)),
                    ],
                  )
                ],
              ),
              const SizedBox(height: 24),

              // Policy Details Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: navy, borderRadius: BorderRadius.circular(20)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('SELECTED PLAN', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                            const SizedBox(height: 4),
                            Text(widget.planData['label'] ?? 'Standard', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                          ],
                        ),
                        if (widget.planData['popular'] == true)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: gold.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(color: gold.withOpacity(0.3)),
                            ),
                            child: const Text('Most Popular', style: TextStyle(color: gold, fontSize: 11, fontWeight: FontWeight.bold)),
                          )
                      ],
                    ),
                    const SizedBox(height: 20),
                    _detailRow('Valid for', '7 days'),
                    const SizedBox(height: 8),
                    _detailRow('Max payout', '₹${widget.planData['max'] ?? 900}/week'),
                    const SizedBox(height: 8),
                    _detailRow('Starts', 'Today'),
                    const SizedBox(height: 16),
                    Row(
                      children: (widget.planData['triggers'] as List).where((t) => t['covered'] == true).take(4).map((t) {
                        String name = t['name'].toString().toLowerCase();
                        String emoji = name.contains('rain') ? '🌧' : name.contains('heat') ? '🌡' : name.contains('aqi') ? '😷' : name.contains('flood') ? '🌊' : '⚡';
                        return Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(99)),
                          child: Row(
                            children: [
                              Text(emoji, style: const TextStyle(fontSize: 10)),
                              const SizedBox(width: 4),
                              Text(t['name'].toString().split(' ').last, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Pay  ', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13, fontWeight: FontWeight.bold)),
                        Text('₹$price', style: const TextStyle(color: gold, fontSize: 28, fontWeight: FontWeight.w900, height: 1.0)),
                        Text(' /week', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    )
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Text('PAYMENT METHOD', style: TextStyle(color: gray.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.0)),
              const SizedBox(height: 12),

              _payMethod(0, 'UPI', 'GPay • PhonePe • Paytm', Icons.qr_code_scanner_rounded),
              if (_selectedMethod == 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white, 
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: navy.withOpacity(0.25))),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    child: TextField(
                      style: const TextStyle(color: navy, fontSize: 15, fontWeight: FontWeight.w600),
                      decoration: const InputDecoration(
                        icon: Icon(Icons.qr_code_scanner_rounded, color: navy, size: 18),
                        hintText: 'Enter UPI ID (e.g. name@upi)',
                        hintStyle: TextStyle(color: gray),
                        border: InputBorder.none,
                      ),
                      onChanged: (v) => setState(() => _upiId = v),
                    ),
                  ),
                ),

              _payMethod(1, 'Debit / Credit Card', 'Visa • Mastercard • Rupay', Icons.credit_card_rounded),
              _payMethod(2, 'Net Banking', 'All major banks', Icons.account_balance_rounded),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: payEnabled && !_loading ? _processPayment : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: navy,
                    disabledBackgroundColor: navy.withOpacity(0.3),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Pay now ', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: gold, borderRadius: BorderRadius.circular(6)),
                              child: Text('₹$price', style: const TextStyle(color: navy, fontSize: 13, fontWeight: FontWeight.w800)),
                            )
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_rounded, color: gray, size: 14),
                  const SizedBox(width: 6),
                  const Text('Secured by Razorpay • 256-bit encryption', style: TextStyle(color: gray, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _payMethod(int index, String title, String subtitle, IconData icon) {
    bool selected = _selectedMethod == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedMethod = index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? navy : const Color(0xFFCDD8F6), width: selected ? 2.0 : 1.0),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFFF3F5FA), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: navy, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: navy, fontSize: 15, fontWeight: FontWeight.w800)),
                  Text(subtitle, style: const TextStyle(color: gray, fontSize: 12, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            Container(
              width: 22, height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: selected ? navy : bdr, width: selected ? 6 : 1.5),
              ),
            )
          ],
        ),
      ),
    );
  }
}
