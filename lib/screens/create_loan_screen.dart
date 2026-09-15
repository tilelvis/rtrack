import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/loan.dart';
import '../providers/loan_provider.dart';
import '../theme/theme.dart';

class CreateLoanScreen extends StatefulWidget {
  const CreateLoanScreen({super.key});

  @override
  State<CreateLoanScreen> createState() => _CreateLoanScreenState();
}

class _CreateLoanScreenState extends State<CreateLoanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _principalCtrl = TextEditingController();
  final _interestCtrl = TextEditingController(text: '0');
  final _expectedCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _keywordCtrl = TextEditingController();
  final _lenderNameCtrl = TextEditingController();
  final _lenderPhoneCtrl = TextEditingController();
  final _lenderEmailCtrl = TextEditingController();

  DateTime? _startDate = DateTime.now();
  DateTime? _dueDate = DateTime.now().add(const Duration(days: 30));
  PaymentInterval _interval = PaymentInterval.weekly;
  final _customDaysCtrl = TextEditingController(text: '7');

  @override
  void dispose() {
    _titleCtrl.dispose();
    _principalCtrl.dispose();
    _interestCtrl.dispose();
    _expectedCtrl.dispose();
    _notesCtrl.dispose();
    _keywordCtrl.dispose();
    _lenderNameCtrl.dispose();
    _lenderPhoneCtrl.dispose();
    _lenderEmailCtrl.dispose();
    _customDaysCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(BuildContext ctx, bool isStart) async {
    final picked = await showDatePicker(
      context: ctx,
      initialDate: isStart ? _startDate! : _dueDate!,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
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
        if (isStart) {
          _startDate = picked;
        } else {
          _dueDate = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _dueDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please pick start and due dates')),
      );
      return;
    }

    final loan = Loan(
      id: '',
      title: _titleCtrl.text.trim(),
      principal: double.parse(_principalCtrl.text),
      interestRate: double.parse(_interestCtrl.text),
      startDate: _startDate!,
      dueDate: _dueDate!,
      expectedPerInterval: double.parse(_expectedCtrl.text),
      interval: _interval,
      customIntervalDays: int.parse(_customDaysCtrl.text),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      keyword: _keywordCtrl.text.trim().isEmpty ? null : _keywordCtrl.text.trim(),
      lenderName: _lenderNameCtrl.text.trim().isEmpty
          ? null
          : _lenderNameCtrl.text.trim(),
      lenderPhone: _lenderPhoneCtrl.text.trim().isEmpty
          ? null
          : _lenderPhoneCtrl.text.trim(),
      lenderEmail: _lenderEmailCtrl.text.trim().isEmpty
          ? null
          : _lenderEmailCtrl.text.trim(),
    );

    await context.read<LoanProvider>().createLoan(loan);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Loan')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Loan title',
                hintText: 'e.g. Mkopo wa Biashara',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _principalCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Principal amount (Ksh)',
                prefixText: 'Ksh ',
              ),
              validator: (v) {
                final n = double.tryParse(v ?? '');
                if (n == null || n <= 0) return 'Enter a valid amount';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _interestCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Interest rate (%)',
                suffixText: '%',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _expectedCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Expected per interval (Ksh)',
                prefixText: 'Ksh ',
              ),
              validator: (v) {
                final n = double.tryParse(v ?? '');
                if (n == null || n <= 0) return 'Enter a valid amount';
                return null;
              },
            ),
            const SizedBox(height: 20),
            _dateRow('Start date', _startDate, () => _pickDate(context, true)),
            const SizedBox(height: 12),
            _dateRow('Due date', _dueDate, () => _pickDate(context, false)),
            const SizedBox(height: 20),
            DropdownButtonFormField<PaymentInterval>(
              value: _interval,
              decoration: const InputDecoration(labelText: 'Payment interval'),
              items: const [
                DropdownMenuItem(
                  value: PaymentInterval.weekly,
                  child: Text('Weekly (every 7 days)'),
                ),
                DropdownMenuItem(
                  value: PaymentInterval.custom,
                  child: Text('Custom days'),
                ),
              ],
              onChanged: (v) => setState(() => _interval = v!),
            ),
            if (_interval == PaymentInterval.custom) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _customDaysCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Custom interval (days)',
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
              ),
            ),
            const SizedBox(height: 20),
            // SMS keyword filter
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.accent.withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.sms_outlined, size: 18, color: AppTheme.accent),
                      const SizedBox(width: 8),
                      const Text(
                        'SMS Auto-Import Keyword',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'When you scan your SMS inbox, only M-Pesa messages containing this '
                    'word will be matched to this loan. Use the lender\'s name (e.g. '
                    '"JOHN DOE") or phone number. Leave empty to match all M-Pesa messages.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _keywordCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Keyword (optional)',
                      hintText: 'e.g. JOHN DOE or 0712345678',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Lender contact
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.contact_phone_outlined, size: 18, color: AppTheme.primary),
                      const SizedBox(width: 8),
                      const Text(
                        'Lender Contact (optional)',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Save your lender\'s name, phone, and email. You can then '
                    'tap to call, WhatsApp, SMS, or email them — and send '
                    'payment receipts / monthly statements directly.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _lenderNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Lender name',
                      hintText: 'e.g. John Doe',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _lenderPhoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Lender phone',
                      hintText: 'e.g. 0712345678 or +254712345678',
                      prefixText: '+254 ',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _lenderEmailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Lender email (optional)',
                      hintText: 'lender@example.com',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: const Text('Create Loan'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateRow(String label, DateTime? dt, VoidCallback onTap) {
    final text = dt == null
        ? 'Select'
        : '${dt.day}/${dt.month}/${dt.year}';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(text),
      ),
    );
  }
}
