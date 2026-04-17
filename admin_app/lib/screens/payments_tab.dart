import 'package:flutter/material.dart';
import '../services/admin_api.dart';
import 'package:intl/intl.dart';

class PaymentsTab extends StatefulWidget {
  const PaymentsTab({super.key});

  @override
  State<PaymentsTab> createState() => _PaymentsTabState();
}

class _PaymentsTabState extends State<PaymentsTab> {
  static const bg   = Color(0xFF0D1829);
  static const navy = Color(0xFF1E2E45);
  static const gold = Color(0xFFF5A623);
  static const gray = Color(0xFF7A8BB0);
  static const bdr  = Color(0xFF2A3A5A);

  List<dynamic> payments = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    final data = await AdminApi.getPayments();
    if (mounted) {
      setState(() { payments = data; loading = false; });
    }
  }

  String _fmtDate(String? iso) {
    if (iso == null) return 'N/A';
    try {
      final d = DateTime.parse(iso).toLocal();
      return DateFormat('MMM d, h:mm a').format(d);
    } catch (_) { return 'Invalid'; }
  }

  String _toTitleCase(String str) {
    if (str.isEmpty) return '';
    return str[0].toUpperCase() + str.substring(1).toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: bg,
      child: Column(
        children: [
          _header(),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator(color: gold))
                : payments.isEmpty
                    ? const Center(child: Text('No payments found.', style: TextStyle(color: gray)))
                    : RefreshIndicator(
                        onRefresh: _loadPayments,
                        color: gold,
                        backgroundColor: navy,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(top: 8, bottom: 80),
                          itemCount: payments.length,
                          itemBuilder: (ctx, i) {
                            final p = payments[i];
                            return _paymentCard(p);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    int totalRev = payments.isEmpty ? 0 : payments.fold(0, (sum, p) => sum + ((p['amount'] as num?)?.toInt() ?? 0));
    
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: const BoxDecoration(
        color:  navy,
        border: Border(bottom: BorderSide(color: bdr)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Payments', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              IconButton(onPressed: _loadPayments, icon: const Icon(Icons.refresh_rounded, color: gray, size: 22)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _statBox('Total Received', '₹$totalRev', Icons.account_balance_wallet_rounded, gold),
              const SizedBox(width: 12),
              _statBox('Transactions', '${payments.length}', Icons.receipt_long_rounded, Colors.blueAccent),
            ],
          )
        ],
      ),
    );
  }

  Widget _statBox(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle), child: Icon(icon, color: color, size: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: gray, fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _paymentCard(dynamic p) {
    final amt    = p['amount'] ?? 0;
    final worker = p['worker_name'] ?? 'Unknown';
    final plan   = p['plan_type'] ?? 'basic';
    final phone  = p['worker_phone'] ?? '';
    final method = p['payment_method'] ?? 'UPI';
    final upi    = p['upi_id'] ?? '-';
    
    return Container(
      margin:  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: navy, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.payment_rounded, color: gold, size: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(worker, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(phone, style: const TextStyle(color: gray, fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('+₹$amt', style: const TextStyle(color: Color(0xFF00C853), fontSize: 18, fontWeight: FontWeight.w900)),
                  Text(method, style: const TextStyle(color: gray, fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              )
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: plan == 'pro' ? const Color(0xFF9C6FFF).withOpacity(0.2) : plan == 'standard' ? Colors.blueAccent.withOpacity(0.2) : gray.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                    child: Text(_toTitleCase(plan), style: TextStyle(color: plan == 'pro' ? const Color(0xFF9C6FFF) : plan == 'standard' ? Colors.blueAccent : Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  Text(_fmtDate(p['created_at']), style: const TextStyle(color: gray, fontSize: 11)),
                ],
              ),
              if (method == 'UPI' && upi != '-')
                Text(upi, style: const TextStyle(color: gray, fontSize: 11, fontStyle: FontStyle.italic)),
            ],
          )
        ],
      ),
    );
  }
}
