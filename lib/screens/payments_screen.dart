import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/loan_provider.dart';
import '../theme/app_tokens.dart';
import 'create_loan_screen.dart';
import 'manual_payment_screen.dart';
import 'mpesa_paste_screen.dart';
import 'payment_history_screen.dart';

/// Standalone Payments screen — wraps PaymentHistoryList with an AppBar
/// that contains:
///   - Loan switcher (dropdown to switch active loan)
///   - "Add Loan" action button to create a new loan to track
class PaymentsScreen extends StatelessWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LoanProvider>();
    final loans = provider.loans;
    final activeLoan = provider.activeLoan;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.receipt_long,
                size: 22, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: AppSpacing.sm),
            const Text('Payments'),
          ],
        ),
        actions: [
          // Loan switcher — popup menu of all visible loans + hidden section
          if (loans.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.swap_horiz),
              tooltip: 'Switch loan',
              onSelected: (loanId) async {
                final provider = context.read<LoanProvider>();
                await provider.setActiveLoan(loanId);
              },
              itemBuilder: (ctx) {
                final visible = provider.visibleLoans;
                final hidden = provider.hiddenLoans;
                final items = <PopupMenuEntry<String>>[];

                // Visible loans
                for (final loan in visible) {
                  items.add(PopupMenuItem<String>(
                    value: loan.id,
                    child: Row(
                      children: [
                        Icon(
                          loan.id == activeLoan?.id
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          size: 18,
                          color: loan.id == activeLoan?.id
                              ? Theme.of(ctx).colorScheme.primary
                              : Theme.of(ctx).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                loan.title,
                                style: TextStyle(
                                  fontWeight: loan.id == activeLoan?.id
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                              Text(
                                'Ksh ${loan.principal.toStringAsFixed(0)} • due ${loan.dueDate.day}/${loan.dueDate.month}',
                                style: Theme.of(ctx).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        // Hide button
                        IconButton(
                          icon: Icon(Icons.visibility_off_outlined,
                              size: 16,
                              color:
                                  Theme.of(ctx).colorScheme.onSurfaceVariant),
                          onPressed: () {
                            Navigator.pop(ctx);
                            context.read<LoanProvider>().hideLoan(loan.id);
                          },
                          tooltip: 'Hide this loan',
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ));
                }

                // Hidden loans section
                if (hidden.isNotEmpty) {
                  items.add(const PopupMenuDivider());
                  items.add(PopupMenuItem<String>(
                    enabled: false,
                    child: Text(
                      'HIDDEN LOANS',
                      style: Theme.of(ctx).textTheme.labelSmall,
                    ),
                  ));
                  for (final loan in hidden) {
                    items.add(PopupMenuItem<String>(
                      value: loan.id,
                      child: Row(
                        children: [
                          Icon(Icons.visibility_off_outlined,
                              size: 16,
                              color: Theme.of(ctx)
                                  .colorScheme
                                  .onSurfaceVariant),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  loan.title,
                                  style: TextStyle(
                                    color: Theme.of(ctx)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                                Text(
                                  'Ksh ${loan.principal.toStringAsFixed(0)}',
                                  style: Theme.of(ctx).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.visibility_outlined,
                                size: 16,
                                color: Theme.of(ctx).colorScheme.primary),
                            onPressed: () {
                              Navigator.pop(ctx);
                              context
                                  .read<LoanProvider>()
                                  .unhideLoan(loan.id);
                            },
                            tooltip: 'Unhide',
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ));
                  }
                }

                return items;
              },
            ),
          // Add new loan
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Add a new loan to track',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateLoanScreen()),
            ),
          ),
        ],
        bottom: activeLoan == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(36),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: 0),
                  child: Row(
                    children: [
                      Icon(Icons.account_balance_wallet_outlined,
                          size: 14,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          'Tracking: ${activeLoan.title}',
                          style: Theme.of(context).textTheme.labelMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${provider.visibleLoans.length} loan${provider.visibleLoans.length == 1 ? "" : "s"}'
                        '${provider.hiddenLoans.isNotEmpty ? " (${provider.hiddenLoans.length} hidden)" : ""}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              ),
      ),
      body: const PaymentHistoryList(),
      floatingActionButton: activeLoan == null
          ? null
          : FloatingActionButton.extended(
              heroTag: 'fab_payments_log',
              onPressed: () => _showLogPaymentOptions(context),
              icon: const Icon(Icons.add),
              label: const Text('Log Payment'),
            ),
    );
  }

  /// Show a bottom sheet with the two payment entry options.
  void _showLogPaymentOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.sms_outlined,
                  color: Theme.of(context).colorScheme.primary),
              title: const Text('Log M-Pesa Payment'),
              subtitle: const Text('Paste or scan an M-Pesa SMS'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MpesaPasteScreen()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.edit_outlined,
                  color: Theme.of(context).colorScheme.primary),
              title: const Text('Enter Manually'),
              subtitle: const Text('Cash, cheque, or custom entry'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ManualPaymentScreen()),
                );
              },
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}
