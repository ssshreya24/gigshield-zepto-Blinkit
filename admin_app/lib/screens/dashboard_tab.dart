import 'dart:async';
import 'package:flutter/material.dart';
import '../services/admin_api.dart';
import 'plan_types_screen.dart'; // ← ADDED
import 'package:shared_preferences/shared_preferences.dart';
import 'admin_login.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});
  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  static const gold = Color(0xFFF5A623);
  static const gray = Color(0xFF7A8BB0);
  static const navy = Color(0xFF1A2E6E);
  static const bdr  = Color(0xFF1E2E45);

  Map<String, dynamic> stats    = {};
  List<dynamic>        triggers = [];
  List<dynamic>        zones    = [];
  bool loading = true;
  Timer? _timer;

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
    final s = await AdminApi.getStats();
    final t = await AdminApi.getTriggers();
    final rawZones = await AdminApi.getZones();
    
    final mappedZones = rawZones.map((x) {
        final triggers = int.tryParse(x['active_triggers'].toString()) ?? 0;
        final score = triggers > 10 ? 95 : (triggers > 3 ? 65 : 30);
        final level = triggers > 10 ? 'HIGH' : (triggers > 3 ? 'MED' : 'LOW');
        return {'name': x['zone'], 'score': score, 'level': level};
    }).toList();

    if (mounted) setState(() {
      stats = s; triggers = t; zones = mappedZones; loading = false; });
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('admin_token');
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AdminLogin()),
        (_) => false,
      );
    }
  }

  int _i(dynamic v) {
    if (v == null) return 0;
    if (v is int)    return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  String _lossRatio() {
    final p = _i(stats['total_premiums']);
    final o = _i(stats['total_paid_out']);
    if (p == 0) return '0%';
    return '${((o / p) * 100).round()}%';
  }

  Color _rc(String l) => l == 'HIGH'
    ? const Color(0xFFFF5252)
    : l == 'MED' ? gold : const Color(0xFF00C853);

  String _tn(String? t) {
    switch (t) {
      case 'heavy_rain':   return '🌧 Heavy Rain';
      case 'flood_alert':  return '🌊 Flood Alert';
      case 'extreme_heat': return '🌡 Extreme Heat';
      case 'severe_aqi':   return '💨 Severe AQI';
      default:             return '⚡ ${t ?? 'Trigger'}';
    }
  }

  // ── ADDED: Fire Trigger bottom sheet ─────────────────────────
  void _showFireTriggerSheet(BuildContext context) {
    const zones = [
      'Koramangala','HSR Layout','Andheri',
      'Velachery','Marathahalli','Gachibowli',
    ];
    const types = [
      {'label': '🌧️ Heavy Rain',   'type': 'heavy_rain',   'sev': 'T2', 'val': 85},
      {'label': '🌊 Flood Alert',  'type': 'flood_alert',  'sev': 'T3', 'val': 95},
      {'label': '🌡️ Extreme Heat', 'type': 'extreme_heat', 'sev': 'T1', 'val': 44},
      {'label': '😷 Severe AQI',   'type': 'severe_aqi',   'sev': 'T2', 'val': 310},
      {'label': '🚫 Curfew',       'type': 'curfew',       'sev': 'T3', 'val': 1},
      {'label': '🌀 Cyclone',      'type': 'cyclone',      'sev': 'T3', 'val': 1},
    ];

    String selectedZone = zones[0];
    int    selectedType = 0;
    bool   firing       = false;

    showModalBottomSheet(
      context:            context,
      backgroundColor:    Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setBS) => Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color:        Color(0xFF13243A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2E45),
                  borderRadius: BorderRadius.circular(99)),
              )),
              const SizedBox(height: 20),
              const Text('Fire Demo Trigger',
                style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800,
                  color: Colors.white)),
              const SizedBox(height: 20),

              // Zone picker
              const Text('Zone',
                style: TextStyle(fontSize: 12, color: Color(0xFF7A8BB0),
                  fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value:    selectedZone,
                dropdownColor: const Color(0xFF13243A),
                style:    const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled:    true,
                  fillColor: const Color(0xFF1E2E45).withOpacity(0.4),
                  border:    OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                ),
                items: zones.map((z) => DropdownMenuItem(
                  value: z, child: Text(z))).toList(),
                onChanged: (v) => setBS(() => selectedZone = v!),
              ),
              const SizedBox(height: 16),

              // Trigger type picker
              const Text('Trigger Type',
                style: TextStyle(fontSize: 12, color: Color(0xFF7A8BB0),
                  fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: List.generate(types.length, (i) {
                  final active = selectedType == i;
                  return GestureDetector(
                    onTap: () => setBS(() => selectedType = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: active
                            ? Colors.redAccent.withOpacity(0.15)
                            : const Color(0xFF1E2E45).withOpacity(0.4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: active
                              ? Colors.redAccent.withOpacity(0.5)
                              : const Color(0xFF1E2E45),
                        ),
                      ),
                      child: Text(types[i]['label'] as String,
                        style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: active ? Colors.redAccent : const Color(0xFF7A8BB0))),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),

              // Fire button
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton.icon(
                  onPressed: firing ? null : () async {
                    setBS(() => firing = true);
                    final t = types[selectedType];
                    await AdminApi.fireTrigger(
                      zone:     selectedZone,
                      type:     t['type'] as String,
                      severity: t['sev']  as String,
                      value:    t['val']  as int,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${t['label']} fired in $selectedZone!'),
                          backgroundColor:  const Color(0xFF1A2E6E),
                          behavior:         SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          margin: const EdgeInsets.all(16),
                        ),
                      );
                    }
                  },
                  icon:  const Icon(Icons.bolt_rounded,
                      color: Colors.white, size: 18),
                  label: firing
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : const Text('Fire Trigger',
                          style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    disabledBackgroundColor:
                        Colors.redAccent.withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) => loading
    ? const Center(child: CircularProgressIndicator(color: gold))
    : RefreshIndicator(
        onRefresh: _load, color: gold,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(),
              const SizedBox(height: 20),

              // Stats
              Row(children: [
                _statCard('${_i(stats['total_workers'])}',
                  'Workers', const Color(0xFF4B9FFF),
                  Icons.people_rounded),
                const SizedBox(width: 10),
                _statCard('${_i(stats['active_policies'])}',
                  'Policies', const Color(0xFF00C853),
                  Icons.shield_rounded),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                _statCard('₹${_i(stats['total_paid_out'])}',
                  'Paid Out', gold,
                  Icons.account_balance_wallet_rounded),
                const SizedBox(width: 10),
                _statCard('${_i(stats['fraud_flags'])}',
                  'Fraud Flags',
                  _i(stats['fraud_flags']) > 0
                    ? const Color(0xFFFF5252)
                    : const Color(0xFF00C853),
                  Icons.security_rounded),
              ]),
              const SizedBox(height: 20),

              // Financial summary
              Container(
                width:   double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A2E6E), Color(0xFF0F1E45)],
                    begin: Alignment.topLeft,
                    end:   Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: bdr)),
                child: Column(children: [
                  Row(mainAxisAlignment:
                      MainAxisAlignment.spaceBetween, children: [
                    const Text('Financial Summary',
                      style: TextStyle(color: Colors.white,
                        fontSize: 15, fontWeight: FontWeight.w700)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: gold.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(99)),
                      child: const Text('This week',
                        style: TextStyle(color: gold,
                          fontSize: 11, fontWeight: FontWeight.w700))),
                  ]),
                  const SizedBox(height: 16),
                  Row(children: [
                    _fin('Premiums',
                      '₹${_i(stats['total_premiums'])}',
                      const Color(0xFF00C853)),
                    _vd(),
                    _fin('Paid Out',
                      '₹${_i(stats['total_paid_out'])}',
                      const Color(0xFFFF5252)),
                    _vd(),
                    _fin('Loss Ratio', _lossRatio(), gold),
                  ]),
                ]),
              ),
              const SizedBox(height: 20),

              // ── ADDED: Quick Actions Row ───────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Quick Actions',
                      style: TextStyle(
                        fontSize:   14,
                        fontWeight: FontWeight.w700,
                        color:      Colors.white)),
                    const SizedBox(height: 12),
                    Row(children: [

                      // Manage Plans
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PlanTypesScreen())),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color:        const Color(0xFF13243A),
                              borderRadius: BorderRadius.circular(16),
                              border:       Border.all(
                                  color: const Color(0xFF9C6FFF).withOpacity(0.35)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 36, height: 36,
                                  decoration: BoxDecoration(
                                    color:        const Color(0xFF9C6FFF).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.dashboard_customize_rounded,
                                      color: Color(0xFF9C6FFF), size: 18),
                                ),
                                const SizedBox(height: 10),
                                const Text('Manage Plans',
                                  style: TextStyle(
                                    fontSize:   13,
                                    fontWeight: FontWeight.w700,
                                    color:      Colors.white)),
                                const SizedBox(height: 2),
                                const Text('Edit pricing & toggles',
                                  style: TextStyle(
                                    fontSize: 10, color: Color(0xFF7A8BB0))),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Fire Demo Trigger
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _showFireTriggerSheet(context),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color:        const Color(0xFF13243A),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: Colors.redAccent.withOpacity(0.35)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 36, height: 36,
                                  decoration: BoxDecoration(
                                    color:        Colors.redAccent.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.bolt_rounded,
                                      color: Colors.redAccent, size: 18),
                                ),
                                const SizedBox(height: 10),
                                const Text('Fire Trigger',
                                  style: TextStyle(
                                    fontSize:   13,
                                    fontWeight: FontWeight.w700,
                                    color:      Colors.white)),
                                const SizedBox(height: 2),
                                const Text('Simulate event',
                                  style: TextStyle(
                                    fontSize: 10, color: Color(0xFF7A8BB0))),
                              ],
                            ),
                          ),
                        ),
                      ),

                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // ──────────────────────────────────────────────────

              // Fire triggers (original inline quick-fire row)
              _label('Demo Controls'),
              const SizedBox(height: 10),
              _card(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Fire trigger manually',
                    style: TextStyle(color: Colors.white,
                      fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  const Text('Fires for all workers in Koramangala',
                    style: TextStyle(color: gray, fontSize: 11)),
                  const SizedBox(height: 14),
                  Row(children: [
                    _trigBtn('🌧 Rain',  'heavy_rain',
                      'T2', const Color(0xFF4B9FFF)),
                    const SizedBox(width: 8),
                    _trigBtn('🌊 Flood', 'flood_alert',
                      'T3', const Color(0xFFFF5252)),
                    const SizedBox(width: 8),
                    _trigBtn('🌡 Heat',  'extreme_heat',
                      'T1', gold),
                    const SizedBox(width: 8),
                    _trigBtn('💨 AQI',   'severe_aqi',
                      'T2', const Color(0xFF9C6FFF)),
                  ]),
                ],
              )),
              const SizedBox(height: 20),

              // Recent triggers
              _label('Recent Triggers'),
              const SizedBox(height: 10),
              if (triggers.isEmpty)
                _emptyBox('No triggers fired', 'All zones clear')
              else
                ...triggers.take(5).map((e) => _trigRow(e as Map<String, dynamic>)),
              const SizedBox(height: 20),

              // Zone heatmap
              _label('Zone Risk Heatmap'),
              const SizedBox(height: 10),
              _card(child: Column(
                children: zones.map((z) {
                  final sc = z['score'] as int;
                  final rc = _rc(z['level'] as String);
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 7),
                    child: Row(children: [
                      SizedBox(width: 95, child: Text(
                        z['name'] as String,
                        style: const TextStyle(
                          color: Colors.white, fontSize: 12,
                          fontWeight: FontWeight.w600))),
                      const SizedBox(width: 8),
                      Expanded(child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value:           sc / 100,
                          backgroundColor:
                            Colors.white.withOpacity(0.08),
                          valueColor:
                            AlwaysStoppedAnimation(rc),
                          minHeight: 8))),
                      const SizedBox(width: 8),
                      SizedBox(width: 30, child: Text(
                        '$sc%', style: const TextStyle(
                          color: Colors.white38, fontSize: 10))),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: rc.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(99)),
                        child: Text(z['level'] as String,
                          style: TextStyle(color: rc,
                            fontSize: 9,
                            fontWeight: FontWeight.bold))),
                    ]),
                  );
                }).toList(),
              )),
            ],
          ),
        ),
      );

  Widget _header() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        Text('Dashboard', style: TextStyle(color: Colors.white,
          fontSize: 24, fontWeight: FontWeight.w900)),
        Text('Live operations', style: TextStyle(
          color: gray, fontSize: 13)),
      ]),
      GestureDetector(
        onTap: _logout,
        child: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFFF5252).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.logout_rounded,
            color: Color(0xFFFF5252), size: 18),
        ),
      ),
  ]);

  Widget _trigBtn(String label, String type,
      String sev, Color color) =>
    Expanded(child: GestureDetector(
      onTap: () async {
        await AdminApi.fireTrigger(
          zone: 'Koramangala', type: type, severity: sev);
        _load();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$label fired! 🔥'),
            backgroundColor: color,
            duration: const Duration(seconds: 2)));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color:        color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border:       Border.all(color: color.withOpacity(0.3))),
        child: Center(child: Text(label,
          textAlign: TextAlign.center,
          style: TextStyle(color: color, fontSize: 10,
            fontWeight: FontWeight.w700))),
      ),
    ));

  Widget _trigRow(Map<String, dynamic> t) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color:        Colors.white.withOpacity(0.04),
      borderRadius: BorderRadius.circular(12),
      border:       Border.all(color: bdr)),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
      Text(_tn(t['trigger_type'] as String?),
        style: const TextStyle(fontSize: 18)),
      const SizedBox(width: 12),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t['zone'] as String? ?? '',
            style: const TextStyle(color: Colors.white,
              fontSize: 13, fontWeight: FontWeight.w600)),
          Text(
            (t['created_at']?.toString() ?? '')
              .substring(0, 10),
            style: const TextStyle(
              color: gray, fontSize: 11)),
        ],
      )),
      Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF4B9FFF).withOpacity(0.1),
          borderRadius: BorderRadius.circular(99)),
        child: Text(t['severity'] as String? ?? 'T2',
          style: const TextStyle(
            color:      Color(0xFF4B9FFF),
            fontSize:   11,
            fontWeight: FontWeight.bold))),
    ]),
  );

  Widget _statCard(String val, String label,
      Color color, IconData icon) =>
    Expanded(child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: color.withOpacity(0.2))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 22)),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Text(val, style: TextStyle(color: color,
            fontSize: 20, fontWeight: FontWeight.w900)),
          Text(label, style: const TextStyle(
            color: gray, fontSize: 10)),
        ]),
      ]),
    ));

  Widget _fin(String l, String v, Color c) => Expanded(
    child: Column(children: [
      Text(v, style: TextStyle(color: c, fontSize: 18,
        fontWeight: FontWeight.w900)),
      const SizedBox(height: 2),
      Text(l, style: const TextStyle(
        color: Colors.white38, fontSize: 10)),
    ]));

  Widget _vd() => Container(
    width: 1, height: 36,
    color: Colors.white.withOpacity(0.08));

  Widget _card({required Widget child}) => Container(
    width: double.infinity, padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color:        Colors.white.withOpacity(0.04),
      borderRadius: BorderRadius.circular(16),
      border:       Border.all(color: bdr)),
    child: child);

  Widget _emptyBox(String t, String s) => Container(
    width:   double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 24),
    decoration: BoxDecoration(
      color:        Colors.white.withOpacity(0.03),
      borderRadius: BorderRadius.circular(12),
      border:       Border.all(color: bdr)),
    child: Column(children: [
      const Icon(Icons.bolt_rounded,
        color: Colors.white24, size: 32),
      const SizedBox(height: 8),
      Text(t, style: const TextStyle(color: Colors.white38,
        fontSize: 14, fontWeight: FontWeight.w600)),
      Text(s, style: const TextStyle(
        color: Colors.white24, fontSize: 12)),
    ]));

  Widget _label(String t) => Text(t,
    style: const TextStyle(color: gray, fontSize: 12,
      fontWeight: FontWeight.w700, letterSpacing: 0.7));
}
