import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_theme.dart';
import '../../services/database_service.dart';

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
  bool _printLogoOnThermal = false;
  double _logoSpacing = 6.0;
  bool _allowNegativeStock = false;
  bool _allowInvoiceAdjustments = false;
  bool _allowEditablePricesInPOS = false;
  String? _logoPath;

  // Advanced Printer Config
  String _printerProfile = 'default';
  String _codePage = 'CP858';
  int _printDensity = 0;
  bool _enableExpertMode = false;
  bool _disableAutoCut = false;
  late TextEditingController _leftMarginCtrl;

  // Currency, Locale & DB Config
  late TextEditingController _currencySymbolCtrl;
  late TextEditingController _currencyCodeCtrl;
  late TextEditingController _currencyNameCtrl;
  late TextEditingController _localeCtrl;
  late TextEditingController _dbNameCtrl;
  String _currentDbName = 'dulces_pierre.db';

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
    _printLogoOnThermal = profile.printLogoOnThermal;
    _logoSpacing = profile.logoSpacing;
    _allowNegativeStock = profile.allowNegativeStock;
    _allowInvoiceAdjustments = profile.allowInvoiceAdjustments;
    _allowEditablePricesInPOS = profile.allowEditablePricesInPOS;
    _logoPath = profile.logoPath;

    _printerProfile = profile.printerProfile;
    _codePage = profile.codePage;
    _printDensity = profile.printDensity;
    _enableExpertMode = profile.enableExpertMode;
    _disableAutoCut = profile.disableAutoCut;
    _leftMarginCtrl = TextEditingController(text: profile.leftMargin.toString());

    _currencySymbolCtrl = TextEditingController(text: profile.currencySymbol);
    _currencyCodeCtrl = TextEditingController(text: profile.currencyCode);
    _currencyNameCtrl = TextEditingController(text: profile.currencyName);
    _localeCtrl = TextEditingController(text: profile.locale);
    _dbNameCtrl = TextEditingController();

    // Async load database name
    DatabaseService().getCurrentDbName().then((name) {
      if (mounted) {
        setState(() {
          _currentDbName = name;
          _dbNameCtrl.text = name.replaceAll('.db', '');
        });
      }
    });
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
    _leftMarginCtrl.dispose();
    _currencySymbolCtrl.dispose();
    _currencyCodeCtrl.dispose();
    _currencyNameCtrl.dispose();
    _localeCtrl.dispose();
    _dbNameCtrl.dispose();
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

    final settingsProvider = context.read<SettingsProvider>();
    final currentProfile = settingsProvider.profile;
    
    // Check if database name changed
    String newDbName = _dbNameCtrl.text.trim();
    if (newDbName.isNotEmpty && !newDbName.endsWith('.db')) {
      newDbName = '$newDbName.db';
    }
    
    bool dbRenameSuccess = true;
    if (newDbName.isNotEmpty && newDbName != _currentDbName) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      dbRenameSuccess = await DatabaseService().renameDatabase(newDbName);
      
      if (mounted) {
        Navigator.pop(context); // Close progress dialog
      }
      
      if (!dbRenameSuccess) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error al cambiar el nombre de la base de datos. Se revirtió el cambio.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return; // Abort saving profile to keep consistent state
      }
    }
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
      printLogoOnThermal: _printLogoOnThermal,
      logoSpacing: _logoSpacing,
      allowNegativeStock: _allowNegativeStock,
      allowInvoiceAdjustments: _allowInvoiceAdjustments,
      allowEditablePricesInPOS: _allowEditablePricesInPOS,
      printerProfile: _printerProfile,
      codePage: _codePage,
      printDensity: _printDensity,
      enableExpertMode: _enableExpertMode,
      disableAutoCut: _disableAutoCut,
      leftMargin: int.tryParse(_leftMarginCtrl.text) ?? 0,
      currencySymbol: _currencySymbolCtrl.text.trim(),
      currencyCode: _currencyCodeCtrl.text.trim(),
      currencyName: _currencyNameCtrl.text.trim(),
      locale: _localeCtrl.text.trim(),
    );

    await settingsProvider.updateProfile(updatedProfile);

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
            SwitchListTile(
              title: const Text('Imprimir Logo en Impresora Térmica'),
              subtitle: const Text('Si está activo, imprime el logo al inicio del ticket'),
              value: _printLogoOnThermal,
              onChanged: (v) => setState(() => _printLogoOnThermal = v),
            ),
            if (_showLogoOnInvoice || _printLogoOnThermal)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Espaciado debajo del Logo: ${_logoSpacing.toStringAsFixed(1)}',
                        style: const TextStyle(fontSize: 14)),
                    Slider(
                      value: _logoSpacing,
                      min: 0.0,
                      max: 40.0,
                      divisions: 40,
                      label: _logoSpacing.toStringAsFixed(1),
                      onChanged: (val) => setState(() => _logoSpacing = val),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),
            
            const _SectionTitle('Hardware y Dispositivos'),
            SwitchListTile(
              title: const Text('Modo Técnico / Experto'),
              subtitle: const Text('Habilitar comandos crudos ESC/POS'),
              value: _enableExpertMode,
              onChanged: (v) => setState(() => _enableExpertMode = v),
            ),
            if (_enableExpertMode)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Página de Códigos (Encoding)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
                      DropdownButton<String>(
                        dropdownColor: AppTheme.cardDark,
                        value: _codePage,
                        isExpanded: true,
                        style: const TextStyle(color: Colors.white),
                        items: ['CP437', 'CP850', 'CP858', 'CP860']
                            .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(color: Colors.white))))
                            .toList(),
                        onChanged: (v) => setState(() => _codePage = v!),
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        ctrl: _leftMarginCtrl,
                        label: 'Margen Izquierdo (puntos)',
                        icon: Icons.space_bar,
                        inputType: TextInputType.number,
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Desactivar Auto-Corte', style: TextStyle(color: Colors.white)),
                        value: _disableAutoCut,
                        onChanged: (v) => setState(() => _disableAutoCut = v),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.restore, color: Colors.amber),
                        label: const Text('Restaurar Predeterminado', style: TextStyle(color: Colors.amber)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.amber),
                          foregroundColor: Colors.amber,
                        ),
                        onPressed: () {
                          setState(() {
                            _codePage = 'CP858';
                            _leftMarginCtrl.text = '0';
                            _disableAutoCut = false;
                            _printDensity = 0;
                            _enableExpertMode = false;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Configuración segura restaurada.')));
                        },
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 24),


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
            SwitchListTile(
              title: const Text('Precios Editables en Punto de Venta'),
              subtitle: const Text('Permite modificar el precio unitario al momento de vender'),
              value: _allowEditablePricesInPOS,
              onChanged: (v) => setState(() => _allowEditablePricesInPOS = v),
            ),

            const SizedBox(height: 24),

            const _SectionTitle('Configuración Regional & DB'),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                      ctrl: _currencySymbolCtrl,
                      label: 'Símbolo Moneda',
                      icon: Icons.attach_money),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                      ctrl: _currencyCodeCtrl,
                      label: 'Código (ej: BOB)',
                      icon: Icons.code),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                      ctrl: _currencyNameCtrl,
                      label: 'Nombre (ej: Bolivianos)',
                      icon: Icons.text_fields),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                      ctrl: _localeCtrl,
                      label: 'Locale (ej: es_BO)',
                      icon: Icons.language),
                ),
              ],
            ),
            _buildTextField(
                ctrl: _dbNameCtrl,
                label: 'Nombre Base de Datos (ej: dulces_pierre)',
                icon: Icons.storage),
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                'Advertencia: Renombrar la BD moverá sus datos. (No incluya .db)',
                style: TextStyle(fontSize: 12, color: Colors.orange),
              ),
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
