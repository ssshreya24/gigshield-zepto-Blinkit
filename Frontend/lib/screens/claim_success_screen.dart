import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/claim_receipt_generator.dart';
import '../services/api_service.dart';
import 'home_screen.dart';

class ClaimSuccessScreen extends StatefulWidget {
  final int                        total;
  final List<Map<String, dynamic>> triggers;
  final List<int>                  amounts;
  final Map<String, dynamic>?      policy;
  final String                     upiId;

  const ClaimSuccessScreen({
    super.key,
    required this.total,
    required this.triggers,
    required this.amounts,
    this.policy,
    required this.upiId,
  });
  @override
  State<ClaimSuccessScreen> createState() =>
    _ClaimSuccessScreenState();
}

class _ClaimSuccessScreenState
    extends State<ClaimSuccessScreen>
    with TickerProviderStateMixin {

  static const bg   = Color(0xFF0D1829);
  static const gold = Color(0xFFF5A623);

  late AnimationController _scaleCtrl;
  late Animation<double>   _scale;
  late AnimationController _amtCtrl;
  late Animation<double>   _amt;

  bool _downloading = false;
  String _paymentProvider = 'Razorpay';
  String _paymentMode = 'test';
  String? _razorpayOrderId;

  late final String _claimId;
  late final String _txnId;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    _claimId = 'CLM-${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}-${now.millisecond}';
    _txnId   = 'TXN${now.millisecondsSinceEpoch.toString().substring(5)}';

    _scaleCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700));
    _scale = CurvedAnimation(
      parent: _scaleCtrl, curve: Curves.elasticOut);

    _amtCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1500));
    _amt = CurvedAnimation(
      parent: _amtCtrl, curve: Curves.easeOut);

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _scaleCtrl.forward();
        _amtCtrl.forward();
        HapticFeedback.heavyImpact();
      }
    });

    // Create Razorpay payment order for this payout
    _createPaymentOrder();
  }

  Future<void> _createPaymentOrder() async {
    try {
      final order = await ApiService.createPaymentOrder(
        amount:      widget.total,
        triggerType: widget.triggers.isNotEmpty
          ? widget.triggers[0]['trigger_type']?.toString() ?? 'payout'
          : 'payout',
        zone: widget.policy?['zone']?.toString(),
      );
      if (mounted && order['success'] == true) {
        setState(() {
          _razorpayOrderId = order['order_id']?.toString();
          _paymentProvider = order['provider']?.toString() ?? 'Razorpay';
          _paymentMode     = order['mode']?.toString() ?? 'test';
        });
      }
    } catch (_) {
      // Non-blocking — payout UI still shows even if order creation fails
    }
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    _amtCtrl.dispose();
    super.dispose();
  }

  Future<void> _downloadReceipt() async {
    setState(() => _downloading = true);
    try {
      await ClaimReceiptGenerator.generate(
        total:    widget.total,
        triggers: widget.triggers,
        amounts:  widget.amounts,
        policy:   widget.policy,
        upiId:    widget.upiId,
        claimId:  _claimId,
        txnId:    _txnId,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:         Text('Error: $e'),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  String get _dateNow {
    final d = DateTime.now();
    const months = ['','Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${months[d.month]} ${d.year}';
  }

  String get _timeNow {
    final t = DateTime.now();
    final h = t.hour > 12 ? t.hour - 12 : t.hour == 0 ? 12 : t.hour;
    final m = t.minute.toString().padLeft(2,'0');
    final p = t.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $p';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(children: [

                // Success icon
                ScaleTransition(
                  scale: _scale,
                  child: Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00C853).withOpacity(0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF00C853).withOpacity(0.4),
                        width: 2)),
                    child: const Icon(Icons.check_rounded,
                      color: Color(0xFF00C853), size: 54),
                  ),
                ),

                const SizedBox(height: 20),
                const Text('Claim Approved!',
                  style: TextStyle(color: Colors.white,
                    fontSize: 28, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                const Text('Amount credited to your UPI',
                  style: TextStyle(
                    color: Colors.white54, fontSize: 14)),

                const SizedBox(height: 16),

                AnimatedBuilder(
                  animation: _amt,
                  builder: (_, __) {
                    final shown =
                      (widget.total * _amt.value).round();
                    return Text('₹$shown',
                      style: const TextStyle(color: gold,
                        fontSize: 64, fontWeight: FontWeight.w900,
                        letterSpacing: -2));
                  },
                ),

                const SizedBox(height: 6),
                Text(widget.upiId,
                  style: const TextStyle(
                    color: Colors.white38, fontSize: 13)),

                const SizedBox(height: 24),

                // Transaction IDs card
                _darkCard(child: Column(children: [
                  _txnRow('Claim ID',       _claimId),
                  _div(),
                  _txnRow('Transaction ID', _txnId),
                  _div(),
                  _txnRow('Date',           _dateNow),
                  _div(),
                  _txnRow('Time',           _timeNow),
                  _div(),
                  _txnRow('Status', '✓ Credited',
                    valueColor: const Color(0xFF00C853)),
                ])),

                const SizedBox(height: 16),

                // Triggers covered
                _sectionLabel('Triggers Covered'),
                const SizedBox(height: 10),
                _darkCard(child: Column(
                  children: List.generate(
                    widget.triggers.length, (i) {
                    final t     = widget.triggers[i];
                    final color = t['color'] as Color;
                    return Column(children: [
                      if (i > 0) _div(),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12),
                        child: Row(children: [
                          Icon(t['icon'] as IconData,
                            color: color, size: 18),
                          const SizedBox(width: 10),
                          Expanded(child: Column(
                            crossAxisAlignment:
                              CrossAxisAlignment.start,
                            children: [
                              Text(t['name'] as String,
                                style: const TextStyle(
                                  color:      Colors.white,
                                  fontSize:   14,
                                  fontWeight: FontWeight.w600)),
                              Text(
                                'Tier ${t['severity']} · ${t['pct']}%',
                                style: const TextStyle(
                                  color:    Colors.white38,
                                  fontSize: 11)),
                            ],
                          )),
                          Text('₹${widget.amounts[i]}',
                            style: const TextStyle(
                              color:      gold,
                              fontSize:   15,
                              fontWeight: FontWeight.w900)),
                        ]),
                      ),
                    ]);
                  }),
                )),

                const SizedBox(height: 16),

                // Approval basis
                _sectionLabel('Approval Basis'),
                const SizedBox(height: 10),
                _darkCard(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _basis('Real-time weather API data verified'),
                    _basis('Government alerts cross-checked'),
                    _basis('GPS location confirmed in zone'),
                    _basis('Fraud check: passed'),
                    _basis('Policy coverage matched'),
                    _basis('Zero manual filing required'),
                  ],
                )),

                const SizedBox(height: 16),

                // Coverage summary
                _sectionLabel('Coverage Summary'),
                const SizedBox(height: 10),
                _darkCard(child: Column(children: [
                  _txnRow('Worker',
                    widget.policy?['name'] ?? 'Worker'),
                  _div(),
                  _txnRow('Zone',
                    widget.policy?['zone'] ?? 'Your Zone'),
                  _div(),
                  _txnRow('Platform',
                    widget.policy?['platform'] ?? 'Zepto'),
                  _div(),
                  _txnRow('Plan',
                    (widget.policy?['plan_type'] ?? 'standard')
                      .toString().toUpperCase()),
                  _div(),
                  _txnRow('Triggers covered',
                    '${widget.triggers.length}'),
                  _div(),
                  _txnRow('Payment Gateway',
                    '$_paymentProvider (${_paymentMode.toUpperCase()})'),
                  _div(),
                  if (_razorpayOrderId != null) ...[
                    _txnRow('Order ID',
                      _razorpayOrderId!.length > 20
                        ? '${_razorpayOrderId!.substring(0, 20)}...'
                        : _razorpayOrderId!),
                    _div(),
                  ],
                  _txnRow('Total credited', '₹${widget.total}',
                    valueColor: gold),
                ])),
              ]),
            ),
          ),

          // Buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(children: [

              // Download receipt PDF button
              GestureDetector(
                onTap: _downloading ? null : _downloadReceipt,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width:   double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: _downloading
                      ? gold.withOpacity(0.6) : gold,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: _downloading ? [] : [BoxShadow(
                      color:      gold.withOpacity(0.35),
                      blurRadius: 16,
                      offset:     const Offset(0, 6))],
                  ),
                  child: _downloading
                    ? const Row(
                        mainAxisAlignment:
                          MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                              color:       Color(0xFF0D1829),
                              strokeWidth: 2.5)),
                          SizedBox(width: 10),
                          Text('Generating PDF...',
                            style: TextStyle(
                              color:      Color(0xFF0D1829),
                              fontSize:   15,
                              fontWeight: FontWeight.w700)),
                        ])
                    : const Row(
                        mainAxisAlignment:
                          MainAxisAlignment.center,
                        children: [
                          Icon(Icons.picture_as_pdf_rounded,
                            color: Color(0xFF0D1829), size: 20),
                          SizedBox(width: 8),
                          Text('Download Claim Receipt (PDF)',
                            style: TextStyle(
                              color:      Color(0xFF0D1829),
                              fontSize:   15,
                              fontWeight: FontWeight.w900)),
                        ]),
                ),
              ),

              const SizedBox(height: 10),

              GestureDetector(
                onTap: () {
                  final wid = (widget.policy?['worker_id'] as int?) ?? 1;
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => HomeScreen(workerId: wid, initialTab: 1)),
                    (route) => false,
                  );
                },
                child: Container(
                  width:   double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1)),
                  ),
                  child: const Center(child: Text('Back to Home',
                    style: TextStyle(color: Colors.white54,
                      fontSize: 14,
                      fontWeight: FontWeight.w500))),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _basis(String t) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      const Icon(Icons.check_circle_rounded,
        color: Color(0xFF00C853), size: 14),
      const SizedBox(width: 8),
      Text(t, style: const TextStyle(
        color: Colors.white54, fontSize: 13)),
    ]),
  );

  Widget _txnRow(String l, String v, {Color? valueColor}) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(l, style: const TextStyle(
            color: Colors.white38, fontSize: 13)),
          Flexible(child: Text(v,
            textAlign: TextAlign.right,
            style: TextStyle(
              color:      valueColor ?? Colors.white,
              fontSize:   13,
              fontWeight: FontWeight.w600))),
        ],
      ),
    );

  Widget _div() =>
    Divider(color: Colors.white.withOpacity(0.06), height: 1);

  Widget _darkCard({required Widget child}) => Container(
    width:   double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.04),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: Colors.white.withOpacity(0.08)),
    ),
    child: child,
  );

  Widget _sectionLabel(String t) => Align(
    alignment: Alignment.centerLeft,
    child: Text(t,
      style: const TextStyle(
        color:         Colors.white38,
        fontSize:      12,
        fontWeight:    FontWeight.w700,
        letterSpacing: 0.8)),
  );
}
