import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/loan_provider.dart';
import '../providers/theme_provider.dart';
import '../services/pdf_report_service.dart';
import '../theme/app_tokens.dart';
import '../theme/theme.dart';
import '../widgets/dashboard_card.dart';
import '../widgets/payment_history_list.dart';
import '../widgets/payment_trend_chart.dart';
import '../widgets/streak_tracker_card.dart';
import '../widgets/transactions_table.dart';
import 'create_loan_screen.dart';
import 'loan_history_screen.dart';
import 'manual_payment_screen.dart';
import 'mpesa_paste_screen.dart';
import 'payments_screen.dart';
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
      const PaymentsScreen(),
      const LoanHistoryScreen(),
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
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
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
      physics: const ClampingScrollPhysics(),
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
            // Loan switcher — visible right on the home screen
            if (provider.visibleLoans.length > 1)
              PopupMenuButton<String>(
                icon: const Icon(Icons.swap_horiz),
                tooltip: 'Switch loan',
                onSelected: (loanId) async {
                  await provider.setActiveLoan(loanId);
                },
                itemBuilder: (ctx) {
                  final visible = provider.visibleLoans;
                  final hidden = provider.hiddenLoans;
                  final items = <PopupMenuEntry<String>>[];

                  for (final loan in visible) {
                    items.add(PopupMenuItem<String>(
                      value: loan.id,
                      child: Row(
                        children: [
                          Icon(
                            loan.id == provider.activeLoan?.id
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            size: 18,
                            color: loan.id == provider.activeLoan?.id
                                ? Theme.of(ctx).colorScheme.primary
                                : Theme.of(ctx).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(loan.title,
                                    style: TextStyle(
                                        fontWeight:
                                            loan.id == provider.activeLoan?.id
                                                ? FontWeight.w700
                                                : FontWeight.w500)),
                                Text(
                                    'Ksh ${loan.principal.toStringAsFixed(0)} • due ${loan.dueDate.day}/${loan.dueDate.month}',
                                    style: Theme.of(ctx).textTheme.bodySmall),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.visibility_off_outlined,
                                size: 16,
                                color: Theme.of(ctx)
                                    .colorScheme
                                    .onSurfaceVariant),
                            onPressed: () {
                              Navigator.pop(ctx);
                              provider.hideLoan(loan.id);
                            },
                            tooltip: 'Hide',
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ));
                  }

                  if (hidden.isNotEmpty) {
                    items.add(const PopupMenuDivider());
                    items.add(PopupMenuItem<String>(
                      enabled: false,
                      child: Text('HIDDEN',
                          style: Theme.of(ctx).textTheme.labelSmall),
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
                                  Text(loan.title,
                                      style: TextStyle(
                                          color: Theme.of(ctx)
                                              .colorScheme
                                              .onSurfaceVariant,
                                          decoration:
                                              TextDecoration.lineThrough)),
                                  Text(
                                      'Ksh ${loan.principal.toStringAsFixed(0)}',
                                      style: Theme.of(ctx).textTheme.bodySmall),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.visibility_outlined,
                                  size: 16,
                                  color: Theme.of(ctx).colorScheme.primary),
                              onPressed: () {
                                Navigator.pop(ctx);
                                provider.unhideLoan(loan.id);
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
            // Theme toggle
            IconButton(
              icon: Icon(_themeIcon(context)),
              tooltip: 'Toggle theme',
              onPressed: () => _cycleTheme(context),
            ),
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
              onPressed: () => setState(() => _index = 3),
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
              const SizedBox(height: AppSpacing.md),
              _LoanHistoryCta(
                activeCount: provider.activeLoans.length,
                completedCount: provider.completedLoans.length,
                hiddenCount: provider.hiddenLoans.length,
                onTap: () => setState(() => _index = 2),
              ),
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
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
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

  /// Show the right icon for the current theme mode.
  IconData _themeIcon(BuildContext context) {
    final themeProvider = context.read<ThemeProvider>();
    switch (themeProvider.mode) {
      case AppThemeMode.light:
        return Icons.light_mode_outlined;
      case AppThemeMode.dark:
        return Icons.dark_mode_outlined;
      case AppThemeMode.system:
        return Icons.brightness_auto_outlined;
    }
  }

  /// Cycle through theme modes: system → light → dark → system.
  /// Tapping the icon quickly switches themes without going to Settings.
  void _cycleTheme(BuildContext context) {
    final themeProvider = context.read<ThemeProvider>();
    final AppThemeMode next;
    switch (themeProvider.mode) {
      case AppThemeMode.system:
        next = AppThemeMode.light;
        break;
      case AppThemeMode.light:
        next = AppThemeMode.dark;
        break;
      case AppThemeMode.dark:
        next = AppThemeMode.system;
        break;
    }
    themeProvider.setMode(next);

    // Show a tiny snackbar so the user knows which mode they're now in
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(_themeIcon(context), size: 18),
              const SizedBox(width: AppSpacing.sm),
              Text('Theme: ${next.label}'),
            ],
          ),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          width: 220,
        ),
      );
  }
}

/// Compact "Loan history" call-to-action card on the home screen.
///
/// Surfaces the new History tab from the home page so users discover that
/// completed/closed loans are still tracked and reviewable. Tapping jumps
/// to the History tab.
class _LoanHistoryCta extends StatelessWidget {
  final int activeCount;
  final int completedCount;
  final int hiddenCount;
  final VoidCallback onTap;

  const _LoanHistoryCta({
    required this.activeCount,
    required this.completedCount,
    required this.hiddenCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = Theme.of(context).extension<LoanTrackerDesignTokens>()!;
    final text = Theme.of(context).textTheme;

    final total = activeCount + completedCount + hiddenCount;
    if (total == 0) return const SizedBox.shrink();

    // Build the count summary line. Prioritises completed loans in the
    // sub-line since that's the most common reason users reach this CTA
    // ("where did my paid loans go?").
    final sub = <String>[];
    if (completedCount > 0) sub.add('$completedCount completed');
    if (activeCount > 0) sub.add('$activeCount active');
    if (hiddenCount > 0) sub.add('$hiddenCount hidden');

    return Material(
      color: tokens.brandSurface,
      borderRadius: BorderRadius.circular(AppRadii.xl),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: Icon(Icons.history_rounded,
                    size: 20, color: scheme.primary),
              ),
              const SizedBox(width: AppSpacing.mdSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Loan history',
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sub.join(' • '),
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (completedCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: tokens.brandSuccess.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle,
                          size: 12, color: tokens.brandSuccess),
                      const SizedBox(width: 4),
                      Text(
                        '$completedCount',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: tokens.brandSuccess,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Text(
                    '$total total',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                    ),
                  ),
                ),
              const SizedBox(width: AppSpacing.xs),
              Icon(Icons.chevron_right,
                  size: 18, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
