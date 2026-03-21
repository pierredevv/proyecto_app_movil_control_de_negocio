import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../providers/customer_provider.dart';
import '../../models/customer.dart';
import 'customer_form_screen.dart';
import '../../utils/input_validators.dart';
import '../../widgets/common/skeleton_list.dart'; // Added SkeletonList
import 'customer_ledger_screen.dart';

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final TextEditingController _searchController = TextEditingController();

  Future<void> _showPaymentDialog(Customer customer) async {
    final controller = TextEditingController();
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Registrar Pago: ${customer.name}'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Monto del Pago (Bs.)',
            prefixText: 'Bs. ',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Guardar')),
        ],
      ),
    );

    if (!mounted) return;

    if (shouldSave == true) {
      final error = InputValidators.validatePaymentAmount(
          controller.text, customer.totalDebt);

      if (error != null) {
        if (error.contains('⚠️')) {
          InputValidators.showValidationWarning(context, error);
          return;
        }
        InputValidators.showValidationError(context, error);
        return;
      }

      final amount = double.tryParse(controller.text)!;

      try {
        await context.read<CustomerProvider>().addPayment(customer.id!, amount);
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pago registrado exitosamente')),
        );
      } catch (e) {
        if (!mounted) return;
        InputValidators.showValidationError(context, 'Error: $e');
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _navigateToForm(BuildContext context, Customer? customer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerFormScreen(customer: customer),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customerProvider = context.watch<CustomerProvider>();
    final customers = customerProvider.filteredCustomers;
    final isLoading = customerProvider.isLoading;

    return Scaffold(
      backgroundColor: const Color(0xFF151924), // Dark #151924 background
      appBar: AppBar(
        backgroundColor: const Color(0xFF151924),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white, size: 24),
        title: const Text(
          'Clientes',
          style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: Column(
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
                      hintText: 'Buscar cliente...',
                      hintStyle: const TextStyle(
                          color: Color(0xFF6B7494), fontSize: 16),
                      prefixIcon: const Icon(Icons.search,
                          color: Color(0xFFA0A8C1), size: 24),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear,
                                  color: Color(0xFFA0A8C1), size: 20),
                              onPressed: () {
                                _searchController.clear();
                                context
                                    .read<CustomerProvider>()
                                    .setSearchQuery('');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                    onChanged: (value) {
                      context.read<CustomerProvider>().setSearchQuery(value);
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
                : customers.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding:
                            const EdgeInsets.only(bottom: 100), // Space for FAB
                        itemCount: customers.length,
                        itemBuilder: (context, index) {
                          final customer = customers[index];
                          // Animate max 5 items
                          Widget card = _CustomerGlassCard(
                            customer: customer,
                            onTap: () => _navigateToForm(context, customer),
                            onPaymentTap: () => _showPaymentDialog(customer),
                            onEditTap: () => _navigateToForm(context, customer),
                            onLedgerTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CustomerLedgerScreen(
                                    customerId: customer.id!,
                                    customerName: customer.name,
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
      ),
      // FAB
      floatingActionButton:
          (customers.isEmpty && !isLoading) ? null : _buildFAB(),
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
                    color: const Color(0xFF4ECDC4).withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                ),
                const Icon(Icons.people, size: 120, color: Color(0xFF4ECDC4)),
              ],
            ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
            const SizedBox(height: 32),
            const Text(
              'No hay clientes registrados',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Añade a tu primer cliente para comenzar a\ngestionar tus relaciones y proyectos.',
              style: TextStyle(
                  color: Color(0xFFA0A8C1), fontSize: 16, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            _AnimatedCTAButton(
              onTap: () => _navigateToForm(context, null),
              title: 'Añadir Primer Cliente',
              icon: Icons.person_add,
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
          color: const Color(0xFF4ECDC4).withValues(alpha: 0.20),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
              color: const Color(0xFF4ECDC4).withValues(alpha: 0.30),
              width: 1.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, color: const Color(0xFF4ECDC4), size: 24),
                const SizedBox(width: 12),
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: Color(0xFF4ECDC4),
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
            colors: [Color(0xFFFF6B6B), Color(0xFFFF5757)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6B6B).withValues(alpha: 0.20),
              blurRadius: 12,
              offset: const Offset(0, 6),
            )
          ],
        ),
        child: const Icon(Icons.person_add, color: Colors.white, size: 28),
      ),
    );
  }
}

class _CustomerGlassCard extends StatefulWidget {
  final Customer customer;
  final VoidCallback onTap;
  final VoidCallback onPaymentTap;
  final VoidCallback onEditTap;
  final VoidCallback onLedgerTap;

  const _CustomerGlassCard({
    required this.customer,
    required this.onTap,
    required this.onPaymentTap,
    required this.onEditTap,
    required this.onLedgerTap,
  });

  @override
  State<_CustomerGlassCard> createState() => _CustomerGlassCardState();
}

class _CustomerGlassCardState extends State<_CustomerGlassCard> {
  bool _isCardPressed = false;

  Color _getAvatarColor(String name) {
    if (name.isEmpty) {
      return const Color(0xFF4ECDC4);
    }
    final firstChar = name.trim().toUpperCase()[0];
    if (RegExp(r'[A-F]').hasMatch(firstChar)) {
      return const Color(0xFF4ECDC4); // Turquoise
    }
    if (RegExp(r'[G-L]').hasMatch(firstChar)) {
      return const Color(0xFF4A90E2); // Blue
    }
    if (RegExp(r'[M-R]').hasMatch(firstChar)) {
      return const Color(0xFF51CF66); // Green
    }
    if (RegExp(r'[S-Z]').hasMatch(firstChar)) {
      return const Color(0xFFF5A623); // Orange
    }
    return const Color(0xFF4ECDC4); // Default Turquoise
  }

  @override
  Widget build(BuildContext context) {
    final avatarColor = _getAvatarColor(widget.customer.name);
    final hasDebt = widget.customer.totalDebt > 0;

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
                              color: avatarColor.withValues(alpha: 0.30),
                              width: 2),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          widget.customer.name.isNotEmpty
                              ? widget.customer.name[0].toUpperCase()
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
                              widget.customer.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (widget.customer.phone != null &&
                                widget.customer.phone!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                widget.customer.phone!,
                                style: const TextStyle(
                                  color: Color(0xFFA0A8C1),
                                  fontSize: 14,
                                ),
                              ),
                            ]
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Actions
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.customer.phone != null &&
                              widget.customer.phone!.isNotEmpty)
                            _CardActionButton(
                              icon: Icons.phone,
                              color: const Color(0xFF4A90E2), // Blue
                              onTap: () {
                                context
                                    .read<CustomerProvider>()
                                    .makePhoneCall(widget.customer.phone!);
                              },
                            ),
                          if (widget.customer.phone != null &&
                              widget.customer.phone!.isNotEmpty)
                            const SizedBox(width: 12),
                          _CardActionButton(
                            icon: Icons.receipt, // or attach_money
                            color: const Color(0xFF51CF66), // Green
                            onTap: widget.onPaymentTap,
                          ),
                          const SizedBox(width: 12),
                          // Custom Popup Menu action button
                          _CardPopupActions(
                            customer: widget.customer,
                            onEdit: widget.onEditTap,
                            onLedger: widget.onLedgerTap,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Debt Badge at Top Right (Outside padding, hugging borders)
            if (hasDebt)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: const BoxDecoration(
                    color: Color(0xE6EF4444), // Red 90%
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(8),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Bs. ${widget.customer.totalDebt.toStringAsFixed(2)}',
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
  final Customer customer;
  final VoidCallback onEdit;
  final VoidCallback onLedger;

  const _CardPopupActions(
      {required this.customer,
      required this.onEdit,
      required this.onLedger});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'edit') onEdit();
        if (value == 'ledger') onLedger();
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
        child: const Icon(Icons.more_vert, color: Color(0xFF6B7494), size: 22),
      ),
      padding: EdgeInsets.zero,
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(
          value: 'edit',
          child: Text('Editar', style: TextStyle(color: Colors.white)),
        ),
        const PopupMenuItem<String>(
          value: 'ledger',
          child:
              Text('Estado de Cuenta', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
