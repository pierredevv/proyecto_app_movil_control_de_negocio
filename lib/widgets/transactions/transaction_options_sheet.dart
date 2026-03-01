import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class TransactionOptionsBottomSheet extends StatelessWidget {
  final VoidCallback? onEdit;
  final VoidCallback? onCancel;
  final VoidCallback? onSharePdf;
  final VoidCallback? onDuplicate;
  final bool isVoided;
  final bool showSharePdf;
  final bool showDuplicate;

  const TransactionOptionsBottomSheet({
    super.key,
    this.onEdit,
    this.onCancel,
    this.onSharePdf,
    this.onDuplicate,
    this.isVoided = false,
    this.showSharePdf = true,
    this.showDuplicate = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2432) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle Bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 24),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Title
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Text(
                'Opciones de Transacción',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),

            // Options
            if (!isVoided) ...[
              _buildOption(
                context,
                icon: Icons.edit,
                label: 'Editar Transacción',
                color: Colors.blue.shade100,
                iconColor: Colors.blue,
                onTap: onEdit,
                delay: 0,
              ),
              _buildOption(
                context,
                icon: Icons.cancel_outlined,
                label: 'Anular/Cancelar',
                color: Colors.red.shade100,
                iconColor: Colors.red,
                onTap: onCancel,
                delay: 50,
              ),
            ],

            if (showSharePdf)
              _buildOption(
                context,
                icon: Icons.picture_as_pdf_outlined,
                label: 'Compartir como PDF',
                color: Colors.purple.shade100,
                iconColor: Colors.purple,
                onTap: onSharePdf,
                delay: 100,
              ),

            if (showDuplicate)
              _buildOption(
                context,
                icon: Icons.copy_rounded,
                label: 'Duplicar Transacción',
                color: Colors.green.shade100,
                iconColor: Colors.green,
                onTap: onDuplicate,
                delay: 150,
              ),

            const SizedBox(height: 24),

            // Close Button
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cerrar',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required Color iconColor, // The actual icon color
    required int delay,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: () {
        Navigator.pop(context);
        onTap?.call();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? iconColor.withValues(alpha: 0.2)
                    : color, // Adjust for dark mode visibility
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 200.ms, delay: delay.ms)
        .slideY(begin: 0.1, end: 0);
  }
}
