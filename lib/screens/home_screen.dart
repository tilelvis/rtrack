import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/loan_provider.dart';
import '../services/pdf_report_service.dart';
import '../theme/theme.dart';
import '../widgets/dashboard_card.dart';
import '../widgets/payment_history_list.dart';
import '../widgets/payment_trend_chart.dart';
import '../widgets/transactions_table.dart';
import 'create_loan_screen.dart';
import 'manual_payment_screen.dart';
import 'mpesa_paste_screen.dart';
import 'sms_scan_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LoanProvider>().loadLoans();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LoanProvider>();
    final hasLoan = provider.activeLoan != null;

    final screens = [
      _buildHome(provider),
      const PaymentHistoryList(),
      const SettingsScreen(),
    ];

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary,
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Text('LoanTracker'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Download PDF report',
            onPressed: hasLoan ? () => _exportPdf(provider) : null,
          ),
          IconButton(
            icon: const Icon(Icons.sms_outlined),
            tooltip: 'Scan SMS for M-Pesa payments',
            onPressed: hasLoan
                ? () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SmsScanScreen()),
                    )
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: screens[_index],
      floatingActionButton: hasLoan
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Manual entry — quick cash payment without M-Pesa code
                FloatingActionButton.extended(
                  heroTag: 'fab_manual',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ManualPaymentScreen()),
                  ),
                  backgroundColor: AppTheme.surfaceAlt,
                  foregroundColor: AppTheme.accent,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Manual'),
                ),
                const SizedBox(width: 10),
                // M-Pesa paste / scan — primary action
                FloatingActionButton.extended(
                  heroTag: 'fab_mpesa',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MpesaPasteScreen()),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Log Payment'),
                ),
              ],
            )
          : FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateLoanScreen()),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add Loan'),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: AppTheme.surface,
        indicatorColor: AppTheme.primary.withOpacity(0.18),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined, color: AppTheme.textSecondary),
            selectedIcon: Icon(Icons.dashboard, color: AppTheme.primary),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined, color: AppTheme.textSecondary),
            selectedIcon: Icon(Icons.receipt_long, color: AppTheme.primary),
            label: 'Payments',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined, color: AppTheme.textSecondary),
            selectedIcon: Icon(Icons.settings, color: AppTheme.primary),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildHome(LoanProvider provider) {
    if (provider.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.activeLoan == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                size: 80,
                color: AppTheme.primary.withOpacity(0.5),
              ),
              const SizedBox(height: 24),
              Text(
                'No loan yet',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Create your first loan to start tracking daily payments and M-Pesa messages.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateLoanScreen()),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Create Loan'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        const DashboardCard(),
        const SizedBox(height: 16),
        PaymentTrendChart(
          payments: provider.recentPayments,
          expectedPerWeek: provider.activeLoan!.expectedPerInterval,
          weeks: 6,
        ),
        const SizedBox(height: 16),
        TransactionsTable(limit: 8),
        const SizedBox(height: 16),
        const PaymentHistoryList(limit: 3, embedded: true),
      ],
    );
  }

  Future<void> _exportPdf(LoanProvider provider) async {
    final loan = provider.activeLoan;
    if (loan == null) return;
    final messenger = ScaffoldMessenger.of(context);

    // Show generating indicator
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
            Text('Generating PDF report...'),
          ],
        ),
        duration: Duration(seconds: 10),
      ),
    );

    try {
      await PdfReportService.generateAndShare(
        loan: loan,
        payments: provider.recentPayments,
        totalPaid: provider.totalPaid,
      );
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('PDF report ready — share or save it.'),
          backgroundColor: AppTheme.primary,
        ),
      );
    } catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to generate PDF: $e'),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }
}
