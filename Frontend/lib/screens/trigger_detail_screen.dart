import 'package:flutter/material.dart';
import 'claim_summary_screen.dart';

class TriggerDetailScreen extends StatefulWidget {
  final List<Map<String, dynamic>> triggers;
  final int                        currentIndex;
  final Map<String, dynamic>?      policy;
  final List<int>                  collectedAmounts;

  const TriggerDetailScreen({
    super.key,
    required this.triggers,
    required this.currentIndex,
    required this.policy,
    required this.collectedAmounts,
  });
  @override
  State<TriggerDetailScreen> createState() =>
    _TriggerDetailScreenState();
}

class _TriggerDetailScreenState
    extends State<TriggerDetailScreen>
    with TickerProviderStateMixin {

  static const bg   = Color(0xFF0D1829);
  static const gold = Color(0xFFF5A623);
  static const gray = Color(0xFF7A8BB0);

  late AnimationController _amtCtrl;
  late Animation<double>   _amtAnim;
  bool _amountVisible = false;

  Map<String, dynamic> get trigger =>
    widget.triggers[widget.currentIndex];

  bool get isLast =>
    widget.currentIndex == widget.triggers.length - 1;

  // Detailed breakdown per trigger type
  List<Map<String, dynamic>> get factors {
    switch (trigger['type']) {
      case 'heavy_rain':
        return [
          {'label': 'Rainfall recorded',  'value': '245 mm',     'weight': 0.35},
          {'label': 'Duration',            'value': '6 hours',    'weight': 0.20},
          {'label': 'Alert severity',      'value': 'Red alert',  'weight': 0.25},
          {'label': 'Area impact level',   'value': 'High',       'weight': 0.20},
        ];
      case 'flood_alert':
        return [
          {'label': 'Flood severity',      'value': 'Severe',     'weight': 0.40},
          {'label': 'Official warning',    'value': 'IMD issued', 'weight': 0.25},
          {'label': 'Damage probability',  'value': '87%',        'weight': 0.20},
          {'label': 'Area impact level',   'value': 'Critical',   'weight': 0.15},
        ];
      case 'curfew':
        return [
          {'label': 'Govt notification',   'value': 'Confirmed',  'weight': 0.40},
          {'label': 'Restriction duration','value': '12 hours',   'weight': 0.30},
          {'label': 'Reason',              'value': 'Flood/Rain', 'weight': 0.20},
          {'label': 'Policy clause',       'value': 'Section 4B', 'weight': 0.10},
        ];
      default:
        return [
          {'label': 'Severity level',      'value': 'High',       'weight': 0.40},
          {'label': 'Duration',            'value': '4 hours',    'weight': 0.30},
          {'label': 'Alert level',         'value': 'Orange',     'weight': 0.30},
        ];
    }
  }

  String get formula {
    switch (trigger['type']) {
      case 'heavy_rain':
        return 'Payout = MaxPayout × 50% × (Rainfall/Threshold) × AlertWeight';
      case 'flood_alert':
        return 'Payout = MaxPayout × 100% × SeverityFactor × AreaImpact';
      case 'curfew':
        return 'Payout = MaxPayout × 100% × DurationFactor × GovtVerified';
      default:
        return 'Payout = MaxPayout × Tier% × SeverityFactor';
    }
  }

  @override
  void initState() {
    super.initState();
    _amtCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200));
    _amtAnim = CurvedAnimation(
      parent: _amtCtrl, curve: Curves.easeOut);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() => _amountVisible = true);
        _amtCtrl.forward();
      }
    });
  }

  @override
  void dispose() { _amtCtrl.dispose(); super.dispose(); }

  void _goNext() {
    final newAmounts = [
      ...widget.collectedAmounts,
      trigger['amount'] as int,
    ];

    if (isLast) {
      Navigator.pushReplacement(context,
        MaterialPageRoute(
          builder: (_) => ClaimSummaryScreen(
            triggers:  widget.triggers,
            amounts:   newAmounts,
            policy:    widget.policy,
          )));
    } else {
      Navigator.pushReplacement(context,
        MaterialPageRoute(
          builder: (_) => TriggerDetailScreen(
            triggers:        widget.triggers,
            currentIndex:    widget.currentIndex + 1,
            policy:          widget.policy,
            collectedAmounts: newAmounts,
          )));
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = trigger['color'] as Color;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(children: [
          _header(color),
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _triggerBadge(color),
                const SizedBox(height: 20),
                _locationCard(),
                const SizedBox(height: 16),
                _factorsCard(color),
                const SizedBox(height: 16),
                _formulaCard(color),
                const SizedBox(height: 16),
                _amountCard(color),
              ],
            ),
          )),
          _nextBtn(color),
        ]),
      ),
    );
  }

  Widget _header(Color color) => Padding(
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
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Claim ${widget.currentIndex + 1} of ${widget.triggers.length}',
            style: const TextStyle(color: Colors.white60,
              fontSize: 12)),
          Text('${trigger['name']} Details',
            style: const TextStyle(color: Colors.white,
              fontSize: 18, fontWeight: FontWeight.w800)),
        ],
      )),
      // Progress dots
      Row(children: List.generate(widget.triggers.length, (i) =>
        Container(
          width: i == widget.currentIndex ? 20 : 6,
          height: 6, margin: const EdgeInsets.only(left: 4),
          decoration: BoxDecoration(
            color: i == widget.currentIndex
              ? color : Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(99)),
        ))),
    ]),
  );

  Widget _triggerBadge(Color color) => Container(
    width:   double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color:        color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(16),
      border:       Border.all(color: color.withOpacity(0.3)),
    ),
    child: Row(children: [
      Container(
        width: 52, height: 52,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(14)),
        child: Icon(trigger['icon'] as IconData,
          color: color, size: 28),
      ),
      const SizedBox(width: 16),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(trigger['name'] as String,
          style: const TextStyle(color: Colors.white,
            fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF00C853).withOpacity(0.15),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: const Color(0xFF00C853).withOpacity(0.4)),
          ),
          child: const Text('● Claimable · Active Now',
            style: TextStyle(color: Color(0xFF00C853),
              fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      ]),
    ]),
  );

  Widget _locationCard() => _darkCard(child: Column(children: [
    _row(Icons.location_on_rounded, 'Location detected',
      widget.policy?['zone'] ?? 'Your Zone'),
    _divider(),
    _row(Icons.schedule_rounded, 'Event time',
      'Today · ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2,'0')} IST'),
    _divider(),
    _row(Icons.verified_rounded, 'Data source',
      'OpenWeatherMap + IMD + Govt alerts'),
  ]));

  Widget _factorsCard(Color color) => _darkCard(child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Parameters used',
        style: TextStyle(color: Colors.white,
          fontSize: 14, fontWeight: FontWeight.w700)),
      const SizedBox(height: 14),
      ...factors.map((f) {
        final w = f['weight'] as double;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(f['label'] as String,
                    style: const TextStyle(
                      color: Colors.white60, fontSize: 13)),
                  Text(f['value'] as String,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value:           w,
                  backgroundColor: Colors.white.withOpacity(0.08),
                  valueColor:      AlwaysStoppedAnimation(color),
                  minHeight:       4,
                ),
              ),
              Text('Weight: ${(w * 100).round()}%',
                style: const TextStyle(
                  color: Colors.white24, fontSize: 10)),
            ],
          ),
        );
      }),
    ],
  ));

  Widget _formulaCard(Color color) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color:        color.withOpacity(0.06),
      borderRadius: BorderRadius.circular(12),
      border:       Border.all(color: color.withOpacity(0.2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Calculation formula',
          style: TextStyle(color: Colors.white54,
            fontSize: 11, fontWeight: FontWeight.w700,
            letterSpacing: 0.6)),
        const SizedBox(height: 6),
        Text(formula,
          style: TextStyle(
            color:    color,
            fontSize: 12,
            fontFamily: 'monospace')),
      ],
    ),
  );

  Widget _amountCard(Color color) => AnimatedOpacity(
    opacity:  _amountVisible ? 1.0 : 0.0,
    duration: const Duration(milliseconds: 500),
    child: Container(
      width:   double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color:        Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: gold.withOpacity(0.3)),
      ),
      child: Column(children: [
        const Text('Calculated claim amount',
          style: TextStyle(color: Colors.white54, fontSize: 13)),
        const SizedBox(height: 8),
        AnimatedBuilder(
          animation: _amtAnim,
          builder: (_, __) {
            final shown =
              ((trigger['amount'] as int) * _amtAnim.value).round();
            return Text('₹$shown',
              style: const TextStyle(color: gold, fontSize: 52,
                fontWeight: FontWeight.w900, letterSpacing: -2));
          },
        ),
        Text(
          'Tier ${trigger['severity']} · ${trigger['pct']}% of max payout',
          style: const TextStyle(color: Colors.white38, fontSize: 12)),
      ]),
    ),
  );

  Widget _nextBtn(Color color) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
    child: GestureDetector(
      onTap: _goNext,
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
          isLast ? 'View Claim Summary →' : 'Next Trigger →',
          style: const TextStyle(
            color:      Color(0xFF0D1829),
            fontSize:   16,
            fontWeight: FontWeight.w900))),
      ),
    ),
  );

  Widget _row(IconData icon, String label, String value) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Icon(icon, color: gray, size: 16),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(
          color: Colors.white38, fontSize: 13)),
        const Spacer(),
        Text(value, style: const TextStyle(
          color: Colors.white,
          fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    );

  Widget _divider() =>
    Divider(color: Colors.white.withOpacity(0.06), height: 1);

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
}
