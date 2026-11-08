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

  /// Generate and share a SINGLE combined PDF that contains every
  /// completed loan (and its payment history) in one document.
  ///
  /// Used by the Loan History screen's "Download completed loans" button
  /// so the user can produce a lifetime repayment record (e.g. to hand to
  /// a bank, lender, or auditor).
  ///
  /// Each loan renders on its own page section with its own totals +
  /// transaction table. A summary page at the start shows the cumulative
  /// totals across all completed loans.
  static Future<String> generateCompletedLoansPdfAndShare({
    required List<Loan> completedLoans,
    required Map<String, List<Payment>> paymentsByLoanId,
    required Map<String, double> totalPaidByLoanId,
  }) async {
    final pdf = await _buildCompletedLoansDocument(
      completedLoans: completedLoans,
      paymentsByLoanId: paymentsByLoanId,
      totalPaidByLoanId: totalPaidByLoanId,
    );

    final bytes = await pdf.save();
    final tmpDir = await getTemporaryDirectory();
    final fileName =
        'completed_loans_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
    final filePath = p.join(tmpDir.path, fileName);
    await File(filePath).writeAsBytes(bytes);

    final grandTotal = totalPaidByLoanId.values.fold<double>(0, (s, v) => s + v);
    final loanCount = completedLoans.length;

    await Share.shareXFiles(
      [XFile(filePath)],
      subject: 'Completed Loans Report — $loanCount loan${loanCount == 1 ? "" : "s"}',
      text: 'Lifetime repayment record covering $loanCount completed '
          'loan${loanCount == 1 ? "" : "s"}. '
          'Total repaid across all completed loans: '
          'Ksh ${grandTotal.toStringAsFixed(2)}.',
    );

    return filePath;
  }

  /// Generate and share a MONTHLY statement PDF for the given loan + month.
  /// Filters payments to only those in the specified [year]/[month].
  /// Returns the path to the saved PDF file.
  static Future<String> generateMonthlyAndShare({
    required Loan loan,
    required List<Payment> allPayments,
    required double totalPaidAllTime,
    required int year,
    required int month,
  }) async {
    // Filter payments to the specified month
    final monthly = allPayments.where((p) =>
        p.paidAt.year == year && p.paidAt.month == month).toList();
    final monthlyTotal = monthly.fold<double>(
      0, (s, p) => s + p.amount);

    final pdf = await _buildDocument(
      loan: loan,
      payments: monthly,
      totalPaid: monthlyTotal,
      isMonthlyStatement: true,
      statementYear: year,
      statementMonth: month,
      allTimeTotalPaid: totalPaidAllTime,
    );

    final bytes = await pdf.save();
    final tmpDir = await getTemporaryDirectory();
    final monthName = DateFormat('MMMM').format(DateTime(year, month));
    final fileName =
        'statement_${loan.title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}'
        '_${monthName}_${year}.pdf';
    final filePath = p.join(tmpDir.path, fileName);
    await File(filePath).writeAsBytes(bytes);

    final lenderEmail = loan.lenderEmail?.trim() ?? '';
    final shareText = StringBuffer()
      ..writeln('Monthly statement — ${loan.title}')
      ..writeln('Period: $monthName $year')
      ..writeln('Payments this month: ${monthly.length}')
      ..writeln('Total this month: Ksh ${monthlyTotal.toStringAsFixed(2)}')
      ..writeln('All-time total paid: Ksh ${totalPaidAllTime.toStringAsFixed(2)}')
      ..writeln('Remaining balance: Ksh ${(loan.totalPayable - totalPaidAllTime).clamp(0, double.infinity).toStringAsFixed(2)}');
    if (lenderEmail.isNotEmpty) {
      shareText.writeln('Lender: ${loan.lenderName ?? "—"} <$lenderEmail>');
    }

    await Share.shareXFiles(
      [XFile(filePath)],
      subject: 'Monthly statement — $monthName $year (${loan.title})',
      text: shareText.toString(),
    );

    return filePath;
  }

  /// Build a PDF document covering every completed loan in a single
  /// multi-page document. The first page is a summary; each subsequent
  /// page section covers one loan.
  static Future<pw.Document> _buildCompletedLoansDocument({
    required List<Loan> completedLoans,
    required Map<String, List<Payment>> paymentsByLoanId,
    required Map<String, double> totalPaidByLoanId,
  }) async {
    final doc = pw.Document(pageMode: PdfPageMode.fullscreen);

    // Color palette (match the single-loan report for consistency)
    const neonGreen = PdfColor.fromInt(0xFF1FAE0D);
    const darkText = PdfColor.fromInt(0xFF0A0E14);
    const mutedText = PdfColor.fromInt(0xFF6B7280);
    const accent = PdfColor.fromInt(0xFF00A0B0);
    const lineColor = PdfColor.fromInt(0xFFE5E7EB);
    const headerBg = PdfColor.fromInt(0xFFF5F7FA);

    final baseFont = pw.Font.helvetica();
    final boldFont = pw.Font.helveticaBold();

    // Sort completed loans oldest-due-first so the report reads
    // chronologically.
    final sortedLoans = List<Loan>.from(completedLoans)
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

    final grandTotalPayable =
        sortedLoans.fold<double>(0, (s, l) => s + l.totalPayable);
    final grandTotalPaid =
        sortedLoans.fold<double>(0, (s, l) => s + (totalPaidByLoanId[l.id] ?? 0));
    final grandPaymentCount = sortedLoans.fold<int>(
        0, (s, l) => s + (paymentsByLoanId[l.id]?.length ?? 0));

    // ------------------------------------------------------------------
    // Page 1 — Summary cover
    // ------------------------------------------------------------------
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
                  'Completed Loans — Lifetime Repayment Record',
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
                  '${sortedLoans.length} Completed Loan${sortedLoans.length == 1 ? "" : "s"}',
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 22,
                    color: darkText,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  'This document is a complete record of every loan you have '
                  'fully repaid through LoanTracker. Each loan is detailed '
                  'on its own page section with full transaction history.',
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

          // Grand totals summary
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _summaryCard(
                'Loans Repaid',
                '${sortedLoans.length}',
                accent,
                baseFont,
                boldFont,
                darkText,
                mutedText,
                lineColor,
              ),
              pw.SizedBox(width: 8),
              _summaryCard(
                'Total Repaid',
                'Ksh ${_fmt(grandTotalPaid)}',
                neonGreen,
                baseFont,
                boldFont,
                darkText,
                mutedText,
                lineColor,
              ),
              pw.SizedBox(width: 8),
              _summaryCard(
                'Total Borrowed',
                'Ksh ${_fmt(grandTotalPayable)}',
                accent,
                baseFont,
                boldFont,
                darkText,
                mutedText,
                lineColor,
              ),
              pw.SizedBox(width: 8),
              _summaryCard(
                'Payments Logged',
                '$grandPaymentCount',
                accent,
                baseFont,
                boldFont,
                darkText,
                mutedText,
                lineColor,
              ),
            ],
          ),
          pw.SizedBox(height: 24),

          // Per-loan index
          pw.Text(
            'Loans in this report',
            style: pw.TextStyle(
              font: boldFont,
              fontSize: 14,
              color: darkText,
            ),
          ),
          pw.SizedBox(height: 8),
          ...sortedLoans.asMap().entries.map((entry) {
            final i = entry.key + 1;
            final loan = entry.value;
            final paid = totalPaidByLoanId[loan.id] ?? 0;
            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 6),
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 10, vertical: 8),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: lineColor),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Row(
                children: [
                  pw.Container(
                    width: 22,
                    height: 22,
                    alignment: pw.Alignment.center,
                    decoration: pw.BoxDecoration(
                      color: neonGreen,
                      borderRadius: pw.BorderRadius.circular(11),
                    ),
                    child: pw.Text(
                      '$i',
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 10,
                        color: const PdfColor.fromInt(0xFFFFFFFF),
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          loan.title,
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: 12,
                            color: darkText,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Due ${_fmtDate(loan.dueDate)}'
                          '${loan.lenderName != null && loan.lenderName!.isNotEmpty ? "  •  ${loan.lenderName}" : ""}',
                          style: pw.TextStyle(
                            font: baseFont,
                            fontSize: 9,
                            color: mutedText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.Text(
                    'Ksh ${_fmt(paid)}',
                    style: pw.TextStyle(
                      font: boldFont,
                      fontSize: 12,
                      color: neonGreen,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );

    // ------------------------------------------------------------------
    // One page section per completed loan
    // ------------------------------------------------------------------
    for (final loan in sortedLoans) {
      final payments = paymentsByLoanId[loan.id] ?? const <Payment>[];
      final totalPaid = totalPaidByLoanId[loan.id] ?? 0.0;

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
                    'Completed Loan Report',
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
            // COMPLETED badge
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xFFE8F8E0),
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: neonGreen, width: 1.2),
              ),
              child: pw.Row(
                children: [
                  pw.Text(
                    '✓ COMPLETED',
                    style: pw.TextStyle(
                      font: boldFont,
                      fontSize: 12,
                      color: neonGreen,
                      letterSpacing: 1.5,
                    ),
                  ),
                  pw.Spacer(),
                  pw.Text(
                    'Closed on ${_fmtDate(loan.dueDate)}',
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

            // Loan title block
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
                  if (loan.lenderName != null &&
                      loan.lenderName!.isNotEmpty) ...[
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Lender: ${loan.lenderName}'
                      '${loan.lenderPhone != null && loan.lenderPhone!.isNotEmpty ? "  •  ${loan.lenderPhone}" : ""}',
                      style: pw.TextStyle(
                        font: baseFont,
                        fontSize: 10,
                        color: mutedText,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Totals row
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
                  'Ksh 0.00',
                  neonGreen,
                  baseFont,
                  boldFont,
                  darkText,
                  mutedText,
                  lineColor,
                ),
                pw.SizedBox(width: 8),
                _summaryCard(
                  'Payments',
                  '${payments.length}',
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
            _progressBar(1.0, neonGreen, lineColor),
            pw.SizedBox(height: 24),

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
              '${payments.length} payment${payments.length == 1 ? "" : "s"} recorded',
              style: pw.TextStyle(
                font: baseFont,
                fontSize: 10,
                color: mutedText,
              ),
            ),
            pw.SizedBox(height: 12),

            _transactionsTable(
              List<Payment>.from(payments)
                ..sort((a, b) => a.paidAt.compareTo(b.paidAt)),
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
    }

    return doc;
  }

  /// Build the PDF document.
  static Future<pw.Document> _buildDocument({
    required Loan loan,
    required List<Payment> payments,
    required double totalPaid,
    bool isMonthlyStatement = false,
    int? statementYear,
    int? statementMonth,
    double? allTimeTotalPaid,
  }) async {
    final doc = pw.Document(pageMode: PdfPageMode.fullscreen);

    // Sort payments oldest-first for the report (more natural reading order)
    final sorted = List<Payment>.from(payments)
      ..sort((a, b) => a.paidAt.compareTo(b.paidAt));

    final balance = loan.totalPayable - totalPaid;
    // `progress` is kept for clarity but the effective progress (which
    // respects all-time total in monthly statements) is what gets rendered.
    // ignore: unused_local_variable
    final progress = loan.totalPayable > 0
        ? (totalPaid / loan.totalPayable).clamp(0.0, 1.0).toDouble()
        : 0.0;

    // For monthly statements, the balance shown is computed from all-time
    // totals, not just this month's payments.
    final effectiveBalance = isMonthlyStatement && allTimeTotalPaid != null
        ? (loan.totalPayable - allTimeTotalPaid).clamp(0.0, double.infinity)
        : balance;
    final effectiveProgress = loan.totalPayable > 0
        ? ((allTimeTotalPaid ?? totalPaid) / loan.totalPayable)
            .clamp(0.0, 1.0)
            .toDouble()
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

    final statementPeriodLabel = (isMonthlyStatement &&
            statementYear != null &&
            statementMonth != null)
        ? '${DateFormat('MMMM y').format(DateTime(statementYear, statementMonth))} Statement'
        : 'Repayment Report';

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
                  statementPeriodLabel,
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
                isMonthlyStatement ? 'Paid this month' : 'Total Paid',
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
                'Ksh ${_fmt(effectiveBalance < 0 ? 0 : effectiveBalance)}',
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
                '${(effectiveProgress * 100).toStringAsFixed(1)}%',
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
          _progressBar(effectiveProgress, neonGreen, lineColor),
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
