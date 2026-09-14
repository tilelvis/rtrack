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

  bool get isValid =>
      amount != null && amount! > 0 && mpesaCode != null && paidAt != null;
}

/// Parses typical Safaricom M-Pesa SMS messages.
///
/// Supports the common forms:
///   - "SI7K2PX1HZ Confirmed. You have sent Ksh500.00 to JOHN DOE 0712345678
///     on 14/9/26 at 9:30 AM. New M-PESA balance is Ksh1,234.56."
///   - "QFA8H7P2LK Confirmed. Ksh1,200.00 received from JANE DOE 254712345678
///     on 14/9/26 at 9:30 AM."
///   - Variants using "KES" instead of "Ksh", without decimals, etc.
class MpesaParser {
  static final RegExp _amountRegex =
      RegExp(r'(?:Ksh|KES|KSh)\s?([\d,]+(?:\.\d{1,2})?)', caseSensitive: false);

  static final RegExp _codeRegex =
      RegExp(r'\b([A-Z0-9]{10})\s+Confirmed', caseSensitive: false);

  static final RegExp _phoneRegex =
      RegExp(r'\b(?:254|0)?7\d{8}\b');

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
    String kind = 'unknown';

    // Code
    final codeMatch = _codeRegex.firstMatch(text);
    if (codeMatch != null) {
      mpesaCode = codeMatch.group(1);
    } else {
      // fallback: 10-char alphanumeric at start
      final fb = RegExp(r'^([A-Z0-9]{10})').firstMatch(text);
      if (fb != null) mpesaCode = fb.group(1);
    }

    // Amount — pick the first amount mentioned after "sent" or "received"
    final amountMatches = _amountRegex.allMatches(text);
    if (amountMatches.isNotEmpty) {
      final rawAmt = amountMatches.first.group(1)!.replaceAll(',', '');
      amount = double.tryParse(rawAmt);
    }

    // Date
    final dateMatch = _dateRegex.firstMatch(text);
    if (dateMatch != null) {
      final day = int.parse(dateMatch.group(1)!);
      final month = int.parse(dateMatch.group(2)!);
      var year = int.parse(dateMatch.group(3)!);
      if (year < 100) year += 2000;
      var hour = int.parse(dateMatch.group(4)!);
      final minute = int.parse(dateMatch.group(5)!);
      final ampm = dateMatch.group(6)?.toUpperCase();
      if (ampm == 'PM' && hour < 12) hour += 12;
      if (ampm == 'AM' && hour == 12) hour = 0;
      try {
        paidAt = DateTime(year, month, day, hour, minute);
      } catch (_) {
        paidAt = null;
      }
    }

    // Phone
    final phoneMatch = _phoneRegex.firstMatch(text);
    if (phoneMatch != null) {
      phone = phoneMatch.group(0);
    }

    // Sender / recipient and kind
    final lower = text.toLowerCase();
    if (lower.contains('you have sent') || lower.contains('sent to')) {
      kind = 'sent';
      final s = RegExp(
        r'(?:sent to|to)\s+([A-Z][A-Z\s.]{2,40})',
        caseSensitive: false,
      ).firstMatch(text);
      if (s != null) {
        sender = s.group(1)?.trim();
        // strip trailing digits
        sender = sender?.replaceAll(RegExp(r'\d.*$'), '').trim();
      }
    } else if (lower.contains('received from') ||
        lower.contains('has been received')) {
      kind = 'received';
      final s = RegExp(
        r'received from\s+([A-Z][A-Z\s.]{2,40})',
        caseSensitive: false,
      ).firstMatch(text);
      if (s != null) {
        sender = s.group(1)?.trim();
        sender = sender?.replaceAll(RegExp(r'\d.*$'), '').trim();
      }
    }

    return ParsedMpesa(
      amount: amount,
      mpesaCode: mpesaCode,
      paidAt: paidAt ?? DateTime.now(),
      phone: phone,
      sender: sender,
      rawMessage: raw,
      kind: kind,
    );
  }

  /// Format currency for display
  static String formatKes(double amount) {
    final fmt = NumberFormat.currency(symbol: 'Ksh ', decimalDigits: 2);
    return fmt.format(amount);
  }

  /// Format date for display
  static String formatDate(DateTime dt) {
    return DateFormat('d MMM y, h:mm a').format(dt);
  }
}
