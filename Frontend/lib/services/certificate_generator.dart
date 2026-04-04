import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class CertificateGenerator {

  static String _month(int m) {
    const months = ['','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return months[m];
  }

  static String _formatDate(DateTime d) =>
    '${d.day.toString().padLeft(2,'0')} ${_month(d.month)} ${d.year}';

  static Future<void> generate({
    required int    workerId,
    required String workerName,
    required String zone,
    required String platform,
    required String planType,
    required int    weeklyPremium,
    required int    maxPayout,
    required String endDate,
  }) async {
    final font     = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: font,
        bold: fontBold,
      ),
    );
    final now       = DateTime.now();
    final policyNo  = 'GS-${now.year}-${now.month.toString().padLeft(2,'0')}-${workerId.toString().padLeft(5,'0')}';
    final clientNo  = 'WRK-${workerId.toString().padLeft(5,'0')}';
    final issueDate = _formatDate(now);
    final startDate = _formatDate(now);
    final planUpper = planType.toUpperCase();
    final navyColor = PdfColor.fromHex('#1A2E6E');
    final goldColor = PdfColor.fromHex('#F5A623');
    final lightBg   = PdfColor.fromHex('#E8EDFF');

    String endFmt = endDate;
    try {
      if (endDate.length >= 10) {
        final d = DateTime.parse(endDate.substring(0, 10));
        endFmt = _formatDate(d);
      }
    } catch (_) {}

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin:     const pw.EdgeInsets.all(40),
      build: (pw.Context ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [

          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(color: navyColor, borderRadius: pw.BorderRadius.circular(10)),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('Insurify', style: pw.TextStyle(color: PdfColors.white, fontSize: 26, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  pw.Text('Income Protection for India\'s Gig Workers', style: const pw.TextStyle(color: PdfColors.white, fontSize: 10)),
                ]),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  pw.Text('PROTECT', style: pw.TextStyle(color: goldColor, fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  pw.Text('EARN',    style: pw.TextStyle(color: goldColor, fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  pw.Text('THRIVE',  style: pw.TextStyle(color: goldColor, fontSize: 11, fontWeight: pw.FontWeight.bold)),
                ]),
              ],
            ),
          ),

          pw.SizedBox(height: 20),
          pw.Center(child: pw.Text('Your Certificate of Income Insurance',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: navyColor))),
          pw.SizedBox(height: 6),
          pw.Center(child: pw.Text(
            'This document is evidence of your income protection cover with Insurify.\nPlease keep it safe. Coverage is valid for the period shown below.',
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700))),
          pw.SizedBox(height: 16),

          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: pw.BoxDecoration(color: goldColor, borderRadius: pw.BorderRadius.circular(6)),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('POLICY NUMBER', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: navyColor)),
                pw.Text(policyNo,        style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: navyColor)),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(color: lightBg, borderRadius: pw.BorderRadius.circular(8)),
            child: pw.Column(children: [
              _dr('Worker / Policyholder', workerName, navyColor),
              _dr('Platform',              platform,   navyColor),
              _dr('Delivery Zone',         '$zone, Bengaluru', navyColor),
              _dr('Start of Cover',        startDate,  navyColor),
              _dr('End of Cover',          endFmt,     navyColor),
              _dr('Insurance Plan',        planUpper,  navyColor),
            ]),
          ),
          pw.SizedBox(height: 16),

          _st('POLICY INFORMATION', navyColor),
          pw.SizedBox(height: 6),
          pw.Text(
            'This document outlines the terms and conditions of the income protection coverage provided by Insurify to the policyholder, $workerName, under policy number $policyNo. The client number associated with this policy is $clientNo.\n\nCoverage under this policy begins on $startDate and remains effective until $endFmt, provided that the weekly premium of ₹$weeklyPremium has been paid in full. The maximum payout under this policy is ₹$maxPayout / week. Payouts are triggered automatically upon verified parametric events — no manual claim filing is required by the worker.\n\nThe policyholder may cancel coverage at any time via the Insurify app. Insurify reserves the right to suspend coverage in the event of verified fraudulent activity, including GPS spoofing, duplicate claim submissions, or misrepresentation of delivery zone.',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800, lineSpacing: 1.4)),
          pw.SizedBox(height: 16),

          _st('COVERAGE DETAILS', navyColor),
          pw.SizedBox(height: 8),
          pw.Text('Platform: $platform    Risk Zone: HIGH    Delivery Zone: $zone    Plan Type: $planUpper',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          pw.SizedBox(height: 8),
          pw.Text('The selected plan, $planUpper, provides parametric income protection against verified external disruptions. Payouts are calculated as a percentage of the maximum weekly payout of ₹$maxPayout / week based on disruption severity tier.',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
          pw.SizedBox(height: 10),

          pw.Table(
            border: pw.TableBorder.all(color: PdfColor.fromHex('#CDD8F6'), width: 0.5),
            columnWidths: {0: const pw.FlexColumnWidth(3), 1: const pw.FlexColumnWidth(1), 2: const pw.FlexColumnWidth(1.5), 3: const pw.FlexColumnWidth(2)},
            children: [
              pw.TableRow(decoration: pw.BoxDecoration(color: navyColor),
                children: [_th('Disruption Type'), _th('Tier'), _th('Payout %'), _th('Max Amount')]),
              _tr('Heavy Rain',    'T2', '50%',  '₹${(maxPayout * 0.5).round()}'),
              _tr('Flood Alert',   'T3', '100%', '₹$maxPayout'),
              _tr('Extreme Heat',  'T1', '25%',  '₹${(maxPayout * 0.25).round()}'),
              _tr('Severe AQI',    'T2', '50%',  '₹${(maxPayout * 0.5).round()}'),
              _tr('Zone Shutdown', 'T3', '100%', '₹$maxPayout'),
            ],
          ),
          pw.SizedBox(height: 16),

          _st('PREMIUM PAYMENT SCHEDULE', navyColor),
          pw.SizedBox(height: 6),
          pw.Text('The total premium amount due is ₹$weeklyPremium per week. This amount is collected at the start of each coverage week. Failure to maintain payment may result in suspension of active coverage.',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColor.fromHex('#CDD8F6'), width: 0.5),
            children: [
              pw.TableRow(decoration: pw.BoxDecoration(color: lightBg),
                children: [_th2('PAYMENT DUE DATE', navyColor), _th2('AMOUNT', navyColor)]),
              pw.TableRow(children: [_tc(startDate), _tc('₹$weeklyPremium')]),
            ],
          ),

          pw.Spacer(),
          pw.Divider(color: PdfColor.fromHex('#CDD8F6')),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('Insurify', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: navyColor)),
                pw.Text('Bengaluru, Karnataka', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                pw.Text('India', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              ]),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
                pw.Text('REPRESENTED BY', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
                pw.Text('Insurify Auto-System', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: navyColor)),
                pw.Text('Ref: SYS-AUTO-001', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
              ]),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text('ISSUE DATE', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
                pw.Text(issueDate, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: navyColor)),
                pw.SizedBox(height: 4),
                pw.Text('CLIENT NUMBER', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
                pw.Text(clientNo, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: navyColor)),
              ]),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Center(child: pw.Text(
            'Page 1 of 1 · Insurify Income Protection Certificate · $policyNo',
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey400))),
        ],
      ),
    ));

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: 'Insurify_Certificate_$policyNo.pdf',
    );
  }

  static pw.Widget _dr(String l, String v, PdfColor c) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(children: [
        pw.SizedBox(width: 150, child: pw.Text(l, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600))),
        pw.Text(v, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: c)),
      ]));

  static pw.Widget _st(String t, PdfColor c) =>
    pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text(t, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: c)),
      pw.Divider(color: PdfColor.fromHex('#CDD8F6')),
    ]);

  static pw.Widget _th(String t) => pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(t, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white)));

  static pw.Widget _th2(String t, PdfColor c) => pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(t, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: c)));

  static pw.Widget _tc(String t) => pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(t, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)));

  static pw.TableRow _tr(String a, String b, String c, String d) =>
    pw.TableRow(children: [_tc(a), _tc(b), _tc(c), _tc(d)]);
}