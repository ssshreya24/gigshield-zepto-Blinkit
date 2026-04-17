// admin_app/lib/screens/worker_detail_screen.dart
// ── Insurify Admin · Worker Profile ────────────────────────────

import 'package:flutter/material.dart';
import '../services/admin_api.dart';

class WorkerDetailScreen extends StatefulWidget {
  final int    workerId;
  final String workerName;
  const WorkerDetailScreen({
    super.key, required this.workerId, required this.workerName });
  @override
  State<WorkerDetailScreen> createState() => _WorkerDetailScreenState();
}

class _WorkerDetailScreenState extends State<WorkerDetailScreen> {
  // colours
  static const bg   = Color(0xFF0A1628);
  static const card = Color(0xFF111E35);
  static const card2= Color(0xFF162240);
  static const bdr  = Color(0xFF1E3352);
  static const gold = Color(0xFFF5A623);
  static const gray = Color(0xFF7A8BB0);
  static const grn  = Color(0xFF00C853);
  static const red  = Color(0xFFFF5252);
  static const blue = Color(0xFF4B9FFF);
  static const purp = Color(0xFF9C6FFF);

  Map<String, dynamic>? _data;
  bool   _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final d = await AdminApi.getWorkerDetail(widget.workerId);
    if (mounted) setState(() {
      _data    = d;
      _loading = false;
      if (d == null) _error = 'Could not load worker data.\nCheck your connection and try again.';
    });
  }

  // ── tiny helpers ───────────────────────────────────────────
  int _i(dynamic v) {
    if (v == null) return 0;
    if (v is int)    return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
  String _ds(String? raw) =>
      (raw == null || raw.length < 10) ? '—' : raw.substring(0, 10);

  Color _planCol(String? p) {
    switch ((p ?? '').toLowerCase()) {
      case 'pro':      return purp;
      case 'standard': return blue;
      default:         return grn;
    }
  }
  Color _trigCol(String? t) {
    switch (t) {
      case 'heavy_rain':   return blue;
      case 'extreme_heat': return red;
      case 'severe_aqi':   return purp;
      case 'flood_alert':  return grn;
      default:             return gold;
    }
  }
  String _trigEmoji(String? t) {
    switch (t) {
      case 'heavy_rain':   return '🌧';
      case 'extreme_heat': return '🌡';
      case 'severe_aqi':   return '💨';
      case 'flood_alert':  return '🌊';
      case 'curfew':       return '🚫';
      case 'cyclone':      return '🌀';
      default:             return '⚡';
    }
  }
  String _trigName(String? t) {
    switch (t) {
      case 'heavy_rain':   return 'Heavy Rain';
      case 'extreme_heat': return 'Extreme Heat';
      case 'severe_aqi':   return 'Severe AQI';
      case 'flood_alert':  return 'Flood Alert';
      case 'curfew':       return 'Curfew';
      case 'cyclone':      return 'Cyclone';
      default:             return t ?? 'Trigger';
    }
  }

  // ── build ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: bg,
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          margin: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: bdr)),
          child: const Icon(Icons.arrow_back_ios_new_rounded,
            color: Colors.white, size: 16)),
      ),
      title: Text(widget.workerName,
        style: const TextStyle(color: Colors.white,
          fontSize: 17, fontWeight: FontWeight.w800)),
      actions: [
        GestureDetector(
          onTap: _load,
          child: Container(
            margin: const EdgeInsets.all(10),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: bdr)),
            child: const Icon(Icons.refresh_rounded,
              color: Colors.white, size: 16)),
        ),
      ],
    ),
    body: _loading
      ? const Center(child: CircularProgressIndicator(color: gold))
      : _error != null ? _errorView() : _body(),
  );

  // ── error ──────────────────────────────────────────────────
  Widget _errorView() => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
          color: red.withOpacity(0.1),
          shape: BoxShape.circle,
          border: Border.all(color: red.withOpacity(0.3))),
        child: const Icon(Icons.wifi_off_rounded, color: red, size: 32)),
      const SizedBox(height: 16),
      Text(_error!,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white54, fontSize: 14, height: 1.5)),
      const SizedBox(height: 24),
      ElevatedButton.icon(
        onPressed: _load,
        icon: const Icon(Icons.refresh_rounded, size: 16),
        label: const Text('Try Again'),
        style: ElevatedButton.styleFrom(
          backgroundColor: blue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      ),
    ]),
  ));

  // ── main body ──────────────────────────────────────────────
  Widget _body() {
    final d          = _data!;
    final plan       = (d['plan_type'] ?? 'basic').toString();
    final pc         = _planCol(plan);
    final claims     = (d['claims']          as List? ?? []);
    final premiums   = (d['premium_payments'] as List? ?? []);
    final timeline   = (d['monthly_timeline'] as List? ?? []);
    final totalOut   = _i(d['total_payout']);
    final totalCl    = _i(d['total_claims']);
    final dailyInc   = _i(d['avg_daily_income']);

    return RefreshIndicator(
      onRefresh: _load, color: gold,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(children: [

          // ── gradient hero banner ──────────────────────────
          _heroBanner(d, plan, pc, totalOut, totalCl, dailyInc),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [

              // ── 3-stat row ───────────────────────────────
              Row(children: [
                _statTile('Triggers\nActivated', '$totalCl',
                  red, Icons.bolt_rounded),
                const SizedBox(width: 10),
                _statTile('Total\nPayout', '₹$totalOut',
                  gold, Icons.account_balance_wallet_rounded),
                const SizedBox(width: 10),
                _statTile('Daily\nIncome', '₹$dailyInc',
                  blue, Icons.trending_up_rounded),
              ]),
              const SizedBox(height: 24),

              // ── policy card ──────────────────────────────
              _label('Policy Details'),
              const SizedBox(height: 10),
              _policyCard(d, plan, pc),
              const SizedBox(height: 24),



              // ── claims ───────────────────────────────────
              _label('Claim History  (${claims.length})'),
              const SizedBox(height: 10),
              claims.isEmpty
                ? _empty('No claims filed yet',
                    Icons.check_circle_outline_rounded, grn)
                : Column(children: claims
                    .map((c) => _claimTile(c as Map<String, dynamic>))
                    .toList()),
              const SizedBox(height: 24),

              // ── premium payments ─────────────────────────
              _label('Premium Payments  (${premiums.length})'),
              const SizedBox(height: 10),
              premiums.isEmpty
                ? _empty('No payments recorded',
                    Icons.payment_rounded, gray)
                : _premCard(premiums),
              const SizedBox(height: 24),

              // ── loss ratio summary ───────────────────────
              _label('Financial Summary'),
              const SizedBox(height: 10),
              _financeSummary(d, claims, totalOut, totalCl),
            ]),
          ),
        ]),
      ),
    );
  }

  // ── HERO BANNER ────────────────────────────────────────────
  Widget _heroBanner(Map<String, dynamic> d, String plan, Color pc,
      int totalOut, int totalCl, int dailyInc) {
    final initials = (d['name'] as String? ?? 'W')
        .split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join();
    final active = d['policy_active'] ?? false;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [pc.withOpacity(0.28), bg],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter),
        border: Border(bottom: BorderSide(color: bdr))),
      child: Column(children: [
        // avatar + name
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(children: [
            Container(
              width: 70, height: 70,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [pc.withOpacity(0.6), pc.withOpacity(0.3)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
                shape: BoxShape.circle,
                border: Border.all(color: pc.withOpacity(0.6), width: 2),
                boxShadow: [BoxShadow(
                  color: pc.withOpacity(0.3), blurRadius: 16, spreadRadius: 2)]),
              child: Center(child: Text(initials,
                style: TextStyle(color: pc == blue ? Colors.white : Colors.white,
                  fontSize: 24, fontWeight: FontWeight.w900)))),
            Positioned(right: 0, bottom: 0,
              child: Container(
                width: 18, height: 18,
                decoration: BoxDecoration(
                  color: active ? grn : red,
                  shape: BoxShape.circle,
                  border: Border.all(color: bg, width: 2)),
              )),
          ]),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Text(d['name'] ?? 'Worker',
              style: const TextStyle(color: Colors.white, fontSize: 20,
                fontWeight: FontWeight.w900, letterSpacing: -0.3)),
            const SizedBox(height: 4),
            _infoChip(Icons.location_on_rounded,
              '${d['zone'] ?? '—'}', Colors.white54),
            const SizedBox(height: 3),
            _infoChip(Icons.delivery_dining_rounded,
              '${d['platform'] ?? '—'}', Colors.white54),
            const SizedBox(height: 3),
            _infoChip(Icons.phone_rounded,
              '${d['phone'] ?? '—'}', Colors.white54),
          ])),
          // Plan badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            decoration: BoxDecoration(
              color: pc.withOpacity(0.18),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: pc.withOpacity(0.5))),
            child: Text(plan.toUpperCase(),
              style: TextStyle(color: pc, fontSize: 11,
                fontWeight: FontWeight.w900, letterSpacing: 0.5))),
        ]),
        const SizedBox(height: 20),
        // date chips
        Row(children: [
          _dateChip('Member since', _ds(d['created_at']?.toString())),
          const SizedBox(width: 8),
          _dateChip('Policy since', _ds(d['policy_start']?.toString())),
          const SizedBox(width: 8),
          _dateChip('Worker ID', '#${d['id'] ?? '—'}'),
        ]),
      ]),
    );
  }

  Widget _infoChip(IconData icon, String text, Color col) =>
    Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: col, size: 12),
      const SizedBox(width: 4),
      Text(text, style: TextStyle(color: col, fontSize: 12)),
    ]);

  Widget _dateChip(String label, String val) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.06),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: bdr)),
    child: Column(children: [
      Text(label, style: const TextStyle(color: Color(0xFF4A5E7A),
        fontSize: 9, fontWeight: FontWeight.w600)),
      const SizedBox(height: 2),
      Text(val, style: const TextStyle(color: Colors.white,
        fontSize: 11, fontWeight: FontWeight.w700)),
    ]),
  ));

  // ── STAT TILE ──────────────────────────────────────────────
  Widget _statTile(String label, String val, Color c, IconData icon) =>
    Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: c.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.withOpacity(0.22)),
        boxShadow: [BoxShadow(
          color: c.withOpacity(0.06), blurRadius: 12)]),
      child: Column(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: c.withOpacity(0.14),
            borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: c, size: 18)),
        const SizedBox(height: 8),
        Text(val, style: TextStyle(color: c, fontSize: 17,
          fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text(label, style: const TextStyle(color: Color(0xFF7A8BB0),
          fontSize: 9, height: 1.3), textAlign: TextAlign.center),
      ]),
    ));

  // ── POLICY CARD ───────────────────────────────────────────
  Widget _policyCard(Map<String, dynamic> d, String plan, Color pc) =>
    _card(child: Column(children: [
      Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: pc.withOpacity(0.14),
            borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.shield_rounded, color: pc, size: 22)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Text(plan.toUpperCase(),
            style: TextStyle(color: pc, fontSize: 15,
              fontWeight: FontWeight.w900)),
          Text('Active Policy Plan',
            style: const TextStyle(color: Color(0xFF7A8BB0), fontSize: 11)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: (d['policy_active'] ?? false)
                ? grn.withOpacity(0.12) : red.withOpacity(0.12),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: (d['policy_active'] ?? false)
                ? grn.withOpacity(0.35) : red.withOpacity(0.35))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 6, height: 6,
              decoration: BoxDecoration(
                color: (d['policy_active'] ?? false) ? grn : red,
                shape: BoxShape.circle)),
            const SizedBox(width: 5),
            Text((d['policy_active'] ?? false) ? 'Active' : 'Inactive',
              style: TextStyle(
                color: (d['policy_active'] ?? false) ? grn : red,
                fontSize: 11, fontWeight: FontWeight.w700)),
          ])),
      ]),
      const SizedBox(height: 16),
      Divider(color: bdr, height: 1),
      const SizedBox(height: 14),
      Row(children: [
        _policyCell('Weekly Premium', '₹${_i(d['weekly_premium'])}', gold),
        Container(width: 1, height: 40, color: bdr),
        _policyCell('Max Payout', '₹${_i(d['max_payout'])}', grn),
        Container(width: 1, height: 40, color: bdr),
        _policyCell('Payout %', 'Up to\n100%', blue),
      ]),
    ]));

  Widget _policyCell(String lbl, String val, Color c) => Expanded(child:
      Column(children: [
        Text(val, textAlign: TextAlign.center,
          style: TextStyle(color: c, fontSize: 15, fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text(lbl, textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF7A8BB0), fontSize: 10)),
      ]));

  // ── BAR CHART ─────────────────────────────────────────────
  Widget _barChart(List timeline) {
    const chartH = 110.0;  // fixed chart area height
    const barH   = 80.0;   // max bar height (≤ chartH)
    const minBarH = 6.0;   // min visible bar height

    if (timeline.isEmpty) {
      return _empty('No payout data yet', Icons.bar_chart_rounded, gray);
    }

    final vals = timeline.map((t) => _i((t as Map)['payout'])).toList();
    final maxV = vals.reduce((a, b) => a > b ? a : b);

    return _card(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Expanded(child: Text('Payout by Month',
            style: TextStyle(color: Colors.white, fontSize: 14,
              fontWeight: FontWeight.w800))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(99)),
            child: Text('Last ${timeline.length} month${timeline.length != 1 ? "s" : ""}',
              style: const TextStyle(color: blue, fontSize: 10,
                fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 20),

        SizedBox(
          height: chartH,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(timeline.length, (i) {
              final t    = timeline[i] as Map<String, dynamic>;
              final val  = vals[i];
              final frac = maxV > 0 ? val / maxV : 0.0;
              // bar height with minimum floor
              final height = val == 0 ? minBarH : (frac * barH).clamp(minBarH, barH);
              final monthLabel = (t['month']?.toString() ?? '').split(' ').first;

              return Expanded(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // payout label above bar
                    if (val > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('₹$val',
                          style: const TextStyle(color: blue,
                            fontSize: 9, fontWeight: FontWeight.w700)))
                    else
                      const SizedBox(height: 15),
                    // bar
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6)),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOut,
                        height: height,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: val == 0
                              ? [Colors.white12, Colors.white12]
                              : [blue.withOpacity(0.55), blue],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // month label
                    Text(monthLabel,
                      style: const TextStyle(color: Color(0xFF7A8BB0),
                        fontSize: 10, fontWeight: FontWeight.w600)),
                  ],
                ),
              ));
            }),
          ),
        ),
      ],
    ));
  }

  // ── CLAIM TILE ────────────────────────────────────────────
  Widget _claimTile(Map<String, dynamic> c) {
    final type   = c['trigger_type'] as String?;
    final sev    = c['severity'] as String? ?? 'T2';
    final tc     = _trigCol(type);
    final sevCol = sev == 'T1' ? gold : sev == 'T2' ? blue : red;
    final payout = _i(c['payout_amount']);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: bdr)),
      child: Row(children: [
        // icon box with left accent
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: tc.withOpacity(0.1),
            borderRadius: BorderRadius.circular(11),
            border: Border(left: BorderSide(color: tc, width: 3))),
          child: Center(child: Text(_trigEmoji(type),
            style: const TextStyle(fontSize: 18)))),
        const SizedBox(width: 12),
        // name + zone + date
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Text(_trigName(type),
            style: const TextStyle(color: Colors.white, fontSize: 14,
              fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text('${c['zone'] ?? '—'}',
            style: const TextStyle(color: Color(0xFF7A8BB0), fontSize: 12)),
          Text(_ds(c['created_at']?.toString()),
            style: const TextStyle(color: Color(0xFF4A5E7A), fontSize: 11)),
        ])),
        // severity + payout
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: sevCol.withOpacity(0.14),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: sevCol.withOpacity(0.3))),
            child: Text(sev, style: TextStyle(color: sevCol,
              fontSize: 12, fontWeight: FontWeight.w900))),
          const SizedBox(height: 6),
          Text('₹$payout',
            style: const TextStyle(color: gold, fontSize: 16,
              fontWeight: FontWeight.w900)),
          const Text('payout',
            style: TextStyle(color: Color(0xFF4A5E7A), fontSize: 9)),
        ]),
      ]),
    );
  }

  // ── PREMIUM CARD ──────────────────────────────────────────
  Widget _premCard(List premiums) => _card(
    child: Column(children: premiums.take(5).toList().asMap().entries.map((e) {
      final i = e.key;
      final p = e.value as Map<String, dynamic>;
      return Column(children: [
        if (i > 0) Divider(color: bdr, height: 1),
        Padding(
          padding: EdgeInsets.only(
            top: i == 0 ? 0 : 12, bottom: 12),
          child: Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: grn.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.receipt_long_rounded,
                color: grn, size: 18)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Text('₹${_i(p['amount'])}',
                style: const TextStyle(color: Colors.white, fontSize: 15,
                  fontWeight: FontWeight.w800)),
              Text(
                '${(p['plan_type'] ?? '').toString().toUpperCase()}  ·  '
                '${_ds(p['created_at']?.toString())}  ·  '
                '${p['payment_method'] ?? 'UPI'}',
                style: const TextStyle(color: Color(0xFF7A8BB0), fontSize: 11)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: grn.withOpacity(0.1),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: grn.withOpacity(0.3))),
              child: Text((p['status'] ?? 'paid').toString().toUpperCase(),
                style: const TextStyle(color: grn, fontSize: 9,
                  fontWeight: FontWeight.bold))),
          ]),
        ),
      ]);
    }).toList()),
  );

  // ── FINANCE SUMMARY ───────────────────────────────────────
  Widget _financeSummary(Map<String, dynamic> d, List claims,
      int totalOut, int totalCl) {
    final premiumList = d['premium_payments'] as List? ?? [];
    final totalPrem = premiumList.fold<int>(0,
        (s, p) => s + _i((p as Map)['amount']));
    final lossRatio = totalPrem > 0
        ? ((totalOut / totalPrem) * 100).clamp(0, 999).round() : 0;
    final lrCol = lossRatio > 80 ? red : lossRatio > 50 ? gold : grn;
    final approved = claims.where((c) => c['status'] == 'approved').length;

    return _card(child: Column(children: [
      _summRow(Icons.arrow_upward_rounded,
        'Total Premiums Collected', '₹$totalPrem', grn),
      Divider(color: bdr, height: 20),
      _summRow(Icons.arrow_downward_rounded,
        'Total Payouts Disbursed', '₹$totalOut', gold),
      Divider(color: bdr, height: 20),
      _summRow(Icons.percent_rounded,
        'Loss Ratio', '$lossRatio%', lrCol),
      Divider(color: bdr, height: 20),
      _summRow(Icons.check_circle_rounded,
        'Approved Claims', '$approved', grn),
      Divider(color: bdr, height: 20),
      _summRow(Icons.bolt_rounded,
        'Total Triggers', '$totalCl', blue),
    ]));
  }

  Widget _summRow(IconData icon, String label, String val, Color c) =>
    Row(children: [
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: c.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: c, size: 16)),
      const SizedBox(width: 12),
      Expanded(child: Text(label,
        style: const TextStyle(color: Color(0xFF7A8BB0), fontSize: 13))),
      Text(val, style: TextStyle(color: c, fontSize: 14,
        fontWeight: FontWeight.w800)),
    ]);

  // ── Shared ─────────────────────────────────────────────
  Widget _label(String t) => Text(t,
    style: const TextStyle(color: gray, fontSize: 12,
      fontWeight: FontWeight.w700, letterSpacing: 0.7));

  Widget _card({required Widget child}) => Container(
    width: double.infinity, padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: bdr),
      boxShadow: [BoxShadow(
        color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0,4))]),
    child: child);

  Widget _empty(String msg, IconData icon, Color c) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 28),
    decoration: BoxDecoration(
      color: c.withOpacity(0.04),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: bdr)),
    child: Column(children: [
      Icon(icon, color: c.withOpacity(0.4), size: 36),
      const SizedBox(height: 10),
      Text(msg, style: const TextStyle(color: Colors.white38, fontSize: 13)),
    ]));
}
