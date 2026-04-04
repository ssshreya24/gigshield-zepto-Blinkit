import 'dart:async';
import 'package:flutter/material.dart';
import '../services/admin_api.dart';
import 'policy_manage_screen.dart';

class WorkersTab extends StatefulWidget {
  const WorkersTab({super.key});
  @override
  State<WorkersTab> createState() => _WorkersTabState();
}

class _WorkersTabState extends State<WorkersTab> {
  static const bg   = Color(0xFF0D1829);
  static const gold = Color(0xFFF5A623);
  static const gray = Color(0xFF7A8BB0);
  static const bdr  = Color(0xFF1E2E45);

  List<dynamic> workers = [];
  bool          loading = true;
  String        search  = '';
  Timer?        _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(
      const Duration(seconds: 15), (_) => _load());
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  Future<void> _load() async {
    final w = await AdminApi.getWorkers();
    if (mounted) setState(() { workers = w; loading = false; });
  }

  List<dynamic> get filtered {
    if (search.isEmpty) return workers;
    return workers.where((w) =>
      (w['name']     as String? ?? '')
        .toLowerCase().contains(search.toLowerCase()) ||
      (w['zone']     as String? ?? '')
        .toLowerCase().contains(search.toLowerCase()) ||
      (w['platform'] as String? ?? '')
        .toLowerCase().contains(search.toLowerCase())
    ).toList();
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    _header(),
    _searchBar(),
    Expanded(
      child: loading
        ? const Center(
            child: CircularProgressIndicator(color: gold))
        : RefreshIndicator(
            onRefresh: _load, color: gold,
            child: filtered.isEmpty
              ? _empty()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    20, 8, 20, 100),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) =>
                    _workerCard(filtered[i]))),
    ),
  ]);

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Workers',
          style: TextStyle(color: Colors.white,
            fontSize: 24, fontWeight: FontWeight.w900)),
        Text('${workers.length} registered',
          style: const TextStyle(color: gray, fontSize: 13)),
      ]),
      GestureDetector(
        onTap: _load,
        child: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white.withOpacity(0.08))),
          child: const Icon(Icons.refresh_rounded,
            color: Colors.white, size: 18)),
      ),
    ]),
  );

  Widget _searchBar() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: bdr)),
      padding: const EdgeInsets.symmetric(
        horizontal: 14, vertical: 4),
      child: Row(children: [
        const Icon(Icons.search_rounded, color: gray, size: 20),
        const SizedBox(width: 10),
        Expanded(child: TextField(
          style: const TextStyle(
            color: Colors.white, fontSize: 14),
          decoration: const InputDecoration(
            hintText:       'Search name, zone, platform...',
            hintStyle:      TextStyle(color: Colors.white24),
            border:         InputBorder.none,
            isDense:        true,
            contentPadding: EdgeInsets.symmetric(vertical: 12)),
          onChanged: (v) => setState(() => search = v),
        )),
      ]),
    ),
  );

  Widget _workerCard(Map<String, dynamic> w) {
    final active = w['active'] ?? true;
    final plan   = (w['plan_type'] ?? 'standard').toString();
    final Color planColor = plan == 'pro'
      ? const Color(0xFF9C6FFF)
      : plan == 'standard'
        ? const Color(0xFF4B9FFF)
        : const Color(0xFF00C853);

    return GestureDetector(
      onTap: () async {
        final changed = await Navigator.push<bool>(context,
          MaterialPageRoute(
            builder: (_) =>
              PolicyManageScreen(worker: w)));
        if (changed == true) _load();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(
            active ? 0.05 : 0.02),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active
              ? bdr
              : const Color(0xFFFF5252).withOpacity(0.2))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: planColor.withOpacity(0.15),
              child: Text(
                (w['name'] as String? ?? 'W')
                  .split(' ')
                  .map((e) => e.isNotEmpty ? e[0] : '')
                  .take(2).join(),
                style: TextStyle(color: planColor,
                  fontSize: 13, fontWeight: FontWeight.w900))),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text(
                    w['name'] as String? ?? 'Worker',
                    style: TextStyle(
                      color:      active
                        ? Colors.white : Colors.white38,
                      fontSize:   14,
                      fontWeight: FontWeight.w700))),
                  if (!active)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5252)
                          .withOpacity(0.12),
                        borderRadius: BorderRadius.circular(99)),
                      child: const Text('SUSPENDED',
                        style: TextStyle(
                          color:      Color(0xFFFF5252),
                          fontSize:   8,
                          fontWeight: FontWeight.bold))),
                ]),
                const SizedBox(height: 2),
                Text(
                  '${w['zone'] ?? ''} · ${w['platform'] ?? ''}',
                  style: const TextStyle(
                    color: gray, fontSize: 11)),
                const SizedBox(height: 4),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: planColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(99)),
                    child: Text(plan.toUpperCase(),
                      style: TextStyle(color: planColor,
                        fontSize: 9, fontWeight: FontWeight.bold))),
                  const SizedBox(width: 8),
                  Text('₹${w['weekly_premium'] ?? 49}/wk',
                    style: const TextStyle(
                      color:      gold,
                      fontSize:   11,
                      fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Text('Max ₹${w['max_payout'] ?? 900}',
                    style: const TextStyle(
                      color: gray, fontSize: 11)),
                ]),
              ],
            )),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color:        gold.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border:       Border.all(
                  color: gold.withOpacity(0.25))),
              child: const Text('Manage',
                style: TextStyle(color: gold, fontSize: 12,
                  fontWeight: FontWeight.w700))),
          ]),
        ),
      ),
    );
  }

  Widget _empty() => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Icon(Icons.people_outline_rounded,
        color: Colors.white24, size: 48),
      const SizedBox(height: 12),
      Text(
        search.isEmpty ? 'No workers yet' : 'No results',
        style: const TextStyle(
          color: Colors.white38, fontSize: 16)),
    ],
  ));
}
