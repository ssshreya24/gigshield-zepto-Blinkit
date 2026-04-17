// admin_app/lib/screens/admin_home.dart
// ── Insurify Admin · Home (Updated with Zones Tab) ──────────
// CHANGE from original: Added ZonesTab as 4th tab (index 3)
// Add:  import 'zones_tab.dart';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dashboard_tab.dart';
import 'workers_tab.dart';
import 'claims_tab.dart';
import 'analytics_tab.dart';
import 'admin_login.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});
  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome>
    with TickerProviderStateMixin {

  static const bg   = Color(0xFF0D1829);
  static const navy = Color(0xFF1A2E6E);
  static const gold = Color(0xFFF5A623);
  static const gray = Color(0xFF7A8BB0);
  static const bdr  = Color(0xFF1E2E45);

  int _tab = 0;
  late AnimationController _tabAnim;

  // ── Tab definitions ────────────────────────────────
  final List<Map<String, dynamic>> _tabs = [
    {'label': 'Dashboard',  'icon': Icons.home_outlined,          'aicon': Icons.home_rounded},
    {'label': 'Workers',    'icon': Icons.people_outline,         'aicon': Icons.people_rounded},
    {'label': 'Claims',     'icon': Icons.receipt_long_outlined,  'aicon': Icons.receipt_long_rounded},
    {'label': 'Analytics',  'icon': Icons.bar_chart_outlined,     'aicon': Icons.bar_chart_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _tabAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 220));
    _tabAnim.forward();
  }

  @override
  void dispose() { _tabAnim.dispose(); super.dispose(); }

  void _switchTab(int i) {
    setState(() => _tab = i);
    _tabAnim.reset();
    _tabAnim.forward();
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('admin_token');
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AdminLogin()),
        (_) => false,
      );
    }
  }

  Widget _buildTab() {
    switch (_tab) {
      case 0: return DashboardTab();
      case 1: return const WorkersTab();
      case 2: return const ClaimsTab();
      case 3: return const AnalyticsTab();
      default: return DashboardTab();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: FadeTransition(opacity: _tabAnim, child: _buildTab()),
          ),
          Positioned(
              bottom: 0, left: 0, right: 0, child: _bottomNav()),
        ],
      ),
    );
  }

  Widget _bottomNav() {
    return Container(
      decoration: BoxDecoration(
        color:  const Color(0xFF0F1E30),
        border: Border(top: BorderSide(color: bdr, width: 1)),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.35),
            blurRadius: 20,
            offset:     const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(
            children: [
              ...List.generate(_tabs.length, (i) {
                final active = _tab == i;
                final item   = _tabs[i];
                return Expanded(
                  child: GestureDetector(
                    onTap: () => _switchTab(i),
                    behavior: HitTestBehavior.opaque,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding:  const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 4),
                          decoration: BoxDecoration(
                            color: active
                                ? navy.withOpacity(0.35)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                active
                                    ? item['aicon'] as IconData
                                    : item['icon'] as IconData,
                                color: active ? gold : gray,
                                size:  active ? 22 : 20,
                              ),
                              const SizedBox(height: 3),
                              Text(item['label'] as String,
                                style: TextStyle(
                                  color:      active ? gold : gray,
                                  fontSize:   9,
                                  fontWeight: active
                                      ? FontWeight.w800
                                      : FontWeight.w400,
                                )),
                              const SizedBox(height: 2),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                height: 2,
                                width:  active ? 16 : 0,
                                decoration: BoxDecoration(
                                  color:        gold,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
