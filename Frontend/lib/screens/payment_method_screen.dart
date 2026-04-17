import 'package:flutter/material.dart';
import 'claim_success_screen.dart';
import '../screens/payout_animation_screen.dart';

class PaymentMethodScreen extends StatefulWidget {
  final int                        total;
  final List<Map<String, dynamic>> triggers;
  final List<int>                  amounts;
  final Map<String, dynamic>?      policy;

  const PaymentMethodScreen({
    super.key,
    required this.total,
    required this.triggers,
    required this.amounts,
    this.policy,
  });
  @override
  State<PaymentMethodScreen> createState() =>
    _PaymentMethodScreenState();
}

class _PaymentMethodScreenState
    extends State<PaymentMethodScreen> {

  static const bg   = Color(0xFF0D1829);
  static const gold = Color(0xFFF5A623);
  static const gray = Color(0xFF7A8BB0);

  String _method     = 'upi';    // 'upi' or 'card'
  bool   _useExisting = true;
  String _upiId       = 'ravi@upi';
  bool   _editing     = false;

  final _upiCtrl  = TextEditingController(text: 'ravi@upi');
  final _cardCtrl = TextEditingController();

  @override
  void dispose() {
    _upiCtrl.dispose();
    _cardCtrl.dispose();
    super.dispose();
  }

 void _pay() {
  final upi      = _upiCtrl.text.trim();
  final myCtx    = context; // capture before navigation

  Navigator.push(myCtx,
    MaterialPageRoute(
      builder: (ctx) => PayoutAnimationScreen(
        triggerName: widget.triggers
          .map((t) => t['name']).join(', '),
        zone:       widget.policy?['zone'] ?? 'Your Zone',
        severity:   'T3',
        amount:     widget.total,
        workerName: widget.policy?['name'] ?? 'Worker',
        onComplete: () {
          Navigator.push(ctx,
            MaterialPageRoute(
              builder: (_) => ClaimSuccessScreen(
                total:    widget.total,
                triggers: widget.triggers,
                amounts:  widget.amounts,
                policy:   widget.policy,
                upiId:    upi,
              )));
        },
      )));
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(children: [
          _header(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Amount due
                  Container(
                    width:   double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color:        Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(16),
                      border:       Border.all(
                        color: gold.withOpacity(0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.account_balance_wallet_rounded,
                        color: gold, size: 28),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Payout amount',
                            style: TextStyle(
                              color: Colors.white54, fontSize: 12)),
                          Text('₹${widget.total}',
                            style: const TextStyle(
                              color:      gold,
                              fontSize:   28,
                              fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ]),
                  ),

                  const SizedBox(height: 16),

                  // Razorpay Payment Gateway Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF072654),
                          const Color(0xFF0A3D7A),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFF2E86DE).withOpacity(0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Razorpay',
                              style: TextStyle(
                                color: Color(0xFF072654),
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5)),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5A623).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: const Text('TEST MODE',
                              style: TextStyle(
                                color: Color(0xFFF5A623),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1)),
                          ),
                          const Spacer(),
                          const Icon(Icons.verified_rounded,
                            color: Color(0xFF2E86DE), size: 20),
                        ]),
                        const SizedBox(height: 10),
                        const Text(
                          'Secure instant payout powered by Razorpay Payment Gateway',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            height: 1.4)),
                        const SizedBox(height: 8),
                        Row(children: [
                          _gatewayChip('UPI'),
                          const SizedBox(width: 6),
                          _gatewayChip('Cards'),
                          const SizedBox(width: 6),
                          _gatewayChip('NetBanking'),
                          const SizedBox(width: 6),
                          _gatewayChip('Wallets'),
                        ]),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Method selector
                  _sectionLabel('Payment method'),
                  const SizedBox(height: 10),
                  Row(children: [
                    _methodBtn('upi',  'UPI',  Icons.phone_android_rounded),
                    const SizedBox(width: 10),
                    _methodBtn('card', 'Card', Icons.credit_card_rounded),
                  ]),

                  const SizedBox(height: 20),

                  // UPI section
                  if (_method == 'upi') ...[
                    _sectionLabel('UPI details'),
                    const SizedBox(height: 10),
                    _darkCard(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Saved UPI
                        GestureDetector(
                          onTap: () => setState(() {
                            _useExisting = true;
                            _editing     = false;
                          }),
                          child: Row(children: [
                            Radio<bool>(
                              value:          true,
                              groupValue:     _useExisting,
                              onChanged: (v) => setState(() {
                                _useExisting = true;
                                _editing     = false;
                              }),
                              activeColor: gold,
                            ),
                            Expanded(child: Column(
                              crossAxisAlignment:
                                CrossAxisAlignment.start,
                              children: [
                                const Text('Saved UPI ID',
                                  style: TextStyle(
                                    color:      Colors.white,
                                    fontSize:   14,
                                    fontWeight: FontWeight.w600)),
                                Text(_upiId,
                                  style: const TextStyle(
                                    color:    Colors.white38,
                                    fontSize: 12)),
                              ],
                            )),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00C853)
                                  .withOpacity(0.12),
                                borderRadius:
                                  BorderRadius.circular(99),
                              ),
                              child: const Text('Verified',
                                style: TextStyle(
                                  color:      Color(0xFF00C853),
                                  fontSize:   10,
                                  fontWeight: FontWeight.bold)),
                            ),
                          ]),
                        ),

                        Divider(
                          color: Colors.white.withOpacity(0.06),
                          height: 20),

                        // New UPI
                        GestureDetector(
                          onTap: () => setState(() {
                            _useExisting = false;
                            _editing     = true;
                          }),
                          child: Row(children: [
                            Radio<bool>(
                              value:      false,
                              groupValue: _useExisting,
                              onChanged: (v) => setState(() {
                                _useExisting = false;
                                _editing     = true;
                              }),
                              activeColor: gold,
                            ),
                            const Text('Use a different UPI ID',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                          ]),
                        ),

                        if (_editing) ...[
                          const SizedBox(height: 12),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              borderRadius:
                                BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.white
                                  .withOpacity(0.12)),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 4),
                            child: TextField(
                              controller:  _upiCtrl,
                              style: const TextStyle(
                                color: Colors.white, fontSize: 15),
                              decoration: const InputDecoration(
                                hintText:  'Enter UPI ID',
                                hintStyle: TextStyle(
                                  color: Colors.white24),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding:
                                  EdgeInsets.symmetric(
                                    vertical: 12)),
                            ),
                          ),
                        ],
                      ],
                    )),
                  ],

                  // Card section
                  if (_method == 'card') ...[
                    _sectionLabel('Card details'),
                    const SizedBox(height: 10),
                    _darkCard(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Card number',
                          style: TextStyle(
                            color: Colors.white38, fontSize: 11)),
                        const SizedBox(height: 6),
                        _inputField(
                          ctrl:    _cardCtrl,
                          hint:    '•••• •••• •••• ••••',
                          keyboard: TextInputType.number),
                        const SizedBox(height: 14),
                        Row(children: [
                          Expanded(child: Column(
                            crossAxisAlignment:
                              CrossAxisAlignment.start,
                            children: [
                              const Text('Expiry',
                                style: TextStyle(
                                  color:    Colors.white38,
                                  fontSize: 11)),
                              const SizedBox(height: 6),
                              _inputField(
                                ctrl:    TextEditingController(),
                                hint:    'MM/YY',
                                keyboard: TextInputType.number),
                            ],
                          )),
                          const SizedBox(width: 14),
                          Expanded(child: Column(
                            crossAxisAlignment:
                              CrossAxisAlignment.start,
                            children: [
                              const Text('CVV',
                                style: TextStyle(
                                  color:    Colors.white38,
                                  fontSize: 11)),
                              const SizedBox(height: 6),
                              _inputField(
                                ctrl:    TextEditingController(),
                                hint:    '•••',
                                keyboard: TextInputType.number,
                                obscure: true),
                            ],
                          )),
                        ]),
                      ],
                    )),
                  ],

                  const SizedBox(height: 20),

                  // Security note
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.06)),
                    ),
                    child: const Row(children: [
                      Icon(Icons.lock_rounded,
                        color: Colors.white24, size: 14),
                      SizedBox(width: 8),
                      Expanded(child: Text(
                        'Payout secured by Insurify · 256-bit encryption · '
                        'RBI compliant',
                        style: TextStyle(
                          color: Colors.white24, fontSize: 11))),
                    ]),
                  ),
                ],
              ),
            ),
          ),
          _payBtn(),
        ]),
      ),
    );
  }

  Widget _header(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
    child: Row(children: [
      GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white.withOpacity(0.1)),
          ),
          child: const Icon(Icons.arrow_back_rounded,
            color: Colors.white, size: 20),
        ),
      ),
      const SizedBox(width: 14),
      const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Payment Method',
            style: TextStyle(color: Colors.white, fontSize: 20,
              fontWeight: FontWeight.w900)),
          Text('Where to receive your payout',
            style: TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      ),
    ]),
  );

  Widget _methodBtn(String val, String label, IconData icon) =>
    Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _method = val),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: _method == val
              ? gold.withOpacity(0.12)
              : Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _method == val
                ? gold.withOpacity(0.5)
                : Colors.white.withOpacity(0.08)),
          ),
          child: Column(children: [
            Icon(icon,
              color: _method == val ? gold : Colors.white38,
              size: 24),
            const SizedBox(height: 6),
            Text(label,
              style: TextStyle(
                color:      _method == val ? gold : Colors.white38,
                fontSize:   13,
                fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );

  Widget _payBtn() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
    child: GestureDetector(
      onTap: _pay,
      child: Container(
        width:   double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 17),
        decoration: BoxDecoration(
          color:        gold,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(
            color:      gold.withOpacity(0.4),
            blurRadius: 20,
            offset:     const Offset(0, 8))],
        ),
        child: Center(child: Text(
          'Confirm & Receive ₹${widget.total} →',
          style: const TextStyle(
            color:      Color(0xFF0D1829),
            fontSize:   16,
            fontWeight: FontWeight.w900))),
      ),
    ),
  );

  Widget _inputField({
    required TextEditingController ctrl,
    required String hint,
    TextInputType keyboard = TextInputType.text,
    bool obscure = false,
  }) =>
    Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withOpacity(0.12)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 14, vertical: 4),
      child: TextField(
        controller:   ctrl,
        keyboardType: keyboard,
        obscureText:  obscure,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          hintText:  hint,
          hintStyle: const TextStyle(color: Colors.white24),
          border:    InputBorder.none,
          isDense:   true,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 12)),
      ),
    );

  Widget _darkCard({required Widget child}) => Container(
    width:   double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.04),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: Colors.white.withOpacity(0.08)),
    ),
    child: child,
  );

  Widget _sectionLabel(String t) => Text(t,
    style: const TextStyle(
      color:         Colors.white38,
      fontSize:      12,
      fontWeight:    FontWeight.w700,
      letterSpacing: 0.8));

  Widget _gatewayChip(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.08),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: Colors.white.withOpacity(0.12)),
    ),
    child: Text(label,
      style: const TextStyle(
        color: Colors.white60,
        fontSize: 10,
        fontWeight: FontWeight.w600)),
  );
}
