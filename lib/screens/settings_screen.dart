import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/loan_provider.dart';
import '../providers/theme_provider.dart';
import '../services/notification_service.dart';
import '../services/pdf_report_service.dart';
import '../theme/theme.dart';
import '../widgets/lender_actions_sheet.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  /// Up to 3 reminder slots. Default: morning 8 AM only.
  List<ReminderTime> _reminderTimes = [
    const ReminderTime(hour: 8, minute: 0),
  ];
  bool _savingReminders = false;

  Future<void> _pickTime(int slotIndex) async {
    final initial = slotIndex < _reminderTimes.length
        ? _reminderTimes[slotIndex]
        : const ReminderTime(hour: 8, minute: 0);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial.hour, minute: initial.minute),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: Theme.of(context).colorScheme.primary,
                onPrimary: const Color(0xFF001100),
                surface: Theme.of(context).colorScheme.surface,
              ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        final newTime = ReminderTime(hour: picked.hour, minute: picked.minute);
        if (slotIndex < _reminderTimes.length) {
          _reminderTimes[slotIndex] = newTime;
        } else {
          _reminderTimes.add(newTime);
        }
      });
    }
  }

  Future<void> _addReminderSlot() async {
    if (_reminderTimes.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Maximum 3 reminder times supported.'),
          backgroundColor: Theme.of(context).extension<LoanTrackerDesignTokens>()!.warning,
        ),
      );
      return;
    }
    // Default new slot to 7 PM if not yet present
    setState(() {
      _reminderTimes.add(const ReminderTime(hour: 19, minute: 0));
    });
  }

  void _removeReminderSlot(int index) {
    setState(() {
      _reminderTimes.removeAt(index);
    });
  }

  Future<void> _saveReminders() async {
    final provider = context.read<LoanProvider>();
    final loan = provider.activeLoan;
    setState(() => _savingReminders = true);
    await NotificationService().scheduleMultipleReminders(
      times: _reminderTimes,
      loanTitle: loan?.title ?? '',
      expectedAmount: loan?.expectedPerInterval ?? 0,
    );
    setState(() => _savingReminders = false);
    if (mounted) {
      final timesStr = _reminderTimes.map((t) => t.format12()).join(', ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reminders set: $timesStr'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    }
  }

  Future<void> _testNotification() async {
    await NotificationService().showTestNotification();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test notification sent')),
      );
    }
  }

  Future<void> _generateMonthlyStatement() async {
    final provider = context.read<LoanProvider>();
    final loan = provider.activeLoan;
    if (loan == null) return;

    // Show month/year picker
    final now = DateTime.now();
    DateTime? selected = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year, now.month, 1),
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(now.year, now.month, 1),
      helpText: 'Pick ANY day in the statement month',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: Theme.of(context).colorScheme.primary,
                onPrimary: const Color(0xFF001100),
                surface: Theme.of(context).colorScheme.surface,
              ),
        ),
        child: child!,
      ),
    );
    if (selected == null) return;

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
            Text('Generating monthly statement...'),
          ],
        ),
        duration: Duration(seconds: 15),
      ),
    );
    try {
      await PdfReportService.generateMonthlyAndShare(
        loan: loan,
        allPayments: provider.recentPayments,
        totalPaidAllTime: provider.totalPaid,
        year: selected.year,
        month: selected.month,
      );
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Statement ready — share or save it.'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    } catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LoanProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          // Quick theme toggle in header — same as on home screen
          PopupMenuButton<AppThemeMode>(
            icon: Icon(_themeIcon(themeProvider.mode)),
            tooltip: 'Theme',
            onSelected: (mode) => themeProvider.setMode(mode),
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: AppThemeMode.system,
                child: _themeMenuRow(ctx, AppThemeMode.system, themeProvider.mode),
              ),
              PopupMenuItem(
                value: AppThemeMode.light,
                child: _themeMenuRow(ctx, AppThemeMode.light, themeProvider.mode),
              ),
              PopupMenuItem(
                value: AppThemeMode.dark,
                child: _themeMenuRow(ctx, AppThemeMode.dark, themeProvider.mode),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // ----------------------------------------------------------------
          // NOTIFICATIONS — collapsible
          // ----------------------------------------------------------------
          _collapsibleSection(
            icon: Icons.alarm,
            title: 'Notifications',
            subtitle: '${_reminderTimes.length} reminder time${_reminderTimes.length == 1 ? '' : 's'}',
            initiallyExpanded: true,
            child: _buildNotificationsContent(),
          ),
          const SizedBox(height: 12),

          // ----------------------------------------------------------------
          // LENDER CONTACT — collapsible
          // ----------------------------------------------------------------
          _collapsibleSection(
            icon: Icons.contact_phone_outlined,
            title: 'Lender Contact',
            subtitle: provider.activeLoan?.hasLenderContact == true
                ? provider.activeLoan!.lenderName
                : 'Not set',
            initiallyExpanded: false,
            child: _buildLenderContent(provider),
          ),
          const SizedBox(height: 12),

          // ----------------------------------------------------------------
          // LOAN SETTINGS — collapsible
          // ----------------------------------------------------------------
          _collapsibleSection(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Loan Settings',
            subtitle: provider.activeLoan?.title ?? 'No loan',
            initiallyExpanded: false,
            child: _buildLoanContent(provider),
          ),
          const SizedBox(height: 12),

          // ----------------------------------------------------------------
          // EXPORT & REPORTS — collapsible
          // ----------------------------------------------------------------
          _collapsibleSection(
            icon: Icons.picture_as_pdf_outlined,
            title: 'Export & Reports',
            subtitle: 'PDF reports + monthly statements',
            initiallyExpanded: false,
            child: _buildExportContent(provider),
          ),
          const SizedBox(height: 12),

          // ----------------------------------------------------------------
          // ABOUT — collapsible
          // ----------------------------------------------------------------
          _collapsibleSection(
            icon: Icons.info_outline,
            title: 'About',
            subtitle: 'v2.0.3+21',
            initiallyExpanded: false,
            child: _buildAboutContent(),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// A collapsible section with a leading icon + trailing chevron.
  /// Uses Card + ExpansionTile for Material 3 styling.
  Widget _collapsibleSection({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
    bool initiallyExpanded = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        shape: Border.all(color: Colors.transparent),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: scheme.onPrimaryContainer, size: 18),
        ),
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        subtitle: Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [child],
      ),
    );
  }

  /// Theme icon for the header.
  IconData _themeIcon(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return Icons.light_mode_outlined;
      case AppThemeMode.dark:
        return Icons.dark_mode_outlined;
      case AppThemeMode.system:
        return Icons.brightness_auto_outlined;
    }
  }

  /// Row inside the theme popup menu.
  Widget _themeMenuRow(BuildContext ctx, AppThemeMode mode, AppThemeMode current) {
    final selected = mode == current;
    return Row(
      children: [
        Icon(_themeIcon(mode),
            size: 18,
            color: selected
                ? Theme.of(ctx).colorScheme.primary
                : Theme.of(ctx).colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            mode.label,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected
                  ? Theme.of(ctx).colorScheme.primary
                  : Theme.of(ctx).colorScheme.onSurface,
            ),
          ),
        ),
        if (selected)
          Icon(Icons.check,
              size: 18, color: Theme.of(ctx).colorScheme.primary),
      ],
    );
  }

  // ----- Section content builders -----
  // (extracted from the original build method so they can live inside
  //  collapsible sections)

  Widget _buildNotificationsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Daily reminder times',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Add multiple reminders (e.g. morning 8 AM + evening 7 PM) '
          'so you never forget a payment. Max 3 slots.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        ..._reminderTimes.asMap().entries.map((entry) {
          final i = entry.key;
          final t = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickTime(i),
                    icon: const Icon(Icons.access_time),
                    label: Text(t.format12()),
                  ),
                ),
                if (_reminderTimes.length > 1) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.close,
                        size: 18, color: Theme.of(context).colorScheme.error),
                    onPressed: () => _removeReminderSlot(i),
                    tooltip: 'Remove this reminder',
                  ),
                ],
              ],
            ),
          );
        }),
        if (_reminderTimes.length < 3)
          OutlinedButton.icon(
            onPressed: _addReminderSlot,
            icon: const Icon(Icons.add),
            label: const Text('Add another reminder time'),
          ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _savingReminders ? null : _saveReminders,
            icon: _savingReminders
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.alarm_on_outlined),
            label: const Text('Save reminders'),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _testNotification,
          icon: const Icon(Icons.notifications_active_outlined),
          label: const Text('Send test notification'),
        ),
      ],
    );
  }

  Widget _buildLenderContent(LoanProvider provider) {
    final loan = provider.activeLoan;
    if (loan == null || !loan.hasLenderContact) {
      return Column(
        children: [
          Text(
            'No lender contact saved.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Edit your loan to add the lender\'s name, phone, and email for one-tap call/WhatsApp/email.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.person,
                  color: Theme.of(context).colorScheme.onSecondaryContainer),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loan.lenderName ?? 'Lender',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  if (loan.lenderPhone != null)
                    Text(
                      loan.lenderPhone!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  if (loan.lenderEmail != null)
                    Text(
                      loan.lenderEmail!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => showLenderActionsSheet(context, loan),
            icon: const Icon(Icons.contact_phone_outlined),
            label: const Text('Call / WhatsApp / SMS / Email'),
          ),
        ),
      ],
    );
  }

  Widget _buildLoanContent(LoanProvider provider) {
    final loan = provider.activeLoan;
    if (loan == null) {
      return Text(
        'No active loan. Create one from the Home screen.',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          loan.title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Principal: Ksh ${loan.principal.toStringAsFixed(2)}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        Text(
          'Due: ${loan.dueDate.day}/${loan.dueDate.month}/${loan.dueDate.year}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (loan.keyword != null) ...[
          const SizedBox(height: 4),
          Text(
            'SMS keyword: "${loan.keyword}"',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Delete this loan?'),
                content: const Text(
                  'This will delete all associated payments as well. This cannot be undone.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Delete',
                        style: TextStyle(
                            color: Color(0xFFFF3B3B))),
                  ),
                ],
              ),
            );
            if (confirmed == true) {
              await provider.deleteLoan(loan.id);
              await NotificationService().cancelAll();
            }
          },
          icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
          label: Text('Delete loan',
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
      ],
    );
  }

  Widget _buildExportContent(LoanProvider provider) {
    final loan = provider.activeLoan;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Full PDF Report',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'All transactions, totals, M-Pesa codes, dates — shareable PDF.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: loan == null ? null : () => _exportPdf(provider),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Generate Full PDF Report'),
          ),
        ),
        const Divider(height: 28),
        Text(
          'Monthly Statement',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Statement for a single month — perfect to email to your lender as proof of payments made that month.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: loan == null ? null : _generateMonthlyStatement,
            icon: const Icon(Icons.calendar_month_outlined),
            label: const Text('Generate Monthly Statement'),
          ),
        ),
      ],
    );
  }

  Widget _buildAboutContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Loan Tracker',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Version 2.0.3+21',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Text(
          'A personal loan tracker with M-Pesa SMS auto-import, '
          'PDF reports, payment receipts, monthly statements, '
          'lender contact, home-screen widget, and payment trend chart. '
          'Built with Flutter & Material 3.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Future<void> _exportPdf(LoanProvider provider) async {
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
        SnackBar(
          content: Text('PDF report ready — share or save it.'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    } catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to generate PDF: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }
}
