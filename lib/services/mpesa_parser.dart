import 'package:intl/intl.dart';

/// Parsed M-Pesa SMS message.
class ParsedMpesa {
  final double? amount;
  final String? mpesaCode;
  final DateTime? paidAt;
  final String? phone;
  final String? sender;
  final String? account;
  final String? rawMessage;
  final String kind; // 'sent' | 'received' | 'unknown'

  ParsedMpesa({
    required this.amount,
    required this.mpesaCode,
    required this.paidAt,
    required this.phone,
    required this.sender,
    this.account,
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
/// Handles multiple Safaricom SMS patterns:
///   - "SI7K2PX1HZ Confirmed. You have sent Ksh500.00 to JOHN DOE 0712345678 on 14/9/26 at 9:30 AM"
///   - "QFA8H7P2LK Confirmed. Ksh1,200.00 received from JANE DOE 254712345678 on 14/9/26 at 9:30 AM"
///   - "UIPHZ7BTFG Confirmed. Ksh400.00 sent to NCBA BANK KENYA PLC. for account 001709 on 25/9/26 at 12:28 PM"
///   - Variants without decimals, with/without "you have", etc.
class MpesaParser {
  // ---- Code: 10-char alphanumeric at start, followed by "Confirmed" ----
  static final RegExp _codeRegex =
      RegExp(r'\b([A-Z0-9]{10})\s+Confirmed\b', caseSensitive: false);

  // ---- Amount patterns ----
  // Pattern 1: "Ksh400.00 sent to" (amount BEFORE "sent")
  static final RegExp _amountBeforeSentRegex = RegExp(
    r'(?:Ksh|KES|KSh)\s?([\d,]+(?:\.\d{1,2})?)\s+(?:sent|has been sent)',
    caseSensitive: false,
  );

  // Pattern 2: "sent Ksh500.00" / "you have sent Ksh500.00" (amount AFTER "sent")
  static final RegExp _amountAfterSentRegex = RegExp(
    r'(?:you\s+have\s+sent|sent)\s+(?:Ksh|KES|KSh)\s?([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  // Pattern 3: "Ksh1,200.00 received from" (amount BEFORE "received")
  static final RegExp _amountReceivedRegex = RegExp(
    r'(?:Ksh|KES|KSh)\s?([\d,]+(?:\.\d{1,2})?)\s+(?:received|has\s+been\s+received)',
    caseSensitive: false,
  );

  // Pattern 4: generic "Confirmed. Ksh500.00" right after the code
  static final RegExp _amountAfterConfirmedRegex = RegExp(
    r'Confirmed\.?\s*(?:Ksh|KES|KSh)\s?([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  // ---- Phone: Kenyan phone format ----
  static final RegExp _phoneRegex = RegExp(r'\b(?:254|0)?7\d{8}\b');

  // ---- Account number: "for account XXXX" ----
  static final RegExp _accountRegex =
      RegExp(r'for\s+account\s+(\w+)', caseSensitive: false);

  // ---- Date ----
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
    String? account;
    var kind = 'unknown';

    // ---- Code ----
    final codeMatch = _codeRegex.firstMatch(text);
    if (codeMatch != null) {
      mpesaCode = codeMatch.group(1)!.toUpperCase();
    } else {
      final fallback =
          RegExp(r'^([A-Z0-9]{10})\b', caseSensitive: false).firstMatch(text);
      if (fallback != null && text.toLowerCase().contains('confirmed')) {
        mpesaCode = fallback.group(1)!.toUpperCase();
      }
    }

    // ---- Amount (try multiple patterns) ----
    // Try each pattern in order until one matches. CRITICAL: we must skip
    // the "New M-PESA balance is KshXXX" amount — all our patterns require
    // "sent" or "received" or "Confirmed" near the amount, which excludes
    // the balance line.
    Match? amountMatch = _amountBeforeSentRegex.firstMatch(text);
    amountMatch ??= _amountAfterSentRegex.firstMatch(text);
    amountMatch ??= _amountReceivedRegex.firstMatch(text);
    amountMatch ??= _amountAfterConfirmedRegex.firstMatch(text);
    if (amountMatch != null) {
      amount = double.tryParse(amountMatch.group(1)!.replaceAll(',', ''));
    }

    // ---- Date ----
    final dateMatch = _dateRegex.firstMatch(text);
    if (dateMatch != null) {
      final day = int.tryParse(dateMatch.group(1)!);
      final month = int.tryParse(dateMatch.group(2)!);
      var year = int.tryParse(dateMatch.group(3)!);
      var hour = int.tryParse(dateMatch.group(4)!);
      final minute = int.tryParse(dateMatch.group(5)!);
      final ampm = dateMatch.group(6)?.toUpperCase();

      if (day != null && month != null && year != null &&
          hour != null && minute != null) {
        if (year < 100) year += 2000;
        if (ampm == 'PM' && hour < 12) hour += 12;
        if (ampm == 'AM' && hour == 12) hour = 0;

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

    // ---- Phone ----
    final phoneMatch = _phoneRegex.firstMatch(text);
    if (phoneMatch != null) phone = phoneMatch.group(0);

    // ---- Account number (for bank/loan payments) ----
    final accountMatch = _accountRegex.firstMatch(text);
    if (accountMatch != null) account = accountMatch.group(1);

    // ---- Sender / recipient ----
    final lower = text.toLowerCase();
    if (lower.contains('sent to') || lower.contains('you have sent')) {
      kind = 'sent';

      // Try "sent to NAME for account XXXX" pattern (bank loan payment)
      final bankMatch = RegExp(
        r'sent to\s+(.+?)\s+for\s+account',
        caseSensitive: false,
      ).firstMatch(text);
      if (bankMatch != null) {
        sender = bankMatch.group(1)?.trim();
      } else {
        // Standard "sent to NAME" or "to NAME"
        final match = RegExp(
          r"(?:sent to|to)\s+([A-Z][A-Z\s.']{2,50}?)\s+(?:on|at|\d)",
          caseSensitive: false,
        ).firstMatch(text);
        if (match != null) {
          sender = match.group(1)?.trim();
        }
      }

      // Clean up: remove trailing period, strip phone numbers
      if (sender != null) {
        sender = sender.replaceAll(RegExp(r'\s+\d+$'), '').trim();
        sender = sender.replaceAll(RegExp(r'\.$'), '').trim();
      }
    } else if (lower.contains('received from') ||
        lower.contains('has been received')) {
      kind = 'received';
      final match = RegExp(
        r"received from\s+([A-Z][A-Z\s.']{2,50}?)\s+(?:on|at|\d)",
        caseSensitive: false,
      ).firstMatch(text);
      if (match != null) {
        sender = match.group(1)?.trim();
        sender = sender?.replaceAll(RegExp(r'\s+\d+$'), '').trim();
        sender = sender?.replaceAll(RegExp(r'\.$'), '').trim();
      }
    }

    return ParsedMpesa(
      amount: amount,
      mpesaCode: mpesaCode,
      paidAt: paidAt,
      phone: phone,
      sender: sender,
      account: account,
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
