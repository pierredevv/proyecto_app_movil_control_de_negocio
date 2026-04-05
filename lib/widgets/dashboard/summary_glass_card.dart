import 'dart:math';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

class SummaryGlassCard extends StatelessWidget {
  final double salesTotal;
  final double purchasesTotal;
  final double balancePercentage; // 0.0 to 1.0 (or higher)

  const SummaryGlassCard({
    super.key,
    required this.salesTotal,
    required this.purchasesTotal,
    required this.balancePercentage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Light Mode: White Card with Shadow (Apple Style)
    // Dark Mode: Glassmorphism

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: isDark
            ? Border.all(color: Colors.white.withValues(alpha: 0.2))
            : Border.all(
                color:
                    Colors.transparent), // No border in light mode, just shadow
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.grey.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Sales (Left)
          Expanded(
            child: _buildSideStat(
              context,
              label: 'Ventas',
              amount: salesTotal,
              color: AppTheme.greenAccent,
              alignment: CrossAxisAlignment.start,
            ),
          ),

          // Gauge (Center)
          _buildGauge(context),

          // Purchases (Right)
          Expanded(
            child: _buildSideStat(
              context,
              label: 'Compras Emitidas',
              amount: purchasesTotal,
              color: AppTheme.redAccent,
              alignment: CrossAxisAlignment.end,
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.1, end: 0, curve: Curves.easeOut);
  }

  Widget _buildSideStat(BuildContext context,
      {required String label,
      required double amount,
      required Color color,
      required CrossAxisAlignment alignment}) {
    final currencyFormat = NumberFormat.currency(
        symbol: 'Bs. ', decimalDigits: 2, locale: 'es_BO');
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            fontSize: 12,
            fontWeight: FontWeight.w400,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignment == CrossAxisAlignment.start 
              ? Alignment.centerLeft 
              : Alignment.centerRight,
          child: Text(
            currencyFormat.format(amount),
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              fontFamily: 'Inter',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGauge(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 110,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: CustomPaint(
              painter: _GaugePainter(
                percentage: balancePercentage,
                isDark: theme.brightness == Brightness.dark,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.show_chart,
                        color: AppTheme.greenAccent, size: 20),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '+${(balancePercentage * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: AppTheme.greenAccent,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
          Text(
            'Balance',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double percentage;
  final bool isDark;

  _GaugePainter({required this.percentage, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    const double strokeWidth = 10;

    final Paint bgPaint = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.1)
          : Colors.grey.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    const double startAngle = 135 * (pi / 180);
    const double sweepAngle = 270 * (pi / 180);

    // Inset to prevent clipping
    final Rect rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width - strokeWidth,
      height: size.height - strokeWidth,
    );

    // Draw Background Arc
    canvas.drawArc(rect, startAngle, sweepAngle, false, bgPaint);

    // Draw Gradient Progress Arc
    final Paint progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        colors: [
          Color(0xFF4CAF50), // Standard Green
          Color(0xFF69F0AE), // Light Green
        ],
        begin: Alignment.bottomLeft,
        end: Alignment.bottomRight,
      ).createShader(rect);

    final double progressSweep = sweepAngle * percentage.clamp(0.0, 1.0);
    canvas.drawArc(rect, startAngle, progressSweep, false, progressPaint);

    // Draw Indicator Dot
    final double dotAngle = startAngle + progressSweep;
    // Radius for dot position is half of the rect width
    final double radius = (size.width - strokeWidth) / 2;
    final double centerX = size.width / 2;
    final double centerY = size.height / 2;

    final double dotX = centerX + radius * cos(dotAngle);
    final double dotY = centerY + radius * sin(dotAngle);

    // Outer Glow Ring
    canvas.drawCircle(
        Offset(dotX, dotY),
        8,
        Paint()
          ..color = const Color(0xFF69F0AE).withValues(alpha: 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));

    // Core Dot
    final Paint dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2);

    canvas.drawCircle(Offset(dotX, dotY), 4, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
