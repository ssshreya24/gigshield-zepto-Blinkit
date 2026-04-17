import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ClaimsTab extends StatefulWidget {
  final int workerId;
  const ClaimsTab({super.key, required this.workerId});
  @override
  State<ClaimsTab> createState() => _ClaimsTabState();
}

class _ClaimsTabState extends State<ClaimsTab> {
  static const bg   = Color(0xFFE8EDFF);
  static const navy = Color(0xFF1A2E6E);
  static const gold = Color(0xFFF5A623);
  static const gray = Color(0xFF7A8BB0);
  static const bdr  = Color(0xFFCDD8F6);

  List<dynamic> claims  = [];
  bool          loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final d = await ApiService.getClaims(widget.workerId);
    setState(() { claims = d; loading = false; });
  }

  int get _total => claims.fold(0,
    (s, c) => s + ((c['payout_amount'] ?? 0) as num).toInt());

  int get _fraudCount => claims.where((c) =>
    c['fraud_flag'] == true || c['status'] == 'fraud_review').length;

  Color _sc(String? s) {
    if (s == 'approved')    return const Color(0xFF00C853);
    if (s == 'processing')  return gold;
    if (s == 'rejected')    return const Color(0xFFFF5252);
    if (s == 'fraud_review') return const Color(0xFFFF6D00);
    return gray;
  }

  IconData _ic(String? t) {
    switch (t) {
      case 'heavy_rain':   return Icons.water_drop_rounded;
      case 'flood_alert':  return Icons.flood_rounded;
      case 'extreme_heat': return Icons.thermostat_rounded;
      case 'severe_aqi':   return Icons.air_rounded;
      default:             return Icons.warning_rounded;
    }
  }

  Color _tc(String? t) {
    switch (t) {
      case 'heavy_rain':   return const Color(0xFF4B9FFF);
      case 'flood_alert':  return const Color(0xFFFF5252);
      case 'extreme_heat': return gold;
      case 'severe_aqi':   return const Color(0xFF9C6FFF);
      default:             return gray;
    }
  }

  String _tn(String? t) {
    switch (t) {
      case 'heavy_rain':   return 'Heavy Rain';
      case 'flood_alert':  return 'Flood Alert';
      case 'extreme_heat': return 'Extreme Heat';
      case 'severe_aqi':   return 'Severe AQI';
      default:             return t ?? 'Disruption';
    }
  }

  @override
  Widget build(BuildContext context) => Stack(children: [
    Positioned(top: -80, right: -60,
      child: _blob(220, const Color(0xFF7B9CFF).withOpacity(0.2))),
    SafeArea(
      child: Column(children: [
        _header(),
        Expanded(
          child: loading
            ? const Center(child: CircularProgressIndicator(color: navy))
            : RefreshIndicator(
                onRefresh: () async => _load(),
                color: navy,
                child: _body(),
              ),
        ),
      ]),
    ),
  ]);

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
    child: Row(children: [
      const Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('My Claims',
            style: TextStyle(color: navy, fontSize: 24,
              fontWeight: FontWeight.w900, letterSpacing: -0.5)),
          Text('Your payout history',
            style: TextStyle(color: gray, fontSize: 13)),
        ],
      )),
      GestureDetector(
        onTap: _load,
        child: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.8),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: bdr),
          ),
          child: const Icon(Icons.refresh_rounded, color: navy, size: 20),
        ),
      ),
    ]),
  );

  Widget _body() => SingleChildScrollView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Summary
      Row(children: [
        _sum('₹$_total',        'Earned back',  const Color(0xFF00C853)),
        const SizedBox(width: 10),
        _sum('${claims.length}','Total claims', navy),
        const SizedBox(width: 10),
        _sum('$_fraudCount',    'Fraud flags',  _fraudCount > 0 ? const Color(0xFFFF5252) : navy),
      ]),
      const SizedBox(height: 20),

      if (claims.isEmpty) _empty()
      else ...[
        Text('${claims.length} claim${claims.length > 1 ? 's' : ''}',
          style: const TextStyle(color: gray, fontSize: 12,
            fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        ...claims.map((c) => _card(c)),
      ],
    ]),
  );

  Widget _sum(String v, String l, Color c) => Expanded(
    child: ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.75),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.9)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(v, style: TextStyle(
              color: c, fontSize: 20, fontWeight: FontWeight.w900)),
            Text(l, style: const TextStyle(color: gray, fontSize: 11)),
          ]),
        ),
      ),
    ),
  );

  Widget _card(Map<String, dynamic> c) {
    final status    = c['status'] as String? ?? 'processing';
    final type      = c['trigger_type'] as String?;
    final date      = c['created_at']?.toString().substring(0, 10) ?? '';
    final sc        = _sc(status);
    final tc        = _tc(type);
    final isFraud   = c['fraud_flag'] == true || status == 'fraud_review';
    final fraudNote = c['fraud_reason'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFraud ? const Color(0xFFFF5252).withOpacity(0.5) : bdr,
          width: isFraud ? 1.5 : 1),
        boxShadow: [BoxShadow(
          color: isFraud
            ? const Color(0xFFFF5252).withOpacity(0.12)
            : tc.withOpacity(0.08),
          blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        // Fraud warning banner
        if (isFraud)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFFF5252),
              borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
            child: Row(children: [
              const Icon(Icons.gpp_bad_rounded, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              const Text('FRAUD FLAGGED',
                style: TextStyle(color: Colors.white, fontSize: 11,
                  fontWeight: FontWeight.w900, letterSpacing: 0.8)),
              const Spacer(),
              Text(status == 'rejected' ? '🚫 BLOCKED'
                : status == 'fraud_review' ? '⏳ UNDER REVIEW' : '',
                style: const TextStyle(color: Colors.white70, fontSize: 10,
                  fontWeight: FontWeight.w700)),
            ]),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Stack(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: tc.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_ic(type), color: tc, size: 22),
              ),
              if (isFraud)
                Positioned(top: -2, right: -2,
                  child: Container(
                    width: 18, height: 18,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF5252),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2)),
                    child: const Icon(Icons.priority_high_rounded,
                      color: Colors.white, size: 10),
                  ),
                ),
            ]),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_tn(type), style: const TextStyle(
                  color: navy, fontSize: 15, fontWeight: FontWeight.w700)),
                Text('${c['zone'] ?? ''} · $date',
                  style: const TextStyle(color: gray, fontSize: 12)),
              ],
            )),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: sc.withOpacity(0.12),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: sc.withOpacity(0.3)),
              ),
              child: Text(
                status == 'fraud_review' ? 'FRAUD REVIEW' : status.toUpperCase(),
                style: TextStyle(color: sc, fontSize: 10,
                  fontWeight: FontWeight.bold)),
            ),
          ]),
        ),
        // Fraud reason
        if (isFraud && fraudNote.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFF5252).withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFFF5252).withOpacity(0.15))),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.info_outline_rounded,
                  color: Color(0xFFFF5252), size: 14),
                const SizedBox(width: 6),
                Expanded(child: Text(fraudNote,
                  style: const TextStyle(color: Color(0xFFFF5252),
                    fontSize: 11, height: 1.3))),
              ]),
            ),
          ),
        Divider(color: bdr, height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 12),
          child: Row(children: [
            _mini('Expected', '₹${c['expected_income'] ?? 0}', gray),
            _divWid(),
            _mini('Actual',   '₹${c['actual_income'] ?? 0}',   gray),
            _divWid(),
            _mini('Payout',   '₹${c['payout_amount'] ?? 0}',
              isFraud ? const Color(0xFFFF5252) : gold),
            const Spacer(),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(isFraud ? 'Razorpay' : 'UPI',
                style: const TextStyle(color: gray, fontSize: 11)),
              Text(
                isFraud ? 'HELD' : (c['payout_status'] ?? 'pending'),
                style: TextStyle(
                  color: isFraud
                    ? const Color(0xFFFF5252)
                    : (c['payout_status'] == 'completed'
                      ? const Color(0xFF00C853) : gold),
                  fontSize: 11, fontWeight: FontWeight.w700)),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _mini(String l, String v, Color c) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(l, style: const TextStyle(color: gray, fontSize: 10)),
      Text(v, style: TextStyle(
        color: c, fontSize: 13, fontWeight: FontWeight.w700)),
    ],
  );

  Widget _divWid() => Container(
    width: 1, height: 28, color: bdr,
    margin: const EdgeInsets.symmetric(horizontal: 12));

  Widget _empty() => Center(
    child: Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: navy.withOpacity(0.07), shape: BoxShape.circle),
          child: const Icon(Icons.shield_rounded, color: navy, size: 40),
        ),
        const SizedBox(height: 16),
        const Text('No claims yet',
          style: TextStyle(color: navy, fontSize: 18,
            fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const Text('You are covered. Stay safe!',
          style: TextStyle(color: gray, fontSize: 14)),
      ]),
    ),
  );

  Widget _blob(double s, Color c) => Container(
    width: s, height: s,
    decoration: BoxDecoration(shape: BoxShape.circle, color: c));
}
