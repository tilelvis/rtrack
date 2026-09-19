import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/loan_provider.dart';
import '../services/pdf_report_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_components.dart';
import '../widgets/dashboard_card.dart';
import '../widgets/payment_history_list.dart';
import '../widgets/payment_trend_chart.dart';
import '../widgets/streak_tracker_card.dart';
import '../widgets/transactions_table.dart';
import 'create_loan_screen.dart';
import 'manual_payment_screen.dart';
import 'mpesa_paste_screen.dart';
import 'settings_screen.dart';
import 'sms_scan_screen.dart';

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
      body: SafeArea(
        child: IndexedStack(
          index: _index,
          children: screens,
        ),
      ),
      floatingActionButton: hasLoan ? _buildFabRow() : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Payments',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildFabRow() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton.extended(
          heroTag: 'fab_manual',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ManualPaymentScreen()),
          ),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Manual'),
        ),
        const SizedBox(width: AppSpacing.sm),
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
    );
  }

  Widget _buildHome(LoanProvider provider) {
    if (provider.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.activeLoan == null) {
      return _buildNoLoanState();
    }

    return CustomScrollView(
      slivers: [
        // Sticky app bar with logo + actions
        SliverAppBar.large(
          title: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: Icon(
                  Icons.account_balance_wallet,
                  size: 18,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Text('LoanTracker'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.sms_outlined),
              tooltip: 'Scan SMS for M-Pesa payments',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SmsScanScreen()),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: 'Download PDF report',
              onPressed: () => _exportPdf(provider),
            ),
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              tooltip: 'Settings',
              onPressed: () => setState(() => _index = 2),
            ),
          ],
        ),
        // Scrollable content
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.sm,
            AppSpacing.screenH,
            96,
          ),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const DashboardCard(),
              const SizedBox(height: AppSpacing.md),
              const StreakTrackerCard(),
              const SizedBox(height: AppSpacing.md),
              PaymentTrendChart(
                payments: provider.recentPayments,
                expectedPerWeek: provider.activeLoan!.expectedPerInterval,
                weeks: 6,
              ),
              const SizedBox(height: AppSpacing.md),
              const TransactionsTable(limit: 5),
              const SizedBox(height: AppSpacing.md),
              const PaymentHistoryList(limit: 3, embedded: true),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildNoLoanState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No loan yet',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Create your first loan to start tracking daily payments and M-Pesa messages.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
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

  Future<void> _exportPdf(LoanProvider provider) async {
    final loan = provider.activeLoan;
    if (loan == null) return;
    final messenger = ScaffoldMessenger.of(context);

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
            const Text('Generating PDF report...'),
          ],
        ),
        duration: const Duration(seconds: 10),
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
        ),
      );
    } catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to generate PDF: $e')),
      );
    }
  }
}
