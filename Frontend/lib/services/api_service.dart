import 'dart:convert';
import 'package:http/http.dart' as http;

// Configure via --dart-define=BASE_URL=http://192.168.x.x:3000
const String BASE_URL = String.fromEnvironment(
  'BASE_URL',
  defaultValue: 'http://localhost:3000',
);

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
  static Future<Map<String, dynamic>> fireDemoTrigger({
    required String zone,
    String type     = 'heavy_rain',
    String severity = 'T2',
    int    value    = 85,
    bool forceFraud = false,
    int? workerId,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$BASE_URL/demo/trigger'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'zone':        zone,
          'type':        type,
          'severity':    severity,
          'value':       value,
          'force_fraud': forceFraud,
          if (workerId != null) 'worker_id': workerId,
        }),
      );
      if (res.statusCode == 200) {
        return json.decode(res.body) as Map<String, dynamic>;
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  // ── Check real-time weather for a zone (for auto-trigger) ──
  static Future<Map<String, dynamic>> checkWeather(String zone) async {
    try {
      final res = await http.get(
        Uri.parse('$BASE_URL/api/weather-check/${Uri.encodeComponent(zone)}'));
      if (res.statusCode == 200) {
        return json.decode(res.body) as Map<String, dynamic>;
      }
      return {'disruption': false};
    } catch (_) {
      return {'disruption': false};
    }
  }

  // ── Get all zones from DB (dynamic) ───────────────────────
  static Future<List<Map<String, dynamic>>> getZones() async {
    try {
      final res = await http.get(Uri.parse('$BASE_URL/api/zones'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        return List<Map<String, dynamic>>.from(data['zones'] ?? []);
      }
      return [];
    } catch (_) { return []; }
  }

  // ── Get dynamic risk score for a zone ─────────────────────
  static Future<Map<String, dynamic>> getZoneRisk(String zone) async {
    try {
      final res = await http.get(
        Uri.parse('$BASE_URL/api/zone-risk/${Uri.encodeComponent(zone)}'));
      if (res.statusCode == 200) return json.decode(res.body);
      return {};
    } catch (_) { return {}; }
  }

  // ── Get plan types from DB ────────────────────────────────
  static Future<List<Map<String, dynamic>>> getPlans() async {
    try {
      final res = await http.get(Uri.parse('$BASE_URL/admin/plan-types'));
      if (res.statusCode == 200) {
        return List<Map<String, dynamic>>.from(json.decode(res.body));
      }
      return [];
    } catch (_) { return []; }
  }

  // ── Get admin zone risks (dynamic) ────────────────────────
  static Future<List<Map<String, dynamic>>> getAdminZoneRisks() async {
    try {
      // Fetch all zones then get risk for each
      final zones = await getZones();
      final List<Map<String, dynamic>> results = [];
      for (final z in zones) {
        final risk = await getZoneRisk(z['name'] as String);
        results.add({
          'name': z['name'],
          'score': risk['riskScore'] ?? 50,
          'level': risk['riskLevel'] ?? 'MED',
        });
      }
      return results;
    } catch (_) { return []; }
  }

  // ── Get admin active triggers (from DB) ────────────────────
  static Future<List<Map<String, dynamic>>> getAdminTriggers() async {
    try {
      final res = await http.get(Uri.parse('$BASE_URL/admin/triggers'));
      if (res.statusCode == 200) {
        return List<Map<String, dynamic>>.from(json.decode(res.body));
      }
      return [];
    } catch (_) { return []; }
  }

  // ── Send OTP to phone ─────────────────────────────────────
  static Future<void> sendOtp({required String phone}) async {
    try {
      await http.post(
        Uri.parse('$BASE_URL/otp/send'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'phone': phone}),
      );
    } catch (_) {
      // Server may not have OTP endpoint yet — silently ignore
    }
  }

  // ── Verify OTP ─────────────────────────────────────────────
  static Future<Map<String, dynamic>> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$BASE_URL/otp/verify'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'phone': phone, 'otp': otp}),
      );
      if (res.statusCode == 200) return json.decode(res.body);
      return {'success': false};
    } catch (_) {
      // Fallback for demo: accept any 6 digits when server unreachable
      if (otp.length == 6) return {'success': true};
      return {'success': false};
    }
  }

  // ── Update worker GPS location (for fraud detection) ──────
  static Future<void> updateLocation({
    required int    workerId,
    required double lat,
    required double lon,
  }) async {
    try {
      await http.post(
        Uri.parse('$BASE_URL/worker/location'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'worker_id': workerId,
          'lat':       lat,
          'lon':       lon,
        }),
      );
    } catch (_) {
      // Silent — GPS update failure shouldn't block the app
    }
  }

  // ── Get ML model info (accuracy, features, etc.) ──────────
  static Future<Map<String, dynamic>> getModelInfo() async {
    try {
      final res = await http.get(Uri.parse('$BASE_URL/api/model-info'));
      if (res.statusCode == 200) return json.decode(res.body);
      return {};
    } catch (_) { return {}; }
  }

  // ── Admin fraud dashboard ─────────────────────────────────
  static Future<Map<String, dynamic>> getFraudDashboard() async {
    try {
      final res = await http.get(Uri.parse('$BASE_URL/admin/fraud'));
      if (res.statusCode == 200) return json.decode(res.body);
      return {};
    } catch (_) { return {}; }
  }

  // ── Payment — Create Razorpay Order ───────────────────────
  static Future<Map<String, dynamic>> createPaymentOrder({
    required int    amount,
    int?    claimId,
    int?    workerId,
    String? triggerType,
    String? zone,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$BASE_URL/payment/create-order'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'amount':       amount,
          'claim_id':     claimId,
          'worker_id':    workerId,
          'trigger_type': triggerType,
          'zone':         zone,
        }),
      );
      if (res.statusCode == 200) return json.decode(res.body);
      return {'success': false};
    } catch (_) { return {'success': false}; }
  }

  // ── Payment — Verify Razorpay Signature ───────────────────
  static Future<Map<String, dynamic>> verifyPayment({
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$BASE_URL/payment/verify'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'order_id':   orderId,
          'payment_id': paymentId,
          'signature':  signature,
        }),
      );
      return json.decode(res.body);
    } catch (_) { return {'success': false}; }
  }

  // ── Payment — UPI Payout ──────────────────────────────────
  static Future<Map<String, dynamic>> initiateUpiPayout({
    required int    amount,
    required String upiId,
    required String workerName,
    int?    claimId,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$BASE_URL/payment/upi-payout'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'amount':      amount,
          'upi_id':      upiId,
          'worker_name': workerName,
          'claim_id':    claimId,
        }),
      );
      return json.decode(res.body);
    } catch (_) { return {'success': false}; }
  }

  // ── Payment — Gateway Info ────────────────────────────────
  static Future<Map<String, dynamic>> getPaymentInfo() async {
    try {
      final res = await http.get(Uri.parse('$BASE_URL/payment/info'));
      if (res.statusCode == 200) return json.decode(res.body);
      return {};
    } catch (_) { return {}; }
  }

  // ── Admin — Full Analytics (loss ratio, predictions, etc.) ─
  static Future<Map<String, dynamic>> getAnalytics() async {
    try {
      final res = await http.get(Uri.parse('$BASE_URL/admin/analytics'));
      if (res.statusCode == 200) return json.decode(res.body);
      return {};
    } catch (_) { return {}; }
  }
}
