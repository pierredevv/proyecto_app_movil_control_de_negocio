import 'dart:ui';
import 'package:flutter/material.dart';

class GlassTransactionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final double amount;
  final String status;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;
  final bool isOrder;
  final Color? borderColor;
  final Widget? actionButtons;
  final String? heroTag;

  const GlassTransactionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.status,
    required this.color,
    required this.icon,
    this.onTap,
    this.isOrder = false,
    this.borderColor,
    this.actionButtons,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    // Side border color calculation
    final sideColor = borderColor ?? _getBorderColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Stack(
        children: [
          // Colored side border
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 4,
              decoration: BoxDecoration(
                color: sideColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
          ),
          // Glassmorphism Card
          Container(
            margin: const EdgeInsets.only(left: 4),
            decoration: BoxDecoration(
              color: const Color(0x26FFFFFF), // White 15% opacity
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0x1AFFFFFF), // White 10% opacity
                width: 1.5,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x26000000), // Black 15% opacity
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: onTap,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              // Leading Icon
                              heroTag != null
                                  ? Hero(
                                      tag: heroTag!,
                                      child: Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color:
                                              sideColor.withValues(alpha: 0.2),
                                        ),
                                        child: Icon(_getStatusIcon(status),
                                            color: sideColor, size: 24),
                                      ),
                                    )
                                  : Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: sideColor.withValues(alpha: 0.2),
                                      ),
                                      child: Icon(_getStatusIcon(status),
                                          color: sideColor, size: 24),
                                    ),
                              const SizedBox(width: 16),
                              // Content
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors
                                            .white, // Always white on glass
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      subtitle,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[200],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Trailing Info
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Bs. ${amount.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: isOrder ? sideColor : Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  _buildStatusBadge(status),
                                ],
                              ),
                            ],
                          ),
                          if (actionButtons != null) ...[
                            const SizedBox(height: 12),
                            Divider(
                                height: 1,
                                color: Colors.white.withValues(alpha: 0.1)),
                            const SizedBox(height: 8),
                            actionButtons!,
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getBorderColor(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
      case 'PAID':
      case 'RECEIVED':
        return const Color(0xFF51CF66); // Green
      case 'PARTIAL':
        return const Color(0xFFF59F00); // Orange
      case 'CREDIT':
        return const Color(0xFF1C7ED6); // Blue
      case 'PENDING':
        return const Color(0xFFFFA94D); // Yellow
      case 'OVERDUE':
        return const Color(0xFFFF6B6B); // Red
      case 'VOIDED':
      case 'CANCELLED':
        return const Color(0xFF6B7494); // Gray
      case 'CONFIRMED':
        return const Color(0xFF29B6F6); // Light Blue
      default:
        return const Color(0xFF4A90E2); // Blue (default)
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
      case 'PAID':
      case 'RECEIVED':
        return Icons.check_circle;
      case 'PARTIAL':
        return Icons.monetization_on;
      case 'CREDIT':
        return Icons.account_balance_wallet;
      case 'PENDING':
        return Icons.schedule;
      case 'EXPIRED':
        return Icons.access_time;
      case 'VOIDED':
      case 'CANCELLED':
        return Icons.cancel;
      case 'CONFIRMED':
        return Icons.check_circle_outline;
      default:
        return Icons.local_shipping;
    }
  }

  String _translateStatus(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return 'PENDIENTE';
      case 'RECEIVED':
        return 'RECIBIDO';
      case 'COMPLETED':
        return 'COMPLETADO';
      case 'PARTIAL':
        return 'PARCIAL';
      case 'CREDIT':
        return 'CRÉDITO';
      case 'PAID':
        return 'PAGADO';
      case 'CANCELLED':
        return 'CANCELADO';
      case 'CONFIRMED':
        return 'CONFIRMADO';
      case 'VOIDED':
        return 'ANULADO';
      default:
        return status;
    }
  }

  Widget _buildStatusBadge(String status) {
    final badgeColor = _getBorderColor(status);
    final label = _translateStatus(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: badgeColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
