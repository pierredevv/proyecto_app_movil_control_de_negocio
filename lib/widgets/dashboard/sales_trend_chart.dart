import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';

class SalesTrendChart extends StatelessWidget {
  final List<Map<String, dynamic>> weeklySales;

  const SalesTrendChart({super.key, this.weeklySales = const []});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Generate spots from weeklySales
    // weeklySales structure: [{'date': millis, 'amount': double}, ...]
    List<FlSpot> spots = [];
    List<String> dateLabels = [];

    // Reverse if needed? getWeeklySales returns: [Older -> Newer] usually or reverse loop.
    // Provider implementation: "for (int i = 6; i >= 0; i--)" adds oldest first (7 days ago).
    // So distinct index 0 is 7 days ago.

    if (weeklySales.isNotEmpty) {
      for (int i = 0; i < weeklySales.length; i++) {
        final amount = weeklySales[i]['amount'] as double;
        final dateMillis = weeklySales[i]['date'] as int;
        spots.add(FlSpot(i.toDouble(), amount));

        final date = DateTime.fromMillisecondsSinceEpoch(dateMillis);
        dateLabels.add('${date.day}/${date.month}');
      }
    } else {
      // Fallback empty spots
      for (int i = 0; i < 7; i++) {
        spots.add(FlSpot(i.toDouble(), 0));
      }
    }

    double maxY = 1000;
    double minY = 0;
    double displayMax = 1000;

    if (spots.isNotEmpty) {
      double maxVal = spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
      if (maxVal > 0) {
        // If we have actual sales, set max to that value efficiently
        maxY = maxVal; // Limit chart to actual max
        displayMax = maxVal; // Label shows actual max
      } else {
        // No sales, keep default
        maxY = 1000;
        displayMax = 1000;
      }
    }

    // Gradient colors
    const List<Color> gradientColors = [
      Color(0xFF5FD068), // Green (Top)
      Color(0xFFFECFEF), // Pastel Pink
      Color(0xFFFF9A9E), // Coral Pink (Bottom)
    ];

    return Container(
      height: 200,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      width: double.infinity,
      child: Stack(
        children: [
          // The Chart
          LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 1, // We control lines via check below
                getDrawingHorizontalLine: (value) {
                  if (value == 200 || value == 1500) {
                    return FlLine(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                      strokeWidth: 1,
                      dashArray: [4, 4],
                    );
                  }
                  return const FlLine(color: Colors.transparent);
                },
                checkToShowHorizontalLine: (value) =>
                    value == 200 || value == 1500,
              ),
              titlesData: FlTitlesData(
                show: true,
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: const AxisTitles(
                    sideTitles:
                        SideTitles(showTitles: false)), // Removed 80px space
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final style = TextStyle(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        fontSize: 12,
                      );

                      if (value.toInt() >= 0 &&
                          value.toInt() < dateLabels.length) {
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: Text(dateLabels[value.toInt()], style: style),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              minX: 0,
              maxX: 6,
              minY: minY,
              maxY: maxY,
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: isDark ? Colors.white : AppTheme.greenAccent,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: 4,
                        color: _getColorForValue(spot.y),
                        strokeWidth: 3,
                        strokeColor: Colors.white,
                      );
                    },
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        gradientColors[0].withValues(alpha: 0.7),
                        gradientColors[1].withValues(alpha: 0.2),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Custom Labels Overlay
          Positioned(
            left: 0,
            top: 20,
            child: Text('Máx. Bs. ${displayMax.toStringAsFixed(0)}',
                style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    fontSize: 10)),
          ),
          if (maxY == 1000 &&
              spots.every((e) =>
                  e.y == 0)) // Only show Min if using default scale (no data)
            Positioned(
              left: 0,
              bottom: 45,
              child: Text('Mín. Bs. ${minY.toStringAsFixed(0)}',
                  style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      fontSize: 10)),
            ),
        ],
      ),
    ).animate().scaleX(
        duration: const Duration(milliseconds: 1000), curve: Curves.easeOut);
  }

  Color _getColorForValue(double y) {
    // Simple mock approximation for dot center color
    if (y > 1000) return const Color(0xFF5FD068);
    if (y > 600) return const Color(0xFFFECFEF);
    return const Color(0xFFFF9A9E);
  }
}
