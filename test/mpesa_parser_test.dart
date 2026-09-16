import 'package:flutter_test/flutter_test.dart';
import 'package:loan_tracker/services/mpesa_parser.dart';

void main() {
  group('MpesaParser', () {
    test('parses sent transaction with a real timestamp', () {
      const sms =
          'SI7K2PX1HZ Confirmed. You have sent Ksh500.00 to JOHN DOE 0712345678 '
          'on 14/9/26 at 9:30 AM. New M-PESA balance is Ksh1,234.56.';
      final parsed = MpesaParser.parse(sms);

      expect(parsed.isValid, isTrue);
      expect(parsed.amount, 500);
      expect(parsed.mpesaCode, 'SI7K2PX1HZ');
      expect(parsed.paidAt, DateTime(2026, 9, 14, 9, 30));
      expect(parsed.kind, 'sent');
    });

    test('parses received transaction when amount precedes received', () {
      const sms =
          'QFA8H7P2LK Confirmed. Ksh1,200.00 received from JANE DOE 254712345678 '
          'on 14/9/26 at 9:30 AM.';
      final parsed = MpesaParser.parse(sms);

      expect(parsed.isValid, isTrue);
      expect(parsed.amount, 1200);
      expect(parsed.mpesaCode, 'QFA8H7P2LK');
      expect(parsed.kind, 'received');
    });

    test('does not fabricate a date when SMS date is missing', () {
      const sms =
          'SI7K2PX1HZ Confirmed. You have sent Ksh500.00 to JOHN DOE 0712345678.';
      final parsed = MpesaParser.parse(sms);

      expect(parsed.paidAt, isNull);
      expect(parsed.isValid, isFalse);
    });

    test('rejects an impossible calendar date', () {
      const sms =
          'SI7K2PX1HZ Confirmed. You have sent Ksh500.00 to JOHN DOE '
          '0712345678 on 31/2/26 at 9:30 AM.';
      final parsed = MpesaParser.parse(sms);

      expect(parsed.paidAt, isNull);
      expect(parsed.isValid, isFalse);
    });

    test('normalizes M-Pesa code to uppercase', () {
      const sms =
          'si7k2px1hz Confirmed. You have sent KES500 to JOHN DOE '
          '0712345678 on 14/9/26 at 9:30 AM.';
      final parsed = MpesaParser.parse(sms);

      expect(parsed.mpesaCode, 'SI7K2PX1HZ');
      expect(parsed.amount, 500);
      expect(parsed.isValid, isTrue);
    });
  });
}
