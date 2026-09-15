import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'package:telephony/telephony.dart';
import '../models/loan.dart';
import '../models/payment.dart';
import 'mpesa_parser.dart';

/// Result of scanning the SMS inbox for M-Pesa messages matching a loan's
/// keyword. Each [DetectedPayment] contains the parsed fields and the raw
/// SMS so the user can review before importing.
class DetectedPayment {
  final Payment payment; // pre-built Payment object (not yet saved)
  final String rawSms;
  final DateTime smsDate;
  final bool alreadyImported; // true if mpesa_code already in DB

  DetectedPayment({
    required this.payment,
    required this.rawSms,
    required this.smsDate,
    required this.alreadyImported,
  });
}

/// Reads the device's SMS inbox for M-Pesa confirmation messages, filters
/// them by a per-loan keyword, and parses each match into a [Payment].
///
/// Example flow:
///   1. User grants READ_SMS permission
///   2. User taps "Scan SMS" on the home screen
///   3. [scanForLoan] reads last N days of SMS, filters by loan.keyword
///   4. UI shows the list of detected payments
///   5. User confirms which to import
class SmsService {
  static final SmsService _instance = SmsService._internal();
  factory SmsService() => _instance;
  SmsService._internal();

  final _telephony = Telephony.instance;

  /// Check if READ_SMS permission is granted. Request if not.
  Future<bool> ensurePermission() async {
    final status = await Permission.sms.status;
    if (status.isGranted) return true;
    final result = await Permission.sms.request();
    return result.isGranted;
  }

  /// Returns true if the user has permanently denied SMS permission.
  Future<bool> isPermanentlyDenied() async {
    final status = await Permission.sms.status;
    return status.isPermanentlyDenied;
  }

  /// Scan the SMS inbox for M-Pesa messages matching [loan.keyword].
  /// Returns a list of detected payments, sorted newest-first.
  ///
  /// The keyword matching is case-insensitive and matches as a substring
  /// anywhere in the SMS body (covers sender name, phone, or any tag).
  ///
  /// If [loan.keyword] is null or empty, no filter is applied and ALL
  /// M-Pesa messages in the time range are returned.
  ///
  /// [daysBack] controls how far back to scan (default 30).
  /// [existingCodes] is a set of M-Pesa codes already in the DB, used to
  /// mark already-imported payments so the UI can grey them out.
  Future<List<DetectedPayment>> scanForLoan({
    required Loan loan,
    required Set<String> existingCodes,
    int daysBack = 30,
  }) async {
    final granted = await ensurePermission();
    if (!granted) return [];

    final cutoff = DateTime.now().subtract(Duration(days: daysBack));
    final cutoffMillis = cutoff.millisecondsSinceEpoch;

    // Build the SMS filter: must contain "M-Pesa" (case-insensitive),
    // and either the keyword or any M-Pesa confirmation code pattern.
    // telephony's SmsFilter supports .contains() which is case-insensitive
    // on most Android implementations.
    final keyword = loan.keyword?.trim() ?? '';
    final filter = keyword.isEmpty
        ? SmsFilter.where.contains('M-Pesa')
        : SmsFilter.where.contains('M-Pesa').or.contains(keyword);

    final smsList = await _telephony.getInboxSms(
      filter: filter,
      sortOrder: [
        OrderBy(SmsColumn.DATE, sort: Sort.by.desc),
      ],
    );

    // Apply the date cutoff locally (telephony doesn't support date filter
    // in SmsFilter directly on all versions).
    final filtered = smsList.where((s) {
      final ts = int.tryParse(s.date ?? '0') ?? 0;
      return ts >= cutoffMillis;
    }).toList();

    final results = <DetectedPayment>[];
    for (final sms in filtered) {
      final body = sms.body ?? '';
      if (body.isEmpty) continue;
      // Re-check keyword match case-insensitively (Android SmsFilter is
      // sometimes case-sensitive depending on ROM).
      if (keyword.isNotEmpty &&
          !body.toLowerCase().contains(keyword.toLowerCase())) {
        continue;
      }
      final parsed = MpesaParser.parse(body);
      if (!parsed.isValid) continue;
      final already = parsed.mpesaCode != null &&
          existingCodes.contains(parsed.mpesaCode!.toUpperCase());
      results.add(DetectedPayment(
        payment: Payment(
          id: '',
          loanId: loan.id,
          amount: parsed.amount!,
          paidAt: parsed.paidAt ?? DateTime.now(),
          mpesaCode: parsed.mpesaCode,
          phone: parsed.phone,
          sender: parsed.sender,
          rawMessage: parsed.rawMessage,
          source: PaymentSource.mpesa,
        ),
        rawSms: body,
        smsDate: DateTime.fromMillisecondsSinceEpoch(
          int.tryParse(sms.date ?? '0') ?? 0,
        ),
        alreadyImported: already,
      ));
    }
    return results;
  }

  /// Batch-import a list of confirmed detected payments.
  /// Returns the number successfully imported.
  Future<int> importConfirmed(
    List<DetectedPayment> detected,
    Future<void> Function(Payment) insertFn,
  ) async {
    var count = 0;
    for (final d in detected) {
      if (d.alreadyImported) continue;
      await insertFn(d.payment);
      count++;
    }
    return count;
  }
}
