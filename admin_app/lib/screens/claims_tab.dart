import 'dart:async';
import 'package:flutter/material.dart';
import '../services/admin_api.dart';

class ClaimsTab extends StatefulWidget {
  const ClaimsTab({super.key});
  @override
  State<ClaimsTab> createState() => _ClaimsTabState();
}

class _ClaimsTabState extends State<ClaimsTab> {
  static const gold = Color(0xFFF5A623);
  static const gray = Color(0xFF7A8BB0);
  static const bdr  = Color(0xFF1E2E45);

  List<dynamic> claims  = [];
  bool          loading = true;
  String        filter  = 'all';
  Timer?        _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(
      const Duration(seconds: 10), (_) => _load());
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  Future<void> _load() async {
    final c = await AdminApi.getClaims();
    if (mounted) setState(() { claims = c; loading = false; });
  }

  int _i(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  List<dynamic> get filtered => filter == 'all'
    ? claims
    : claims.where((c) => c['status'] == filter).toList();

  int get totalPayout => claims.fold(
    0, (s, c) => s + _i(c['payout_amount']));

  Color _sc(String? s) {
    if (s == 'approved')   return const Color(0xFF00C853);
    if (s == 'processing') return gold;
    if (s == 'rejected')   return const Color(0xFFFF5252);
    return gray;
  }

  String _tn(String? t) {
    switch (t) {
      case 'heavy_rain':   return '🌧';
      case 'flood_alert':  return '🌊';
      case 'extreme_heat': return '🌡';
      case 'severe_aqi':   return '💨';
      default:             return '⚡';
    }
  }

  String _tname(String? t) {
    switch (t) {
      case 'heavy_rain':   return 'Heavy Rain';
      case 'flood_alert':  return 'Flood Alert';
      case 'extreme_heat': return 'Extreme Heat';
      case 'severe_aqi':   return 'Severe AQI';
      default:             return t ?? 'Trigger';
    }
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    _header(),
    _filters(),
    Expanded(
      child: loading
        ? const Center(
            child: CircularProgressIndicator(color: gold))
        : RefreshIndicator(
            onRefresh: _load, color: gold,
            child: filtered.isEmpty
              ? _empty()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    20, 8, 20, 100),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) =>
                    _claimCard(filtered[i])))),
  ]);

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
    child: Row(children: [
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Claims Feed', style: TextStyle(
            color: Colors.white, fontSize: 24,
            fontWeight: FontWeight.w900)),
          Text('${claims.length} total · ₹$totalPayout paid',
            style: const TextStyle(color: gray, fontSize: 13)),
        ],
      )),
      Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF00C853).withOpacity(0.08),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: const Color(0xFF00C853).withOpacity(0.3))),
        child: const Row(children: [
          Icon(Icons.circle, color: Color(0xFF00C853), size: 6),
          SizedBox(width: 5),
          Text('Auto 10s', style: TextStyle(
            color: Color(0xFF00C853), fontSize: 10,
            fontWeight: FontWeight.w600)),
        ])),
    ]),
  );

  Widget _filters() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        _chip('all',        'All',        Colors.white),
        _chip('approved',   'Approved',   const Color(0xFF00C853)),
        _chip('processing', 'Processing', gold),
        _chip('rejected',   'Rejected',   const Color(0xFFFF5252)),
      ]),
    ),
  );

  Widget _chip(String val, String label, Color color) {
    final active = filter == val;
    return GestureDetector(
      onTap: () => setState(() => filter = val),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active
            ? color.withOpacity(0.12)
            : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: active
              ? color.withOpacity(0.4) : bdr)),
        child: Text(label, style: TextStyle(
          color:      active ? color : gray,
          fontSize:   12,
          fontWeight: active ? FontWeight.w800 : FontWeight.w400)),
      ),
    );
  }

  Widget _claimCard(Map<String, dynamic> c) {
    final status = c['status'] as String? ?? 'processing';
    final sc     = _sc(status);
    final fraud  = c['fraud_flag'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: fraud
            ? const Color(0xFFFF5252).withOpacity(0.3)
            : bdr)),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: sc.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12)),
              child: Center(child: Text(
                _tn(c['trigger_type'] as String?),
                style: const TextStyle(fontSize: 22)))),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text(
                    c['name'] as String? ?? 'Worker',
                    style: const TextStyle(color: Colors.white,
                      fontSize: 14, fontWeight: FontWeight.w700))),
                  if (fraud)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5252)
                          .withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4)),
                      child: const Text('⚠ FRAUD',
                        style: TextStyle(
                          color:      Color(0xFFFF5252),
                          fontSize:   8,
                          fontWeight: FontWeight.bold))),
                ]),
                Text(_tname(c['trigger_type'] as String?),
                  style: TextStyle(color: sc.withOpacity(0.8),
                    fontSize: 12)),
                Text(
                  '${c['zone'] ?? ''} · '
                  '${(c['created_at']?.toString() ?? '').substring(0, 10)}',
                  style: const TextStyle(
                    color: gray, fontSize: 11)),
              ],
            )),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color:        sc.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: sc.withOpacity(0.3))),
                child: Text(status.toUpperCase(),
                  style: TextStyle(color: sc, fontSize: 9,
                    fontWeight: FontWeight.bold))),
              const SizedBox(height: 4),
              Text('₹${_i(c['payout_amount'])}',
                style: const TextStyle(color: gold,
                  fontSize: 16, fontWeight: FontWeight.w900)),
            ]),
          ]),
        ),

        // Action buttons for processing claims
        if (status == 'processing') ...[
          Divider(color: bdr, height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Row(children: [
              Expanded(child: GestureDetector(
                onTap: () async {
                  await AdminApi.updateClaim(
                    c['id'] as int, 'rejected');
                  _load();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 9),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5252)
                      .withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFFF5252)
                        .withOpacity(0.3))),
                  child: const Center(child: Text('Reject',
                    style: TextStyle(
                      color:      Color(0xFFFF5252),
                      fontSize:   13,
                      fontWeight: FontWeight.w700)))),
              )),
              const SizedBox(width: 10),
              Expanded(child: GestureDetector(
                onTap: () async {
                  await AdminApi.updateClaim(
                    c['id'] as int, 'approved');
                  _load();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 9),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C853)
                      .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF00C853)
                        .withOpacity(0.3))),
                  child: const Center(child: Text('Approve',
                    style: TextStyle(
                      color:      Color(0xFF00C853),
                      fontSize:   13,
                      fontWeight: FontWeight.w700)))),
              )),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _empty() => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Icon(Icons.receipt_long_rounded,
        color: Colors.white24, size: 48),
      const SizedBox(height: 12),
      const Text('No claims found',
        style: TextStyle(color: Colors.white38, fontSize: 16)),
    ],
  ));
}
