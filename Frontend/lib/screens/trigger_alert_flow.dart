import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';

// ═══════════════════════════════════════════════════════════════
// TRIGGER ALERT FLOW — Exact like the spec image:
// Screen 1: Processing (Weather verified, Policy active...)
// Screen 2: Dynamic Premium Calculation
// Screen 3: Claim Summary (days, income lost, payout)
// Screen 4: UPI Payout (Sending ₹X → UPI ID)
// Screen 5: Success (✅ Credited, Claim ID)
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

  int _screen = 0; // 0=processing 1=premium 2=summary 3=payout 4=success

  // Processing screen state
  int _checksDone = 0;
  bool _isFraud = false;
  String? _fraudReason;
  String? _claimStatus;
  List<Map<String, dynamic>> _checks = [];

  void _buildChecks() {
    _isFraud      = widget.triggers.any((t) => t['fraud_flag'] == true);
    _fraudReason  = widget.triggers
        .map((t) => t['fraud_reason']?.toString())
        .where((r) => r != null && r.isNotEmpty)
        .join('; ');
    _claimStatus  = widget.triggers
        .map((t) => t['claim_status']?.toString())
        .firstWhere((s) => s != null, orElse: () => 'approved');
    if (_fraudReason == null || _fraudReason!.isEmpty) {
      _fraudReason = 'Suspicious activity detected';
    }

    final hasBehaviorAnomaly = widget.triggers.any((t) {
      final p = t['behavioral_profile'] as Map?;
      return p != null && ((p['claims_7d'] ?? 0) >= 3 || (p['claim_to_income_ratio'] ?? 0) > 3);
    });

    _checks = [
      {'label': 'OpenWeatherMap API verified',       'icon': Icons.cloud_done_rounded,       'color': const Color(0xFF4B9FFF)},
      {'label': 'XGBoost ML risk model scored',      'icon': Icons.psychology_rounded,        'color': const Color(0xFF9C6FFF)},
      {
        'label': hasBehaviorAnomaly
          ? '⚠ Behavioral anomaly detected'
          : 'Individual behavioral profile — normal',
        'icon': hasBehaviorAnomaly ? Icons.person_off_rounded : Icons.person_search_rounded,
        'color': hasBehaviorAnomaly ? const Color(0xFFFF6D00) : const Color(0xFF26A69A),
        'isFraud': hasBehaviorAnomaly,
      },
      {
        'label': _isFraud
          ? '⚠ Fraud detected — flagged for review'
          : '5-Layer fraud detection passed',
        'icon': _isFraud ? Icons.gpp_bad_rounded : Icons.security_rounded,
        'color': _isFraud ? const Color(0xFFFF5252) : const Color(0xFF00C853),
        'isFraud': _isFraud,
      },
      {'label': 'Policy active & eligible',          'icon': Icons.shield_rounded,            'color': const Color(0xFFF5A623)},
      {
        'label': _isFraud
          ? 'Razorpay payout HELD — under review'
          : 'Razorpay payout initialized',
        'icon': Icons.account_balance_rounded,
        'color': _isFraud ? const Color(0xFFFF6D00) : const Color(0xFF2E86DE),
      },
    ];
  }

  // Premium calculation state
  late int _basePrem;
  int _rainfallRisk = 0;
  int _floodZone    = 0;
  int _safeDiscount = 0;
  bool _premReady   = false;

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
    _buildChecks();

    _basePrem    = widget.policy?['weekly_premium'] ?? 49;
    _totalPayout = widget.triggers.fold(
      0, (s, t) => s + (t['amount'] as int? ?? 0));
    _zone        = widget.policy?['zone'] ?? 'Your Zone';
    _triggerName = widget.triggers.map((t) {
      final val = t['name'] ?? t['label'];
      if (val == null || val.toString().trim().isEmpty || val.toString() == 'null') {
        return 'Heavy Rain';
      }
      return val.toString();
    }).join(', ');
    
    if (_triggerName.trim().isEmpty) {
      _triggerName = 'Heavy Rain';
    }

    final now = DateTime.now();
    _claimId = 'CLM-${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}-${now.millisecond}';
    _txnId   = 'TXN${now.millisecondsSinceEpoch.toString().substring(5)}';

    _amtCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1500));
    _amtAnim = CurvedAnimation(
      parent: _amtCtrl, curve: Curves.easeOut);

    _checkCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 400));
    _checkAnim = CurvedAnimation(
      parent: _checkCtrl, curve: Curves.elasticOut);

    _runProcessingScreen();
  }

  @override
  void dispose() {
    _amtCtrl.dispose();
    _checkCtrl.dispose();
    super.dispose();
  }

  Future<void> _runProcessingScreen() async {
    // Run checks one by one
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
    if (!mounted) return;
    setState(() => _rainfallRisk = 8);

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() => _floodZone = 5);

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() {
      _safeDiscount = 3;
      _premReady    = true;
    });
    HapticFeedback.mediumImpact();

    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    setState(() => _screen = 2); // claim summary
  }

  int get _finalPrem =>
    _basePrem + _rainfallRisk + _floodZone - _safeDiscount;

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
      case 3: return _payoutScreen();
      case 4: return _successScreen();
      default: return _processingScreen();
    }
  }

  // ── Screen 1: Processing ────────────────────────────────────
  Widget _processingScreen() => Padding(
    key: const ValueKey('processing'),
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _backBtn(),
        const SizedBox(height: 16),

        // Header
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
          style: const TextStyle(
            color: Colors.white54, fontSize: 14)),

        const SizedBox(height: 40),

        // Trigger badge
        Container(
          width:   double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFFF5252).withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFFF5252).withOpacity(0.3))),
          child: Row(children: [
            const Text('🌧', style: TextStyle(fontSize: 32)),
            const SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Text(_triggerName,
                style: const TextStyle(color: Colors.white,
                  fontSize: 18, fontWeight: FontWeight.w800)),
              Text('$_zone · Disruption detected',
                style: const TextStyle(
                  color: Colors.white54, fontSize: 12)),
            ]),
          ]),
        ),

        const SizedBox(height: 20),

        // Processing Screen label
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color:        Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(8)),
          child: const Text('Processing Screen',
            style: TextStyle(color: Colors.white38,
              fontSize: 11, letterSpacing: 0.8))),
        const SizedBox(height: 16),

        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Checks
                ..._checks.asMap().entries.map((e) {
                  final idx   = e.key;
                  final check = e.value;
                  final done  = _checksDone > idx;
                  final color = check['color'] as Color;
                  final isFraudItem = check['isFraud'] == true;

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
                          done
                            ? (isFraudItem ? Icons.close_rounded : Icons.check_rounded)
                            : check['icon'] as IconData,
                          color: done ? color : Colors.white24,
                          size: 18)),
                      const SizedBox(width: 14),
                      Expanded(child: Text(check['label'] as String,
                        style: TextStyle(
                          color:      done ? Colors.white : Colors.white38,
                          fontSize:   15,
                          fontWeight: done ? FontWeight.w600 : FontWeight.w400))),
                      if (done)
                        Icon(
                          isFraudItem ? Icons.cancel_rounded : Icons.check_circle_rounded,
                          color: color, size: 20),
                    ]),
                  );
                }),

                // ── FRAUD IMPACT CARD ──────────────────────────────
                if (_isFraud && _checksDone >= 4) ...[
                  const SizedBox(height: 8),
                  AnimatedOpacity(
                    opacity: _checksDone >= 4 ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 500),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5252).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFF5252).withOpacity(0.3)),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Row(children: [
                          Icon(Icons.warning_amber_rounded, color: Color(0xFFFF5252), size: 18),
                          SizedBox(width: 8),
                          Text('Fraud Detection Report',
                            style: TextStyle(color: Color(0xFFFF5252), fontSize: 14, fontWeight: FontWeight.w700)),
                        ]),
                        const SizedBox(height: 10),
                        _fraudInfoRow('Reason', _fraudReason ?? 'Suspicious activity'),
                        const SizedBox(height: 6),
                        _fraudInfoRow('Status', (_claimStatus ?? 'fraud_review').toUpperCase()),
                        const SizedBox(height: 6),
                        _fraudInfoRow('ML Score', '${widget.triggers.firstOrNull?['fraud_score'] ?? '—'} / 100'),
                        const SizedBox(height: 6),
                        _fraudInfoRow('Probability', widget.triggers.firstOrNull?['fraud_probability']?.toString() ?? '—'),
                        const SizedBox(height: 6),
                        _fraudInfoRow('Impact', 'Payout held for manual review'),
                        const SizedBox(height: 6),
                        _fraudInfoRow('Action', 'Escalated to admin panel'),
                      ]),
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Auto label
                Center(child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                  const Icon(Icons.auto_awesome_rounded,
                    color: Colors.white24, size: 14),
                  const SizedBox(width: 6),
                  Text(_isFraud ? 'Fraud review in progress...' : 'Processing automatically...',
                    style: const TextStyle(color: Colors.white24, fontSize: 12)),
                ])),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _fraudInfoRow(String label, String value) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 95,
        child: Text('$label:',
          style: const TextStyle(color: Color(0xFFFF8A80), fontSize: 12, fontWeight: FontWeight.w600)),
      ),
      Expanded(child: Text(value,
        style: const TextStyle(color: Colors.white70, fontSize: 12))),
    ],
  );

  // ── Screen 2: Dynamic Premium Calculation ──────────────────
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

        // Section label
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color:        Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(8)),
          child: const Text('Dynamic Premium Calculation Screen',
            style: TextStyle(color: Colors.white38,
              fontSize: 11, letterSpacing: 0.8))),
        const SizedBox(height: 20),

        // Calculation breakdown
        _darkCard(child: Column(children: [

          _calcRow('Base Premium',
            '₹$_basePrem', Colors.white60, false),
          const SizedBox(height: 8),
          Divider(color: Colors.white.withOpacity(0.06)),
          const SizedBox(height: 8),

          // Animated risk additions
          AnimatedOpacity(
            opacity: _rainfallRisk > 0 ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 400),
            child: Column(children: [
              _calcRow('+ Rainfall risk',
                '+₹$_rainfallRisk', gold, true),
              const SizedBox(height: 8),
            ])),

          AnimatedOpacity(
            opacity: _floodZone > 0 ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 400),
            child: Column(children: [
              _calcRow('+ Flood zone',
                '+₹$_floodZone', gold, true),
              const SizedBox(height: 8),
            ])),

          AnimatedOpacity(
            opacity: _safeDiscount > 0 ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 400),
            child: Column(children: [
              _calcRow('- Safe history',
                '-₹$_safeDiscount',
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

        // Auto advance note
        if (_premReady)
          Center(child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
            const Icon(Icons.auto_awesome_rounded,
              color: Colors.white24, size: 14),
            const SizedBox(width: 6),
            const Text('Advancing to claim summary...',
              style: TextStyle(color: Colors.white24, fontSize: 12)),
          ])),
      ],
    ),
  );

  // ── Screen 3: Claim Summary ─────────────────────────────────
  Widget _summaryScreen() {
    final mp       = (widget.policy?['max_payout'] ?? 900) as num;
    final daysAff  = 3;
    final dailyInc = (widget.policy?['avg_daily_income'] ?? 800) as num;
    final incLost  = dailyInc * daysAff;
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

        // Section label
        Align(alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color:        Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(8)),
            child: const Text('Claim Summary Screen',
              style: TextStyle(color: Colors.white38,
                fontSize: 11, letterSpacing: 0.8)))),
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
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
            const Text('Total Claimable',
              style: TextStyle(color: Colors.white, fontSize: 18,
                fontWeight: FontWeight.w800)),
            Text('₹$_totalPayout',
              style: const TextStyle(color: Color(0xFFF5A623),
                fontSize: 26, fontWeight: FontWeight.w900)),
          ]),
        ])),

        const Spacer(),

        // Auto label
        const Center(child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
          Icon(Icons.auto_awesome_rounded,
            color: Colors.white24, size: 14),
          SizedBox(width: 6),
          Text('(auto)', style: TextStyle(
            color: Colors.white24, fontSize: 12)),
        ])),
        const SizedBox(height: 16),

        // Claim Now button
        GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            setState(() => _screen = 3);
            _runPayoutScreen();
          },
          child: Container(
            width:   double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 17),
            decoration: BoxDecoration(
              color:        gold,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(
                color:      gold.withOpacity(0.4),
                blurRadius: 20,
                offset:     const Offset(0, 8))]),
            child: Center(child: Text(
              'Claim ₹$_totalPayout Now →',
              style: const TextStyle(color: Color(0xFF0D1829),
                fontSize: 16, fontWeight: FontWeight.w900))),
          ),
        ),
      ]),
    );
  }

  Future<void> _runPayoutScreen() async {
    // Auto advance after showing payout animation
    await Future.delayed(const Duration(milliseconds: 3500));
    if (!mounted) return;
    _amtCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;
    setState(() => _screen = 4);
    HapticFeedback.heavyImpact();
  }

  // ── Screen 4: UPI Payout Processing ────────────────────────
  Widget _payoutScreen() {
    final upi = widget.policy?['upi_id'] ?? 'worker@upi';

    return Padding(
      key: const ValueKey('payout'),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
        const SizedBox(height: 40),

        // Section label
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color:        Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(8)),
          child: const Text('Razorpay UPI Payout',
            style: TextStyle(color: Colors.white38,
              fontSize: 11, letterSpacing: 0.8))),
        const SizedBox(height: 20),

        // Razorpay badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF072654), Color(0xFF0A3D7A)]),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF2E86DE).withOpacity(0.4))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4)),
              child: const Text('Razorpay',
                style: TextStyle(color: Color(0xFF072654),
                  fontSize: 12, fontWeight: FontWeight.w900))),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: gold.withOpacity(0.2),
                borderRadius: BorderRadius.circular(99)),
              child: const Text('TEST MODE',
                style: TextStyle(color: Color(0xFFF5A623),
                  fontSize: 8, fontWeight: FontWeight.bold,
                  letterSpacing: 1))),
          ])),
        const SizedBox(height: 20),

        // Pulsing logo
        Container(
          width: 90, height: 90,
          decoration: BoxDecoration(
            color:  const Color(0xFF2E86DE).withOpacity(0.12),
            shape:  BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF2E86DE).withOpacity(0.4), width: 2)),
          child: const Icon(Icons.account_balance_wallet_rounded,
            color: Color(0xFF2E86DE), size: 44)),

        const SizedBox(height: 28),

        const Text('Razorpay processing UPI payout',
          style: TextStyle(color: Colors.white54, fontSize: 15)),
        const SizedBox(height: 8),

        // Animated amount
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

        // Steps
        _payoutStep('Razorpay processing...', true,
          const Color(0xFF2E86DE)),
        const SizedBox(height: 8),

        Row(children: [
          const SizedBox(width: 2),
          Container(width: 2, height: 20,
            color: Colors.white.withOpacity(0.1)),
        ]),
        const SizedBox(height: 4),

        _payoutStep('Initiating UPI transfer', false, gray),
        const SizedBox(height: 8),
        _payoutStep('Crediting via Razorpay', false, gray),

        const Spacer(),

        const Center(child: Text('(auto)',
          style: TextStyle(color: Colors.white24, fontSize: 12))),
      ]),
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

  // ── Screen 5: Success ───────────────────────────────────────
  Widget _successScreen() {
    final upi = widget.policy?['upi_id'] ?? 'worker@upi';

    return SingleChildScrollView(
      key: const ValueKey('success'),
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        const SizedBox(height: 40),

        // Section label
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color:        Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(8)),
          child: const Text('Success Screen',
            style: TextStyle(color: Colors.white38,
              fontSize: 11, letterSpacing: 0.8))),
        const SizedBox(height: 32),

        // Big checkmark
        Container(
          width: 100, height: 100,
          decoration: BoxDecoration(
            color:  const Color(0xFF00C853).withOpacity(0.12),
            shape:  BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF00C853).withOpacity(0.4),
              width: 2)),
          child: const Icon(Icons.check_rounded,
            color: Color(0xFF00C853), size: 54)),

        const SizedBox(height: 20),

        Text('₹$_totalPayout credited via Razorpay',
          style: const TextStyle(color: Color(0xFF00C853),
            fontSize: 18, fontWeight: FontWeight.w800)),

        const SizedBox(height: 4),
        Text(upi, style: const TextStyle(
          color: Colors.white54, fontSize: 13)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF2E86DE).withOpacity(0.15),
            borderRadius: BorderRadius.circular(99)),
          child: const Text('Powered by Razorpay',
            style: TextStyle(color: Color(0xFF2E86DE),
              fontSize: 11, fontWeight: FontWeight.w700))),

        const SizedBox(height: 24),

        _darkCard(child: Column(children: [
          _sumRow('✅ Claim ID', _claimId, const Color(0xFF00C853)),
          _div(),
          _sumRow('Transaction', _txnId, Colors.white70),
          _div(),
          _sumRow('Trigger', _triggerName, Colors.white70),
          _div(),
          _sumRow('Zone', _zone, Colors.white70),
          _div(),
          _sumRow('Amount', '₹$_totalPayout', gold),
          _div(),
          _sumRow('Gateway', 'Razorpay (Test Mode)', const Color(0xFF2E86DE)),
          _div(),
          _sumRow('Method', 'UPI Instant Payout', Colors.white70),
          _div(),
          _sumRow('Status', '✅ Credited',
            const Color(0xFF00C853)),
        ])),

        const SizedBox(height: 32),

        // Back to home
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
                blurRadius: 16,
                offset:     const Offset(0, 6))]),
            child: const Center(child: Text('Back to Home',
              style: TextStyle(color: Color(0xFF0D1829),
                fontSize: 16, fontWeight: FontWeight.w900))),
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () {},
          child: Container(
            width:   double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withOpacity(0.1))),
            child: const Center(child: Text(
              'Download Receipt',
              style: TextStyle(color: Colors.white54,
                fontSize: 14, fontWeight: FontWeight.w500))),
          ),
        ),
      ]),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────
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
          border: Border.all(
            color: Colors.white.withOpacity(0.1))),
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
          color:    highlight ? Colors.white70 : Colors.white54,
          fontSize: 14)),
        Text(v, style: TextStyle(color: c,
          fontSize: 15, fontWeight: FontWeight.w700)),
      ]),
    );

  Widget _sumRow(String l, String v, Color c) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
      Text(l, style: const TextStyle(
        color: Colors.white38, fontSize: 13)),
      Flexible(child: Text(v, textAlign: TextAlign.right,
        style: TextStyle(color: c,
          fontSize: 13, fontWeight: FontWeight.w600))),
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
      border: Border.all(
        color: Colors.white.withOpacity(0.08))),
    child: child,
  );
}
