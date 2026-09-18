import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/payment.dart';
import '../providers/loan_provider.dart';
import '../services/mpesa_parser.dart';
import '../theme/theme.dart';

/// Manual payment entry form.
///
/// Lets the user enter all payment fields by hand — useful when:
///   - The M-Pesa SMS parser failed to extract some fields
///   - The payment was made in cash (no M-Pesa code)
///   - The user wants to backfill an older payment
///
/// If [prefill] is provided (typically from a partially-parsed M-Pesa SMS),
/// the form is pre-populated with whatever the parser did manage to extract,
/// so the user can fix the missing pieces instead of re-typing everything.
class ManualPaymentScreen extends StatefulWidget {
  final ParsedMpesa? prefill;

  const ManualPaymentScreen({super.key, this.prefill});

  @override
  State<ManualPaymentScreen> createState() => _ManualPaymentScreenState();
}

class _ManualPaymentScreenState extends State<ManualPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountCtrl;
  late final TextEditingController _mpesaCodeCtrl;
  late final TextEditingController _senderCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _notesCtrl;
  DateTime _paidAt = DateTime.now();
  TimeOfDay _paidTime = TimeOfDay.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.prefill;
    _amountCtrl = TextEditingController(
      text: p?.amount != null ? p!.amount!.toStringAsFixed(2) : '',
    );
    _mpesaCodeCtrl = TextEditingController(text: p?.mpesaCode ?? '');
    _senderCtrl = TextEditingController(text: p?.sender ?? '');
    _phoneCtrl = TextEditingController(text: p?.phone ?? '');
    _notesCtrl = TextEditingController();

    // If the parser supplied a date, use it; otherwise default to now.
    if (p?.paidAt != null) {
      _paidAt = p!.paidAt!;
      _paidTime = TimeOfDay(hour: p.paidAt!.hour, minute: p.paidAt!.minute);
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _mpesaCodeCtrl.dispose();
    _senderCtrl.dispose();
    _phoneCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paidAt,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
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
      setState(() => _paidAt = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _paidTime,
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
      setState(() => _paidTime = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<LoanProvider>();
    final loanId = provider.activeLoan?.id;
    if (loanId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active loan to add a payment to.')),
      );
      return;
    }

    final amount = double.parse(_amountCtrl.text.trim());
    final paidAt = DateTime(
      _paidAt.year,
      _paidAt.month,
      _paidAt.day,
      _paidTime.hour,
      _paidTime.minute,
    );

    // Trim M-Pesa code to uppercase if provided
    final code = _mpesaCodeCtrl.text.trim();
    final source = code.isEmpty
        ? PaymentSource.manual
        : PaymentSource.mpesa;

    final payment = Payment(
      id: '',
      loanId: loanId,
      amount: amount,
      paidAt: paidAt,
      mpesaCode: code.isEmpty ? null : code.toUpperCase(),
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      sender: _senderCtrl.text.trim().isEmpty ? null : _senderCtrl.text.trim(),
      rawMessage: widget.prefill?.rawMessage,
      source: source,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );

    setState(() => _saving = true);
    final saved = await provider.addPayment(payment);
    if (!mounted) return;
    setState(() => _saving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(saved
            ? 'Payment saved: Ksh ${amount.toStringAsFixed(2)}'
            : 'This M-Pesa transaction code is already recorded for another loan.'),
        backgroundColor: saved ? AppTheme.primary : AppTheme.warning,
      ),
    );
    if (saved) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manual Payment'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Amount
            TextFormField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount (Ksh) *',
                hintText: 'e.g. 500.00',
                prefixText: 'Ksh ',
              ),
              validator: (v) {
                final n = double.tryParse((v ?? '').trim());
                if (n == null || n <= 0) return 'Enter a valid amount';
                return null;
              },
            ),
            const SizedBox(height: 12),

            // M-Pesa code (optional)
            TextFormField(
              controller: _mpesaCodeCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'M-Pesa code (optional)',
                hintText: 'e.g. SI7K2PX1HZ',
                helperText: 'Leave empty for cash payments',
              ),
            ),
            const SizedBox(height: 12),

            // Sender / recipient name (optional)
            TextFormField(
              controller: _senderCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Sender / Recipient (optional)',
                hintText: 'e.g. JOHN DOE',
              ),
            ),
            const SizedBox(height: 12),

            // Phone (optional)
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone (optional)',
                hintText: 'e.g. 0712345678',
              ),
            ),
            const SizedBox(height: 16),

            // Date row
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date',
                  suffixIcon: Icon(Icons.calendar_today, size: 18),
                ),
                child: Text(DateFormat('d MMM y').format(_paidAt)),
              ),
            ),
            const SizedBox(height: 12),

            // Time row
            InkWell(
              onTap: _pickTime,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Time',
                  suffixIcon: Icon(Icons.access_time, size: 18),
                ),
                child: Text(_paidTime.format(context)),
              ),
            ),
            const SizedBox(height: 12),

            // Notes (optional)
            TextFormField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Any extra details about this payment',
              ),
            ),
            const SizedBox(height: 24),

            // Save button
            ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Save Payment'),
            ),
            const SizedBox(height: 12),

            // Helper text
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.accent.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 18, color: AppTheme.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.prefill?.rawMessage != null
                          ? 'Some fields were pre-filled from the M-Pesa SMS you pasted. Edit them as needed.'
                          : 'All fields marked with * are required. M-Pesa code is optional — leave it empty for cash payments.',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
