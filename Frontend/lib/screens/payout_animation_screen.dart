import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PayoutAnimationScreen extends StatefulWidget {
  final String    triggerName;
  final String    zone;
  final String    severity;
  final int       amount;
  final String    workerName;
  final VoidCallback? onComplete;

  const PayoutAnimationScreen({
    super.key,
    required this.triggerName,
    required this.zone,
    required this.severity,
    required this.amount,
    required this.workerName,
    this.onComplete,
  });
  @override
  State<PayoutAnimationScreen> createState() =>
    _PayoutAnimationScreenState();
}

class _PayoutAnimationScreenState
    extends State<PayoutAnimationScreen>
    with TickerProviderStateMixin {

  static const navy = Color(0xFF1A2E6E);
  static const gold = Color(0xFFF5A623);

  int  _step = 0;
  bool _done = false;

  late AnimationController _pulseCtrl;
  late AnimationController _scaleCtrl;
  late AnimationController _amtCtrl;
  late Animation<double>   _pulse;
  late Animation<double>   _scale;
  late Animation<double>   _amtAnim;

  final List<Map<String, dynamic>> _steps = [
    {'label': 'Disruption detected',
      'icon': Icons.warning_amber_rounded,
      'color': Color(0xFFFF5252)},
    {'label': 'Worker activity verified',
      'icon': Icons.location_on_rounded,
      'color': Color(0xFF4B9FFF)},
    {'label': 'Fraud check passed',
      'icon': Icons.verified_rounded,
      'color': Color(0xFF9C6FFF)},
    {'label': 'Razorpay processing payout...',
      'icon': Icons.account_balance_wallet_rounded,
      'color': Color(0xFF2E86DE)},
  ];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1000))
      ..repeat(reverse: true);
    _pulse = Tween(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _scaleCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600));
    _scale = CurvedAnimation(
      parent: _scaleCtrl, curve: Curves.elasticOut);
    _amtCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1500));
    _amtAnim = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _amtCtrl, curve: Curves.easeOut));
    _runSequence();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _scaleCtrl.dispose();
    _amtCtrl.dispose();
    super.dispose();
  }

  Future<void> _runSequence() async {
    for (int i = 0; i < _steps.length; i++) {
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      setState(() => _step = i + 1);
      HapticFeedback.lightImpact();
    }
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _done = true);
    _scaleCtrl.forward();
    _amtCtrl.forward();
    HapticFeedback.heavyImpact();
    _pulseCtrl.stop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1829),
      body: SafeArea(
        child: _done ? _payoutDone(context) : _timeline(context),
      ),
    );
  }

  Widget _timeline(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.close_rounded,
                color: Colors.white, size: 20)),
          ),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Processing Claim',
              style: TextStyle(color: Colors.white,
                fontSize: 18, fontWeight: FontWeight.w800)),
            Text(widget.triggerName,
              style: const TextStyle(
                color: Colors.white54, fontSize: 13)),
          ]),
        ]),
        const SizedBox(height: 40),
        Container(
          width:   double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color:        const Color(0xFFFF5252).withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border:       Border.all(
              color: const Color(0xFFFF5252).withOpacity(0.4))),
          child: Column(children: [
            const Icon(Icons.warning_rounded,
              color: Color(0xFFFF5252), size: 44),
            const SizedBox(height: 10),
            Text(widget.triggerName,
              style: const TextStyle(color: Colors.white,
                fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('${widget.zone} · Severity ${widget.severity}',
              style: const TextStyle(
                color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 12),
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) => Transform.scale(
                scale: _pulse.value,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5252).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(99)),
                  child: const Text('● Processing your claim...',
                    style: TextStyle(
                      color:      Color(0xFFFF5252),
                      fontSize:   13,
                      fontWeight: FontWeight.w600))),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 36),
        ..._steps.asMap().entries.map((e) {
          final idx   = e.key;
          final s     = e.value;
          final done  = _step > idx;
          final color = s['color'] as Color;
          return Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Row(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color:  done
                    ? color : Colors.white.withOpacity(0.05),
                  shape:  BoxShape.circle,
                  border: Border.all(
                    color: done
                      ? color : Colors.white.withOpacity(0.15),
                    width: 1.5)),
                child: Icon(
                  done ? Icons.check_rounded
                    : s['icon'] as IconData,
                  color: done ? Colors.white
                    : Colors.white.withOpacity(0.3),
                  size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s['label'] as String,
                    style: TextStyle(
                      color:      done ? Colors.white
                        : Colors.white38,
                      fontSize:   15,
                      fontWeight: done ? FontWeight.w700
                        : FontWeight.w400)),
                  if (done)
                    const Text('Completed',
                      style: TextStyle(
                        color: Colors.white38, fontSize: 12)),
                ],
              )),
              if (done)
                Icon(Icons.check_circle_rounded,
                  color: color, size: 20),
            ]),
          );
        }),
      ],
    ),
  );

  Widget _payoutDone(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(children: [
      const Spacer(),
      ScaleTransition(
        scale: _scale,
        child: Column(children: [
          Container(
            width: 120, height: 120,
            decoration: BoxDecoration(
              shape:  BoxShape.circle,
              color:  gold.withOpacity(0.12),
              border: Border.all(
                color: gold.withOpacity(0.4), width: 2)),
            child: const Icon(Icons.check_rounded,
              color: gold, size: 60),
          ),
          const SizedBox(height: 24),
          const Text('Payout Approved!',
            style: TextStyle(color: Colors.white,
              fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          AnimatedBuilder(
            animation: _amtAnim,
            builder: (_, __) {
              final shown =
                (widget.amount * _amtAnim.value).round();
              return Text('₹$shown',
                style: const TextStyle(
                  color:         gold,
                  fontSize:      72,
                  fontWeight:    FontWeight.w900,
                  letterSpacing: -2));
            },
          ),
          const Text('credited via Razorpay UPI',
            style: TextStyle(
              color: Colors.white54, fontSize: 16)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF2E86DE).withOpacity(0.15),
              borderRadius: BorderRadius.circular(99),
            ),
            child: const Text('Powered by Razorpay',
              style: TextStyle(
                color: Color(0xFF2E86DE),
                fontSize: 11,
                fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
      const SizedBox(height: 40),
      Container(
        width:   double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.12))),
        child: Column(children: [
          _sumRow('Worker',   widget.workerName),
          _sumRow('Trigger',  widget.triggerName),
          _sumRow('Zone',     widget.zone),
          _sumRow('Amount',   '₹${widget.amount}'),
          _sumRow('Gateway',  'Razorpay (Test Mode)'),
          _sumRow('Method',   'UPI Instant Payout'),
          _sumRow('Status',   '✓ Completed'),
        ]),
      ),
      const Spacer(),
      GestureDetector(
        onTap: () {
          if (widget.onComplete != null) {
            widget.onComplete!();
          } else {
            Navigator.pop(context);
          }
},
        child: Container(
          width:   double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color:        gold,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(
              color:      gold.withOpacity(0.4),
              blurRadius: 20,
              offset:     const Offset(0, 8))]),
          child: const Center(child: Text(
            'View Receipt →',
            style: TextStyle(
              color:      Color(0xFF1A2E6E),
              fontSize:   17,
              fontWeight: FontWeight.w900))),
        ),
      ),
      const SizedBox(height: 12),
    ]),
  );

  Widget _sumRow(String l, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(l, style: const TextStyle(
          color: Colors.white38, fontSize: 13)),
        Text(v, style: TextStyle(
          color: v.startsWith('✓')
            ? const Color(0xFF00C853) : Colors.white,
          fontSize: 13, fontWeight: FontWeight.w700)),
      ],
    ),
  );
}
