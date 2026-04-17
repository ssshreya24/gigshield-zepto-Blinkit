import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'policy_tab.dart';
import 'claims_tab.dart';
import 'profile_tab.dart';
import 'trigger_alert_flow.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  final int  workerId;
  final int  initialTab;
  final bool fromPayment; // true when navigating right after policy payment
  const HomeScreen({
    super.key,
    required this.workerId,
    this.initialTab  = 0,
    this.fromPayment = false,
  });
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
  Timer? _policyTimer;  // ← polls admin policy changes every 30s

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
    _initializeSafe();
  }

  Future<void> _initializeSafe() async {
    await _initClaimSync();
    await _loadPolicy();
    if (widget.fromPayment) {
      // Arrived fresh from payment → wait 10 s before first trigger check
      await Future.delayed(const Duration(seconds: 10));
      if (!mounted) return;
    }
    _scheduleDemoTrigger();
  }

  Future<void> _initClaimSync() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getInt('last_seen_claim_id') ?? 0;
    
    final claims = await ApiService.getClaims(widget.workerId);
    if (claims.isNotEmpty) {
      final latestId = int.tryParse(claims.first['id'].toString()) ?? 0;
      
      if (widget.initialTab == 1) {
        // Just returned from completing the claim flow. Suppress it!
        _lastClaimId = latestId;
        await prefs.setInt('last_seen_claim_id', latestId);
      } else {
        // Normal launch, pick up from persisted ID so offline claims pop up!
        _lastClaimId = savedId;
      }
    } else {
      _lastClaimId = savedId;
    }
  }

  @override
  void dispose() {
    _tabAnim.dispose();
    _demoTimer?.cancel();
    _policyTimer?.cancel();
    super.dispose();
  }

  int _triggerCount = 0;
  int _lastClaimId = 0;
  bool _showingPopup = false;

  Future<void> _loadPolicy() async {
    final data = await ApiService.getPolicy(widget.workerId);
    if (mounted) {
      setState(() { policy = data; loadingPolicy = false; });
      if (data != null && data['zone'] != null) {
        final allClaims = await ApiService.getClaims(widget.workerId);
        final now = DateTime.now();
        final recentTriggers = allClaims.where((c) {
          if (c['detected_at'] == null) return false;
          try {
            return now.difference(DateTime.parse(c['detected_at'])).inHours <= 48;
          } catch (_) { return false; }
        }).toList();
        setState(() { _triggerCount = recentTriggers.length; });
      }
      _checkNewClaims();
    }
  }

  Future<void> _checkNewClaims() async {
    if (_showingPopup) return;
    final claims = await ApiService.getClaims(widget.workerId);
    if (claims.isEmpty) return;
    
    final latest = claims.first; // sorted by DESC in backend
    final id = int.tryParse(latest['id'].toString()) ?? 0;
    
    if (id > _lastClaimId && (latest['status'] == 'processing' || latest['status'] == 'approved' || latest['status'] == 'completed')) {
      _lastClaimId = id;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_seen_claim_id', id);
      _fireBackendTrigger(latest);
    }
  }

  Future<void> _fireBackendTrigger(Map<String, dynamic> claim) async {
    if (!mounted || _showingPopup) return;
    setState(() => _showingPopup = true);

    final triggerData = {
      'trigger_type': claim['trigger_type'] ?? 'heavy_rain',
      'zone':         claim['zone']         ?? 'My Zone',
      'amount':       claim['payout_amount'] ?? 500,
      'trigger_id':   claim['trigger_id'],
      'claim_id':     claim['id'],
      'expected_income': claim['expected_income'],
      'actual_income':   claim['actual_income'],
    };

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
        title: Center(child: Icon(Icons.bolt_rounded, color: gold, size: 48)),
        content: Text(
          "Automatic Payout Activated!\nWeather disruption detected in your area.",
          textAlign: TextAlign.center,
          style: TextStyle(color: navy, fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );

    await Future.delayed(const Duration(seconds: 3));
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
    
    if (mounted) {
      setState(() => _showingPopup = false);
      _openClaimsTab();
    }
  }

  // ── Auto trigger: Polling real claims every 10s
  void _scheduleDemoTrigger() {
    _demoTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _checkNewClaims();
    });
    // ← Poll for admin policy changes every 30 seconds
    _policyTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadPolicy();
    });
  }

  Future<void> _fireDemoTrigger() async {
    if (!mounted) return;
    final pick = _demos[Random().nextInt(_demos.length)];
    final zone = policy?['zone'] as String? ?? 'Koramangala';

    Map<String, dynamic> triggerData = {
      'trigger_type': pick['type'],
      'severity':     pick['severity'],
      'zone':         zone,
      'label':        pick['label'],
      'icon':         pick['icon'],
      'value':        pick['value'],
      'worker_id':    widget.workerId,
      'amount':       _payoutForSeverity(pick['severity'] as String),
    };

    // Mark trigger as fired so it won't re-run if HomeScreen is rebuilt
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('demo_trigger_fired', true);

    try {
      final res = await http.post(
        Uri.parse('$BASE_URL/demo/trigger'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'zone':      zone,
          'type':      pick['type'],
          'severity':  pick['severity'],
          'value':     pick['value'],
          'worker_id': widget.workerId, // ← tells backend which worker to claim for
        }),
      );
      if (res.statusCode == 200) {
        final body = json.decode(res.body) as Map<String, dynamic>;
        // Merge real claim data from backend response
        triggerData = {
          ...triggerData,
          if (body['claim'] != null)
            'amount': (body['claim'] as Map)['amount'] ?? triggerData['amount'],
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
        triggerCount: _triggerCount,
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
        triggerCount: _triggerCount,
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
