// admin_app/lib/screens/plan_types_screen.dart
// ── Insurify Admin · Global Plan Management ─────────────────
// Shows Basic / Standard / Pro plan catalogue.
// Admin can:
//   • Edit weekly premium & max payout (inline)
//   • Toggle plan ON / OFF  (is_active)
//   • See which triggers are covered per plan
// Linked from DashboardTab or WorkersTab via a button.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/admin_api.dart';

class PlanTypesScreen extends StatefulWidget {
  const PlanTypesScreen({super.key});
  @override
  State<PlanTypesScreen> createState() => _PlanTypesScreenState();
}

class _PlanTypesScreenState extends State<PlanTypesScreen> {
  static const bg   = Color(0xFF0D1829);
  static const card = Color(0xFF13243A);
  static const navy = Color(0xFF1A2E6E);
  static const gold = Color(0xFFF5A623);
  static const gray = Color(0xFF7A8BB0);
  static const bdr  = Color(0xFF1E2E45);

  static const _planColors = {
    'basic':    Color(0xFF4B9FFF),
    'standard': Color(0xFF1A2E6E),
    'pro':      Color(0xFF9C6FFF),
  };

  static const _triggerLabels = {
    'heavy_rain':   '🌧️ Heavy Rain',
    'extreme_heat': '🌡️ Extreme Heat',
    'flood_alert':  '🌊 Flood Alert',
    'severe_aqi':   '😷 Severe AQI',
    'curfew':       '🚫 Curfew',
    'cyclone':      '🌀 Cyclone',
  };

  List<Map<String, dynamic>> _plans = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final raw = await AdminApi.getPlanTypes();
    setState(() {
      _plans   = raw.cast<Map<String, dynamic>>();
      _loading = false;
    });
  }

  Future<void> _toggle(Map<String, dynamic> plan) async {
    final id       = plan['id'] as int;
    final current  = plan['is_active'] as bool;
    setState(() => plan['is_active'] = !current);

    final ok = await AdminApi.togglePlanType(id, current);
    if (!ok) {
      setState(() => plan['is_active'] = current); // revert on failure
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Toggle failed. Check connection.'),
          backgroundColor: Colors.redAccent,
        ));
      }
    }
  }

  Future<void> _editPlan(Map<String, dynamic> plan) async {
    final premCtrl = TextEditingController(
        text: '${plan['weekly_premium']}');
    final payCtrl  = TextEditingController(
        text: '${plan['max_payout']}');
    bool saving = false;

    final color = _planColors[plan['plan_key']] ?? navy;

    await showModalBottomSheet(
      context:           context,
      backgroundColor:   Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setBS) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding:      const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color:        Color(0xFF13243A),
              borderRadius: BorderRadius.vertical(
                  top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color:        bdr,
                      borderRadius: BorderRadius.circular(99)),
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color:        color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10)),
                    child: Center(
                      child: Text(
                        plan['name'][0],
                        style: TextStyle(
                          fontSize:   16,
                          fontWeight: FontWeight.w900,
                          color:      color),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Edit ${plan['name']} Plan',
                    style: const TextStyle(
                      fontSize:   18,
                      fontWeight: FontWeight.w800,
                      color:      Colors.white),
                  ),
                ]),
                const SizedBox(height: 24),

                // Weekly Premium field
                _sheetField(
                  label:      'Weekly Premium (₹)',
                  ctrl:       premCtrl,
                  hint:       'e.g. 79',
                  accentColor: color,
                ),
                const SizedBox(height: 16),

                // Max Payout field
                _sheetField(
                  label:      'Max Payout (₹)',
                  ctrl:       payCtrl,
                  hint:       'e.g. 1500',
                  accentColor: color,
                ),
                const SizedBox(height: 28),

                // Save button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: saving ? null : () async {
                      setBS(() => saving = true);
                      final prem = int.tryParse(premCtrl.text) ?? 0;
                      final pay  = int.tryParse(payCtrl.text)  ?? 0;
                      final ok   = await AdminApi.updatePlanType(
                        id:            plan['id'] as int,
                        weeklyPremium: prem,
                        maxPayout:     pay,
                        isActive:      plan['is_active'] as bool,
                      );
                      if (ok) {
                        setState(() {
                          plan['weekly_premium'] = prem;
                          plan['max_payout']     = pay;
                        });
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${plan['name']} updated!'),
                              backgroundColor:  navy,
                              behavior:         SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              margin: const EdgeInsets.all(16),
                            ),
                          );
                        }
                      }
                      setBS(() => saving = false);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: saving
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5))
                        : const Text('Save Changes',
                            style: TextStyle(
                              fontSize:   15,
                              fontWeight: FontWeight.w700,
                              color:      Colors.white)),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation:       0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color:        card,
              borderRadius: BorderRadius.circular(10),
              border:       Border.all(color: bdr),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 16, color: Colors.white),
          ),
        ),
        title: const Text('Plan Management',
          style: TextStyle(
            fontSize:   18,
            fontWeight: FontWeight.w800,
            color:      Colors.white)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: gold))
          : RefreshIndicator(
              color:           gold,
              backgroundColor: card,
              onRefresh:       _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Header note
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color:        gold.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border:       Border.all(
                          color: gold.withOpacity(0.25)),
                    ),
                    child: Row(children: const [
                      Icon(Icons.info_outline_rounded,
                          color: gold, size: 16),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Changes apply to all new subscriptions. '
                          'Existing policies keep their original rates.',
                          style: TextStyle(
                            fontSize: 12, color: gold,
                            fontWeight: FontWeight.w500),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 20),

                  // Plan cards
                  ..._plans.map((plan) => _planCard(plan)),
                ],
              ),
            ),
    );
  }

  Widget _planCard(Map<String, dynamic> plan) {
    final color    = _planColors[plan['plan_key'] as String] ?? navy;
    final isActive = plan['is_active'] as bool;
    final triggers = (plan['triggers_json'] as List?)
            ?.map((t) => t.toString())
            .toList() ??
        [];

    return Container(
      margin:  const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color:        card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? color.withOpacity(0.35) : bdr,
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row ─────────────────────────────
          Row(children: [
            // Color dot + name
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color:        color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  (plan['name'] as String)[0],
                  style: TextStyle(
                    fontSize:   20,
                    fontWeight: FontWeight.w900,
                    color:      color),
                ),
              ),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(plan['name'] as String,
                    style: const TextStyle(
                      fontSize:   16,
                      fontWeight: FontWeight.w800,
                      color:      Colors.white)),
                  Text(
                    isActive ? 'Active' : 'Disabled',
                    style: TextStyle(
                      fontSize:   11,
                      fontWeight: FontWeight.w600,
                      color:      isActive
                          ? Colors.greenAccent
                          : Colors.redAccent),
                  ),
                ],
              ),
            ),

            // Active toggle
            GestureDetector(
              onTap: () => _toggle(plan),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width:    48, height: 26,
                decoration: BoxDecoration(
                  color:        isActive
                      ? Colors.greenAccent.withOpacity(0.2)
                      : bdr,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: isActive
                        ? Colors.greenAccent.withOpacity(0.6)
                        : gray.withOpacity(0.3),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: Row(
                    mainAxisAlignment: isActive
                        ? MainAxisAlignment.end
                        : MainAxisAlignment.start,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width:    18, height: 18,
                        decoration: BoxDecoration(
                          color: isActive
                              ? Colors.greenAccent
                              : gray,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ]),

          const SizedBox(height: 16),
          Divider(color: bdr, height: 1),
          const SizedBox(height: 16),

          // ── Premium & Payout ─────────────────────
          Row(children: [
            Expanded(
              child: _statBox(
                label: 'Weekly Premium',
                value: '₹${plan['weekly_premium']}',
                color: gold,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statBox(
                label: 'Max Payout',
                value: '₹${plan['max_payout']}',
                color: color,
              ),
            ),
          ]),

          const SizedBox(height: 16),

          // ── Triggers covered ─────────────────────
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _triggerLabels.entries.map((e) {
              final covered = triggers.contains(e.key);
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: covered
                      ? color.withOpacity(0.12)
                      : bdr.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      covered
                          ? Icons.check_circle_rounded
                          : Icons.remove_circle_outline_rounded,
                      size:  11,
                      color: covered ? color : gray,
                    ),
                    const SizedBox(width: 4),
                    Text(e.value,
                      style: TextStyle(
                        fontSize:   10,
                        fontWeight: FontWeight.w600,
                        color: covered ? color : gray,
                      )),
                  ],
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 16),

          // ── Edit button ──────────────────────────
          GestureDetector(
            onTap: () => _editPlan(plan),
            child: Container(
              width:   double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color:        color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
                border:       Border.all(
                    color: color.withOpacity(0.25)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.edit_rounded, size: 14, color: color),
                  const SizedBox(width: 6),
                  Text('Edit Pricing',
                    style: TextStyle(
                      fontSize:   13,
                      fontWeight: FontWeight.w700,
                      color:      color)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statBox({
    required String label,
    required String value,
    required Color  color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
            style: TextStyle(fontSize: 10, color: gray)),
          const SizedBox(height: 2),
          Text(value,
            style: TextStyle(
              fontSize:   18,
              fontWeight: FontWeight.w900,
              color:      color)),
        ],
      ),
    );
  }

  Widget _sheetField({
    required String             label,
    required TextEditingController ctrl,
    required String             hint,
    required Color              accentColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
          style: TextStyle(
            fontSize:   12,
            fontWeight: FontWeight.w700,
            color:      gray)),
        const SizedBox(height: 6),
        TextField(
          controller:      ctrl,
          keyboardType:    TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style:           const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            hintText:        hint,
            hintStyle:       TextStyle(color: gray.withOpacity(0.6)),
            filled:          true,
            fillColor:       bdr.withOpacity(0.4),
            prefixText:      '₹ ',
            prefixStyle:     TextStyle(
                color: accentColor, fontWeight: FontWeight.w700),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:   BorderSide.none),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: accentColor, width: 1.5)),
          ),
        ),
      ],
    );
  }
}
