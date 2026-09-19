import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/loan_provider.dart';
import '../theme/theme.dart';

/// Reusable payment history list widget.
/// Shows recent payments for the active loan.
class PaymentHistoryList extends StatelessWidget {
  final int? limit;
  final bool embedded;

  const PaymentHistoryList({super.key, this.limit, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LoanProvider>();
    final payments = provider.recentPayments;
    final list = limit != null ? payments.take(limit!).toList() : payments;

    if (payments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 64,
                color: AppTheme.accent.withOpacity(0.4),
              ),
              const SizedBox(height: 16),
              Text(
                'No payments logged yet',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Tap "Log Payment" to paste an M-Pesa SMS.',
                style: TextStyle(color: AppTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final listView = ListView.separated(
      padding: EdgeInsets.fromLTRB(
        16,
        embedded ? 0 : 16,
        16,
        embedded ? 0 : 96,
      ),
      itemCount: list.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1, color: AppTheme.border),
      itemBuilder: (context, i) {
        final p = list[i];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (p.source.name == 'mpesa'
                      ? AppTheme.primary
                      : AppTheme.accent)
                  .withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (p.source.name == 'mpesa'
                        ? AppTheme.primary
                        : AppTheme.accent)
                    .withOpacity(0.5),
              ),
            ),
            child: Icon(
              p.source.name == 'mpesa'
                  ? Icons.phone_iphone
                  : Icons.edit,
              color: p.source.name == 'mpesa'
                  ? AppTheme.primary
                  : AppTheme.accent,
              size: 20,
            ),
          ),
          title: Text(
            'Ksh ${p.amount.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              Text(
                '${p.paidAt.day}/${p.paidAt.month}/${p.paidAt.year} • '
                '${p.paidAt.hour.toString().padLeft(2, '0')}:'
                '${p.paidAt.minute.toString().padLeft(2, '0')}',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
              if (p.mpesaCode != null) ...[
                const SizedBox(height: 4),
                Text(
                  p.mpesaCode!,
                  style: const TextStyle(
                    color: AppTheme.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
          isThreeLine: true,
        );
      },
    );

    if (embedded) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent payments',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '${payments.length} total',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              listView,
            ],
          ),
        ),
      );
    }
    return listView;
  }
}
