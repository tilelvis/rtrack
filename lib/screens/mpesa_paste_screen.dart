import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/payment.dart';
import '../providers/loan_provider.dart';
import '../services/mpesa_parser.dart';
import '../theme/theme.dart';
import 'manual_payment_screen.dart';

class MpesaPasteScreen extends StatefulWidget {
  const MpesaPasteScreen({super.key});

  @override
  State<MpesaPasteScreen> createState() => _MpesaPasteScreenState();
}

class _MpesaPasteScreenState extends State<MpesaPasteScreen> {
  final _smsCtrl = TextEditingController();
  ParsedMpesa? _parsed;
  bool _saving = false;

  @override
  void dispose() {
    _smsCtrl.dispose();
    super.dispose();
  }

  void _parse() {
    final raw = _smsCtrl.text.trim();
    if (raw.isEmpty) return;
    setState(() {
      _parsed = MpesaParser.parse(raw);
    });
  }

  Future<void> _save() async {
    final p = _parsed;
    if (p == null || !p.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not parse M-Pesa message')),
      );
      return;
    }
    final provider = context.read<LoanProvider>();
    final loanId = provider.activeLoan?.id;
    if (loanId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create a loan first')),
      );
      return;
    }

    setState(() => _saving = true);
    final payment = Payment(
      id: '',
      loanId: loanId,
      amount: p.amount!,
      paidAt: p.paidAt!,
      mpesaCode: p.mpesaCode,
      phone: p.phone,
      sender: p.sender,
      rawMessage: p.rawMessage,
      source: PaymentSource.mpesa,
    );
    final saved = await provider.addPayment(payment);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(saved
            ? 'Payment saved: Ksh ${p.amount!.toStringAsFixed(2)}'
            : 'This M-Pesa transaction is already recorded for another loan.'),
        backgroundColor: saved ? AppTheme.primary : AppTheme.warning,
      ),
    );
    if (saved) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Log M-Pesa Payment')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Paste your M-Pesa SMS below',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'We will auto-extract amount, code, date and sender.',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _smsCtrl,
            maxLines: 6,
            minLines: 4,
            decoration: const InputDecoration(
              hintText:
                  'SI7K2PX1HZ Confirmed. You have sent Ksh500.00 to JOHN DOE 0712345678 on 14/9/26 at 9:30 AM...',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _parse,
                  icon: const Icon(Icons.auto_fix_high_outlined),
                  label: const Text('Parse SMS'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('Save'),
                ),
              ),
            ],
          ),
          if (_parsed != null) ...[
            const SizedBox(height: 24),
            _parsedCard(_parsed!),
          ],
          const SizedBox(height: 16),
          // Manual entry shortcut — opens ManualPaymentScreen with the
          // already-parsed data as a prefill, so the user can fix the
          // missing/incorrect fields rather than re-typing everything.
          TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ManualPaymentScreen(
                  prefill: _parsed,
                ),
              ),
            ),
            icon: const Icon(Icons.edit_outlined),
            label: Text(
              _parsed == null
                  ? 'Enter payment manually instead'
                  : 'Edit parsed details manually',
            ),
          ),
        ],
      ),
    );
  }

  Widget _parsedCard(ParsedMpesa p) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Parsed',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.primary,
                      ),
                ),
              ],
            ),
            const Divider(height: 20),
            _row('Amount', p.amount == null
                ? '-'
                : MpesaParser.formatKes(p.amount!)),
            _row('M-Pesa code', p.mpesaCode ?? '-'),
            _row('Date', p.paidAt == null
                ? '-'
                : MpesaParser.formatDate(p.paidAt!)),
            _row('Phone', p.phone ?? '-'),
            _row('Sender', p.sender ?? '-'),
            _row('Direction', p.kind),
            if (!p.isValid) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.danger.withOpacity(0.1),
                  border: Border.all(color: AppTheme.danger),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Could not parse all fields. Please edit the SMS or enter manually.',
                  style: TextStyle(color: AppTheme.danger, fontSize: 13),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
