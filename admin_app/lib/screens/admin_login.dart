import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/admin_api.dart';
import 'admin_home.dart';

class AdminLogin extends StatefulWidget {
  const AdminLogin({super.key});
  @override
  State<AdminLogin> createState() => _AdminLoginState();
}

class _AdminLoginState extends State<AdminLogin>
    with TickerProviderStateMixin {

  static const bg   = Color(0xFF0D1829);
  static const navy = Color(0xFF1A2E6E);
  static const gold = Color(0xFFF5A623);
  static const gray = Color(0xFF7A8BB0);

  final _emailCtrl = TextEditingController(text: 'admin@insurify.com');
  final _passCtrl  = TextEditingController();
  bool   _loading  = false;
  bool   _showPass = false;
  String _error    = '';

  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final pass  = _passCtrl.text.trim();
    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Enter email and password');
      return;
    }
    setState(() { _loading = true; _error = ''; });

    bool ok = false;
    if (email == 'admin@insurify.com' && pass == 'insurify@2026') {
      ok = true;
    } else {
      ok = await AdminApi.login(email, pass);
    }

    if (ok) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_admin', true);
      if (mounted) {
        Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const AdminHome()));
      }
    } else {
      setState(() {
        _error   = 'Invalid credentials';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: Stack(children: [
        Positioned(top: -100, right: -80,
          child: _blob(300, navy.withOpacity(0.4))),
        Positioned(bottom: -80, left: -80,
          child: _blob(280, const Color(0xFF0A3D62).withOpacity(0.3))),
        SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  // Logo
                  Row(children: [
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1A2E6E), Color(0xFF22387E)]),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(
                          color:      gold.withOpacity(0.3),
                          blurRadius: 20,
                          offset:     const Offset(0, 8))]),
                      child: const Icon(Icons.shield_rounded,
                        color: gold, size: 28),
                    ),
                    const SizedBox(width: 14),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Insurify',
                          style: TextStyle(color: Colors.white,
                            fontSize: 22, fontWeight: FontWeight.w900)),
                        Text('Admin Portal',
                          style: TextStyle(color: gold,
                            fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ]),
                  const SizedBox(height: 60),
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: Colors.white, height: 1.15),
                      children: [
                        TextSpan(text: 'Insurer\n'),
                        TextSpan(text: 'Dashboard',
                          style: TextStyle(color: gold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Restricted access — authorised only',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 13)),
                  const SizedBox(height: 40),

                  // Email
                  _fieldLabel('Email Address'),
                  const SizedBox(height: 8),
                  _inputField(
                    ctrl:     _emailCtrl,
                    hint:     'admin@insurify.com',
                    icon:     Icons.email_outlined,
                    keyboard: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 20),

                  // Password
                  _fieldLabel('Password'),
                  const SizedBox(height: 8),
                  _inputField(
                    ctrl:    _passCtrl,
                    hint:    'Enter password',
                    icon:    Icons.lock_outline_rounded,
                    obscure: !_showPass,
                    suffix: GestureDetector(
                      onTap: () => setState(() => _showPass = !_showPass),
                      child: Icon(
                        _showPass
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                        color: gray, size: 20)),
                  ),

                  if (_error.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5252).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFFF5252).withOpacity(0.3))),
                      child: Row(children: [
                        const Icon(Icons.error_outline_rounded,
                          color: Color(0xFFFF5252), size: 16),
                        const SizedBox(width: 8),
                        Text(_error,
                          style: const TextStyle(
                            color: Color(0xFFFF5252), fontSize: 13)),
                      ]),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Login button
                  GestureDetector(
                    onTap: _loading ? null : _login,
                    child: Container(
                      width:   double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [gold, Color(0xFFFFBF47)]),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(
                          color:      gold.withOpacity(0.4),
                          blurRadius: 20,
                          offset:     const Offset(0, 8))]),
                      child: Center(
                        child: _loading
                          ? const SizedBox(width: 22, height: 22,
                              child: CircularProgressIndicator(
                                color: Color(0xFF1A2E6E), strokeWidth: 2.5))
                          : const Text('Sign In to Admin',
                              style: TextStyle(color: Color(0xFF1A2E6E),
                                fontSize: 16, fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Hint card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.08))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.info_outline_rounded,
                            color: gold, size: 14),
                          const SizedBox(width: 6),
                          const Text('Demo credentials',
                            style: TextStyle(color: gold,
                              fontSize: 12, fontWeight: FontWeight.w700)),
                        ]),
                        const SizedBox(height: 8),
                        _credRow('Email',    'admin@insurify.com'),
                        _credRow('Password', 'insurify@2026'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _fieldLabel(String t) => Text(t,
    style: const TextStyle(color: Colors.white60, fontSize: 12,
      fontWeight: FontWeight.w700, letterSpacing: 0.6));

  Widget _inputField({
    required TextEditingController ctrl,
    required String   hint,
    required IconData icon,
    TextInputType keyboard = TextInputType.text,
    bool    obscure  = false,
    Widget? suffix,
  }) =>
    Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1))),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(children: [
        Icon(icon, color: const Color(0xFF7A8BB0), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller:   ctrl,
            keyboardType: keyboard,
            obscureText:  obscure,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              hintText:       hint,
              hintStyle:      const TextStyle(color: Colors.white24),
              border:         InputBorder.none,
              isDense:        true,
              contentPadding: const EdgeInsets.symmetric(vertical: 14)),
            onChanged: (_) => setState(() => _error = ''),
          ),
        ),
        if (suffix != null) suffix,
      ]),
    );

  Widget _credRow(String l, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      SizedBox(width: 60,
        child: Text(l, style: const TextStyle(
          color: Colors.white38, fontSize: 12))),
      Text(v, style: const TextStyle(
        color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
    ]),
  );

  Widget _blob(double s, Color c) => Container(
    width: s, height: s,
    decoration: BoxDecoration(shape: BoxShape.circle, color: c));
}
