import 'dart:async';
import 'package:flutter/material.dart';
import 'package:telephony/telephony.dart';
import '../models/loan.dart';
import '../models/payment.dart';
import '../repositories/loan_repository.dart';
import 'database_service.dart';
import 'mpesa_parser.dart';
import 'notification_service.dart';

/// Auto-imports M-Pesa SMS messages as payments — NO manual paste needed.
///
/// How it works:
///   1. On app launch, calls `telephony.listenIncomingSms()` which fires
///      whenever a new SMS arrives (even when app is in foreground).
///   2. Filters messages that contain "M-Pesa" (case-insensitive).
///   3. Parses the SMS with MpesaParser.
///   4. Matches against the active loan's keyword (e.g. "001709" or "NCBA").
///   5. If matched + valid → auto-creates a Payment via the repository.
///   6. Shows a notification: "Payment auto-imported: Ksh 700".
///
/// The listener runs while the app is alive. For true background detection
/// (app closed), a native Android BroadcastReceiver would be needed —
/// that's a larger future enhancement.
class SmsAutoImportService {
  static final SmsAutoImportService _instance = SmsAutoImportService._internal();
  factory SmsAutoImportService() => _instance;
  SmsAutoImportService._internal();

  final _telephony = Telephony.instance;
  StreamSubscription<SmsMessage>? _subscription;
  bool _listening = false;

  /// Whether the SMS listener is currently active.
  bool get isListening => _listening;

  /// Start listening for incoming M-Pesa SMS.
  ///
  /// [repository] — used to insert the auto-imported payment.
  /// [activeLoan] — the current loan; its [keyword] field is used to
  ///   filter which M-Pesa messages belong to this loan. If keyword is
  ///   null/empty, ALL M-Pesa messages are matched.
  /// [onPaymentImported] — callback fired when a payment is auto-imported.
  ///   The UI can use this to refresh the dashboard.
  Future<void> startListening({
    required LoanRepository repository,
    required Loan? Function() getActiveLoan,
    required void Function(Payment payment) onPaymentImported,
  }) async {
    if (_listening) return;

    // Check SMS permission
    final granted = await _ensurePermission();
    if (!granted) return;

    _subscription = _telephony.listenIncomingSms(
      onNewMessage: (SmsMessage message) async {
        final body = message.body ?? '';
        if (body.isEmpty) return;

        // Quick filter — must mention M-Pesa
        if (!body.toLowerCase().contains('m-pesa') &&
            !body.toLowerCase().contains('mpesa')) {
          return;
        }

        // Parse the message
        final parsed = MpesaParser.parse(body);
        if (!parsed.isValid) return;

        // Get the current active loan
        final loan = getActiveLoan();
        if (loan == null) return;

        // Check keyword match
        // The keyword can be an account number ("001709"), a bank name
        // ("NCBA"), a paybill number ("880100"), or any other string.
        // If keyword is empty, match ALL M-Pesa messages.
        final keyword = loan.keyword?.trim() ?? '';
        if (keyword.isNotEmpty) {
          final lowerBody = body.toLowerCase();
          final lowerKeyword = keyword.toLowerCase();
          if (!lowerBody.contains(lowerKeyword)) {
            // Also check if the parsed account matches the keyword
            if (parsed.account != null &&
                parsed.account!.toLowerCase() == lowerKeyword) {
              // Account number match — OK
            } else if (parsed.sender != null &&
                parsed.sender!.toLowerCase().contains(lowerKeyword)) {
              // Sender name match — OK
            } else {
              return; // No match — skip this message
            }
          }
        }

        // Check for duplicate (same M-Pesa code already in DB)
        final existingCodes = <String>{};
        final payments = await repository.getPaymentsForLoan(loan.id);
        for (final p in payments) {
          if (p.mpesaCode != null) {
            existingCodes.add(p.mpesaCode!.toUpperCase());
          }
        }
        if (parsed.mpesaCode != null &&
            existingCodes.contains(parsed.mpesaCode!.toUpperCase())) {
          // Already imported — skip silently
          return;
        }

        // Create the payment
        final payment = Payment(
          id: '',
          loanId: loan.id,
          amount: parsed.amount!,
          paidAt: parsed.paidAt!,
          mpesaCode: parsed.mpesaCode,
          phone: parsed.phone,
          sender: parsed.sender,
          account: parsed.account,
          rawMessage: parsed.rawMessage,
          source: PaymentSource.mpesa,
        );

        try {
          await repository.insertPayment(payment);
          onPaymentImported(payment);

          // Show notification
          await NotificationService().showCriticalNotification(
            title: 'Payment auto-imported',
            body: 'Ksh ${parsed.amount!.toStringAsFixed(0)} from M-Pesa '
                '(${parsed.mpesaCode ?? "?"}) — ${loan.title}',
          );
        } catch (_) {
          // Insert failed (duplicate or other DB error) — silently skip
        }
      },
    );

    _listening = true;
  }

  /// Stop listening for SMS.
  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _listening = false;
  }

  /// Ensure SMS permissions are granted.
  Future<bool> _ensurePermission() async {
    // telephony has its own permission request
    final granted = await _telephony.requestSmsPermissions;
    return granted ?? false;
  }
}
