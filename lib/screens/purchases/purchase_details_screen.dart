import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:io';
import 'package:intl/intl.dart';
import '../../models/transaction_model.dart';
import '../../services/database_service.dart';
import '../../theme/app_theme.dart';
import '../suppliers/supplier_ledger_screen.dart';
import '../../widgets/transactions/transaction_options_sheet.dart';
import '../../utils/haptic_feedback_helper.dart';
import 'purchase_form_screen.dart';

class PurchaseDetailsScreen extends StatefulWidget {
  final Purchase purchase;
  final String? heroTag;

  const PurchaseDetailsScreen(
      {super.key, required this.purchase, this.heroTag});

  @override
  State<PurchaseDetailsScreen> createState() => _PurchaseDetailsScreenState();
}

class _PurchaseDetailsScreenState extends State<PurchaseDetailsScreen> {
  late Purchase _purchase;
  final DatabaseService _db = DatabaseService();
  final Map<int, String?> _productImages = {};

  @override
  void initState() {
    super.initState();
    _purchase = widget.purchase;
    _loadProductImages();
  }

  Future<void> _loadProductImages() async {
    try {
      final productIds = _purchase.items.map((e) => e.productId).toList();
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de Compra'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        actions: [
          IconButton(
            icon: Icon(Icons.more_vert,
                color: isDark ? Colors.white : Colors.black87),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (context) => TransactionOptionsBottomSheet(
                  isVoided: _purchase.status == 'VOIDED',
                  showSharePdf: false,
                  onEdit: () {
                    _handleEditPurchase();
                  },
                  onCancel: () {
                    if (_purchase.status == 'VOIDED') {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Esta transacción ya está anulada')),
                      );
                      return;
                    }
                    _handleVoidPurchase();
                  },
                  onSharePdf: () {}, // Not needed
                  onDuplicate: () {
                    _handleDuplicatePurchase();
                  },
                ),
              );
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(bool isDark) {
    final statusColor = switch (_purchase.status) {
      'PARTIAL' => const Color(0xFFF59F00),
      'CREDIT' => Colors.blueAccent,
      'VOIDED' => const Color(0xFF6B7494), // P1 FIX: VOIDED was showing green
      _ => Colors.green,
    };

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
                      tag: widget.heroTag ?? 'purchase_${_purchase.id}_icon',
                      child: CircleAvatar(
                        backgroundColor: statusColor.withValues(alpha: 0.1),
                        child:
                            Icon(Icons.shopping_bag, color: statusColor),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _purchase.supplierName ?? 'Proveedor General',
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                          Text(
                            'Compra #${_purchase.id}',
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
                        // P1 FIX: Added VOIDED label
                        switch (_purchase.status) {
                          'PARTIAL' => 'PARCIAL',
                          'CREDIT' => 'CRÉDITO',
                          'VOIDED' => 'ANULADO',
                          _ => 'COMPLETADO',
                        },
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
                          const Text('Fecha y Hora de Compra',
                              style: TextStyle(
                                  fontSize: 10, color: Colors.white54)),
                          const SizedBox(height: 4),
                          Text(DateFormat('dd/MM/yyyy').format(_purchase.date),
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                          Text(DateFormat('HH:mm').format(_purchase.date),
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.white70)),
                        ],
                      ),
                    ),
                    // Supplier Invoice Reference
                    if (_purchase.supplierInvoiceRef != null && _purchase.supplierInvoiceRef!.isNotEmpty)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Nro. Factura / Recibo',
                                style: TextStyle(
                                    fontSize: 10, color: Colors.white54)),
                            const SizedBox(height: 4),
                            Text(_purchase.supplierInvoiceRef!,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
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
                      '${_purchase.items.length} Items',
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _purchase.items.length,
                  separatorBuilder: (_, __) => Divider(
                      height: 16, color: Colors.white.withValues(alpha: 0.1)),
                  itemBuilder: (context, index) {
                    final item = _purchase.items[index];
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
    return Column(
      children: [
        Container(
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
                        const Flexible(
                          child: Text('TOTAL COMPRA',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                        const SizedBox(width: 8),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Bs. ${_purchase.totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    if (_purchase.amountPaid > 0 || _purchase.status == 'PARTIAL' || _purchase.status == 'CREDIT') ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('PAGADO',
                              style: TextStyle(color: Colors.white70)),
                          Text('Bs. ${_purchase.amountPaid.toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('PENDIENTE',
                              style: TextStyle(color: Colors.white)),
                          Text('Bs. ${_purchase.pendingAmount.toStringAsFixed(2)}',
                              style: const TextStyle(color: Color(0xFFF59F00), fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_purchase.pendingAmount > 0 && _purchase.supplierId != null) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SupplierLedgerScreen(
                      supplierId: _purchase.supplierId!,
                      supplierName: _purchase.supplierName ?? 'Proveedor',
                    ),
                  ),
                ).then((_) {
                  _reloadPurchaseData();
                });
              },
              icon: const Icon(Icons.payment),
              label: const Text('PAGAR DEUDA / ABONAR'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ]
      ],
    );
  }

  Future<void> _reloadPurchaseData() async {
    final updatedPurchase = await _db.getTransactionById(_purchase.id!) as Purchase?;
    if (updatedPurchase != null && mounted) {
      setState(() {
        _purchase = updatedPurchase;
      });
    }
  }

  Future<void> _handleVoidPurchase() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Anular Compra'),
        content: const Text(
            '¿Estás seguro de anular esta compra? El stock de los productos será reducido y el balance revertido.'),
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
        await _db.deletePurchase(_purchase.id!);

        HapticFeedbackHelper.heavyImpact();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Compra anulada correctamente'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context); // Return to list
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al anular: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleDuplicatePurchase() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Duplicar Transacción'),
        content: const Text(
            '¿Deseas duplicar esta Compra?\n\nSe abrirá el formulario de compra cargado con los datos para que procedas a revisarla.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, Duplicar',
                style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PurchaseFormScreen(
          initialTransactionToDuplicate: _purchase,
        ),
      ),
    );
  }

  Future<void> _handleEditPurchase() async {
    if (_purchase.status == 'VOIDED') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se puede editar una compra anulada.')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar Transacción'),
        content: const Text(
            'Al guardar la edición, la transacción anterior será anulada (revirtiendo inventario y balances) y se guardará la nueva.\n\n¿Deseas continuar?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Continuar', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PurchaseFormScreen(
          initialTransactionToDuplicate: _purchase,
          editingOriginalId: _purchase.id,
        ),
      ),
    );
  }
}
