import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/loan_provider.dart';
import '../theme/theme.dart';
import '../widgets/dashboard_card.dart';
import '../widgets/payment_history_list.dart';
import 'create_loan_screen.dart';
import 'mpesa_paste_screen.dart';
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
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MpesaPasteScreen()),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Log Payment'),
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
      children: const [
        DashboardCard(),
        SizedBox(height: 16),
        PaymentHistoryList(limit: 5, embedded: true),
      ],
    );
  }
}
