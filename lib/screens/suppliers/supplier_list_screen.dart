import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../providers/supplier_provider.dart';
import '../../models/supplier.dart';
import 'supplier_form_screen.dart';
import '../../widgets/common/skeleton_list.dart'; // Added SkeletonList
import '../../utils/whatsapp_helper.dart';
import 'supplier_ledger_screen.dart';
import '../../utils/currency_helper.dart';
import '../../theme/app_theme.dart';
import '../../widgets/responsive_layout.dart';

class SupplierListScreen extends StatefulWidget {
  const SupplierListScreen({super.key});

  @override
  State<SupplierListScreen> createState() => _SupplierListScreenState();
}

class _SupplierListScreenState extends State<SupplierListScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _navigateToForm(BuildContext context, Supplier? supplier) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SupplierFormScreen(supplier: supplier),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Supplier supplier) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Proveedor'),
        content: Text('¿Seguro que deseas eliminar a ${supplier.name}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              context.read<SupplierProvider>().deleteSupplier(supplier.id!);
              Navigator.pop(ctx);
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final supplierProvider = context.watch<SupplierProvider>();
    final suppliers = supplierProvider.filteredSuppliers;
    final isLoading = supplierProvider.isLoading;

    return Scaffold(
      backgroundColor: AppTheme.backgroundBlack, // Dark #151924 background
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundBlack,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white, size: 24),
        title: const Text(
          'Proveedores',
          style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: BoundedDesktopWrapper(child: Column(
        children: [
          // SEARCH BAR
          Padding(
            padding:
                const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 16),
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08), width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Buscar proveedor...',
                      hintStyle: const TextStyle(
                          color: AppTheme.textTertiary, fontSize: 16),
                      prefixIcon: const Icon(Icons.search,
                          color: AppTheme.textSecondary, size: 24),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear,
                                  color: AppTheme.textSecondary, size: 20),
                              onPressed: () {
                                _searchController.clear();
                                context
                                    .read<SupplierProvider>()
                                    .setSearchQuery('');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                    onChanged: (value) {
                      context.read<SupplierProvider>().setSearchQuery(value);
                      setState(() {});
                    },
                  ),
                ),
              ),
            ),
          ),

          // MAIN CONTENT
          Expanded(
            child: isLoading
                ? const SkeletonList()
                : suppliers.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding:
                            const EdgeInsets.only(bottom: 100), // Space for FAB
                        itemCount: suppliers.length,
                        itemBuilder: (context, index) {
                          final supplier = suppliers[index];
                          // Animate max 5 items
                          Widget card = _SupplierGlassCard(
                            supplier: supplier,
                            onTap: () => _navigateToForm(context, supplier),
                            onDeleteTap: () =>
                                _confirmDelete(context, supplier),
                            onLedgerTap: () {
                              if (supplier.id == null) return;
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SupplierLedgerScreen(
                                    supplierId: supplier.id!,
                                    supplierName: supplier.name,
                                  ),
                                ),
                              );
                            },
                          );

                          if (index < 5) {
                            return card
                                .animate()
                                .fade(
                                    duration: 300.ms,
                                    delay: (index * 50).ms,
                                    curve: Curves.easeOut)
                                .slideY(
                                    begin: 0.1,
                                    end: 0,
                                    duration: 300.ms,
                                    delay: (index * 50).ms,
                                    curve: Curves.easeOut);
                          }
                          return card;
                        },
                      ),
          ),
        ],
      ),),
      // FAB
      floatingActionButton:
          (suppliers.isEmpty && !isLoading) ? null : _buildFAB(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: AppTheme.greenIcon.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                ),
                const Icon(Icons.business, size: 120, color: AppTheme.greenIcon),
              ],
            ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
            const SizedBox(height: 32),
            const Text(
              'No hay proveedores',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Añade a tu primer proveedor para comenzar a\ngestionar tus inventarios.',
              style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 16, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            _AnimatedCTAButton(
              onTap: () => _navigateToForm(context, null),
              title: 'Añadir Proveedor',
              icon: Icons.add_business,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAB() {
    return _AnimatedFAB(
      onTap: () => _navigateToForm(context, null),
    );
  }
}

class _AnimatedCTAButton extends StatefulWidget {
  final VoidCallback onTap;
  final String title;
  final IconData icon;

  const _AnimatedCTAButton(
      {required this.onTap, required this.title, required this.icon});

  @override
  State<_AnimatedCTAButton> createState() => _AnimatedCTAButtonState();
}

class _AnimatedCTAButtonState extends State<_AnimatedCTAButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        transform: Matrix4.diagonal3Values(
            _isPressed ? 0.96 : 1.0, _isPressed ? 0.96 : 1.0, 1.0),
        transformAlignment: Alignment.center,
        width: 240,
        height: 56,
        decoration: BoxDecoration(
          color: AppTheme.greenIcon.withValues(alpha: 0.20),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
              color: AppTheme.greenIcon.withValues(alpha: 0.30),
              width: 1.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, color: AppTheme.greenIcon, size: 24),
                const SizedBox(width: 12),
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: AppTheme.greenIcon,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedFAB extends StatefulWidget {
  final VoidCallback onTap;
  const _AnimatedFAB({required this.onTap});

  @override
  State<_AnimatedFAB> createState() => _AnimatedFABState();
}

class _AnimatedFABState extends State<_AnimatedFAB> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        transform: Matrix4.diagonal3Values(
            _isPressed ? 0.95 : 1.0, _isPressed ? 0.95 : 1.0, 1.0),
        transformAlignment: Alignment.center,
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [AppTheme.redAccent, Color(0xFFFF5757)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.redAccent.withValues(alpha: 0.20),
              blurRadius: 12,
              offset: const Offset(0, 6),
            )
          ],
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }
}

class _SupplierGlassCard extends StatefulWidget {
  final Supplier supplier;
  final VoidCallback onTap;
  final VoidCallback onDeleteTap;
  final VoidCallback onLedgerTap;

  const _SupplierGlassCard({
    required this.supplier,
    required this.onTap,
    required this.onDeleteTap,
    required this.onLedgerTap,
  });

  @override
  State<_SupplierGlassCard> createState() => _SupplierGlassCardState();
}

class _SupplierGlassCardState extends State<_SupplierGlassCard> {
  bool _isCardPressed = false;

  Color _getAvatarColor(String name) {
    if (name.isEmpty) {
      return AppTheme.greenIcon;
    }
    final firstChar = name.trim().toUpperCase()[0];
    if (RegExp(r'[A-F]').hasMatch(firstChar)) {
      return AppTheme.greenIcon; // Turquoise
    }
    if (RegExp(r'[G-L]').hasMatch(firstChar)) {
      return AppTheme.blueIcon; // Blue
    }
    if (RegExp(r'[M-R]').hasMatch(firstChar)) {
      return AppTheme.success; // Green
    }
    if (RegExp(r'[S-Z]').hasMatch(firstChar)) {
      return AppTheme.yellowIcon; // Orange
    }
    return AppTheme.greenIcon; // Default Turquoise
  }

  @override
  Widget build(BuildContext context) {
    final avatarColor = _getAvatarColor(widget.supplier.name);
    final hasPhone =
        widget.supplier.phone != null && widget.supplier.phone!.isNotEmpty;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isCardPressed = true),
      onTapUp: (_) {
        setState(() => _isCardPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isCardPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        transform: Matrix4.diagonal3Values(
            _isCardPressed ? 0.98 : 1.0, _isCardPressed ? 0.98 : 1.0, 1.0),
        transformAlignment: Alignment.center,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white
                    .withValues(alpha: _isCardPressed ? 0.12 : 0.10),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08), width: 1),
              ),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: avatarColor.withValues(alpha: 0.20),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: avatarColor.withValues(alpha: 0.30), width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      widget.supplier.name.isNotEmpty
                          ? widget.supplier.name[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: avatarColor,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.supplier.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.supplier.category != null &&
                            widget.supplier.category!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.supplier.category!,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (hasPhone) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.supplier.phone!,
                            style: const TextStyle(
                              color: AppTheme.textTertiary,
                              fontSize: 13,
                            ),
                          ),
                        ]
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Actions — constrained so they don't push Expanded info
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 168),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      alignment: WrapAlignment.end,
                      children: [
                        if (hasPhone)
                          _CardActionButton(
                            icon: Icons.phone,
                            color: AppTheme.blueIcon, // Blue
                            onTap: () {
                              context
                                  .read<SupplierProvider>()
                                  .makePhoneCall(widget.supplier.phone!);
                            },
                          ),
                        if (hasPhone)
                          _CardActionButton(
                            icon:
                                Icons.message, // Use message as WhatsApp fallback
                            color: AppTheme.success, // Green
                            onTap: () {
                              WhatsAppHelper.launchWhatsApp(
                                  widget.supplier.phone!,
                                  "Hola ${widget.supplier.name}, quisiera hacer un pedido.");
                            },
                          ),
                        _CardActionButton(
                          icon: Icons.receipt_long,
                          color: AppTheme.yellowIcon, // Orange
                          onTap: widget.onLedgerTap,
                        ),
                        // Custom Popup Menu action button
                        _CardPopupActions(
                          supplier: widget.supplier,
                          onEdit: widget.onTap,
                          onDelete: widget.onDeleteTap,
                          onLedger: widget.onLedgerTap,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (widget.supplier.totalDebt > 0)
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: const BoxDecoration(
                color: Color(0xE6EF4444),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Text(
                CurrencyHelper.simple(widget.supplier.totalDebt),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }
}

class _CardActionButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _CardActionButton(
      {required this.icon, required this.color, required this.onTap});

  @override
  State<_CardActionButton> createState() => _CardActionButtonState();
}

class _CardActionButtonState extends State<_CardActionButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        transform: Matrix4.diagonal3Values(
            _isPressed ? 0.92 : 1.0, _isPressed ? 0.92 : 1.0, 1.0),
        transformAlignment: Alignment.center,
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: _isPressed ? 0.30 : 0.20),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: widget.color.withValues(alpha: 0.30), width: 1.5),
        ),
        child: Icon(widget.icon, color: widget.color, size: 22),
      ),
    );
  }
}

class _CardPopupActions extends StatelessWidget {
  final Supplier supplier;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onLedger;

  const _CardPopupActions(
      {required this.supplier, required this.onEdit, required this.onDelete, required this.onLedger});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'edit') {
          onEdit();
        } else if (value == 'ledger') {
          onLedger();
        } else if (value == 'delete') {
          onDelete();
        }
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: const Color(0xFF1E2433), // Dark dropdown menu
      icon: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.more_vert, color: AppTheme.textTertiary, size: 22),
      ),
      padding: EdgeInsets.zero,
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(
          value: 'edit',
          child: Text('Editar', style: TextStyle(color: Colors.white)),
        ),
        const PopupMenuItem<String>(
          value: 'ledger',
          child: Text('Cuentas por Pagar', style: TextStyle(color: Colors.white)),
        ),
        const PopupMenuItem<String>(
          value: 'delete',
          child: Text('Eliminar', style: TextStyle(color: Colors.red)),
        ),
      ],
    );
  }
}
