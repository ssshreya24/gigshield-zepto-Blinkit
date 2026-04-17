import 'dart:async';
import 'package:flutter/material.dart';
import '../services/admin_api.dart';
import 'plan_types_screen.dart';
import 'payments_tab.dart';
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
  bool loading = true;
  Timer? _timer;

  final zones = [
    {'name': 'Koramangala', 'score': 72, 'level': 'HIGH'},
    {'name': 'HSR Layout',  'score': 65, 'level': 'HIGH'},
    {'name': 'Marathahalli','score': 55, 'level': 'MED'},
    {'name': 'Indiranagar', 'score': 45, 'level': 'MED'},
    {'name': 'Bellandur',   'score': 48, 'level': 'MED'},
    {'name': 'Whitefield',  'score': 30, 'level': 'LOW'},
  ];

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
    if (mounted) setState(() {
      stats = s; triggers = t; loading = false; });
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
      {'label': '🚫 Curfew',           'type': 'curfew',           'sev': 'T3', 'val': 1},
      {'label': '🌀 Cyclone',          'type': 'cyclone',          'sev': 'T3', 'val': 1},
      {'label': '🛑 Platform Shutdown','type': 'platform_shutdown','sev': 'T3', 'val': 1},
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
              const Text('Fire Manual Override Trigger',
                style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800,
                  color: Colors.white)),
              const SizedBox(height: 20),

              // Zone picker
              const Text('Target Zone',
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

              // ── Quick Actions ──────────────────────────────────
              const Text('Quick Actions',
                style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 12),
              Row(children: [
                // Manage Policy
                Expanded(child: GestureDetector(
                  onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const PlanTypesScreen())),
                  child: _qaCard(Icons.shield_rounded, const Color(0xFF00C853),
                    'Manage Policy', 'Plans & coverage'),
                )),
                const SizedBox(width: 10),
                // Payments
                Expanded(child: GestureDetector(
                  onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => Scaffold(
                      backgroundColor: const Color(0xFF0D1829),
                      appBar: AppBar(
                        backgroundColor: const Color(0xFF0D1829),
                        elevation: 0,
                        leading: IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 18),
                          onPressed: () => Navigator.pop(context)),
                        title: const Text('Payments', style: TextStyle(
                          color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
                      body: const PaymentsTab()))),
                  child: _qaCard(Icons.payment_rounded, gold,
                    'Payments', 'Revenue & receipts'),
                )),
                const SizedBox(width: 10),
                // Support
                Expanded(child: GestureDetector(
                  onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AdminSupportScreen())),
                  child: _qaCard(Icons.support_agent_rounded,
                    const Color(0xFF4B9FFF), 'Support', 'Help tickets'),
                )),
              ]),
              const SizedBox(height: 20),

              // Manual Overrides (backend unchanged)
              _label('Manual Overrides'),
              const SizedBox(height: 10),
              _card(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Fire administrative triggers',
                    style: TextStyle(color: Colors.white,
                      fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  const Text('Fires immediately for target zones. No weather threshold needed.',
                    style: TextStyle(color: gray, fontSize: 11)),
                  const SizedBox(height: 14),
                  Row(children: [
                    _trigBtn('🚫 Curfew',  'curfew',  'T3', const Color(0xFFFF5252)),
                    const SizedBox(width: 8),
                    _trigBtn('🌀 Cyclone', 'cyclone', 'T3', const Color(0xFF4B9FFF)),
                    const SizedBox(width: 8),
                    _trigBtn('🛑 Shutdown','platform_shutdown','T3',const Color(0xFF9C6FFF)),
                  ]),
                ],
              )),
              const SizedBox(height: 20),

              // ── Recent Triggers (image-matched) ───────────────
              _recentTriggersSection(),
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
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Text(val, style: TextStyle(color: color,
            fontSize: 20, fontWeight: FontWeight.w900)),
          Text(label, style: const TextStyle(
            color: gray, fontSize: 10, overflow: TextOverflow.ellipsis)),
        ])),
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

  // ── QA card helper ──────────────────────────────────────────
  Widget _qaCard(IconData icon, Color color, String title, String sub) =>
    Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF13243A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.35))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 17)),
        const SizedBox(height: 8),
        Text(title, style: const TextStyle(fontSize: 12,
          fontWeight: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 2),
        Text(sub, style: const TextStyle(fontSize: 9, color: Color(0xFF7A8BB0))),
      ]),
    );

  // ── Recent Triggers section (image-matched) ──────────────────
  Widget _recentTriggersSection() => Container(
    decoration: BoxDecoration(
      color: const Color(0xFF0F1F35),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFF1E3352))),
    child: Column(children: [
      // Header row
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Row(children: [
          const Text('Recent Triggers',
            style: TextStyle(color: Colors.white, fontSize: 16,
              fontWeight: FontWeight.w800)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF00C853).withOpacity(0.12),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: const Color(0xFF00C853).withOpacity(0.35))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 6, height: 6,
                decoration: const BoxDecoration(
                  color: Color(0xFF00C853), shape: BoxShape.circle)),
              const SizedBox(width: 5),
              const Text('Live', style: TextStyle(
                color: Color(0xFF00C853), fontSize: 11, fontWeight: FontWeight.w700)),
            ])),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => AllTriggersScreen(triggers: triggers))),
            child: const Text('See all',
              style: TextStyle(color: Color(0xFF4B9FFF), fontSize: 12,
                fontWeight: FontWeight.w700))),
        ]),
      ),
      // Trigger rows
      if (triggers.isEmpty)
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: const [
            Icon(Icons.bolt_rounded, color: Colors.white24, size: 32),
            SizedBox(height: 8),
            Text('No triggers fired',
              style: TextStyle(color: Colors.white38, fontSize: 13)),
          ]))
      else
        ...triggers.take(5).map((e) => _newTrigRow(e as Map<String, dynamic>)),
      // View all button
      GestureDetector(
        onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => AllTriggersScreen(triggers: triggers))),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(18)),
            border: Border(top: BorderSide(color: const Color(0xFF1E3352)))),
          child: const Center(child: Text('View all triggers  →',
            style: TextStyle(color: Colors.white38, fontSize: 13,
              fontWeight: FontWeight.w600))),
        ),
      ),
    ]),
  );

  // ── New styled trigger row ───────────────────────────────────
  Widget _newTrigRow(Map<String, dynamic> t) {
    final type = t['trigger_type'] as String? ?? '';
    final sev  = t['severity']     as String? ?? 'T2';
    final val  = t['value'];
    final zone = t['zone']         as String? ?? '';
    final date = (t['created_at']?.toString() ?? '').length >= 10
        ? t['created_at'].toString().substring(0, 10) : '';

    // Colors & icon per trigger type
    Color lineCol;
    IconData ic;
    String valLabel;
    switch (type) {
      case 'heavy_rain':   lineCol = const Color(0xFF4B9FFF); ic = Icons.water_drop_rounded;  valLabel = val != null ? '${val}mm'  : ''; break;
      case 'flood_alert':  lineCol = const Color(0xFF00C853); ic = Icons.flood_rounded;        valLabel = val != null ? '${val}mm'  : ''; break;
      case 'extreme_heat': lineCol = const Color(0xFFFF5252); ic = Icons.thermostat_rounded;   valLabel = val != null ? '${val}°C'  : ''; break;
      case 'severe_aqi':   lineCol = const Color(0xFF9C6FFF); ic = Icons.air_rounded;          valLabel = val != null ? 'AQI $val'  : ''; break;
      default:             lineCol = gold;                     ic = Icons.bolt_rounded;          valLabel = val?.toString() ?? '';
    }
    final sevCol = sev == 'T3' ? const Color(0xFFFF5252)
                 : sev == 'T2' ? const Color(0xFF4B9FFF)
                 : gold;
    final pct    = sev == 'T1' ? '25%' : sev == 'T2' ? '50%' : '100%';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E3352))),
      child: Row(children: [
        // Left accent + icon
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: lineCol.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border(left: BorderSide(color: lineCol, width: 3))),
          child: Icon(ic, color: lineCol, size: 20)),
        const SizedBox(width: 12),
        // Name + zone + date
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_tn(type).replaceAll(RegExp(r'^.{2}'), '').trim(),
            style: const TextStyle(color: Colors.white, fontSize: 14,
              fontWeight: FontWeight.w700)),
          Text(zone, style: const TextStyle(color: Color(0xFF7A8BB0), fontSize: 12)),
          Text(date, style: const TextStyle(color: Color(0xFF4A5E7A), fontSize: 11)),
        ])),
        // Tier badge + value
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: sevCol.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8)),
            child: Text(sev, style: TextStyle(color: sevCol,
              fontSize: 12, fontWeight: FontWeight.w900))),
          const SizedBox(height: 3),
          Text(valLabel.isNotEmpty ? valLabel : pct,
            style: const TextStyle(color: Color(0xFF7A8BB0), fontSize: 11)),
        ]),
      ]),
    );
  }

  Widget _label(String t) => Text(t,
    style: const TextStyle(color: gray, fontSize: 12,
      fontWeight: FontWeight.w700, letterSpacing: 0.7));
}

// ═══════════════════════════════════════════════════════════════
//  ADMIN SUPPORT SCREEN — Worker help tickets
// ═══════════════════════════════════════════════════════════════
class AdminSupportScreen extends StatefulWidget {
  const AdminSupportScreen({super.key});
  @override
  State<AdminSupportScreen> createState() => _AdminSupportScreenState();
}

class _AdminSupportScreenState extends State<AdminSupportScreen> {
  static const bg   = Color(0xFF0D1829);
  static const gold = Color(0xFFF5A623);
  static const gray = Color(0xFF7A8BB0);
  static const bdr  = Color(0xFF1E3352);

  List<dynamic> _tickets = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final t = await AdminApi.getSupportTickets();
    if (mounted) setState(() { _tickets = t; _loading = false; });
  }

  Future<void> _resolve(int ticketId) async {
    await AdminApi.resolveTicket(ticketId);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Support Queries',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF4B9FFF)))
        : _tickets.isEmpty
          ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.inbox_rounded, color: Colors.white24, size: 48),
              SizedBox(height: 12),
              Text('No support tickets yet.',
                style: TextStyle(color: Colors.white38, fontSize: 15)),
            ]))
          : RefreshIndicator(
              onRefresh: _load,
              color: const Color(0xFF4B9FFF),
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _tickets.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) => _ticketCard(_tickets[i]),
              ),
            ),
    );
  }

  Widget _ticketCard(Map<String, dynamic> t) {
    final isOpen     = t['status'] == 'open';
    final statusCol  = isOpen ? const Color(0xFFF5A623) : const Color(0xFF00C853);
    final statusLabel= isOpen ? 'Open' : 'Resolved';
    final createdAt  = t['created_at']?.toString().substring(0, 16).replaceAll('T', ' ') ?? '';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F1F35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: bdr),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF4B9FFF).withOpacity(0.15),
            radius: 20,
            child: Text(
              (t['worker_name'] ?? 'W').substring(0, 1).toUpperCase(),
              style: const TextStyle(color: Color(0xFF4B9FFF), fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t['worker_name'] ?? 'Unknown Worker',
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
            Text('#GS-${t['worker_id']} · ${t['worker_phone'] ?? ''} · ${t['zone'] ?? ''} · ${(t['plan_type'] ?? '').toString().toUpperCase()}',
              style: const TextStyle(color: Color(0xFF7A8BB0), fontSize: 11)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusCol.withOpacity(0.12),
              borderRadius: BorderRadius.circular(99)),
            child: Text(statusLabel,
              style: TextStyle(color: statusCol, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 12),
        Text(t['subject'] ?? 'General Query',
          style: const TextStyle(color: Color(0xFF4B9FFF), fontSize: 12,
            fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        const SizedBox(height: 6),
        Text(t['message'] ?? '',
          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5)),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(createdAt, style: const TextStyle(color: Color(0xFF7A8BB0), fontSize: 11)),
          if (isOpen)
            GestureDetector(
              onTap: () => _resolve(t['id'] as int),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFF00C853).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: const Color(0xFF00C853).withOpacity(0.4))),
                child: const Text('Mark Resolved',
                  style: TextStyle(color: Color(0xFF00C853),
                    fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ),
        ]),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  ALL TRIGGERS SCREEN
// ═══════════════════════════════════════════════════════════════
class AllTriggersScreen extends StatefulWidget {
  final List<dynamic> triggers;
  const AllTriggersScreen({super.key, required this.triggers});
  @override
  State<AllTriggersScreen> createState() => _AllTriggersScreenState();
}

class _AllTriggersScreenState extends State<AllTriggersScreen> {
  static const bg  = Color(0xFF0D1829);
  static const bdr = Color(0xFF1E3352);
  static const gray = Color(0xFF7A8BB0);
  static const gold = Color(0xFFF5A623);

  String _filter = 'all';

  List<dynamic> get _filtered {
    if (_filter == 'all') return widget.triggers;
    return widget.triggers.where((t) => t['trigger_type'] == _filter).toList();
  }

  String _tn(String? t) {
    switch (t) {
      case 'heavy_rain':   return 'Heavy Rain';
      case 'flood_alert':  return 'Flood Alert';
      case 'extreme_heat': return 'Extreme Heat';
      case 'severe_aqi':   return 'Severe AQI';
      default:             return t ?? 'Trigger';
    }
  }

  @override
  Widget build(BuildContext context) {
    final types = ['all', 'heavy_rain', 'extreme_heat', 'severe_aqi', 'flood_alert'];
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('All Triggers',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white)),
          Text('${widget.triggers.length} total',
            style: const TextStyle(color: Color(0xFF7A8BB0), fontSize: 12)),
        ]),
      ),
      body: Column(children: [
        // Filter chips
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: types.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final t = types[i];
              final label = t == 'all' ? 'All' : _tn(t);
              final active = _filter == t;
              return GestureDetector(
                onTap: () => setState(() => _filter = t),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: active ? const Color(0xFF4B9FFF).withOpacity(0.15) : Colors.transparent,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: active ? const Color(0xFF4B9FFF) : bdr)),
                  child: Text(label, style: TextStyle(
                    color: active ? const Color(0xFF4B9FFF) : gray,
                    fontSize: 12, fontWeight: FontWeight.w700))),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _filtered.isEmpty
            ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.bolt_rounded, color: Colors.white24, size: 48),
                SizedBox(height: 12),
                Text('No triggers for this filter',
                  style: TextStyle(color: Colors.white38, fontSize: 14)),
              ]))
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: _filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _row(_filtered[i] as Map<String, dynamic>),
              ),
        ),
      ]),
    );
  }

  Widget _row(Map<String, dynamic> t) {
    final type = t['trigger_type'] as String? ?? '';
    final sev  = t['severity']     as String? ?? 'T2';
    final val  = t['value'];
    final zone = t['zone']         as String? ?? '';
    final raw  = t['created_at']?.toString() ?? '';
    final date = raw.length >= 10 ? raw.substring(0, 10) : raw;

    Color lineCol; IconData ic; String valLabel;
    switch (type) {
      case 'heavy_rain':   lineCol = const Color(0xFF4B9FFF); ic = Icons.water_drop_rounded;  valLabel = val != null ? '${val}mm'  : ''; break;
      case 'flood_alert':  lineCol = const Color(0xFF00C853); ic = Icons.flood_rounded;        valLabel = val != null ? '${val}mm'  : ''; break;
      case 'extreme_heat': lineCol = const Color(0xFFFF5252); ic = Icons.thermostat_rounded;   valLabel = val != null ? '${val}°C'  : ''; break;
      case 'severe_aqi':   lineCol = const Color(0xFF9C6FFF); ic = Icons.air_rounded;          valLabel = val != null ? 'AQI $val'  : ''; break;
      default:             lineCol = gold;                     ic = Icons.bolt_rounded;          valLabel = val?.toString() ?? '';
    }
    final sevCol = sev == 'T3' ? const Color(0xFFFF5252)
                 : sev == 'T2' ? const Color(0xFF4B9FFF) : gold;
    final pct    = sev == 'T1' ? '25%' : sev == 'T2' ? '50%' : '100%';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: bdr)),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: lineCol.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border(left: BorderSide(color: lineCol, width: 3))),
          child: Icon(ic, color: lineCol, size: 20)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_tn(type), style: const TextStyle(color: Colors.white, fontSize: 14,
            fontWeight: FontWeight.w700)),
          Text(zone, style: const TextStyle(color: Color(0xFF7A8BB0), fontSize: 12)),
          Text(date, style: const TextStyle(color: Color(0xFF4A5E7A), fontSize: 11)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: sevCol.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8)),
            child: Text(sev, style: TextStyle(color: sevCol,
              fontSize: 12, fontWeight: FontWeight.w900))),
          const SizedBox(height: 3),
          Text(valLabel.isNotEmpty ? valLabel : pct,
            style: const TextStyle(color: Color(0xFF7A8BB0), fontSize: 11)),
        ]),
      ]),
    );
  }
}
