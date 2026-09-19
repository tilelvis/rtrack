import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/loan_provider.dart';
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

              // Balance + progress ring
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
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
                  ),
                  const SizedBox(width: AppSpacing.md),
                  // Animated progress ring
                  _ProgressRing(progress: progress),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

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
        // PAYMENT ACTION CARD — primary CTA
        // ------------------------------------------------------------------
        _PaymentActionCard(
          amount: loan.expectedPerInterval,
          paid: todayPaid,
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

/// Animated circular progress ring with percentage in the center.
class _ProgressRing extends StatelessWidget {
  final double progress;

  const _ProgressRing({required this.progress});

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<LoanTrackerDesignTokens>()!;
    final scheme = Theme.of(context).colorScheme;
    final size = 72.0;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: progress),
            duration: AppDurations.hero,
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return CircularProgressIndicator(
                value: value,
                strokeWidth: 6,
                strokeCap: StrokeCap.round,
                color: tokens.brandSuccess,
                backgroundColor: scheme.surfaceContainerHighest,
              );
            },
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(fontFamily: "JetBrainsMono", 
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
              Text(
                'REPAID',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Primary payment action card — prominent CTA for "Pay Ksh X today".
class _PaymentActionCard extends StatelessWidget {
  final double amount;
  final bool paid;

  const _PaymentActionCard({required this.amount, required this.paid});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = Theme.of(context).extension<LoanTrackerDesignTokens>()!;
    final text = Theme.of(context).textTheme;

    return AppCard.tinted(
      tintColor: paid ? tokens.successSurface : scheme.primaryContainer,
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: () {
        // Navigate to M-Pesa paste screen — handled by parent via Hero tap
      },
      child: Row(
        children: [
          IconBubble(
            icon: paid ? Icons.check_circle : Icons.bolt_outlined,
            color: paid ? tokens.brandSuccess : scheme.primary,
            size: 44,
            iconSize: 22,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  paid
                      ? 'Payment done today'
                      : 'Pay Ksh ${amount.toStringAsFixed(0)} today',
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: paid
                        ? tokens.onSuccessContainer
                        : scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  paid
                      ? 'Great work — see you tomorrow'
                      : 'Keep your plan on track',
                  style: text.bodySmall?.copyWith(
                    color: paid
                        ? tokens.onSuccessContainer.withOpacity(0.7)
                        : scheme.onPrimaryContainer.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: paid
                ? tokens.onSuccessContainer
                : scheme.onPrimaryContainer,
          ),
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
