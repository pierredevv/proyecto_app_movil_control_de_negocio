import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/customer.dart';
import '../../providers/customer_provider.dart';
import '../../services/contact_helper.dart';
import '../../theme/app_theme.dart';
import '../../utils/input_validators.dart';

class CustomerFormScreen extends StatefulWidget {
  final Customer? customer;

  const CustomerFormScreen({super.key, this.customer});

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;

  @override
  void initState() {
    super.initState();
    final c = widget.customer;
    _nameController = TextEditingController(text: c?.name);
    _phoneController = TextEditingController(text: c?.phone);
    _emailController = TextEditingController(text: c?.email);
    _addressController = TextEditingController(text: c?.address);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
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
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final address = _addressController.text.trim();

    final newCustomer = Customer(
      id: widget.customer?.id,
      name: name,
      phone: phone.isEmpty ? null : phone,
      email: email.isEmpty ? null : email,
      address: address.isEmpty ? null : address,
      totalDebt: widget.customer?.totalDebt ?? 0.0,
      createdAt: widget.customer?.createdAt,
    );

    try {
      final provider = context.read<CustomerProvider>();
      await provider
          .addCustomer(newCustomer); // Handles update internally based on ID
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.customer != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Editar Cliente' : 'Nuevo Cliente'),
        actions: [
          if (isEdit)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Eliminar Cliente'),
                    content: const Text('¿Estás seguro?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancelar')),
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Eliminar')),
                    ],
                  ),
                );

                if (confirm != true) return;
                if (!context.mounted) return;

                final provider = context.read<CustomerProvider>();
                await provider.deleteCustomer(widget.customer!.id!);
                if (context.mounted) Navigator.pop(context);
              },
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _pickContact,
                icon: const Icon(Icons.contacts),
                label: const Text('Importar desde Contactos'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nombre Completo *'),
              textCapitalization: TextCapitalization.words,
              validator: (value) => InputValidators.validateName(value),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Teléfono',
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
              validator: InputValidators.validateBolivianPhone,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: InputValidators.validateEmail,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Dirección',
                prefixIcon: Icon(Icons.location_on),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Guardar Cliente'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
