import 'package:flutter/material.dart';
import '../services/admin_api.dart';

// ── Policy Management Screen ──────────────────────────────────
// Called from WorkersTab when admin taps a worker's Edit button
// Shows full policy details + edit + trigger coverage per plan

class PolicyManageScreen extends StatefulWidget {
  final Map<String, dynamic> worker;
  const PolicyManageScreen({super.key, required this.worker});
  @override
  State<PolicyManageScreen> createState() =>
    _PolicyManageScreenState();
}

class _PolicyManageScreenState
    extends State<PolicyManageScreen>
    with TickerProviderStateMixin {

  static const bg   = Color(0xFF0D1829);
  static const navy = Color(0xFF1A2E6E);
  static const gold = Color(0xFFF5A623);
  static const gray = Color(0xFF7A8BB0);
  static const bdr  = Color(0xFF1E2E45);

  late String selectedPlan;
  late int    premium;
  late int    maxPayout;
  late bool   active;

  bool _saving   = false;
  bool _changed  = false;

  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  final premCtrl = TextEditingController();
  final payCtrl  = TextEditingController();

  // Plan definitions with trigger coverage
  final Map<String, Map<String, dynamic>> planDefs = {
    'basic': {
      'price': 29, 'max': 500,
      'color': Color(0xFF4B9FFF),
      'label': 'Basic',
      'triggers': [
        {'name': 'Heavy Rain',   'covered': true,  'tier': 'T2', 'pct': 50},
        {'name': 'Extreme Heat', 'covered': true,  'tier': 'T1', 'pct': 25},
        {'name': 'Flood Alert',  'covered': false, 'tier': 'T3', 'pct': 100},
        {'name': 'Severe AQI',   'covered': false, 'tier': 'T2', 'pct': 50},
        {'name': 'Curfew',       'covered': false, 'tier': 'T3', 'pct': 100},
        {'name': 'Cyclone',      'covered': false, 'tier': 'T3', 'pct': 100},
      ],
    },
    'standard': {
      'price': 49, 'max': 900,
      'color': Color(0xFF1A2E6E),
      'label': 'Standard',
      'triggers': [
        {'name': 'Heavy Rain',   'covered': true,  'tier': 'T2', 'pct': 50},
        {'name': 'Extreme Heat', 'covered': true,  'tier': 'T1', 'pct': 25},
        {'name': 'Flood Alert',  'covered': true,  'tier': 'T3', 'pct': 100},
        {'name': 'Severe AQI',   'covered': true,  'tier': 'T2', 'pct': 50},
        {'name': 'Curfew',       'covered': false, 'tier': 'T3', 'pct': 100},
        {'name': 'Cyclone',      'covered': false, 'tier': 'T3', 'pct': 100},
      ],
    },
    'pro': {
      'price': 79, 'max': 1500,
      'color': Color(0xFF9C6FFF),
      'label': 'Pro',
      'triggers': [
        {'name': 'Heavy Rain',   'covered': true, 'tier': 'T2', 'pct': 50},
        {'name': 'Extreme Heat', 'covered': true, 'tier': 'T1', 'pct': 25},
        {'name': 'Flood Alert',  'covered': true, 'tier': 'T3', 'pct': 100},
        {'name': 'Severe AQI',   'covered': true, 'tier': 'T2', 'pct': 50},
        {'name': 'Curfew',       'covered': true, 'tier': 'T3', 'pct': 100},
        {'name': 'Cyclone',      'covered': true, 'tier': 'T3', 'pct': 100},
      ],
    },
  };

  @override
  void initState() {
    super.initState();
    selectedPlan = widget.worker['plan_type'] ?? 'standard';
    premium      = _i(widget.worker['weekly_premium']) > 0
      ? _i(widget.worker['weekly_premium'])
      : planDefs[selectedPlan]!['price'] as int;
    maxPayout    = _i(widget.worker['max_payout']) > 0
      ? _i(widget.worker['max_payout'])
      : planDefs[selectedPlan]!['max'] as int;
    active       = widget.worker['active'] ?? true;

    premCtrl.text = premium.toString();
    payCtrl.text  = maxPayout.toString();

    _fadeCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(
      parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    premCtrl.dispose();
    payCtrl.dispose();
    super.dispose();
  }

  int _i(dynamic v) {
    if (v == null) return 0;
    if (v is int)    return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  void _selectPlan(String plan) {
    final def = planDefs[plan]!;
    setState(() {
      selectedPlan    = plan;
      premium         = def['price'] as int;
      maxPayout       = def['max']   as int;
      premCtrl.text   = premium.toString();
      payCtrl.text    = maxPayout.toString();
      _changed        = true;
    });
  }

  Future<void> _save() async {
    final pid = widget.worker['policy_id'];
    if (pid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No policy found for this worker'),
          backgroundColor: Color(0xFFFF5252)));
      return;
    }
    setState(() => _saving = true);
    final ok = await AdminApi.updatePolicy(
      policyId:     pid as int,
      planType:     selectedPlan,
      weeklyPremium: int.tryParse(premCtrl.text) ?? premium,
      maxPayout:    int.tryParse(payCtrl.text) ?? maxPayout,
      active:       active,
    );
    setState(() { _saving = false; _changed = false; });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
            ? '✓ Policy updated successfully!'
            : '✗ Failed to update. Try again.'),
          backgroundColor: ok
            ? const Color(0xFF00C853)
            : const Color(0xFFFF5252),
          duration: const Duration(seconds: 2)));
      if (ok) Navigator.pop(context, true);
    }
  }

  Future<void> _suspend() async {
    final ok = await AdminApi.suspendWorker(
      widget.worker['id'] as int);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Worker suspended'),
          backgroundColor: Color(0xFFFF5252)));
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = planDefs[selectedPlan]!;
    final color = plan['color'] as Color;
    final triggers = plan['triggers'] as List;
    final covered = triggers.where(
      (t) => t['covered'] == true).length;

    return Scaffold(
      backgroundColor: bg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Column(children: [
          _header(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Worker info card
                  _workerCard(),
                  const SizedBox(height: 20),

                  // Policy status toggle
                  _sectionLabel('Policy Status'),
                  const SizedBox(height: 10),
                  _darkCard(child: Row(children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: (active
                          ? const Color(0xFF00C853)
                          : const Color(0xFFFF5252))
                          .withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12)),
                      child: Icon(
                        active
                          ? Icons.shield_rounded
                          : Icons.shield_outlined,
                        color: active
                          ? const Color(0xFF00C853)
                          : const Color(0xFFFF5252),
                        size: 22)),
                    const SizedBox(width: 14),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          active ? 'Policy Active' : 'Policy Suspended',
                          style: TextStyle(
                            color: active
                              ? Colors.white : Colors.white38,
                            fontSize:   15,
                            fontWeight: FontWeight.w700)),
                        Text(
                          active
                            ? 'Worker can claim triggers'
                            : 'Worker cannot claim',
                          style: const TextStyle(
                            color: gray, fontSize: 12)),
                      ],
                    )),
                    Switch(
                      value:          active,
                      activeColor:    const Color(0xFF00C853),
                      inactiveThumbColor: const Color(0xFFFF5252),
                      inactiveTrackColor:
                        const Color(0xFFFF5252).withOpacity(0.3),
                      onChanged: (v) => setState(() {
                        active = v; _changed = true; }),
                    ),
                  ])),

                  const SizedBox(height: 20),

                  // Plan selector
                  _sectionLabel('Plan Type'),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: bdr)),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: planDefs.entries.map((e) {
                        final isActive = selectedPlan == e.key;
                        final c = e.value['color'] as Color;
                        final covCount = (e.value['triggers'] as List)
                          .where((t) => t['covered'] == true)
                          .length;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => _selectPlan(e.key),
                            child: AnimatedContainer(
                              duration: const Duration(
                                milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                vertical: 12),
                              decoration: BoxDecoration(
                                color: isActive
                                  ? navy : Colors.transparent,
                                borderRadius:
                                  BorderRadius.circular(10)),
                              child: Column(children: [
                                Text(
                                  e.value['label'] as String,
                                  style: TextStyle(
                                    color:      isActive
                                      ? Colors.white70 : gray,
                                    fontSize:   11,
                                    fontWeight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                Text('₹${e.value['price']}',
                                  style: TextStyle(
                                    color:      isActive ? gold : gray,
                                    fontSize:   18,
                                    fontWeight: FontWeight.w900)),
                                Text('$covCount triggers',
                                  style: TextStyle(
                                    color: isActive ? c : gray,
                                    fontSize: 9)),
                              ]),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Trigger coverage for selected plan
                  _sectionLabel(
                    'Trigger Coverage — ${plan['label']} Plan'),
                  const SizedBox(height: 10),
                  _darkCard(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10)),
                          child: Icon(Icons.shield_rounded,
                            color: color, size: 20)),
                        const SizedBox(width: 12),
                        Expanded(child: Column(
                          crossAxisAlignment:
                            CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$covered of ${triggers.length} triggers covered',
                              style: const TextStyle(
                                color:      Colors.white,
                                fontSize:   14,
                                fontWeight: FontWeight.w700)),
                            Text('Max payout ₹$maxPayout / week',
                              style: const TextStyle(
                                color: gray, fontSize: 12)),
                          ],
                        )),
                        Text('₹${plan['price']}/wk',
                          style: TextStyle(color: color,
                            fontSize: 16, fontWeight: FontWeight.w900)),
                      ]),
                      const SizedBox(height: 14),
                      const Divider(color: bdr, height: 1),
                      const SizedBox(height: 12),
                      ...triggers.map((t) {
                        final isCovered = t['covered'] as bool;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(children: [
                            Container(
                              width: 22, height: 22,
                              decoration: BoxDecoration(
                                color: isCovered
                                  ? const Color(0xFF00C853)
                                    .withOpacity(0.12)
                                  : Colors.white.withOpacity(0.04),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isCovered
                                    ? const Color(0xFF00C853)
                                      .withOpacity(0.4)
                                    : Colors.white.withOpacity(0.08),
                                  width: 1)),
                              child: Icon(
                                isCovered
                                  ? Icons.check_rounded
                                  : Icons.close_rounded,
                                color: isCovered
                                  ? const Color(0xFF00C853)
                                  : Colors.white24,
                                size: 13)),
                            const SizedBox(width: 10),
                            Expanded(child: Text(
                              t['name'] as String,
                              style: TextStyle(
                                color:      isCovered
                                  ? Colors.white : Colors.white38,
                                fontSize:   13,
                                fontWeight: isCovered
                                  ? FontWeight.w600 : FontWeight.w400,
                                decoration: isCovered
                                  ? null : TextDecoration.lineThrough,
                                decorationColor:
                                  Colors.white24))),
                            if (isCovered)
                              Container(
                                padding:
                                  const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.1),
                                  borderRadius:
                                    BorderRadius.circular(99)),
                                child: Text(
                                  '${t['tier']} · ${t['pct']}%',
                                  style: TextStyle(
                                    color: color, fontSize: 9,
                                    fontWeight: FontWeight.bold)))
                            else
                              const Icon(Icons.lock_outline_rounded,
                                color: Colors.white24, size: 14),
                          ]),
                        );
                      }),
                    ],
                  )),

                  const SizedBox(height: 20),

                  // Custom override fields
                  _sectionLabel('Custom Premium Override'),
                  const SizedBox(height: 4),
                  Text('Override default plan pricing if needed',
                    style: const TextStyle(
                      color: gray, fontSize: 11)),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _inputField(
                      label: 'Weekly Premium (₹)',
                      ctrl:  premCtrl,
                      icon:  Icons.currency_rupee_rounded,
                      onChanged: (_) =>
                        setState(() => _changed = true),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _inputField(
                      label: 'Max Payout (₹)',
                      ctrl:  payCtrl,
                      icon:  Icons.payments_rounded,
                      onChanged: (_) =>
                        setState(() => _changed = true),
                    )),
                  ]),

                  const SizedBox(height: 20),

                  // Danger zone
                  _sectionLabel('Danger Zone'),
                  const SizedBox(height: 10),
                  _darkCard(child: Row(children: [
                    const Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Suspend Worker',
                          style: TextStyle(color: Colors.white,
                            fontSize: 14, fontWeight: FontWeight.w700)),
                        Text('Disables policy and all claims',
                          style: TextStyle(
                            color: gray, fontSize: 12)),
                      ],
                    )),
                    GestureDetector(
                      onTap: _suspend,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 9),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF5252)
                            .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFFFF5252)
                              .withOpacity(0.3))),
                        child: const Text('Suspend',
                          style: TextStyle(
                            color:      Color(0xFFFF5252),
                            fontSize:   13,
                            fontWeight: FontWeight.w700))),
                    ),
                  ])),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // Save button
          if (_changed)
            _saveBar(),
        ]),
      ),
    );
  }

  Widget _header() => SafeArea(
    bottom: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.white.withOpacity(0.1))),
            child: const Icon(Icons.arrow_back_rounded,
              color: Colors.white, size: 20)),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Manage Policy',
              style: TextStyle(color: Colors.white,
                fontSize: 18, fontWeight: FontWeight.w800)),
            Text(widget.worker['name'] as String? ?? 'Worker',
              style: const TextStyle(color: gold, fontSize: 12)),
          ],
        )),
        if (_changed)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: gold.withOpacity(0.12),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: gold.withOpacity(0.4))),
            child: const Text('Unsaved changes',
              style: TextStyle(color: gold, fontSize: 10,
                fontWeight: FontWeight.w700))),
      ]),
    ),
  );

  Widget _workerCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.04),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: bdr)),
    child: Row(children: [
      CircleAvatar(
        radius: 26,
        backgroundColor: navy.withOpacity(0.5),
        child: Text(
          (widget.worker['name'] as String? ?? 'W')
            .split(' ').map((e) => e[0]).take(2).join(),
          style: const TextStyle(color: gold, fontSize: 16,
            fontWeight: FontWeight.w900))),
      const SizedBox(width: 14),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.worker['name'] as String? ?? 'Worker',
            style: const TextStyle(color: Colors.white,
              fontSize: 16, fontWeight: FontWeight.w700)),
          Text(
            '${widget.worker['zone'] ?? ''} · ${widget.worker['platform'] ?? ''}',
            style: const TextStyle(color: gray, fontSize: 12)),
          Text(widget.worker['phone'] as String? ?? '',
            style: const TextStyle(color: gray, fontSize: 11)),
        ],
      )),
    ]),
  );

  Widget _saveBar() => Container(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
    decoration: BoxDecoration(
      color: const Color(0xFF0D1829),
      border: Border(top: BorderSide(
        color: Colors.white.withOpacity(0.08), width: 1))),
    child: GestureDetector(
      onTap: _saving ? null : _save,
      child: Container(
        width:   double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color:        gold,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(
            color:      gold.withOpacity(0.35),
            blurRadius: 16, offset: const Offset(0, 6))]),
        child: Center(child: _saving
          ? const SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(
                color: Color(0xFF0D1829), strokeWidth: 2.5))
          : const Text('Save Policy Changes →',
              style: TextStyle(color: Color(0xFF0D1829),
                fontSize: 16, fontWeight: FontWeight.w900))),
      ),
    ),
  );

  Widget _inputField({
    required String label,
    required TextEditingController ctrl,
    required IconData icon,
    Function(String)? onChanged,
  }) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: gray,
        fontSize: 11, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: bdr)),
        padding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 4),
        child: Row(children: [
          Icon(icon, color: gray, size: 16),
          const SizedBox(width: 8),
          Expanded(child: TextField(
            controller:   ctrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            onChanged:    onChanged,
            decoration: const InputDecoration(
              border:         InputBorder.none,
              isDense:        true,
              contentPadding:
                EdgeInsets.symmetric(vertical: 12)))),
        ]),
      ),
    ]);

  Widget _darkCard({required Widget child}) => Container(
    width:   double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color:        Colors.white.withOpacity(0.04),
      borderRadius: BorderRadius.circular(14),
      border:       Border.all(color: bdr)),
    child: child,
  );

  Widget _sectionLabel(String t) => Text(t,
    style: const TextStyle(color: gray, fontSize: 12,
      fontWeight: FontWeight.w700, letterSpacing: 0.7));
}
