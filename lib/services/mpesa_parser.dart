import 'package:intl/intl.dart';

/// Parsed M-Pesa SMS message.
class ParsedMpesa {
  final double? amount;
  final String? mpesaCode;
  final DateTime? paidAt;
  final String? phone;
  final String? sender;
  final String? rawMessage;
  final String kind; // 'sent' | 'received' | 'unknown'

  ParsedMpesa({
    required this.amount,
    required this.mpesaCode,
    required this.paidAt,
    required this.phone,
    required this.sender,
    required this.rawMessage,
    required this.kind,
  });

  /// A payment is importable only when the transaction has a real, parseable
  /// amount, confirmation code and transaction timestamp. We deliberately do
  /// not invent a timestamp when the SMS date cannot be parsed.
  bool get isValid =>
      amount != null && amount! > 0 && mpesaCode != null && paidAt != null;
}

/// Parses common Safaricom M-Pesa confirmation SMS formats.
///
/// The parser is intentionally conservative: an unparseable transaction date
/// remains null rather than being replaced with DateTime.now(). This prevents
/// historical payments from being silently recorded as today's payment.
class MpesaParser {
  static final RegExp _amountRegex = RegExp(
    r'(?:you\s+have\s+sent|sent)\s+(?:Ksh|KES|KSh)\s?([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  static final RegExp _receivedAmountRegex = RegExp(
    r'(?:Ksh|KES|KSh)\s?([\d,]+(?:\.\d{1,2})?)\s+(?:received|has\s+been\s+received)',
    caseSensitive: false,
  );

  static final RegExp _receivedAmountPrefixRegex = RegExp(
    r'(?:received|has\s+been\s+received)\s+(?:Ksh|KES|KSh)\s?([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  static final RegExp _codeRegex =
      RegExp(r'\b([A-Z0-9]{10})\s+Confirmed\b', caseSensitive: false);

  static final RegExp _phoneRegex = RegExp(r'\b(?:254|0)7\d{8}\b');

  static final RegExp _dateRegex = RegExp(
    r'(\d{1,2})/(\d{1,2})/(\d{2,4})\s+at\s+(\d{1,2}):(\d{2})\s*(AM|PM)?',
    caseSensitive: false,
  );

  static ParsedMpesa parse(String raw) {
    final text = raw.trim();
    String? mpesaCode;
    double? amount;
    DateTime? paidAt;
    String? phone;
    String? sender;
    var kind = 'unknown';

    final codeMatch = _codeRegex.firstMatch(text);
    if (codeMatch != null) {
      mpesaCode = codeMatch.group(1)!.toUpperCase();
    } else {
      final fallback = RegExp(r'^([A-Z0-9]{10})\b', caseSensitive: false)
          .firstMatch(text);
      if (fallback != null && text.toLowerCase().contains('confirmed')) {
        mpesaCode = fallback.group(1)!.toUpperCase();
      }
    }

    Match? amountMatch = _amountRegex.firstMatch(text);
    amountMatch ??= _receivedAmountRegex.firstMatch(text);
    amountMatch ??= _receivedAmountPrefixRegex.firstMatch(text);
    if (amountMatch != null) {
      amount = double.tryParse(amountMatch.group(1)!.replaceAll(',', ''));
    }

    final dateMatch = _dateRegex.firstMatch(text);
    if (dateMatch != null) {
      final day = int.tryParse(dateMatch.group(1)!);
      final month = int.tryParse(dateMatch.group(2)!);
      var year = int.tryParse(dateMatch.group(3)!);
      var hour = int.tryParse(dateMatch.group(4)!);
      final minute = int.tryParse(dateMatch.group(5)!);
      final ampm = dateMatch.group(6)?.toUpperCase();

      if (day != null && month != null && year != null && hour != null &&
          minute != null) {
        if (year < 100) year += 2000;
        if (ampm == 'PM' && hour < 12) hour += 12;
        if (ampm == 'AM' && hour == 12) hour = 0;

        // DateTime normalises invalid dates (e.g. 31 Feb) instead of throwing,
        // so construct and compare every component explicitly.
        try {
          final candidate = DateTime(year, month, day, hour, minute);
          if (candidate.year == year &&
              candidate.month == month &&
              candidate.day == day &&
              candidate.hour == hour &&
              candidate.minute == minute) {
            paidAt = candidate;
          }
        } catch (_) {
          paidAt = null;
        }
      }
    }

    final phoneMatch = _phoneRegex.firstMatch(text);
    if (phoneMatch != null) phone = phoneMatch.group(0);

    final lower = text.toLowerCase();
    if (lower.contains('you have sent') || lower.contains('sent to')) {
      kind = 'sent';
      final match = RegExp(
        r'(?:sent to|to)\s+([A-Z][A-Z\s.]{2,40})',
        caseSensitive: false,
      ).firstMatch(text);
      if (match != null) {
        sender = match.group(1)?.trim();
        sender = sender?.replaceAll(RegExp(r'\d.*$'), '').trim();
      }
    } else if (lower.contains('received from') ||
        lower.contains('has been received')) {
      kind = 'received';
      final match = RegExp(
        r'received from\s+([A-Z][A-Z\s.]{2,40})',
        caseSensitive: false,
      ).firstMatch(text);
      if (match != null) {
        sender = match.group(1)?.trim();
        sender = sender?.replaceAll(RegExp(r'\d.*$'), '').trim();
      }
    }

    return ParsedMpesa(
      amount: amount,
      mpesaCode: mpesaCode,
      paidAt: paidAt,
      phone: phone,
      sender: sender,
      rawMessage: raw,
      kind: kind,
    );
  }

  static String formatKes(double amount) {
    final fmt = NumberFormat.currency(symbol: 'Ksh ', decimalDigits: 2);
    return fmt.format(amount);
  }

  static String formatDate(DateTime dt) {
    return DateFormat('d MMM y, h:mm a').format(dt);
  }
}
