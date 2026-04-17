import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/certificate_generator.dart';
import 'payout_animation_screen.dart';
import 'admin_screen.dart';
import 'trigger_flow_screen.dart';

class PolicyTab extends StatelessWidget {
  final int workerId;
  final Map<String, dynamic>? policy;
  final bool loading;
  final int triggerCount;
  final VoidCallback onRefresh;

  const PolicyTab({
    super.key,
    required this.workerId,
    required this.policy,
    required this.loading,
    required this.triggerCount,
    required this.onRefresh,
  });

  static const bg    = Color(0xFFE8EDFF);
  static const navy  = Color(0xFF1A2E6E);
  static const navy2 = Color(0xFF22387E);
  static const gold  = Color(0xFFF5A623);
  static const gray  = Color(0xFF7A8BB0);
  static const bdr   = Color(0xFFCDD8F6);

  final List<Map<String, dynamic>> coverage = const [
    {'icon': Icons.water_drop_rounded,
      'name': 'Heavy Rain',    'tier': 'T2', 'pct': 50,
      'color': Color(0xFF4B9FFF)},
    {'icon': Icons.flood_rounded,
      'name': 'Flood Alert',   'tier': 'T3', 'pct': 100,
      'color': Color(0xFFFF5252)},
    {'icon': Icons.thermostat_rounded,
      'name': 'Extreme Heat',  'tier': 'T1', 'pct': 25,
      'color': Color(0xFFF5A623)},
    {'icon': Icons.air_rounded,
      'name': 'Severe AQI',    'tier': 'T2', 'pct': 50,
      'color': Color(0xFF9C6FFF)},
    {'icon': Icons.store_mall_directory_rounded,
      'name': 'Zone Shutdown', 'tier': 'T3', 'pct': 100,
      'color': Color(0xFFFF5252)},
  ];

  // ── Dynamic coverage from backend triggers_json ────────────────
  static const _allTriggerMeta = {
    'heavy_rain':        {'icon': Icons.water_drop_rounded,            'name': 'Heavy Rain',       'tier': 'T2', 'pct': 50,  'color': Color(0xFF4B9FFF)},
    'flood_alert':       {'icon': Icons.flood_rounded,                 'name': 'Flood Alert',      'tier': 'T3', 'pct': 100, 'color': Color(0xFFFF5252)},
    'extreme_heat':      {'icon': Icons.thermostat_rounded,            'name': 'Extreme Heat',     'tier': 'T1', 'pct': 25,  'color': Color(0xFFF5A623)},
    'severe_aqi':        {'icon': Icons.air_rounded,                   'name': 'Severe AQI',       'tier': 'T2', 'pct': 50,  'color': Color(0xFF9C6FFF)},
    'curfew':            {'icon': Icons.store_mall_directory_rounded,  'name': 'Zone Shutdown',    'tier': 'T3', 'pct': 100, 'color': Color(0xFFFF5252)},
    'cyclone':           {'icon': Icons.cyclone_rounded,               'name': 'Cyclone',          'tier': 'T3', 'pct': 100, 'color': Color(0xFF4B9FFF)},
    'platform_shutdown': {'icon': Icons.phonelink_off_rounded,         'name': 'Platform Shutdown','tier': 'T3', 'pct': 100, 'color': Color(0xFF9C6FFF)},
    'storm':             {'icon': Icons.thunderstorm_rounded,          'name': 'Storm',            'tier': 'T2', 'pct': 50,  'color': Color(0xFF00C853)},
  };

  List<Map<String, dynamic>> _buildCoverage() {
    // Try to read live triggers_json from admin-configured plan
    final raw = policy?['triggers_json'];
    List<String> keys = [];
    if (raw is List && raw.isNotEmpty) {
      keys = raw.map((e) => e.toString()).toList();
    } else {
      // Fallback defaults per plan if backend not yet updated
      final plan = (policy?['plan_type'] ?? 'standard').toString().toLowerCase();
      if (plan == 'pro') {
        keys = ['heavy_rain', 'flood_alert', 'extreme_heat', 'severe_aqi', 'curfew', 'cyclone'];
      } else if (plan == 'basic') {
        keys = ['heavy_rain', 'curfew'];
      } else {
        keys = ['heavy_rain', 'extreme_heat', 'severe_aqi', 'flood_alert'];
      }
    }
    return keys
      .map((k) => _allTriggerMeta[k])
      .whereType<Map<String, dynamic>>()
      .map((m) => Map<String, dynamic>.from(m))
      .toList();
  }

  int _days() {
    if (policy == null) return 7;
    try {
      final end = DateTime.parse(policy!['end_date']);
      return end.difference(DateTime.now()).inDays.clamp(0, 7);
    } catch (_) { return 7; }
  }

  // ── HELPER: safe name ────────────────────────────────────
  String _safeName() {
    final raw = policy?['name'];
    if (raw == null || raw.toString().trim().isEmpty) return 'GS';
    return raw.toString().trim();
  }

  // ── Generate PDF Certificate ─────────────────────────────
  Future<void> _downloadCertificate(BuildContext context) async {
    try {
      await CertificateGenerator.generate(
        workerId:      workerId,
        workerName:    policy?['name']            ?? 'Worker',
        zone:          policy?['zone']            ?? 'Koramangala',
        platform:      policy?['platform']        ?? 'Zepto',
        planType:      policy?['plan_type']       ?? 'standard',
        weeklyPremium: policy?['weekly_premium']  ?? 74,
        maxPayout:     policy?['max_payout']      ?? 900,
        endDate:       policy?['end_date']?.toString() ?? '',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not generate PDF: $e'),
            backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Positioned(top: -80, right: -60,
        child: _blob(220,
          const Color(0xFF7B9CFF).withOpacity(0.2))),
      Positioned(bottom: 100, left: -80,
        child: _blob(260,
          const Color(0xFF5B6FBE).withOpacity(0.12))),
      Positioned(top: 300, left: 100,
        child: _blob(120, gold.withOpacity(0.06))),

      SafeArea(
        child: Column(children: [
          _appBar(context),
          Expanded(
            child: loading
              ? const Center(
                  child: CircularProgressIndicator(color: navy))
              : RefreshIndicator(
                  onRefresh: () async => onRefresh(),
                  color:     navy,
                  child:     _body(context),
                ),
          ),
        ]),
      ),
    ]);
  }

  Widget _appBar(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: navy,
              borderRadius: BorderRadius.circular(11),
              boxShadow: [BoxShadow(
                color:      navy.withOpacity(0.35),
                blurRadius: 10,
                offset:     const Offset(0, 4))],
            ),
            child: const Icon(Icons.shield_rounded,
              color: Colors.white, size: 22),
          ),
          const SizedBox(width: 10),
          const Text('Insurify',
            style: TextStyle(
              color:      navy,
              fontSize:   19,
              fontWeight: FontWeight.w800)),
        ]),
        Row(children: [
          // Demo trigger button
          GestureDetector(
            onTap: () => _showTriggerDemo(context),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF5252).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFFF5252)
                    .withOpacity(0.3)),
              ),
              child: const Row(children: [
                Icon(Icons.bolt_rounded,
                  color: Color(0xFFFF5252), size: 15),
                SizedBox(width: 4),
                Text('Trigger',
                  style: TextStyle(
                    color:      Color(0xFFFF5252),
                    fontSize:   12,
                    fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ]),
      ],
    ),
  );

  void _showTriggerDemo(BuildContext context) {
    final zone    = policy?['zone']     ?? 'Koramangala';
    final city    = _cityFromZone(zone);
    final upiId   = policy?['upi_id']  ?? '${(policy?['name'] ?? 'worker').toLowerCase().replaceAll(' ', '')}@okicici';
    final maxP    = (policy?['max_payout']       ?? 900) as num;
    final income  = (policy?['avg_daily_income'] ?? 800) as num;

    final triggers = [
      {'label': 'Heavy Rain (T2)',    'type': 'heavy_rain',   'sev': 'T2', 'color': Color(0xFF4B9FFF)},
      {'label': 'Flood Alert (T3)',   'type': 'flood_alert',  'sev': 'T3', 'color': Color(0xFFFF5252)},
      {'label': 'Extreme Heat (T1)',  'type': 'extreme_heat', 'sev': 'T1', 'color': Color(0xFFF5A623)},
      {'label': 'Severe AQI (T2)',    'type': 'severe_aqi',   'sev': 'T2', 'color': Color(0xFF9C6FFF)},
    ];

    showModalBottomSheet(
      context:            context,
      backgroundColor:    Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── HEADING: City name : trigger with zone ──
            Text('$city : Triggers',
              style: const TextStyle(color: navy, fontSize: 18,
                fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('$zone · Tap to simulate disruption & claim',
              style: const TextStyle(color: gray, fontSize: 13)),
            const SizedBox(height: 20),

            ...triggers.map((t) => GestureDetector(
              onTap: () async {
                Navigator.pop(context);

                // Fire on backend
                await ApiService.fireDemoTrigger(
                  zone:     zone,
                  type:     t['type'] as String,
                  severity: t['sev']  as String,
                  value:    85,
                );

                // Open 5-screen TriggerFlowScreen
                if (context.mounted) {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => TriggerFlowScreen(
                      triggerLabel: t['label'] as String,
                      triggerType:  t['type']  as String,
                      severity:     t['sev']   as String,
                      zone:         zone,
                      workerName:   policy?['name']  ?? 'Worker',
                      upiId:        upiId,
                      maxPayout:    maxP.toInt(),
                      dailyIncome:  income.toInt(),
                    )));
                }
              },
              child: Container(
                margin:  const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color:        (t['color'] as Color).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border:       Border.all(
                    color: (t['color'] as Color).withOpacity(0.25))),
                child: Row(children: [
                  Icon(Icons.bolt_rounded,
                    color: t['color'] as Color, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t['label'] as String,
                        style: const TextStyle(color: navy,
                          fontSize: 14, fontWeight: FontWeight.w700)),
                      Text('$zone · Tap to claim',
                        style: const TextStyle(color: gray, fontSize: 11)),
                    ],
                  )),
                  const Icon(Icons.arrow_forward_ios_rounded,
                    color: gray, size: 14),
                ]),
              ),
            )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // Returns city name from known zones
  String _cityFromZone(String zone) {
    const zoneCity = {
      'Koramangala':'Bengaluru','Indiranagar':'Bengaluru','Whitefield':'Bengaluru',
      'HSR Layout':'Bengaluru','Marathahalli':'Bengaluru','Bellandur':'Bengaluru',
      'Jayanagar':'Bengaluru','Rajajinagar':'Bengaluru','Malleshwaram':'Bengaluru','Hebbal':'Bengaluru',
      'Andheri':'Mumbai','Bandra':'Mumbai','Powai':'Mumbai','Thane':'Mumbai',
      'Kurla':'Mumbai','Dadar':'Mumbai','Borivali':'Mumbai','Mulund':'Mumbai',
      'Gachibowli':'Hyderabad','Hitech City':'Hyderabad','Banjara Hills':'Hyderabad',
      'Anna Nagar':'Chennai','Velachery':'Chennai','Adyar':'Chennai',
      'Koregaon Park':'Pune','Baner':'Pune','Wakad':'Pune','Kothrud':'Pune',
    };
    return zoneCity[zone] ?? zone;
  }

  Widget _body(BuildContext context) => SingleChildScrollView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // Greeting
        Text(
          'Hello, ${(policy?['name'] ?? 'Worker').split(' ').first}! 👋',
          style: const TextStyle(
            color:      navy,
            fontSize:   24,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5)),
        const Text('Your income is protected today.',
          style: TextStyle(color: gray, fontSize: 14,
            height: 1.4)),
        const SizedBox(height: 20),

        // Status card
        _statusCard(),
        const SizedBox(height: 16),

        // Quick stats
        Row(children: [
          _quickStat(Icons.calendar_today_rounded,
            '${_days()}d', 'Remaining', navy),
          const SizedBox(width: 10),
          _quickStat(Icons.bolt_rounded, 
            triggerCount.toString(), 'Triggers', 
            triggerCount > 0 ? const Color(0xFFFF5252) : gold,
            onTap: () => _showTriggersSheet(context),
          ),
          const SizedBox(width: 10),
          _quickStat(Icons.verified_rounded,
            '0', 'Fraud', const Color(0xFF00C853)),
        ]),
        const SizedBox(height: 20),

        // Live Weather Widget
        LiveWeatherCard(
          lat: double.tryParse(policy?['latitude']?.toString() ?? ''),
          lon: double.tryParse(policy?['longitude']?.toString() ?? ''),
          fallbackZone: policy?['zone']?.toString(),
          workerId: workerId,
          policy: policy,
        ),
        
        const SizedBox(height: 20),

        // Coverage — dynamic from admin plan config
        _sectionLabel('What you\'re covered for'),
        const SizedBox(height: 10),
        ..._buildCoverage().map((c) => _coverageRow(context, c)),

        const SizedBox(height: 20),

        // Policy details
        _sectionLabel('Policy Details'),
        const SizedBox(height: 10),
        _glass(child: Column(children: [
          _detRow('Plan',
            (policy?['plan_type'] ?? 'standard')
              .toString().toUpperCase(),
            isTag: true),
          _div(),
          _detRow('Weekly Premium',
            '₹${policy?['weekly_premium'] ?? 74}'),
          _div(),
          _detRow('Max Payout',
            '₹${policy?['max_payout'] ?? 900} / week'),
          _div(),
          _detRow('Coverage Until',
            policy?['end_date']?.toString().substring(0, 10)
              ?? '09 Apr 2026'),
          _div(),
          _detRow('Risk Zone', 'HIGH', isRisk: true),
          _div(),
          _detRow('Platform', policy?['platform'] ?? 'Zepto'),
          _div(),
          _detRow('Zone', policy?['zone'] ?? 'Koramangala'),
        ])),

        const SizedBox(height: 12),

        // ── PDF CERTIFICATE BUTTON ──────────────────────
        GestureDetector(
          onTap: () => _downloadCertificate(context),
          child: Container(
            width:   double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [navy, navy2],
                begin:  Alignment.topLeft,
                end:    Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(
                color:      navy.withOpacity(0.3),
                blurRadius: 16,
                offset:     const Offset(0, 6))],
            ),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.picture_as_pdf_rounded,
                  color: gold, size: 24),
              ),
              const SizedBox(width: 14),
              const Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Download Policy Certificate',
                    style: TextStyle(
                      color:      Colors.white,
                      fontSize:   15,
                      fontWeight: FontWeight.w800)),
                  Text('Official income protection document',
                    style: TextStyle(
                      color:    Colors.white60,
                      fontSize: 12)),
                ],
              )),
              const Icon(Icons.download_rounded,
                color: gold, size: 22),
            ]),
          ),
        ),

        const SizedBox(height: 20),
      ],
    ),
  );

  Widget _statusCard() => Container(
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end:   Alignment.bottomRight,
        colors: [navy, Color(0xFF22387E)],
      ),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(
        color:      navy.withOpacity(0.4),
        blurRadius: 24,
        offset:     const Offset(0, 10))],
    ),
    padding: const EdgeInsets.all(20),
    child: Column(children: [
      Row(children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.shield_rounded,
            color: gold, size: 28),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF00C853).withOpacity(0.2),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(
                  color: const Color(0xFF00C853).withOpacity(0.4)),
              ),
              child: const Text('● ACTIVE',
                style: TextStyle(
                  color:      Color(0xFF00C853),
                  fontSize:   11,
                  fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 6),
            Text(policy?['name'] ?? 'Worker',
              style: const TextStyle(
                color:      Colors.white,
                fontSize:   18,
                fontWeight: FontWeight.w800)),
            Text(
              '${policy?['platform'] ?? 'Zepto'} · ${policy?['zone'] ?? 'Koramangala'}',
              style: TextStyle(
                color:    Colors.white.withOpacity(0.55),
                fontSize: 13)),
          ],
        )),

        // ── FIX: safe initials — only change in entire file ──
        CircleAvatar(
          backgroundColor: gold,
          radius:          22,
          child: Text(
            _safeName()
              .split(' ')
              .where((e) => e.isNotEmpty)
              .map((e) => e[0])
              .take(2)
              .join(),
            style: const TextStyle(
              color:      Colors.white,
              fontWeight: FontWeight.w900,
              fontSize:   14),
          ),
        ),
      ]),
      const SizedBox(height: 18),
      Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(children: [
          _sb('₹${policy?['weekly_premium'] ?? 74}', 'PREMIUM'),
          _sd(),
          _sb('₹${policy?['max_payout'] ?? 900}', 'MAX PAYOUT'),
          _sd(),
          _sb('${_days()}d', 'REMAINING'),
        ]),
      ),
    ]),
  );

  Widget _sb(String v, String l) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(children: [
        Text(v, style: const TextStyle(
          color:      gold,
          fontSize:   17,
          fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(l, style: const TextStyle(
          color: Colors.white38, fontSize: 9)),
      ]),
    ),
  );

  Widget _sd() => Container(
    width: 1, height: 34, color: Colors.white12);

  Widget _coverageRow(BuildContext context, Map<String, dynamic> c) {
    final payout = ((policy?['max_payout'] ?? 900) *
      (c['pct'] as int) / 100).round();
    return GestureDetector(
      onTap: () => _showTriggerDetail(context, c, payout),
      child: Container(
        margin:  const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: bdr),
          boxShadow: [BoxShadow(
            color:      (c['color'] as Color).withOpacity(0.08),
            blurRadius: 10,
            offset:     const Offset(0, 3))],
        ),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: (c['color'] as Color).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(c['icon'] as IconData,
              color: c['color'] as Color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(c['name'] as String,
                style: const TextStyle(
                  color:      navy,
                  fontSize:   14,
                  fontWeight: FontWeight.w700)),
              Text('Tier ${c['tier']} · ${c['pct']}% payout · Tap for details',
                style: const TextStyle(
                  color: gray, fontSize: 12)),
            ],
          )),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('₹$payout',
                style: const TextStyle(
                  color:      gold,
                  fontSize:   17,
                  fontWeight: FontWeight.w900)),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFFCDD8F6), size: 16),
            ],
          ),
        ]),
      ),
    );
  }

  // ── Trigger Detail Popup ──────────────────────────────────────
  void _showTriggerDetail(BuildContext context, Map<String, dynamic> c, int payoutAmt) {
    final col  = c['color'] as Color;
    final icon = c['icon']  as IconData;
    final name = c['name']  as String;
    final tier = c['tier']  as String;
    final pct  = c['pct']   as int;

    // Per-trigger detail content
    final Map<String, Map<String, String>> details = {
      'Heavy Rain': {
        'condition': 'Rainfall exceeds the configured threshold (default: 10 mm/hr) in your zone.',
        'how':       'Our system polls live weather data every 5 minutes. When rainfall crosses the threshold, a claim is auto-created instantly.',
        'payout':    'Tier 2 — you receive 50% of your max weekly payout (₹$payoutAmt).',
        'note':      'You must have been active (online on your delivery app) in the past 2 hours.',
      },
      'Flood Alert': {
        'condition': 'A flood or waterlogging alert is issued for your zone by civic authorities.',
        'how':       'Linked to government flood-alert APIs and local IoT sensors. Triggers automatically when a zone alert is active.',
        'payout':    'Tier 3 — full 100% of your max weekly payout (₹$payoutAmt). Highest severity.',
        'note':      'No activeness requirement for Tier 3 events — safety takes priority.',
      },
      'Extreme Heat': {
        'condition': 'Ambient temperature exceeds the configured threshold (default: 40°C) in your zone.',
        'how':       'Temperature data is pulled from real-time open-weather feeds. Sustained heat above threshold triggers the claim.',
        'payout':    'Tier 1 — 25% of your max weekly payout (₹$payoutAmt). Partial relief.',
        'note':      'Heat events are verified over a sustained 1-hour window to avoid false triggers.',
      },
      'Severe AQI': {
        'condition': 'Air Quality Index in your zone exceeds 200 (Hazardous category).',
        'how':       'AQI data is sourced from CPCB monitoring stations. A claim fires when AQI breaches the plan threshold.',
        'payout':    'Tier 2 — 50% of your max weekly payout (₹$payoutAmt).',
        'note':      'Covers both PM2.5 and PM10 based hazardous readings.',
      },
      'Zone Shutdown': {
        'condition': 'Your delivery zone is officially shut down due to curfew, civic order, or government directive.',
        'how':       'Manually verified and activated by the Insurify admin team within 30 minutes of an official announcement.',
        'payout':    'Tier 3 — 100% of your max weekly payout (₹$payoutAmt).',
        'note':      'Admin-triggered. No sensor threshold needed — applies zone-wide.',
      },
      'Cyclone': {
        'condition': 'IMD cyclone warning for your region at Cyclone or higher category.',
        'how':       'Triggered via IMD API integration. Activates for entire affected zones simultaneously.',
        'payout':    'Tier 3 — 100% of your max weekly payout (₹$payoutAmt). Emergency tier.',
        'note':      'Cooldown does not apply for back-to-back cyclone alerts in the same event.',
      },
      'Storm': {
        'condition': 'Wind speed or storm intensity exceeds the configured threshold in your zone.',
        'how':       'Weather station data triggers automatically when sustained storm conditions are detected.',
        'payout':    'Tier 2 — 50% of your max weekly payout (₹$payoutAmt).',
        'note':      'Includes thunderstorm, lightning storm, and severe squal conditions.',
      },
      'Platform Shutdown': {
        'condition': 'Your delivery platform (e.g. Zepto, Blinkit) officially suspends operations in your city.',
        'how':       'Admin verifies the official platform communication and activates the trigger within 1 hour.',
        'payout':    'Tier 3 — 100% of your max weekly payout (₹$payoutAmt).',
        'note':      'Requires 2+ hours of official downtime for the claim to qualify.',
      },
    };

    final d = details[name] ?? {
      'condition': 'Threshold-based automatic detection.',
      'how':       'System monitors live data and triggers when conditions are met.',
      'payout':    '$tier — $pct% of your max weekly payout (₹$payoutAmt).',
      'note':      'Check policy terms for full details.',
    };

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle + close
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: bdr, borderRadius: BorderRadius.circular(99))),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: const Icon(Icons.close_rounded, color: gray, size: 22),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Icon + name + tier badge
            Row(children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: col.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: col, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(
                    color: navy, fontSize: 20, fontWeight: FontWeight.w900)),
                  Row(children: [
                    _triggerBadge(tier, col),
                    const SizedBox(width: 6),
                    _triggerBadge('$pct% payout', col.withOpacity(0.6)),
                  ]),
                ],
              )),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: gold.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: gold.withOpacity(0.3)),
                ),
                child: Column(children: [
                  Text('₹$payoutAmt',
                    style: const TextStyle(color: gold, fontSize: 18, fontWeight: FontWeight.w900)),
                  const Text('payout', style: TextStyle(color: gold, fontSize: 9, fontWeight: FontWeight.w600)),
                ]),
              ),
            ]),

            const SizedBox(height: 24),
            _detailSection('When does it trigger?', d['condition']!, Icons.sensors_rounded, col),
            const SizedBox(height: 14),
            _detailSection('How it works', d['how']!,    Icons.auto_awesome_rounded, col),
            const SizedBox(height: 14),
            _detailSection('Payout logic',  d['payout']!, Icons.account_balance_wallet_rounded, col),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: col.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: col.withOpacity(0.2)),
              ),
              child: Row(children: [
                Icon(Icons.info_outline_rounded, color: col, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(d['note']!,
                  style: TextStyle(color: col, fontSize: 12, fontWeight: FontWeight.w500))),
              ]),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: navy,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text('Got it', style: TextStyle(
                  color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailSection(String title, String body, IconData icon, Color col) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(color: col.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: col, size: 16),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: col, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
          const SizedBox(height: 4),
          Text(body, style: const TextStyle(color: navy, fontSize: 13, height: 1.5, fontWeight: FontWeight.w500)),
        ],
      )),
    ],
  );

  Widget _triggerBadge(String text, Color col) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: col.withOpacity(0.12),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(text, style: TextStyle(color: col, fontSize: 10, fontWeight: FontWeight.w800)),
  );

  Widget _quickStat(IconData icon, String v, String l, Color c, {VoidCallback? onTap}) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: bdr),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: c, size: 20),
            const SizedBox(height: 8),
            Text(v, style: TextStyle(
              color:      c,
              fontSize:   18,
              fontWeight: FontWeight.w900)),
            Text(l, style: const TextStyle(
              color: gray, fontSize: 11)),
          ],
        ),
      ),
    ),
  );

  Widget _howRow(String num, String title, String sub) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Container(
          width: 28, height: 28,
          decoration: const BoxDecoration(
            color: navy, shape: BoxShape.circle),
          child: Center(child: Text(num,
            style: const TextStyle(
              color:      Colors.white,
              fontSize:   12,
              fontWeight: FontWeight.w900))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(
              color:      navy,
              fontSize:   14,
              fontWeight: FontWeight.w700)),
            Text(sub, style: const TextStyle(
              color: gray, fontSize: 12, height: 1.3)),
          ],
        )),
      ]),
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
            color:      const Color(0xFF7B9CFF).withOpacity(0.08),
            blurRadius: 16,
            offset:     const Offset(0, 4))],
        ),
        padding: const EdgeInsets.all(16),
        child:   child,
      ),
    ),
  );

  Widget _detRow(String label, String value,
      {bool isTag = false, bool isRisk = false}) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
            style: const TextStyle(color: gray, fontSize: 14)),
          isTag
            ? _tag(value, navy)
            : isRisk
              ? _tag(value, const Color(0xFFFF5252))
              : Text(value, style: const TextStyle(
                  color:      navy,
                  fontSize:   14,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );

  Widget _tag(String v, Color c) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: 12, vertical: 4),
    decoration: BoxDecoration(
      color:        c.withOpacity(0.1),
      borderRadius: BorderRadius.circular(99),
      border:       Border.all(color: c.withOpacity(0.3)),
    ),
    child: Text(v, style: TextStyle(
      color:      c,
      fontSize:   12,
      fontWeight: FontWeight.w700)),
  );

  Widget _div() => Divider(color: bdr, height: 1);

  Widget _sectionLabel(String t) => Text(t,
    style: const TextStyle(
      color:         gray,
      fontSize:      12,
      fontWeight:    FontWeight.w700,
      letterSpacing: 0.8));

  Widget _blob(double s, Color c) => Container(
    width: s, height: s,
    decoration: BoxDecoration(
      shape: BoxShape.circle, color: c));
  void _showTriggersSheet(BuildContext context) async {
    final zone = policy?['zone'] ?? 'Unknown';
    final allClaims = await ApiService.getClaims(workerId);
    
    // Filter to show only recent triggers (last 48 hours for instance)
    final now = DateTime.now();
    final triggers = allClaims.where((c) {
      if (c['detected_at'] == null) return false;
      try {
        final dt = DateTime.parse(c['detected_at']);
        return now.difference(dt).inHours <= 48;
      } catch (_) { return false; }
    }).toList();

    if (context.mounted) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your Recent Triggers',
                style: const TextStyle(color: navy, fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              if (triggers.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text('No active triggers detected in your zone.', style: TextStyle(color: gray)),
                )
              else
                ...triggers.map((t) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F8F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: bdr),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.bolt_rounded, color: gold, size: 24),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${t['trigger_type'].toString().replaceAll('_', ' ').toUpperCase()}',
                               style: const TextStyle(color: navy, fontWeight: FontWeight.w800)),
                            Text('Severity: ${t['severity']} · Value: ${t['value']}',
                               style: const TextStyle(color: gray, fontSize: 12)),
                          ],
                        ),
                      ),
                      Text('${t['detected_at'].toString().substring(11, 16)}',
                         style: const TextStyle(color: gray, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                )),
              const SizedBox(height: 20),
            ],
          ),
        ),
      );
    }
  }
}

// ── LIVE WEATHER WIDGET ──────────────────────────────────────────────────────
enum WeatherState { normal, warning, danger, cooldown }

class LiveWeatherCard extends StatefulWidget {
  final double? lat;
  final double? lon;
  final String? fallbackZone;
  final int workerId;
  final Map<String, dynamic>? policy;

  const LiveWeatherCard({
    super.key,
    this.lat,
    this.lon,
    this.fallbackZone,
    required this.workerId,
    this.policy,
  });

  @override
  State<LiveWeatherCard> createState() => _LiveWeatherCardState();
}

class _LiveWeatherCardState extends State<LiveWeatherCard> {
  Map<String, dynamic>? weather;
  Timer? _timer;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
    _timer = Timer.periodic(const Duration(minutes: 5), (_) => _fetch());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetch() async {
    // If no GPS, fallback to mock data or we can try using the fallback zone
    if (widget.lat == null || widget.lon == null) {
      if (mounted) setState(() { loading = false; });
      return;
    }
    final w = await ApiService.getLiveWeather(widget.lat!, widget.lon!, widget.workerId);
    if (mounted && w != null) {
      setState(() {
        weather = w;
        loading = false;
      });
    } else if (mounted) {
      setState(() => loading = false);
    }
  }

  WeatherState get _state {
    if (weather == null) return WeatherState.normal;
    final r   = (weather!['rainfall']    as num?)?.toDouble() ?? 0;
    final t   = (weather!['temperature'] as num?)?.toDouble() ?? 25;
    final aqi = (weather!['aqi']         as num?)?.toDouble() ?? 0;

    // ── Step 1: If a trigger already fired within 24h → COOLDOWN ────────
    // This is independent of current weather thresholds.
    final cooldownHrs = (weather!['cooldown_remaining_hours'] as num?)?.toDouble() ?? 0;
    if (cooldownHrs > 0) return WeatherState.cooldown;

    // ── Step 2: If no cooldown, check live thresholds → DANGER ──────────
    final th      = widget.policy?['thresholds_json'] as Map<String, dynamic>? ?? {};
    final trigList = (widget.policy?['triggers_json'] as List?) ?? [];

    final rainTh = (th['rain_mm'] as num?)?.toDouble() ?? 10.0;
    final tempTh = (th['temp_c']  as num?)?.toDouble() ?? 40.0;
    final aqiTh  = (th['aqi']    as num?)?.toDouble() ?? 200.0;

    final rainD = trigList.contains('heavy_rain')   && r   >= rainTh;
    final tempD = trigList.contains('extreme_heat') && t   >= tempTh;
    final aqiD  = trigList.contains('severe_aqi')   && aqi >= aqiTh;

    if (rainD || tempD || aqiD) return WeatherState.danger;

    // ── Step 3: Warning — 70-80% of threshold ───────────────────────────
    if (trigList.contains('heavy_rain')   && r >= rainTh * 0.7) return WeatherState.warning;
    if (trigList.contains('extreme_heat') && t >= tempTh * 0.8) return WeatherState.warning;

    return WeatherState.normal;
  }

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF1A2E6E);

    final st = _state;
    Color  statusColor;
    String statusText;

    switch (st) {
      case WeatherState.danger:
        // Before any trigger fires — show DANGER only, no cooldown text
        statusColor = const Color(0xFFFF5252);
        statusText  = '● DANGER — disruption threshold reached';
        break;
      case WeatherState.warning:
        statusColor = const Color(0xFFF5A623);
        statusText  = 'Warning — conditions worsening';
        break;
      case WeatherState.cooldown:
        // After trigger fired — show cooldown countdown
        statusColor = const Color(0xFFFF8A65);
        final hrs   = (weather?['cooldown_remaining_hours'] as num?)?.toInt() ?? 23;
        statusText  = 'Cooling down: ~${hrs}h left until next trigger';
        break;
      default:
        statusColor = const Color(0xFF75A642);
        statusText  = 'Safe conditions — no disruption detected';
    }

    final isDanger    = st == WeatherState.danger;
    final isCooldown  = st == WeatherState.cooldown;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Live conditions',
                style: TextStyle(
                  color: navy,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'serif', // matching the design's elegant serif
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F3DE),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF75A642),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'LIVE',
                      style: TextStyle(
                        color: Color(0xFF53782E),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 16),
          
          // Location
          Row(
            children: [
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  weather?['zone'] ?? widget.fallbackZone ?? 'Locating GPS...',
                  style: const TextStyle(
                    color: Color(0xFF7A8BB0),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (loading)
            const Center(child: Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(color: navy),
            ))
          else ...[
            // 3 Blocks
            Row(
              children: [
                _buildStatBlock(
                  (weather?['rainfall'] as num?)?.toStringAsFixed(1) ?? '0',
                  'mm/hr\nRainfall',
                  subLabel: 'Limit: ${(widget.policy?['thresholds_json']?['rain_mm'] ?? 10)}',
                ),
                const SizedBox(width: 10),
                _buildStatBlock(
                  (weather?['temperature'] as num?)?.toStringAsFixed(0) ?? '25',
                  '°C\nTemp',
                  subLabel: 'Limit: ${(widget.policy?['thresholds_json']?['temp_c'] ?? 40)}',
                ),
                const SizedBox(width: 10),
                _buildStatBlock(
                  (weather?['aqi'] as num?)?.toStringAsFixed(0) ?? '50',
                  'AQI\nAir quality',
                  subLabel: 'Limit: ${(widget.policy?['thresholds_json']?['aqi'] ?? 200)}',
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Status bar
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 12, height: 12,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor.withOpacity(0.8),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Action button
            GestureDetector(
              onTap: isDanger ? () async {
                final maxP = (widget.policy?['max_payout'] as num?)?.toDouble() ?? 500;
                final income = (widget.policy?['avg_daily_income'] as num?)?.toDouble() ?? 800;
                
                // Show a brief loading indicator while we fire the demo trigger, just in case
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.white)),
                );
                
                await ApiService.fireDemoTrigger(
                  zone:     widget.fallbackZone ?? 'Unknown',
                  type:     'extreme_heat',
                  severity: 'T2',
                  value:    100,
                  workerId: widget.workerId,
                );
                
                if (context.mounted) Navigator.pop(context); // Close loader

                if (context.mounted) {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => TriggerFlowScreen(
                      triggerLabel: 'Extreme Heat',
                      triggerType:  'extreme_heat',
                      severity:     'T2',
                      zone:         widget.fallbackZone ?? 'Unknown',
                      workerName:   widget.policy?['name'] ?? 'Worker',
                      upiId:        '${widget.policy?['phone'] ?? '9999'}@ybl',
                      maxPayout:    maxP.toInt(),
                      dailyIncome:  income.toInt(),
                    )));
                }
              } : null,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: isDanger
                      ? const Color(0xFF4B9FFF)
                      : isCooldown
                          ? const Color(0xFFFF8A65).withOpacity(0.85)
                          : const Color(0xFFCDD8F6).withOpacity(0.6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    isDanger
                        ? 'Disruption detected — view payout'
                        : isCooldown
                            ? 'Wait for cooldown to finish'
                            : 'Disruption detected — view payout',
                    style: TextStyle(
                      color: (isDanger || isCooldown)
                          ? Colors.white
                          : const Color(0xFF7A8BB0),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            )
          ]
        ],
      ),
    );
  }

  Widget _buildStatBlock(String value, String label, {String? subLabel}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8F9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Color(0xFF1A2E6E),
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF7A8BB0),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
            if (subLabel != null) ...[
              const SizedBox(height: 4),
              Text(
                subLabel,
                style: const TextStyle(
                  color: Color(0xFFF5A623),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}