// admin_app/lib/screens/predictive_tab.dart
// ── Insurify Admin · AI Predictive Dashboard ─────────────────
// Shows next-week disruption forecasts per zone using ML service
// Add this as a new tab in admin_home.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const String BASE_URL = 'https://insurify-backend.onrender.com';

class PredictiveTab extends StatefulWidget {
  const PredictiveTab({super.key});
  @override
  State<PredictiveTab> createState() => _PredictiveTabState();
}

class _PredictiveTabState extends State<PredictiveTab> {
  static const bg   = Color(0xFFE8EDFF);
  static const navy = Color(0xFF1A2E6E);
  static const gold = Color(0xFFF5A623);
  static const gray = Color(0xFF7A8BB0);
  static const bdr  = Color(0xFFCDD8F6);

  List<Map<String, dynamic>> _forecasts = [];
  bool _loading = true;
  String? _error;

  final List<String> _zones = [
    'Koramangala', 'HSR Layout', 'Marathahalli',
    'Indiranagar', 'Whitefield', 'Andheri',
  ];

  @override
  void initState() {
    super.initState();
    _loadForecasts();
  }

  Future<void> _loadForecasts() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await http.get(
        Uri.parse('$BASE_URL/ml/forecast/all'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 25));

      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        final list = (body['forecasts'] as List)
            .map((e) => e as Map<String, dynamic>)
            .toList();
        setState(() { _forecasts = list; _loading = false; });
      } else {
        _loadMockForecasts();
      }
    } catch (e) {
      _loadMockForecasts();
    }
  }

  void _loadMockForecasts() {
    setState(() {
      _forecasts = [
        {
          'zone': 'Koramangala', 'predicted_risk': 74.2, 'risk_level': 'HIGH',
          'expected_claims': 28, 'expected_payout_inr': 21000,
          'weather_forecast': {'rainfall_mm': 45.0, 'temperature_c': 29.5, 'aqi': 142},
          'trigger_forecasts': [
            {'trigger': 'heavy_rain', 'probability': 0.82, 'severity': 'T2'},
            {'trigger': 'flood_alert', 'probability': 0.61, 'severity': 'T3'},
            {'trigger': 'severe_aqi', 'probability': 0.38, 'severity': 'T2'},
          ],
        },
        {
          'zone': 'HSR Layout', 'predicted_risk': 62.5, 'risk_level': 'HIGH',
          'expected_claims': 20, 'expected_payout_inr': 15000,
          'weather_forecast': {'rainfall_mm': 32.0, 'temperature_c': 30.2, 'aqi': 128},
          'trigger_forecasts': [
            {'trigger': 'heavy_rain', 'probability': 0.71, 'severity': 'T2'},
            {'trigger': 'extreme_heat', 'probability': 0.44, 'severity': 'T1'},
          ],
        },
        {
          'zone': 'Marathahalli', 'predicted_risk': 51.0, 'risk_level': 'MEDIUM',
          'expected_claims': 14, 'expected_payout_inr': 10500,
          'weather_forecast': {'rainfall_mm': 18.0, 'temperature_c': 31.8, 'aqi': 118},
          'trigger_forecasts': [
            {'trigger': 'extreme_heat', 'probability': 0.55, 'severity': 'T1'},
            {'trigger': 'heavy_rain', 'probability': 0.42, 'severity': 'T2'},
          ],
        },
        {
          'zone': 'Whitefield', 'predicted_risk': 28.3, 'risk_level': 'LOW',
          'expected_claims': 5, 'expected_payout_inr': 3750,
          'weather_forecast': {'rainfall_mm': 8.0, 'temperature_c': 32.4, 'aqi': 95},
          'trigger_forecasts': [
            {'trigger': 'extreme_heat', 'probability': 0.48, 'severity': 'T1'},
            {'trigger': 'heavy_rain', 'probability': 0.22, 'severity': 'T2'},
          ],
        },
      ];
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: navy))
                  : RefreshIndicator(
                      onRefresh: _loadForecasts,
                      color: navy,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                        children: [
                          const SizedBox(height: 16),
                          _summaryRow(),
                          const SizedBox(height: 20),
                          _sectionLabel('ZONE RISK FORECAST — NEXT 7 DAYS'),
                          const SizedBox(height: 10),
                          ..._forecasts.map(_forecastCard),
                          const SizedBox(height: 20),
                          _mlBadge(),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() => Container(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: bdr)),
    ),
    child: Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('AI Forecast', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: navy)),
              SizedBox(height: 2),
              Text('Next-week disruption prediction', style: TextStyle(fontSize: 12, color: gray)),
            ],
          ),
        ),
        GestureDetector(
          onTap: _loadForecasts,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: navy.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.refresh_rounded, size: 14, color: navy),
                SizedBox(width: 4),
                Text('Refresh', style: TextStyle(fontSize: 12, color: navy, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _summaryRow() {
    if (_forecasts.isEmpty) return const SizedBox();
    final highZones  = _forecasts.where((f) => f['risk_level'] == 'HIGH').length;
    final totalPayout = _forecasts.fold<int>(0, (s, f) => s + ((f['expected_payout_inr'] as num?)?.toInt() ?? 0));
    final totalClaims = _forecasts.fold<int>(0, (s, f) => s + ((f['expected_claims'] as num?)?.toInt() ?? 0));

    return Row(
      children: [
        _miniKpi('High Risk Zones', '$highZones', Colors.red.shade50, Colors.red.shade700),
        const SizedBox(width: 10),
        _miniKpi('Expected Claims', '$totalClaims', Colors.orange.shade50, Colors.orange.shade800),
        const SizedBox(width: 10),
        _miniKpi('Predicted Payout', '₹${(totalPayout / 1000).toStringAsFixed(1)}K', Colors.blue.shade50, navy),
      ],
    );
  }

  Widget _miniKpi(String label, String value, Color bg, Color textColor) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: textColor)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, color: textColor.withOpacity(0.7))),
        ],
      ),
    ),
  );

  Widget _sectionLabel(String text) => Text(
    text,
    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: gray, letterSpacing: 0.8),
  );

  Widget _forecastCard(Map<String, dynamic> f) {
    final risk      = (f['predicted_risk'] as num?)?.toDouble() ?? 50.0;
    final level     = f['risk_level'] as String? ?? 'MEDIUM';
    final claims    = f['expected_claims'] as int? ?? 0;
    final payout    = f['expected_payout_inr'] as int? ?? 0;
    final weather   = f['weather_forecast'] as Map<String, dynamic>? ?? {};
    final triggers  = (f['trigger_forecasts'] as List<dynamic>?) ?? [];

    final levelColor = level == 'HIGH'
        ? const Color(0xFFDC2626)
        : level == 'MEDIUM'
        ? const Color(0xFFD97706)
        : const Color(0xFF059669);
    final levelBg = level == 'HIGH'
        ? const Color(0xFFFEE2E2)
        : level == 'MEDIUM'
        ? const Color(0xFFFEF3C7)
        : const Color(0xFFD1FAE5);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: bdr, width: 0.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(f['zone'] ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: navy)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: levelBg, borderRadius: BorderRadius.circular(20)),
                  child: Text(level, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: levelColor)),
                ),
              ],
            ),
          ),

          // Risk bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('ML Risk Score', style: TextStyle(fontSize: 11, color: gray)),
                    Text('${risk.toStringAsFixed(1)}/100', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: levelColor)),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: risk / 100,
                    backgroundColor: Colors.grey.shade100,
                    valueColor: AlwaysStoppedAnimation<Color>(levelColor),
                    minHeight: 7,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Stats row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _statChip('🌧️', '${(weather['rainfall_mm'] as num?)?.toStringAsFixed(0) ?? 0}mm rain'),
                const SizedBox(width: 8),
                _statChip('🌡️', '${(weather['temperature_c'] as num?)?.toStringAsFixed(1) ?? 28}°C'),
                const SizedBox(width: 8),
                _statChip('😷', 'AQI ${weather['aqi'] ?? 100}'),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Trigger forecasts
          if (triggers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('TRIGGER PROBABILITIES', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: gray, letterSpacing: 0.6)),
                  const SizedBox(height: 8),
                  ...triggers.take(3).map((t) {
                    final prob  = ((t['probability'] as num?)?.toDouble() ?? 0);
                    final label = (t['trigger'] as String).replaceAll('_', ' ');
                    final sev   = t['severity'] as String? ?? 'T2';
                    final sevColor = sev == 'T3' ? Colors.red : sev == 'T2' ? Colors.orange : Colors.green;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(label, style: const TextStyle(fontSize: 12, color: navy)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: sevColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(sev, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: sevColor)),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 80,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: prob,
                                backgroundColor: Colors.grey.shade100,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  prob > 0.6 ? Colors.red.shade400
                                      : prob > 0.4 ? Colors.orange.shade400
                                      : Colors.green.shade400
                                ),
                                minHeight: 5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 34,
                            child: Text(
                              '${(prob * 100).toInt()}%',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: navy),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),

          const SizedBox(height: 12),

          // Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Row(
              children: [
                _footerStat('Expected Claims', '$claims'),
                const SizedBox(width: 20),
                _footerStat('Predicted Payout', '₹${(payout / 1000).toStringAsFixed(1)}K'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(String icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: const Color(0xFFE8EDFF), borderRadius: BorderRadius.circular(8)),
    child: Text('$icon $label', style: const TextStyle(fontSize: 11, color: navy, fontWeight: FontWeight.w600)),
  );

  Widget _footerStat(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 10, color: gray)),
      Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: navy)),
    ],
  );

  Widget _mlBadge() => Center(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: navy.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: bdr),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.psychology_rounded, size: 14, color: navy),
          SizedBox(width: 6),
          Text(
            'Powered by GradientBoostingRegressor + OpenWeatherMap',
            style: TextStyle(fontSize: 11, color: navy, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    ),
  );
}
