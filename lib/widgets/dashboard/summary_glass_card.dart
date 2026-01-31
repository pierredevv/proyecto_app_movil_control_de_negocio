import 'dart:math';
import 'package:flutter/material.dart';
import 'dart:ui';
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
    // Glassmorphism Specs
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 16), // Reduced padding
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1), // Reduced opacity
            borderRadius: BorderRadius.circular(24), // More rounded
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2), // Sharper border
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround, // Better spacing
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
                  label: 'Compras',
                  amount: purchasesTotal,
                  color: AppTheme.redAccent,
                  alignment: CrossAxisAlignment.end,
                ),
              ),
            ],
          ),
        ),
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

    return Column(
      crossAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12, // Smaller font
            fontWeight: FontWeight.w400,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          currencyFormat.format(amount),
          style: TextStyle(
            color: color,
            fontSize: 16, // Smaller font
            fontWeight: FontWeight.w700,
            fontFamily: 'Inter',
          ),
        ),
      ],
    );
  }

  Widget _buildGauge(BuildContext context) {
    return SizedBox(
      width: 110, // Fixed container width
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 80, // Smaller gauge
            height: 80, // Square area for full circle calculation
            child: CustomPaint(
              painter: _GaugePainter(percentage: balancePercentage),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                        Icons
                            .show_chart, // Changed icon to match "trend" notion better? Or stick to arrow.
                        color: AppTheme.greenAccent,
                        size: 20),
                    const SizedBox(height: 2),
                    Text(
                      '+${(balancePercentage * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        color: AppTheme.greenAccent,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12), // Push Balance text down
                  ],
                ),
              ),
            ),
          ),
          const Text(
            'Balance',
            style: TextStyle(
              color: AppTheme.textSecondary,
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

  _GaugePainter({required this.percentage});

  @override
  void paint(Canvas canvas, Size size) {
    // Specs: Arc thickness 10px, Inverted C (Arch)
    // Start 135 deg (Bottom-Left), Sweep 270 deg (to Bottom-Right)

    const double strokeWidth = 10;

    final Paint bgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
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
