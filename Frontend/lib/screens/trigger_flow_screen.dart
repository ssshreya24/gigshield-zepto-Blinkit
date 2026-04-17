import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import '../services/claim_receipt_generator.dart';

// ═══════════════════════════════════════════════════════════════════
// EXACT FLOW FROM SPEC IMAGE:
// Screen 0: Processing (4 auto checks)
// Screen 1: Dynamic Premium Calculation (Base ₹50 + Rainfall risk +₹8 + Flood zone +₹5 - Safe history -₹3)
// Screen 2: Claim Summary (Disruption / Days affected / Income lost / Policy covers % / Total Claimable)
// Screen 3: UPI Payout (Sending ₹X → upi@id  + card + saved methods)
// Screen 4: Success (✅ credited + Claim ID)
// Back to Home → popUntil(first)   NOT logout
// ═══════════════════════════════════════════════════════════════════

class TriggerFlowScreen extends StatefulWidget {
  final String triggerLabel;   // e.g. "Heavy Rain (T2)"
  final String triggerType;    // e.g. "heavy_rain"
  final String severity;       // T1 / T2 / T3
  final String zone;           // e.g. "Koramangala"
  final String workerName;
  final String upiId;
  final int    maxPayout;
  final int    dailyIncome;

  const TriggerFlowScreen({
    super.key,
    required this.triggerLabel,
    required this.triggerType,
    required this.severity,
    required this.zone,
    required this.workerName,
    required this.upiId,
    required this.maxPayout,
    required this.dailyIncome,
  });

  @override
  State<TriggerFlowScreen> createState() => _TriggerFlowScreenState();
}

class _TriggerFlowScreenState extends State<TriggerFlowScreen>
    with TickerProviderStateMixin {

  static const bg   = Color(0xFFE8EDFF);
  static const navy = Color(0xFF1A2E6E);
  static const gold = Color(0xFFF5A623);
  static const gray = Color(0xFF7A8BB0);
  static const bdr  = Color(0xFFCDD8F6);
  static const grn  = Color(0xFF00C853);
  static const red  = Color(0xFFFF5252);

  int  _screen        = 0;
  int  _checks        = 0;
  bool _downloading   = false;
  String _selMethod   = 'upi'; // selected payment method

  // Screen 1 — premium breakdown animated in one by one
  int  _rainRisk  = 0;
  int  _floodZone = 0;
  int  _safeDisc  = 0;
  bool _premReady = false;

  // Screen 3 — UPI amount counter
  late AnimationController _amtCtrl;
  late Animation<double>   _amtAnim;

  // Derived
  late int    _payout;
  late int    _daysAffected;
  late int    _incomeLost;
  late int    _coverPct;
  late String _claimId;
  late String _txnId;

  final List<Map<String, dynamic>> _checks4 = [
    {'label': 'Weather API verified',   'color': Color(0xFF4B9FFF)},
    {'label': 'Zone risk confirmed',    'color': Color(0xFF9C6FFF)},
    {'label': 'Policy active',          'color': Color(0xFF00C853)},
    {'label': 'Eligibility confirmed',  'color': Color(0xFFF5A623)},
  ];

  @override
  void initState() {
    super.initState();

    // Calculate all amounts
    final pctMap = {'T1': 0.25, 'T2': 0.50, 'T3': 1.00};
    final pct    = pctMap[widget.severity] ?? 0.50;
    _payout      = (widget.maxPayout * pct).round();
    _daysAffected = 3;
    _incomeLost  = widget.dailyIncome * _daysAffected;
    _coverPct    = widget.severity == 'T1' ? 25
                 : widget.severity == 'T2' ? 50 : 80;

    final now = DateTime.now();
    _claimId = 'CLM-${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}${now.millisecond.toString().padLeft(3,'0')}';
    _txnId   = 'TXN${now.millisecondsSinceEpoch.toString().substring(6)}';

    _amtCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1800));
    _amtAnim = CurvedAnimation(parent: _amtCtrl, curve: Curves.easeOut);

    _runScreen0();
  }

  Future<void> _downloadReceipt() async {
    setState(() => _downloading = true);
    try {
      final triggerEntry = <String, dynamic>{
        'name':     _triggerName(),
        'severity': widget.severity,
        'pct':      _coverPct,
        'icon':     Icons.bolt_rounded,
        'color':    const Color(0xFF4B9FFF),
      };
      final policy = <String, dynamic>{
        'name':      widget.workerName,
        'zone':      widget.zone,
        'platform':  'Delivery',
        'plan_type': 'standard',
        'id':        1,
        'worker_id': 1,
      };
      await ClaimReceiptGenerator.generate(
        total:    _payout,
        triggers: [triggerEntry],
        amounts:  [_payout],
        policy:   policy,
        upiId:    widget.upiId,
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
  void dispose() { _amtCtrl.dispose(); super.dispose(); }

  // ── SCREEN 0: Processing (auto) ───────────────────────────
  Future<void> _runScreen0() async {
    for (int i = 0; i < _checks4.length; i++) {
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      setState(() => _checks = i + 1);
      HapticFeedback.lightImpact();
    }
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() => _screen = 1);
    _runScreen1();
  }

  // ── SCREEN 1: Dynamic Premium Calc (auto, animated) ──────
  Future<void> _runScreen1() async {
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() => _rainRisk = 8);

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _floodZone = 5);

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() { _safeDisc = 3; _premReady = true; });
    HapticFeedback.mediumImpact();

    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;
    setState(() => _screen = 2);
  }

  int get _finalPrem => 50 + _rainRisk + _floodZone - _safeDisc;

  // ── SCREEN 4: UPI payout animation (auto, called from payment screen) ─────
  Future<void> _goToPayout() async {
    setState(() => _screen = 4);
    HapticFeedback.mediumImpact();
    _amtCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 3500));
    if (!mounted) return;
    setState(() => _screen = 5);
    HapticFeedback.heavyImpact();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim, child: child),
        child: _buildScreen(),
      ),
    );
  }

  Widget _buildScreen() {
    switch (_screen) {
      case 0: return _s0Processing();
      case 1: return _s1Premium();
      case 2: return _s2Summary();
      case 3: return _s3PaymentMethod();  // NEW: payment selection
      case 4: return _s4Payout();         // was screen 3
      case 5: return _s5Success();         // was screen 4
      default: return _s0Processing();
    }
  }

  // ══════════════════════════════════════════════════════════
  // SCREEN 0 — Processing Screen
  // ══════════════════════════════════════════════════════════
  Widget _s0Processing() => SafeArea(
    key: const ValueKey('s0'),
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _backBtn(),
          const SizedBox(height: 8),
          _screenTag('Processing Screen'),
          const SizedBox(height: 20),

          // Popup / alert box  (like image: "🌧 Heavy Rainfall 84mm detected in your zone — Claim Now")
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: red.withOpacity(0.07),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: red.withOpacity(0.22))),
            child: Row(children: [
              Text(_triggerEmoji(), style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${_triggerName()} detected',
                    style: const TextStyle(color: navy, fontSize: 15,
                      fontWeight: FontWeight.w800)),
                  Text('${widget.zone} — Claim Now',
                    style: const TextStyle(color: gray, fontSize: 13)),
                ],
              )),
            ]),
          ),

          const SizedBox(height: 32),

          // 4 checks
          ..._checks4.asMap().entries.map((e) {
            final i     = e.key;
            final check = e.value;
            final done  = _checks > i;
            final color = check['color'] as Color;
            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Row(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: done ? color.withOpacity(0.12)
                               : Colors.white.withOpacity(0.5),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: done ? color.withOpacity(0.4) : bdr)),
                  child: Icon(
                    done ? Icons.check_rounded : Icons.radio_button_unchecked_rounded,
                    color: done ? color : gray, size: 18)),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(check['label'] as String,
                    style: TextStyle(
                      color:      done ? navy : gray,
                      fontSize:   15,
                      fontWeight: done ? FontWeight.w700 : FontWeight.w400))),
                if (done)
                  Icon(Icons.check_circle_rounded, color: color, size: 20),
              ]),
            );
          }),

          const Spacer(),
          _autoTag(),
        ],
      ),
    ),
  );

  // ══════════════════════════════════════════════════════════
  // SCREEN 1 — Dynamic Premium Calculation Screen
  // ══════════════════════════════════════════════════════════
  Widget _s1Premium() => SafeArea(
    key: const ValueKey('s1'),
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _backBtn(),
          const SizedBox(height: 8),
          _screenTag('Dynamic Premium Calculation Screen'),
          const SizedBox(height: 24),

          _glassCard(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Base Premium ₹50
              _premRow('Base Premium', '₹50', navy, bold: true),
              const SizedBox(height: 12),
              const Divider(color: bdr, height: 1),
              const SizedBox(height: 12),

              // + Rainfall risk  +₹8
              AnimatedOpacity(
                opacity: _rainRisk > 0 ? 1 : 0,
                duration: const Duration(milliseconds: 400),
                child: Column(children: [
                  _premRow('+ Rainfall risk', '+₹$_rainRisk', gold),
                  const SizedBox(height: 10),
                ])),

              // + Flood zone  +₹5
              AnimatedOpacity(
                opacity: _floodZone > 0 ? 1 : 0,
                duration: const Duration(milliseconds: 400),
                child: Column(children: [
                  _premRow('+ Flood zone', '+₹$_floodZone', gold),
                  const SizedBox(height: 10),
                ])),

              // - Safe history  -₹3
              AnimatedOpacity(
                opacity: _safeDisc > 0 ? 1 : 0,
                duration: const Duration(milliseconds: 400),
                child: Column(children: [
                  _premRow('- Safe history', '-₹$_safeDisc', grn),
                  const SizedBox(height: 10),
                ])),

              if (_premReady) ...[
                const SizedBox(height: 2),
                Container(
                  height: 1,
                  color: navy.withOpacity(0.15),
                  margin: const EdgeInsets.symmetric(vertical: 4)),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Final Premium',
                      style: TextStyle(color: navy, fontSize: 17,
                        fontWeight: FontWeight.w900)),
                    Text('₹$_finalPrem/week',
                      style: const TextStyle(color: gold, fontSize: 22,
                        fontWeight: FontWeight.w900)),
                  ],
                ),
              ],
            ],
          )),

          const Spacer(),
          _autoTag(),
        ],
      ),
    ),
  );

  // ══════════════════════════════════════════════════════════
  // SCREEN 2 — Claim Summary Screen
  // ══════════════════════════════════════════════════════════
  Widget _s2Summary() => SafeArea(
    key: const ValueKey('s2'),
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _backBtn(),
          const SizedBox(height: 8),
          _screenTag('Claim Summary Screen'),
          const SizedBox(height: 20),

          _glassCard(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sumRow('Disruption', _triggerName(), navy),
              _sdiv(),
              _sumRow('Days affected', '$_daysAffected days', gray),
              _sdiv(),
              _sumRow('Income lost', '₹$_incomeLost', red),
              _sdiv(),
              _sumRow('Policy covers', '$_coverPct%',
                const Color(0xFF4B9FFF)),
              _sdiv(),
              const SizedBox(height: 4),
              const Divider(color: bdr),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Claimable',
                    style: TextStyle(color: navy, fontSize: 16,
                      fontWeight: FontWeight.w800)),
                  Text('₹$_payout',
                    style: const TextStyle(color: gold, fontSize: 26,
                      fontWeight: FontWeight.w900)),
                ],
              ),
            ],
          )),

          const Spacer(),
          _autoTag(),
          const SizedBox(height: 16),

          // Claim ₹X Now → go to payment method selection (screen 3)
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
                  color:      gold.withOpacity(0.5),
                  blurRadius: 20, offset: const Offset(0, 8))]),
              child: Center(child: Text(
                'Claim ₹$_payout Now →',
                style: const TextStyle(color: Color(0xFF0D1829),
                  fontSize: 16, fontWeight: FontWeight.w900))),
            ),
          ),
        ],
      ),
    ),
  );

  // ══════════════════════════════════════════════════════════
  // SCREEN 3 — Payment Method Selection (NEW)
  // ══════════════════════════════════════════════════════════
  Widget _s3PaymentMethod() => SafeArea(
    key: const ValueKey('s3pay'),
    child: Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _screen = 2),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withOpacity(0.15))),
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
                  Text('Receive your payout of ₹$_payout',
                    style: TextStyle(color: Colors.white.withOpacity(0.5),
                      fontSize: 12)),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Payout amount banner
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: gold.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: gold.withOpacity(0.35))),
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet_rounded,
                  color: gold, size: 26),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Payout amount',
                      style: TextStyle(color: Colors.white54, fontSize: 11)),
                    Text('₹$_payout',
                      style: const TextStyle(color: gold, fontSize: 26,
                        fontWeight: FontWeight.w900)),
                  ],
                ),
              ],
            ),
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
          child: Column(
            children: [
              _payOption('upi',   Icons.account_balance_wallet_rounded,
                const Color(0xFF4B9FFF), 'UPI', widget.upiId, 'Instant · Verified'),
              const SizedBox(height: 10),
              _payOption('card',  Icons.credit_card_rounded,
                const Color(0xFF9C6FFF), 'Debit Card', 'HDFC Bank •••• 4521',
                'Within 2 hours'),
              const SizedBox(height: 10),
              _payOption('gpay',  Icons.phone_android_rounded,
                const Color(0xFF00C853), 'Google Pay / PhonePe',
                widget.upiId, 'Instant UPI'),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Security note
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              const Icon(Icons.lock_rounded, color: Colors.white24, size: 13),
              const SizedBox(width: 6),
              Expanded(child: Text(
                'Payout secured by Insurify · 256-bit encryption · RBI compliant',
                style: TextStyle(color: Colors.white.withOpacity(0.25),
                  fontSize: 11))),
            ],
          ),
        ),

        const Spacer(),

        // Confirm button
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
          child: GestureDetector(
            onTap: _goToPayout,
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
                'Confirm & Receive ₹$_payout →',
                style: const TextStyle(color: Color(0xFF0D1829),
                  fontSize: 16, fontWeight: FontWeight.w900))),
            ),
          ),
        ),
      ],
    ),
  );

  // ══════════════════════════════════════════════════════════
  // SCREEN 4 — UPI Payout Screen (was screen 3)
  // ══════════════════════════════════════════════════════════
  Widget _s4Payout() => SafeArea(
    key: const ValueKey('s4pay'),
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _backBtn(),
          const SizedBox(height: 8),
          _screenTag('UPI Payout Screen'),
          const SizedBox(height: 20),

          // Animated amount
          Center(child: Column(children: [
            const SizedBox(height: 8),
            const Text('Sending to',
              style: TextStyle(color: gray, fontSize: 13)),
            const SizedBox(height: 4),
            AnimatedBuilder(
              animation: _amtAnim,
              builder: (_, __) {
                final shown = (_payout * _amtAnim.value).round();
                return Text('₹$shown',
                  style: const TextStyle(color: navy, fontSize: 58,
                    fontWeight: FontWeight.w900, letterSpacing: -2));
              }),
          ])),

          const SizedBox(height: 20),

          // Payout methods
          _glassCard(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('PAYMENT METHODS',
                style: TextStyle(color: gray, fontSize: 11,
                  fontWeight: FontWeight.w700, letterSpacing: 0.8)),
              const SizedBox(height: 14),

              // UPI (selected — primary)
              _payMethod(
                icon:     Icons.account_balance_wallet_rounded,
                color:    const Color(0xFF4B9FFF),
                title:    widget.upiId,
                subtitle: 'UPI ID',
                isSelected: true,
                badge:    '💚 Processing...',
              ),
              const SizedBox(height: 10),

              const Divider(color: bdr, height: 1),
              const SizedBox(height: 10),

              const Text('OTHER SAVED METHODS',
                style: TextStyle(color: gray, fontSize: 10,
                  fontWeight: FontWeight.w700, letterSpacing: 0.8)),
              const SizedBox(height: 10),

              // Saved bank card
              _payMethod(
                icon:     Icons.credit_card_rounded,
                color:    const Color(0xFF9C6FFF),
                title:    'HDFC Bank •••• 4521',
                subtitle: 'Debit card',
                isSelected: false,
              ),
              const SizedBox(height: 8),

              // Netbanking
              _payMethod(
                icon:     Icons.account_balance_rounded,
                color:    gold,
                title:    'SBI Net Banking',
                subtitle: 'Bank account',
                isSelected: false,
              ),
              const SizedBox(height: 8),

              // GPay / PhonePe
              _payMethod(
                icon:     Icons.phone_android_rounded,
                color:    grn,
                title:    'Google Pay',
                subtitle: 'UPI app',
                isSelected: false,
              ),
            ],
          )),

          const SizedBox(height: 16),
          Center(child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 8, height: 8,
                decoration: const BoxDecoration(
                  color: grn, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              const Text('Processing payment...',
                style: TextStyle(color: grn, fontSize: 13,
                  fontWeight: FontWeight.w600)),
            ],
          )),

          const SizedBox(height: 8),
          _autoTag(),
        ],
      ),
    ),
  );

  // ══════════════════════════════════════════════════════════
  // SCREEN 5 — Success Screen (was screen 4)
  // ══════════════════════════════════════════════════════════
  Widget _s5Success() => SafeArea(
    key: const ValueKey('s5success'),
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _backBtn(),
          const SizedBox(height: 8),
          _screenTag('Success Screen'),
          const SizedBox(height: 28),

          // Big tick
          Center(child: Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: grn.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: grn.withOpacity(0.4), width: 2)),
            child: const Icon(Icons.check_rounded,
              color: grn, size: 40))),

          const SizedBox(height: 16),
          Center(child: Text('₹$_payout credited to UPI',
            style: const TextStyle(color: grn, fontSize: 18,
              fontWeight: FontWeight.w800))),
          const SizedBox(height: 4),
          Center(child: Text(widget.upiId,
            style: const TextStyle(color: gray, fontSize: 13))),

          const SizedBox(height: 24),

          _glassCard(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.check_circle_rounded,
                  color: grn, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  '${_triggerName()} credited to UPI',
                  style: const TextStyle(color: navy, fontSize: 14,
                    fontWeight: FontWeight.w700))),
              ]),
              _sdiv(),
              _sumRow('Claim ID', _claimId, grn),
              _sdiv(),
              _sumRow('Transaction ID', _txnId, gray),
              _sdiv(),
              _sumRow('Worker', widget.workerName, navy),
              _sdiv(),
              _sumRow('Zone', widget.zone, navy),
              _sdiv(),
              _sumRow('Amount', '₹$_payout', gold),
            ],
          )),

          const Spacer(),

          // BACK TO HOME
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
              padding: const EdgeInsets.symmetric(vertical: 17),
              decoration: BoxDecoration(
                color:        gold,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(
                  color:      gold.withOpacity(0.4),
                  blurRadius: 16, offset: const Offset(0, 6))]),
              child: const Center(child: Text(
                'Back to Home',
                style: TextStyle(color: Color(0xFF0D1829),
                  fontSize: 16, fontWeight: FontWeight.w900))),
            ),
          ),

          const SizedBox(height: 12),

          // DOWNLOAD RECEIPT PDF
          GestureDetector(
            onTap: _downloading ? null : _downloadReceipt,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width:    double.infinity,
              padding:  const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.18))),
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
        ],
      ),
    ),
  );

  // ── HELPERS ──────────────────────────────────────────────

  String _triggerEmoji() {
    switch (widget.triggerType) {
      case 'heavy_rain':   return '🌧';
      case 'flood_alert':  return '🌊';
      case 'extreme_heat': return '🌡';
      case 'severe_aqi':   return '💨';
      case 'curfew':       return '🚫';
      default:             return '⚡';
    }
  }

  String _triggerName() {
    switch (widget.triggerType) {
      case 'heavy_rain':   return 'Heavy Rain';
      case 'flood_alert':  return 'Flood Alert';
      case 'extreme_heat': return 'Extreme Heat';
      case 'severe_aqi':   return 'Severe AQI';
      default:
        return widget.triggerLabel.split('(').first.trim();
    }
  }

  Widget _screenTag(String t) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      color:        navy.withOpacity(0.06),
      borderRadius: BorderRadius.circular(8),
      border:       Border.all(color: bdr)),
    child: Text(t, style: const TextStyle(
      color: gray, fontSize: 11,
      fontWeight: FontWeight.w700, letterSpacing: 0.5)),
  );

  Widget _autoTag() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(Icons.auto_awesome_rounded,
        color: gray.withOpacity(0.5), size: 12),
      const SizedBox(width: 5),
      Text('(auto)', style: TextStyle(
        color: gray.withOpacity(0.6), fontSize: 12)),
    ],
  );

  Widget _backBtn() => GestureDetector(
    onTap: () => Navigator.pop(context),
    child: Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        color:        Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: bdr)),
      child: const Icon(Icons.arrow_back_rounded, color: navy, size: 20)),
  );

  Widget _glassCard({required Widget child}) => Container(
    width:   double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color:        Colors.white.withOpacity(0.8),
      borderRadius: BorderRadius.circular(16),
      border:       Border.all(color: bdr),
      boxShadow: [BoxShadow(
        color:      const Color(0xFF7B9CFF).withOpacity(0.08),
        blurRadius: 16, offset: const Offset(0, 4))]),
    child: child,
  );

  Widget _premRow(String l, String v, Color c, {bool bold = false}) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(l, style: TextStyle(
            color: bold ? navy : gray,
            fontSize: bold ? 15 : 14,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
          Text(v, style: TextStyle(
            color: c, fontSize: bold ? 16 : 14,
            fontWeight: FontWeight.w700)),
        ],
      ),
    );

  Widget _sumRow(String l, String v, Color c) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 11),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(l, style: const TextStyle(color: gray, fontSize: 14)),
        Flexible(child: Text(v, style: TextStyle(color: c, fontSize: 14,
          fontWeight: FontWeight.w700),
          textAlign: TextAlign.right)),
      ],
    ),
  );

  Widget _sdiv() => const Divider(color: bdr, height: 1);

  Widget _payMethod({
    required IconData icon,
    required Color    color,
    required String   title,
    required String   subtitle,
    required bool     isSelected,
    String?           badge,
  }) =>
    Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isSelected
          ? navy.withOpacity(0.06)
          : Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? navy.withOpacity(0.3) : bdr,
          width: isSelected ? 1.5 : 1)),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color:        color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 22)),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(
              color: navy, fontSize: 14,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
            Text(subtitle, style: const TextStyle(
              color: gray, fontSize: 11)),
            if (badge != null) ...[
              const SizedBox(height: 4),
              Text(badge, style: TextStyle(
                color: grn, fontSize: 12,
                fontWeight: FontWeight.w600)),
            ],
          ],
        )),
        if (isSelected)
          const Icon(Icons.check_circle_rounded, color: grn, size: 20),
      ]),
    );

  // ── Selectable payment option tile for screen 3 ───────────
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
            color: sel ? color.withOpacity(0.6) : Colors.white.withOpacity(0.1),
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
                color: Colors.white,
                fontSize: 14,
                fontWeight: sel ? FontWeight.w800 : FontWeight.w500)),
              const SizedBox(height: 2),
              Text(detail, style: const TextStyle(
                color: Colors.white38, fontSize: 12)),
              const SizedBox(height: 2),
              Text(speed, style: TextStyle(
                color: color.withOpacity(0.8), fontSize: 11,
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
                border: Border.all(color: Colors.white24, width: 1.5))),
        ]),
      ),
    );
  }
}
