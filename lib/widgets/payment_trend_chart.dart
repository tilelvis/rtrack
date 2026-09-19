import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/payment.dart';
import '../theme/theme.dart';

/// Weekly payment trend chart.
///
/// Shows the last [weeks] weeks of payments as a line chart, with each
/// data point representing the total paid in that ISO week.
/// The expected-per-interval line is drawn as a dashed reference.
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Payment Trend',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const Spacer(),
                _legend(),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Last ${widget.weeks} weeks • total paid per week',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: weeklyData.isEmpty || maxY == 0
                  ? _emptyChart()
                  : LineChart(_buildChart(weeklyData, maxY)),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: weeklyData
                  .map(
                    (d) => Expanded(
                      child: Text(
                        d.label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legend() {
    return Row(
      children: [
        Container(
          width: 10,
          height: 2,
          color: AppTheme.primary,
        ),
        const SizedBox(width: 4),
        Text(
          'Paid',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 10,
          ),
        ),
        const SizedBox(width: 10),
        if (widget.expectedPerWeek > 0) ...[
          CustomPaint(
            size: const Size(10, 2),
            painter: _DashedLinePainter(
              color: AppTheme.accent,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'Target',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 10,
            ),
          ),
        ],
      ],
    );
  }

  Widget _emptyChart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.show_chart,
            color: AppTheme.primary.withOpacity(0.3),
            size: 40,
          ),
          const SizedBox(height: 8),
          Text(
            'No payments to chart yet',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  LineChartData _buildChart(
    List<WeekData> data,
    double maxY,
  ) {
    final paidSpots = <FlSpot>[];

    for (var i = 0; i < data.length; i++) {
      paidSpots.add(
        FlSpot(
          i.toDouble(),
          data[i].total,
        ),
      );
    }

    final targetSpots = <FlSpot>[];

    if (widget.expectedPerWeek > 0) {
      for (var i = 0; i < data.length; i++) {
        targetSpots.add(
          FlSpot(
            i.toDouble(),
            widget.expectedPerWeek,
          ),
        );
      }
    }

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: maxY > 0 ? maxY / 4 : 1,
        getDrawingHorizontalLine: (value) => FlLine(
          color: AppTheme.border.withOpacity(0.5),
          strokeWidth: 1,
        ),
      ),
      titlesData: const FlTitlesData(
        show: false,
      ),
      borderData: FlBorderData(
        show: false,
      ),
      minY: 0,
      maxY: maxY,
      lineBarsData: [
        if (targetSpots.isNotEmpty)
          LineChartBarData(
            spots: targetSpots,
            isCurved: false,
            color: AppTheme.accent,
            barWidth: 1.5,
            dashArray: [4, 4],
            dotData: const FlDotData(
              show: false,
            ),
            belowBarData: BarAreaData(
              show: false,
            ),
          ),
        LineChartBarData(
          spots: paidSpots,
          isCurved: true,
          curveSmoothness: 0.35,
          color: AppTheme.primary,
          barWidth: 2.5,
          dotData: FlDotData(
            show: true,
            getDotPainter: (
              spot,
              percent,
              barData,
              index,
            ) =>
                FlDotCirclePainter(
              radius: 3.5,
              color: AppTheme.primary,
              strokeWidth: 2,
              strokeColor: AppTheme.bg,
            ),
          ),
          belowBarData: BarAreaData(
            show: true,
            color: AppTheme.primary.withOpacity(0.12),
          ),
        ),
      ],
      lineTouchData: LineTouchData(
        enabled: true,
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (touchedSpot) => AppTheme.surfaceAlt,
          tooltipRoundedRadius: 8,
          tooltipPadding: const EdgeInsets.all(8),
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              final idx = spot.spotIndex;
              final weekData = data[idx];

              return LineTooltipItem(
                '${weekData.label}\nKsh ${spot.y.toStringAsFixed(0)}',
                TextStyle(
                  color: AppTheme.textPrimary,
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

  /// Group payments by ISO week, returning last [weeks] weeks oldest-first.
  List<WeekData> _aggregateByWeek(
    List<Payment> payments,
    int weeks,
  ) {
    final now = DateTime.now();

    // Find the Monday of the current week.
    final monday = now.subtract(
      Duration(days: now.weekday - 1),
    );

    final weeksList = <WeekData>[];

    for (var i = weeks - 1; i >= 0; i--) {
      final weekStart = monday.subtract(
        Duration(days: 7 * i),
      );

      final weekEnd = weekStart.add(
        const Duration(days: 7),
      );

      final total = payments
          .where(
            (p) =>
                !p.paidAt.isBefore(weekStart) &&
                p.paidAt.isBefore(weekEnd),
          )
          .fold<double>(
            0,
            (sum, payment) => sum + payment.amount,
          );

      final label = i == 0
          ? 'This wk'
          : DateFormat('d/M').format(weekStart);

      weeksList.add(
        WeekData(
          label: label,
          total: total,
        ),
      );
    }

    return weeksList;
  }

  double _computeMaxY(
    List<WeekData> data,
    double expected,
  ) {
    var maxPaid = 0.0;

    for (final d in data) {
      if (d.total > maxPaid) {
        maxPaid = d.total;
      }
    }

    var maxVal = maxPaid > expected ? maxPaid : expected;

    // Round up to nearest 100 for nicer gridlines.
    if (maxVal <= 0) {
      return 100;
    }

    final rounded = (maxVal / 100).ceil() * 100;
    return rounded.toDouble();
  }
}

class WeekData {
  final String label;
  final double total;

  WeekData({
    required this.label,
    required this.total,
  });
}

class _DashedLinePainter extends CustomPainter {
  final Color color;

  _DashedLinePainter({
    required this.color,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const dashWidth = 3.0;
    const dashSpace = 2.0;

    var x = 0.0;

    while (x < size.width) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + dashWidth, 0),
        paint,
      );

      x += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(
    covariant _DashedLinePainter oldDelegate,
  ) {
    return oldDelegate.color != color;
  }
}
