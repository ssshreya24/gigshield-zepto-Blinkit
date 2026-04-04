import 'dart:ui';
import 'package:flutter/material.dart';
import 'trigger_validation_screen.dart';

class TriggersScreen extends StatefulWidget {
  final Map<String, dynamic>? policy;
  const TriggersScreen({super.key, this.policy});
  @override
  State<TriggersScreen> createState() => _TriggersScreenState();
}

class _TriggersScreenState extends State<TriggersScreen>
    with TickerProviderStateMixin {

  static const bg   = Color(0xFF0D1829);
  static const navy = Color(0xFF1A2E6E);
  static const gold = Color(0xFFF5A623);
  static const gray = Color(0xFF7A8BB0);

  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  // All possible triggers with their status
  final List<Map<String, dynamic>> allTriggers = [
    {
      'name':      'Heavy Rain',
      'icon':      Icons.water_drop_rounded,
      'color':     Color(0xFF4B9FFF),
      'type':      'heavy_rain',
      'severity':  'T2',
      'pct':       50,
      'active':    true,
      'claimable': true,
      'location':  'Koramangala, Bengaluru',
      'detail':    'Rainfall: 245mm · Red alert active',
      'amount':    450,
    },
    {
      'name':      'Flood Alert',
      'icon':      Icons.flood_rounded,
      'color':     Color(0xFFFF5252),
      'type':      'flood_alert',
      'severity':  'T3',
      'pct':       100,
      'active':    true,
      'claimable': true,
      'location':  'Koramangala, Bengaluru',
      'detail':    'Flood warning issued · High severity',
      'amount':    900,
    },
    {
      'name':      'Curfew',
      'icon':      Icons.not_interested_rounded,
      'color':     Color(0xFFFF5252),
      'type':      'curfew',
      'severity':  'T3',
      'pct':       100,
      'active':    true,
      'claimable': true,
      'location':  'Koramangala, Bengaluru',
      'detail':    'Govt notification issued · 12hr restriction',
      'amount':    900,
    },
    {
      'name':      'Extreme Heat',
      'icon':      Icons.thermostat_rounded,
      'color':     Color(0xFFF5A623),
      'type':      'extreme_heat',
      'severity':  'T1',
      'pct':       25,
      'active':    false,
      'claimable': false,
      'location':  'Not triggered in your zone',
      'detail':    'Temperature within normal range',
      'amount':    225,
    },
    {
      'name':      'Cyclone',
      'icon':      Icons.cyclone_rounded,
      'color':     Color(0xFF9C6FFF),
      'type':      'cyclone',
      'severity':  'T3',
      'pct':       100,
      'active':    false,
      'claimable': false,
      'location':  'Not triggered in your zone',
      'detail':    'No cyclone warning in your area',
      'amount':    900,
    },
    {
      'name':      'Severe AQI',
      'icon':      Icons.air_rounded,
      'color':     Color(0xFF9C6FFF),
      'type':      'severe_aqi',
      'severity':  'T2',
      'pct':       50,
      'active':    false,
      'claimable': false,
      'location':  'Not triggered in your zone',
      'detail':    'AQI within safe range',
      'amount':    450,
    },
    {
      'name':      'Heat Wave',
      'icon':      Icons.wb_sunny_rounded,
      'color':     Color(0xFFFF7B7B),
      'type':      'heat_wave',
      'severity':  'T2',
      'pct':       50,
      'active':    false,
      'claimable': false,
      'location':  'Not triggered in your zone',
      'detail':    'No heat wave alert in your area',
      'amount':    450,
    },
    {
      'name':      'Landslide',
      'icon':      Icons.terrain_rounded,
      'color':     Color(0xFF8B6914),
      'type':      'landslide',
      'severity':  'T3',
      'pct':       100,
      'active':    false,
      'claimable': false,
      'location':  'Not triggered in your zone',
      'detail':    'No landslide risk detected',
      'amount':    900,
    },
    {
      'name':      'Zone Shutdown',
      'icon':      Icons.store_mall_directory_rounded,
      'color':     Color(0xFFFF5252),
      'type':      'zone_shutdown',
      'severity':  'T3',
      'pct':       100,
      'active':    false,
      'claimable': false,
      'location':  'Not triggered in your zone',
      'detail':    'No zone shutdown order',
      'amount':    900,
    },
  ];

  List<Map<String, dynamic>> get claimable =>
    allTriggers.where((t) => t['claimable'] == true).toList();

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(
      parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() { _fadeCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Column(children: [
            _header(context),
            _summary(),
            Expanded(child: _list(context)),
            if (claimable.isNotEmpty) _goBtn(context),
          ]),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
    child: Row(children: [
      GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white.withOpacity(0.1)),
          ),
          child: const Icon(Icons.arrow_back_rounded,
            color: Colors.white, size: 20),
        ),
      ),
      const SizedBox(width: 14),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Active Triggers',
          style: TextStyle(color: Colors.white, fontSize: 20,
            fontWeight: FontWeight.w900)),
        Text('${widget.policy?['zone'] ?? 'Koramangala'} · Live',
          style: const TextStyle(color: gold, fontSize: 12,
            fontWeight: FontWeight.w600)),
      ]),
      const Spacer(),
      Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF00C853).withOpacity(0.15),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: const Color(0xFF00C853).withOpacity(0.4)),
        ),
        child: const Row(children: [
          Icon(Icons.circle, color: Color(0xFF00C853), size: 7),
          SizedBox(width: 4),
          Text('Live', style: TextStyle(
            color: Color(0xFF00C853), fontSize: 10,
            fontWeight: FontWeight.bold)),
        ]),
      ),
    ]),
  );

  Widget _summary() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFF5252).withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFFF5252).withOpacity(0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.warning_amber_rounded,
          color: Color(0xFFFF5252), size: 28),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${claimable.length} triggers claimable right now',
              style: const TextStyle(color: Colors.white,
                fontSize: 15, fontWeight: FontWeight.w700)),
            Text(
              'Total eligible: ₹${claimable.fold(0, (s, t) => s + (t['amount'] as int))}',
              style: const TextStyle(color: gold, fontSize: 13,
                fontWeight: FontWeight.w700)),
          ],
        )),
      ]),
    ),
  );

  Widget _list(BuildContext context) => ListView.builder(
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
    itemCount: allTriggers.length,
    itemBuilder: (_, i) => _triggerCard(allTriggers[i], context),
  );

  Widget _triggerCard(Map<String, dynamic> t, BuildContext context) {
    final active    = t['active']    as bool;
    final claimable = t['claimable'] as bool;
    final color     = t['color']     as Color;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(active ? 0.07 : 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: active
            ? color.withOpacity(0.4)
            : Colors.white.withOpacity(0.06)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(active ? 0.15 : 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(t['icon'] as IconData,
              color: active ? color : color.withOpacity(0.3),
              size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(t['name'] as String,
                  style: TextStyle(
                    color: active ? Colors.white : Colors.white38,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                if (claimable)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00C853).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                        color: const Color(0xFF00C853).withOpacity(0.4)),
                    ),
                    child: const Text('Claimable',
                      style: TextStyle(
                        color: Color(0xFF00C853), fontSize: 9,
                        fontWeight: FontWeight.bold)),
                  ),
                if (active && !claimable)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: gold.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Text('Active',
                      style: TextStyle(
                        color: Color(0xFFF5A623), fontSize: 9,
                        fontWeight: FontWeight.bold)),
                  ),
              ]),
              const SizedBox(height: 3),
              Text(t['location'] as String,
                style: const TextStyle(
                  color: Colors.white38, fontSize: 11)),
              Text(t['detail'] as String,
                style: TextStyle(
                  color: active ? Colors.white54 : Colors.white24,
                  fontSize: 11)),
            ],
          )),
          const SizedBox(width: 8),
          Column(children: [
            if (claimable) ...[
              Text('₹${t['amount']}',
                style: const TextStyle(
                  color: gold, fontSize: 16,
                  fontWeight: FontWeight.w900)),
              Text('Tier ${t['severity']}',
                style: const TextStyle(
                  color: Colors.white38, fontSize: 10)),
            ] else
              Icon(Icons.lock_outline_rounded,
                color: Colors.white.withOpacity(0.2), size: 18),
          ]),
        ]),
      ),
    );
  }

  Widget _goBtn(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
    child: GestureDetector(
      onTap: () => Navigator.push(context,
        MaterialPageRoute(
          builder: (_) => TriggerValidationScreen(
            claimableTriggers: claimable,
            policy: widget.policy,
          ))),
      child: Container(
        width:   double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 17),
        decoration: BoxDecoration(
          color: gold,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(
            color:      gold.withOpacity(0.4),
            blurRadius: 20,
            offset:     const Offset(0, 8))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Process Claimable Triggers',
              style: TextStyle(color: Color(0xFF0D1829),
                fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(width: 8),
            Text('(${claimable.length})',
              style: const TextStyle(
                color: Color(0xFF0D1829), fontSize: 16,
                fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    ),
  );
}
