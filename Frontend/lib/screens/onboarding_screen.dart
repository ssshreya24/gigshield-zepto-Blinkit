// lib/screens/onboarding_screen.dart
// ✅ OTP after step-1 Continue
// ✅ Segmented "Weekly Premium" / "Comparison" toggle
// ✅ Comparison table with tap-to-select
// ✅ Email field added after phone
// ✅ All original background, blobs, glass, colors UNCHANGED
import 'dart:ui';
import 'dart:math';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'home_screen.dart';
import 'payment_screen.dart';
import 'otp_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {

  static const bg    = Color(0xFFE8EDFF);
  static const navy  = Color(0xFF1A2E6E);
  static const navy2 = Color(0xFF22387E);
  static const gold  = Color(0xFFF5A623);
  static const gray  = Color(0xFF7A8BB0);
  static const bdr   = Color(0xFFCDD8F6);

  int    step         = 1;
  String name         = '';
  String phone        = '';
  String email        = ''; // ← NEW
  String selectedCity = '';
  String citySearch   = '';
  String zoneSearch   = '';
  String selectedState= 'Maharashtra';
  String zone         = '';
  String platform     = 'Zepto';
  int    dailyIncome  = 800;
  String planType     = 'standard';
  int    basePrem     = 49;
  int    maxPay       = 900;
  bool   loading      = false;
  bool   locLoading   = false;
  Map<String, dynamic>? premiumData;

  int _planSegment = 0; // 0 = Weekly Premium, 1 = Comparison

  // Location state
  bool    locationDetected = false;
  String  detectedAddress  = '';
  double? detectedLat;
  double? detectedLng;

  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;
  late AnimationController _pulseCtrl;
  late Animation<double>   _pulse;

  final _cityCtrl  = TextEditingController();
  final _zoneCtrl  = TextEditingController();

  Timer? _debounce;
  List<dynamic> apiZones = [];
  bool isSearchingZone = false;

  final Map<String, Map<String, dynamic>> zoneData = {
    'Koramangala':  {'lat': 12.9352, 'lng': 77.6245, 'city': 'Bengaluru', 'risk': 72},
    'Indiranagar':  {'lat': 12.9784, 'lng': 77.6408, 'city': 'Bengaluru', 'risk': 45},
    'Whitefield':   {'lat': 12.9698, 'lng': 77.7500, 'city': 'Bengaluru', 'risk': 30},
    'HSR Layout':   {'lat': 12.9116, 'lng': 77.6389, 'city': 'Bengaluru', 'risk': 65},
    'Marathahalli': {'lat': 12.9591, 'lng': 77.6974, 'city': 'Bengaluru', 'risk': 55},
    'Bellandur':    {'lat': 12.9259, 'lng': 77.6762, 'city': 'Bengaluru', 'risk': 48},
    'Jayanagar':    {'lat': 12.9308, 'lng': 77.5839, 'city': 'Bengaluru', 'risk': 40},
    'Malleshwaram': {'lat': 13.0035, 'lng': 77.5705, 'city': 'Bengaluru', 'risk': 44},
    'Hebbal':       {'lat': 13.0355, 'lng': 77.5913, 'city': 'Bengaluru', 'risk': 38},
    'Andheri':      {'lat': 19.1136, 'lng': 72.8697, 'city': 'Mumbai',    'risk': 60},
    'Bandra':       {'lat': 19.0544, 'lng': 72.8402, 'city': 'Mumbai',    'risk': 48},
    'Powai':        {'lat': 19.1176, 'lng': 72.9060, 'city': 'Mumbai',    'risk': 35},
    'Gachibowli':   {'lat': 17.4401, 'lng': 78.3489, 'city': 'Hyderabad', 'risk': 40},
    'Hitech City':  {'lat': 17.4474, 'lng': 78.3762, 'city': 'Hyderabad', 'risk': 35},
    'Koregaon Park':{'lat': 18.5362, 'lng': 73.8938, 'city': 'Pune',      'risk': 36},
    'Baner':        {'lat': 18.5590, 'lng': 73.7868, 'city': 'Pune',      'risk': 42},
    'Anna Nagar':   {'lat': 13.0850, 'lng': 80.2101, 'city': 'Chennai',   'risk': 38},
    'Velachery':    {'lat': 12.9815, 'lng': 80.2180, 'city': 'Chennai',   'risk': 55},
    'Lajpat Nagar': {'lat': 28.5700, 'lng': 77.2373, 'city': 'Delhi',     'risk': 50},
    'Dwarka':       {'lat': 28.5921, 'lng': 77.0460, 'city': 'Delhi',     'risk': 42},
  };

  final Map<String, List<String>> cityZones = {
    'Bengaluru': ['Koramangala','Indiranagar','Whitefield','HSR Layout',
      'Marathahalli','Bellandur','Jayanagar','Malleshwaram','Hebbal'],
    'Mumbai':    ['Andheri','Bandra','Powai'],
    'Hyderabad': ['Gachibowli','Hitech City'],
    'Pune':      ['Koregaon Park','Baner'],
    'Chennai':   ['Anna Nagar','Velachery'],
    'Delhi':     ['Lajpat Nagar','Dwarka'],
  };

  final List<String> indianStates = [
    'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar', 'Chhattisgarh',
    'Goa', 'Gujarat', 'Haryana', 'Himachal Pradesh', 'Jharkhand', 'Karnataka',
    'Kerala', 'Madhya Pradesh', 'Maharashtra', 'Manipur', 'Meghalaya', 'Mizoram',
    'Nagaland', 'Odisha', 'Punjab', 'Rajasthan', 'Sikkim', 'Tamil Nadu',
    'Telangana', 'Tripura', 'Uttar Pradesh', 'Uttarakhand', 'West Bengal',
    'Andaman and Nicobar', 'Chandigarh', 'Dadra and Nagar Haveli',
    'Delhi', 'Jammu and Kashmir', 'Ladakh', 'Lakshadweep', 'Puducherry'
  ];

  List<Map<String, dynamic>> plans = [
    {
      'id':    'basic',
      'label': 'Basic',
      'price': 29,
      'max':   500,
      'color': Color(0xFF4B9FFF),
      'triggers': [
        {'name': 'Heavy Rain',  'tier': 'T2', 'pct': 50,  'covered': true},
        {'name': 'Extreme Heat','tier': 'T1', 'pct': 25,  'covered': true},
        {'name': 'Flood Alert', 'tier': 'T3', 'pct': 100, 'covered': false},
        {'name': 'Curfew',      'tier': 'T3', 'pct': 100, 'covered': false},
        {'name': 'Cyclone',     'tier': 'T3', 'pct': 100, 'covered': false},
        {'name': 'Severe AQI',  'tier': 'T2', 'pct': 50,  'covered': false},
      ],
      'features': [
        'Heavy Rain + Heat Wave',
        '2 triggers covered',
        'Max ₹500 / week',
        'Basic GPS verification',
      ],
    },
    {
      'id':      'standard',
      'label':   'Standard',
      'price':   49,
      'max':     900,
      'color':   Color(0xFF1A2E6E),
      'popular': true,
      'triggers': [
        {'name': 'Heavy Rain',  'tier': 'T2', 'pct': 50,  'covered': true},
        {'name': 'Extreme Heat','tier': 'T1', 'pct': 25,  'covered': true},
        {'name': 'Flood Alert', 'tier': 'T3', 'pct': 100, 'covered': true},
        {'name': 'Severe AQI',  'tier': 'T2', 'pct': 50,  'covered': true},
        {'name': 'Curfew',      'tier': 'T3', 'pct': 100, 'covered': false},
        {'name': 'Cyclone',     'tier': 'T3', 'pct': 100, 'covered': false},
      ],
      'features': [
        'Rain, Heat, Flood, AQI',
        '4 triggers covered',
        'Max ₹900 / week',
        'GPS + fraud detection',
      ],
    },
    {
      'id':    'pro',
      'label': 'Pro',
      'price': 79,
      'max':   1500,
      'color': Color(0xFF9C6FFF),
      'triggers': [
        {'name': 'Heavy Rain',   'tier': 'T2', 'pct': 50,  'covered': true},
        {'name': 'Extreme Heat', 'tier': 'T1', 'pct': 25,  'covered': true},
        {'name': 'Flood Alert',  'tier': 'T3', 'pct': 100, 'covered': true},
        {'name': 'Severe AQI',   'tier': 'T2', 'pct': 50,  'covered': true},
        {'name': 'Curfew',       'tier': 'T3', 'pct': 100, 'covered': true},
        {'name': 'Cyclone',      'tier': 'T3', 'pct': 100, 'covered': true},
      ],
      'features': [
        'All 6 triggers covered',
        'Max ₹1500 / week',
        'Priority claim processing',
        'AI fraud shield + GPS ring',
      ],
    },
  ];

  Map<String, dynamic> get selectedPlan =>
    plans.firstWhere((p) => p['id'] == planType);

  @override
  void initState() {
    super.initState();
    _fetchLivePlans();
    _fadeCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
    _pulseCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _pulse = Tween(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _pulseCtrl.dispose();
    _cityCtrl.dispose();
    _zoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchLivePlans() async {
    try {
      final res = await http.get(Uri.parse('$BASE_URL/admin/plan-types'));
      if (res.statusCode == 200) {
        final List<dynamic> data = json.decode(res.body);
        final List<Map<String, dynamic>> newPlans = [];

        final colorMap = {
          'basic':    const Color(0xFF4B9FFF),
          'standard': const Color(0xFF1A2E6E),
          'pro':      const Color(0xFF9C6FFF),
        };

        for (final p in data) {
          if (p['is_active'] != true) continue;
          final planKey  = p['plan_key'] as String;
          final covered  = (p['triggers_json'] as List?)?.cast<String>() ?? [];
          final duration = p['duration_days'] ?? 7;

          newPlans.add({
            'id':       planKey,
            'label':    p['name'],
            'price':    p['weekly_premium'],
            'max':      p['max_payout'],
            'color':    colorMap[planKey] ?? const Color(0xFF1A2E6E),
            'popular':  planKey == 'standard',
            'duration': duration,
            'triggers': [
              {'name': 'Heavy Rain',   'tier': 'T2', 'pct': 50,  'covered': covered.contains('heavy_rain')},
              {'name': 'Extreme Heat', 'tier': 'T1', 'pct': 25,  'covered': covered.contains('extreme_heat')},
              {'name': 'Flood Alert',  'tier': 'T3', 'pct': 100, 'covered': covered.contains('flood_alert')},
              {'name': 'Severe AQI',   'tier': 'T2', 'pct': 50,  'covered': covered.contains('severe_aqi')},
              {'name': 'Curfew',       'tier': 'T3', 'pct': 100, 'covered': covered.contains('curfew')},
              {'name': 'Cyclone',      'tier': 'T3', 'pct': 100, 'covered': covered.contains('cyclone')},
              {'name': 'Storm',        'tier': 'T3', 'pct': 100, 'covered': covered.contains('storm')},
            ],
            'features': [
              '${covered.length} triggers covered',
              'Max ₹${p['max_payout']} / week',
              'GPS + fraud detection',
              'Duration: $duration days',
            ],
          });
        }

        if (newPlans.isNotEmpty && mounted) {
          setState(() {
            plans    = newPlans;
            final current = plans.firstWhere(
              (p) => p['id'] == planType,
              orElse: () => plans.first,
            );
            planType = current['id'] as String;
            basePrem = current['price'] as int;
            maxPay   = current['max']   as int;
          });
        }
      }
    } catch (e) {
      debugPrint('Failed to fetch live plans: $e');
    }
  }

  Future<void> _detectLocation() async {
    setState(() => locLoading = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showLocationError('Location services are disabled. Enable in Settings.');
        setState(() => locLoading = false); return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showLocationError('Location permission denied.');
          setState(() => locLoading = false); return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _showLocationError('Location permission permanently denied. Enable in Settings.');
        setState(() => locLoading = false); return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
      detectedLat = pos.latitude;
      detectedLng = pos.longitude;
      
      final apiResponse = await ApiService.reverseGeocode(pos.latitude, pos.longitude);
      if (apiResponse.isNotEmpty && apiResponse['area'] != null) {
        final rName = apiResponse['area'] as String;
        final rCity = apiResponse['city'] as String? ?? '';
        final rRisk = apiResponse['risk'] as int? ?? 50;
        
        // Overwrite apiZones to ensure the UI recalculates based on this exact location
        if (mounted) {
          setState(() {
             apiZones = [{'name': rName, 'city': rCity, 'risk': rRisk}];
             zone             = rName;
             selectedCity     = rCity;
             detectedAddress  = '$rName, $rCity';
             locationDetected = true;
             locLoading       = false;
             _cityCtrl.text   = rCity;
          });
        }
        recalc();
        _showLocationSuccess(rName, rCity);
      } else {
        throw Exception('Geocoding failed');
      }
    } catch (e) {
      if (mounted) setState(() => locLoading = false);
      // 🔥 Simulator Fallback (Mock location if simulator geolocation fails)
      final dummyZone = 'Dwarka Sector 21';
      final dummyCity = 'Delhi';
      if (mounted) {
        setState(() {
          apiZones = [{'name': dummyZone, 'city': dummyCity, 'risk': 42}];
          zone             = dummyZone;
          selectedCity     = dummyCity;
          detectedAddress  = '$dummyZone, $dummyCity';
          locationDetected = true;
          _cityCtrl.text   = dummyCity;
        });
      }
      recalc();
      _showLocationSuccess(dummyZone, dummyCity);
    }
  }

  double _distKm(double lat1, double lng1, double lat2, double lng2) {
    const R = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLng = _deg2rad(lng2 - lng1);
    final a = sin(dLat/2)*sin(dLat/2) +
      cos(_deg2rad(lat1))*cos(_deg2rad(lat2))*sin(dLng/2)*sin(dLng/2);
    return R * 2 * atan2(sqrt(a), sqrt(1-a));
  }

  double _deg2rad(double deg) => deg * (pi / 180);

  void _showLocationSuccess(String z, String city) {
    int r = 50;
    if (zoneData.containsKey(z)) {
      r = zoneData[z]!['risk'] as int;
    } else {
      try {
        final azObj = apiZones.firstWhere((item) => item['name'] == z);
        r = azObj['risk'] as int? ?? 50;
      } catch (_) {}
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF00C853).withOpacity(0.12),
                shape: BoxShape.circle),
              child: const Icon(Icons.location_on_rounded,
                color: Color(0xFF00C853), size: 30),
            ),
            const SizedBox(height: 14),
            const Text('Location Detected!',
              style: TextStyle(color: navy, fontSize: 20,
                fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('$z, $city',
              style: const TextStyle(color: gray, fontSize: 15)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF00C853).withOpacity(0.1),
                borderRadius: BorderRadius.circular(99)),
              child: Text(
                'Risk zone: ${_riskLevel(r)}',
                style: const TextStyle(color: Color(0xFF00C853),
                  fontSize: 13, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width:   double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: navy, borderRadius: BorderRadius.circular(12)),
                child: const Center(child: Text('Use this location',
                  style: TextStyle(color: Colors.white,
                    fontSize: 15, fontWeight: FontWeight.w700))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLocationError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: Colors.red,
      duration: const Duration(seconds: 3)));
  }

  String _riskLevel(int score) =>
    score > 60 ? 'High Risk' : score > 40 ? 'Medium Risk' : 'Low Risk';

  Color _riskColor(int score) =>
    score > 60 ? const Color(0xFFFF5252) :
    score > 40 ? gold : const Color(0xFF00C853);

  void _showStatePicker() {
    String localSearch = '';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setModalState) {
          final filtered = indianStates
              .where((s) => s.toLowerCase().contains(localSearch.toLowerCase()))
              .toList();
          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: const BoxDecoration(
              color: Color(0xFFE8EDFF),
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1A2E6E),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(99)))),
                    const SizedBox(height: 24),
                const Text('Select your state',
                  style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                const SizedBox(height: 6),
                const Text('Where do you deliver?',
                  style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500)),
                  ])), // End of Navy Header
                const SizedBox(height: 20),
                // ── Search bar + counts (fixed height, no Expanded) ───────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF333130),
                        borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          const Icon(Icons.search_rounded, color: Colors.white54, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              autofocus: false,
                              style: const TextStyle(color: Colors.white, fontSize: 15),
                              decoration: const InputDecoration(
                                hintText: 'Search any state...',
                                hintStyle: TextStyle(color: Colors.white54),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(vertical: 10),
                              ),
                              onChanged: (v) => setModalState(() => localSearch = v),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('ALL STATES — ${filtered.length}',
                      style: const TextStyle(color: gray, fontSize: 11,
                        fontWeight: FontWeight.w700, letterSpacing: 1.0)),
                    const SizedBox(height: 12),
                  ]),
                ),
                // ── GridView is a DIRECT child of outer Column via Expanded ──
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: filtered.isEmpty
                      ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.search_off_rounded, color: Color(0xFFB0BDD8), size: 40),
                          const SizedBox(height: 12),
                          Text('No state found for "$localSearch"',
                            style: const TextStyle(color: Color(0xFF7A8BB0), fontSize: 13)),
                        ]))
                      : GridView.builder(
                          padding: const EdgeInsets.only(bottom: 32),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 3.4,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final s = filtered[i];
                            final isSelected = s == selectedState;
                            return GestureDetector(
                              onTap: () {
                                if (mounted) {
                                  setState(() {
                                    selectedState = s;
                                    apiZones = [];
                                    zone = '';
                                    zoneSearch = '';
                                    _zoneCtrl.clear();
                                  });
                                }
                                Navigator.pop(ctx);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFF1A2E6E) : Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFF1A2E6E) : const Color(0xFFCDD8F6),
                                    width: 1.5)),
                                child: Row(children: [
                                  if (isSelected)
                                    const Padding(
                                      padding: EdgeInsets.only(right: 6),
                                      child: Icon(Icons.check_circle_rounded,
                                        color: Colors.white, size: 14)),
                                  Expanded(child: Text(s,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : navy,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700))),
                                ]),
                              ),
                            );
                          },
                        ),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  void recalc() {
    if (zone.isEmpty) return;
    int risk = 50;
    if (zoneData.containsKey(zone)) {
      risk = zoneData[zone]!['risk'] as int;
    } else {
      try {
        final azObj = apiZones.firstWhere((item) => item['name'] == zone);
        risk = azObj['risk'] as int? ?? 50;
      } catch (_) {
        risk = 50;
      }
    }
    final za   = ((risk / 100) * 20).round();
    final wa   = ((30 / 100) * 15).round();
    final fin  = basePrem + za + wa;
    setState(() {
      premiumData = {
        'final':   fin,  'base':    basePrem,
        'zone':    za,   'weather': wa,
        'max':     maxPay,
        'risk':    _riskLevel(risk),
        'score':   risk,
      };
    });
  }

  void selPlan(String t, int b, int m) {
    setState(() { planType = t; basePrem = b; maxPay = m; });
    recalc();
    // ── Upgrade prompt when Basic is selected ───────────────────────
    if (t == 'basic') {
      WidgetsBinding.instance.addPostFrameCallback((_) =>
          _showUpgradePrompt());
    }
  }

  void _showUpgradePrompt() {
    showModalBottomSheet(
      context:            context,
      backgroundColor:    Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF1A2E6E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(99)),
            )),
            const SizedBox(height: 20),
            Row(children: const [
              Icon(Icons.shield_rounded, color: Color(0xFFF5A623), size: 22),
              SizedBox(width: 10),
              Expanded(child: Text(
                'You selected Basic — Rain + Curfew only',
                style: TextStyle(color: Colors.white,
                  fontSize: 16, fontWeight: FontWeight.w800),
              )),
            ]),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(children: const [
                _UpgradeBenefitRow('🌡️ Extreme Heat coverage', true),
                SizedBox(height: 8),
                _UpgradeBenefitRow('😷 Severe AQI coverage', true),
                SizedBox(height: 8),
                _UpgradeBenefitRow('📅 Same 7-day duration', false),
                SizedBox(height: 8),
                _UpgradeBenefitRow('💰 Only ₹20/week more', false),
              ]),
            ),
            const SizedBox(height: 20),
            // Upgrade CTA — use live standard plan data
            Builder(builder: (ctx2) {
              final stdPlan = plans.firstWhere(
                (p) => p['id'] == 'standard',
                orElse: () => {'id': 'standard', 'price': 49, 'max': 900},
              );
              final stdPrice = stdPlan['price'] as int;
              final stdMax   = stdPlan['max']   as int;
              return SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    selPlanNoPrompt('standard', stdPrice, stdMax);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF5A623),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Text(
                    'Upgrade to Standard — ₹$stdPrice/week',
                    style: const TextStyle(color: Colors.white,
                      fontSize: 15, fontWeight: FontWeight.w800)),
                ),
              );
            }),
            const SizedBox(height: 10),
            // Keep Basic
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Keep Basic plan',
                  style: TextStyle(color: Colors.white54, fontSize: 14)),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // Upgrade without triggering the prompt loop
  void selPlanNoPrompt(String t, int b, int m) {
    setState(() { planType = t; basePrem = b; maxPay = m; });
    recalc();
  }

  List<String> get filteredZones {
    if (selectedCity.isEmpty) return [];
    final zones = cityZones[selectedCity] ?? [];
    if (zoneSearch.isEmpty) return zones;
    return zones.where((z) =>
      z.toLowerCase().contains(zoneSearch.toLowerCase())).toList();
  }

  List<String> get filteredCities => cityZones.keys
    .where((c) => citySearch.isEmpty ||
      c.toLowerCase().contains(citySearch.toLowerCase()))
    .toList();

  Future<void> activate() async {
    if (zone.isEmpty) return;
    setState(() => loading = true);
    try {
      final res = await ApiService.registerWorker(
        name:           name,
        phone:          phone,
        zone:           zone,
        platform:       platform,
        avgDailyIncome: dailyIncome,
        planType:       planType.toLowerCase(),
        latitude:       detectedLat == 0.0 ? null : detectedLat,
        longitude:      detectedLng == 0.0 ? null : detectedLng,
      );
      int? wid;
      if (res['worker'] != null && res['worker']['id'] != null) {
        wid = res['worker']['id'] as int;
      } else if (res['id'] != null) {
        wid = res['id'] as int;
      }
      if (wid == null) {
        setState(() => loading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Registration failed. Try again.'),
          backgroundColor: Colors.red));
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('worker_id', wid);
      if (mounted) {
        Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => PaymentScreen(
            workerData: res,
            planData: selectedPlan,
          )));
      }
    } catch (e) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: Stack(children: [
        Positioned(top: -80, right: -60,
          child: _blob(220, const Color(0xFF7B9CFF).withOpacity(0.2))),
        Positioned(bottom: 100, left: -80,
          child: _blob(260, const Color(0xFF5B6FBE).withOpacity(0.12))),
        SafeArea(
          child: Column(children: [
            _progressBar(),
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnim,
                child:   SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child:   step == 1 ? _step1() : _step2(),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _progressBar() => Padding(
    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
    child: Row(children: [
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value:           step == 1 ? 0.5 : 1.0,
            backgroundColor: bdr,
            valueColor:      const AlwaysStoppedAnimation(navy),
            minHeight:       4,
          ),
        ),
      ),
      const SizedBox(width: 12),
      Text('Step $step of 2',
        style: const TextStyle(color: gray, fontSize: 12,
          fontWeight: FontWeight.w600)),
    ]),
  );

  // ── STEP 1 — Name + Phone + Email + OTP ──────────────────
  Widget _step1() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 16),
      Container(
        width: 56, height: 56,
        decoration: BoxDecoration(
          color: navy,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
            color: navy.withOpacity(0.35),
            blurRadius: 20, offset: const Offset(0, 8))]),
        child: const Icon(Icons.shield_rounded, color: Colors.white, size: 30),
      ),
      const SizedBox(height: 22),
      RichText(
        text: const TextSpan(
          style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900,
            color: navy, height: 1.15, letterSpacing: -0.5),
          children: [
            TextSpan(text: 'Welcome to\n'),
            TextSpan(text: 'Insurify', style: TextStyle(color: gold)),
          ],
        ),
      ),
      const SizedBox(height: 10),
      const Text('Setup takes less than 2 minutes.',
        style: TextStyle(color: gray, fontSize: 15, height: 1.6)),
      const SizedBox(height: 32),

      // ── Fields card ──────────────────────────────────────
      _glass(child: Column(children: [
        // Name
        _field('Full Name', Icons.person_outline_rounded,
          false, 'Enter your full name',
          TextInputType.name,
          (v) => setState(() => name = v)),

        const SizedBox(height: 16),

        // Phone
        _field('Phone Number', Icons.phone_outlined,
          true, '10-digit mobile number',
          TextInputType.phone,
          (v) => setState(() => phone = v)),

        const SizedBox(height: 16),

        // ── EMAIL FIELD ──────────────────────────────────
        _field('Email Address', Icons.email_outlined,
          false, 'your@email.com (optional)',
          TextInputType.emailAddress,
          (v) => setState(() => email = v)),
      ])),

      const SizedBox(height: 32),

      // Continue → OTP → step 2
      _navyBtn('Continue →',
        name.length > 1 && phone.length == 10,
        () async {
          final verified = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => OtpScreen(phone: phone, isLogin: false)),
          );
          if (verified == true && mounted) {
            setState(() {
              step = 2;
              _fadeCtrl.reset();
              _fadeCtrl.forward();
            });
          }
        }),

      const SizedBox(height: 16),
      Center(
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: RichText(
            text: const TextSpan(
              style: TextStyle(color: gray, fontSize: 13),
              children: [
                TextSpan(text: 'Already registered? '),
                TextSpan(text: 'Sign in',
                  style: TextStyle(color: navy, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    ],
  );

  // ── STEP 2 — Zone, Platform, Income, Plan ────────────────
  Widget _step2() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 16),
      RichText(
        text: const TextSpan(
          style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900,
            color: navy, height: 1.15, letterSpacing: -0.5),
          children: [
            TextSpan(text: 'Almost\n'),
            TextSpan(text: 'done!', style: TextStyle(color: gold)),
          ],
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'Tell us about your work to get personalised coverage.',
        style: TextStyle(color: gray, fontSize: 14, height: 1.5)),
      const SizedBox(height: 24),

      // ── Location ──────────────────────────────────────
      _sectionLabel('Your Delivery Zone'),
      const SizedBox(height: 10),
      GestureDetector(
        onTap: locLoading ? null : _detectLocation,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (_, __) => Transform.scale(
            scale: locLoading ? _pulse.value : 1.0,
            child: Container(
              width:   double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: locationDetected
                  ? const Color(0xFF00C853).withOpacity(0.08)
                  : navy.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: locationDetected
                    ? const Color(0xFF00C853).withOpacity(0.4)
                    : navy.withOpacity(0.2),
                  width: 1.5),
              ),
              child: Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: locationDetected
                      ? const Color(0xFF00C853).withOpacity(0.15)
                      : navy.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12)),
                  child: locLoading
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(
                          color: navy, strokeWidth: 2.5))
                    : Icon(
                        locationDetected
                          ? Icons.my_location_rounded
                          : Icons.location_searching_rounded,
                        color: locationDetected
                          ? const Color(0xFF00C853) : navy,
                        size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      locationDetected
                        ? 'Location detected'
                        : locLoading
                          ? 'Detecting location...'
                          : 'Detect my location automatically',
                      style: TextStyle(
                        color:      locationDetected
                          ? const Color(0xFF00C853) : navy,
                        fontSize:   14,
                        fontWeight: FontWeight.w700)),
                    Text(
                      locationDetected
                        ? detectedAddress
                        : 'GPS-based · Like Blinkit / Zepto',
                      style: const TextStyle(color: gray, fontSize: 12)),
                  ],
                )),
                if (locationDetected)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00C853).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(99)),
                    child: const Text('✓ Auto',
                      style: TextStyle(color: Color(0xFF00C853),
                        fontSize: 11, fontWeight: FontWeight.bold)),
                  )
                else
                  const Icon(Icons.arrow_forward_ios_rounded,
                    color: navy, size: 14),
              ]),
            ),
          ),
        ),
      ),

      if (locLoading) ...[
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) =>
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) => Container(
                width:  8, height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: navy.withOpacity(
                    i == 0 ? _pulse.value :
                    i == 1 ? 1 - _pulse.value :
                    _pulse.value * 0.5)),
              ),
            )
          ),
        ),
      ],

      const SizedBox(height: 12),
      Row(children: [
        const Expanded(child: Divider(color: bdr)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('or search manually',
            style: const TextStyle(color: gray, fontSize: 12)),
        ),
        const Expanded(child: Divider(color: bdr)),
      ]),
      const SizedBox(height: 12),

      // Manual Location Search
      _glass(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // State Selector
          Row(children: [
            const Icon(Icons.map_outlined, color: navy, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: _showStatePicker,
                child: Container(
                  color: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(selectedState, style: const TextStyle(color: navy, fontSize: 15, fontWeight: FontWeight.w600)),
                      const Icon(Icons.keyboard_arrow_down_rounded, color: navy),
                    ],
                  ),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          const Divider(color: bdr, height: 1),
          const SizedBox(height: 8),
          
          // Locality Text Input
          Row(children: [
            const Icon(Icons.search_rounded, color: navy, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _zoneCtrl,
                style:      const TextStyle(color: navy, fontSize: 15),
                decoration: InputDecoration(
                  hintText:       'Search zone in $selectedState...',
                  hintStyle:      const TextStyle(color: Color(0xFFB0BDD8)),
                  border:         InputBorder.none,
                  isDense:        true,
                  contentPadding: EdgeInsets.zero),
                onChanged: (v) {
                  setState(() => zoneSearch = v);
                  if (_debounce?.isActive ?? false) _debounce!.cancel();
                  _debounce = Timer(const Duration(milliseconds: 600), () async {
                    if (v.trim().isEmpty) {
                      if (mounted) setState(() => apiZones = []);
                      return;
                    }
                    if (mounted) setState(() => isSearchingZone = true);
                    final results = await ApiService.searchZones('${v.trim()}, $selectedState, India');
                    if (mounted) {
                      setState(() {
                        apiZones = results;
                        isSearchingZone = false;
                      });
                    }
                  });
                },
              ),
            ),
          ]),
          const SizedBox(height: 8),
          const Divider(color: bdr, height: 1),
          const SizedBox(height: 8),
          
          if (isSearchingZone)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator(color: navy, strokeWidth: 2)),
            ),
            
          if (!isSearchingZone && apiZones.isEmpty && zoneSearch.isNotEmpty && zone.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('No localities found. Try a broader area.', style: TextStyle(color: gray, fontSize: 12)),
            ),
            
          ...apiZones.map((az) {
            final zName = az['name'] as String;
            final zState = az['state'] as String? ?? 'India';
            final risk = az['risk'] as int? ?? 50;
            final riskLvl  = _riskLevel(risk);
            final rc       = _riskColor(risk);
            final selected = zone == zName;
            
            return GestureDetector(
              onTap: () {
                setState(() {
                  zone = zName;
                  detectedLat = (az['lat'] as num?)?.toDouble() ?? 0.0;
                  detectedLng = (az['lon'] as num?)?.toDouble() ?? 0.0;
                });
                recalc();
                FocusScope.of(context).unfocus(); // Close keyboard automatically
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color:        selected ? navy : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border:       Border.all(
                    color: selected ? navy : bdr,
                    width: selected ? 1.5 : 1)),
                child: Row(children: [
                  Icon(Icons.location_on_rounded,
                    color: selected ? gold : gray, size: 16),
                  const SizedBox(width: 10),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(zName,
                        style: TextStyle(
                          color:      selected ? Colors.white : navy,
                          fontSize:   14,
                          fontWeight: FontWeight.w600)),
                      Text(selectedState,
                        style: TextStyle(
                          color: selected ? Colors.white60 : gray,
                          fontSize: 11)),
                    ],
                  )),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: selected
                        ? Colors.white.withOpacity(0.15)
                        : rc.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(99)),
                    child: Text(riskLvl,
                      style: TextStyle(
                        color:      selected ? Colors.white70 : rc,
                        fontSize:   10,
                        fontWeight: FontWeight.bold)),
                  ),
                  if (selected) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.check_circle_rounded,
                      color: gold, size: 18),
                  ],
                ]),
              ),
            );
          }),
        ],
      )),

      const SizedBox(height: 20),

      // ── Platform ──────────────────────────────────────
      _sectionLabel('Platform'),
      const SizedBox(height: 10),
      Row(children: [
        _platformBtn('Zepto',   'Z',
          const Color(0xFFF0EAFF), const Color(0xFF7B2FBE)),
        const SizedBox(width: 10),
        _platformBtn('Blinkit', 'B',
          const Color(0xFFFFF8E1), const Color(0xFFD4A000)),
      ]),

      const SizedBox(height: 20),

      // ── Income ────────────────────────────────────────
      _sectionLabel('Average Daily Income'),
      const SizedBox(height: 10),
      _glass(child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('₹$dailyIncome',
            style: const TextStyle(color: navy, fontSize: 34,
              fontWeight: FontWeight.w900)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: navy.withOpacity(0.08),
              borderRadius: BorderRadius.circular(99)),
            child: const Text('per day',
              style: TextStyle(color: navy, fontSize: 13,
                fontWeight: FontWeight.w600))),
        ]),
        const SizedBox(height: 12),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor:   navy,
            inactiveTrackColor: bdr,
            thumbColor:         navy,
            overlayColor:       navy.withOpacity(0.1),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            trackHeight: 4,
          ),
          child: Slider(
            value:     dailyIncome.toDouble(),
            min:       300, max: 1500, divisions: 24,
            onChanged: (v) => setState(() => dailyIncome = v.round()),
          ),
        ),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('₹300',   style: TextStyle(color: gray.withOpacity(0.7), fontSize: 11)),
          Text('₹1,500', style: TextStyle(color: gray.withOpacity(0.7), fontSize: 11)),
        ]),
      ])),

      const SizedBox(height: 20),

      // ── Plan Section ──────────────────────────────────
      _sectionLabel('Choose Plan'),
      const SizedBox(height: 10),
      _planSegmentControl(),
      const SizedBox(height: 12),

      if (_planSegment == 1)
        _comparisonTable()
      else ...[
        Container(
          decoration: BoxDecoration(
            color:        Colors.white.withOpacity(0.6),
            borderRadius: BorderRadius.circular(12),
            border:       Border.all(color: bdr)),
          padding: const EdgeInsets.all(4),
          child: Row(
            children: plans.map((p) {
              final active = planType == p['id'];
              return Expanded(
                child: GestureDetector(
                  onTap: () => selPlan(
                    p['id'] as String,
                    p['price'] as int,
                    p['max'] as int),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color:        active ? navy : Colors.transparent,
                      borderRadius: BorderRadius.circular(9)),
                    child: Column(children: [
                      if (p['popular'] == true && !active)
                        Container(
                          margin: const EdgeInsets.only(bottom: 2),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color:        gold.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(99)),
                          child: const Text('Popular',
                            style: TextStyle(color: gold, fontSize: 8,
                              fontWeight: FontWeight.bold))),
                      Text(p['label'] as String,
                        style: TextStyle(
                          color:      active ? Colors.white70 : gray,
                          fontSize:   11,
                          fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text('₹${p['price']}',
                        style: TextStyle(
                          color:      active ? gold : navy,
                          fontSize:   20,
                          fontWeight: FontWeight.w900)),
                      Text('/week',
                        style: TextStyle(
                          color:   active ? Colors.white38 : gray,
                          fontSize: 9)),
                    ]),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child:    _planDetailCard(selectedPlan),
        ),
      ],

      const SizedBox(height: 28),
      _navyBtn(
        loading ? 'Activating...' : 'Activate Insurify →',
        zone.isNotEmpty && !loading,
        activate,
        loading: loading,
      ),
      const SizedBox(height: 16),
      Center(
        child: GestureDetector(
          onTap: () => setState(() {
            step = 1;
            _fadeCtrl.reset();
            _fadeCtrl.forward();
          }),
          child: const Text('← Go back',
            style: TextStyle(color: navy, fontSize: 14,
              fontWeight: FontWeight.w700)),
        ),
      ),
      const SizedBox(height: 40),
    ],
  );

  // ── Segmented control ─────────────────────────────────────
  Widget _planSegmentControl() {
    const labels = ['Weekly Premium', 'Comparison'];
    return Container(
      decoration: BoxDecoration(
        color:        Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: bdr),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: List.generate(labels.length, (i) {
          final active = _planSegment == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _planSegment = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:  const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color:        active ? navy : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize:   13,
                    fontWeight: FontWeight.w700,
                    color:      active ? Colors.white : gray,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Comparison table — fully data-driven from live plans ────
  Widget _comparisonTable() {
    const planColors = [Color(0xFF4B9FFF), Color(0xFF1A2E6E), Color(0xFF9C6FFF)];

    // Build plan order from live list; fallback to known keys
    final orderedKeys = ['basic', 'standard', 'pro'];
    final activePlans = orderedKeys
      .map((k) {
        try { return plans.firstWhere((p) => p['id'] == k); }
        catch (_) { return null; }
      })
      .whereType<Map<String, dynamic>>()
      .toList();

    // Collect all unique trigger names across all plans
    final allTriggerNames = <String>{};
    for (final p in activePlans) {
      for (final t in (p['triggers'] as List)) {
        allTriggerNames.add(t['name'] as String);
      }
    }

    // Build dynamic rows: Premium + Max Payout first, then each trigger
    final List<Map<String, String>> rows = [
      {
        'label': 'Premium',
        for (final p in activePlans)
          p['id'] as String: '₹${p['price']}',
      },
      {
        'label': 'Max Payout',
        for (final p in activePlans)
          p['id'] as String: '₹${p['max']}',
      },
      ...allTriggerNames.map((tName) => {
        'label': tName,
        for (final p in activePlans)
          p['id'] as String: ((p['triggers'] as List)
            .any((t) => t['name'] == tName && t['covered'] == true))
              ? '✓' : '✗',
      }),
    ];

    return Container(
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: bdr),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(children: [
        Container(
          color: const Color(0xFFF0F3FF),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: Row(children: [
            const Expanded(flex: 3, child: Text('Feature',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                color: Color(0xFF7A8BB0)))),
            ...activePlans.asMap().entries.map((pe) {
              final i    = pe.key;
              final p    = pe.value;
              final pId  = p['id'] as String;
              return Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: () {
                    selPlan(pId, p['price'] as int, p['max'] as int);
                    setState(() => _planSegment = 0);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin:   const EdgeInsets.symmetric(horizontal: 2),
                    padding:  const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: planColors[i % planColors.length].withOpacity(
                        planType == pId ? 1.0 : 0.12),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(p['label'] as String,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize:   11,
                        fontWeight: FontWeight.w800,
                        color: planType == pId
                          ? Colors.white
                          : planColors[i % planColors.length],
                      )),
                  ),
                ),
              );
            }),
          ]),
        ),
        ...rows.asMap().entries.map((entry) {
          final isShaded = entry.key.isOdd;
          final row      = entry.value;
          return Container(
            color: isShaded ? const Color(0xFFF8F9FF) : Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
            child: Row(children: [
              Expanded(flex: 3, child: Text(row['label']!,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                  color: Color(0xFF1A2E6E)))),
              ...activePlans.asMap().entries.map((pe) {
                final i   = pe.key;
                final val = row[pe.value['id'] as String] ?? '–';
                final check = val == '✓';
                final cross = val == '✗';
                return Expanded(flex: 2, child: Center(
                  child: cross
                    ? Icon(Icons.remove_rounded, color: bdr, size: 14)
                    : check
                      ? Icon(Icons.check_circle_rounded,
                          color: planColors[i % planColors.length], size: 14)
                      : Text(val,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: planColors[i % planColors.length])),
                ));
              }),
            ]),
          );
        }),
        Padding(
          padding: const EdgeInsets.all(10),
          child: Text('Tap a column to select that plan',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: gray,
              fontStyle: FontStyle.italic)),
        ),
      ]),
    );
  }

  // ── Plan detail card ──────────────────────────────────────
  Widget _planDetailCard(Map<String, dynamic> plan) {
    final color    = plan['color'] as Color;
    final triggers = plan['triggers'] as List;
    final features = plan['features'] as List;
    final covered  = triggers.where((t) => t['covered'] == true).length;
    final total    = triggers.length;

    return Container(
      key: ValueKey(plan['id']),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: color.withOpacity(0.3), width: 1.5),
        boxShadow: [BoxShadow(
          color:      color.withOpacity(0.1),
          blurRadius: 12, offset: const Offset(0, 4))]),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.shield_rounded, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(plan['label'] as String,
                    style: const TextStyle(color: navy, fontSize: 15,
                      fontWeight: FontWeight.w800)),
                  if (plan['popular'] == true) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: gold.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: gold.withOpacity(0.3))),
                      child: const Text('Most Popular',
                        style: TextStyle(color: gold, fontSize: 9,
                          fontWeight: FontWeight.bold))),
                  ],
                ]),
                Text('$covered of $total triggers covered · Max ₹${plan['max']}/week',
                  style: const TextStyle(color: gray, fontSize: 11)),
              ],
            )),
            Text('₹${plan['price']}/wk',
              style: TextStyle(color: color, fontSize: 18,
                fontWeight: FontWeight.w900)),
          ]),
          const SizedBox(height: 14),
          const Divider(color: bdr, height: 1),
          const SizedBox(height: 12),
          const Text('Trigger Coverage',
            style: TextStyle(color: gray, fontSize: 11,
              fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          ...triggers.map((t) {
            final cov = t['covered'] as bool;
            return Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(children: [
                Container(
                  width: 20, height: 20,
                  decoration: BoxDecoration(
                    color: cov
                      ? const Color(0xFF00C853).withOpacity(0.1)
                      : const Color(0xFFFF5252).withOpacity(0.06),
                    shape: BoxShape.circle),
                  child: Icon(
                    cov ? Icons.check_rounded : Icons.close_rounded,
                    color: cov
                      ? const Color(0xFF00C853)
                      : const Color(0xFFFF5252).withOpacity(0.5),
                    size: 13),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(t['name'] as String,
                  style: TextStyle(
                    color:      cov ? navy : gray,
                    fontSize:   13,
                    fontWeight: cov ? FontWeight.w600 : FontWeight.w400,
                    decoration: cov ? null : TextDecoration.lineThrough,
                    decorationColor: gray.withOpacity(0.3)))),
                if (cov)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(99)),
                    child: Text('${t['tier']} · ${t['pct']}%',
                      style: TextStyle(color: color, fontSize: 9,
                        fontWeight: FontWeight.bold))),
              ]),
            );
          }),
          const SizedBox(height: 10),
          const Divider(color: bdr, height: 1),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6, runSpacing: 6,
            children: (features as List).map((f) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: navy.withOpacity(0.05),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: bdr)),
              child: Text(f as String,
                style: const TextStyle(color: navy, fontSize: 10,
                  fontWeight: FontWeight.w600)),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _platformBtn(String label, String letter, Color bg2, Color fg) {
    final active = platform == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => platform = label),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding:  const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color:        active ? navy : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border:       Border.all(
              color: active ? navy : bdr,
              width: active ? 1.5 : 1),
            boxShadow: active ? [BoxShadow(
              color:      navy.withOpacity(0.25),
              blurRadius: 16, offset: const Offset(0, 6))] : []),
          child: Column(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color:        active ? Colors.white.withOpacity(0.15) : bg2,
                borderRadius: BorderRadius.circular(12)),
              child: Center(child: Text(letter,
                style: TextStyle(
                  color:      active ? Colors.white : fg,
                  fontSize:   18, fontWeight: FontWeight.w900))),
            ),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(
              color:      active ? Colors.white : navy,
              fontSize:   15, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }

  Widget _navyBtn(String label, bool enabled,
      VoidCallback onTap, {bool loading = false}) =>
    GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width:    double.infinity,
        padding:  const EdgeInsets.symmetric(vertical: 17),
        decoration: BoxDecoration(
          color:        enabled ? navy : bdr,
          borderRadius: BorderRadius.circular(14),
          boxShadow: enabled ? [BoxShadow(
            color:      navy.withOpacity(0.35),
            blurRadius: 20, offset: const Offset(0, 8))] : []),
        child: Center(
          child: loading
            ? const SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2.5))
            : Text(label, style: TextStyle(
                color:      enabled ? Colors.white : gray,
                fontSize:   16, fontWeight: FontWeight.w800,
                letterSpacing: 0.3))),
      ),
    );

  // ── Updated _field with keyboardType param ────────────────
  Widget _field(String label, IconData icon, bool isNum,
      String hint, TextInputType keyboardType, Function(String) onChange) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(
        color: gray, fontSize: 12, fontWeight: FontWeight.w700,
        letterSpacing: 0.6)),
      const SizedBox(height: 8),
      TextField(
        keyboardType: keyboardType,
        maxLength:    isNum ? 10 : null,
        onChanged:    onChange,
        style: const TextStyle(color: navy, fontSize: 15),
        decoration: InputDecoration(
          hintText:    hint,
          hintStyle:   const TextStyle(color: Color(0xFFB0BDD8)),
          counterText: '',
          prefixIcon:  Icon(icon, color: gray, size: 20),
          filled:      true,
          fillColor:   Colors.white.withOpacity(0.6),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:   const BorderSide(color: bdr)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:   const BorderSide(color: bdr)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:   const BorderSide(color: navy, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14)),
      ),
    ]);

  Widget _sectionLabel(String t) => Text(t,
    style: const TextStyle(color: gray, fontSize: 12,
      fontWeight: FontWeight.w700, letterSpacing: 0.8));

  Widget _blob(double s, Color c) => Container(
    width: s, height: s,
    decoration: BoxDecoration(shape: BoxShape.circle, color: c));


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
          blurRadius: 16, offset: const Offset(0, 4))]),
      padding: const EdgeInsets.all(16),
      child:   child,
    ),
  ),
);
}

// ── Upgrade popup benefit row ──────────────────────────────────
class _UpgradeBenefitRow extends StatelessWidget {
  final String text;
  final bool   isNew;
  const _UpgradeBenefitRow(this.text, this.isNew);

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(
      width: 20, height: 20,
      decoration: BoxDecoration(
        color: isNew
          ? const Color(0xFFF5A623).withOpacity(0.15)
          : Colors.white.withOpacity(0.06),
        shape: BoxShape.circle,
      ),
      child: Icon(
        isNew ? Icons.add_rounded : Icons.check_rounded,
        size: 12,
        color: isNew ? const Color(0xFFF5A623) : Colors.white38,
      ),
    ),
    const SizedBox(width: 10),
    Expanded(child: Text(text,
      style: TextStyle(
        color:      isNew ? Colors.white : Colors.white60,
        fontSize:   13,
        fontWeight: isNew ? FontWeight.w700 : FontWeight.w500,
      ))),
  ]);
}

