import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/transaction_model.dart';
import '../../services/database_service.dart';
import '../../utils/whatsapp_helper.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/settings_provider.dart';

class OrderDetailsScreen extends StatefulWidget {
  final Order order;
  final String? heroTag;

  const OrderDetailsScreen({super.key, required this.order, this.heroTag});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  late Order _order;
  final DatabaseService _db = DatabaseService();
  final Map<int, String?> _productImages = {};

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _loadProductImages();
  }

  Future<void> _loadProductImages() async {
    try {
      final productIds = _order.items.map((e) => e.productId).toList();
      if (productIds.isEmpty) return;

      final products = await _db.getProductsByIds(productIds);
      if (mounted) {
        setState(() {
          for (var p in products) {
            _productImages[p.id!] = p.imagePath;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading product images: $e');
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    try {
      await _db.updateOrderStatus(_order.id!, newStatus);
      setState(() {
        _order = Order(
          id: _order.id,
          date: _order.date,
          totalAmount: _order.totalAmount,
          status: newStatus,
          supplierName: _order.supplierName,
          items: _order.items,
        );
      });
      if (newStatus == 'RECEIVED' && mounted) {
        await context.read<InventoryProvider>().loadProducts(reset: true);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Pedido actualizado a $newStatus'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del Pedido'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              final phone = context.read<SettingsProvider>().whatsapp;
              if (phone.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text(
                          'Configure su número de WhatsApp en Ajustes primero.'),
                      backgroundColor: Colors.orange),
                );
                return;
              }
              final message = WhatsAppHelper.generateOrderMessage(_order);
              WhatsAppHelper.launchWhatsApp(phone, message);
            },
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF0F172A),
                    const Color(0xFF1E293B),
                    const Color(0xFF0F172A),
                  ]
                : [
                    const Color(0xFFF8FAFC),
                    const Color(0xFFE2E8F0),
                    const Color(0xFFF1F5F9),
                  ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeaderCard(isDark),
                const SizedBox(height: 16),
                _buildProductList(isDark),
                const SizedBox(height: 16),
                _buildTotalsCard(isDark),
                const SizedBox(height: 24),
                _buildActionButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(bool isDark) {
    Color statusColor;
    switch (_order.status.toUpperCase()) {
      case 'PENDING':
        statusColor = Colors.orange;
        break;
      case 'CONFIRMED':
        statusColor = Colors.blue;
        break;
      default:
        statusColor = Colors.green;
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0x26FFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1AFFFFFF), width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Hero(
                      tag: widget.heroTag ?? 'order_${_order.id}_icon',
                      child: CircleAvatar(
                        backgroundColor: statusColor.withValues(alpha: 0.1),
                        child: Icon(Icons.inventory_2, color: statusColor),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _order.supplierName ?? 'Proveedor General',
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                          Text(
                            'Pedido #${_order.id}',
                            style: TextStyle(
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[400],
                                fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: statusColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        _order.status,
                        style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.1)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Fecha y Hora del Pedido',
                              style: TextStyle(
                                  fontSize: 10, color: Colors.white54)),
                          const SizedBox(height: 4),
                          Text(DateFormat('dd/MM/yyyy').format(_order.date),
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                          Text(DateFormat('HH:mm').format(_order.date),
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.white70)),
                        ],
                      ),
                    ),
                    if (_order.deliveryDate != null)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Fecha y Hora de Entrega',
                                style: TextStyle(
                                    fontSize: 10, color: Colors.white54)),
                            const SizedBox(height: 4),
                            Text(
                                DateFormat('dd/MM/yyyy')
                                    .format(_order.deliveryDate!),
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                            Text(
                                DateFormat('HH:mm')
                                    .format(_order.deliveryDate!),
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.white70)),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductList(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0x26FFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1AFFFFFF), width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.list, size: 20, color: Colors.blue),
                    const SizedBox(width: 8),
                    const Text(
                      'PRODUCTOS',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                          color: Colors.white),
                    ),
                    const Spacer(),
                    Text(
                      '${_order.items.length} Items',
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _order.items.length,
                  separatorBuilder: (_, __) => Divider(
                      height: 16, color: Colors.white.withValues(alpha: 0.1)),
                  itemBuilder: (context, index) {
                    final item = _order.items[index];
                    final imagePath = _productImages[item.productId];

                    return Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            image: (imagePath != null && imagePath.isNotEmpty)
                                ? DecorationImage(
                                    image: FileImage(File(imagePath)),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: (imagePath != null && imagePath.isNotEmpty)
                              ? null
                              : const Icon(Icons.image_not_supported,
                                  size: 20, color: Colors.white54),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.productName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white)),
                              Text(
                                '${item.quantity.toStringAsFixed(0)} x Bs. ${item.unitPrice.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.white54),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          'Bs. ${item.subtotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTotalsCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0x26FFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1AFFFFFF), width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Flexible(
                  child: Text('TOTAL ESTIMADO',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                const SizedBox(width: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Bs. ${_order.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    final status = _order.status.toUpperCase();
    if (status == 'RECEIVED' || status == 'CANCELLED') {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        if (status == 'PENDING') ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _updateStatus('CONFIRMED'),
              icon: const Icon(Icons.check),
              label: const Text('Confirmar Pedido'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (status == 'CONFIRMED') ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showReceiveConfirmation(),
              icon: const Icon(Icons.inventory),
              label: const Text('Marcar como Recibido'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _showCancelConfirmation(),
            icon: const Icon(Icons.cancel),
            label: const Text('Cancelar Pedido'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  void _showReceiveConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recibir Pedido'),
        content: const Text(
            '¿Marcar este pedido como RECIBIDO?\nEsto actualizará el inventario con los productos del pedido.'),
        actionsAlignment: MainAxisAlignment.end,
        actions: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _updateStatus('RECEIVED');
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('Confirmar Recepción'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCancelConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar Pedido'),
        content: const Text(
            '¿Estás seguro de cancelar este pedido?\nEsta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Volver'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _updateStatus('CANCELLED');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sí, Cancelar'),
          ),
        ],
      ),
    );
  }
}
