import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../models/supplier.dart';
import '../../providers/supplier_provider.dart';
import '../../services/contact_helper.dart';
import '../../widgets/common/glass_text_field_group.dart';

class SupplierFormScreen extends StatefulWidget {
  final Supplier? supplier;

  const SupplierFormScreen({super.key, this.supplier});

  @override
  State<SupplierFormScreen> createState() => _SupplierFormScreenState();
}

class _SupplierFormScreenState extends State<SupplierFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  late TextEditingController _categoryController;
  late TextEditingController _ciNitController;

  // Validation trackers to trigger error states on custom UI
  String? _nameError;

  @override
  void initState() {
    super.initState();
    final s = widget.supplier;
    _nameController = TextEditingController(text: s?.name ?? '');
    _phoneController = TextEditingController(text: s?.phone ?? '');
    _emailController = TextEditingController(text: s?.email ?? '');
    _addressController = TextEditingController(text: s?.address ?? '');
    _categoryController = TextEditingController(text: s?.category ?? '');
    _ciNitController = TextEditingController(text: s?.ciNit ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _categoryController.dispose();
    _ciNitController.dispose();
    super.dispose();
  }

  Future<void> _pickContact() async {
    final contact = await ContactHelper.pickPhoneContact(context);
    if (contact != null) {
      setState(() {
        _nameController.text = contact.displayName;
        if (contact.phones.isNotEmpty) {
          _phoneController.text = contact.phones.first.number;
        }
        if (contact.emails.isNotEmpty) {
          _emailController.text = contact.emails.first.address;
        }
        _validate(); // Re-validate after auto-fill
      });
    }
  }

  bool _validate() {
    setState(() {
      _nameError = _nameController.text.trim().isEmpty ? 'Requerido' : null;
    });
    return _nameError == null;
  }

  Future<void> _save() async {
    if (!_validate()) return;

    // Fallback UI validation block
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final address = _addressController.text.trim();
    final category = _categoryController.text.trim();
    final ciNit = _ciNitController.text.trim();

    final supplier = Supplier(
      id: widget.supplier?.id,
      name: name,
      phone: phone.isEmpty ? null : phone,
      email: email.isEmpty ? null : email,
      address: address.isEmpty ? null : address,
      category: category.isEmpty ? null : category,
      ciNit: ciNit.isEmpty ? null : ciNit,
      createdAt: widget.supplier?.createdAt,
    );

    try {
      await context.read<SupplierProvider>().addSupplier(supplier);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  bool _canSave() {
    final name = _nameController.text.trim();
    return name.isNotEmpty && _nameError == null;
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.supplier != null;
    return Scaffold(
      backgroundColor: const Color(0xFF151924),
      appBar: AppBar(
        backgroundColor: const Color(0xFF151924),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white, size: 24),
        title: Text(
          isEditing ? 'Editar Proveedor' : 'Nuevo Proveedor',
          style: const TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              _ImportContactButton(onTap: _pickContact)
                  .animate()
                  .fade(duration: 300.ms)
                  .slideY(begin: 0.1, end: 0, delay: 0.ms),
              const SizedBox(height: 24),
              GlassTextFieldGroup(
                label: 'Nombre *',
                controller: _nameController,
                icon: Icons.business,
                placeholder: 'Ingresa el nombre del proveedor',
                errorText: _nameError,
                onChanged: (_) => setState(() => _nameError =
                    _nameController.text.trim().isEmpty ? 'Requerido' : null),
              )
                  .animate()
                  .fade(duration: 300.ms)
                  .slideY(begin: 0.1, end: 0, delay: 50.ms),
              const SizedBox(height: 16),
              GlassTextFieldGroup(
                label: 'Categoría / Productos',
                controller: _categoryController,
                icon: Icons.category_outlined,
                placeholder: 'Ej. Bebidas, Insumos...',
              )
                  .animate()
                  .fade(duration: 300.ms)
                  .slideY(begin: 0.1, end: 0, delay: 100.ms),
              const SizedBox(height: 16),
              GlassTextFieldGroup(
                label: 'NIT/CI',
                controller: _ciNitController,
                icon: Icons.badge,
                placeholder: 'NIT o Carnet de Identidad',
              )
                  .animate()
                  .fade(duration: 300.ms)
                  .slideY(begin: 0.1, end: 0, delay: 125.ms),
              const SizedBox(height: 16),
              GlassTextFieldGroup(
                label: 'Teléfono / WhatsApp',
                controller: _phoneController,
                icon: Icons.phone,
                placeholder: 'Ingresa el número de celular o teléfono',
                keyboardType: TextInputType.phone,
              )
                  .animate()
                  .fade(duration: 300.ms)
                  .slideY(begin: 0.1, end: 0, delay: 150.ms),
              const SizedBox(height: 16),
              GlassTextFieldGroup(
                label: 'Email',
                controller: _emailController,
                icon: Icons.email_outlined,
                placeholder: 'Ingresa el correo electrónico',
                keyboardType: TextInputType.emailAddress,
              )
                  .animate()
                  .fade(duration: 300.ms)
                  .slideY(begin: 0.1, end: 0, delay: 200.ms),
              const SizedBox(height: 16),
              GlassTextFieldGroup(
                label: 'Dirección',
                controller: _addressController,
                icon: Icons.location_on_outlined,
                placeholder: 'Ingresa la dirección (opcional)',
              )
                  .animate()
                  .fade(duration: 300.ms)
                  .slideY(begin: 0.1, end: 0, delay: 250.ms),
              const SizedBox(height: 32),
              _AnimatedSaveButton(
                onTap: _save,
                isEnabled: _canSave(),
              )
                  .animate()
                  .fade(duration: 300.ms)
                  .slideY(begin: 0.1, end: 0, delay: 300.ms),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImportContactButton extends StatefulWidget {
  final VoidCallback onTap;

  const _ImportContactButton({required this.onTap});

  @override
  State<_ImportContactButton> createState() => _ImportContactButtonState();
}

class _ImportContactButtonState extends State<_ImportContactButton> {
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
            _isPressed ? 0.98 : 1.0, _isPressed ? 0.98 : 1.0, 1.0),
        transformAlignment: Alignment.center,
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFFFF6B6B)
              .withValues(alpha: _isPressed ? 0.15 : 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: const Color(0xFFFF6B6B).withValues(alpha: 0.30),
              width: 1.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.contact_page, color: Color(0xFFFF6B6B), size: 22),
                SizedBox(width: 12),
                Text(
                  'Importar desde Contactos',
                  style: TextStyle(
                    color: Color(0xFFFF6B6B),
                    fontSize: 15,
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



class _AnimatedSaveButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool isEnabled;

  const _AnimatedSaveButton({required this.onTap, required this.isEnabled});

  @override
  State<_AnimatedSaveButton> createState() => _AnimatedSaveButtonState();
}

class _AnimatedSaveButtonState extends State<_AnimatedSaveButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.isEnabled) {
      return Container(
        height: 56,
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.30),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: const Text(
          'Guardar Proveedor',
          style: TextStyle(
              color: Colors.white54, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      );
    }

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
            _isPressed ? 0.97 : 1.0, _isPressed ? 0.97 : 1.0, 1.0),
        transformAlignment: Alignment.center,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6B6B), Color(0xFFFF5757)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: _isPressed
              ? null
              : [
                  BoxShadow(
                    color: const Color(0xFFFF6B6B).withValues(alpha: 0.30),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  )
                ],
        ),
        alignment: Alignment.center,
        child: const Text(
          'Guardar Proveedor',
          style: TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
