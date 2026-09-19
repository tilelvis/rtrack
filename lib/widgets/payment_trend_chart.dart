import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/payment.dart';
import '../theme/app_tokens.dart';
import '../theme/theme.dart';
import 'app_components.dart';

/// Payment trend chart — line chart of weekly payments over last N weeks,
/// with a dashed target line for the expected-per-week amount.
///
/// Uses theme colors throughout:
///   - chartPaid (green) for the actual paid line
///   - chartTarget (blue, dashed) for the expected amount
///   - surfaceContainerHighest for the grid
class PaymentTrendChart extends StatefulWidget {
  final List<Payment> payments;
  final double expectedPerWeek;
  final int weeks;

  const PaymentTrendChart({
    super.key,
    required this.payments,
    this.expectedPerWeek = 0,
    this.weeks = 6,
  });

  @override
  State<PaymentTrendChart> createState() => _PaymentTrendChartState();
}

class _PaymentTrendChartState extends State<PaymentTrendChart> {
  @override
  Widget build(BuildContext context) {
    final weeklyData = _aggregateByWeek(widget.payments, widget.weeks);
    final maxY = _computeMaxY(weeklyData, widget.expectedPerWeek);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title + legend
          Row(
            children: [
              IconBubble(
                icon: Icons.show_chart,
                color: Theme.of(context).colorScheme.primary,
                size: 32,
                iconSize: 16,
              ),
              const SizedBox(width: AppSpacing.mdSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment Trend',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    Text(
                      'Last ${widget.weeks} weeks · total paid per week',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Chart
          SizedBox(
            height: 160,
            child: weeklyData.isEmpty || maxY == 0
                ? _emptyChart(context)
                : LineChart(_buildChart(weeklyData, maxY)),
          ),
          const SizedBox(height: AppSpacing.sm),

          // X-axis labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: weeklyData
                .map((d) => Expanded(
                      child: Text(
                        d.label,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontSize: 9,
                            ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: AppSpacing.md),

          // Legend
          Row(
            children: [
              _legendDot(
                context,
                color: Theme.of(context)
                    .extension<LoanTrackerDesignTokens>()!
                    .chartPaid,
                label: 'Paid',
                dashed: false,
              ),
              const SizedBox(width: AppSpacing.lg),
              if (widget.expectedPerWeek > 0)
                _legendDot(
                  context,
                  color: Theme.of(context)
                      .extension<LoanTrackerDesignTokens>()!
                      .chartTarget,
                  label: 'Target',
                  dashed: true,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendDot(
    BuildContext context, {
    required Color color,
    required String label,
    bool dashed = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (dashed)
          Row(
            children: List.generate(
              3,
              (_) => Container(
                width: 4,
                height: 2,
                margin: const EdgeInsets.only(right: 2),
                color: color,
              ),
            ),
          )
        else
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }

  Widget _emptyChart(BuildContext context) {
    final tokens = Theme.of(context).extension<LoanTrackerDesignTokens>()!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.show_chart,
            color: tokens.chartPaid.withOpacity(0.3),
            size: 36,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'No payments to chart yet',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  LineChartData _buildChart(List<WeekData> data, double maxY) {
    final tokens = Theme.of(context).extension<LoanTrackerDesignTokens>()!;
    final scheme = Theme.of(context).colorScheme;

    final paidSpots = <FlSpot>[];
    for (var i = 0; i < data.length; i++) {
      paidSpots.add(FlSpot(i.toDouble(), data[i].total));
    }

    final targetSpots = <FlSpot>[];
    if (widget.expectedPerWeek > 0) {
      for (var i = 0; i < data.length; i++) {
        targetSpots.add(FlSpot(i.toDouble(), widget.expectedPerWeek));
      }
    }

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: maxY > 0 ? maxY / 4 : 1,
        getDrawingHorizontalLine: (value) => FlLine(
          color: tokens.chartGrid,
          strokeWidth: 0.5,
        ),
      ),
      titlesData: const FlTitlesData(show: false),
      borderData: FlBorderData(show: false),
      minY: 0,
      maxY: maxY,
      lineBarsData: [
        // Target (dashed) line
        if (targetSpots.isNotEmpty)
          LineChartBarData(
            spots: targetSpots,
            isCurved: false,
            color: tokens.chartTarget,
            barWidth: 1.5,
            dashArray: [4, 4],
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
          ),
        // Actual paid line
        LineChartBarData(
          spots: paidSpots,
          isCurved: true,
          curveSmoothness: 0.35,
          color: tokens.chartPaid,
          barWidth: 2.5,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
              radius: 3,
              color: scheme.surface,
              strokeWidth: 2,
              strokeColor: tokens.chartPaid,
            ),
          ),
          belowBarData: BarAreaData(
            show: true,
            color: tokens.chartPaid.withOpacity(0.12),
          ),
        ),
      ],
      lineTouchData: LineTouchData(
        enabled: true,
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (touchedSpot) => scheme.inverseSurface,
          tooltipRoundedRadius: 8,
          tooltipPadding: const EdgeInsets.all(8),
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              final idx = spot.spotIndex;
              final weekData = data[idx];
              return LineTooltipItem(
                '${weekData.label}\nKsh ${spot.y.toStringAsFixed(0)}',
                TextStyle(
                  color: scheme.onInverseSurface,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              );
            }).toList();
          },
        ),
      ),
    );
  }

  List<WeekData> _aggregateByWeek(List<Payment> payments, int weeks) {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final weeksList = <WeekData>[];
    for (var i = weeks - 1; i >= 0; i--) {
      final weekStart = monday.subtract(Duration(days: 7 * i));
      final weekEnd = weekStart.add(const Duration(days: 7));
      final total = payments
          .where((p) =>
              !p.paidAt.isBefore(weekStart) && p.paidAt.isBefore(weekEnd))
          .fold<double>(0, (s, p) => s + p.amount);
      final label = i == 0 ? 'This wk' : DateFormat('d/M').format(weekStart);
      weeksList.add(WeekData(label: label, total: total));
    }
    return weeksList;
  }

  double _computeMaxY(List<WeekData> data, double expected) {
    var maxPaid = 0.0;
    for (final d in data) {
      if (d.total > maxPaid) maxPaid = d.total;
    }
    var maxVal = maxPaid > expected ? maxPaid : expected;
    if (maxVal <= 0) return 100;
    final rounded = (maxVal / 100).ceil() * 100;
    return rounded.toDouble();
  }
}

class WeekData {
  final String label;
  final double total;
  WeekData({required this.label, required this.total});
}
