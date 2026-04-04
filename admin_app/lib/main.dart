import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/admin_login.dart';
import 'screens/admin_home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor:          Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  final prefs   = await SharedPreferences.getInstance();
  final isAdmin = prefs.getBool('is_admin') ?? false;
  runApp(InsurifyAdminApp(isLoggedIn: isAdmin));
}

class InsurifyAdminApp extends StatelessWidget {
  final bool isLoggedIn;
  const InsurifyAdminApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title:                      'Insurify Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFF0D1829),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF1A2E6E)),
        useMaterial3: true,
      ),
      home: isLoggedIn ? const AdminHome() : const AdminLogin(),
    );
  }
}
