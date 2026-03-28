import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';

class BusinessProfileScreen extends StatefulWidget {
  const BusinessProfileScreen({super.key});

  @override
  State<BusinessProfileScreen> createState() => _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends State<BusinessProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _businessNameCtrl;
  late TextEditingController _ownerNameCtrl;
  late TextEditingController _businessTypeCtrl;
  late TextEditingController _nitCtrl;
  late TextEditingController _ciCtrl;
  late TextEditingController _invoicePrefixCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _whatsappCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _cityCtrl;
  late TextEditingController _departmentCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _zoneCtrl;
  late TextEditingController _streetNumberCtrl;
  late TextEditingController _branchNumberCtrl;
  late TextEditingController _posNumberCtrl;
  late TextEditingController _invoiceFooterCtrl;
  late TextEditingController _defaultMinStockCtrl;
  late TextEditingController _lowStockThresholdCtrl;

  bool _showNitOnInvoice = true;
  bool _showLogoOnInvoice = true;
  bool _allowNegativeStock = false;
  bool _allowInvoiceAdjustments = false;
  String? _logoPath;

  @override
  void initState() {
    super.initState();
    final profile = context.read<SettingsProvider>().profile;

    _businessNameCtrl = TextEditingController(text: profile.businessName);
    _ownerNameCtrl = TextEditingController(text: profile.ownerName);
    _businessTypeCtrl = TextEditingController(text: profile.businessType);
    _nitCtrl = TextEditingController(text: profile.nit);
    _ciCtrl = TextEditingController(text: profile.ci);
    _invoicePrefixCtrl = TextEditingController(text: profile.invoicePrefix);
    _phoneCtrl = TextEditingController(text: profile.phone);
    _whatsappCtrl = TextEditingController(text: profile.whatsapp);
    _emailCtrl = TextEditingController(text: profile.email);
    _cityCtrl = TextEditingController(text: profile.city);
    _departmentCtrl = TextEditingController(text: profile.department);
    _addressCtrl = TextEditingController(text: profile.address);
    _zoneCtrl = TextEditingController(text: profile.zone);
    _streetNumberCtrl = TextEditingController(text: profile.streetNumber);
    _branchNumberCtrl = TextEditingController(text: profile.branchNumber);
    _posNumberCtrl = TextEditingController(text: profile.posNumber);
    _invoiceFooterCtrl = TextEditingController(text: profile.invoiceFooter);
    _defaultMinStockCtrl =
        TextEditingController(text: profile.defaultMinStock.toString());
    _lowStockThresholdCtrl =
        TextEditingController(text: profile.lowStockThreshold.toString());

    _showNitOnInvoice = profile.showNitOnInvoice;
    _showLogoOnInvoice = profile.showLogoOnInvoice;
    _allowNegativeStock = profile.allowNegativeStock;
    _allowInvoiceAdjustments = profile.allowInvoiceAdjustments;
    _logoPath = profile.logoPath;
  }

  @override
  void dispose() {
    _businessNameCtrl.dispose();
    _ownerNameCtrl.dispose();
    _businessTypeCtrl.dispose();
    _nitCtrl.dispose();
    _ciCtrl.dispose();
    _invoicePrefixCtrl.dispose();
    _phoneCtrl.dispose();
    _whatsappCtrl.dispose();
    _emailCtrl.dispose();
    _cityCtrl.dispose();
    _departmentCtrl.dispose();
    _addressCtrl.dispose();
    _zoneCtrl.dispose();
    _streetNumberCtrl.dispose();
    _branchNumberCtrl.dispose();
    _posNumberCtrl.dispose();
    _invoiceFooterCtrl.dispose();
    _defaultMinStockCtrl.dispose();
    _lowStockThresholdCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _logoPath = pickedFile.path;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final currentProfile = context.read<SettingsProvider>().profile;
    final updatedProfile = currentProfile.copyWith(
      businessName: _businessNameCtrl.text.trim(),
      ownerName: _ownerNameCtrl.text.trim(),
      businessType: _businessTypeCtrl.text.trim(),
      logoPath: _logoPath,
      nit: _nitCtrl.text.trim(),
      ci: _ciCtrl.text.trim(),
      invoicePrefix: _invoicePrefixCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      whatsapp: _whatsappCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      city: _cityCtrl.text.trim(),
      department: _departmentCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      zone: _zoneCtrl.text.trim(),
      streetNumber: _streetNumberCtrl.text.trim(),
      branchNumber: _branchNumberCtrl.text.trim(),
      posNumber: _posNumberCtrl.text.trim(),
      invoiceFooter: _invoiceFooterCtrl.text.trim(),
      defaultMinStock: int.tryParse(_defaultMinStockCtrl.text) ?? 0,
      lowStockThreshold: int.tryParse(_lowStockThresholdCtrl.text) ?? 3,
      showNitOnInvoice: _showNitOnInvoice,
      showLogoOnInvoice: _showLogoOnInvoice,
      allowNegativeStock: _allowNegativeStock,
      allowInvoiceAdjustments: _allowInvoiceAdjustments,
    );

    await context.read<SettingsProvider>().updateProfile(updatedProfile);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Perfil actualizado correctamente'),
            backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil de Negocio'),
        actions: [
          TextButton(
            onPressed: _saveProfile,
            child: const Text('Guardar',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // LOGO
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    image: _logoPath != null && _logoPath!.isNotEmpty
                        ? DecorationImage(
                            image: FileImage(File(_logoPath!)),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _logoPath == null || _logoPath!.isEmpty
                      ? const Icon(Icons.add_a_photo,
                          size: 40, color: Colors.grey)
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text('Toca para cambiar el logo',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
            ),
            const SizedBox(height: 24),

            const _SectionTitle('Identidad y Contacto'),
            _buildTextField(
                ctrl: _businessNameCtrl,
                label: 'Nombre del Negocio',
                icon: Icons.store),
            _buildTextField(
                ctrl: _ownerNameCtrl, label: 'Propietario', icon: Icons.person),
            _buildTextField(
                ctrl: _businessTypeCtrl,
                label: 'Rubro / Tipo',
                icon: Icons.category),
            _buildTextField(
                ctrl: _phoneCtrl,
                label: 'Teléfono',
                icon: Icons.phone,
                inputType: TextInputType.phone),
            _buildTextField(
                ctrl: _whatsappCtrl,
                label: 'WhatsApp (ej: 59170123456)',
                icon: Icons.chat,
                inputType: TextInputType.phone),
            _buildTextField(
                ctrl: _emailCtrl,
                label: 'Correo Electrónico',
                icon: Icons.email,
                inputType: TextInputType.emailAddress),

            const SizedBox(height: 24),

            const _SectionTitle('Ubicación'),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                      ctrl: _cityCtrl,
                      label: 'Ciudad',
                      icon: Icons.location_city),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                      ctrl: _departmentCtrl,
                      label: 'Departamento',
                      icon: Icons.map),
                ),
              ],
            ),
            _buildTextField(
                ctrl: _addressCtrl,
                label: 'Dirección Completa',
                icon: Icons.location_on),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                      ctrl: _zoneCtrl,
                      label: 'Zona',
                      icon: Icons.map),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                      ctrl: _streetNumberCtrl,
                      label: 'Número/Calle',
                      icon: Icons.home),
                ),
              ],
            ),

            const SizedBox(height: 24),

            const _SectionTitle('Datos Fiscales / Facturación'),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                      ctrl: _nitCtrl, label: 'NIT', icon: Icons.numbers),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                      ctrl: _ciCtrl,
                      label: 'CI (Alternativo)',
                      icon: Icons.perm_identity),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                      ctrl: _branchNumberCtrl,
                      label: 'Nº Sucursal',
                      icon: Icons.storefront),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                      ctrl: _posNumberCtrl,
                      label: 'Punto Venta',
                      icon: Icons.point_of_sale),
                ),
              ],
            ),
            _buildTextField(
                ctrl: _invoicePrefixCtrl,
                label: 'Prefijo de Venta (Ej: VTA)',
                icon: Icons.receipt),
            _buildTextField(
                ctrl: _invoiceFooterCtrl,
                label: 'Mensaje a pie de Factura',
                icon: Icons.message),
            SwitchListTile(
              title: const Text('Mostrar NIT en PDF'),
              value: _showNitOnInvoice,
              onChanged: (v) => setState(() => _showNitOnInvoice = v),
            ),
            SwitchListTile(
              title: const Text('Mostrar Logo en PDF'),
              value: _showLogoOnInvoice,
              onChanged: (v) => setState(() => _showLogoOnInvoice = v),
            ),

            const _SectionTitle('Reglas de Negocio / ERP'),
            SwitchListTile(
              title: const Text('Permitir Stock Negativo'),
              subtitle: const Text('Permite vender aunque no haya stock (WAC congelado)'),
              value: _allowNegativeStock,
              onChanged: (v) => setState(() => _allowNegativeStock = v),
            ),
            SwitchListTile(
              title: const Text('Ajustes Finales en Factura'),
              subtitle: const Text('Permite redondear o modificar el total a pagar'),
              value: _allowInvoiceAdjustments,
              onChanged: (v) => setState(() => _allowInvoiceAdjustments = v),
            ),

            const SizedBox(height: 24),

            const _SectionTitle('Valores por Defecto'),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                      ctrl: _defaultMinStockCtrl,
                      label: 'Stock Mín. inicial',
                      icon: Icons.inventory,
                      inputType: TextInputType.number),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                      ctrl: _lowStockThresholdCtrl,
                      label: 'Umbral Alerta',
                      icon: Icons.warning,
                      inputType: TextInputType.number),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController ctrl,
    required String label,
    required IconData icon,
    TextInputType inputType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        keyboardType: inputType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
