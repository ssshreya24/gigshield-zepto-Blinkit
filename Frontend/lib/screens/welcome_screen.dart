// lib/screens/welcome_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'onboarding_screen.dart';
import 'home_screen.dart';
import 'otp_screen.dart';   // ← NEW

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {

  static const bg   = Color(0xFFE8EDFF);
  static const navy = Color(0xFF1A2E6E);
  static const gold = Color(0xFFF5A623);
  static const gray = Color(0xFF7A8BB0);
  static const bdr  = Color(0xFFCDD8F6);

  bool   _showSignIn = false;
  bool   _loading    = false;
  String _error      = '';

  final _phoneCtrl = TextEditingController();

  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(
      parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  // ── Sign In → OTP flow ──────────────────────────────────
  Future<void> _signIn() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.length != 10) {
      setState(() => _error = 'Enter a valid 10-digit phone number');
      return;
    }
    setState(() { _loading = true; _error = ''; });
    try {
      final result = await ApiService.signIn(phone);
      if (result == null) {
        setState(() {
          _error   = 'Phone number not found. Please register first.';
          _loading = false;
        });
        return;
      }
      final wid   = result['id'] as int;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('worker_id', wid);

      // ── Navigate to OTP instead of HomeScreen directly ──
      if (mounted) {
        setState(() => _loading = false);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpScreen(
              phone:    phone,
              isLogin:  true,
              workerId: wid,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error   = 'Connection error. Is the backend running?';
        _loading = false;
      });
    }
  }

  void _switchToSignIn() {
    setState(() { _showSignIn = true; _error = ''; });
    _fadeCtrl.reset();
    _fadeCtrl.forward();
  }

  void _switchToWelcome() {
    setState(() { _showSignIn = false; _error = ''; });
    _fadeCtrl.reset();
    _fadeCtrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: Stack(children: [
        Positioned(top: -80, right: -60,
          child: _blob(240, const Color(0xFF7B9CFF).withOpacity(0.22))),
        Positioned(bottom: 60, left: -80,
          child: _blob(280, const Color(0xFF5B6FBE).withOpacity(0.14))),
        Positioned(top: 340, left: 80,
          child: _blob(140, gold.withOpacity(0.08))),
        SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child:   _showSignIn ? _signInView() : _welcomeView(),
          ),
        ),
      ]),
    );
  }

  Widget _welcomeView() => LayoutBuilder(
    builder: (context, constraints) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Row(children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color: navy,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [BoxShadow(
                        color:  navy.withOpacity(0.35),
                        blurRadius: 16, offset: const Offset(0, 6))],
                    ),
                    child: const Icon(Icons.shield_rounded,
                      color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Insurify',
                        style: TextStyle(color: navy, fontSize: 24,
                          fontWeight: FontWeight.w900)),
                      Text('Income Protection',
                        style: TextStyle(color: gray, fontSize: 13)),
                    ],
                  ),
                ]),

                const Spacer(),

        RichText(
          text: const TextSpan(
            style: TextStyle(
              fontSize:   36,
              fontWeight: FontWeight.w900,
              color:      navy,
              height:     1.15,
              letterSpacing: -1,
            ),
            children: [
              TextSpan(text: 'Protect your\n'),
              TextSpan(text: 'income.\n',
                style: TextStyle(color: gold)),
              TextSpan(text: 'Every week.'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Automatic payouts when disruptions stop your deliveries.\nNo claims needed — ever.',
          style: TextStyle(color: gray, fontSize: 15, height: 1.6)),

        const SizedBox(height: 40),

        Row(children: [
          _badge(Icons.bolt_rounded,   'Instant payouts'),
          const SizedBox(width: 10),
          _badge(Icons.shield_rounded, 'Zero-touch claims'),
          const SizedBox(width: 10),
          _badge(Icons.lock_rounded,   'Fraud protected'),
        ]),

        const SizedBox(height: 40),

        _navyBtn('Register — I\'m new here', () {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => const OnboardingScreen()));
        }),

        const SizedBox(height: 12),

        GestureDetector(
          onTap: _switchToSignIn,
          child: Container(
            width:   double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: bdr, width: 1.5),
            ),
            child: const Center(
              child: Text('Sign in — I already have an account',
                style: TextStyle(
                  color:      navy,
                  fontSize:   15,
                  fontWeight: FontWeight.w700)),
            ),
          ),
        ),

        const SizedBox(height: 20),
        Center(
          child: Text('For Zepto & Blinkit delivery partners',
            style: TextStyle(
              color: gray.withOpacity(0.7), fontSize: 12)),
        ),
        const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _signInView() => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),

        GestureDetector(
          onTap: _switchToWelcome,
          child: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: bdr),
            ),
            child: const Icon(Icons.arrow_back_rounded,
              color: navy, size: 20),
          ),
        ),
        const SizedBox(height: 28),

        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            color: navy,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(
              color:  navy.withOpacity(0.35),
              blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: const Icon(Icons.phone_rounded,
            color: Colors.white, size: 28),
        ),
        const SizedBox(height: 20),

        RichText(
          text: const TextSpan(
            style: TextStyle(
              fontSize: 30, fontWeight: FontWeight.w900,
              color: navy, height: 1.2),
            children: [
              TextSpan(text: 'Welcome\n'),
              TextSpan(text: 'back!',
                style: TextStyle(color: gold)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text('Enter your registered phone number to sign in.',
          style: TextStyle(color: gray, fontSize: 14, height: 1.5)),

        const SizedBox(height: 32),

        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: bdr, width: 1.5),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 4),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: navy.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('+91',
                    style: TextStyle(color: navy, fontSize: 15,
                      fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller:   _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    maxLength:    10,
                    style: const TextStyle(
                      color:         navy,
                      fontSize:      18,
                      fontWeight:    FontWeight.w600,
                      letterSpacing: 2),
                    decoration: const InputDecoration(
                      hintText:    '9999 999 999',
                      hintStyle:   TextStyle(
                        color:         Color(0xFFB0BDD8),
                        letterSpacing: 2,
                        fontSize:      18),
                      counterText: '',
                      border:      InputBorder.none,
                    ),
                    onChanged: (_) => setState(() => _error = ''),
                  ),
                ),
              ]),
            ),
          ),
        ),

        if (_error.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFF5252).withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFFFF5252).withOpacity(0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.error_outline_rounded,
                color: Color(0xFFFF5252), size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(_error,
                style: const TextStyle(
                  color: Color(0xFFFF5252), fontSize: 13))),
            ]),
          ),
        ],

        const SizedBox(height: 28),

        _navyBtn(
          _loading ? 'Signing in...' : 'Sign In →',
          _loading ? null : _signIn,
          loading: _loading,
        ),

        const SizedBox(height: 24),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: navy.withOpacity(0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: bdr),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                Icon(Icons.info_outline_rounded,
                  color: navy, size: 14),
                SizedBox(width: 6),
                Text('Test accounts — tap to fill',
                  style: TextStyle(color: navy, fontSize: 12,
                    fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 10),
              _hint('9999999901', 'Ravi Kumar',   'Your Zone'),
              _hint('9999999902', 'Priya Sharma', 'Indiranagar'),
              _hint('9999999903', 'Arjun Singh',  'Whitefield'),
            ],
          ),
        ),

        const SizedBox(height: 24),
        Center(
          child: GestureDetector(
            onTap: () => Navigator.push(context,
              MaterialPageRoute(
                builder: (_) => const OnboardingScreen())),
            child: RichText(
              text: const TextSpan(
                style: TextStyle(color: gray, fontSize: 13),
                children: [
                  TextSpan(text: 'New here? '),
                  TextSpan(text: 'Register now',
                    style: TextStyle(
                      color:      navy,
                      fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 30),
      ],
    ),
  );

  Widget _hint(String phone, String name, String zone) =>
    GestureDetector(
      onTap: () {
        _phoneCtrl.text = phone;
        setState(() => _error = '');
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.7),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: bdr),
        ),
        child: Row(children: [
          const Icon(Icons.touch_app_rounded,
            color: navy, size: 14),
          const SizedBox(width: 8),
          Text(phone,
            style: const TextStyle(color: navy, fontSize: 13,
              fontWeight: FontWeight.w700)),
          const SizedBox(width: 6),
          Text('$name · $zone',
            style: const TextStyle(color: gray, fontSize: 12)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: navy.withOpacity(0.06),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text('Tap',
              style: TextStyle(color: navy, fontSize: 10,
                fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    );

  Widget _badge(IconData icon, String label) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(
        vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.75),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: bdr),
        boxShadow: [BoxShadow(
          color:  navy.withOpacity(0.05),
          blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        Icon(icon, color: navy, size: 22),
        const SizedBox(height: 6),
        Text(label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: navy, fontSize: 10,
            fontWeight: FontWeight.w600)),
      ]),
    ),
  );

  Widget _navyBtn(String label, VoidCallback? onTap,
      {bool loading = false}) =>
    GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width:    double.infinity,
        padding:  const EdgeInsets.symmetric(vertical: 17),
        decoration: BoxDecoration(
          color: onTap != null ? navy : bdr,
          borderRadius: BorderRadius.circular(14),
          boxShadow: onTap != null ? [BoxShadow(
            color:  navy.withOpacity(0.35),
            blurRadius: 16, offset: const Offset(0, 6))] : [],
        ),
        child: Center(
          child: loading
            ? const SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2.5))
            : Text(label,
                style: TextStyle(
                  color:      onTap != null ? Colors.white : gray,
                  fontSize:   16,
                  fontWeight: FontWeight.w800)),
        ),
      ),
    );

  Widget _blob(double s, Color c) => Container(
    width: s, height: s,
    decoration: BoxDecoration(shape: BoxShape.circle, color: c));
}
