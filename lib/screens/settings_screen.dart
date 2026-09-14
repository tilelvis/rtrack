import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/loan_provider.dart';
import '../services/notification_service.dart';
import '../theme/theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  TimeOfDay _reminderTime = const TimeOfDay(hour: 8, minute: 0);
  bool _saving = false;

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
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
      setState(() => _reminderTime = picked);
    }
  }

  Future<void> _saveReminder() async {
    final provider = context.read<LoanProvider>();
    final loan = provider.activeLoan;
    setState(() => _saving = true);
    await NotificationService().scheduleDailyReminder(
      hour: _reminderTime.hour,
      minute: _reminderTime.minute,
      title: 'Loan Tracker Reminder',
      body: loan == null
          ? 'Remember to make your loan payment today.'
          : 'Remember to pay Ksh ${loan.expectedPerInterval.toStringAsFixed(0)} today.',
    );
    setState(() => _saving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Daily reminder set for ${_reminderTime.format(context)}',
          ),
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LoanProvider>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _section('Notifications'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Daily reminder time',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'You will be notified every day at this time to make your payment.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickTime,
                        icon: const Icon(Icons.access_time),
                        label: Text(_reminderTime.format(context)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _saveReminder,
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.alarm_on_outlined),
                        label: const Text('Save'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
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
                  'Version 1.0.0 • Build 1',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Text(
                  'A personal loan tracker with M-Pesa SMS parsing, '
                  'daily reminders, and offline SQLite storage. '
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

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: AppTheme.accent,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
