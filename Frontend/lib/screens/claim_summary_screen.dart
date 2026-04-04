import 'package:flutter/material.dart';
import 'payment_method_screen.dart';

class ClaimSummaryScreen extends StatelessWidget {
  final List<Map<String, dynamic>> triggers;
  final List<int>                  amounts;
  final Map<String, dynamic>?      policy;

  const ClaimSummaryScreen({
    super.key,
    required this.triggers,
    required this.amounts,
    this.policy,
  });

  static const bg   = Color(0xFF0D1829);
  static const gold = Color(0xFFF5A623);
  static const gray = Color(0xFF7A8BB0);

  int get total => amounts.fold(0, (s, a) => s + a);

  String get policyNo {
    final now = DateTime.now();
    final wid = policy?['id'] ?? 1;
    return 'GS-${now.year}-${now.month.toString().padLeft(2,'0')}-${wid.toString().padLeft(5,'0')}';
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

                  // Total card
                  Container(
                    width:   double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color:        Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border:       Border.all(
                        color: gold.withOpacity(0.3)),
                    ),
                    child: Column(children: [
                      const Text('Total claim amount',
                        style: TextStyle(color: Colors.white54,
                          fontSize: 14)),
                      const SizedBox(height: 10),
                      Text('₹$total',
                        style: const TextStyle(color: gold,
                          fontSize: 56, fontWeight: FontWeight.w900,
                          letterSpacing: -2)),
                      Text(
                        '${triggers.length} trigger${triggers.length > 1 ? 's' : ''} combined',
                        style: const TextStyle(
                          color: Colors.white38, fontSize: 13)),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00C853)
                            .withOpacity(0.15),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                            color: const Color(0xFF00C853)
                              .withOpacity(0.4)),
                        ),
                        child: const Text(
                          '● All triggers verified · Ready to claim',
                          style: TextStyle(
                            color:      Color(0xFF00C853),
                            fontSize:   12,
                            fontWeight: FontWeight.bold)),
                      ),
                    ]),
                  ),

                  const SizedBox(height: 20),

                  // Breakdown
                  _sectionLabel('Claim Breakdown'),
                  const SizedBox(height: 10),
                  _darkCard(child: Column(
                    children: List.generate(triggers.length, (i) {
                      final t     = triggers[i];
                      final color = t['color'] as Color;
                      return Column(children: [
                        if (i > 0)
                          Divider(
                            color: Colors.white.withOpacity(0.06),
                            height: 1),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 14),
                          child: Row(children: [
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.12),
                                borderRadius:
                                  BorderRadius.circular(10)),
                              child: Icon(t['icon'] as IconData,
                                color: color, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Column(
                              crossAxisAlignment:
                                CrossAxisAlignment.start,
                              children: [
                                Text(t['name'] as String,
                                  style: const TextStyle(
                                    color:      Colors.white,
                                    fontSize:   14,
                                    fontWeight: FontWeight.w700)),
                                Text(
                                  'Tier ${t['severity']} · ${t['pct']}% payout',
                                  style: const TextStyle(
                                    color:    Colors.white38,
                                    fontSize: 11)),
                              ],
                            )),
                            Text('₹${amounts[i]}',
                              style: const TextStyle(
                                color:      gold,
                                fontSize:   18,
                                fontWeight: FontWeight.w900)),
                          ]),
                        ),
                      ]);
                    }),
                  )),

                  const SizedBox(height: 16),

                  // Policy info
                  _sectionLabel('Policy Reference'),
                  const SizedBox(height: 10),
                  _darkCard(child: Column(children: [
                    _infoRow('Policy number', policyNo),
                    _divider(),
                    _infoRow('Coverage type', 'Parametric Income'),
                    _divider(),
                    _infoRow('Worker',
                      policy?['name'] ?? 'Worker'),
                    _divider(),
                    _infoRow('Zone',
                      policy?['zone'] ?? 'Koramangala'),
                    _divider(),
                    _infoRow('Platform',
                      policy?['platform'] ?? 'Zepto'),
                    _divider(),
                    _infoRow('Triggers applied',
                      '${triggers.length}'),
                  ])),

                  const SizedBox(height: 16),

                  // How calculated
                  _sectionLabel('Basis of Claim'),
                  const SizedBox(height: 10),
                  _darkCard(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Each trigger was independently verified against real-time data sources including OpenWeatherMap, IMD alerts, and government notifications. Payouts are calculated using parametric formulas based on event severity, duration, and policy tier.',
                        style: TextStyle(
                          color:    Colors.white54,
                          fontSize: 13,
                          height:   1.6)),
                      const SizedBox(height: 12),
                      Row(children: [
                        _tag('Zero-touch claim'),
                        const SizedBox(width: 8),
                        _tag('AI verified'),
                        const SizedBox(width: 8),
                        _tag('No paperwork'),
                      ]),
                    ],
                  )),
                ],
              ),
            ),
          ),
          _bottomBtns(context),
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
          Text('Claim Summary',
            style: TextStyle(color: Colors.white, fontSize: 20,
              fontWeight: FontWeight.w900)),
          Text('Review before claiming',
            style: TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      ),
    ]),
  );

  Widget _bottomBtns(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
    child: Column(children: [
      GestureDetector(
        onTap: () => Navigator.push(context,
          MaterialPageRoute(
            builder: (_) => PaymentMethodScreen(
              total:    total,
              triggers: triggers,
              amounts:  amounts,
              policy:   policy,
            ))),
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
            'Claim Now · ₹$total →',
            style: const TextStyle(
              color:      Color(0xFF0D1829),
              fontSize:   16,
              fontWeight: FontWeight.w900))),
        ),
      ),
      const SizedBox(height: 10),
      GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          width:   double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withOpacity(0.1)),
          ),
          child: const Center(child: Text('View calculation details',
            style: TextStyle(color: Colors.white54,
              fontSize: 14, fontWeight: FontWeight.w500))),
        ),
      ),
    ]),
  );

  Widget _infoRow(String l, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(l, style: const TextStyle(
          color: Colors.white38, fontSize: 13)),
        Flexible(child: Text(v,
          textAlign: TextAlign.right,
          style: const TextStyle(color: Colors.white,
            fontSize: 13, fontWeight: FontWeight.w600))),
      ],
    ),
  );

  Widget _tag(String t) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.06),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(
        color: Colors.white.withOpacity(0.1)),
    ),
    child: Text(t, style: const TextStyle(
      color: Colors.white38, fontSize: 10)),
  );

  Widget _darkCard({required Widget child}) => Container(
    width:   double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.04),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white.withOpacity(0.08)),
    ),
    child: child,
  );

  Widget _divider() =>
    Divider(color: Colors.white.withOpacity(0.06), height: 1);

  Widget _sectionLabel(String t) => Text(t,
    style: const TextStyle(
      color:         Colors.white38,
      fontSize:      12,
      fontWeight:    FontWeight.w700,
      letterSpacing: 0.8));
}
