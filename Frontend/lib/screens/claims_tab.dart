import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

  List<dynamic> claims   = [];
  List<dynamic> payments = [];
  bool          loading  = true;
  int           _mode    = 0; // 0: Payouts, 1: Policy

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final res = await Future.wait([
        ApiService.getClaims(widget.workerId),
        ApiService.getWorkerPayments(widget.workerId),
      ]);
      if (mounted) {
        setState(() {
          claims   = res[0];
          payments = res[1];
          loading  = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  int get _totalClaims => claims.fold(0, (s, c) => s + ((c['payout_amount'] ?? 0) as num).toInt());
  int get _fraudCount => claims.where((c) => c['fraud_flag'] == true).length;

  String _toTitleCase(String str) {
    if (str.isEmpty) return '';
    return str[0].toUpperCase() + str.substring(1).toLowerCase();
  }

  String _fmtDate(String? iso) {
    if (iso == null) return 'Today';
    try {
      final d = DateTime.parse(iso).toLocal();
      if (d.year == DateTime.now().year && d.month == DateTime.now().month && d.day == DateTime.now().day) {
        return 'Today';
      }
      return DateFormat('MMM d').format(d);
    } catch (_) { return 'Today'; }
  }

  String _fmtTime(String? iso) {
    if (iso == null) return 'Now';
    try {
      return DateFormat('h:mm a').format(DateTime.parse(iso).toLocal());
    } catch (_) { return 'Now'; }
  }

  Color _tc(String? t) {
    switch (t) {
      case 'heavy_rain':   return const Color(0xFF4B9FFF);
      case 'flood_alert':  return const Color(0xFF009688);
      case 'extreme_heat': return const Color(0xFFFF5252);
      case 'severe_aqi':   return const Color(0xFF9C6FFF);
      default:             return gray;
    }
  }

  @override
  Widget build(BuildContext context) => Stack(children: [
    Positioned(top: -80, right: -60, child: _blob(220, const Color(0xFF7B9CFF).withOpacity(0.2))),
    SafeArea(
      child: Column(children: [
        _header(),
        _summaryStats(),
        _toggle(),
        Expanded(
          child: loading
            ? const Center(child: CircularProgressIndicator(color: navy))
            : RefreshIndicator(
                onRefresh: _load,
                color: navy,
                child: _mode == 0 ? _payoutsBody() : _policyBody(),
              ),
        ),
      ]),
    ),
  ]);

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
    child: Row(children: [
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('My Coverage', style: TextStyle(color: navy, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
          Text('Payouts · Policy history', style: TextStyle(color: gray, fontSize: 13, fontWeight: FontWeight.w500)),
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

  Widget _summaryStats() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Row(children: [
      _sum('₹${_totalClaims >= 1000 ? '${(_totalClaims / 1000).toStringAsFixed(1)}K' : _totalClaims}', 'Earned back', const Color(0xFF00C853)),
      const SizedBox(width: 10),
      _sum('${claims.length}', 'Total claims', navy),
      const SizedBox(width: 10),
      _sum('$_fraudCount', 'Fraud flags', navy),
    ]),
  );

  Widget _sum(String v, String l, Color c) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: bdr),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(v, style: TextStyle(color: c, fontSize: 20, fontWeight: FontWeight.w900)),
        Text(l, style: const TextStyle(color: gray, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    ),
  );

  Widget _toggle() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
    child: Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: bdr)),
      child: Row(children: [
        Expanded(child: _toggleBtn(0, 'Payouts')),
        Expanded(child: _toggleBtn(1, 'Policy')),
      ]),
    ),
  );

  Widget _toggleBtn(int idx, String title) {
    bool sel = _mode == idx;
    return GestureDetector(
      onTap: () => setState(() => _mode = idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: sel ? const Color(0xFF232323) : Colors.transparent, borderRadius: BorderRadius.circular(12)),
        alignment: Alignment.center,
        child: Text(title, style: TextStyle(color: sel ? Colors.white : gray, fontSize: 13, fontWeight: sel ? FontWeight.w800 : FontWeight.w600)),
      ),
    );
  }

  // ════════ Payouts Tab ════════
  Widget _payoutsBody() => claims.isEmpty
    ? _empty('No payouts yet', 'You are covered. Stay safe!')
    : ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        itemCount: claims.length,
        itemBuilder: (_, i) => _payoutCard(claims[i]),
      );

  Widget _payoutCard(Map<String, dynamic> c) {
    final t   = c['trigger_type']?.toString();
    final amt = c['payout_amount'] ?? 0;
    final tc  = _tc(t);
    String emoji = t == 'heavy_rain' ? '🌧' : t == 'extreme_heat' ? '🌡' : t == 'flood_alert' ? '🌊' : t == 'severe_aqi' ? '😷' : '⚡';
    String lbl   = t == 'heavy_rain' ? 'Heavy Rain' : t == 'extreme_heat' ? 'Extreme Heat' : t == 'flood_alert' ? 'Flood Alert' : t == 'severe_aqi' ? 'Severe AQI' : 'Disruption';
    
    // Severity parsing
    final sev = c['severity']?.toString() ?? 'T2';
    final sevPct = sev == 'T3' ? '100%' : sev == 'T1' ? '25%' : '50%';
    
    // Mock value labels if null
    String metricLbl = t == 'heavy_rain' || t == 'flood_alert' ? 'Rainfall detected' : t == 'extreme_heat' ? 'Temperature' : 'AQI level';
    String metricVal = '${c['trigger_value'] ?? (t == 'extreme_heat' ? 42 : t == 'heavy_rain' ? 15 : 200)}${t == 'extreme_heat' ? '°C' : t == 'heavy_rain' || t == 'flood_alert' ? 'mm/hr' : ''}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tc.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: tc.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: tc.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
              child: Text(emoji, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lbl, style: const TextStyle(color: navy, fontSize: 15, fontWeight: FontWeight.w800)),
                Text('${c['zone']} · ${_fmtDate(c['detected_at'])}', style: const TextStyle(color: gray, fontSize: 12, fontWeight: FontWeight.w500)),
              ],
            )),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('+₹$amt', style: const TextStyle(color: Color(0xFF00C853), fontSize: 18, fontWeight: FontWeight.w900)),
                Text(_fmtTime(c['detected_at']), style: const TextStyle(color: gray, fontSize: 11)),
              ],
            )
          ],
        ),
        const SizedBox(height: 12),
        const Divider(color: bdr, height: 1),
        const SizedBox(height: 12),
        _plow('Severity', '$sev · $sevPct', true),
        _plow(metricLbl, metricVal, false),
        _plow('Income protected', '₹${c['expected_income'] ?? 0}', false),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Status', style: TextStyle(color: gray, fontSize: 12, fontWeight: FontWeight.w600)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFF00C853).withOpacity(0.12), borderRadius: BorderRadius.circular(99)),
              child: const Text('✓ Approved', style: TextStyle(color: Color(0xFF00C853), fontSize: 11, fontWeight: FontWeight.w800)),
            ),
          ],
        )
      ]),
    );
  }

  Widget _plow(String l, String v, bool cld) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(l, style: const TextStyle(color: gray, fontSize: 12, fontWeight: FontWeight.w600)),
        if (cld) Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: const Color(0xFF5A78B8).withOpacity(0.12), borderRadius: BorderRadius.circular(8)), child: Text(v, style: const TextStyle(color: Color(0xFF5A78B8), fontSize: 10, fontWeight: FontWeight.w800))) else Text(v, style: const TextStyle(color: navy, fontSize: 12, fontWeight: FontWeight.w800)),
      ],
    ),
  );

  // ════════ Policy Tab ════════
  Widget _policyBody() => payments.isEmpty
    ? _empty('No policy records', 'You have not subscribed to a plan.')
    : ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        itemCount: payments.length,
        itemBuilder: (_, i) => _policyCard(payments[i]),
      );

  Widget _policyCard(Map<String, dynamic> p) {
    DateTime start = DateTime.parse(p['created_at']).toLocal();
    DateTime end   = start.add(const Duration(days: 7));
    bool isActive  = DateTime.now().isBefore(end);

    int daysLeft = end.difference(DateTime.now()).inDays;
    if (daysLeft < 0) daysLeft = 0;

    String startS = DateFormat('MMM d').format(start);
    String endS   = DateFormat('MMM d, yyyy').format(end);
    
    // Calc matched claims for this policy 7 day validity period
    List matchedClaims = claims.where((c) {
      if (c['detected_at'] == null) return false;
      DateTime d = DateTime.parse(c['detected_at']).toLocal();
      return d.isAfter(start) && d.isBefore(end);
    }).toList();
    
    int cTotal = matchedClaims.fold(0, (s, c) => s + ((c['payout_amount'] ?? 0) as num).toInt());
    String planName = _toTitleCase(p['plan_type'] ?? 'Basic');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: bdr),
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: navy.withOpacity(0.06), shape: BoxShape.circle), child: const Icon(Icons.shield_outlined, color: navy, size: 22)),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$planName Plan', style: const TextStyle(color: navy, fontSize: 15, fontWeight: FontWeight.w800)),
                  Text('$startS – $endS', style: const TextStyle(color: gray, fontSize: 12, fontWeight: FontWeight.w500)),
                ],
              )),
              if (isActive)
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: const Color(0xFF00C853).withOpacity(0.12), borderRadius: BorderRadius.circular(99)), child: const Text('• ACTIVE', style: TextStyle(color: Color(0xFF00C853), fontSize: 10, fontWeight: FontWeight.bold)))
              else
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFFF5252).withOpacity(0.12), borderRadius: BorderRadius.circular(99)), child: const Text('EXPIRED', style: TextStyle(color: Color(0xFFFF5252), fontSize: 10, fontWeight: FontWeight.bold))),
            ],
          ),
        ),
        
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              if (isActive) ...[
                _plow('Premium', '₹${p['amount'] ?? 55}/week', false),
                _plow('Max payout', '₹${planName.toLowerCase() == 'pro' ? 1500 : planName.toLowerCase() == 'standard' ? 900 : 500}/week', false),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Days left', style: TextStyle(color: gray, fontSize: 12, fontWeight: FontWeight.w600)),
                  Text('$daysLeft days', style: const TextStyle(color: Color(0xFF00C853), fontSize: 12, fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 10),
                Row(
                  children: ['Rain', 'Heat', 'Flood', 'AQI'].map((t) => Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(color: navy.withOpacity(0.04), borderRadius: BorderRadius.circular(8), border: Border.all(color: bdr)),
                    child: Row(
                      children: [
                        Text(t=='Rain'?'🌧':t=='Heat'?'🌡':t=='Flood'?'🌊':'😷', style: const TextStyle(fontSize: 9)),
                        const SizedBox(width: 3),
                        Text(t, style: const TextStyle(color: navy, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE6F4EA), // pale green
                    borderRadius: BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('✓ Paid via ${p['payment_method'] ?? 'UPI'}', style: const TextStyle(color: Color(0xFF137333), fontSize: 12, fontWeight: FontWeight.w800)),
                      Text('₹${p['amount']} · $startS', style: const TextStyle(color: Color(0xFF137333), fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                )
              ] else ...[
                _plow('Premium paid', '₹${p['amount'] ?? 55}', false),
                _plow('Claims', '${matchedClaims.length} claim${matchedClaims.length==1?'':'s'} · ₹$cTotal paid', false),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Expired on', style: TextStyle(color: gray, fontSize: 12, fontWeight: FontWeight.w600)),
                  Text(endS, style: const TextStyle(color: Color(0xFFFF5252), fontSize: 12, fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFF9EE), // pale yellow wait, the mockup has white/pale gold
                    borderRadius: BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Renew for ', style: TextStyle(color: gold.withOpacity(0.5), fontSize: 13, fontWeight: FontWeight.w700)),
                      const Text('₹55/week →', style: TextStyle(color: gold, fontSize: 13, fontWeight: FontWeight.w800)),
                    ],
                  ),
                )
              ]
            ],
          ),
        ),
      ]),
    );
  }

  Widget _empty(String t, String s) => Center(
    child: Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(color: navy.withOpacity(0.07), shape: BoxShape.circle),
          child: const Icon(Icons.shield_rounded, color: navy, size: 40),
        ),
        const SizedBox(height: 16),
        Text(t, style: const TextStyle(color: navy, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(s, style: const TextStyle(color: gray, fontSize: 14)),
      ]),
    ),
  );

  Widget _blob(double s, Color c) => Container(width: s, height: s, decoration: BoxDecoration(shape: BoxShape.circle, color: c));
}
