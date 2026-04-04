// lib/screens/otp_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'home_screen.dart';

class OtpScreen extends StatefulWidget {
  final String phone;
  final bool   isLogin;
  final int?   workerId;

  const OtpScreen({
    super.key,
    required this.phone,
    this.isLogin  = false,
    this.workerId,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen>
    with SingleTickerProviderStateMixin {

  static const bg   = Color(0xFFE8EDFF);
  static const navy = Color(0xFF1A2E6E);
  static const gold = Color(0xFFF5A623);
  static const gray = Color(0xFF7A8BB0);
  static const bdr  = Color(0xFFCDD8F6);

  static const _dummyOtp = '654321';

  final List<TextEditingController> _ctrl =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _fn =
      List.generate(6, (_) => FocusNode());

  int    _seconds   = 30;
  bool   _canResend = false;
  bool   _verifying = false;
  bool   _hasError  = false;
  Timer? _timer;

  late AnimationController _shakeCtrl;
  late Animation<Offset>   _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = TweenSequence<Offset>([
      TweenSequenceItem(
          tween: Tween(begin: Offset.zero, end: const Offset(-0.06, 0)),
          weight: 1),
      TweenSequenceItem(
          tween: Tween(
              begin: const Offset(-0.06, 0), end: const Offset(0.06, 0)),
          weight: 2),
      TweenSequenceItem(
          tween: Tween(begin: const Offset(0.06, 0), end: Offset.zero),
          weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));

    _startTimer();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _fn[0].requestFocus());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _shakeCtrl.dispose();
    for (final c in _ctrl) c.dispose();
    for (final f in _fn) f.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() { _seconds = 30; _canResend = false; });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        if (_seconds > 0) {
          _seconds--;
        } else {
          _canResend = true;
          t.cancel();
        }
      });
    });
  }

  String get _entered => _ctrl.map((c) => c.text).join();

  void _onChanged(int i, String v) {
    setState(() => _hasError = false);
    if (v.length == 1 && i < 5) _fn[i + 1].requestFocus();
    if (_entered.length == 6)   _verify();
  }

  void _onKey(int i, RawKeyEvent e) {
    if (e is RawKeyDownEvent &&
        e.logicalKey == LogicalKeyboardKey.backspace &&
        _ctrl[i].text.isEmpty &&
        i > 0) {
      _ctrl[i - 1].clear();
      _fn[i - 1].requestFocus();
    }
  }

  Future<void> _verify() async {
    if (_verifying) return;
    setState(() { _verifying = true; _hasError = false; });
    await Future.delayed(const Duration(milliseconds: 850));
    if (!mounted) return;

    if (_entered == _dummyOtp) {
      if (widget.isLogin) {
        // Login flow → go directly to HomeScreen
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => HomeScreen(workerId: widget.workerId ?? 1),
          ),
          (_) => false,
        );
      } else {
        // Signup flow → return true so onboarding advances to step 2
        Navigator.pop(context, true);
      }
    } else {
      _shakeCtrl.forward(from: 0);
      setState(() { _verifying = false; _hasError = true; });
      for (final c in _ctrl) c.clear();
      await Future.delayed(const Duration(milliseconds: 50));
      if (mounted) _fn[0].requestFocus();
    }
  }

  void _resend() {
    if (!_canResend) return;
    for (final c in _ctrl) c.clear();
    setState(() => _hasError = false);
    _startTimer();
    _fn[0].requestFocus();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('OTP resent! Use 654321 for demo.'),
      backgroundColor:  navy,
      behavior:         SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin:           const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: Stack(children: [
        // Same background blobs as the rest of the app
        Positioned(top: -80, right: -60,
          child: _blob(240, const Color(0xFF7B9CFF).withOpacity(0.22))),
        Positioned(bottom: 60, left: -80,
          child: _blob(280, const Color(0xFF5B6FBE).withOpacity(0.14))),
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),

                // Back button
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color:        Colors.white.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(10),
                      border:       Border.all(color: bdr),
                    ),
                    child: const Icon(Icons.arrow_back_rounded,
                        color: navy, size: 20),
                  ),
                ),
                const SizedBox(height: 32),

                // Shield icon — same style as onboarding
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color:        navy,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(
                      color:      navy.withOpacity(0.35),
                      blurRadius: 20,
                      offset:     const Offset(0, 8),
                    )],
                  ),
                  child: const Icon(Icons.shield_rounded,
                      color: Colors.white, size: 30),
                ),
                const SizedBox(height: 22),

                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize:   34,
                      fontWeight: FontWeight.w900,
                      color:      navy,
                      height:     1.15,
                      letterSpacing: -0.5,
                    ),
                    children: [
                      TextSpan(
                        text: widget.isLogin
                            ? 'Verify\n'
                            : 'Verify your\n'),
                      const TextSpan(
                        text: 'number',
                        style: TextStyle(color: gold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                        color: gray, fontSize: 14, height: 1.5),
                    children: [
                      const TextSpan(text: 'Enter the 6-digit OTP sent to '),
                      TextSpan(
                        text: '+91 ${widget.phone}',
                        style: const TextStyle(
                            color:      navy,
                            fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // OTP boxes with shake animation
                SlideTransition(
                  position: _shakeAnim,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(6, _buildBox),
                  ),
                ),

                // Error message
                AnimatedCrossFade(
                  duration:       const Duration(milliseconds: 200),
                  crossFadeState: _hasError
                      ? CrossFadeState.showFirst
                      : CrossFadeState.showSecond,
                  firstChild: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5252).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: const Color(0xFFFF5252).withOpacity(0.3)),
                      ),
                      child: const Row(children: [
                        Icon(Icons.error_outline_rounded,
                            color: Color(0xFFFF5252), size: 15),
                        SizedBox(width: 8),
                        Text('Incorrect OTP. Please try again.',
                            style: TextStyle(
                                color: Color(0xFFFF5252), fontSize: 13)),
                      ]),
                    ),
                  ),
                  secondChild: const SizedBox.shrink(),
                ),

                const SizedBox(height: 32),

                // Resend
                Center(
                  child: _canResend
                      ? GestureDetector(
                          onTap: _resend,
                          child: const Text(
                            'Resend OTP',
                            style: TextStyle(
                              color:           navy,
                              fontWeight:      FontWeight.w700,
                              fontSize:        15,
                              decoration:      TextDecoration.underline,
                              decorationColor: navy,
                            ),
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Resend in ',
                                style: TextStyle(
                                    color: gray, fontSize: 14)),
                            Text('${_seconds}s',
                                style: const TextStyle(
                                    color:      navy,
                                    fontWeight: FontWeight.w700,
                                    fontSize:   14)),
                          ],
                        ),
                ),

                const SizedBox(height: 40),

                // Verify button — same style as _navyBtn in onboarding
                GestureDetector(
                  onTap: (_entered.length == 6 && !_verifying)
                      ? _verify
                      : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width:    double.infinity,
                    padding:  const EdgeInsets.symmetric(vertical: 17),
                    decoration: BoxDecoration(
                      color: (_entered.length == 6 && !_verifying)
                          ? navy
                          : bdr,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: (_entered.length == 6 && !_verifying)
                          ? [BoxShadow(
                              color:      navy.withOpacity(0.35),
                              blurRadius: 20,
                              offset:     const Offset(0, 8))]
                          : [],
                    ),
                    child: Center(
                      child: _verifying
                          ? const SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5))
                          : Text(
                              'Verify & Continue',
                              style: TextStyle(
                                color: (_entered.length == 6)
                                    ? Colors.white
                                    : gray,
                                fontSize:   16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Demo hint chip
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color:        gold.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(12),
                      border:       Border.all(color: gold.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text('🔑', style: TextStyle(fontSize: 15)),
                        SizedBox(width: 8),
                        Text('Demo OTP: 654321',
                            style: TextStyle(
                                color:      navy,
                                fontWeight: FontWeight.w700,
                                fontSize:   13)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildBox(int i) {
    final filled = _ctrl[i].text.isNotEmpty;
    return RawKeyboardListener(
      focusNode: FocusNode(canRequestFocus: false),
      onKey:     (e) => _onKey(i, e),
      child: SizedBox(
        width: 46, height: 58,
        child: TextField(
          controller:      _ctrl[i],
          focusNode:       _fn[i],
          textAlign:       TextAlign.center,
          keyboardType:    TextInputType.number,
          maxLength:       1,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
              fontSize: 22, fontWeight: FontWeight.w800, color: navy),
          decoration: InputDecoration(
            counterText: '',
            filled:    true,
            fillColor: filled
                ? navy.withOpacity(0.07)
                : Colors.white.withOpacity(0.8),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:   BorderSide.none),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: navy, width: 2.5)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                    color: _hasError
                        ? const Color(0xFFFF5252)
                        : (filled ? navy.withOpacity(0.3) : bdr),
                    width: 1.5)),
          ),
          onChanged: (v) => _onChanged(i, v),
        ),
      ),
    );
  }

  Widget _blob(double s, Color c) => Container(
      width: s, height: s,
      decoration: BoxDecoration(shape: BoxShape.circle, color: c));
}
