import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/payment.dart';
import '../providers/loan_provider.dart';
import '../theme/theme.dart';

/// Compact transactions table shown on the home screen.
///
/// Renders a borderless data table with columns:
///   Date | Code | Amount | Type
/// Each row is tappable for future detail expansion.
/// If no payments exist, shows an empty-state hint.
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with title + count
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 16,
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Transactions',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Text(
                    '${payments.length}',
                    style: const TextStyle(
                      color: AppTheme.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (payments.isEmpty)
              _emptyState(context)
            else
              _table(list, provider),
            if (!showAll && payments.length > limit)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Align(
                  alignment: Alignment.center,
                  child: TextButton.icon(
                    onPressed: () {
                      // Switch to Payments tab via bottom nav
                      // (handled by parent — fall back to no-op)
                    },
                    icon: const Icon(Icons.list_alt, size: 16),
                    label: Text(
                      'View all ${payments.length} transactions',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 40,
            color: AppTheme.accent.withOpacity(0.3),
          ),
          const SizedBox(height: 8),
          const Text(
            'No transactions yet',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tap "Log Payment" to paste an M-Pesa SMS.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _table(List<Payment> list, LoanProvider provider) {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2.2),
        1: FlexColumnWidth(2.0),
        2: FlexColumnWidth(1.4),
        3: IntrinsicColumnWidth(),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        // Header
        TableRow(
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppTheme.border, width: 1),
            ),
          ),
          children: [
            _headerCell('Date'),
            _headerCell('Code'),
            _headerCell('Amount', align: TextAlign.right),
            _headerCell('Type', align: TextAlign.right),
          ],
        ),
        // Body
        ...list.map((p) => _row(p, provider)),
      ],
    );
  }

  Widget _headerCell(String text, {TextAlign align = TextAlign.left}) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8, left: 4, right: 8),
      child: Text(
        text.toUpperCase(),
        textAlign: align,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _row(Payment p, LoanProvider provider) {
    final isMpesa = p.source == PaymentSource.mpesa;
    final typeColor = isMpesa ? AppTheme.primary : AppTheme.accent;
    return TableRow(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.border, width: 0.5),
        ),
      ),
      children: [
        // Date
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${p.paidAt.day}/${p.paidAt.month}/${p.paidAt.year}',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${p.paidAt.hour.toString().padLeft(2, '0')}:'
                '${p.paidAt.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        // M-Pesa code or sender
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (p.mpesaCode != null)
                Text(
                  p.mpesaCode!,
                  style: const TextStyle(
                    color: AppTheme.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                  ),
                )
              else
                const Text(
                  '—',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                ),
              if (p.sender != null && p.sender!.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  p.sender!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
        // Amount
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Text(
            'Ksh ${p.amount.toStringAsFixed(0)}',
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: AppTheme.primary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        // Type badge
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: typeColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: typeColor.withOpacity(0.4)),
              ),
              child: Text(
                isMpesa ? 'M-P' : 'MAN',
                style: TextStyle(
                  color: typeColor,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
