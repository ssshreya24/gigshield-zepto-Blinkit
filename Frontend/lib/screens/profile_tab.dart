import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'welcome_screen.dart';

class ProfileTab extends StatelessWidget {
  final int workerId;
  final Map<String, dynamic>? policy;
  const ProfileTab({
    super.key,
    required this.workerId,
    this.policy,
  });

  static const bg   = Color(0xFFE8EDFF);
  static const navy = Color(0xFF1A2E6E);
  static const gold = Color(0xFFF5A623);
  static const gray = Color(0xFF7A8BB0);
  static const bdr  = Color(0xFFCDD8F6);

  // ── Logout → goes to WelcomeScreen (sign in page) ────────
  Future<void> _logout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18)),
        title: const Text('Log out?',
          style: TextStyle(
            color:      navy,
            fontWeight: FontWeight.w800)),
        content: const Text(
          'You will be taken to the sign in screen.',
          style: TextStyle(color: gray, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
              style: TextStyle(color: gray))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5252),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log out',
              style: TextStyle(
                color:      Colors.white,
                fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (ok == true && context.mounted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const WelcomeScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final name     = (policy?['name']?.toString().trim().isNotEmpty == true)
        ? policy!['name'] as String
        : 'Worker';                                   // ← safe name
    final zone     = policy?['zone']     ?? 'Your Zone';
    final platform = policy?['platform'] ?? 'Zepto';
    final plan     = (policy?['plan_type'] ?? 'standard')
      .toString().toUpperCase();

    // ── FIX: guard empty segments before [0] ─────────────
    final initials = name
      .split(' ')
      .where((e) => e.isNotEmpty)   // ← only change
      .map((e) => e[0])
      .take(2)
      .join();

    return Stack(children: [
      Positioned(top: -80, right: -60,
        child: _blob(220,
          const Color(0xFF7B9CFF).withOpacity(0.2))),
      Positioned(bottom: 100, left: -80,
        child: _blob(260,
          const Color(0xFF5B6FBE).withOpacity(0.12))),

      SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Header
              const Text('Profile',
                style: TextStyle(color: navy, fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5)),
              const Text('Your account & settings',
                style: TextStyle(color: gray, fontSize: 13)),
              const SizedBox(height: 24),

              // Avatar card
              Container(
                width:   double.infinity,
                padding: const EdgeInsets.all(24),
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
                child: Column(children: [
                  CircleAvatar(
                    backgroundColor: gold,
                    radius:          38,
                    child: Text(initials,
                      style: const TextStyle(
                        color:      Colors.white,
                        fontSize:   26,
                        fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(height: 14),
                  Text(name,
                    style: const TextStyle(
                      color:      Colors.white,
                      fontSize:   22,
                      fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('$platform · $zone',
                    style: TextStyle(
                      color:    Colors.white.withOpacity(0.55),
                      fontSize: 14)),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00C853).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                        color: const Color(0xFF00C853)
                          .withOpacity(0.4)),
                    ),
                    child: const Text('● Coverage Active',
                      style: TextStyle(
                        color:      Color(0xFF00C853),
                        fontSize:   13,
                        fontWeight: FontWeight.bold)),
                  ),
                ]),
              ),

              const SizedBox(height: 24),

              // Account info
              _label('Account Info'),
              const SizedBox(height: 10),
              _glass(child: Column(children: [
                _infoRow(Icons.badge_rounded,
                  'Worker ID', '#GS-$workerId'),
                _div(),
                _infoRow(Icons.location_on_rounded,
                  'Zone', zone),
                _div(),
                _infoRow(Icons.store_rounded,
                  'Platform', platform),
                _div(),
                _infoRow(Icons.shield_rounded,
                  'Plan', plan),
                _div(),
                _infoRow(Icons.calendar_today_rounded,
                  'Member since', 'Apr 2026'),
              ])),

              const SizedBox(height: 20),

              // Settings
              _label('Settings'),
              const SizedBox(height: 10),
              _glass(child: Column(children: [
                _settRow(context,
                  Icons.notifications_rounded,
                  'Notifications',
                  'Alerts for disruptions',
                  hasToggle: true),
                _div(),
                _settRow(context,
                  Icons.language_rounded,
                  'Language', 'English'),
                _div(),
                _settRow(context,
                  Icons.privacy_tip_rounded,
                  'Privacy Policy', 'View our policy'),
                _div(),
                _settRow(context,
                  Icons.help_rounded,
                  'Help & Support', 'Contact us'),
              ])),

              const SizedBox(height: 20),

              // App info
              _glass(child: Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: navy.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.shield_rounded,
                    color: navy, size: 22),
                ),
                const SizedBox(width: 14),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Insurify',
                      style: TextStyle(
                        color:      navy,
                        fontSize:   15,
                        fontWeight: FontWeight.w700)),
                    Text('Version 1.0.0 · DEVTrails 2026',
                      style: TextStyle(
                        color: gray, fontSize: 12)),
                  ],
                ),
              ])),

              const SizedBox(height: 20),

              // ── LOGOUT BUTTON ───────────────────────────
              GestureDetector(
                onTap: () => _logout(context),
                child: Container(
                  width:   double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFFF5252)
                        .withOpacity(0.4)),
                    boxShadow: [BoxShadow(
                      color:      const Color(0xFFFF5252)
                        .withOpacity(0.08),
                      blurRadius: 12,
                      offset:     const Offset(0, 4))],
                  ),
                  child: const Row(
                    mainAxisAlignment:
                      MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout_rounded,
                        color: Color(0xFFFF5252), size: 20),
                      SizedBox(width: 8),
                      Text('Log out',
                        style: TextStyle(
                          color:      Color(0xFFFF5252),
                          fontSize:   16,
                          fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    ]);
  }

  Widget _infoRow(IconData icon, String l, String v) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        Icon(icon, color: navy, size: 18),
        const SizedBox(width: 12),
        Text(l, style: const TextStyle(
          color: gray, fontSize: 14)),
        const Spacer(),
        Text(v, style: const TextStyle(
          color:      navy,
          fontSize:   14,
          fontWeight: FontWeight.w700)),
      ]),
    );

  Widget _settRow(BuildContext context, IconData icon,
      String title, String sub,
      {bool hasToggle = false}) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: navy.withOpacity(0.07),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: navy, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(
              color:      navy,
              fontSize:   14,
              fontWeight: FontWeight.w600)),
            Text(sub, style: const TextStyle(
              color: gray, fontSize: 12)),
          ],
        )),
        hasToggle
          ? Switch(
              value:            true,
              onChanged:        (_) {},
              activeColor:      navy,
              activeTrackColor: navy.withOpacity(0.3))
          : const Icon(Icons.chevron_right_rounded,
              color: gray, size: 20),
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
            color: Colors.white.withOpacity(0.9),
            width: 1.5),
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

  Widget _label(String t) => Text(t,
    style: const TextStyle(
      color:         gray,
      fontSize:      12,
      fontWeight:    FontWeight.w700,
      letterSpacing: 0.8));

  Widget _div() => Divider(color: bdr, height: 1);

  Widget _blob(double s, Color c) => Container(
    width: s, height: s,
    decoration: BoxDecoration(
      shape: BoxShape.circle, color: c));
}
