import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../models/loan.dart';
import '../models/payment.dart';

/// Generates a single-payment receipt PDF that can be shared via
/// WhatsApp / Email / SMS to the lender as proof of payment.
///
/// The receipt contains:
///   - "PAYMENT RECEIPT" header
///   - Loan title + lender info
///   - Big amount paid + payment date
///   - M-Pesa transaction code (prominent)
///   - Sender / phone details
///   - Updated balance after this payment
///   - Generated-at timestamp + footer
class PaymentReceiptService {
  static Future<String> generateAndShare({
    required Loan loan,
    required Payment payment,
    required double totalPaidAfter,
  }) async {
    final pdf = await _buildDocument(
      loan: loan,
      payment: payment,
      totalPaidAfter: totalPaidAfter,
    );

    final bytes = await pdf.save();
    final tmpDir = await getTemporaryDirectory();
    final code = payment.mpesaCode ?? payment.id.substring(0, 8);
    final fileName =
        'receipt_${code}_${DateFormat('yyyyMMdd').format(payment.paidAt)}.pdf';
    final filePath = p.join(tmpDir.path, fileName);
    await File(filePath).writeAsBytes(bytes);

    // Pre-fill the share text with the lender's name + summary
    final lenderName = loan.lenderName?.trim() ?? '';
    final shareText = StringBuffer()
      ..writeln('Payment receipt for ${loan.title}')
      ..writeln('Amount: Ksh ${payment.amount.toStringAsFixed(2)}')
      ..writeln('M-Pesa code: ${payment.mpesaCode ?? "—"}')
      ..writeln('Date: ${DateFormat('d MMM y, h:mm a').format(payment.paidAt)}')
      ..writeln('Remaining balance: Ksh ${(loan.totalPayable - totalPaidAfter).clamp(0, double.infinity).toStringAsFixed(2)}');
    if (lenderName.isNotEmpty) {
      shareText.writeln('Lender: $lenderName');
    }

    await Share.shareXFiles(
      [XFile(filePath)],
      subject: 'Payment receipt — ${loan.title} (Ksh ${payment.amount.toStringAsFixed(2)})',
      text: shareText.toString(),
    );

    return filePath;
  }

  static Future<pw.Document> _buildDocument({
    required Loan loan,
    required Payment payment,
    required double totalPaidAfter,
  }) async {
    final doc = pw.Document();
    final baseFont = pw.Font.helvetica();
    final boldFont = pw.Font.helveticaBold();

    const neonGreen = PdfColor.fromInt(0xFF1FAE0D);
    const darkText = PdfColor.fromInt(0xFF0A0E14);
    const mutedText = PdfColor.fromInt(0xFF6B7280);
    const accent = PdfColor.fromInt(0xFF00A0B0);
    const lineColor = PdfColor.fromInt(0xFFE5E7EB);
    const headerBg = PdfColor.fromInt(0xFFF5F7FA);
    const codeBg = PdfColor.fromInt(0xFFE8F8E0);

    final remaining = (loan.totalPayable - totalPaidAfter)
        .clamp(0.0, double.infinity);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(50),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header band
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 18,
              ),
              decoration: pw.BoxDecoration(
                color: headerBg,
                borderRadius: pw.BorderRadius.circular(10),
                border: pw.Border.all(color: lineColor),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'PAYMENT RECEIPT',
                        style: pw.TextStyle(
                          font: boldFont,
                          fontSize: 20,
                          color: neonGreen,
                          letterSpacing: 2,
                        ),
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'Loan Tracker',
                            style: pw.TextStyle(
                              font: baseFont,
                              fontSize: 10,
                              color: mutedText,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            DateFormat('d MMM y, h:mm a')
                                .format(DateTime.now()),
                            style: pw.TextStyle(
                              font: baseFont,
                              fontSize: 9,
                              color: mutedText,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 10),
                  pw.Divider(color: lineColor, height: 1),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    loan.title,
                    style: pw.TextStyle(
                      font: boldFont,
                      fontSize: 16,
                      color: darkText,
                    ),
                  ),
                  if (loan.lenderName?.isNotEmpty ?? false) ...[
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Lender: ${loan.lenderName}'
                      '${loan.lenderPhone != null ? "  •  ${loan.lenderPhone}" : ""}',
                      style: pw.TextStyle(
                        font: baseFont,
                        fontSize: 11,
                        color: mutedText,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            pw.SizedBox(height: 30),

            // Big amount paid
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(
                    'AMOUNT PAID',
                    style: pw.TextStyle(
                      font: boldFont,
                      fontSize: 10,
                      color: mutedText,
                      letterSpacing: 1.5,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'Ksh ${payment.amount.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      font: boldFont,
                      fontSize: 44,
                      color: neonGreen,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    DateFormat('EEEE, d MMMM y • h:mm a')
                        .format(payment.paidAt),
                    style: pw.TextStyle(
                      font: baseFont,
                      fontSize: 12,
                      color: darkText,
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 30),

            // M-Pesa code highlight (if present)
            if (payment.mpesaCode != null) ...[
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(18),
                decoration: pw.BoxDecoration(
                  color: codeBg,
                  borderRadius: pw.BorderRadius.circular(10),
                  border: pw.Border.all(color: neonGreen, width: 1.5),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'M-PESA TRANSACTION CODE',
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: 9,
                            color: mutedText,
                            letterSpacing: 1.2,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          payment.mpesaCode!,
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: 22,
                            color: neonGreen,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                    pw.Text(
                      'VERIFIED',
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 10,
                        color: neonGreen,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 18),
            ],

            // Details table
            pw.Table(
              border: pw.TableBorder.all(color: lineColor, width: 0.5),
              columnWidths: const {
                0: pw.FlexColumnWidth(1.2),
                1: pw.FlexColumnWidth(2),
              },
              children: [
                _detailRow(
                  'Source',
                  payment.source.name == 'mpesa' ? 'M-Pesa' : 'Manual entry',
                  baseFont,
                  boldFont,
                  darkText,
                  mutedText,
                ),
                _detailRow(
                  'Sender',
                  payment.sender ?? '—',
                  baseFont,
                  boldFont,
                  darkText,
                  mutedText,
                ),
                _detailRow(
                  'Phone',
                  payment.phone ?? '—',
                  baseFont,
                  boldFont,
                  darkText,
                  mutedText,
                ),
                _detailRow(
                  'Loan principal',
                  'Ksh ${loan.principal.toStringAsFixed(2)}',
                  baseFont,
                  boldFont,
                  darkText,
                  mutedText,
                ),
                _detailRow(
                  'Total payable',
                  'Ksh ${loan.totalPayable.toStringAsFixed(2)}'
                  ' (${loan.interestRate.toStringAsFixed(1)}% interest)',
                  baseFont,
                  boldFont,
                  darkText,
                  mutedText,
                ),
                _detailRow(
                  'Total paid so far',
                  'Ksh ${totalPaidAfter.toStringAsFixed(2)}',
                  baseFont,
                  boldFont,
                  neonGreen,
                  mutedText,
                ),
                _detailRow(
                  'Remaining balance',
                  'Ksh ${remaining.toStringAsFixed(2)}',
                  baseFont,
                  boldFont,
                  remaining <= 0 ? neonGreen : accent,
                  mutedText,
                ),
                _detailRow(
                  'Due date',
                  DateFormat('d MMM y').format(loan.dueDate),
                  baseFont,
                  boldFont,
                  darkText,
                  mutedText,
                ),
              ],
            ),

            pw.Spacer(),

            // Footer
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.only(top: 18),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  top: pw.BorderSide(color: lineColor, width: 0.5),
                ),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Generated by Loan Tracker',
                    style: pw.TextStyle(
                      font: baseFont,
                      fontSize: 9,
                      color: mutedText,
                    ),
                  ),
                  pw.Text(
                    'Receipt #${payment.mpesaCode ?? payment.id.substring(0, 8).toUpperCase()}',
                    style: pw.TextStyle(
                      font: baseFont,
                      fontSize: 9,
                      color: mutedText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return doc;
  }

  static pw.TableRow _detailRow(
    String label,
    String value,
    pw.Font baseFont,
    pw.Font boldFont,
    PdfColor valueColor,
    PdfColor mutedText,
  ) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: pw.Text(
            label,
            style: pw.TextStyle(
              font: boldFont,
              fontSize: 9,
              color: mutedText,
              letterSpacing: 0.8,
            ),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: pw.Text(
            value,
            style: pw.TextStyle(
              font: baseFont,
              fontSize: 11,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }
}
