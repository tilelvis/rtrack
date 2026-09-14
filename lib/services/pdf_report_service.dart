import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../models/loan.dart';
import '../models/payment.dart';

/// Generates a PDF report of all payments for a loan.
/// The report includes:
///   - Header with app name and generation date
///   - Loan summary (title, principal, due date)
///   - Totals box (total payable, total paid, balance, progress)
///   - Transaction table (date, M-Pesa code, sender, amount, source)
class PdfReportService {
  /// Generate and share a PDF report for the given loan + payments.
  /// Returns the path to the saved PDF file.
  static Future<String> generateAndShare({
    required Loan loan,
    required List<Payment> payments,
    required double totalPaid,
  }) async {
    final pdf = await _buildDocument(
      loan: loan,
      payments: payments,
      totalPaid: totalPaid,
    );

    // Save to a temp file
    final bytes = await pdf.save();
    final tmpDir = await getTemporaryDirectory();
    final fileName =
        'loan_tracker_${loan.title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}'
        '_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
    final filePath = p.join(tmpDir.path, fileName);
    final file = File(filePath);
    await file.writeAsBytes(bytes);

    // Trigger the system share sheet so the user can save / send / print
    await Share.shareXFiles(
      [XFile(filePath)],
      subject: 'Loan Tracker Report — ${loan.title}',
      text: 'Loan repayment report for "${loan.title}". '
          'Total paid: Ksh ${totalPaid.toStringAsFixed(2)} of '
          'Ksh ${loan.totalPayable.toStringAsFixed(2)}.',
    );

    return filePath;
  }

  /// Build the PDF document.
  static Future<pw.Document> _buildDocument({
    required Loan loan,
    required List<Payment> payments,
    required double totalPaid,
  }) async {
    final doc = pw.Document(pageMode: PdfPageMode.fullscreen);

    // Sort payments oldest-first for the report (more natural reading order)
    final sorted = List<Payment>.from(payments)
      ..sort((a, b) => a.paidAt.compareTo(b.paidAt));

    final balance = loan.totalPayable - totalPaid;
    final progress = loan.totalPayable > 0
        ? (totalPaid / loan.totalPayable).clamp(0.0, 1.0).toDouble()
        : 0.0;

    // Color palette (match app's dark-neon identity, but on a white PDF)
    const neonGreen = PdfColor.fromInt(0xFF1FAE0D); // printable green
    const darkText = PdfColor.fromInt(0xFF0A0E14);
    const mutedText = PdfColor.fromInt(0xFF6B7280);
    const accent = PdfColor.fromInt(0xFF00A0B0);
    const lineColor = PdfColor.fromInt(0xFFE5E7EB);
    const headerBg = PdfColor.fromInt(0xFFF5F7FA);

    // Load a default font; pdf package ships with Helvetica by default
    final baseFont = pw.Font.helvetica();
    final boldFont = pw.Font.helveticaBold();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (ctx) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'LOAN TRACKER',
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 14,
                    color: neonGreen,
                    letterSpacing: 2,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Repayment Report',
                  style: pw.TextStyle(
                    font: baseFont,
                    fontSize: 10,
                    color: mutedText,
                  ),
                ),
              ],
            ),
            pw.Text(
              'Generated ${DateFormat('d MMM y, h:mm a').format(DateTime.now())}',
              style: pw.TextStyle(
                font: baseFont,
                fontSize: 9,
                color: mutedText,
              ),
            ),
          ],
        ),
        footer: (ctx) => pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(top: 12),
          child: pw.Text(
            'Page ${ctx.pageNumber} of ${ctx.pagesCount} • Loan Tracker',
            style: pw.TextStyle(
              font: baseFont,
              fontSize: 9,
              color: mutedText,
            ),
          ),
        ),
        build: (ctx) => [
          // --- Loan title ---
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: headerBg,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: lineColor),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  loan.title,
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 22,
                    color: darkText,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  'Principal: Ksh ${_fmt(loan.principal)}    '
                  '•    Interest: ${loan.interestRate.toStringAsFixed(1)}%    '
                  '•    Start: ${_fmtDate(loan.startDate)}    '
                  '•    Due: ${_fmtDate(loan.dueDate)}',
                  style: pw.TextStyle(
                    font: baseFont,
                    fontSize: 10,
                    color: mutedText,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // --- Totals summary ---
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _summaryCard(
                'Total Payable',
                'Ksh ${_fmt(loan.totalPayable)}',
                accent,
                baseFont,
                boldFont,
                darkText,
                mutedText,
                lineColor,
              ),
              pw.SizedBox(width: 8),
              _summaryCard(
                'Total Paid',
                'Ksh ${_fmt(totalPaid)}',
                neonGreen,
                baseFont,
                boldFont,
                darkText,
                mutedText,
                lineColor,
              ),
              pw.SizedBox(width: 8),
              _summaryCard(
                'Balance',
                'Ksh ${_fmt(balance < 0 ? 0 : balance)}',
                const PdfColor.fromInt(0xFFFF3B3B),
                baseFont,
                boldFont,
                darkText,
                mutedText,
                lineColor,
              ),
              pw.SizedBox(width: 8),
              _summaryCard(
                'Progress',
                '${(progress * 100).toStringAsFixed(1)}%',
                accent,
                baseFont,
                boldFont,
                darkText,
                mutedText,
                lineColor,
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          _progressBar(progress, neonGreen, lineColor),
          pw.SizedBox(height: 24),

          // --- Section heading ---
          pw.Text(
            'Transaction History',
            style: pw.TextStyle(
              font: boldFont,
              fontSize: 14,
              color: darkText,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            '${payments.length} payment${payments.length == 1 ? '' : 's'} recorded',
            style: pw.TextStyle(
              font: baseFont,
              fontSize: 10,
              color: mutedText,
            ),
          ),
          pw.SizedBox(height: 12),

          // --- Transaction table ---
          _transactionsTable(
            sorted,
            baseFont,
            boldFont,
            darkText,
            mutedText,
            lineColor,
            headerBg,
            neonGreen,
            accent,
          ),
        ],
      ),
    );

    return doc;
  }

  static pw.Widget _summaryCard(
    String label,
    String value,
    PdfColor accentColor,
    pw.Font baseFont,
    pw.Font boldFont,
    PdfColor darkText,
    PdfColor mutedText,
    PdfColor lineColor,
  ) {
    // baseFont + darkText reserved for future sub-line; suppress unused warnings.
    final _ = (baseFont, darkText);
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: lineColor),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label.toUpperCase(),
              style: pw.TextStyle(
                font: boldFont,
                fontSize: 7,
                color: mutedText,
                letterSpacing: 1.2,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              style: pw.TextStyle(
                font: boldFont,
                fontSize: 13,
                color: accentColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _progressBar(
    double progress,
    PdfColor fillColor,
    PdfColor trackColor,
  ) {
    // pdf package does not ship FractionallySizedBox, so we emulate the
    // progress bar using an Expanded-based Row with proportional flex.
    // progress is clamped to [0, 1] and converted to integer flex parts.
    final p = progress.clamp(0.0, 1.0);
    final filledFlex = (p * 1000).round();
    final emptyFlex = 1000 - filledFlex;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.ClipRRect(
          horizontalRadius: 4,
          verticalRadius: 4,
          child: pw.Container(
            width: double.infinity,
            height: 8,
            decoration: pw.BoxDecoration(color: trackColor),
            child: pw.Row(
              children: [
                if (filledFlex > 0)
                  pw.Expanded(
                    flex: filledFlex,
                    child: pw.Container(color: fillColor),
                  ),
                if (emptyFlex > 0)
                  pw.Expanded(
                    flex: emptyFlex,
                    child: pw.Container(color: trackColor),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _transactionsTable(
    List<Payment> payments,
    pw.Font baseFont,
    pw.Font boldFont,
    PdfColor darkText,
    PdfColor mutedText,
    PdfColor lineColor,
    PdfColor headerBg,
    PdfColor mpesaColor,
    PdfColor manualColor,
  ) {
    if (payments.isEmpty) {
      return pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(20),
        decoration: pw.BoxDecoration(
          color: headerBg,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Text(
          'No payments recorded yet.',
          style: pw.TextStyle(
            font: baseFont,
            fontSize: 11,
            color: mutedText,
          ),
          textAlign: pw.TextAlign.center,
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: lineColor, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(2.2), // date
        1: pw.FlexColumnWidth(1.8), // code
        2: pw.FlexColumnWidth(2.0), // sender
        3: pw.FlexColumnWidth(0.9), // source
        4: pw.FlexColumnWidth(1.6), // amount
      },
      children: [
        // Header row
        pw.TableRow(
          decoration: pw.BoxDecoration(color: headerBg),
          children: [
            _headerCell('Date', baseFont, boldFont, mutedText),
            _headerCell('M-Pesa Code', baseFont, boldFont, mutedText),
            _headerCell('Sender / Recipient', baseFont, boldFont, mutedText),
            _headerCell('Type', baseFont, boldFont, mutedText),
            _headerCell('Amount (Ksh)', baseFont, boldFont, mutedText,
                align: pw.TextAlign.right),
          ],
        ),
        // Body rows
        ...payments.asMap().entries.map((entry) {
          final i = entry.key;
          final p = entry.value;
          final altBg = i.isEven ? null : headerBg;
          return pw.TableRow(
            decoration: altBg != null ? pw.BoxDecoration(color: altBg) : null,
            children: [
              _cell(
                '${DateFormat('d MMM y').format(p.paidAt)}\n'
                    '${DateFormat('h:mm a').format(p.paidAt)}',
                baseFont,
                darkText,
                mutedText,
                fontSize: 9,
              ),
              _cell(
                p.mpesaCode ?? '—',
                baseFont,
                p.mpesaCode != null ? mpesaColor : mutedText,
                mutedText,
                fontSize: 9,
                isBold: p.mpesaCode != null,
              ),
              _cell(
                p.sender ?? '—',
                baseFont,
                darkText,
                mutedText,
                fontSize: 9,
              ),
              _cell(
                p.source.name == 'mpesa' ? 'M-Pesa' : 'Manual',
                baseFont,
                p.source.name == 'mpesa' ? mpesaColor : manualColor,
                mutedText,
                fontSize: 8,
              ),
              _cell(
                p.amount.toStringAsFixed(2),
                baseFont,
                darkText,
                mutedText,
                fontSize: 10,
                align: pw.TextAlign.right,
                isBold: true,
              ),
            ],
          );
        }),
        // Total row — pdf package requires every TableRow to have one child
        // per column, so we emit 5 cells (the first holds the "TOTAL" label,
        // the next 3 are empty spacers, the last holds the summed amount).
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: const PdfColor.fromInt(0xFFE8F8E0),
          ),
          children: [
            _cell(
              'TOTAL',
              baseFont,
              darkText,
              mutedText,
              fontSize: 10,
              isBold: true,
            ),
            _cell('', baseFont, mutedText, mutedText),
            _cell('', baseFont, mutedText, mutedText),
            _cell('', baseFont, mutedText, mutedText),
            _cell(
              payments.fold<double>(0, (s, p) => s + p.amount).toStringAsFixed(2),
              baseFont,
              mpesaColor,
              mutedText,
              fontSize: 11,
              align: pw.TextAlign.right,
              isBold: true,
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _headerCell(
    String text,
    pw.Font baseFont,
    pw.Font boldFont,
    PdfColor mutedText, {
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: pw.Text(
        text.toUpperCase(),
        style: pw.TextStyle(
          font: boldFont,
          fontSize: 8,
          color: mutedText,
          letterSpacing: 1.0,
        ),
        textAlign: align,
      ),
    );
  }

  static pw.Widget _cell(
    String text,
    pw.Font baseFont,
    PdfColor primaryColor,
    PdfColor mutedColor, {
    double fontSize = 10,
    pw.TextAlign align = pw.TextAlign.left,
    bool isBold = false,
  }) {
    // mutedColor is accepted for API symmetry but not used in the cell body;
    // primaryColor already conveys the visual emphasis.
    final _ = mutedColor;
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: baseFont,
          fontSize: fontSize,
          color: primaryColor,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: align,
      ),
    );
  }

  static String _fmt(double v) => v.toStringAsFixed(2);
  static String _fmtDate(DateTime d) => DateFormat('d MMM y').format(d);
}
