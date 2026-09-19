import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/payment.dart';
import '../providers/loan_provider.dart';
import '../theme/app_tokens.dart';
import '../theme/theme.dart';
import 'app_components.dart';

/// Streak tracker card — counts consecutive days the user made a payment.
///
/// Uses Material 3 design language: tonal surface, subtle icon bubble,
/// status chip. No neon glow.
class StreakTrackerCard extends StatelessWidget {
  const StreakTrackerCard({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LoanProvider>();
    final payments = provider.recentPayments;

    if (payments.isEmpty) return const SizedBox.shrink();

    final currentStreak = _computeCurrentStreak(payments);
    final longestStreak = _computeLongestStreak(payments);
    final todayPaid = provider.todayPaid;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          IconBubble(
            icon: Icons.local_fire_department_outlined,
            color: currentStreak > 0
                ? Theme.of(context).extension<LoanTrackerDesignTokens>()!.warning
                : Theme.of(context).colorScheme.onSurfaceVariant,
            size: 44,
            iconSize: 22,
          ),
          const SizedBox(width: AppSpacing.md),
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
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: currentStreak > 0
                                ? Theme.of(context)
                                    .extension<LoanTrackerDesignTokens>()!
                                    .warning
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'day${currentStreak == 1 ? '' : 's'} streak',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _motivationalMessage(currentStreak, longestStreak),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                if (longestStreak > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.emoji_events_outlined,
                        size: 14,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Best: $longestStreak day${longestStreak == 1 ? '' : 's'}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.secondary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          StatusChip(
            label: todayPaid ? 'TODAY' : 'PENDING',
            variant: todayPaid
                ? StatusChipVariant.success
                : StatusChipVariant.warning,
            icon: todayPaid ? Icons.check_circle : Icons.schedule,
          ),
        ],
      ),
    );
  }

  static int _computeCurrentStreak(List<Payment> payments) {
    if (payments.isEmpty) return 0;
    final paidDays = <String>{};
    for (final p in payments) {
      final d = p.paidAt;
      paidDays.add(
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');
    }

    var streak = 0;
    var cursor = DateTime.now();
    final todayKey =
        '${cursor.year}-${cursor.month.toString().padLeft(2, '0')}-${cursor.day.toString().padLeft(2, '0')}';
    if (!paidDays.contains(todayKey)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }

    while (true) {
      final key =
          '${cursor.year}-${cursor.month.toString().padLeft(2, '0')}-${cursor.day.toString().padLeft(2, '0')}';
      if (paidDays.contains(key)) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }

  static int _computeLongestStreak(List<Payment> payments) {
    if (payments.isEmpty) return 0;
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
    if (current == 0) return 'Log a payment today to start a new streak.';
    if (current == 1) return 'Great start! Pay again tomorrow to build momentum.';
    if (current < 5) return 'Keep going — $current days and counting!';
    if (current < longest) return 'Beat your best of $longest days!';
    if (current == longest && current >= 5) {
      return 'Tied your best streak — break it tomorrow!';
    }
    return 'New personal best! Keep it up!';
  }
}
