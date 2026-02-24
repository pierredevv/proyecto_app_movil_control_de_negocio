import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../models/transaction_model.dart';
import '../../utils/haptic_feedback_helper.dart';
import '../../services/network_service.dart';
import '../../widgets/transactions/transaction_options_sheet.dart';
import '../utilities/print_preview_screen.dart';
import '../../services/database_service.dart'; // Import DatabaseService

class SaleDetailScreen extends StatefulWidget {
  final Sale sale;
  final String? heroTag;

  const SaleDetailScreen({super.key, required this.sale, this.heroTag});

  @override
  State<SaleDetailScreen> createState() => _SaleDetailScreenState();
}

class _SaleDetailScreenState extends State<SaleDetailScreen> {
  bool _isSendingReceipt = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Dynamic Colors based on Theme
    final backgroundColor = theme.scaffoldBackgroundColor;
    final cardColor = isDark ? const Color(0xFF252A36) : Colors.white;
    final textColor = theme.colorScheme.onSurface;
    final subTextColor = isDark ? const Color(0xFF9CA3AF) : Colors.grey[600];
    final dividerColor = theme.dividerColor.withValues(alpha: 0.1);

    // Constants
    const greenColor = Color(0xFF4CAF50);
    const yellowColor = Color(0xFFFBC02D);

    final currencyFormat = NumberFormat.currency(
        symbol: 'Bs. ', decimalDigits: 2, locale: 'es_BO');
    final dateFormat = DateFormat('dd MMM, yyyy', 'es_BO');
    final timeFormat = DateFormat('HH:mm', 'es_BO');

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text('Detalle de Venta',
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 18, color: textColor)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.more_vert, color: textColor), // Correct icon color
            onPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (context) => TransactionOptionsBottomSheet(
                  onEdit: () {},
                  onCancel: () => _handleVoidSale(),
                  onSharePdf: () {},
                  onDuplicate: () {},
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 1. Header Card
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  if (!isDark)
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                ],
              ),
              child: Stack(
                children: [
                  // Green Bar
                  Positioned(
                    left: 0,
                    top: 20,
                    bottom: 20,
                    child: Container(
                      width: 4,
                      decoration: const BoxDecoration(
                        color: greenColor,
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(4),
                          bottomRight: Radius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Hero(
                              tag: widget.heroTag ??
                                  'sale_${widget.sale.id}_icon',
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDark
                                      ? const Color(0xFF333333)
                                      : Colors.grey[200],
                                ),
                                alignment: Alignment.center,
                                child: const Text('S',
                                    style: TextStyle(
                                        color: yellowColor,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'VENTA #${widget.sale.id}',
                                    style: TextStyle(
                                      color: subTextColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.sale.customerName ??
                                        'Cliente Ocasional',
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Status Pill
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: greenColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.circle,
                                      size: 8, color: greenColor),
                                  SizedBox(width: 6),
                                  Text(
                                    'Completado',
                                    style: TextStyle(
                                      color: greenColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Divider
                        Divider(
                            color: theme.dividerColor.withValues(alpha: 0.1),
                            height: 1),
                        const SizedBox(height: 16),
                        // Date & Time Rows
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Fecha',
                                      style: TextStyle(
                                          color: subTextColor, fontSize: 12)),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF2A2F3D)
                                          : Colors.grey[100],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.calendar_today_outlined,
                                            size: 16, color: textColor),
                                        const SizedBox(width: 8),
                                        Text(
                                          dateFormat.format(widget.sale.date),
                                          style: TextStyle(
                                              color: textColor,
                                              fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Hora',
                                      style: TextStyle(
                                          color: subTextColor, fontSize: 12)),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF2A2F3D)
                                          : Colors.grey[100],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.access_time_rounded,
                                            size: 16, color: textColor),
                                        const SizedBox(width: 8),
                                        Text(
                                          timeFormat.format(widget.sale.date),
                                          style: TextStyle(
                                              color: textColor,
                                              fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fade().slideY(begin: 0.1, end: 0),

            const SizedBox(height: 24),

            // 2. Products Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'PRODUCTOS',
                  style: TextStyle(
                    color: subTextColor,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${widget.sale.items.length} items',
                    style: TextStyle(color: subTextColor, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Products Card
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  if (!isDark)
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                ],
              ),
              child: Column(
                children: widget.sale.items.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final isLast = index == widget.sale.items.length - 1;

                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      border: isLast
                          ? null
                          : Border(
                              bottom: BorderSide(color: dividerColor, width: 1),
                            ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Product Icon/Image
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.shopping_bag_outlined,
                              color: isDark ? Colors.white70 : Colors.blue,
                              size: 20),
                        ),
                        const SizedBox(width: 12),
                        // Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.productName,
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${item.quantity} x ${currencyFormat.format(item.unitPrice)}',
                                style: TextStyle(
                                  color: subTextColor,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Price
                        Text(
                          currencyFormat.format(item.subtotal),
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ).animate().fade(delay: 100.ms).slideY(begin: 0.1, end: 0),

            const SizedBox(height: 24),

            // 3. Totals Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  if (!isDark)
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                ],
              ),
              child: Column(
                children: [
                  _buildSummaryRow('Subtotal', widget.sale.totalAmount,
                      currencyFormat, subTextColor),
                  const SizedBox(height: 12),
                  _buildSummaryRow(
                      'Descuento', 0.00, currencyFormat, subTextColor),
                  const SizedBox(height: 12),
                  _buildSummaryRow('IVA (13%)', widget.sale.totalAmount * 0.13,
                      currencyFormat, subTextColor),
                  const SizedBox(height: 16),
                  Divider(color: dividerColor),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Pagado',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        currencyFormat.format(widget.sale.totalAmount),
                        style: TextStyle(
                          color: textColor,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ).animate().fade(delay: 200.ms).slideY(begin: 0.1, end: 0),

            const SizedBox(height: 16),

            // Info Note
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E2432)
                    : Colors.blue.withValues(alpha: 0.05), // Darker for info
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: Colors.blue, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Esta transacción fue procesada exitosamente.',
                      style: TextStyle(
                          color: subTextColor, fontSize: 12, height: 1.4),
                    ),
                  )
                ],
              ),
            ).animate().fade(delay: 300.ms),

            const SizedBox(height: 32),

            // 4. Action Buttons
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _handleGeneratePdf,
                      icon: Icon(Icons.receipt_long_rounded,
                          color: isDark ? Colors.white : Colors.black87,
                          size: 20),
                      label: Text('Emitir Factura',
                          style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark
                            ? const Color(0xFF2E323F)
                            : Colors
                                .grey[200], // Dark Gray Button vs Light Gray
                        foregroundColor: isDark ? Colors.white : Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.grey.withValues(alpha: 0.3)),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _isSendingReceipt ? null : _handleSendReceipt,
                      icon: _isSendingReceipt
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.share_rounded,
                              color: Colors.white, size: 20),
                      label: Text(
                          _isSendingReceipt ? 'Enviando...' : 'Enviar Recibo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: greenColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ).animate().fade(delay: 400.ms).slideY(begin: 0.2, end: 0),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
      String label, double amount, NumberFormat format, Color? color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: color, fontSize: 14)),
        Text(format.format(amount),
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w500,
                fontSize: 14)),
      ],
    );
  }

  void _handleGeneratePdf() {
    HapticFeedbackHelper.lightImpact();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PrintPreviewScreen(transaction: widget.sale),
      ),
    );
  }

  Future<void> _handleSendReceipt() async {
    final messenger = ScaffoldMessenger.of(context);
    HapticFeedbackHelper.mediumImpact();
    setState(() => _isSendingReceipt = true);

    try {
      final hasConnection = await NetworkService.hasConnection;
      if (!hasConnection) {
        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(
                content: Text('Sin conexión a internet'),
                backgroundColor: Colors.orange),
          );
        }
        return;
      }

      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
              content: Text('Recibo enviado correctamente'),
              backgroundColor: Colors.green),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingReceipt = false);
    }
  }

  Future<void> _handleVoidSale() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    // Close options sheet
    navigator.pop();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Anular Venta'),
        content: const Text(
            '¿Estás seguro de anular esta venta? El stock de los productos será restaurado.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Anular'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final dbService =
            DatabaseService(); // Or use Provider if available, but simple instance is fine here or context.read if using provider
        await dbService.deleteSale(widget.sale.id!);

        HapticFeedbackHelper.heavyImpact();

        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Venta anulada correctamente'),
              backgroundColor: Colors.green,
            ),
          );
          navigator.pop(); // Return to list
        }
      } catch (e) {
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Error al anular: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
