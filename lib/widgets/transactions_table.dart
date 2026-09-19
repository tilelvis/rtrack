import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/payment.dart';
import '../providers/loan_provider.dart';
import '../theme/app_tokens.dart';
import '../theme/theme.dart';
import 'app_components.dart';

/// Compact transactions table for the home dashboard.
///
/// Renders as a Card containing a Material 3 list of payments with:
///   - Date + time (stacked)
///   - M-Pesa code (monospace, brand-colored)
///   - Sender (italic, muted)
///   - Amount (large, success-colored)
///   - Type badge (M-P / MAN)
class TransactionsTable extends StatelessWidget {
  final int limit;
  final bool showAll;

  const TransactionsTable({
    super.key,
    this.limit = 8,
    this.showAll = false,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LoanProvider>();
    final payments = provider.recentPayments;
    final list = showAll ? payments : payments.take(limit).toList();

    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Transactions',
            subtitle: payments.isEmpty ? null : '${payments.length} total',
          ),
          const SizedBox(height: AppSpacing.xs),
          if (payments.isEmpty)
            _emptyState(context)
          else
            AnimatedSwitcher(
              duration: AppDurations.medium,
              child: Column(
                key: ValueKey(list.length),
                children: list
                    .map((p) => _TransactionTile(payment: p))
                    .toList(),
              ),
            ),
          if (!showAll && payments.length > limit)
            Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.xs,
                bottom: AppSpacing.sm,
              ),
              child: Center(
                child: TextButton(
                  onPressed: () {
                    // Switch to Payments tab — handled by parent
                  },
                  child: const Text('View all'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 36,
            color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'No transactions yet',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap "Log Payment" to record your first payment.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final Payment payment;

  const _TransactionTile({required this.payment});

  @override
  Widget build(BuildContext context) {
    final isMpesa = payment.source == PaymentSource.mpesa;
    final tokens = Theme.of(context).extension<LoanTrackerDesignTokens>()!;

    return InkWell(
      onTap: () {
        // Could open receipt / details
      },
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.mdSm,
          horizontal: AppSpacing.xs,
        ),
        child: Row(
          children: [
            // Date + time stacked
            SizedBox(
              width: 56,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${payment.paidAt.day}/${payment.paidAt.month}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${payment.paidAt.hour.toString().padLeft(2, '0')}:'
                    '${payment.paidAt.minute.toString().padLeft(2, '0')}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.mdSm),

            // M-Pesa code + sender
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (payment.mpesaCode != null)
                    Text(
                      payment.mpesaCode!,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.primary,
                        letterSpacing: 0.3,
                      ),
                    )
                  else
                    Text(
                      'Manual',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                  if (payment.sender != null &&
                      payment.sender!.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      payment.sender!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),

            // Amount
            Text(
              'Ksh ${payment.amount.toStringAsFixed(0)}',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: tokens.brandSuccess,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),

            // Type badge
            StatusChip(
              label: isMpesa ? 'M-P' : 'MAN',
              variant: isMpesa ? StatusChipVariant.brand : StatusChipVariant.neutral,
            ),
          ],
        ),
      ),
    );
  }
}
