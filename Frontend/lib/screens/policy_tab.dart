import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/certificate_generator.dart';
import 'payout_animation_screen.dart';
import 'admin_screen.dart';
import 'trigger_flow_screen.dart';
import 'trigger_alert_flow.dart';

class PolicyTab extends StatefulWidget {
  final int workerId;
  final Map<String, dynamic>? policy;
  final bool loading;
  final VoidCallback onRefresh;

  const PolicyTab({
    super.key,
    required this.workerId,
    required this.policy,
    required this.loading,
    required this.onRefresh,
  });

  @override
  State<PolicyTab> createState() => _PolicyTabState();
}

class _PolicyTabState extends State<PolicyTab> {
  int workerId   = 0;
  Map<String, dynamic>? policy;
  bool loading   = false;
  VoidCallback get onRefresh => widget.onRefresh;

  int fraudCount = 0;

  static const bg    = Color(0xFFE8EDFF);
  static const navy  = Color(0xFF1A2E6E);
  static const navy2 = Color(0xFF22387E);
  static const gold  = Color(0xFFF5A623);
  static const gray  = Color(0xFF7A8BB0);
  static const bdr   = Color(0xFFCDD8F6);

  @override
  void initState() {
    super.initState();
    workerId = widget.workerId;
    policy   = widget.policy;
    loading  = widget.loading;
    _fetchFraudCount();
  }

  @override
  void didUpdateWidget(covariant PolicyTab old) {
    super.didUpdateWidget(old);
    workerId = widget.workerId;
    policy   = widget.policy;
    loading  = widget.loading;
  }

  Future<void> _fetchFraudCount() async {
    try {
      final claims = await ApiService.getClaims(workerId);
      final count = claims.where((c) =>
        c['fraud_flag'] == true || c['status'] == 'fraud_review').length;
      if (mounted) setState(() => fraudCount = count);
    } catch (_) {}
  }

  // ── Trigger Fraud Test ─────────────────────────────────────
  Future<void> _triggerFraudTest(BuildContext ctx) async {
    final zone = policy?['zone'] ?? 'Your Zone';
    
    // Show loading dialog
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFFF6D00), size: 48),
            SizedBox(height: 16),
            Text('Simulating Fraud Claim...',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF1A2E6E), fontSize: 16, fontWeight: FontWeight.w700)),
            SizedBox(height: 8),
            Text('Running 4-layer fraud detection pipeline',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF7A8BB0), fontSize: 13)),
            SizedBox(height: 16),
            CircularProgressIndicator(color: Color(0xFFFF6D00)),
          ],
        ),
      ),
    );

    try {
      await ApiService.fireDemoTrigger(
        zone:       zone,
        type:       'heavy_rain',
        severity:   'T2',
        value:      85,
        forceFraud: true,
      );

      if (!ctx.mounted) return;
      Navigator.of(ctx, rootNavigator: true).pop(); // close loading

      // Update fraud count
      await _fetchFraudCount();

      // Show success dialog with fraud details
      if (!ctx.mounted) return;
      showDialog(
        context: ctx,
        builder: (_) => AlertDialog(
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16))),
          title: const Row(children: [
            Icon(Icons.gpp_bad_rounded, color: Color(0xFFFF5252), size: 28),
            SizedBox(width: 8),
            Text('Fraud Detected!',
              style: TextStyle(color: Color(0xFFFF5252), fontSize: 18, fontWeight: FontWeight.w800)),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5252).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFF5252).withOpacity(0.3))),
                child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('⚠ Fraudulent Claim Created',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  SizedBox(height: 4),
                  Text('Status: FRAUD REVIEW',
                    style: TextStyle(color: Color(0xFFFF6D00), fontWeight: FontWeight.w600, fontSize: 13)),
                  SizedBox(height: 4),
                  Text('Reason: Manual trigger — Suspicious activity testing',
                    style: TextStyle(color: Color(0xFF7A8BB0), fontSize: 12)),
                ]),
              ),
              const SizedBox(height: 12),
              const Text('💳 Payout: HELD by Razorpay',
                style: TextStyle(color: Color(0xFFFF5252), fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 4),
              const Text('Go to Claims tab to see the flagged claim.',
                style: TextStyle(color: Color(0xFF7A8BB0), fontSize: 12)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK', style: TextStyle(color: Color(0xFF1A2E6E), fontWeight: FontWeight.w700))),
          ],
        ),
      );
    } catch (e) {
      if (ctx.mounted) {
        Navigator.of(ctx, rootNavigator: true).pop();
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text('Fraud test failed: $e'), backgroundColor: Colors.red));
      }
    }
  }

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
        zone:          policy?['zone']            ?? 'Your Zone',
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
    final zone    = policy?['zone']     ?? 'Your Zone';
    final city    = _cityFromZone(zone);
    final upiId   = policy?['upi_id']  ?? '${(policy?['name'] ?? 'worker').toLowerCase().replaceAll(' ', '')}@okicici';
    final maxP    = (policy?['max_payout']       ?? 900) as num;
    final income  = (policy?['avg_daily_income'] ?? 800) as num;

    final triggers = [
      {'label': 'Heavy Rain (T2)',    'type': 'heavy_rain',   'sev': 'T2', 'color': Color(0xFF4B9FFF)},
      {'label': 'Flood Alert (T3)',   'type': 'flood_alert',  'sev': 'T3', 'color': Color(0xFFFF5252)},
      {'label': 'Extreme Heat (T1)',  'type': 'extreme_heat', 'sev': 'T1', 'color': Color(0xFFF5A623)},
      {'label': 'Severe AQI (T2)',    'type': 'severe_aqi',   'sev': 'T2', 'color': Color(0xFF9C6FFF)},
      {'label': 'Fraud Test (Testing)','type': 'heavy_rain',  'sev': 'T2', 'color': Color(0xFFFF6D00), 'forceFraud': true},
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
                  zone:       zone,
                  type:       t['type'] as String,
                  severity:   t['sev']  as String,
                  value:      85,
                  forceFraud: t['forceFraud'] == true,
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

  // City resolution now happens dynamically on the server via geocoding
  String _cityFromZone(String zone) {
    // Zone name is displayed directly — city grouping is server-side
    return zone;
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
          _quickStat(Icons.bolt_rounded, '5', 'Triggers', gold),
          const SizedBox(width: 10),
          _quickStat(Icons.verified_rounded,
            '$fraudCount', 'Fraud',
            fraudCount > 0 ? const Color(0xFFFF5252) : const Color(0xFF00C853)),
        ]),
        const SizedBox(height: 16),

        // ── TRIGGER FRAUD TEST BUTTON ──────────────────────
        GestureDetector(
          onTap: () => _triggerFraudTest(context),
          child: Container(
            width:   double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                const Color(0xFFFF6D00).withOpacity(0.9),
                const Color(0xFFFF9800),
              ]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(
                color: const Color(0xFFFF6D00).withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 6))],
            ),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.gpp_bad_rounded,
                  color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              const Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('🚨 Trigger Fraud Test',
                    style: TextStyle(
                      color:      Colors.white,
                      fontSize:   15,
                      fontWeight: FontWeight.w800)),
                  Text('Simulate a fraudulent claim for testing',
                    style: TextStyle(
                      color: Colors.white70, fontSize: 12)),
                ],
              )),
              const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white, size: 16),
            ]),
          ),
        ),
        const SizedBox(height: 16),

        // Demo trigger banner
        GestureDetector(
          onTap: () => _showTriggerDemo(context),
          child: Container(
            width:   double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                const Color(0xFFFF5252).withOpacity(0.9),
                const Color(0xFFFF7B7B),
              ]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(
                color:      const Color(0xFFFF5252)
                  .withOpacity(0.3),
                blurRadius: 16,
                offset:     const Offset(0, 6))],
            ),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.play_circle_rounded,
                  color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${policy?['zone'] ?? 'Your Zone'} : ${coverage.first['name']} (${coverage.first['tier']})',
                    style: const TextStyle(
                      color:      Colors.white,
                      fontSize:   15,
                      fontWeight: FontWeight.w800)),
                  const Text('Watch instant payout happen live',
                    style: TextStyle(
                      color: Colors.white70, fontSize: 12)),
                ],
              )),
              const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white, size: 16),
            ]),
          ),
        ),

        const SizedBox(height: 20),

        // Coverage
        _sectionLabel('What you\'re covered for'),
        const SizedBox(height: 10),
        ...coverage.map((c) => _coverageRow(c)),

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
          _detRow('Zone', policy?['zone'] ?? 'Your Zone'),
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

        // How payouts work
        _sectionLabel('How Payouts Work'),
        const SizedBox(height: 10),
        _glass(child: Column(children: [
          _howRow('1', 'Disruption detected',
            'Weather or civic alert fires automatically'),
          _howRow('2', 'Activity verified',
            'System checks you were online in your zone'),
          _howRow('3', 'Fraud check passed',
            'GPS and behavior validated in seconds'),
          _howRow('4', 'Instant payout',
            'Money credited to UPI in under 60 seconds'),
        ])),
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
              '${policy?['platform'] ?? 'Zepto'} · ${policy?['zone'] ?? 'Your Zone'}',
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

  Widget _coverageRow(Map<String, dynamic> c) {
    final payout = ((policy?['max_payout'] ?? 900) *
      (c['pct'] as int) / 100).round();
    return Container(
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
            Text('Tier ${c['tier']} · ${c['pct']}% payout',
              style: const TextStyle(
                color: gray, fontSize: 12)),
          ],
        )),
        Text('₹$payout',
          style: const TextStyle(
            color:      gold,
            fontSize:   18,
            fontWeight: FontWeight.w900)),
      ]),
    );
  }

  Widget _quickStat(IconData icon, String v,
      String l, Color c) => Expanded(
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
}