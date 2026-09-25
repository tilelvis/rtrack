import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/payment.dart';
import '../providers/loan_provider.dart';
import '../services/daily_payment_calculator.dart';
import '../services/mpesa_parser.dart';
import '../theme/app_tokens.dart';
import '../theme/theme.dart';
import 'app_components.dart';

/// Main dashboard — the "hero" loan summary card.
///
/// Layout (top to bottom):
///   1. Borrower name + due date
///   2. Balance remaining (large amount) + animated progress ring
///   3. Mini progress bar
///   4. Today-paid status chip
///   5. Three metric cards: Paid / Total / Days Left
///   6. Primary payment action card (Pay Ksh X today)
///   7. Lender contact chip (if lender info is set)
class DashboardCard extends StatelessWidget {
  const DashboardCard({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LoanProvider>();
    final loan = provider.activeLoan;
    if (loan == null) return const SizedBox.shrink();

    final progress = provider.progress;
    final balance = provider.balanceRemaining;
    final days = loan.daysRemaining;
    final totalPaid = provider.totalPaid;
    final todayPaid = provider.todayPaid;
    final tokens = Theme.of(context).extension<LoanTrackerDesignTokens>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ------------------------------------------------------------------
        // HERO CARD — loan summary with progress ring
        // ------------------------------------------------------------------
        AppCard.tinted(
          tintColor: tokens.brandSurface,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Borrower + due date row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BORROWER',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          loan.lenderName ?? loan.title,
                          style: Theme.of(context).textTheme.titleLarge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'DUE',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('d MMM y').format(loan.dueDate),
                        style: TextStyle(fontFamily: "JetBrainsMono", 
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // Balance remaining — full width (no donut)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BALANCE REMAINING',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(height: 4),
                  // Large financial amount — most prominent thing on screen
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      MpesaParser.formatKes(balance),
                      style: TextStyle(fontFamily: "JetBrainsMono", 
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // Mini progress bar
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: progress),
                    duration: AppDurations.slow,
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: value,
                          minHeight: 6,
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          color: tokens.brandSuccess,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${(progress * 100).toStringAsFixed(0)}% repaid',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: tokens.brandSuccess,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Compact recent payments list (no cards, just rows on top
              // of the hero card surface)
              if (provider.recentPayments.isNotEmpty) ...[
                Text(
                  'RECENT PAYMENTS',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                ...provider.recentPayments.take(3).map((p) => _CompactPaymentRow(
                      payment: p,
                    )),
                const SizedBox(height: AppSpacing.md),
              ],

              // Today status row
              Row(
                children: [
                  StatusChip(
                    label: todayPaid ? 'PAID TODAY' : 'PENDING TODAY',
                    variant: todayPaid
                        ? StatusChipVariant.success
                        : StatusChipVariant.warning,
                    icon: todayPaid ? Icons.check_circle : Icons.schedule,
                  ),
                  const Spacer(),
                  if (loan.hasLenderContact)
                    IconBubble(
                      icon: Icons.person,
                      color: Theme.of(context).colorScheme.secondary,
                      size: 28,
                      iconSize: 14,
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // ------------------------------------------------------------------
        // METRICS ROW — Paid / Total / Days Left
        // ------------------------------------------------------------------
        Row(
          children: [
            Expanded(
              child: MetricCard(
                label: 'PAID',
                value: MpesaParser.formatKes(totalPaid),
                icon: Icons.savings_outlined,
                tintColor: tokens.successSurface,
                iconColor: tokens.brandSuccess,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: MetricCard(
                label: 'TOTAL',
                value: MpesaParser.formatKes(loan.totalPayable),
                icon: Icons.account_balance_wallet_outlined,
                tintColor: tokens.neutralSurface,
                iconColor: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: MetricCard(
                label: 'DAYS LEFT',
                value: '$days',
                icon: Icons.event_outlined,
                tintColor: days <= 3
                    ? tokens.dangerSurface
                    : days <= 7
                        ? tokens.warningSurface
                        : tokens.neutralSurface,
                iconColor: days <= 3
                    ? tokens.danger
                    : days <= 7
                        ? tokens.warning
                        : Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // ------------------------------------------------------------------
        // PAYMENT ACTION CARD — primary CTA with intelligent daily recommendation
        // ------------------------------------------------------------------
        _PaymentActionCard(
          amount: loan.expectedPerInterval,
          paid: todayPaid,
          recommendation: provider.dailyRecommendation,
        ),
        const SizedBox(height: AppSpacing.md),

        // Lender contact chip (if set)
        if (loan.hasLenderContact)
          _LenderContactChip(
            name: loan.lenderName ?? 'Lender',
            phone: loan.lenderPhone,
          ),
      ],
    );
  }
}

/// Compact payment row — shows date + amount inline, no card wrapper.
/// Used inside the hero card to list recent payments directly on the
/// tinted surface (keeps the dashboard compact — no extra card chrome).
class _CompactPaymentRow extends StatelessWidget {
  final Payment payment;

  const _CompactPaymentRow({required this.payment});

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<LoanTrackerDesignTokens>()!;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          // Date (compact: d MMM)
          SizedBox(
            width: 48,
            child: Text(
              DateFormat('d MMM').format(payment.paidAt),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),

          // M-Pesa code (if present) or source label
          if (payment.mpesaCode != null)
            Expanded(
              child: Text(
                payment.mpesaCode!,
                style: TextStyle(fontFamily: "JetBrainsMono",
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            )
          else
            Expanded(
              child: Text(
                payment.sender ?? 'Manual',
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

          // Amount — green, monospace, bold
          Text(
            'Ksh ${payment.amount.toStringAsFixed(0)}',
            style: TextStyle(fontFamily: "JetBrainsMono",
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: tokens.brandSuccess,
            ),
          ),
        ],
      ),
    );
  }
}

/// Primary payment action card — prominent CTA showing the intelligent
/// daily recommendation.
///
/// When the loan is fully paid, shows a celebratory state.
/// When payment is overdue, shows a CRITICAL alert with the full balance.
/// Otherwise shows: "Pay Ksh X daily — N days left, Ksh Y remaining".
class _PaymentActionCard extends StatelessWidget {
  final double amount;
  final bool paid;
  final DailyPaymentRecommendation? recommendation;

  const _PaymentActionCard({
    required this.amount,
    required this.paid,
    this.recommendation,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = Theme.of(context).extension<LoanTrackerDesignTokens>()!;
    final text = Theme.of(context).textTheme;
    final rec = recommendation;

    // ----------------------------------------------------------------
    // Fully paid — celebratory state
    // ----------------------------------------------------------------
    if (rec != null && rec.severity == RecommendationSeverity.paid) {
      return AppCard.tinted(
        tintColor: tokens.successSurface,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            IconBubble(
              icon: Icons.celebration,
              color: tokens.brandSuccess,
              size: 44,
              iconSize: 22,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Loan fully paid', style: text.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    rec.message,
                    style: text.bodySmall?.copyWith(
                      color: tokens.onSuccessContainer.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // ----------------------------------------------------------------
    // Today already paid — show next-day recommendation
    // ----------------------------------------------------------------
    if (paid && rec != null) {
      return AppCard.tinted(
        tintColor: tokens.successSurface,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            IconBubble(
              icon: Icons.check_circle,
              color: tokens.brandSuccess,
              size: 44,
              iconSize: 22,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Paid today — nice work!',
                    style: text.titleMedium?.copyWith(
                      color: tokens.onSuccessContainer,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    rec.daysRemaining > 0
                        ? 'Tomorrow: Ksh ${rec.dailyAmount.toStringAsFixed(0)}/day × ${rec.daysRemaining} days'
                        : 'Loan cleared 🎉',
                    style: text.bodySmall?.copyWith(
                      color: tokens.onSuccessContainer.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // ----------------------------------------------------------------
    // Critical / overdue — red alert
    // ----------------------------------------------------------------
    if (rec != null && rec.severity == RecommendationSeverity.critical) {
      return AppCard.tinted(
        tintColor: tokens.dangerSurface,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            IconBubble(
              icon: Icons.warning_rounded,
              color: tokens.danger,
              size: 44,
              iconSize: 22,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rec.daysRemaining == 0
                        ? 'OVERDUE — pay today'
                        : 'Critical — only ${rec.daysRemaining} day${rec.daysRemaining == 1 ? '' : 's'} left',
                    style: text.titleMedium?.copyWith(
                      color: tokens.onDangerContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pay Ksh ${rec.dailyAmount.toStringAsFixed(0)} today to clear Ksh ${rec.remainingBalance.toStringAsFixed(0)}',
                    style: text.bodySmall?.copyWith(
                      color: tokens.onDangerContainer.withOpacity(0.85),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    rec.message,
                    style: text.bodySmall?.copyWith(
                      color: tokens.onDangerContainer.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // ----------------------------------------------------------------
    // Normal / moderate / elevated — show daily recommendation
    // ----------------------------------------------------------------
    final Color tintColor;
    final Color iconColor;
    final Color onTintColor;
    final IconData iconData;
    switch (rec?.severity) {
      case RecommendationSeverity.elevated:
        tintColor = tokens.warningSurface;
        iconColor = tokens.warning;
        onTintColor = tokens.onWarningContainer;
        iconData = Icons.priority_high;
        break;
      case RecommendationSeverity.moderate:
        tintColor = scheme.primaryContainer;
        iconColor = scheme.primary;
        onTintColor = scheme.onPrimaryContainer;
        iconData = Icons.bolt_outlined;
        break;
      case RecommendationSeverity.normal:
      default:
        tintColor = scheme.primaryContainer;
        iconColor = scheme.primary;
        onTintColor = scheme.onPrimaryContainer;
        iconData = Icons.bolt_outlined;
        break;
    }

    return AppCard.tinted(
      tintColor: tintColor,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBubble(
                icon: iconData,
                color: iconColor,
                size: 44,
                iconSize: 22,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rec != null
                          ? 'Pay Ksh ${rec.dailyAmount.toStringAsFixed(0)} today'
                          : 'Pay Ksh ${amount.toStringAsFixed(0)} today',
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: onTintColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      rec?.message ??
                          'Keep your plan on track',
                      style: text.bodySmall?.copyWith(
                        color: onTintColor.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: onTintColor),
            ],
          ),
          if (rec != null && rec.daysRemaining > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            // Visual breakdown bar
            Row(
              children: [
                Expanded(
                  flex: rec.daysRemaining,
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: iconColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '${rec.daysRemaining} day${rec.daysRemaining == 1 ? '' : 's'} × '
                  'Ksh ${rec.dailyAmount.toStringAsFixed(0)}/day',
                  style: text.labelSmall?.copyWith(color: onTintColor),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Lender contact chip — tappable to open lender actions sheet.
class _LenderContactChip extends StatelessWidget {
  final String name;
  final String? phone;

  const _LenderContactChip({required this.name, this.phone});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.mdSm,
      ),
      onTap: () {
        // Open lender actions — handled by parent
      },
      child: Row(
        children: [
          IconBubble(
            icon: Icons.person_outline,
            color: scheme.secondary,
            size: 36,
            iconSize: 18,
          ),
          const SizedBox(width: AppSpacing.mdSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LENDER',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (phone != null) ...[
            const SizedBox(width: AppSpacing.sm),
            IconBubble(
              icon: Icons.phone_outlined,
              color: scheme.primary,
              size: 32,
              iconSize: 16,
            ),
            const SizedBox(width: AppSpacing.xs),
            IconBubble(
              icon: Icons.chat_outlined,
              color: scheme.primary,
              size: 32,
              iconSize: 16,
            ),
          ],
        ],
      ),
    );
  }
}
