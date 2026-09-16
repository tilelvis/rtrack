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
/// Implementation note: telephony 0.2.0's `SmsFilter.where.contains(...)`
/// chainable API is unreliable across versions (the `where` getter is
/// typed as a `Function` and the chainable methods don't resolve cleanly).
/// To stay version-agnostic, we pass `filter: null` (returns ALL inbox
/// SMS) and apply our own filtering in Dart. This is fast enough for
/// typical inbox sizes (hundreds to a few thousand messages).
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

    final keyword = loan.keyword?.trim() ?? '';

    // Read ALL inbox SMS (filter: null = no filter). We sort in Dart below.
    // This avoids the telephony 0.2.0 SmsFilter/Sort API mismatch.
    final smsList = await _telephony.getInboxSms();

    // Filter + sort locally. We:
    //   1. Keep only messages containing "M-Pesa" (case-insensitive)
    //   2. Keep only messages within the daysBack window
    //   3. Optionally filter by loan.keyword (case-insensitive)
    //   4. Sort newest-first by date
    final filtered = smsList.where((s) {
      final body = s.body ?? '';
      if (body.isEmpty) return false;
      if (!body.toLowerCase().contains('m-pesa')) return false;

      // Parse the date — telephony 0.2.0 exposes `date` as Object?, so
      // stringify defensively before parsing.
      final ts = _parseDateMillis(s.date);
      if (ts < cutoffMillis) return false;

      if (keyword.isNotEmpty &&
          !body.toLowerCase().contains(keyword.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();

    // Sort newest-first (highest timestamp first)
    filtered.sort((a, b) =>
        _parseDateMillis(b.date).compareTo(_parseDateMillis(a.date)));

    final results = <DetectedPayment>[];
    for (final sms in filtered) {
      final body = sms.body ?? '';
      if (body.isEmpty) continue;
      final parsed = MpesaParser.parse(body);
      if (!parsed.isValid) continue;
      final already = parsed.mpesaCode != null &&
          existingCodes.contains(parsed.mpesaCode!.toUpperCase());
      results.add(DetectedPayment(
        payment: Payment(
          id: '',
          loanId: loan.id,
          amount: parsed.amount!,
          paidAt: parsed.paidAt!,
          mpesaCode: parsed.mpesaCode,
          phone: parsed.phone,
          sender: parsed.sender,
          rawMessage: parsed.rawMessage,
          source: PaymentSource.mpesa,
        ),
        rawSms: body,
        smsDate: DateTime.fromMillisecondsSinceEpoch(
          _parseDateMillis(sms.date),
        ),
        alreadyImported: already,
      ));
    }
    return results;
  }

  /// Parse the `date` field of a [SmsMessage] into epoch milliseconds.
  ///
  /// telephony 0.2.0 exposes `SmsMessage.date` as `Object?` rather than
  /// `String?` or `int?`. In practice the value is a numeric string
  /// (epoch millis as text), but we handle all reasonable shapes here.
  static int _parseDateMillis(dynamic date) {
    if (date == null) return 0;
    if (date is int) return date;
    if (date is num) return date.toInt();
    final s = date.toString();
    return int.tryParse(s) ?? 0;
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
