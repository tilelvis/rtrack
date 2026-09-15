import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/loan_provider.dart';
import '../services/sms_service.dart';
import '../services/mpesa_parser.dart';
import '../theme/theme.dart';

/// Scan the SMS inbox for M-Pesa messages matching the active loan's keyword.
/// Shows a list of detected payments with checkboxes; the user selects which
/// to import. Already-imported messages are greyed out.
class SmsScanScreen extends StatefulWidget {
  const SmsScanScreen({super.key});

  @override
  State<SmsScanScreen> createState() => _SmsScanScreenState();
}

class _SmsScanScreenState extends State<SmsScanScreen> {
  final _smsService = SmsService();
  List<DetectedPayment> _detected = [];
  final Set<int> _selected = {}; // index into _detected
  bool _loading = false;
  bool _permissionDenied = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scan());
  }

  Future<void> _scan() async {
    final provider = context.read<LoanProvider>();
    final loan = provider.activeLoan;
    if (loan == null) {
      setState(() => _errorMessage = 'No active loan to scan for.');
      return;
    }
    setState(() {
      _loading = true;
      _permissionDenied = false;
      _errorMessage = null;
      _detected = [];
      _selected.clear();
    });
    try {
      final existingCodes = provider.recentPayments
          .where((p) => p.mpesaCode != null)
          .map((p) => p.mpesaCode!.toUpperCase())
          .toSet();
      final results = await _smsService.scanForLoan(
        loan: loan,
        existingCodes: existingCodes,
        daysBack: 30,
      );
      setState(() {
        _detected = results;
        // Pre-select all new (not-already-imported) detections
        for (var i = 0; i < results.length; i++) {
          if (!results[i].alreadyImported) _selected.add(i);
        }
      });
      if (results.isEmpty && !await _smsService.ensurePermission()) {
        setState(() => _permissionDenied = true);
      }
    } catch (e) {
      setState(() => _errorMessage = 'Failed to read SMS: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _importSelected() async {
    final provider = context.read<LoanProvider>();
    final toImport = _selected
        .map((i) => _detected[i])
        .where((d) => !d.alreadyImported)
        .toList();
    if (toImport.isEmpty) {
      Navigator.pop(context);
      return;
    }
    var count = 0;
    for (final d in toImport) {
      await provider.addPayment(d.payment);
      count++;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Imported $count payment${count == 1 ? '' : 's'}'),
          backgroundColor: AppTheme.primary,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LoanProvider>();
    final loan = provider.activeLoan;
    final keyword = loan?.keyword ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan M-Pesa SMS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _scan,
            tooltip: 'Re-scan',
          ),
        ],
      ),
      body: Column(
        children: [
          // Info banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: AppTheme.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.sms_outlined, size: 18, color: AppTheme.accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        loan == null
                            ? 'No active loan'
                            : 'Scanning for loan: ${loan.title}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                if (keyword.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Keyword filter: "$keyword" (case-insensitive)',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 4),
                  Text(
                    'No keyword set — showing all M-Pesa messages from last 30 days. '
                    'Set a keyword (e.g. lender name) when editing the loan for tighter filtering.',
                    style: const TextStyle(
                      color: AppTheme.warning,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Body
          Expanded(child: _buildBody()),
        ],
      ),
      bottomNavigationBar: _detected.isEmpty || _selected.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: _importSelected,
                  icon: const Icon(Icons.download_done_outlined),
                  label: Text(
                    'Import ${_selected.where((i) => !_detected[i].alreadyImported).length} selected',
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Scanning SMS inbox...',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    if (_permissionDenied) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.sms_failed_outlined,
                  size: 64, color: AppTheme.warning),
              const SizedBox(height: 16),
              Text(
                'SMS permission required',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Loan Tracker needs to read your SMS inbox to find M-Pesa '
                'confirmation messages. Your data stays on your device.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () async {
                  await _smsService.ensurePermission();
                  _scan();
                },
                icon: const Icon(Icons.security),
                label: const Text('Grant permission'),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppTheme.danger),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.danger),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _scan,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_detected.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.inbox_outlined,
                size: 64,
                color: AppTheme.textSecondary.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'No M-Pesa messages found',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'We scanned the last 30 days of SMS for messages matching your keyword. '
                'Nothing matched. Try changing the keyword or paste a payment manually.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _detected.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.border),
      itemBuilder: (context, i) {
        final d = _detected[i];
        final selected = _selected.contains(i);
        return _DetectedTile(
          detected: d,
          selected: selected,
          onToggle: () {
            setState(() {
              if (selected) {
                _selected.remove(i);
              } else {
                _selected.add(i);
              }
            });
          },
        );
      },
    );
  }
}

class _DetectedTile extends StatelessWidget {
  final DetectedPayment detected;
  final bool selected;
  final VoidCallback onToggle;

  const _DetectedTile({
    required this.detected,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final p = detected.payment;
    return InkWell(
      onTap: detected.alreadyImported ? null : onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            // Checkbox
            if (detected.alreadyImported)
              const Icon(Icons.check_circle, color: AppTheme.textSecondary, size: 22)
            else
              Checkbox(
                value: selected,
                onChanged: (_) => onToggle(),
                activeColor: AppTheme.primary,
              ),
            const SizedBox(width: 8),
            // Amount + code
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        MpesaParser.formatKes(p.amount),
                        style: TextStyle(
                          color: detected.alreadyImported
                              ? AppTheme.textSecondary
                              : AppTheme.primary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          decoration: detected.alreadyImported
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (p.mpesaCode != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            p.mpesaCode!,
                            style: const TextStyle(
                              color: AppTheme.accent,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      if (detected.alreadyImported) ...[
                            const SizedBox(width: 8),
                            const Text(
                              'already in app',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 10,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('d MMM y • h:mm a').format(p.paidAt),
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  if (p.sender != null && p.sender!.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      p.sender!,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
