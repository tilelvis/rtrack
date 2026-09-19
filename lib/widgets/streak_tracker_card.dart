import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/payment.dart';
import '../providers/loan_provider.dart';
import '../theme/theme.dart';

/// Streak tracker card — counts consecutive **calendar days** the user
/// made at least one payment, ending today.
///
/// Rules:
///   - Today paid → streak includes today
///   - Today not paid, but yesterday paid → streak is the count up to
///     yesterday (today breaks it tomorrow if not paid)
///   - Two consecutive days with no payment → streak = 0
///
/// The card also shows the longest streak ever recorded (computed from
/// the full payment history) and a motivational message.
class StreakTrackerCard extends StatelessWidget {
  const StreakTrackerCard({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LoanProvider>();
    final payments = provider.recentPayments;

    if (payments.isEmpty) {
      return const SizedBox.shrink();
    }

    final currentStreak = _computeCurrentStreak(payments);
    final longestStreak = _computeLongestStreak(payments);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Flame icon + streak count
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: (currentStreak > 0
                        ? AppTheme.warning
                        : AppTheme.surfaceAlt)
                    .withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: (currentStreak > 0
                          ? AppTheme.warning
                          : AppTheme.border)
                      .withOpacity(0.5),
                ),
              ),
              child: Icon(
                currentStreak > 0 ? Icons.local_fire_department : Icons.whatshot_outlined,
                color: currentStreak > 0 ? AppTheme.warning : AppTheme.textSecondary,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$currentStreak',
                        style: TextStyle(
                          color: currentStreak > 0
                              ? AppTheme.warning
                              : AppTheme.textPrimary,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'day${currentStreak == 1 ? '' : 's'} streak',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _motivationalMessage(currentStreak, longestStreak),
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  if (longestStreak > 0) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.emoji_events_outlined,
                            size: 14, color: AppTheme.accent),
                        const SizedBox(width: 4),
                        Text(
                          'Best: $longestStreak day${longestStreak == 1 ? '' : 's'}',
                          style: const TextStyle(
                            color: AppTheme.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // "Today" status badge
            _todayBadge(provider.todayPaid),
          ],
        ),
      ),
    );
  }

  Widget _todayBadge(bool paid) {
    final color = paid ? AppTheme.primary : AppTheme.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(paid ? Icons.check_circle : Icons.schedule, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            paid ? 'TODAY' : 'PENDING',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }

  /// Compute current streak: consecutive days with at least one payment,
  /// ending today (or yesterday if today not yet paid).
  static int _computeCurrentStreak(List<Payment> payments) {
    if (payments.isEmpty) return 0;

    // Build a set of "YYYY-MM-DD" strings of all paid days.
    final paidDays = <String>{};
    for (final p in payments) {
      final d = p.paidAt;
      paidDays.add('${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');
    }

    // Walk backwards from today.
    // If today is NOT paid, start from yesterday (grace period).
    var streak = 0;
    var cursor = DateTime.now();
    final todayKey = '${cursor.year}-${cursor.month.toString().padLeft(2, '0')}-${cursor.day.toString().padLeft(2, '0')}';
    if (!paidDays.contains(todayKey)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }

    while (true) {
      final key = '${cursor.year}-${cursor.month.toString().padLeft(2, '0')}-${cursor.day.toString().padLeft(2, '0')}';
      if (paidDays.contains(key)) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }

  /// Compute the longest streak ever achieved from the payment history.
  static int _computeLongestStreak(List<Payment> payments) {
    if (payments.isEmpty) return 0;

    // Sort payments oldest-first, deduplicate by date.
    final sorted = List<Payment>.from(payments)
      ..sort((a, b) => a.paidAt.compareTo(b.paidAt));
    final paidDays = <DateTime>[];
    for (final p in sorted) {
      final d = DateTime(p.paidAt.year, p.paidAt.month, p.paidAt.day);
      if (paidDays.isEmpty || paidDays.last != d) {
        paidDays.add(d);
      }
    }

    var longest = 1;
    var current = 1;
    for (var i = 1; i < paidDays.length; i++) {
      final diff = paidDays[i].difference(paidDays[i - 1]).inDays;
      if (diff == 1) {
        current++;
        if (current > longest) longest = current;
      } else {
        current = 1;
      }
    }
    return longest;
  }

  static String _motivationalMessage(int current, int longest) {
    if (current == 0) {
      return 'Log a payment today to start a new streak.';
    }
    if (current == 1) {
      return 'Great start! Pay again tomorrow to build momentum.';
    }
    if (current < 5) {
      return 'Keep going — $current days and counting!';
    }
    if (current < longest) {
      return 'Beat your best of $longest days!';
    }
    if (current == longest && current >= 5) {
      return 'Tied your best streak — break it tomorrow! 🚀';
    }
    return 'New personal best! Keep it up! 🚀';
  }
}
