// admin_app/lib/screens/analytics_tab.dart
// ── Insurify Admin · Enhanced Analytics Tab ─────────────────
// Replaces original analytics_tab.dart
// Changes:
//   • Claims-this-week card  (calls /admin/stats)
//   • Total payout card
//   • Premium revenue card
//   • Fraud flags card       (red badge when > 0)
//   • Loss-ratio bar
//   • By-zone breakdown
//   • By-type breakdown
//   • Auto-refresh every 15 s (unchanged)

import 'dart:async';
import 'package:flutter/material.dart';
import '../services/admin_api.dart';

class AnalyticsTab extends StatefulWidget {
  const AnalyticsTab({super.key});
  @override
  State<AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<AnalyticsTab> {
  // ── Theme (mirrors admin dark palette) ──────────────────
  static const bg   = Color(0xFF0D1829);
  static const card = Color(0xFF13243A);
  static const navy = Color(0xFF1A2E6E);
  static const gold = Color(0xFFF5A623);
  static const gray = Color(0xFF7A8BB0);
  static const bdr  = Color(0xFF1E2E45);

  Map<String, dynamic> stats  = {};
  List<dynamic>        claims = [];
  bool loading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _load());
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  Future<void> _load() async {
    final s = await AdminApi.getStats();
    final c = await AdminApi.getClaims();
    if (mounted) setState(() { stats = s; claims = c; loading = false; });
  }

  // ── Helpers ──────────────────────────────────────────────
  int _i(dynamic v) {
    if (v == null) return 0;
    if (v is int)    return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  double _d(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int)    return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  String _fmt(double v) {
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000)   return '₹${(v / 1000).toStringAsFixed(1)}K';
    return '₹${v.toStringAsFixed(0)}';
  }

  double get lossRatio {
    final p = _d(stats['total_premiums']);
    final o = _d(stats['total_paid_out']);
    if (p == 0) return 0.0;
    return (o / p).clamp(0.0, 1.0);
  }

  Map<String, int> get byZone {
    final m = <String, int>{};
    for (final c in claims) {
      final z = c['zone'] as String? ?? 'Unknown';
      m[z] = (m[z] ?? 0) + 1;
    }
    return Map.fromEntries(
      m.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
  }

  Map<String, int> get byType {
    final m = <String, int>{};
    for (final c in claims) {
      final t = c['trigger_type'] as String? ?? 'other';
      m[t] = (m[t] ?? 0) + 1;
    }
    return Map.fromEntries(
      m.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
  }

  String _typeName(String t) {
    const map = {
      'heavy_rain':   '🌧️  Heavy Rain',
      'flood_alert':  '🌊  Flood Alert',
      'extreme_heat': '🌡️  Extreme Heat',
      'severe_aqi':   '😷  Severe AQI',
      'curfew':       '🚫  Curfew',
      'cyclone':      '🌀  Cyclone',
    };
    return map[t] ?? t;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: loading
          ? const Center(child: CircularProgressIndicator(color: gold))
          : RefreshIndicator(
              color:           gold,
              backgroundColor: card,
              onRefresh:       _load,
              child: CustomScrollView(
                slivers: [
                  // ── App bar ──────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Analytics',
                            style: TextStyle(
                              fontSize:   24,
                              fontWeight: FontWeight.w800,
                              color:      Colors.white)),
                          // Live indicator
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color:        Colors.green.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(
                                  color: Colors.green.withOpacity(0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6, height: 6,
                                  decoration: const BoxDecoration(
                                    color: Colors.greenAccent,
                                    shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 5),
                                const Text('Live',
                                  style: TextStyle(
                                    fontSize:   11,
                                    color:      Colors.greenAccent,
                                    fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SliverPadding(
                    padding: const EdgeInsets.all(20),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // ── KPI Grid ─────────────────────────────
                        GridView.count(
                          crossAxisCount:    2,
                          shrinkWrap:        true,
                          physics:           const NeverScrollableScrollPhysics(),
                          crossAxisSpacing:  12,
                          mainAxisSpacing:   12,
                          childAspectRatio:  1.30,
                          children: [
                            _kpi(
                              label: 'Claims This Week',
                              value: '${_i(stats['total_claims'])}',
                              sub:   'Total all-time',
                              icon:  Icons.receipt_long_rounded,
                              color: const Color(0xFF4B9FFF),
                            ),
                            _kpi(
                              label: 'Total Paid Out',
                              value: _fmt(_d(stats['total_paid_out'])),
                              sub:   'Completed payouts',
                              icon:  Icons.payments_rounded,
                              color: Colors.greenAccent,
                            ),
                            _kpi(
                              label: 'Premium Revenue',
                              value: _fmt(_d(stats['total_premiums'])),
                              sub:   'Active policies',
                              icon:  Icons.trending_up_rounded,
                              color: gold,
                            ),
                            _kpi(
                              label: 'Fraud Flags',
                              value: '${_i(stats['fraud_flags'])}',
                              sub:   'Requires review',
                              icon:  Icons.gpp_bad_rounded,
                              color: _i(stats['fraud_flags']) > 0
                                  ? Colors.redAccent
                                  : gray,
                              alert: _i(stats['fraud_flags']) > 0,
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // ── Loss Ratio ────────────────────────────
                        _sectionCard(
                          title: 'Loss Ratio',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${(lossRatio * 100).toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      fontSize:   28,
                                      fontWeight: FontWeight.w900,
                                      color: lossRatio > 0.8
                                          ? Colors.redAccent
                                          : lossRatio > 0.6
                                              ? gold
                                              : Colors.greenAccent,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: lossRatio > 0.8
                                          ? Colors.red.withOpacity(0.15)
                                          : Colors.green.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      lossRatio > 0.8
                                          ? '⚠ High Risk'
                                          : lossRatio > 0.6
                                              ? 'Moderate'
                                              : '✓ Healthy',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: lossRatio > 0.8
                                            ? Colors.redAccent
                                            : lossRatio > 0.6
                                                ? gold
                                                : Colors.greenAccent,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Paid out ${_fmt(_d(stats['total_paid_out']))} of '
                                '${_fmt(_d(stats['total_premiums']))} collected',
                                style: TextStyle(
                                    fontSize: 12, color: gray),
                              ),
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(99),
                                child: LinearProgressIndicator(
                                  value:            lossRatio,
                                  minHeight:        10,
                                  backgroundColor:  bdr,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    lossRatio > 0.8
                                        ? Colors.redAccent
                                        : lossRatio > 0.6
                                            ? gold
                                            : Colors.greenAccent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ── Workers & Policies ────────────────────
                        Row(children: [
                          Expanded(
                            child: _miniStat(
                              label: 'Workers',
                              value: '${_i(stats['total_workers'])}',
                              icon:  Icons.people_rounded,
                              color: const Color(0xFF9C6FFF),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _miniStat(
                              label: 'Active Plans',
                              value: '${_i(stats['active_policies'])}',
                              icon:  Icons.verified_rounded,
                              color: const Color(0xFF4B9FFF),
                            ),
                          ),
                        ]),

                        const SizedBox(height: 20),

                        // ── Claims by Zone ────────────────────────
                        if (byZone.isNotEmpty)
                          _sectionCard(
                            title: 'Claims by Zone',
                            child: Column(
                              children: byZone.entries.map((e) {
                                final total = byZone.values
                                    .fold(0, (a, b) => a + b);
                                final pct = total == 0
                                    ? 0.0
                                    : e.value / total;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(e.key,
                                            style: const TextStyle(
                                              fontSize:   12,
                                              fontWeight: FontWeight.w600,
                                              color:      Colors.white)),
                                          Text('${e.value} claims',
                                            style: TextStyle(
                                                fontSize: 11, color: gray)),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(99),
                                        child: LinearProgressIndicator(
                                          value:            pct,
                                          minHeight:        6,
                                          backgroundColor:  bdr,
                                          valueColor:
                                              const AlwaysStoppedAnimation(
                                                  Color(0xFF4B9FFF)),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),

                        const SizedBox(height: 16),

                        // ── Claims by Trigger Type ────────────────
                        if (byType.isNotEmpty)
                          _sectionCard(
                            title: 'Claims by Trigger Type',
                            child: Column(
                              children: byType.entries.map((e) {
                                final total = byType.values
                                    .fold(0, (a, b) => a + b);
                                final pct = total == 0
                                    ? 0.0
                                    : e.value / total;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(_typeName(e.key),
                                            style: const TextStyle(
                                              fontSize:   12,
                                              fontWeight: FontWeight.w600,
                                              color:      Colors.white)),
                                          Text('${(pct * 100).round()}%',
                                            style: TextStyle(
                                                fontSize: 11, color: gold)),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(99),
                                        child: LinearProgressIndicator(
                                          value:           pct,
                                          minHeight:       6,
                                          backgroundColor: bdr,
                                          valueColor: AlwaysStoppedAnimation(
                                            _typeColor(e.key)),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),

                        const SizedBox(height: 100),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ── Widgets ───────────────────────────────────────────────

  Widget _kpi({
    required String label,
    required String value,
    required String sub,
    required IconData icon,
    required Color  color,
    bool alert = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        card,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(
          color: alert ? Colors.redAccent.withOpacity(0.4) : bdr),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 18),
              if (alert)
                Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.redAccent, shape: BoxShape.circle),
                ),
            ],
          ),
          const Spacer(),
          Text(value,
            style: TextStyle(
              fontSize:   22,
              fontWeight: FontWeight.w900,
              color:      color,
            )),
          const SizedBox(height: 2),
          Text(label,
            style: const TextStyle(
              fontSize:   12,
              fontWeight: FontWeight.w700,
              color:      Colors.white)),
          Text(sub,
            style: TextStyle(fontSize: 10, color: gray)),
        ],
      ),
    );
  }

  Widget _miniStat({
    required String label,
    required String value,
    required IconData icon,
    required Color  color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        card,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: bdr),
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color:        color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
              style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w900,
                color: color)),
            Text(label,
              style: const TextStyle(
                fontSize: 11, color: Colors.white70,
                fontWeight: FontWeight.w600)),
          ],
        ),
      ]),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        card,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: bdr),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
            style: const TextStyle(
              fontSize:   14,
              fontWeight: FontWeight.w700,
              color:      Colors.white)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Color _typeColor(String t) {
    const map = {
      'heavy_rain':   Color(0xFF4B9FFF),
      'flood_alert':  Color(0xFF1E90FF),
      'extreme_heat': Color(0xFFFF6B35),
      'severe_aqi':   Color(0xFFB39DDB),
      'curfew':       Color(0xFFF5A623),
      'cyclone':      Color(0xFF9C6FFF),
    };
    return map[t] ?? gray;
  }
}
