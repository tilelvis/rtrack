import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/payment.dart';
import '../providers/loan_provider.dart';
import '../services/mpesa_parser.dart';
import '../services/payment_receipt_service.dart';
import '../theme/theme.dart';

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
                color: Theme.of(context).colorScheme.secondary.withOpacity(0.4),
              ),
              const SizedBox(height: 16),
              Text(
                'No payments logged yet',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Tap "Log Payment" to paste an M-Pesa SMS.',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final listView = ListView.separated(
      padding: EdgeInsets.fromLTRB(16, embedded ? 0 : 16, 16, embedded ? 0 : 96),
      itemCount: list.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
      itemBuilder: (context, i) {
        final p = list[i];
        return _PaymentTile(payment: p, provider: provider);
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
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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

class _PaymentTile extends StatelessWidget {
  final Payment payment;
  final LoanProvider provider;

  const _PaymentTile({required this.payment, required this.provider});

  @override
  Widget build(BuildContext context) {
    final isMpesa = payment.source == PaymentSource.mpesa;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: (isMpesa ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.secondary).withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (isMpesa ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.secondary).withOpacity(0.5),
          ),
        ),
        child: Icon(
          isMpesa ? Icons.phone_iphone : Icons.edit,
          color: isMpesa ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.secondary,
          size: 20,
        ),
      ),
      title: Text(
        MpesaParser.formatKes(payment.amount),
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Text(
            DateFormat('d MMM y • h:mm a').format(payment.paidAt),
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
          ),
          if (payment.mpesaCode != null || payment.sender != null) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (payment.mpesaCode != null)
                  Chip(
                    label: Text(
                      payment.mpesaCode!,
                      style: const TextStyle(fontSize: 11),
                    ),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    labelStyle: TextStyle(color: Theme.of(context).colorScheme.secondary),
                  ),
                if (payment.sender != null)
                  Text(
                    payment.sender!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Theme.of(context).colorScheme.secondary, size: 20),
            tooltip: 'Share payment proof',
            onPressed: () async {
              final loan = provider.activeLoan;
              if (loan == null) return;
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
                      SizedBox(width: 12),
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
                  totalPaidAfter: provider.totalPaid,
                );
                messenger.hideCurrentSnackBar();
              } catch (e) {
                messenger.hideCurrentSnackBar();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Failed: $e'),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error, size: 20),
            tooltip: 'Delete payment',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  title: const Text('Delete payment?'),
                  content: Text(
                    'This will remove Ksh ${payment.amount.toStringAsFixed(2)} from your history.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await provider.deletePayment(payment.id);
              }
            },
          ),
        ],
      ),
      isThreeLine: true,
    );
  }
}
