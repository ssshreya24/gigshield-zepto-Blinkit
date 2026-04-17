import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'policy_tab.dart' show PolicyTab;
import 'claims_tab.dart';
import 'profile_tab.dart';
import 'trigger_alert_flow.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  final int workerId;
  final int initialTab;
  const HomeScreen({super.key, required this.workerId, this.initialTab = 0});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {

  static const bg   = Color(0xFFE8EDFF);
  static const navy = Color(0xFF1A2E6E);
  static const gold = Color(0xFFF5A623);
  static const gray = Color(0xFF7A8BB0);
  static const bdr  = Color(0xFFCDD8F6);

  int _tab = 0;
  int _claimsRefreshKey = 0; // Increment to force ClaimsTab rebuild & reload
  Map<String, dynamic>? policy;
  bool loadingPolicy = true;

  late AnimationController _tabAnim;
  Timer? _demoTimer;

  // Possible demo triggers to rotate through
  static const _demos = [
    {'type': 'heavy_rain',   'severity': 'T2', 'value': 85,
     'label': 'Heavy Rain',  'icon': '🌧️'},
    {'type': 'flood_alert',  'severity': 'T3', 'value': 95,
     'label': 'Flood Alert', 'icon': '🌊'},
    {'type': 'extreme_heat', 'severity': 'T1', 'value': 44,
     'label': 'Extreme Heat','icon': '🌡️'},
    {'type': 'severe_aqi',   'severity': 'T2', 'value': 310,
     'label': 'Severe AQI',  'icon': '😷'},
  ];

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    _claimsRefreshKey = widget.initialTab == 1 ? 1 : 0;
    _tabAnim = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 250),
    );
    _tabAnim.forward();
    _loadPolicy();
    // Always schedule demo trigger on app launch for demo purposes
    _scheduleDemoTrigger();
  }

  @override
  void dispose() {
    _tabAnim.dispose();
    _demoTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPolicy() async {
    final data = await ApiService.getPolicy(widget.workerId);
    if (mounted) setState(() { policy = data; loadingPolicy = false; });
    // Report GPS location for fraud detection
    _reportLocation();
  }

  Future<void> _reportLocation() async {
    try {
      final geo = await import_geolocator();
      if (geo != null) {
        await ApiService.updateLocation(
          workerId: widget.workerId,
          lat: geo['lat']!,
          lon: geo['lon']!,
        );
      }
    } catch (_) {
      // GPS permission denied or unavailable — non-blocking
    }
  }

  // Attempt to get current GPS position
  Future<Map<String, double>?> import_geolocator() async {
    try {
      // Using geolocator package (already in pubspec)
      final position = await _getCurrentPosition();
      return position;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, double>?> _getCurrentPosition() async {
    try {
      // Minimal GPS fetch — uses package:geolocator
      final uri = Uri.parse('https://ipapi.co/json/');
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        return {
          'lat': (data['latitude'] as num).toDouble(),
          'lon': (data['longitude'] as num).toDouble(),
        };
      }
    } catch (_) {}
    return null;
  }

  // ── Auto trigger logic ─────────────────────────────────────
  // First launch: fire one demo trigger unconditionally (for wow-factor)
  // After that: only fire if the weather API confirms a real disruption
  bool _demoFiredThisSession = false;

  void _scheduleDemoTrigger() {
    if (_demoFiredThisSession) return;
    final delay = 5 + Random().nextInt(6); // 5–10s
    _demoTimer = Timer(Duration(seconds: delay), _checkAndFireTrigger);
  }

  Future<void> _checkAndFireTrigger() async {
    if (!mounted || _demoFiredThisSession) return;
    _demoFiredThisSession = true;

    final prefs = await SharedPreferences.getInstance();
    final firstFired = prefs.getBool('demo_first_fired') ?? false;

    if (!firstFired) {
      // ── FIRST EVER LAUNCH: fire one demo trigger unconditionally ──
      await prefs.setBool('demo_first_fired', true);
      await _fireDemoTrigger();
      return;
    }

    // ── SUBSEQUENT LAUNCHES: check real weather API first ──
    final zone = policy?['zone'] as String? ?? 'Koramangala';
    final weatherData = await ApiService.checkWeather(zone);

    if (weatherData['disruption'] == true) {
      // Real disruption detected — pick the first matching disruption
      final disruptions = weatherData['disruptions'] as List? ?? [];
      if (disruptions.isNotEmpty) {
        final d = disruptions[0] as Map<String, dynamic>;
        await _fireDemoTrigger(
          overrideType:     d['type'] as String?,
          overrideSeverity: d['severity'] as String?,
          overrideValue:    d['value'] as int?,
        );
      }
    }
    // No disruption → no popup. Silent. Realistic.
  }

  Future<void> _fireDemoTrigger({
    bool forceFraud = false,
    String? overrideType,
    String? overrideSeverity,
    int? overrideValue,
  }) async {
    if (!mounted) return;
    final pick = _demos.firstWhere(
      (d) => d['type'] == overrideType,
      orElse: () => _demos[Random().nextInt(_demos.length)],
    );
    final zone = policy?['zone'] as String? ?? 'Your Zone';
    final type     = overrideType     ?? pick['type'] as String;
    final severity = overrideSeverity ?? pick['severity'] as String;
    final value    = overrideValue    ?? pick['value'] as int;

    Map<String, dynamic> triggerData = {
      'trigger_type': type,
      'severity':     severity,
      'zone':         zone,
      'label':        pick['label'],
      'icon':         pick['icon'],
      'value':        value,
      'worker_id':    widget.workerId,
      'amount':       _payoutForSeverity(severity),
    };

    try {
      final res = await http.post(
        Uri.parse('$BASE_URL/demo/trigger'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'zone':          zone,
          'type':          type,
          'severity':      severity,
          'value':         value,
          'worker_id':     widget.workerId,
          'force_fraud':   forceFraud,
          'is_auto_popup': true,
        }),
      );
      if (res.statusCode == 200) {
        final body = json.decode(res.body) as Map<String, dynamic>;
        final claim = body['claim'] as Map?;
        triggerData = {
          ...triggerData,
          if (claim != null) ...{
            'amount':             claim['amount'] ?? triggerData['amount'],
            'fraud_flag':         claim['fraud_flag'] ?? false,
            'fraud_reason':       claim['fraud_reason'],
            'claim_status':       claim['status'],
            'fraud_score':        claim['fraud_score'],
            'fraud_probability':  claim['fraud_probability'],
            'behavioral_profile': claim['behavioral_profile'],
          },
          if (body['trigger'] != null)
            'trigger_id': (body['trigger'] as Map)['id'],
        };
      }
    } catch (_) {
      // Network unavailable — use mock data, demo still works
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        title: Center(
          child: Icon(Icons.warning_rounded, color: gold, size: 48),
        ),
        content: Text(
          "A trigger event is detected. Starting claim process.",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: navy,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TriggerAlertFlow(
          triggers: [triggerData],
          policy:   policy,
        ),
      ),
    );
    // User returned from the trigger/claim flow → refresh Claims tab
    if (mounted) _openClaimsTab();
  }

  int _payoutForSeverity(String sev) {
    final max = policy?['max_payout'] as int? ?? 1500;
    switch (sev) {
      case 'T3': return max;
      case 'T2': return (max * 0.5).round();
      default:   return (max * 0.25).round();
    }
  }

  void _switchTab(int i) {
    setState(() => _tab = i);
    _tabAnim.reset();
    _tabAnim.forward();
  }

  // Switch to Claims tab AND force a fresh data load
  void _openClaimsTab() {
    setState(() {
      _tab = 1;
      _claimsRefreshKey++; // new key → ClaimsTab rebuilds & calls initState
    });
    _tabAnim.reset();
    _tabAnim.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          FadeTransition(opacity: _tabAnim, child: _buildTab()),
          Positioned(
            bottom: 0, left: 0, right: 0,
            child:  _bottomNav(),
          ),
        ],
      ),
    );
  }

  Widget _buildTab() {
    switch (_tab) {
      case 0: return PolicyTab(
        workerId:  widget.workerId,
        policy:    policy,
        loading:   loadingPolicy,
        onRefresh: _loadPolicy,
      );
      case 1: return ClaimsTab(
        key: ValueKey(_claimsRefreshKey),
        workerId: widget.workerId,
      );
      case 2: return ProfileTab(workerId: widget.workerId, policy: policy);
      default: return PolicyTab(
        workerId:  widget.workerId,
        policy:    policy,
        loading:   loadingPolicy,
        onRefresh: _loadPolicy,
      );
    }
  }

  Widget _bottomNav() {
    final items = [
      {'icon': Icons.home_rounded,         'active': Icons.home_rounded,         'label': 'Home'},
      {'icon': Icons.receipt_long_rounded, 'active': Icons.receipt_long_rounded, 'label': 'Claims'},
      {'icon': Icons.person_outline,       'active': Icons.person_rounded,       'label': 'Profile'},
    ];

    return Container(
      decoration: BoxDecoration(
        color:  Colors.white,
        border: Border(top: BorderSide(color: bdr, width: 1)),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset:     const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 6, horizontal: 16),
          child: Row(
            children: List.generate(items.length, (i) {
              final active = _tab == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => _switchTab(i),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve:    Curves.easeOut,
                    padding: const EdgeInsets.symmetric(
                      vertical: 8, horizontal: 8),
                    decoration: BoxDecoration(
                      color: active
                        ? navy.withOpacity(0.07)
                        : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            active
                              ? items[i]['active'] as IconData
                              : items[i]['icon'] as IconData,
                            color: active ? navy : gray,
                            size:  active ? 26 : 23,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          items[i]['label'] as String,
                          style: TextStyle(
                            color:      active ? navy : gray,
                            fontSize:   11,
                            fontWeight: active
                              ? FontWeight.w800
                              : FontWeight.w400,
                            letterSpacing: active ? 0.2 : 0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 3,
                          width:  active ? 20 : 0,
                          decoration: BoxDecoration(
                            color:        navy,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
