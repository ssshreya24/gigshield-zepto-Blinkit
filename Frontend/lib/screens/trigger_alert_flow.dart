import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/claim_receipt_generator.dart';
import 'home_screen.dart';

// ═══════════════════════════════════════════════════════════════
// TRIGGER ALERT FLOW
// Screen 0: Processing (API checks auto)
// Screen 1: Dynamic Premium Calculation (auto)
// Screen 2: Claim Summary  → user taps "Claim Now"
// Screen 3: Payment Method Selection (NEW)  → user taps "Confirm"
// Screen 4: UPI Payout animation (auto)
// Screen 5: Success + Download Receipt PDF
// ═══════════════════════════════════════════════════════════════

class TriggerAlertFlow extends StatefulWidget {
  final List<Map<String, dynamic>> triggers;
  final Map<String, dynamic>?      policy;

  const TriggerAlertFlow({
    super.key,
    required this.triggers,
    this.policy,
  });
  @override
  State<TriggerAlertFlow> createState() =>
    _TriggerAlertFlowState();
}

class _TriggerAlertFlowState extends State<TriggerAlertFlow>
    with TickerProviderStateMixin {

  static const bg   = Color(0xFF0D1829);
  static const navy = Color(0xFF1A2E6E);
  static const gold = Color(0xFFF5A623);
  static const gray = Color(0xFF7A8BB0);
  static const grn  = Color(0xFF00C853);

  int    _screen      = 0;
  bool   _downloading = false;
  String _selMethod   = 'upi'; // selected payment method

  // Processing screen state
  int _checksDone = 0;
  final List<Map<String, dynamic>> _checks = [
    {'label': 'Weather API verified',  'icon': Icons.cloud_done_rounded,   'color': Color(0xFF4B9FFF)},
    {'label': 'Zone risk confirmed',   'icon': Icons.location_on_rounded,  'color': Color(0xFF9C6FFF)},
    {'label': 'Policy active',         'icon': Icons.shield_rounded,       'color': Color(0xFF00C853)},
    {'label': 'Eligibility confirmed', 'icon': Icons.verified_user_rounded,'color': Color(0xFFF5A623)},
  ];

  // Premium calculation state
  late int _basePrem;
  int  _rainfallRisk = 0;
  int  _floodZone    = 0;
  int  _safeDiscount = 0;
  bool _premReady    = false;

  // Claim data
  late int    _totalPayout;
  late String _zone;
  late String _triggerName;
  late String _claimId;
  late String _txnId;

  late AnimationController _amtCtrl;
  late Animation<double>   _amtAnim;
  late AnimationController _checkCtrl;
  late Animation<double>   _checkAnim;

  @override
  void initState() {
    super.initState();

    _basePrem    = widget.policy?['weekly_premium'] ?? 49;
    _totalPayout = widget.triggers.fold(
      0, (s, t) => s + (t['amount'] as int? ?? 0));
    _zone        = widget.policy?['zone'] ?? 'Koramangala';
    _triggerName = widget.triggers.map((t) {
      final val = t['name'] ?? t['label'] ?? t['trigger_type'];
      if (val == null || val.toString().trim().isEmpty || val.toString() == 'null') {
        return 'Heavy Rain';
      }
      return val.toString().replaceAll('_', ' ').split(' ')
        .map((s) => s.isNotEmpty ? s[0].toUpperCase() + s.substring(1) : '')
        .join(' ');
    }).join(', ');

    if (_triggerName.trim().isEmpty) _triggerName = 'Heavy Rain';

    final now = DateTime.now();
    _claimId = 'CLM-${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}-${now.millisecond}';
    _txnId   = 'TXN${now.millisecondsSinceEpoch.toString().substring(5)}';

    _amtCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1500));
    _amtAnim = CurvedAnimation(parent: _amtCtrl, curve: Curves.easeOut);

    _checkCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 400));
    _checkAnim = CurvedAnimation(parent: _checkCtrl, curve: Curves.elasticOut);

    _runProcessingScreen();
  }

  @override
  void dispose() {
    _amtCtrl.dispose();
    _checkCtrl.dispose();
    super.dispose();
  }

  Future<void> _runProcessingScreen() async {
    for (int i = 0; i < _checks.length; i++) {
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      setState(() => _checksDone = i + 1);
      HapticFeedback.lightImpact();
      _checkCtrl.reset();
      _checkCtrl.forward();
    }
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() => _screen = 1);
    _runPremiumScreen();
  }

  Future<void> _runPremiumScreen() async {
    await Future.delayed(const Duration(milliseconds: 600));
    try {
      final dynamicPremium = await ApiService.getPremium(
        zone: widget.policy?['zone'] ?? 'Koramangala',
        planType: widget.policy?['plan_type'] ?? 'basic',
      );
      if (!mounted) return;
      final pData = dynamicPremium['premium'] ?? {};
      setState(() {
        _basePrem     = pData['base'] ?? 49;
        _rainfallRisk = pData['weather_adjustment'] ?? 8;
        _floodZone    = pData['zone_adjustment'] ?? 5;
        _safeDiscount = pData['tenure_discount'] ?? 3;
        _premReady    = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _rainfallRisk = 8;
        _floodZone    = 5;
        _safeDiscount = 3;
        _premReady    = true;
      });
    }
    HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    setState(() => _screen = 2); // claim summary
  }

  int get _finalPrem => _basePrem + _rainfallRisk + _floodZone - _safeDiscount;

  // Called from payment confirm button
  Future<void> _runPayoutScreen() async {
    setState(() => _screen = 4);
    HapticFeedback.mediumImpact();
    _amtCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 3500));
    if (!mounted) return;
    setState(() => _screen = 5);
    HapticFeedback.heavyImpact();
  }

  Future<void> _downloadReceipt() async {
    setState(() => _downloading = true);
    try {
      final upi = widget.policy?['upi_id'] ?? 'worker@upi';
      final pct = widget.triggers.isNotEmpty
        ? (widget.triggers.first['pct'] as int? ?? 80) : 80;
      final triggerEntry = <String, dynamic>{
        'name':     _triggerName,
        'severity': widget.triggers.isNotEmpty
          ? (widget.triggers.first['severity'] ?? 'T2') : 'T2',
        'pct':      pct,
        'icon':     Icons.bolt_rounded,
        'color':    const Color(0xFF4B9FFF),
      };
      await ClaimReceiptGenerator.generate(
        total:    _totalPayout,
        triggers: [triggerEntry],
        amounts:  [_totalPayout],
        policy:   widget.policy,
        upiId:    upi,
        claimId:  _claimId,
        txnId:    _txnId,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim, child: child),
          child: _buildScreen(),
        ),
      ),
    );
  }

  Widget _buildScreen() {
    switch (_screen) {
      case 0: return _processingScreen();
      case 1: return _premiumScreen();
      case 2: return _summaryScreen();
      case 3: return _paymentMethodScreen();   // NEW
      case 4: return _payoutScreen();           // was 3
      case 5: return _successScreen();           // was 4
      default: return _processingScreen();
    }
  }

  // ── Screen 0: Processing ──────────────────────────────────────
  Widget _processingScreen() => Padding(
    key: const ValueKey('processing'),
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _backBtn(),
        const SizedBox(height: 32),

        RichText(text: const TextSpan(
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900,
            color: Colors.white, height: 1.2),
          children: [
            TextSpan(text: 'Verifying\n'),
            TextSpan(text: 'your claim',
              style: TextStyle(color: Color(0xFFF5A623))),
          ],
        )),
        const SizedBox(height: 8),
        Text('AI is checking all conditions in $_zone',
          style: const TextStyle(color: Colors.white54, fontSize: 14)),

        const SizedBox(height: 40),

        // Trigger badge
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFFF5252).withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFFF5252).withOpacity(0.3))),
          child: Row(children: [
            Text(_triggerName.toLowerCase().contains('heat') ? '☀️'
                 : _triggerName.toLowerCase().contains('aqi') ? '😷'
                 : _triggerName.toLowerCase().contains('storm') ? '⛈️'
                 : '🌧', style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_triggerName,
                style: const TextStyle(color: Colors.white,
                  fontSize: 18, fontWeight: FontWeight.w800)),
              Text('$_zone · Disruption detected',
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ]),
          ]),
        ),

        const SizedBox(height: 36),

        _tagLabel('Processing Screen'),
        const SizedBox(height: 16),

        // Checks
        ..._checks.asMap().entries.map((e) {
          final idx   = e.key;
          final check = e.value;
          final done  = _checksDone > idx;
          final color = check['color'] as Color;
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: done
                    ? color.withOpacity(0.15)
                    : Colors.white.withOpacity(0.04),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: done
                      ? color.withOpacity(0.5)
                      : Colors.white.withOpacity(0.1))),
                child: Icon(
                  done ? Icons.check_rounded : check['icon'] as IconData,
                  color: done ? color : Colors.white24, size: 18)),
              const SizedBox(width: 14),
              Expanded(child: Text(check['label'] as String,
                style: TextStyle(
                  color:      done ? Colors.white : Colors.white38,
                  fontSize:   15,
                  fontWeight: done ? FontWeight.w600 : FontWeight.w400))),
              if (done)
                Icon(Icons.check_circle_rounded, color: color, size: 20),
            ]),
          );
        }),

        const Spacer(),
        _autoLabel('Processing automatically...'),
      ],
    ),
  );

  // ── Screen 1: Dynamic Premium Calculation ────────────────────
  Widget _premiumScreen() => Padding(
    key: const ValueKey('premium'),
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _backBtn(),
        const SizedBox(height: 32),

        RichText(text: const TextSpan(
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900,
            color: Colors.white, height: 1.2),
          children: [
            TextSpan(text: 'Dynamic Premium\n'),
            TextSpan(text: 'Calculation',
              style: TextStyle(color: Color(0xFFF5A623))),
          ],
        )),
        const SizedBox(height: 8),
        const Text('Risk-based pricing for your zone',
          style: TextStyle(color: Colors.white54, fontSize: 14)),
        const SizedBox(height: 32),

        _tagLabel('Dynamic Premium Calculation Screen'),
        const SizedBox(height: 20),

        _darkCard(child: Column(children: [
          _calcRow('Base Premium', '₹$_basePrem', Colors.white60, false),
          const SizedBox(height: 8),
          Divider(color: Colors.white.withOpacity(0.06)),
          const SizedBox(height: 8),
          AnimatedOpacity(
            opacity: _rainfallRisk > 0 ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 400),
            child: Column(children: [
              _calcRow('+ Rainfall risk', '+₹$_rainfallRisk', gold, true),
              const SizedBox(height: 8),
            ])),
          AnimatedOpacity(
            opacity: _floodZone > 0 ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 400),
            child: Column(children: [
              _calcRow('+ Flood zone', '+₹$_floodZone', gold, true),
              const SizedBox(height: 8),
            ])),
          AnimatedOpacity(
            opacity: _safeDiscount > 0 ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 400),
            child: Column(children: [
              _calcRow('- Safe history', '-₹$_safeDiscount',
                const Color(0xFF00C853), false),
              const SizedBox(height: 8),
            ])),
          if (_premReady) ...[
            Divider(color: Colors.white.withOpacity(0.12)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
              const Text('Final Premium',
                style: TextStyle(color: Colors.white,
                  fontSize: 18, fontWeight: FontWeight.w800)),
              Text('₹$_finalPrem/week',
                style: const TextStyle(color: Color(0xFFF5A623),
                  fontSize: 22, fontWeight: FontWeight.w900)),
            ]),
          ],
        ])),

        const Spacer(),
        if (_premReady) _autoLabel('Advancing to claim summary...'),
      ],
    ),
  );

  // ── Screen 2: Claim Summary ───────────────────────────────────
  Widget _summaryScreen() {
    final expInc  = widget.triggers.isNotEmpty
      ? (widget.triggers.first['expected_income'] as num? ?? 800) : 800;
    final actInc  = widget.triggers.isNotEmpty
      ? (widget.triggers.first['actual_income'] as num? ?? 0) : 0;
    final incLost = (expInc - actInc) > 0 ? (expInc - actInc) : 2400;
    final daysAff = (incLost / expInc).ceil().clamp(1, 4);
    final coverPct = widget.triggers.isNotEmpty
      ? (widget.triggers.first['pct'] as int? ?? 80) : 80;

    return Padding(
      key: const ValueKey('summary'),
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        _backBtn(),
        const SizedBox(height: 24),

        RichText(text: const TextSpan(
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900,
            color: Colors.white, height: 1.2),
          children: [
            TextSpan(text: 'Claim\n'),
            TextSpan(text: 'Summary',
              style: TextStyle(color: Color(0xFFF5A623))),
          ],
        )),
        const SizedBox(height: 24),

        Align(alignment: Alignment.centerLeft,
          child: _tagLabel('Claim Summary Screen')),
        const SizedBox(height: 16),

        _darkCard(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          _sumRow('Disruption', _triggerName, Colors.white),
          _div(),
          _sumRow('Days affected', '$daysAff days', Colors.white70),
          _div(),
          _sumRow('Income lost', '₹${incLost.round()}',
            const Color(0xFFFF5252)),
          _div(),
          _sumRow('Policy covers', '$coverPct%',
            const Color(0xFF4B9FFF)),
          _div(),
          const SizedBox(height: 8),
          Divider(color: Colors.white.withOpacity(0.12)),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Total Claimable',
              style: TextStyle(color: Colors.white, fontSize: 18,
                fontWeight: FontWeight.w800)),
            Text('₹$_totalPayout',
              style: const TextStyle(color: Color(0xFFF5A623),
                fontSize: 26, fontWeight: FontWeight.w900)),
          ]),
        ])),

        const Spacer(),
        _autoLabel('(auto)'),
        const SizedBox(height: 16),

        // ── Claim Now → go to Payment Method screen
        GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            setState(() => _screen = 3);
          },
          child: Container(
            width:   double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 17),
            decoration: BoxDecoration(
              color:        gold,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(
                color:      gold.withOpacity(0.45),
                blurRadius: 20, offset: const Offset(0, 8))]),
            child: Center(child: Text(
              'Claim ₹$_totalPayout Now →',
              style: const TextStyle(color: Color(0xFF0D1829),
                fontSize: 16, fontWeight: FontWeight.w900))),
          ),
        ),
      ]),
    );
  }

  // ── Screen 3: Payment Method Selection (NEW) ─────────────────
  Widget _paymentMethodScreen() {
    final upi = widget.policy?['upi_id'] ?? 'worker@upi';
    return Column(
      key: const ValueKey('payment'),
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: Row(children: [
            GestureDetector(
              onTap: () => setState(() => _screen = 2),
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.15))),
                child: const Icon(Icons.arrow_back_rounded,
                  color: Colors.white, size: 20)),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Payment Method',
                  style: TextStyle(color: Colors.white, fontSize: 22,
                    fontWeight: FontWeight.w900)),
                Text('Receive your payout of ₹$_totalPayout',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5), fontSize: 12)),
              ],
            ),
          ]),
        ),

        const SizedBox(height: 20),

        // Amount banner
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color:        gold.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border:       Border.all(color: gold.withOpacity(0.35))),
            child: Row(children: [
              const Icon(Icons.account_balance_wallet_rounded,
                color: gold, size: 26),
              const SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Payout amount',
                  style: TextStyle(color: Colors.white54, fontSize: 11)),
                Text('₹$_totalPayout',
                  style: const TextStyle(color: gold,
                    fontSize: 26, fontWeight: FontWeight.w900)),
              ]),
            ]),
          ),
        ),

        const SizedBox(height: 20),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: const Text('SELECT METHOD',
            style: TextStyle(color: Colors.white38, fontSize: 11,
              fontWeight: FontWeight.w700, letterSpacing: 1.2)),
        ),
        const SizedBox(height: 10),

        // Payment options
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(children: [
            _payOption('upi',  Icons.account_balance_wallet_rounded,
              const Color(0xFF4B9FFF), 'UPI', upi, 'Instant · Verified'),
            const SizedBox(height: 10),
            _payOption('card', Icons.credit_card_rounded,
              const Color(0xFF9C6FFF), 'Debit Card',
              'HDFC Bank •••• 4521', 'Within 2 hours'),
            const SizedBox(height: 10),
            _payOption('gpay', Icons.phone_android_rounded,
              const Color(0xFF00C853), 'Google Pay / PhonePe',
              upi, 'Instant UPI'),
          ]),
        ),

        const SizedBox(height: 14),

        // Security note
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(children: [
            const Icon(Icons.lock_rounded, color: Colors.white24, size: 13),
            const SizedBox(width: 6),
            Expanded(child: Text(
              'Payout secured by Insurify · 256-bit encryption · RBI compliant',
              style: TextStyle(
                color: Colors.white.withOpacity(0.25), fontSize: 11))),
          ]),
        ),

        const Spacer(),

        // Confirm button
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
          child: GestureDetector(
            onTap: _runPayoutScreen,
            child: Container(
              width:   double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 17),
              decoration: BoxDecoration(
                color:        gold,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(
                  color:      gold.withOpacity(0.45),
                  blurRadius: 20, offset: const Offset(0, 8))]),
              child: Center(child: Text(
                'Confirm & Receive ₹$_totalPayout →',
                style: const TextStyle(color: Color(0xFF0D1829),
                  fontSize: 16, fontWeight: FontWeight.w900))),
            ),
          ),
        ),
      ],
    );
  }

  // ── Screen 4: UPI Payout Processing ──────────────────────────
  Widget _payoutScreen() {
    final upi = widget.policy?['upi_id'] ?? 'worker@upi';
    return Padding(
      key: const ValueKey('payout'),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
        const SizedBox(height: 40),

        _tagLabel('UPI Payout Screen'),
        const SizedBox(height: 40),

        Container(
          width: 90, height: 90,
          decoration: BoxDecoration(
            color:  gold.withOpacity(0.12),
            shape:  BoxShape.circle,
            border: Border.all(color: gold.withOpacity(0.4), width: 2)),
          child: const Icon(Icons.account_balance_wallet_rounded,
            color: gold, size: 44)),

        const SizedBox(height: 28),
        const Text('Sending to UPI',
          style: TextStyle(color: Colors.white54, fontSize: 15)),
        const SizedBox(height: 8),

        // Animated amount counter
        AnimatedBuilder(
          animation: _amtAnim,
          builder: (_, __) {
            final shown = (_totalPayout * _amtAnim.value).round();
            return Text('₹$shown',
              style: const TextStyle(color: gold, fontSize: 64,
                fontWeight: FontWeight.w900, letterSpacing: -2));
          },
        ),

        const SizedBox(height: 8),
        Text('→ $upi',
          style: const TextStyle(color: Colors.white60, fontSize: 15)),

        const SizedBox(height: 40),

        _payoutStep('Processing...', true,  const Color(0xFF4B9FFF)),
        const SizedBox(height: 8),
        Row(children: [
          const SizedBox(width: 2),
          Container(width: 2, height: 20,
            color: Colors.white.withOpacity(0.1)),
        ]),
        const SizedBox(height: 4),
        _payoutStep('Initiating transfer', false, gray),
        const SizedBox(height: 8),
        _payoutStep('Crediting to UPI',    false, gray),

        const Spacer(),
        const Center(child: Text('(auto)',
          style: TextStyle(color: Colors.white24, fontSize: 12))),
      ]),
    );
  }

  // ── Screen 5: Success ─────────────────────────────────────────
  Widget _successScreen() {
    final upi = widget.policy?['upi_id'] ?? 'worker@upi';
    return Padding(
      key: const ValueKey('success'),
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        const SizedBox(height: 40),

        _tagLabel('Success Screen'),
        const SizedBox(height: 32),

        Container(
          width: 100, height: 100,
          decoration: BoxDecoration(
            color:  const Color(0xFF00C853).withOpacity(0.12),
            shape:  BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF00C853).withOpacity(0.4), width: 2)),
          child: const Icon(Icons.check_rounded,
            color: Color(0xFF00C853), size: 54)),

        const SizedBox(height: 20),
        Text('₹$_totalPayout credited to UPI',
          style: const TextStyle(color: Color(0xFF00C853),
            fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(upi, style: const TextStyle(
          color: Colors.white54, fontSize: 13)),
        const SizedBox(height: 32),

        _darkCard(child: Column(children: [
          _sumRow('✅ Claim ID', _claimId, const Color(0xFF00C853)),
          _div(),
          _sumRow('Transaction', _txnId, Colors.white70),
          _div(),
          _sumRow('Trigger',     _triggerName, Colors.white70),
          _div(),
          _sumRow('Zone',        _zone, Colors.white70),
          _div(),
          _sumRow('Amount',      '₹$_totalPayout', gold),
          _div(),
          _sumRow('Status',      '✅ Credited', const Color(0xFF00C853)),
        ])),

        const Spacer(),

        // Back to Home (gold)
        GestureDetector(
          onTap: () async {
            final prefs = await SharedPreferences.getInstance();
            final wid = prefs.getInt('worker_id') ?? 1;
            if (!context.mounted) return;
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => HomeScreen(workerId: wid, initialTab: 1)),
              (route) => false,
            );
          },
          child: Container(
            width:   double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color:        gold,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(
                color:      gold.withOpacity(0.35),
                blurRadius: 16, offset: const Offset(0, 6))]),
            child: const Center(child: Text('Back to Home',
              style: TextStyle(color: Color(0xFF0D1829),
                fontSize: 16, fontWeight: FontWeight.w900))),
          ),
        ),

        const SizedBox(height: 12),

        // Download Receipt PDF (working)
        GestureDetector(
          onTap: _downloading ? null : _downloadReceipt,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width:    double.infinity,
            padding:  const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.15))),
            child: _downloading
              ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white54, strokeWidth: 2.5)),
                    SizedBox(width: 10),
                    Text('Generating PDF...',
                      style: TextStyle(color: Colors.white54,
                        fontSize: 14, fontWeight: FontWeight.w600)),
                  ])
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.picture_as_pdf_rounded,
                      color: Colors.white60, size: 20),
                    SizedBox(width: 8),
                    Text('Download Receipt (PDF)',
                      style: TextStyle(color: Colors.white70,
                        fontSize: 14, fontWeight: FontWeight.w700)),
                  ]),
          ),
        ),
      ]),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────

  Widget _payOption(
    String key, IconData icon, Color color,
    String label, String detail, String speed,
  ) {
    final sel = _selMethod == key;
    return GestureDetector(
      onTap: () => setState(() => _selMethod = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: sel
            ? color.withOpacity(0.12)
            : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: sel
              ? color.withOpacity(0.6)
              : Colors.white.withOpacity(0.1),
            width: sel ? 1.5 : 1)),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 22)),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(
                color:      Colors.white,
                fontSize:   14,
                fontWeight: sel ? FontWeight.w800 : FontWeight.w500)),
              const SizedBox(height: 2),
              Text(detail, style: const TextStyle(
                color: Colors.white38, fontSize: 12)),
              const SizedBox(height: 2),
              Text(speed, style: TextStyle(
                color: color.withOpacity(0.85), fontSize: 11,
                fontWeight: FontWeight.w600)),
            ],
          )),
          if (sel)
            Icon(Icons.check_circle_rounded, color: color, size: 22)
          else
            Container(
              width: 20, height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white24, width: 1.5))),
        ]),
      ),
    );
  }

  Widget _payoutStep(String label, bool active, Color color) =>
    Row(children: [
      Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          shape: BoxShape.circle,
          border: Border.all(color: color.withOpacity(0.4))),
        child: Icon(
          active
            ? Icons.currency_rupee_rounded
            : Icons.radio_button_unchecked_rounded,
          color: color, size: 14)),
      const SizedBox(width: 10),
      Text(label, style: TextStyle(
        color:      active ? Colors.white : Colors.white38,
        fontSize:   14,
        fontWeight: active ? FontWeight.w700 : FontWeight.w400)),
    ]);

  Widget _tagLabel(String t) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color:        Colors.white.withOpacity(0.06),
      borderRadius: BorderRadius.circular(8)),
    child: Text(t, style: const TextStyle(
      color: Colors.white38, fontSize: 11, letterSpacing: 0.8)),
  );

  Widget _autoLabel(String t) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Icon(Icons.auto_awesome_rounded, color: Colors.white24, size: 14),
      const SizedBox(width: 6),
      Text(t, style: const TextStyle(color: Colors.white24, fontSize: 12)),
    ],
  );

  Widget _backBtn() => Align(
    alignment: Alignment.centerLeft,
    child: GestureDetector(
      onTap: () => _screen == 0
        ? Navigator.pop(context)
        : setState(() => _screen = _screen - 1),
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.1))),
        child: const Icon(Icons.arrow_back_rounded,
          color: Colors.white, size: 20)),
    ),
  );

  Widget _calcRow(String l, String v, Color c, bool highlight) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
        Text(l, style: TextStyle(
          color: highlight ? Colors.white70 : Colors.white54,
          fontSize: 14)),
        Text(v, style: TextStyle(
          color: c, fontSize: 15, fontWeight: FontWeight.w700)),
      ]),
    );

  Widget _sumRow(String l, String v, Color c) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
      Text(l, style: const TextStyle(color: Colors.white38, fontSize: 13)),
      Flexible(child: Text(v, textAlign: TextAlign.right,
        style: TextStyle(color: c, fontSize: 13,
          fontWeight: FontWeight.w600))),
    ]),
  );

  Widget _div() => Divider(
    color: Colors.white.withOpacity(0.06), height: 1);

  Widget _darkCard({required Widget child}) => Container(
    width:   double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.04),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white.withOpacity(0.08))),
    child: child,
  );
}
