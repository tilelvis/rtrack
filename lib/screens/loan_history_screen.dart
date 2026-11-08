import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/loan.dart';
import '../models/payment.dart';
import '../providers/loan_provider.dart';
import '../providers/theme_provider.dart';
import '../services/mpesa_parser.dart';
import '../services/payment_receipt_service.dart';
import '../services/pdf_report_service.dart';
import '../theme/app_tokens.dart';
import '../theme/theme.dart';
import '../widgets/app_components.dart';

/// Dedicated Loan History screen — a chronological record of every loan
/// the user has tracked, organised into three sections:
///
///   1. **Active** — visible loans that still have an outstanding balance
///      or whose due date is still in the future.
///   2. **Completed** — visible loans whose due date has passed and which
///      have been fully paid off. These used to be auto-hidden in earlier
///      versions; now they are preserved here as a permanent repayment log.
///   3. **Hidden** — loans the user has manually hidden (and can restore).
///
/// Each loan renders as an expandable card. Tapping the chevron reveals
/// the full payment list for that loan — dates, amounts, M-Pesa codes,
/// sources. From any expanded loan the user can:
///   - Share a payment receipt (per row)
///   - Generate a full PDF report (per loan)
///   - Make that loan the active one (so the dashboard jumps to it)
///   - Hide / unhide / permanently delete the loan
class LoanHistoryScreen extends StatefulWidget {
  const LoanHistoryScreen({super.key});

  @override
  State<LoanHistoryScreen> createState() => _LoanHistoryScreenState();
}

class _LoanHistoryScreenState extends State<LoanHistoryScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Filter loans by the search box (matches title, lender name, or notes).
  List<Loan> _filter(List<Loan> loans) {
    if (_query.isEmpty) return loans;
    final q = _query.toLowerCase();
    return loans.where((l) {
      final hay = [
        l.title,
        l.lenderName ?? '',
        l.notes ?? '',
        l.keyword ?? '',
      ].join(' ').toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LoanProvider>();
    final scheme = Theme.of(context).colorScheme;
    final tokens = Theme.of(context).extension<LoanTrackerDesignTokens>()!;

    final active = _filter(provider.activeLoans);
    final completed = _filter(provider.completedLoans);
    final hidden = _filter(provider.hiddenLoans);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.history_rounded,
                size: 22, color: scheme.primary),
            const SizedBox(width: AppSpacing.sm),
            const Text('Loan History'),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_themeIcon(context),
                color: scheme.onSurfaceVariant),
            tooltip: 'Toggle theme',
            onPressed: () => _cycleTheme(context),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Search bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH, AppSpacing.sm, AppSpacing.screenH, 0,
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v.trim()),
                decoration: InputDecoration(
                  hintText: 'Search by name, lender, or notes',
                  prefixIcon: const Icon(Icons.search_outlined, size: 20),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  isDense: true,
                ),
              ),
            ),
          ),

          // Stats summary
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH, AppSpacing.md, AppSpacing.screenH, 0,
              ),
              child: _StatsRow(
                active: active.length,
                completed: completed.length,
                hidden: hidden.length,
              ),
            ),
          ),

          // "Download completed PDFs" CTA — only when there's at least one
          // completed loan to export. Generates a single combined PDF that
          // covers every completed loan in one document.
          if (provider.completedLoans.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH, AppSpacing.md, AppSpacing.screenH, 0,
                ),
                child: _CompletedLoansPdfCta(
                  count: provider.completedLoans.length,
                  totalRepaid: provider.completedLoans.fold<double>(
                    0,
                    (s, l) =>
                        s + (provider.loanTotals[l.id] ?? 0),
                  ),
                  onTap: () => _generateCompletedPdf(provider),
                ),
              ),
            ),

          // Active section
          if (active.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _SectionHeader(
                label: 'ACTIVE',
                count: active.length,
                color: scheme.primary,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH, AppSpacing.xs, AppSpacing.screenH, 0,
              ),
              sliver: SliverList.separated(
                itemCount: active.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (_, i) => _LoanHistoryCard(
                  loan: active[i],
                  totalPaid: provider.loanTotals[active[i].id] ?? 0,
                  defaultExpanded: active.length == 1 &&
                      provider.activeLoan?.id == active[i].id,
                ),
              ),
            ),
          ],

          // Completed section
          if (completed.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _SectionHeader(
                label: 'COMPLETED',
                count: completed.length,
                color: tokens.brandSuccess,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH, AppSpacing.xs, AppSpacing.screenH, 0,
              ),
              sliver: SliverList.separated(
                itemCount: completed.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (_, i) => _LoanHistoryCard(
                  loan: completed[i],
                  totalPaid: provider.loanTotals[completed[i].id] ?? 0,
                  defaultExpanded: false,
                ),
              ),
            ),
          ],

          // Hidden section
          if (hidden.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _SectionHeader(
                label: 'HIDDEN',
                count: hidden.length,
                color: scheme.onSurfaceVariant,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH, AppSpacing.xs, AppSpacing.screenH, 0,
              ),
              sliver: SliverList.separated(
                itemCount: hidden.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (_, i) => _LoanHistoryCard(
                  loan: hidden[i],
                  totalPaid: provider.loanTotals[hidden[i].id] ?? 0,
                  defaultExpanded: false,
                ),
              ),
            ),
          ],

          // Empty state — no loans at all
          if (active.isEmpty &&
              completed.isEmpty &&
              hidden.isEmpty) ...[
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyHistoryState(query: _query),
            ),
          ] else ...[
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
            const SliverToBoxAdapter(child: SizedBox(height: 96)),
          ],
        ],
      ),
    );
  }

  // ---- Theme helpers (mirror home_screen) ----
  IconData _themeIcon(BuildContext context) {
    final themeProvider = context.read<ThemeProvider>();
    switch (themeProvider.mode) {
      case AppThemeMode.light:
        return Icons.light_mode_outlined;
      case AppThemeMode.dark:
        return Icons.dark_mode_outlined;
      case AppThemeMode.system:
        return Icons.brightness_auto_outlined;
    }
  }

  void _cycleTheme(BuildContext context) {
    final themeProvider = context.read<ThemeProvider>();
    final AppThemeMode next;
    switch (themeProvider.mode) {
      case AppThemeMode.system:
        next = AppThemeMode.light;
        break;
      case AppThemeMode.light:
        next = AppThemeMode.dark;
        break;
      case AppThemeMode.dark:
        next = AppThemeMode.system;
        break;
    }
    themeProvider.setMode(next);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(_themeIcon(context), size: 18),
              const SizedBox(width: AppSpacing.sm),
              Text('Theme: ${next.label}'),
            ],
          ),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          width: 220,
        ),
      );
  }

  /// Generate a single PDF covering EVERY completed loan (lifetime
  /// repayment record). Fetches each loan's payment list in parallel and
  /// hands everything to PdfReportService.generateCompletedLoansPdfAndShare.
  Future<void> _generateCompletedPdf(LoanProvider provider) async {
    final messenger = ScaffoldMessenger.of(context);
    final completed = provider.completedLoans;

    if (completed.isEmpty) return;

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text('Generating PDF for ${completed.length} completed '
                'loan${completed.length == 1 ? "" : "s"}...'),
          ],
        ),
        duration: const Duration(seconds: 30),
      ),
    );

    try {
      // Fetch payments for each completed loan in parallel — no N+1 delay.
      final paymentLists = await Future.wait(
        completed.map((l) => provider.getPaymentsForLoan(l.id)),
      );
      final paymentsByLoanId = <String, List<Payment>>{};
      final totalPaidByLoanId = <String, double>{};
      for (var i = 0; i < completed.length; i++) {
        final loan = completed[i];
        final list = paymentLists[i];
        paymentsByLoanId[loan.id] = list;
        totalPaidByLoanId[loan.id] = provider.loanTotals[loan.id] ??
            list.fold<double>(0, (s, p) => s + p.amount);
      }

      await PdfReportService.generateCompletedLoansPdfAndShare(
        completedLoans: completed,
        paymentsByLoanId: paymentsByLoanId,
        totalPaidByLoanId: totalPaidByLoanId,
      );
      // Capture the error color BEFORE the await so we don't reference
      // BuildContext across an async gap. If the widget unmounted in the
      // meantime, skip the snackbar entirely.
      if (!mounted) return;
      final successColor = Theme.of(context).colorScheme.primary;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Completed loans PDF ready — share or save it.'),
          backgroundColor: successColor,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final errColor = Theme.of(context).colorScheme.error;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to generate PDF: $e'),
          backgroundColor: errColor,
        ),
      );
    }
  }
}

/// Stats strip showing counts of active / completed / hidden loans.
class _StatsRow extends StatelessWidget {
  final int active;
  final int completed;
  final int hidden;

  const _StatsRow({
    required this.active,
    required this.completed,
    required this.hidden,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = Theme.of(context).extension<LoanTrackerDesignTokens>()!;
    final total = active + completed + hidden;

    return AppCard.tinted(
      tintColor: scheme.surfaceContainerHigh,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md, vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          _StatPill(
            label: 'Total',
            value: '$total',
            color: scheme.onSurface,
            bg: scheme.surfaceContainerHighest,
          ),
          const SizedBox(width: AppSpacing.sm),
          _StatPill(
            label: 'Active',
            value: '$active',
            color: scheme.primary,
            bg: scheme.primaryContainer.withValues(alpha: 0.4),
          ),
          const SizedBox(width: AppSpacing.sm),
          _StatPill(
            label: 'Completed',
            value: '$completed',
            color: tokens.brandSuccess,
            bg: tokens.successSurface,
          ),
          const SizedBox(width: AppSpacing.sm),
          _StatPill(
            label: 'Hidden',
            value: '$hidden',
            color: scheme.onSurfaceVariant,
            bg: scheme.surfaceContainerHighest,
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color bg;

  const _StatPill({
    required this.label,
    required this.value,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs, vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color.withValues(alpha: 0.85),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small "ACTIVE / COMPLETED / HIDDEN" header with a count chip.
class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _SectionHeader({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH, AppSpacing.lg, AppSpacing.screenH, AppSpacing.xs,
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            margin: const EdgeInsets.only(right: AppSpacing.sm),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Expandable loan card showing loan summary + payment history inline.
class _LoanHistoryCard extends StatefulWidget {
  final Loan loan;
  final double totalPaid;
  final bool defaultExpanded;

  const _LoanHistoryCard({
    required this.loan,
    required this.totalPaid,
    required this.defaultExpanded,
  });

  @override
  State<_LoanHistoryCard> createState() => _LoanHistoryCardState();
}

class _LoanHistoryCardState extends State<_LoanHistoryCard> {
  bool _expanded = false;
  List<Payment>? _payments;
  bool _loadingPayments = false;

  @override
  void initState() {
    super.initState();
    _expanded = widget.defaultExpanded;
    if (_expanded) _loadPayments();
  }

  Future<void> _loadPayments() async {
    if (_payments != null) return;
    setState(() => _loadingPayments = true);
    final provider = context.read<LoanProvider>();
    final list = await provider.getPaymentsForLoan(widget.loan.id);
    if (mounted) {
      setState(() {
        _payments = list;
        _loadingPayments = false;
      });
    }
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded && _payments == null) _loadPayments();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = Theme.of(context).extension<LoanTrackerDesignTokens>()!;
    final text = Theme.of(context).textTheme;
    final loan = widget.loan;
    final paid = widget.totalPaid;
    final total = loan.totalPayable;
    // clamp() on a double returns num, so cast explicitly to double to
    // satisfy downstream `double` parameter sites (e.g. _buildExpanded).
    final balance =
        (total - paid).clamp(0.0, double.infinity).toDouble();
    final progress =
        (total > 0 ? (paid / total).clamp(0.0, 1.0) : 0.0).toDouble();
    final isCompleted = paid >= total && total > 0;
    final isOverdue = DateTime.now().isAfter(loan.dueDate) && !isCompleted;

    // Status color + label
    final Color statusColor;
    final String statusLabel;
    final IconData statusIcon;
    if (loan.isHidden) {
      statusColor = scheme.onSurfaceVariant;
      statusLabel = 'Hidden';
      statusIcon = Icons.visibility_off_outlined;
    } else if (isCompleted) {
      statusColor = tokens.brandSuccess;
      statusLabel = 'Completed';
      statusIcon = Icons.check_circle;
    } else if (isOverdue) {
      statusColor = tokens.danger;
      statusLabel = 'Overdue';
      statusIcon = Icons.warning_rounded;
    } else {
      statusColor = scheme.primary;
      statusLabel = 'Active';
      statusIcon = Icons.radio_button_checked;
    }

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row — tap to expand
          InkWell(
            onTap: _toggle,
            // NOTE: borderRadius is NOT const because it depends on the
            // runtime `_expanded` flag (changes the bottom-corner rounding
            // when the card is expanded vs collapsed).
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(AppRadii.xl),
              topRight: Radius.circular(AppRadii.xl),
              bottomLeft: _expanded
                  ? Radius.zero
                  : Radius.circular(AppRadii.xl),
              bottomRight: _expanded
                  ? Radius.zero
                  : Radius.circular(AppRadii.xl),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.md, AppSpacing.sm, AppSpacing.md,
              ),
              child: Row(
                children: [
                  // Status icon bubble
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
                    child: Icon(statusIcon, color: statusColor, size: 20),
                  ),
                  const SizedBox(width: AppSpacing.mdSm),
                  // Title + meta
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                loan.title,
                                style: text.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: scheme.onSurface,
                                  decoration: loan.isHidden
                                      ? TextDecoration.lineThrough
                                      : null,
                                  decorationColor: scheme.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            _StatusBadge(
                              label: statusLabel,
                              color: statusColor,
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (loan.lenderName != null &&
                                loan.lenderName!.isNotEmpty)
                              loan.lenderName!,
                            'Due ${DateFormat('d MMM y').format(loan.dueDate)}',
                          ].join(' • '),
                          style: text.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Chevron
                  AnimatedRotation(
                    turns: _expanded ? 0.25 : 0,
                    duration: AppDurations.medium,
                    child: Icon(Icons.chevron_right,
                        color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),

          // Expanded payment history
          AnimatedCrossFade(
            duration: AppDurations.medium,
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: _buildExpanded(
              loan: loan,
              paid: paid,
              total: total,
              balance: balance,
              progress: progress,
              statusColor: statusColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpanded({
    required Loan loan,
    required double paid,
    required double total,
    required double balance,
    required double progress,
    required Color statusColor,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = Theme.of(context).extension<LoanTrackerDesignTokens>()!;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md, 0, AppSpacing.md, AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(height: 1, color: scheme.outlineVariant),
          const SizedBox(height: AppSpacing.md),

          // Progress bar + breakdown
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: scheme.surfaceContainerHighest,
                    color: statusColor,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: text.labelSmall?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Three metric columns
          Row(
            children: [
              Expanded(
                child: _MetricCol(
                  label: 'PAID',
                  value: MpesaParser.formatKes(paid),
                  color: tokens.brandSuccess,
                ),
              ),
              Expanded(
                child: _MetricCol(
                  label: 'TOTAL',
                  value: MpesaParser.formatKes(total),
                  color: scheme.onSurface,
                ),
              ),
              Expanded(
                child: _MetricCol(
                  label: 'BALANCE',
                  value: MpesaParser.formatKes(balance),
                  color: balance == 0
                      ? tokens.brandSuccess
                      : scheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Action buttons row
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              if (!loan.isHidden)
                ActionChip(
                  avatar: const Icon(Icons.dashboard_outlined, size: 16),
                  label: const Text('Make active'),
                  onPressed: () =>
                      context.read<LoanProvider>().setActiveLoan(loan.id),
                ),
              ActionChip(
                avatar: Icon(
                  loan.isHidden
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 16,
                ),
                label: Text(loan.isHidden ? 'Unhide' : 'Hide'),
                onPressed: () {
                  final p = context.read<LoanProvider>();
                  if (loan.isHidden) {
                    p.unhideLoan(loan.id);
                  } else {
                    p.hideLoan(loan.id);
                  }
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                label: const Text('PDF report'),
                onPressed: () => _exportPdf(loan),
              ),
              ActionChip(
                avatar: Icon(Icons.delete_outline,
                    size: 16, color: scheme.error),
                label: Text('Delete',
                    style: TextStyle(color: scheme.error)),
                onPressed: () => _confirmDelete(loan),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),
          // Payments list header
          Row(
            children: [
              Icon(Icons.receipt_long_outlined,
                  size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'PAYMENTS',
                style: text.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${_payments?.length ?? 0} recorded',
                style: text.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),

          // Payments list
          ..._buildPaymentsList(),
        ],
      ),
    );
  }

  /// Build the payments list for the expanded card.
  /// Returns a list of widgets (possibly empty) — never null.
  List<Widget> _buildPaymentsList() {
    if (_loadingPayments) {
      return [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ];
    }
    if (_payments == null || _payments!.isEmpty) {
      final scheme = Theme.of(context).colorScheme;
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Center(
            child: Text(
              'No payments recorded for this loan yet.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ),
      ];
    }
    final loan = widget.loan;
    final paid = widget.totalPaid;
    return _payments!
        .map((p) => _PaymentRow(
              payment: p,
              loan: loan,
              totalPaidAfter: paid,
            ))
        .toList();
  }

  Future<void> _exportPdf(Loan loan) async {
    final provider = context.read<LoanProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final payments =
        _payments ?? await provider.getPaymentsForLoan(loan.id);

    messenger.showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: AppSpacing.sm),
            Text('Generating PDF report...'),
          ],
        ),
        duration: Duration(seconds: 10),
      ),
    );

    try {
      await PdfReportService.generateAndShare(
        loan: loan,
        payments: payments,
        totalPaid: widget.totalPaid,
      );
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(content: Text('PDF report ready — share or save it.')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to generate PDF: $e')),
      );
    }
  }

  Future<void> _confirmDelete(Loan loan) async {
    final provider = context.read<LoanProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete loan?'),
        content: Text(
          'This permanently removes "${loan.title}" and all of its '
          'payments. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await provider.closePaidLoan(loan.id);
    }
  }
}

/// A small status badge (rounded pill).
class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          color: color,
        ),
      ),
    );
  }
}

/// A small metric column inside the expanded loan card.
class _MetricCol extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricCol({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: text.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            )),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}

/// A single payment row inside the expanded loan card.
/// Reuses the same compact visual language as the dashboard's recent payments.
class _PaymentRow extends StatelessWidget {
  final Payment payment;
  final Loan loan;
  final double totalPaidAfter;

  const _PaymentRow({
    required this.payment,
    required this.loan,
    required this.totalPaidAfter,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = Theme.of(context).extension<LoanTrackerDesignTokens>()!;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          // Date
          SizedBox(
            width: 52,
            child: Text(
              DateFormat('d MMM').format(payment.paidAt),
              style: text.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          // Source / mpesa code
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (payment.mpesaCode != null)
                  Text(
                    payment.mpesaCode!,
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                    ),
                  )
                else
                  Text(
                    payment.sender ?? 'Manual',
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (payment.sender != null && payment.mpesaCode != null)
                  Text(
                    payment.sender!,
                    style: text.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          // Amount
          Text(
            'Ksh ${payment.amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: tokens.brandSuccess,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          // Share receipt
          IconButton(
            icon: Icon(Icons.share_outlined,
                size: 16, color: scheme.onSurfaceVariant),
            tooltip: 'Share receipt',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: () => _shareReceipt(context),
          ),
        ],
      ),
    );
  }

  Future<void> _shareReceipt(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: AppSpacing.sm),
            Text('Generating receipt...'),
          ],
        ),
        duration: Duration(seconds: 10),
      ),
    );
    try {
      await PaymentReceiptService.generateAndShare(
        loan: loan,
        payment: payment,
        totalPaidAfter: totalPaidAfter,
      );
      messenger.hideCurrentSnackBar();
    } catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    }
  }
}

/// Empty-state widget shown when the user has zero loans or when a search
/// returns no matches.
class _EmptyHistoryState extends StatelessWidget {
  final String query;
  const _EmptyHistoryState({required this.query});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final hasQuery = query.isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasQuery ? Icons.search_off : Icons.history_rounded,
              size: 64,
              color: scheme.primary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              hasQuery ? 'No matching loans' : 'No loans yet',
              style: text.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              hasQuery
                  ? 'Try a different search term.'
                  : 'Create your first loan from the Home screen — completed '
                    'loans will appear here as a permanent record.',
              textAlign: TextAlign.center,
              style: text.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

/// Call-to-action card that lets the user download a single combined PDF
/// of every completed loan. Only shown when there is at least one
/// completed loan.
class _CompletedLoansPdfCta extends StatelessWidget {
  final int count;
  final double totalRepaid;
  final VoidCallback onTap;

  const _CompletedLoansPdfCta({
    required this.count,
    required this.totalRepaid,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = Theme.of(context).extension<LoanTrackerDesignTokens>()!;
    final text = Theme.of(context).textTheme;

    return Material(
      color: tokens.successSurface,
      borderRadius: BorderRadius.circular(AppRadii.xl),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tokens.brandSuccess.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: Icon(Icons.picture_as_pdf_outlined,
                    size: 20, color: tokens.brandSuccess),
              ),
              const SizedBox(width: AppSpacing.mdSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Download completed loans PDF',
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$count loan${count == 1 ? "" : "s"} • '
                      'Ksh ${totalRepaid.toStringAsFixed(0)} repaid',
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton.icon(
                onPressed: onTap,
                style: FilledButton.styleFrom(
                  backgroundColor: tokens.brandSuccess,
                  foregroundColor: tokens.onSuccessContainer,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.mdSm,
                    vertical: AppSpacing.xs,
                  ),
                  minimumSize: const Size(0, 36),
                ),
                icon: const Icon(Icons.download_outlined, size: 16),
                label: const Text(
                  'Download',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
