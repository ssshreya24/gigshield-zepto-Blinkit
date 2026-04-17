// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

const String BASE_URL = 'http://127.0.0.1:3000';

class ApiService {

  // ── Health check ─────────────────────────────────────────
  static Future<bool> checkHealth() async {
    try {
      final res = await http.get(Uri.parse('$BASE_URL/health'));
      return res.statusCode == 200;
    } catch (_) { return false; }
  }

  // ── Sign in by phone ──────────────────────────────────────
  static Future<Map<String, dynamic>?> signIn(String phone) async {
    try {
      final res = await http.get(
        Uri.parse('$BASE_URL/signin?phone=${phone.trim()}'),
      );
      if (res.statusCode == 200) return json.decode(res.body);
      return null;
    } catch (_) { return null; }
  }

  // ── Register new worker ───────────────────────────────────
  static Future<Map<String, dynamic>> registerWorker({
    required String name,
    required String phone,
    required String zone,
    required String platform,
    required int    avgDailyIncome,
    required String planType,
    String?  email,
    double?  latitude,
    double?  longitude,
  }) async {
    try {
      final Map<String, dynamic> body = {
        'name':             name,
        'phone':            phone,
        'zone':             zone,
        'platform':         platform,
        'avg_daily_income': avgDailyIncome,
        'plan_type':        planType,
      };
      if (email     != null) body['email']     = email;
      if (latitude  != null) body['latitude']  = latitude;
      if (longitude != null) body['longitude'] = longitude;

      final res = await http.post(
        Uri.parse('$BASE_URL/register'),
        headers: {'Content-Type': 'application/json'},
        body:    json.encode(body),
      );
      return json.decode(res.body);
    } catch (e) {
      throw Exception('Registration failed. Check your connection.');
    }
  }

  // ── Get dynamic premium quote ─────────────────────────────
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

  // ── Record Premium Payment ────────────────────────────────
  static Future<Map<String, dynamic>> recordPayment({
    required int workerId,
    required int amount,
    required String planType,
    required String paymentMethod,
    required String upiId,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$BASE_URL/payments'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'worker_id': workerId,
          'amount': amount,
          'plan_type': planType,
          'payment_method': paymentMethod,
          'upi_id': upiId,
        }),
      );
      if (res.statusCode == 200) {
        return json.decode(res.body);
      }
      throw Exception('Payment recording failed.');
    } catch (_) {
      throw Exception('Cannot connect to backend.');
    }
  }

  // ── Get Worker Payments ───────────────────────────────────
  static Future<List<dynamic>> getWorkerPayments(int workerId) async {
    try {
      final res = await http.get(Uri.parse('$BASE_URL/payments/$workerId'));
      if (res.statusCode == 200) {
        return json.decode(res.body);
      }
      return [];
    } catch (_) { return []; }
  }

  // ── Get worker active policy ──────────────────────────────
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

  // ── Get worker claims ─────────────────────────────────────
  static Future<List<dynamic>> getClaims(int workerId) async {
    try {
      final res = await http.get(
        Uri.parse('$BASE_URL/claims/$workerId'));
      return json.decode(res.body);
    } catch (_) { return []; }
  }

  // ── Admin stats ───────────────────────────────────────────
  static Future<Map<String, dynamic>> getAdminStats() async {
    try {
      final res = await http.get(
        Uri.parse('$BASE_URL/admin/stats'));
      return json.decode(res.body);
    } catch (_) { return {}; }
  }

  // ── Admin claims feed ─────────────────────────────────────
  static Future<List<dynamic>> getAdminClaims() async {
    try {
      final res = await http.get(
        Uri.parse('$BASE_URL/admin/claims'));
      return json.decode(res.body);
    } catch (_) { return []; }
  }

  // ── Get active triggers ───────────────────────────────────
  static Future<List<dynamic>> getActiveTriggers(String zone) async {
    try {
      final res = await http.get(
        Uri.parse('$BASE_URL/triggers/${Uri.encodeComponent(zone)}'));
      if (res.statusCode == 200) return json.decode(res.body);
      return [];
    } catch (_) { return []; }
  }

  // ── Reverse Geocode ───────────────────────────────────────
  static Future<Map<String, dynamic>> reverseGeocode(double lat, double lon) async {
    try {
      final res = await http.get(Uri.parse('$BASE_URL/geocode/reverse?lat=$lat&lon=$lon'));
      if (res.statusCode == 200) return json.decode(res.body);
      return {};
    } catch (_) { return {}; }
  }

  // ── Search zones ──────────────────────────────────────────
  static Future<List<dynamic>> searchZones(String query) async {
    try {
      final res = await http.get(
          Uri.parse('$BASE_URL/geocode/search?q=${Uri.encodeComponent(query)}'));
      if (res.statusCode == 200) return json.decode(res.body);
      return [];
    } catch (_) { return []; }
  }

  // ── Fire demo trigger ─────────────────────────────────────
  static Future<void> fireDemoTrigger({
    required String zone,
    String type     = 'heavy_rain',
    String severity = 'T2',
    int    value    = 85,
    int?   workerId,
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
          if (workerId != null) 'worker_id': workerId,
        }),
      );
    } catch (e) {
      throw Exception('Trigger failed.');
    }
  }
  static Future<Map<String, dynamic>?> getLiveWeather(double lat, double lon, int workerId) async {
    try {
      final res = await http.get(Uri.parse('$BASE_URL/weather?lat=$lat&lon=$lon&workerId=$workerId'));
      if (res.statusCode == 200) return json.decode(res.body);
    } catch (_) {}
    return null;
  }
}
