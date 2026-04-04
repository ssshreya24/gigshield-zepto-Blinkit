// admin_app/lib/services/admin_api.dart
// ── Insurify Admin · API Service (Updated) ──────────────────
// ADDITIONS vs original:
//   • getPlanTypes()       → GET /admin/plan-types
//   • updatePlanType()     → PUT /admin/plan-types/:id
//   • togglePlanType()     → PATCH /admin/plan-types/:id/toggle
//   • getZones()           → GET /admin/zones
//   • createTrigger()      → POST /demo/trigger (admin manual fire)
// All other methods are unchanged from original.

import 'dart:convert';
import 'package:http/http.dart' as http;

// iOS Simulator  → http://localhost:3000
// Android        → http://10.0.2.2:3000
const String BASE_URL = 'http://localhost:3000';

class AdminApi {

  // ── Auth ─────────────────────────────────────────────────
  static Future<bool> login(String email, String password) async {
    try {
      final res = await http.post(
        Uri.parse('$BASE_URL/admin/login'),
        headers: {'Content-Type': 'application/json'},
        body:    json.encode({'email': email, 'password': password}),
      );
      return res.statusCode == 200;
    } catch (_) { return false; }
  }

  // ── Stats ────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getStats() async {
    try {
      final res = await http.get(Uri.parse('$BASE_URL/admin/stats'));
      if (res.statusCode == 200) return json.decode(res.body);
      return {};
    } catch (_) { return {}; }
  }

  // ── Claims ───────────────────────────────────────────────
  static Future<List<dynamic>> getClaims() async {
    try {
      final res = await http.get(Uri.parse('$BASE_URL/admin/claims'));
      if (res.statusCode == 200) return json.decode(res.body);
      return [];
    } catch (_) { return []; }
  }

  static Future<bool> updateClaim(int claimId, String status) async {
    try {
      final res = await http.put(
        Uri.parse('$BASE_URL/admin/claim/$claimId'),
        headers: {'Content-Type': 'application/json'},
        body:    json.encode({'status': status}),
      );
      return res.statusCode == 200;
    } catch (_) { return false; }
  }

  // ── Workers ──────────────────────────────────────────────
  static Future<List<dynamic>> getWorkers() async {
    try {
      final res = await http.get(Uri.parse('$BASE_URL/admin/workers'));
      if (res.statusCode == 200) return json.decode(res.body);
      return [];
    } catch (_) { return []; }
  }

  static Future<bool> suspendWorker(int workerId) async {
    try {
      final res = await http.put(
        Uri.parse('$BASE_URL/admin/worker/$workerId/suspend'),
        headers: {'Content-Type': 'application/json'},
      );
      return res.statusCode == 200;
    } catch (_) { return false; }
  }

  // ── Individual worker policy ─────────────────────────────
  static Future<bool> updatePolicy({
    required int    policyId,
    required String planType,
    required int    weeklyPremium,
    required int    maxPayout,
    required bool   active,
  }) async {
    try {
      final res = await http.put(
        Uri.parse('$BASE_URL/admin/policy/$policyId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'plan_type':      planType,
          'weekly_premium': weeklyPremium,
          'max_payout':     maxPayout,
          'active':         active,
        }),
      );
      return res.statusCode == 200;
    } catch (_) { return false; }
  }

  // ── Triggers ─────────────────────────────────────────────
  static Future<List<dynamic>> getTriggers() async {
    try {
      final res = await http.get(Uri.parse('$BASE_URL/admin/triggers'));
      if (res.statusCode == 200) return json.decode(res.body);
      return [];
    } catch (_) { return []; }
  }

  /// Fire a demo trigger from admin (manual)
  static Future<Map<String, dynamic>?> fireTrigger({
    required String zone,
    required String type,
    required String severity,
    int value = 60,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$BASE_URL/demo/trigger'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'zone': zone, 'type': type,
          'severity': severity, 'value': value,
        }),
      );
      if (res.statusCode == 200) return json.decode(res.body);
      return null;
    } catch (_) { return null; }
  }

  // ── Plan Types (Global Catalogue) ────────────────────────
  // NEW — calls /admin/plan-types

  /// GET /admin/plan-types → all 3 plan definitions
  static Future<List<dynamic>> getPlanTypes() async {
    try {
      final res = await http.get(Uri.parse('$BASE_URL/admin/plan-types'));
      if (res.statusCode == 200) return json.decode(res.body);
      return _fallbackPlans;
    } catch (_) { return _fallbackPlans; }
  }

  /// PUT /admin/plan-types/:id → update premium / payout / active
  static Future<bool> updatePlanType({
    required int  id,
    required int  weeklyPremium,
    required int  maxPayout,
    required bool isActive,
  }) async {
    try {
      final res = await http.put(
        Uri.parse('$BASE_URL/admin/plan-types/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'weekly_premium': weeklyPremium,
          'max_payout':     maxPayout,
          'is_active':      isActive,
        }),
      );
      return res.statusCode == 200;
    } catch (_) { return false; }
  }

  /// PATCH /admin/plan-types/:id/toggle → flip is_active
  static Future<bool> togglePlanType(int id, bool currentState) async {
    try {
      final res = await http.patch(
        Uri.parse('$BASE_URL/admin/plan-types/$id/toggle'),
        headers: {'Content-Type': 'application/json'},
        body:    json.encode({'current': currentState}),
      );
      return res.statusCode == 200;
    } catch (_) { return false; }
  }

  // ── Zones ────────────────────────────────────────────────
  // NEW — calls /admin/zones

  /// GET /admin/zones → live active-trigger counts per zone
  static Future<List<dynamic>> getZones() async {
    try {
      final res = await http.get(Uri.parse('$BASE_URL/admin/zones'));
      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        return body['zones'] as List<dynamic>;
      }
      return [];
    } catch (_) { return []; }
  }

  // ── Fallback seed data ────────────────────────────────────
  static const _fallbackPlans = [
    {
      'id': 1, 'name': 'Basic', 'plan_key': 'basic',
      'weekly_premium': 29, 'max_payout': 500, 'is_active': true,
      'triggers_json': ['heavy_rain', 'extreme_heat'],
    },
    {
      'id': 2, 'name': 'Standard', 'plan_key': 'standard',
      'weekly_premium': 49, 'max_payout': 900, 'is_active': true,
      'triggers_json': ['heavy_rain','extreme_heat','flood_alert','severe_aqi'],
    },
    {
      'id': 3, 'name': 'Pro', 'plan_key': 'pro',
      'weekly_premium': 79, 'max_payout': 1500, 'is_active': true,
      'triggers_json': ['heavy_rain','extreme_heat','flood_alert',
                        'severe_aqi','curfew','cyclone'],
    },
  ];
}
