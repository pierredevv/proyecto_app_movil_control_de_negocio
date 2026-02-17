import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class SkeletonListItem extends StatelessWidget {
  final double height;
  final bool hasImage;

  const SkeletonListItem({super.key, this.height = 72, this.hasImage = true});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final shimmerColor = isDark ? Colors.grey[700] : Colors.grey[100];

    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          if (hasImage) ...[
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.circular(8),
              ),
            )
                .animate(onPlay: (c) => c.repeat())
                .shimmer(duration: 1200.ms, color: shimmerColor),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: double.infinity,
                  height: 14,
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ).animate(onPlay: (c) => c.repeat()).shimmer(
                    duration: 1200.ms, delay: 200.ms, color: shimmerColor),
                const SizedBox(height: 8),
                Container(
                  width: 150,
                  height: 12,
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ).animate(onPlay: (c) => c.repeat()).shimmer(
                    duration: 1200.ms, delay: 400.ms, color: shimmerColor),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
