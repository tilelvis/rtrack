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
                primary: AppTheme.primary,
                onPrimary: const Color(0xFF001100),
                surface: AppTheme.surface,
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
        const SnackBar(
          content: Text('Maximum 3 reminder times supported.'),
          backgroundColor: AppTheme.warning,
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
          backgroundColor: AppTheme.primary,
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
                primary: AppTheme.primary,
                onPrimary: const Color(0xFF001100),
                surface: AppTheme.surface,
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
        const SnackBar(
          content: Text('Statement ready — share or save it.'),
          backgroundColor: AppTheme.primary,
        ),
      );
    } catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed: $e'),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LoanProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _section('Appearance'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.palette_outlined, size: 18, color: AppTheme.accent),
                    SizedBox(width: 8),
                    Text(
                      'Theme',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Switch between light and dark. System follows your phone\'s setting.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                ...AppThemeMode.values.map((mode) {
                  final selected = themeProvider.mode == mode;
                  return InkWell(
                    onTap: () => themeProvider.setMode(mode),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 12),
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppTheme.primary.withOpacity(0.1)
                            : AppTheme.surfaceAlt,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? AppTheme.primary
                              : AppTheme.border,
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            mode == AppThemeMode.light
                                ? Icons.light_mode_outlined
                                : mode == AppThemeMode.dark
                                    ? Icons.dark_mode_outlined
                                    : Icons.brightness_auto_outlined,
                            size: 20,
                            color: selected
                                ? AppTheme.primary
                                : AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              mode.label,
                              style: TextStyle(
                                color: selected
                                    ? AppTheme.primary
                                    : AppTheme.textPrimary,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                          if (selected)
                            const Icon(Icons.check_circle,
                                color: AppTheme.primary, size: 20),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        _section('Notifications'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.alarm, color: AppTheme.primary, size: 18),
                    const SizedBox(width: 8),
                    const Text(
                      'Daily reminder times',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    Text(
                      '${_reminderTimes.length}/3',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Add multiple reminders (e.g. morning 8 AM + evening 7 PM) '
                  'so you never forget a payment. Max 3 slots.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
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
                            icon: const Icon(Icons.close, size: 18,
                                color: AppTheme.danger),
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
                  child: ElevatedButton.icon(
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
            ),
          ),
        ),
        const SizedBox(height: 24),
        _section('Lender Contact'),
        if (provider.activeLoan?.hasLenderContact ?? false)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.accent.withOpacity(0.5)),
                        ),
                        child: const Icon(Icons.person, color: AppTheme.accent),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              provider.activeLoan!.lenderName ?? 'Lender',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            if (provider.activeLoan!.lenderPhone != null)
                              Text(
                                provider.activeLoan!.lenderPhone!,
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            if (provider.activeLoan!.lenderEmail != null)
                              Text(
                                provider.activeLoan!.lenderEmail!,
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => showLenderActionsSheet(
                        context,
                        provider.activeLoan!,
                      ),
                      icon: const Icon(Icons.contact_phone_outlined),
                      label: const Text('Call / WhatsApp / SMS / Email'),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No lender contact saved. Edit your loan to add the lender\'s '
                'name, phone, and email for one-tap call/WhatsApp/email.',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          ),
        const SizedBox(height: 24),
        _section('Export & Reports'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Full PDF Report',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'All transactions, totals, M-Pesa codes, dates — shareable PDF.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: provider.activeLoan == null
                        ? null
                        : () => _exportPdf(provider),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('Generate Full PDF Report'),
                  ),
                ),
                Divider(height: 28, color: AppTheme.border),
                const Text(
                  'Monthly Statement',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Statement for a single month — perfect to email to your lender '
                  'as proof of payments made that month.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: provider.activeLoan == null
                        ? null
                        : _generateMonthlyStatement,
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: const Text('Generate Monthly Statement'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        _section('Loan'),
        if (provider.activeLoan != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    provider.activeLoan!.title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Principal: Ksh ${provider.activeLoan!.principal.toStringAsFixed(2)}',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                  Text(
                    'Due: ${provider.activeLoan!.dueDate.day}/${provider.activeLoan!.dueDate.month}/${provider.activeLoan!.dueDate.year}',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                  if (provider.activeLoan!.keyword != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'SMS keyword: "${provider.activeLoan!.keyword}"',
                      style: const TextStyle(color: AppTheme.accent, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: AppTheme.surface,
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
                              child: const Text('Delete', style: TextStyle(color: AppTheme.danger)),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await provider.deleteLoan(provider.activeLoan!.id);
                        await NotificationService().cancelAll();
                      }
                    },
                    icon: const Icon(Icons.delete_outline, color: AppTheme.danger),
                    label: const Text('Delete loan', style: TextStyle(color: AppTheme.danger)),
                  ),
                ],
              ),
            ),
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No active loan. Create one from the Home screen.',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          ),
        const SizedBox(height: 24),
        _section('About'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Loan Tracker',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Version 1.3.0 • Build 4',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Text(
                  'A personal loan tracker with M-Pesa SMS auto-import, '
                  'PDF reports, payment receipts, monthly statements, '
                  'home-screen widget, lender contact, and multiple daily reminders. '
                  'Built with Flutter & Material 3.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
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

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppTheme.accent,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
