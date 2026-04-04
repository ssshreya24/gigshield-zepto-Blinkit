import 'dart:async';
import 'package:flutter/material.dart';
import 'trigger_detail_screen.dart';

class TriggerValidationScreen extends StatefulWidget {
  final List<Map<String, dynamic>> claimableTriggers;
  final Map<String, dynamic>?      policy;

  const TriggerValidationScreen({
    super.key,
    required this.claimableTriggers,
    this.policy,
  });
  @override
  State<TriggerValidationScreen> createState() =>
    _TriggerValidationScreenState();
}

class _TriggerValidationScreenState
    extends State<TriggerValidationScreen>
    with TickerProviderStateMixin {

  static const bg   = Color(0xFF0D1829);
  static const gold = Color(0xFFF5A623);
  static const gray = Color(0xFF7A8BB0);

  int     _currentStep = 0;
  bool    _done        = false;

  late AnimationController _pulseCtrl;
  late Animation<double>   _pulse;

  final List<Map<String, dynamic>> steps = [
    {
      'label': 'Fetching weather data',
      'sub':   'Connecting to OpenWeatherMap API...',
      'icon':  Icons.cloud_download_rounded,
      'color': Color(0xFF4B9FFF),
    },
    {
      'label': 'Checking govt alert data',
      'sub':   'Verifying official disaster notifications...',
      'icon':  Icons.policy_rounded,
      'color': Color(0xFF9C6FFF),
    },
    {
      'label': 'Validating policy rules',
      'sub':   'Matching triggers against your coverage...',
      'icon':  Icons.shield_rounded,
      'color': Color(0xFF00C853),
    },
    {
      'label': 'Running fraud check',
      'sub':   'GPS verification · duplicate detection...',
      'icon':  Icons.verified_user_rounded,
      'color': Color(0xFFF5A623),
    },
    {
      'label': 'Estimating claim amounts',
      'sub':   'Calculating payout for each trigger...',
      'icon':  Icons.calculate_rounded,
      'color': Color(0xFF00C853),
    },
  ];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulse = Tween(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _runSteps();
  }

  @override
  void dispose() { _pulseCtrl.dispose(); super.dispose(); }

  Future<void> _runSteps() async {
    for (int i = 0; i < steps.length; i++) {
      await Future.delayed(const Duration(milliseconds: 1000));
      if (!mounted) return;
      setState(() => _currentStep = i + 1);
    }
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _done = true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    Navigator.pushReplacement(context,
      MaterialPageRoute(
        builder: (_) => TriggerDetailScreen(
          triggers:       widget.claimableTriggers,
          currentIndex:   0,
          policy:         widget.policy,
          collectedAmounts: [],
        )));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: bg,
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),

            // Header
            const Text('Validating your claim',
              style: TextStyle(color: Colors.white, fontSize: 26,
                fontWeight: FontWeight.w900, letterSpacing: -0.5)),
            const SizedBox(height: 6),
            Text(
              'AI is verifying real-time data for your zone',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14)),

            const SizedBox(height: 40),

            // Animated shield
            Center(
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (_, __) => Opacity(
                  opacity: _done ? 1.0 : _pulse.value,
                  child: Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                      color: _done
                        ? const Color(0xFF00C853).withOpacity(0.15)
                        : gold.withOpacity(0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _done
                          ? const Color(0xFF00C853).withOpacity(0.4)
                          : gold.withOpacity(0.4),
                        width: 2),
                    ),
                    child: Icon(
                      _done
                        ? Icons.check_rounded
                        : Icons.shield_rounded,
                      color: _done
                        ? const Color(0xFF00C853) : gold,
                      size: 48),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),

            // Steps
            ...steps.asMap().entries.map((e) {
              final idx   = e.key;
              final step  = e.value;
              final done  = _currentStep > idx;
              final color = step['color'] as Color;

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: done
                        ? color.withOpacity(0.15)
                        : Colors.white.withOpacity(0.04),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: done
                          ? color.withOpacity(0.5)
                          : Colors.white.withOpacity(0.1)),
                    ),
                    child: Icon(
                      done
                        ? Icons.check_rounded
                        : step['icon'] as IconData,
                      color: done ? color : Colors.white24,
                      size: 18),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(step['label'] as String,
                        style: TextStyle(
                          color:      done ? Colors.white : Colors.white38,
                          fontSize:   14,
                          fontWeight: done
                            ? FontWeight.w700 : FontWeight.w400)),
                      if (done)
                        Text(step['sub'] as String,
                          style: const TextStyle(
                            color: Colors.white38, fontSize: 11)),
                    ],
                  )),
                  if (done)
                    Icon(Icons.check_circle_rounded,
                      color: color, size: 18),
                ]),
              );
            }),

            const Spacer(),

            // Status bar
            Container(
              width:   double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.08)),
              ),
              child: Row(children: [
                const Icon(Icons.location_on_rounded,
                  color: gold, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  '${widget.policy?['zone'] ?? 'Koramangala'} · '
                  '${widget.claimableTriggers.length} triggers verified',
                  style: const TextStyle(
                    color: Colors.white60, fontSize: 13))),
                if (_done)
                  const Text('All checks passed',
                    style: TextStyle(
                      color: Color(0xFF00C853), fontSize: 12,
                      fontWeight: FontWeight.w700)),
              ]),
            ),
          ],
        ),
      ),
    ),
  );
}
