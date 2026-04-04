import 'dart:convert';
import 'package:http/http.dart' as http;

// Android Emulator  → http://10.0.2.2:3000
// iOS Simulator     → http://localhost:3000
// Real device       → http://YOUR_MAC_IP:3000
const String BASE_URL = 'http://localhost:3000';

class ApiService {

  // ── Health check ─────────────────────────────────────────
  static Future<bool> checkHealth() async {
    try {
      final res = await http.get(Uri.parse('$BASE_URL/health'));
      return res.statusCode == 200;
    } catch (_) { return false; }
  }

  // ── Sign in by phone ─────────────────────────────────────
  static Future<Map<String, dynamic>?> signIn(String phone) async {
    try {
      final res = await http.get(
        Uri.parse('$BASE_URL/signin?phone=${phone.trim()}'),
      );
      if (res.statusCode == 200) return json.decode(res.body);
      return null;
    } catch (_) { return null; }
  }

  // ── Register new worker ──────────────────────────────────
  static Future<Map<String, dynamic>> registerWorker({
    required String name,
    required String phone,
    required String zone,
    required String platform,
    required int    avgDailyIncome,
    required String planType,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$BASE_URL/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'name':             name,
          'phone':            phone,
          'zone':             zone,
          'platform':         platform,
          'avg_daily_income': avgDailyIncome,
          'plan_type':        planType,
        }),
      );
      return json.decode(res.body);
    } catch (e) {
      throw Exception('Registration failed. Check your connection.');
    }
  }

  // ── Get dynamic premium quote ────────────────────────────
  static Future<Map<String, dynamic>> getPremium({
    required String zone,
    required String planType,
    int tenureWeeks = 1,
    int weatherRisk = 30,
  }) async {
    try {
      final uri = Uri.parse(
        '$BASE_URL/premium'
        '?zone=${Uri.encodeComponent(zone)}'
        '&plan_type=$planType'
        '&tenure_weeks=$tenureWeeks'
        '&weather_risk=$weatherRisk'
      );
      final res = await http.get(uri);
      return json.decode(res.body);
    } catch (e) {
      throw Exception('Cannot connect to backend.');
    }
  }

  // ── Get worker active policy ─────────────────────────────
  static Future<Map<String, dynamic>?> getPolicy(int workerId) async {
    try {
      final res = await http.get(
        Uri.parse('$BASE_URL/policy/$workerId'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        return data;
      }
      return null;
    } catch (_) { return null; }
  }

  // ── Get worker claims ────────────────────────────────────
  static Future<List<dynamic>> getClaims(int workerId) async {
    try {
      final res = await http.get(
        Uri.parse('$BASE_URL/claims/$workerId'));
      return json.decode(res.body);
    } catch (_) { return []; }
  }

  // ── Admin stats ──────────────────────────────────────────
  static Future<Map<String, dynamic>> getAdminStats() async {
    try {
      final res = await http.get(
        Uri.parse('$BASE_URL/admin/stats'));
      return json.decode(res.body);
    } catch (_) { return {}; }
  }

  // ── Admin claims feed ────────────────────────────────────
  static Future<List<dynamic>> getAdminClaims() async {
    try {
      final res = await http.get(
        Uri.parse('$BASE_URL/admin/claims'));
      return json.decode(res.body);
    } catch (_) { return []; }
  }

  // ── Get active triggers ──────────────────────────────────
  static Future<List<dynamic>> getActiveTriggers(String zone) async {
    try {
      final res = await http.get(
        Uri.parse('$BASE_URL/triggers/${Uri.encodeComponent(zone)}'));
      if (res.statusCode == 200) return json.decode(res.body);
      return [];
    } catch (_) { return []; }
  }

  // ── Fire demo trigger ────────────────────────────────────
  static Future<void> fireDemoTrigger({
    required String zone,
    String type     = 'heavy_rain',
    String severity = 'T2',
    int    value    = 85,
  }) async {
    try {
      await http.post(
        Uri.parse('$BASE_URL/demo/trigger'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'zone':     zone,
          'type':     type,
          'severity': severity,
          'value':    value,
        }),
      );
    } catch (e) {
      throw Exception('Trigger failed.');
    }
  }
}
