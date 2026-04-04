// admin_app/lib/screens/zones_tab.dart
// ── Insurify Admin · High-Risk Zones Tab ────────────────────
// NEW FILE — add to admin_home.dart tab list (see admin_home.dart patch)
// Shows HIGH / MEDIUM / LOW zones with active trigger counts
// Data source: GET /admin/triggers (existing endpoint)

import 'dart:async';
import 'package:flutter/material.dart';
import '../services/admin_api.dart';

class ZonesTab extends StatefulWidget {
  ZonesTab({super.key});
  @override
  State<ZonesTab> createState() => _ZonesTabState();
}

class _ZonesTabState extends State<ZonesTab> {
  static const bg   = Color(0xFF0D1829);
  static const card = Color(0xFF13243A);
  static const navy = Color(0xFF1A2E6E);
  static const gold = Color(0xFFF5A623);
  static const gray = Color(0xFF7A8BB0);
  static const bdr  = Color(0xFF1E2E45);

  List<dynamic> triggers = [];
  bool loading = true;
  String _filter = 'ALL'; // ALL | HIGH | MEDIUM | LOW
  Timer? _timer;

  // Static zone catalogue (extended from onboarding_screen zones)
  final List<Map<String, dynamic>> _allZones = [
    {'name': 'Koramangala', 'city': 'Bengaluru', 'baseRisk': 72},
    {'name': 'HSR Layout',  'city': 'Bengaluru', 'baseRisk': 65},
    {'name': 'Marathahalli','city': 'Bengaluru', 'baseRisk': 55},
    {'name': 'Andheri',     'city': 'Mumbai',    'baseRisk': 60},
    {'name': 'Velachery',   'city': 'Chennai',   'baseRisk': 55},
    {'name': 'Indiranagar', 'city': 'Bengaluru', 'baseRisk': 45},
    {'name': 'Bander',      'city': 'Mumbai',    'baseRisk': 48},
    {'name': 'Lajpat Nagar','city': 'Delhi',     'baseRisk': 50},
    {'name': 'Gachibowli',  'city': 'Hyderabad', 'baseRisk': 40},
    {'name': 'Anna Nagar',  'city': 'Chennai',   'baseRisk': 38},
    {'name': 'Whitefield',  'city': 'Bengaluru', 'baseRisk': 30},
    {'name': 'Powai',       'city': 'Mumbai',    'baseRisk': 35},
  ];

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _load());
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  Future<void> _load() async {
    final t = await AdminApi.getTriggers();
    if (mounted) setState(() { triggers = t; loading = false; });
  }

  // Count active triggers per zone from live data
  int _activeTriggers(String zoneName) {
    return triggers.where((t) {
      final z = (t['zone'] as String? ?? '').toLowerCase();
      return z.contains(zoneName.toLowerCase()) &&
             t['status'] == 'active';
    }).length;
  }

  // Compute risk level: base risk + active trigger bonus
  String _risk(String zone, int baseRisk) {
    final bonus = _activeTriggers(zone) * 15;
    final total = baseRisk + bonus;
    if (total >= 65) return 'HIGH';
    if (total >= 45) return 'MEDIUM';
    return 'LOW';
  }

  int _riskScore(String zone, int baseRisk) {
    final bonus = _activeTriggers(zone) * 15;
    return (baseRisk + bonus).clamp(0, 100);
  }

  List<Map<String, dynamic>> get _zonesWithRisk {
    return _allZones.map((z) {
      final score = _riskScore(z['name'] as String, z['baseRisk'] as int);
      return {
        ...z,
        'risk':    _risk(z['name'] as String, z['baseRisk'] as int),
        'score':   score,
        'active':  _activeTriggers(z['name'] as String),
      };
    }).toList()
      ..sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
  }

  List<Map<String, dynamic>> get _filtered {
    if (_filter == 'ALL') return _zonesWithRisk;
    return _zonesWithRisk
        .where((z) => z['risk'] == _filter)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: loading
          ? const Center(child: CircularProgressIndicator(color: gold))
          : RefreshIndicator(
              color: gold, backgroundColor: card, onRefresh: _load,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Risk Zones',
                            style: TextStyle(
                              fontSize:   24,
                              fontWeight: FontWeight.w800,
                              color:      Colors.white)),
                          const SizedBox(height: 4),
                          Text('${_filtered.length} zones · updated live',
                            style: TextStyle(
                              fontSize: 12, color: gray)),

                          const SizedBox(height: 16),

                          // ── Summary chips ─────────────────
                          _summaryRow(),

                          const SizedBox(height: 16),

                          // ── Filter tabs ───────────────────
                          _filterRow(),
                        ],
                      ),
                    ),
                  ),

                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _zoneCard(_filtered[i]),
                        ),
                        childCount: _filtered.length,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ── Widgets ───────────────────────────────────────────────

  Widget _summaryRow() {
    final all = _zonesWithRisk;
    final high   = all.where((z) => z['risk'] == 'HIGH').length;
    final medium = all.where((z) => z['risk'] == 'MEDIUM').length;
    final low    = all.where((z) => z['risk'] == 'LOW').length;

    return Row(children: [
      _summaryChip('$high', 'High',   Colors.redAccent),
      const SizedBox(width: 8),
      _summaryChip('$medium', 'Medium', gold),
      const SizedBox(width: 8),
      _summaryChip('$low', 'Low',    Colors.greenAccent),
    ]);
  }

  Widget _summaryChip(String count, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(count,
          style: TextStyle(
            fontSize: 18, fontWeight: FontWeight.w900, color: color)),
        const SizedBox(width: 5),
        Text(label,
          style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600,
            color: color.withOpacity(0.85))),
      ]),
    );
  }

  Widget _filterRow() {
    final options = ['ALL', 'HIGH', 'MEDIUM', 'LOW'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: options.map((opt) {
          final active = _filter == opt;
          final color  = opt == 'HIGH'
              ? Colors.redAccent
              : opt == 'MEDIUM' ? gold
              : opt == 'LOW'    ? Colors.greenAccent
              : Colors.white;
          return GestureDetector(
            onTap: () => setState(() => _filter = opt),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin:   const EdgeInsets.only(right: 8),
              padding:  const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: active
                    ? (opt == 'ALL' ? navy : color).withOpacity(0.2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(
                  color: active
                      ? (opt == 'ALL' ? const Color(0xFF4B9FFF) : color)
                      : bdr,
                ),
              ),
              child: Text(opt,
                style: TextStyle(
                  fontSize:   12,
                  fontWeight: FontWeight.w700,
                  color: active
                      ? (opt == 'ALL' ? const Color(0xFF4B9FFF) : color)
                      : gray,
                )),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _zoneCard(Map<String, dynamic> zone) {
    final risk  = zone['risk'] as String;
    final score = zone['score'] as int;
    final active = zone['active'] as int;

    final riskColor = risk == 'HIGH'
        ? Colors.redAccent
        : risk == 'MEDIUM' ? gold : Colors.greenAccent;

    final riskIcon = risk == 'HIGH' ? '🔴'
        : risk == 'MEDIUM' ? '🟡' : '🟢';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: risk == 'HIGH'
              ? Colors.redAccent.withOpacity(0.35)
              : bdr,
          width: risk == 'HIGH' ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          Row(children: [
            // Zone info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$riskIcon  ${zone['name']}',
                    style: const TextStyle(
                      fontSize:   15,
                      fontWeight: FontWeight.w800,
                      color:      Colors.white)),
                  const SizedBox(height: 2),
                  Text(zone['city'] as String,
                    style: TextStyle(fontSize: 12, color: gray)),
                ],
              ),
            ),

            // Risk badge
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color:        riskColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(risk,
                  style: TextStyle(
                    fontSize:   11,
                    fontWeight: FontWeight.w800,
                    color:      riskColor,
                  )),
              ),
              const SizedBox(height: 4),
              if (active > 0)
                Text('$active active trigger${active > 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontSize:   10,
                    color:      Colors.redAccent,
                    fontWeight: FontWeight.w600)),
            ]),
          ]),

          const SizedBox(height: 12),

          // Risk score bar
          Row(children: [
            Text('Risk Score ',
              style: TextStyle(fontSize: 11, color: gray)),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value:           score / 100,
                  minHeight:       8,
                  backgroundColor: bdr,
                  valueColor: AlwaysStoppedAnimation(riskColor),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text('$score/100',
              style: TextStyle(
                fontSize:   11,
                fontWeight: FontWeight.w700,
                color:      riskColor)),
          ]),

          // Fire trigger button for HIGH zones
          if (risk == 'HIGH') ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => _fireTriggerFor(zone['name'] as String),
              child: Container(
                width:   double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color:        Colors.redAccent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: Colors.redAccent.withOpacity(0.3)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bolt_rounded,
                        color: Colors.redAccent, size: 14),
                    SizedBox(width: 5),
                    Text('Fire Demo Trigger',
                      style: TextStyle(
                        fontSize:   12,
                        fontWeight: FontWeight.w700,
                        color:      Colors.redAccent)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _fireTriggerFor(String zone) async {
    await AdminApi.fireTrigger(
      zone:     zone,
      type:     'heavy_rain',
      severity: 'T2',
      value:    85,
    );
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('🌧️ Trigger fired for $zone'),
      backgroundColor: navy,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
    _load();
  }
}
