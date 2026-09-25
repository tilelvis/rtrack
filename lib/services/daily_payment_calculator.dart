import '../models/loan.dart';

/// Daily payment recommendation calculator.
///
/// Given the remaining balance and days until due, computes a recommended
/// daily payment amount that will pay off the loan by the due date.
///
/// Logic:
///   daily = remainingBalance / daysRemaining
///
/// With smart behaviour:
///   - If daysRemaining <= 0 (loan overdue): recommends full balance today,
///     flagged as [RecommendationSeverity.critical]
///   - If daily <= 50 (manageable): rounded up to nearest 50, severity normal
///   - If daily between 50 and 200: rounded up to nearest 25, severity moderate
///   - If daily > 200: rounded up to nearest 100, severity elevated
///   - If loan is fully paid: returns 0 with severity paid
///
/// The goal is to give the user a concrete, actionable number every day
/// that adapts as time passes and as payments are made.
class DailyPaymentRecommendation {
  final double dailyAmount;
  final double remainingBalance;
  final int daysRemaining;
  final RecommendationSeverity severity;
  final String message;
  final bool isOnTrack;
  final double projectedFinalDay;

  DailyPaymentRecommendation({
    required this.dailyAmount,
    required this.remainingBalance,
    required this.daysRemaining,
    required this.severity,
    required this.message,
    required this.isOnTrack,
    required this.projectedFinalDay,
  });

  /// Whether the user needs to take action today.
  bool get needsActionToday => severity != RecommendationSeverity.paid;
}

enum RecommendationSeverity {
  /// Loan is fully paid — no action needed.
  paid,

  /// Plenty of time, manageable daily amount.
  normal,

  /// Getting closer — moderate daily amount, should stay on top of it.
  moderate,

  /// Days are shrinking — daily amount is climbing, pay attention.
  elevated,

  /// Critical — overdue or massive daily amount, urgent action required.
  critical,
}

class DailyPaymentCalculator {
  DailyPaymentCalculator._();

  /// Compute the recommended daily payment for the given loan + balance.
  static DailyPaymentRecommendation compute({
    required Loan loan,
    required double remainingBalance,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final balance = remainingBalance < 0 ? 0.0 : remainingBalance;

    // ----------------------------------------------------------------
    // Fully paid
    // ----------------------------------------------------------------
    if (balance <= 0.01) {
      return DailyPaymentRecommendation(
        dailyAmount: 0,
        remainingBalance: 0,
        daysRemaining: loan.daysRemaining,
        severity: RecommendationSeverity.paid,
        message: 'Loan fully paid — well done! 🎉',
        isOnTrack: true,
        projectedFinalDay: 0,
      );
    }

    // ----------------------------------------------------------------
    // Days remaining
    // ----------------------------------------------------------------
    final days = loan.daysRemaining; // 0 if overdue
    final isOverdue = today.isAfter(loan.dueDate);

    if (isOverdue || days <= 0) {
      // Overdue — must pay everything TODAY
      return DailyPaymentRecommendation(
        dailyAmount: balance,
        remainingBalance: balance,
        daysRemaining: 0,
        severity: RecommendationSeverity.critical,
        message:
            'OVERDUE — pay Ksh ${_fmt(balance)} today to clear the loan.',
        isOnTrack: false,
        projectedFinalDay: balance,
      );
    }

    // ----------------------------------------------------------------
    // Compute raw daily amount
    // ----------------------------------------------------------------
    final rawDaily = balance / days;

    // ----------------------------------------------------------------
    // Round to a friendly amount
    // ----------------------------------------------------------------
    double daily;
    if (rawDaily <= 50) {
      daily = _roundUpTo(rawDaily, 50);
    } else if (rawDaily <= 200) {
      daily = _roundUpTo(rawDaily, 25);
    } else if (rawDaily <= 500) {
      daily = _roundUpTo(rawDaily, 50);
    } else {
      daily = _roundUpTo(rawDaily, 100);
    }

    // Never recommend less than 50 unless balance itself is tiny
    if (balance < 50) daily = balance;

    // ----------------------------------------------------------------
    // Severity based on days + daily amount
    // ----------------------------------------------------------------
    RecommendationSeverity severity;
    String message;
    bool onTrack;

    if (days <= 3) {
      severity = RecommendationSeverity.critical;
      message = 'Only $days day${days == 1 ? '' : 's'} left — '
          'pay Ksh ${_fmt(daily)} daily to clear Ksh ${_fmt(balance)}.';
      onTrack = false;
    } else if (days <= 7) {
      severity = RecommendationSeverity.elevated;
      message = '$days days left, Ksh ${_fmt(balance)} remaining — '
          'pay Ksh ${_fmt(daily)} daily.';
      onTrack = false;
    } else if (days <= 14) {
      severity = RecommendationSeverity.moderate;
      message = '$days days left — Ksh ${_fmt(daily)} daily keeps you on track.';
      onTrack = true;
    } else if (rawDaily > 500) {
      severity = RecommendationSeverity.elevated;
      message = 'Heavy daily load: Ksh ${_fmt(daily)}/day for $days days. '
          'Pay early to reduce pressure.';
      onTrack = false;
    } else {
      severity = RecommendationSeverity.normal;
      message = '$days days left — Ksh ${_fmt(daily)} daily covers it. '
          'You\'re on track.';
      onTrack = true;
    }

    return DailyPaymentRecommendation(
      dailyAmount: daily,
      remainingBalance: balance,
      daysRemaining: days,
      severity: severity,
      message: message,
      isOnTrack: onTrack,
      projectedFinalDay: daily * days,
    );
  }

  /// Round `value` up to the nearest `step`.
  /// e.g. _roundUpTo(173, 25) = 175
  static double _roundUpTo(double value, double step) {
    if (step <= 0) return value;
    return (value / step).ceil() * step;
  }

  static String _fmt(double v) => v.toStringAsFixed(0);
}
