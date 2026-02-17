import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/product.dart';

class ProductListItem extends StatefulWidget {
  final Product product;
  final String categoryName;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ProductListItem({
    super.key,
    required this.product,
    required this.categoryName,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<ProductListItem> createState() => _ProductListItemState();
}

class _ProductListItemState extends State<ProductListItem>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final stock = widget.product.stock;

    // Stock Logic
    Color stockColor;
    if (stock > 10) {
      stockColor = const Color(0xFF10B981); // Green
    } else if (stock >= 5) {
      stockColor = const Color(0xFFF59E0B); // Yellow
    } else if (stock > 0) {
      stockColor = const Color(0xFFEF4444); // Red
    } else {
      stockColor = const Color(0xFF9CA3AF); // Gray
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _isExpanded = !_isExpanded;
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0x26FFFFFF), // White 15% opacity
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0x1AFFFFFF), // White 10% opacity
            width: 1.5,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26000000), // Black 15%
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Stack(
              children: [
                // Side Border (Stock Indicator)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 4,
                    color: stockColor,
                  ),
                ),
                Column(
                  children: [
                    // Main Horizontal Content
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      child: Row(
                        children: [
                          // 1. Product Image
                          Hero(
                            tag: 'product_${widget.product.id}_image',
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: const Color(
                                    0x334A90E2), // Placeholder color
                              ),
                              child: widget.product.imagePath != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.file(
                                        File(widget.product.imagePath!),
                                        fit: BoxFit.cover,
                                        width: 60,
                                        height: 60,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return const Icon(Icons.broken_image,
                                              color: Colors.white54);
                                        },
                                      ),
                                    )
                                  : const Icon(Icons.inventory_2_outlined,
                                      color: Colors.white54),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // 2. Center Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.product.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Cód: ${widget.product.barcode.isEmpty ? "N/A" : widget.product.barcode}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFFA0A8C1),
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: stockColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Stock: ${widget.product.stock.toStringAsFixed(0)} unid.',
                                      style: TextStyle(
                                        color: stockColor,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // 3. Right Price + Chevron
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Bs. ${widget.product.price.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 12),
                              AnimatedRotation(
                                turns: _isExpanded ? 0.5 : 0.0,
                                duration: const Duration(milliseconds: 300),
                                child: const Icon(Icons.expand_more,
                                    color: Color(0xFF6B7494), size: 24),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Expanded Section
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                      child: _isExpanded
                          ? Container(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: Column(
                                children: [
                                  Divider(
                                      color:
                                          Colors.white.withValues(alpha: 0.1),
                                      height: 1),
                                  const SizedBox(height: 16),
                                  // Grid Info
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _buildInfoRow('Categoría',
                                                widget.categoryName),
                                            const SizedBox(height: 8),
                                            _buildInfoRow('Precio Costo',
                                                'Bs. ${widget.product.cost.toStringAsFixed(2)}'),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _buildInfoRow('Min. Stock',
                                                '${widget.product.minStock} unid.'),
                                            const SizedBox(height: 8),
                                            _buildInfoRow(
                                              'Última Act.',
                                              DateFormat('dd/MM/yyyy').format(
                                                  widget.product.createdAt),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  // Action Buttons
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildGlassButton(
                                          icon: Icons.edit_outlined,
                                          label: 'Editar',
                                          color: Colors.white,
                                          onTap: widget.onEdit,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _buildGlassButton(
                                          icon: Icons.delete_outline,
                                          label: 'Eliminar',
                                          color: const Color(0xFFEF4444),
                                          onTap: widget.onDelete,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox.shrink(),
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

  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFA0A8C1),
            fontSize: 12,
            fontWeight: FontWeight.normal,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildGlassButton(
      {required IconData icon,
      required String label,
      required Color color,
      required VoidCallback onTap}) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
