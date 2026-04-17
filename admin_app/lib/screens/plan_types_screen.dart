// admin_app/lib/screens/plan_types_screen.dart
// ── Insurify Admin · Adaptive Parametric Insurance Plans ──────
// Admin controls EVERYTHING:
//   • Weekly premium & max payout
//   • Coverage duration (days) → reflected in worker app
//   • Rain/Heat/AQI thresholds per plan
//   • Which trigger types are covered (toggleable chips)
//   • Plan ON/OFF toggle

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
    'standard': Color(0xFF00C853),
    'pro':      Color(0xFF9C6FFF),
  };

  // All trigger types admin can assign to any plan
  static const _allTriggers = {
    'heavy_rain':   '🌧️ Heavy Rain',
    'curfew':       '🚫 Curfew',
    'extreme_heat': '🌡️ Extreme Heat',
    'severe_aqi':   '😷 Severe AQI',
    'flood_alert':  '🌊 Flood Alert',
    'cyclone':      '🌀 Cyclone',
    'storm':        '⛈️ Storm',
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
    final id      = plan['id'] as int;
    final current = plan['is_active'] as bool;
    setState(() => plan['is_active'] = !current);
    final ok = await AdminApi.togglePlanType(id, current);
    if (!ok) {
      setState(() => plan['is_active'] = current);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Toggle failed. Check connection.'),
          backgroundColor: Colors.redAccent,
        ));
      }
    }
  }

  // ── Full edit bottom-sheet ────────────────────────────────
  Future<void> _editPlan(Map<String, dynamic> plan) async {
    final premCtrl = TextEditingController(text: '${plan['weekly_premium']}');
    final payCtrl  = TextEditingController(text: '${plan['max_payout']}');
    final durCtrl  = TextEditingController(
        text: '${plan['duration_days'] ?? 7}');

    // --- Thresholds ---
    final thresholds = (plan['thresholds_json'] as Map<String, dynamic>?) ?? {};
    final rainCtrl = TextEditingController(
        text: '${thresholds['rain_mm'] ?? 10}');
    final tempCtrl = TextEditingController(
        text: '${thresholds['temp_c'] ?? 40}');
    final aqiCtrl  = TextEditingController(
        text: '${thresholds['aqi'] ?? 200}');
    final stormCtrl = TextEditingController(
        text: '${thresholds['storm_kmh'] ?? 60}');

    // --- Trigger toggles ---
    final List<String> currentTriggers =
        ((plan['triggers_json'] as List?) ?? []).cast<String>().toList();
    final Map<String, bool> trigSelected = {
      for (final k in _allTriggers.keys) k: currentTriggers.contains(k),
    };

    bool saving = false;
    final color = _planColors[plan['plan_key']] ?? navy;

    await showModalBottomSheet(
      context:            context,
      backgroundColor:    Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setBS) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding:    const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color:        Color(0xFF13243A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize:        MainAxisSize.min,
                crossAxisAlignment:  CrossAxisAlignment.start,
                children: [
                  Center(child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: bdr, borderRadius: BorderRadius.circular(99)),
                  )),
                  const SizedBox(height: 20),

                  // Title
                  Row(children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color:        color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10)),
                      child: Center(child: Text(
                        plan['name'][0],
                        style: TextStyle(fontSize: 16,
                          fontWeight: FontWeight.w900, color: color),
                      )),
                    ),
                    const SizedBox(width: 12),
                    Text('Edit ${plan['name']} Plan',
                      style: const TextStyle(fontSize: 18,
                        fontWeight: FontWeight.w800, color: Colors.white)),
                  ]),
                  const SizedBox(height: 24),

                  // ── Pricing ──────────────────────────────
                  _sheetSection('💰 Pricing', color),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _numField('Weekly Premium (₹)',
                        premCtrl, 'e.g. 79', color)),
                    const SizedBox(width: 12),
                    Expanded(child: _numField('Max Payout (₹)',
                        payCtrl, 'e.g. 1500', color)),
                  ]),
                  const SizedBox(height: 20),

                  // ── Coverage Duration ─────────────────────
                  _sheetSection('📅 Coverage Duration', color),
                  const SizedBox(height: 10),
                  _numField('Duration (days)', durCtrl, 'e.g. 7', color,
                      suffix: 'days'),
                  const SizedBox(height: 6),
                  Text('Workers on this plan get ${durCtrl.text}-day coverage per subscription.',
                    style: const TextStyle(color: gray, fontSize: 11)),
                  const SizedBox(height: 20),

                  // ── Trigger Management ──────────────────────
                  _sheetSection('🛡️ Trigger Management', color),
                  const SizedBox(height: 4),
                  Text('Toggle included events and configure thresholds inline.',
                    style: const TextStyle(color: gray, fontSize: 11)),
                  const SizedBox(height: 14),
                  Column(
                    children: _allTriggers.entries.map((e) {
                      final key    = e.key;
                      final active = trigSelected[key] ?? false;
                      final isWeather = ['heavy_rain', 'extreme_heat', 'severe_aqi', 'flood_alert', 'storm'].contains(key);
                      
                      TextEditingController? ctrl;
                      String unit = '';
                      if (key == 'heavy_rain' || key == 'flood_alert') { ctrl = rainCtrl; unit = 'mm/hr'; }
                      else if (key == 'extreme_heat') { ctrl = tempCtrl; unit = '°C'; }
                      else if (key == 'severe_aqi') { ctrl = aqiCtrl; unit = 'AQI'; }
                      else if (key == 'storm') { ctrl = stormCtrl; unit = 'km/h'; } // Will define stormCtrl

                      return Container(
                        margin:  const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: active ? color.withOpacity(0.08) : Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: active ? color.withOpacity(0.3) : bdr),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text(e.value,
                                  style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w700,
                                    color: active ? Colors.white : Colors.white54))),
                                Switch(
                                  value: active,
                                  activeColor: color,
                                  onChanged: (v) => setBS(() => trigSelected[key] = v),
                                ),
                              ],
                            ),
                            if (active && isWeather && ctrl != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Row(children: [
                                  Text('Fires when value exceeds:', style: TextStyle(color: gray, fontSize: 11)),
                                  const Spacer(),
                                  SizedBox(
                                    width: 70, height: 32,
                                    child: TextField(
                                      controller: ctrl,
                                      keyboardType: TextInputType.number,
                                      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
                                      textAlign: TextAlign.center,
                                      decoration: InputDecoration(
                                        contentPadding: EdgeInsets.zero,
                                        filled: true, fillColor: color.withOpacity(0.1),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(unit, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
                                ]),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Save button
                  SizedBox(
                    width: double.infinity, height: 52,
                    child: ElevatedButton(
                      onPressed: saving ? null : () async {
                        setBS(() => saving = true);
                        final prem  = int.tryParse(premCtrl.text) ?? 0;
                        final pay   = int.tryParse(payCtrl.text)  ?? 0;
                        final dur   = int.tryParse(durCtrl.text)  ?? 7;
                        final rainT = num.tryParse(rainCtrl.text) ?? 10;
                        final tempT = num.tryParse(tempCtrl.text) ?? 40;
                        final aqiT  = num.tryParse(aqiCtrl.text)  ?? 200;
                        final stormT= num.tryParse(stormCtrl.text)?? 60;
                        final trList = trigSelected.entries
                          .where((e) => e.value)
                          .map((e) => e.key)
                          .toList();

                        // Update pricing + duration
                        final ok = await AdminApi.updatePlanType(
                          id:            plan['id'] as int,
                          weeklyPremium: prem,
                          maxPayout:     pay,
                          isActive:      plan['is_active'] as bool,
                          durationDays:  dur,
                        );

                        // Update thresholds + trigger list
                        await AdminApi.updatePlanThresholds(
                          id:             plan['id'] as int,
                          triggersJson:   trList,
                          thresholdsJson: {
                            'rain_mm':   rainT,
                            'temp_c':    tempT,
                            'aqi':       aqiT,
                            'storm_kmh': stormT,
                          },
                          durationDays: dur,
                        );

                        if (ok) {
                          setState(() {
                            plan['weekly_premium'] = prem;
                            plan['max_payout']     = pay;
                            plan['duration_days']  = dur;
                            plan['triggers_json']  = trList;
                            plan['thresholds_json'] = {
                              'rain_mm':   rainT,
                              'temp_c':    tempT,
                              'aqi':       aqiT,
                              'storm_kmh': stormT,
                            };
                          });
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('${plan['name']} updated!'),
                              backgroundColor: navy,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                              margin: const EdgeInsets.all(16),
                            ));
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
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5))
                        : const Text('Save All Changes',
                            style: TextStyle(fontSize: 15,
                              fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Policy Control Center',
          style: TextStyle(fontSize: 18,
            fontWeight: FontWeight.w800, color: Colors.white)),
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
                ..._plans.map((plan) => _planCard(plan)),
              ],
            ),
          ),
    );
  }

  Widget _planCard(Map<String, dynamic> plan) {
    final color    = _planColors[plan['plan_key'] as String] ?? navy;
    final isActive = plan['is_active'] as bool;
    final triggers = ((plan['triggers_json'] as List?) ?? [])
        .map((t) => t.toString()).toList();
    final dur = plan['duration_days'] as int? ?? 7;
    final thresholds = (plan['thresholds_json'] as Map<String, dynamic>?) ?? {};

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
          // ── Header row ──────────────────────────────
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color:        color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(child: Text(
                (plan['name'] as String)[0],
                style: TextStyle(fontSize: 20,
                  fontWeight: FontWeight.w900, color: color),
              )),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plan['name'] as String,
                  style: const TextStyle(fontSize: 16,
                    fontWeight: FontWeight.w800, color: Colors.white)),
                Row(children: [
                  Text(isActive ? 'Active' : 'Disabled',
                    style: TextStyle(fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isActive ? Colors.greenAccent : Colors.redAccent)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color:        color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(99)),
                    child: Text('$dur days',
                      style: TextStyle(fontSize: 9,
                        fontWeight: FontWeight.bold, color: color)),
                  ),
                ]),
              ],
            )),
            GestureDetector(
              onTap: () => _toggle(plan),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 48, height: 26,
                decoration: BoxDecoration(
                  color: isActive
                    ? Colors.greenAccent.withOpacity(0.2) : bdr,
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
                        width: 18, height: 18,
                        decoration: BoxDecoration(
                          color:  isActive ? Colors.greenAccent : gray,
                          shape:  BoxShape.circle),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          Divider(color: bdr, height: 1),
          const SizedBox(height: 14),

          // ── Pricing row ───────────────────────────────
          Row(children: [
            Expanded(child: _statBox(label: 'Weekly Premium',
                value: '₹${plan['weekly_premium']}', color: gold)),
            const SizedBox(width: 10),
            Expanded(child: _statBox(label: 'Max Payout',
                value: '₹${plan['max_payout']}', color: color)),
          ]),
          const SizedBox(height: 10),

          // ── Threshold indicators ──────────────────────
          Row(children: [
            _thresholdChip('🌧 ${thresholds['rain_mm'] ?? 10}mm/hr', color),
            const SizedBox(width: 6),
            _thresholdChip('🌡 ${thresholds['temp_c'] ?? 40}°C', color),
            const SizedBox(width: 6),
            _thresholdChip('💨 AQI ${thresholds['aqi'] ?? 200}', color),
          ]),
          const SizedBox(height: 14),

          // ── Triggers covered ──────────────────────────
          Wrap(
            spacing: 6, runSpacing: 6,
            children: _allTriggers.entries.map((e) {
              final covered = triggers.contains(e.key);
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: covered
                    ? color.withOpacity(0.12) : bdr.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    covered
                      ? Icons.check_circle_rounded
                      : Icons.remove_circle_outline_rounded,
                    size:  11,
                    color: covered ? color : gray,
                  ),
                  const SizedBox(width: 4),
                  Text(e.value,
                    style: TextStyle(fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: covered ? color : gray)),
                ]),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // ── Edit button ───────────────────────────────
          GestureDetector(
            onTap: () => _editPlan(plan),
            child: Container(
              width:   double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color:        color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
                border:       Border.all(color: color.withOpacity(0.25)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.tune_rounded, size: 14, color: color),
                  const SizedBox(width: 6),
                  Text('Edit Plan Rules',
                    style: TextStyle(fontSize: 13,
                      fontWeight: FontWeight.w700, color: color)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _thresholdChip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color:        color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(8),
      border:       Border.all(color: color.withOpacity(0.2)),
    ),
    child: Text(label,
      style: TextStyle(fontSize: 9,
        fontWeight: FontWeight.w700, color: color)),
  );

  Widget _statBox({
    required String label,
    required String value,
    required Color  color,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color:        color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      border:       Border.all(color: color.withOpacity(0.2)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 10, color: gray)),
      const SizedBox(height: 2),
      Text(value, style: TextStyle(fontSize: 18,
        fontWeight: FontWeight.w900, color: color)),
    ]),
  );

  Widget _sheetSection(String title, Color color) => Row(children: [
    Container(width: 3, height: 14,
      decoration: BoxDecoration(
        color: color, borderRadius: BorderRadius.circular(99))),
    const SizedBox(width: 8),
    Text(title, style: const TextStyle(fontSize: 13,
      fontWeight: FontWeight.w700, color: Colors.white)),
  ]);

  Widget _numField(String label, TextEditingController ctrl, String hint,
      Color color, {String? suffix}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 10,
        fontWeight: FontWeight.w700, color: gray)),
      const SizedBox(height: 6),
      TextField(
        controller:      ctrl,
        keyboardType:    TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style:           const TextStyle(color: Colors.white,
            fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          hintText:    hint,
          hintStyle:   TextStyle(color: gray.withOpacity(0.6)),
          filled:      true,
          fillColor:   bdr.withOpacity(0.4),
          suffixText:  suffix,
          suffixStyle: TextStyle(color: color),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:   BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: color, width: 1.5)),
        ),
      ),
    ],
  );
}
