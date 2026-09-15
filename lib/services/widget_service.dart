import 'package:shared_preferences/shared_preferences.dart';
import '../models/loan.dart';

/// Pushes a compact loan summary to SharedPreferences so the native
/// Android AppWidgetProvider (LoanWidgetProvider.kt) can render the
/// home-screen widget.
///
/// The native widget reads these keys from the SharedPreferences file
/// named "FlutterSharedPreferences" (Flutter's default), with the
/// "flutter." prefix that shared_preferences adds internally.
///
/// Keys (all under "flutter." prefix on disk):
///   widget_loan_title         — String
///   widget_balance            — String (formatted "Ksh 1,234.56")
///   widget_next_due            — String (formatted "Due 25 Dec 2026")
///   widget_daily_amount        — String (formatted "Ksh 500/day")
///   widget_progress            — double 0.0–1.0
///   widget_total_paid          — String
///   widget_total_payable       — String
///   widget_days_remaining      — int
///   widget_updated_at          — String (ISO8601)
class WidgetService {
  static final WidgetService _instance = WidgetService._internal();
  factory WidgetService() => _instance;
  WidgetService._internal();

  /// Update the home-screen widget with the current loan summary.
  /// Pass null for [loan] to clear the widget (no active loan).
  Future<void> update({
    Loan? loan,
    required double totalPaid,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (loan == null) {
      await prefs.setString('widget_loan_title', 'No active loan');
      await prefs.setString('widget_balance', '—');
      await prefs.setString('widget_next_due', '');
      await prefs.setString('widget_daily_amount', '');
      await prefs.setDouble('widget_progress', 0.0);
      await prefs.setString('widget_total_paid', '');
      await prefs.setString('widget_total_payable', '');
      await prefs.setInt('widget_days_remaining', 0);
      await prefs.setString('widget_updated_at', DateTime.now().toIso8601String());
      return;
    }

    final balance = loan.totalPayable - totalPaid;
    final clampedBalance = balance < 0 ? 0.0 : balance;
    final progress = loan.totalPayable > 0
        ? (totalPaid / loan.totalPayable).clamp(0.0, 1.0)
        : 0.0;
    final days = loan.daysRemaining;

    await prefs.setString('widget_loan_title', loan.title);
    await prefs.setString(
      'widget_balance',
      'Ksh ${_fmt(clampedBalance)}',
    );
    await prefs.setString(
      'widget_next_due',
      'Due ${_fmtDate(loan.dueDate)}',
    );
    await prefs.setString(
      'widget_daily_amount',
      'Ksh ${_fmt(loan.expectedPerInterval)}/interval',
    );
    await prefs.setDouble('widget_progress', progress);
    await prefs.setString('widget_total_paid', 'Ksh ${_fmt(totalPaid)}');
    await prefs.setString('widget_total_payable', 'Ksh ${_fmt(loan.totalPayable)}');
    await prefs.setInt('widget_days_remaining', days);
    await prefs.setString('widget_updated_at', DateTime.now().toIso8601String());
  }

  String _fmt(double v) {
    // Format with thousands separator, 0 decimal places (compact for widget)
    final s = v.toStringAsFixed(0);
    // Insert thousands separators
    final buf = StringBuffer();
    var count = 0;
    for (var i = s.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) buf.write(',');
      buf.write(s[i]);
      count++;
    }
    return String.fromCharCodes(buf.toString().codeUnits.reversed);
  }

  String _fmtDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}
