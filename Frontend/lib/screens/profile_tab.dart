import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'welcome_screen.dart';

class ProfileTab extends StatelessWidget {
  final int workerId;
  final Map<String, dynamic>? policy;
  const ProfileTab({super.key, required this.workerId, this.policy});

  static const bg   = Color(0xFFE8EDFF);
  static const navy = Color(0xFF1A2E6E);
  static const gold = Color(0xFFF5A623);
  static const gray = Color(0xFF7A8BB0);
  static const bdr  = Color(0xFFCDD8F6);

  Future<void> _logout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Log out?',
          style: TextStyle(color: navy, fontWeight: FontWeight.w800)),
        content: const Text('You will be taken to the sign in screen.',
          style: TextStyle(color: gray, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: gray))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5252),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log out',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => const WelcomeScreen()), (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name     = (policy?['name']?.toString().trim().isNotEmpty == true)
        ? policy!['name'] as String : 'Worker';
    final zone     = policy?['zone']     ?? 'Koramangala';
    final platform = policy?['platform'] ?? 'Zepto';
    final plan     = (policy?['plan_type'] ?? 'standard').toString().toUpperCase();
    final initials = name.split(' ').where((e) => e.isNotEmpty).map((e) => e[0]).take(2).join();

    return Stack(children: [
      Positioned(top: -80, right: -60,
        child: _blob(220, const Color(0xFF7B9CFF).withOpacity(0.2))),
      Positioned(bottom: 100, left: -80,
        child: _blob(260, const Color(0xFF5B6FBE).withOpacity(0.12))),
      SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            const Text('Profile',
              style: TextStyle(color: navy, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
            const Text('Your account & settings',
              style: TextStyle(color: gray, fontSize: 13)),
            const SizedBox(height: 24),

            // ── Avatar card ──────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [navy, Color(0xFF22387E)]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: navy.withOpacity(0.4), blurRadius: 24, offset: const Offset(0, 10))],
              ),
              child: Column(children: [
                CircleAvatar(backgroundColor: gold, radius: 38,
                  child: Text(initials,
                    style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900))),
                const SizedBox(height: 14),
                Text(name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('$platform · $zone',
                  style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 14)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C853).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: const Color(0xFF00C853).withOpacity(0.4))),
                  child: const Text('● Coverage Active',
                    style: TextStyle(color: Color(0xFF00C853), fontSize: 13, fontWeight: FontWeight.bold))),
              ]),
            ),

            const SizedBox(height: 24),

            // ── Account info ─────────────────────────────────
            _label('Account Info'),
            const SizedBox(height: 10),
            _glass(child: Column(children: [
              _infoRow(Icons.badge_rounded,         'Worker ID', '#GS-$workerId'),
              _div(),
              _infoRow(Icons.location_on_rounded,   'Zone',      zone),
              _div(),
              _infoRow(Icons.store_rounded,         'Platform',  platform),
              _div(),
              _infoRow(Icons.shield_rounded,        'Plan',      plan),
              _div(),
              _infoRow(Icons.calendar_today_rounded,'Member since','Apr 2026'),
            ])),

            const SizedBox(height: 20),

            // ── Settings ─────────────────────────────────────
            _label('Settings'),
            const SizedBox(height: 10),
            _glass(child: Column(children: [
              _settRow(
                icon:  Icons.privacy_tip_rounded,
                title: 'Privacy Policy',
                sub:   'View our data policy',
                onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const _PrivacyPolicyScreen())),
              ),
              _div(),
              _settRow(
                icon:  Icons.help_rounded,
                title: 'Help & Support',
                sub:   'Submit a query or issue',
                onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => _HelpSupportScreen(
                    workerId: workerId, workerName: name))),
              ),
            ])),

            const SizedBox(height: 20),

            // ── App info ─────────────────────────────────────
            _glass(child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: navy.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.shield_rounded, color: navy, size: 22),
              ),
              const SizedBox(width: 14),
              const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Insurify', style: TextStyle(color: navy, fontSize: 15, fontWeight: FontWeight.w700)),
                Text('Version 1.0.0 · DEVTrails 2026', style: TextStyle(color: gray, fontSize: 12)),
              ]),
            ])),

            const SizedBox(height: 20),

            // ── Logout ───────────────────────────────────────
            GestureDetector(
              onTap: () => _logout(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFF5252).withOpacity(0.4)),
                  boxShadow: [BoxShadow(
                    color: const Color(0xFFFF5252).withOpacity(0.08),
                    blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.logout_rounded, color: Color(0xFFFF5252), size: 20),
                  SizedBox(width: 8),
                  Text('Log out', style: TextStyle(
                    color: Color(0xFFFF5252), fontSize: 16, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
            const SizedBox(height: 40),
          ]),
        ),
      ),
    ]);
  }

  Widget _infoRow(IconData icon, String l, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(children: [
      Icon(icon, color: navy, size: 18),
      const SizedBox(width: 12),
      Text(l, style: const TextStyle(color: gray, fontSize: 14)),
      const Spacer(),
      Text(v, style: const TextStyle(color: navy, fontSize: 14, fontWeight: FontWeight.w700)),
    ]),
  );

  Widget _settRow({required IconData icon, required String title, required String sub, VoidCallback? onTap}) =>
    InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: navy.withOpacity(0.07), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: navy, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: navy, fontSize: 14, fontWeight: FontWeight.w600)),
            Text(sub,   style: const TextStyle(color: gray, fontSize: 12)),
          ])),
          const Icon(Icons.chevron_right_rounded, color: gray, size: 20),
        ]),
      ),
    );

  Widget _glass({required Widget child}) => ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.75),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.9), width: 1.5),
          boxShadow: [BoxShadow(
            color: const Color(0xFF7B9CFF).withOpacity(0.08),
            blurRadius: 16, offset: const Offset(0, 4))],
        ),
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    ),
  );

  Widget _label(String t) => Text(t,
    style: const TextStyle(color: gray, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8));
  Widget _div()            => Divider(color: bdr, height: 1);
  Widget _blob(double s, Color c) =>
    Container(width: s, height: s, decoration: BoxDecoration(shape: BoxShape.circle, color: c));
}

// ═══════════════════════════════════════════════════════════════
//  PRIVACY POLICY SCREEN
// ═══════════════════════════════════════════════════════════════
class _PrivacyPolicyScreen extends StatelessWidget {
  const _PrivacyPolicyScreen();

  static const navy = Color(0xFF1A2E6E);
  static const gray = Color(0xFF7A8BB0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8EDFF),
      appBar: AppBar(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Privacy Policy', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Insurify Privacy Policy',
            style: TextStyle(color: navy, fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('Last updated: April 2026',
            style: TextStyle(color: gray, fontSize: 13)),
          const SizedBox(height: 20),

          _section('1. Information We Collect',
            'We collect the following information when you register and use Insurify:\n\n'
            '• Personal details: Name, mobile number, email address.\n'
            '• Location data: Your GPS coordinates and delivery zone to enable weather-based trigger detection.\n'
            '• Platform info: Your delivery platform (e.g. Zepto, Blinkit) and work schedule.\n'
            '• Financial info: UPI ID for payout processing (never stored in plaintext).\n'
            '• Device data: Device type, app version, and crash logs for support.'),

          _section('2. How We Use Your Data',
            'Your data is used solely to:\n\n'
            '• Determine trigger eligibility (weather, zone, and activity matching).\n'
            '• Process and credit claim payouts to your UPI account.\n'
            '• Detect and prevent fraudulent claims using GPS and activity logs.\n'
            '• Send you important policy and disruption alerts.\n'
            '• Improve our service quality and risk models.'),

          _section('3. Data Sharing',
            'Insurify does NOT sell or share your personal data with third parties for marketing purposes.\n\n'
            'Data may be shared in the following limited cases:\n\n'
            '• With payment processors to execute UPI payouts.\n'
            '• With government authorities when legally required.\n'
            '• With service providers (e.g. weather APIs, AQI data sources) in anonymized form only.'),

          _section('4. Location Data',
            'Location data is used exclusively to:\n\n'
            '• Match you to your registered delivery zone.\n'
            '• Verify you were active in the zone during a weather event.\n'
            '• Detect GPS spoofing and fraudulent activity claims.\n\n'
            'We do not track your location continuously. Location is only accessed when you are active in the app.'),

          _section('5. Data Retention',
            'We retain your data for as long as your policy is active plus 12 months after termination. '
            'Claims data is retained for 5 years as required by insurance regulations. '
            'You may request deletion of non-regulatory data at any time via Help & Support.'),

          _section('6. Security',
            'We implement industry-standard security measures:\n\n'
            '• All data is encrypted in transit (TLS 1.3) and at rest (AES-256).\n'
            '• UPI IDs are stored hashed and never logged in plaintext.\n'
            '• Access to your data is restricted to authorized Insurify personnel only.'),

          _section('7. Your Rights',
            'You have the right to:\n\n'
            '• Access the personal data we hold about you.\n'
            '• Request correction of inaccurate data.\n'
            '• Request deletion of your account and associated data.\n'
            '• Withdraw consent for location tracking at any time.\n\n'
            'To exercise these rights, contact us via Help & Support in the app.'),

          _section('8. Contact',
            'For privacy-related queries:\n\n'
            '• Email: privacy@insurify.in\n'
            '• Address: DEVTrails Technologies, Koramangala, Bengaluru – 560034\n'
            '• Use the Help & Support section in the app for fastest response.'),

          const SizedBox(height: 30),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: navy.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: navy.withOpacity(0.12)),
            ),
            child: const Text(
              'By using Insurify, you agree to this Privacy Policy. We may update this policy periodically. '
              'Significant changes will be communicated via in-app notification.',
              style: TextStyle(color: navy, fontSize: 12, height: 1.6),
            ),
          ),
          const SizedBox(height: 30),
        ]),
      ),
    );
  }

  Widget _section(String title, String body) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: navy, fontSize: 16, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFCDD8F6)),
        ),
        child: Text(body, style: const TextStyle(color: Color(0xFF3A4A6B), fontSize: 13, height: 1.7)),
      ),
    ]),
  );
}

// ═══════════════════════════════════════════════════════════════
//  HELP & SUPPORT SCREEN
// ═══════════════════════════════════════════════════════════════
class _HelpSupportScreen extends StatefulWidget {
  final int    workerId;
  final String workerName;
  const _HelpSupportScreen({required this.workerId, required this.workerName});
  @override
  State<_HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<_HelpSupportScreen> {
  static const navy = Color(0xFF1A2E6E);
  static const gold = Color(0xFFF5A623);
  static const gray = Color(0xFF7A8BB0);

  final _formKey   = GlobalKey<FormState>();
  final _msgCtrl   = TextEditingController();
  String _subject  = 'General Query';
  bool   _sending  = false;
  bool   _sent     = false;

  final List<String> _subjects = [
    'General Query',
    'Claim Issue',
    'Payment Problem',
    'Policy Question',
    'Technical Bug',
    'Other',
  ];

  @override
  void dispose() { _msgCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);
    try {
      final res = await http.post(
        Uri.parse('$BASE_URL/support'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'worker_id': widget.workerId,
          'subject':   _subject,
          'message':   _msgCtrl.text.trim(),
        }),
      );
      if (res.statusCode == 200) {
        setState(() { _sent = true; _sending = false; });
      } else {
        _showError('Could not submit. Please try again.');
        setState(() => _sending = false);
      }
    } catch (_) {
      _showError('Network error. Check your connection.');
      setState(() => _sending = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8EDFF),
      appBar: AppBar(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Help & Support', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: _sent ? _successView() : _formView(),
    );
  }

  Widget _successView() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFF00C853).withOpacity(0.12),
            shape: BoxShape.circle),
          child: const Icon(Icons.check_circle_rounded,
            color: Color(0xFF00C853), size: 48),
        ),
        const SizedBox(height: 24),
        const Text('Query Submitted!',
          style: TextStyle(color: navy, fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        const Text(
          'Our support team will review your query and respond within 24 hours.\n\n'
          'Your Worker ID has been attached to the ticket so we can identify you quickly.',
          textAlign: TextAlign.center,
          style: TextStyle(color: gray, fontSize: 14, height: 1.6)),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: navy,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0),
            child: const Text('Go Back',
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
          ),
        ),
      ]),
    ),
  );

  Widget _formView() => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Form(
      key: _formKey,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Worker info banner
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: navy.withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: navy.withOpacity(0.12))),
          child: Row(children: [
            const Icon(Icons.badge_rounded, color: navy, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.workerName,
                style: const TextStyle(color: navy, fontSize: 14, fontWeight: FontWeight.w700)),
              Text('Worker ID: #GS-${widget.workerId}',
                style: const TextStyle(color: gray, fontSize: 12)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF00C853).withOpacity(0.1),
                borderRadius: BorderRadius.circular(99)),
              child: const Text('Verified',
                style: TextStyle(color: Color(0xFF00C853), fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),

        const SizedBox(height: 24),
        const Text('Subject',
          style: TextStyle(color: navy, fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFCDD8F6))),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _subject,
              isExpanded: true,
              style: const TextStyle(color: navy, fontSize: 14, fontWeight: FontWeight.w600),
              items: _subjects.map((s) =>
                DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) => setState(() => _subject = v ?? _subject),
            ),
          ),
        ),

        const SizedBox(height: 16),
        const Text('Describe your issue',
          style: TextStyle(color: navy, fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _msgCtrl,
          maxLines: 6,
          validator: (v) => (v == null || v.trim().length < 10)
            ? 'Please describe your issue in at least 10 characters.' : null,
          style: const TextStyle(color: navy, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'e.g. My claim was not processed after the heavy rain trigger on Apr 15...',
            hintStyle: TextStyle(color: gray.withOpacity(0.7), fontSize: 13),
            filled: true, fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCDD8F6))),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCDD8F6))),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: navy, width: 1.5)),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),

        const SizedBox(height: 10),
        Text('Your Worker ID (#GS-${widget.workerId}) will be automatically attached.',
          style: const TextStyle(color: gray, fontSize: 12)),

        const SizedBox(height: 24),

        // Common FAQs
        const Text('Common Questions',
          style: TextStyle(color: gray, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
        const SizedBox(height: 10),
        _faq('How long does payout take?',
          'Payouts are credited to your UPI ID within 60 seconds of trigger confirmation.'),
        _faq('Why was my claim not triggered?',
          'Claims require the weather threshold to be crossed AND you must have been active online in the past 2 hours.'),
        _faq('Can I change my plan?',
          'Plan upgrades or changes take effect from the next billing cycle. Contact support to initiate.'),

        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _sending ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: navy,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0),
            child: _sending
              ? const SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Submit Query',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(height: 40),
      ]),
    ),
  );

  Widget _faq(String q, String a) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFCDD8F6))),
    child: ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      title: Text(q, style: const TextStyle(
        color: navy, fontSize: 13, fontWeight: FontWeight.w700)),
      iconColor: navy, collapsedIconColor: gray,
      children: [Text(a, style: const TextStyle(color: gray, fontSize: 13, height: 1.5))],
    ),
  );
}
