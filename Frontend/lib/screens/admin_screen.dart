import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with TickerProviderStateMixin {

  static const bg   = Color(0xFFE8EDFF);
  static const navy = Color(0xFF1A2E6E);
  static const gold = Color(0xFFF5A623);
  static const gray = Color(0xFF7A8BB0);
  static const bdr  = Color(0xFFCDD8F6);

  Map<String, dynamic> stats  = {};
  List<dynamic>        claims = [];
  bool loading = true;

  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  final List<Map<String, dynamic>> zoneRisks = [
    {'name': 'Koramangala', 'score': 72, 'level': 'HIGH'},
    {'name': 'HSR Layout',  'score': 65, 'level': 'HIGH'},
    {'name': 'Marathahalli','score': 55, 'level': 'MED'},
    {'name': 'Indiranagar', 'score': 45, 'level': 'MED'},
    {'name': 'Whitefield',  'score': 30, 'level': 'LOW'},
    {'name': 'Bellandur',   'score': 48, 'level': 'MED'},
  ];

  final List<Map<String, dynamic>> activeTriggers = [
    {'type': 'Heavy Rain', 'zone': 'Koramangala',
      'tier': 'T2', 'time': '12:34 PM', 'color': Color(0xFF4B9FFF)},
    {'type': 'Severe AQI', 'zone': 'HSR Layout',
      'tier': 'T2', 'time': '11:20 AM', 'color': Color(0xFF9C6FFF)},
  ];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this,
      duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(
      parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
    _load();
  }

  @override
  void dispose() { _fadeCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    final s = await ApiService.getAdminStats();
    final c = await ApiService.getAdminClaims();
    setState(() { stats = s; claims = c; loading = false; });
  }

  Color _rc(String l) {
    if (l == 'HIGH') return const Color(0xFFFF5252);
    if (l == 'MED')  return gold;
    return const Color(0xFF00C853);
  }

  Color _rb(String l) {
    if (l == 'HIGH') return const Color(0xFFFF5252).withOpacity(0.12);
    if (l == 'MED')  return gold.withOpacity(0.12);
    return const Color(0xFF00C853).withOpacity(0.12);
  }

  Color _sc(String? s) {
    if (s == 'approved')   return const Color(0xFF00C853);
    if (s == 'processing') return gold;
    if (s == 'rejected')   return const Color(0xFFFF5252);
    return gray;
  }

  String _st(String? t) {
    switch (t) {
      case 'heavy_rain':   return 'Rain';
      case 'flood_alert':  return 'Flood';
      case 'extreme_heat': return 'Heat';
      case 'severe_aqi':   return 'AQI';
      default:             return t?.substring(0, 4) ?? '-';
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: bg,
    body: Stack(children: [
      Positioned(top: -80, right: -60,
        child: _blob(220, const Color(0xFF7B9CFF).withOpacity(0.2))),
      Positioned(bottom: 100, left: -80,
        child: _blob(260, const Color(0xFF5B6FBE).withOpacity(0.12))),
      SafeArea(child: Column(children: [
        _appBar(),
        Expanded(
          child: loading
            ? const Center(child: CircularProgressIndicator(color: navy))
            : FadeTransition(opacity: _fadeAnim, child: _body()),
        ),
      ])),
    ]),
  );

  Widget _appBar() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
    child: Row(children: [
      const Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Insurify Admin',
            style: TextStyle(color: navy, fontSize: 20,
              fontWeight: FontWeight.w900)),
          Text('Live insurance monitor',
            style: TextStyle(color: gray, fontSize: 12)),
        ],
      )),
      // Refresh
      GestureDetector(
        onTap: _load,
        child: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: bdr),
          ),
          child: const Icon(Icons.refresh_rounded, color: navy, size: 20),
        ),
      ),
      const SizedBox(width: 8),
      // Exit button
      GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFF5252).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFFFF5252).withOpacity(0.35)),
          ),
          child: const Row(children: [
            Icon(Icons.logout_rounded,
              color: Color(0xFFFF5252), size: 16),
            SizedBox(width: 4),
            Text('Exit', style: TextStyle(
              color:      Color(0xFFFF5252),
              fontSize:   12,
              fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    ]),
  );

  Widget _body() => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // Stats grid
      Row(children: [
        _statCard('${stats['total_workers'] ?? 4}',
          'Workers',  navy,  Icons.people_rounded),
        const SizedBox(width: 10),
        _statCard('${stats['active_policies'] ?? 4}',
          'Policies', const Color(0xFF00C853),
          Icons.shield_rounded),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        _statCard('₹${stats['total_paid_out'] ?? 0}',
          'Paid Out', gold,  Icons.account_balance_wallet_rounded),
        const SizedBox(width: 10),
        _statCard('${stats['fraud_flags'] ?? 0}',
          'Fraud Flags',
          (int.tryParse('${stats['fraud_flags'] ?? 0}') ?? 0) > 0
            ? const Color(0xFFFF5252)
            : const Color(0xFF00C853),
          Icons.security_rounded),
      ]),
      const SizedBox(height: 24),

      // Active triggers
      _label('Active Triggers Today'),
      const SizedBox(height: 10),
      ...activeTriggers.map((t) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: bdr),
          boxShadow: [BoxShadow(
            color: (t['color'] as Color).withOpacity(0.1),
            blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Row(children: [
          Container(
            width: 10, height: 10,
            decoration: BoxDecoration(
              color: t['color'] as Color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(
            '${t['type']} · ${t['zone']}',
            style: const TextStyle(color: navy, fontSize: 14,
              fontWeight: FontWeight.w600))),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (t['color'] as Color).withOpacity(0.12),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(t['tier'] as String,
              style: TextStyle(color: t['color'] as Color,
                fontSize: 11, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          Text(t['time'] as String,
            style: const TextStyle(color: gray, fontSize: 11)),
        ]),
      )),

      const SizedBox(height: 24),

      // Zone risk heatmap
      _label('Zone Risk Heatmap'),
      const SizedBox(height: 10),
      _glass(child: Column(
        children: zoneRisks.map((z) {
          final score = z['score'] as int;
          final level = z['level'] as String;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              SizedBox(width: 100,
                child: Text(z['name'] as String,
                  style: const TextStyle(color: navy, fontSize: 13,
                    fontWeight: FontWeight.w600))),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: score / 100,
                    backgroundColor: bdr,
                    valueColor: AlwaysStoppedAnimation(_rc(level)),
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(width: 34,
                child: Text('$score%',
                  style: const TextStyle(color: gray, fontSize: 11))),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _rb(level),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(level,
                  style: TextStyle(color: _rc(level),
                    fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ]),
          );
        }).toList(),
      )),

      const SizedBox(height: 24),

      // Loss ratio
      _label('Loss Ratio Analysis'),
      const SizedBox(height: 10),
      Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [navy, Color(0xFF22387E)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
            color: navy.withOpacity(0.3),
            blurRadius: 20, offset: const Offset(0, 8))],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          _lrow('Total premiums collected',
            '₹${stats['total_premiums'] ?? 276}', Colors.white60),
          const SizedBox(height: 8),
          _lrow('Total paid out',
            '₹${stats['total_paid_out'] ?? 0}', gold),
          const SizedBox(height: 16),
          const Divider(color: Colors.white12),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Loss Ratio',
              style: TextStyle(color: Colors.white,
                fontSize: 16, fontWeight: FontWeight.w700)),
            const Text('489%',
              style: TextStyle(color: Color(0xFFFF5252),
                fontSize: 24, fontWeight: FontWeight.w900)),
          ]),
          const SizedBox(height: 6),
          const Text(
            'Expected for early stage — explain in pitch deck',
            style: TextStyle(color: Colors.white38, fontSize: 11)),
        ]),
      ),

      const SizedBox(height: 24),

      // Claims table
      _label('Recent Claims Feed'),
      const SizedBox(height: 10),
      _glass(child: Column(children: [
        // Header row
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            _th('Worker', 2),
            _th('Zone',   2),
            _th('Type',   1),
            _th('Payout', 1),
            _th('Status', 2),
          ]),
        ),
        const Divider(color: bdr, height: 1),
        const SizedBox(height: 8),
        if (claims.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: Text('No claims yet',
              style: TextStyle(color: gray, fontSize: 13))),
          )
        else ...claims.take(8).map((c) {
          final s  = c['status'] as String? ?? 'processing';
          final sc = _sc(s);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(children: [
              _td((c['name'] ?? '-').toString().split(' ').first, 2),
              _td(_sz(c['zone']),     2),
              _td(_st(c['trigger_type']), 1),
              _td('₹${c['payout_amount'] ?? 0}', 1, gold),
              Expanded(flex: 2, child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: sc.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(s, style: TextStyle(
                  color: sc, fontSize: 10,
                  fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis),
              )),
            ]),
          );
        }),
      ])),
    ]),
  );

  Widget _lrow(String l, String v, Color c) =>
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(l, style: const TextStyle(
        color: Colors.white54, fontSize: 13)),
      Text(v, style: TextStyle(
        color: c, fontSize: 16, fontWeight: FontWeight.w700)),
    ]);

  Widget _statCard(String val, String label,
      Color color, IconData icon) => Expanded(
    child: ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.75),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.9)),
            boxShadow: [BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(val, style: TextStyle(
                color: color, fontSize: 20,
                fontWeight: FontWeight.w900)),
              Text(label, style: const TextStyle(
                color: gray, fontSize: 11)),
            ]),
          ]),
        ),
      ),
    ),
  );

  Widget _glass({required Widget child}) => ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.75),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.9), width: 1.5),
          boxShadow: [BoxShadow(
            color: const Color(0xFF7B9CFF).withOpacity(0.08),
            blurRadius: 16, offset: const Offset(0, 4))],
        ),
        padding: const EdgeInsets.all(16),
        child:   child,
      ),
    ),
  );

  Widget _th(String t, int f) => Expanded(flex: f,
    child: Text(t, style: const TextStyle(
      color: gray, fontSize: 11, fontWeight: FontWeight.w700)));

  Widget _td(String t, int f, [Color c = const Color(0xFF1A2E6E)]) =>
    Expanded(flex: f, child: Text(t,
      style: TextStyle(color: c, fontSize: 12,
        fontWeight: FontWeight.w600),
      overflow: TextOverflow.ellipsis));

  String _sz(String? z) {
    if (z == null) return '-';
    return z.length <= 8 ? z : '${z.substring(0, 7)}..';
  }

  Widget _label(String t) => Text(t,
    style: const TextStyle(color: gray, fontSize: 12,
      fontWeight: FontWeight.w700, letterSpacing: 0.8));

  Widget _blob(double s, Color c) => Container(
    width: s, height: s,
    decoration: BoxDecoration(shape: BoxShape.circle, color: c));
}
