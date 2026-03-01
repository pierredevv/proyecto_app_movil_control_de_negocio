class BusinessProfile {
  final String businessName;
  final String ownerName;
  final String businessType;
  final String? logoPath;

  final String nit;
  final String ci;
  final String invoicePrefix;

  final String phone;
  final String whatsapp;
  final String email;

  final String city;
  final String department;
  final String address;

  final String invoiceFooter;
  final bool showNitOnInvoice;
  final bool showLogoOnInvoice;

  // POS & Inventory settings
  final int defaultMinStock;
  final int lowStockThreshold;
  final bool confirmClearCart;
  final bool autoClearCartAfterSale;
  final bool showOutOfStockInPOS;
  final bool lowStockAlertsEnabled;

  const BusinessProfile({
    this.businessName = 'Mi Negocio',
    this.ownerName = '',
    this.businessType = '',
    this.logoPath,
    this.nit = '',
    this.ci = '',
    this.invoicePrefix = 'VTA',
    this.phone = '',
    this.whatsapp = '',
    this.email = '',
    this.city = 'Santa Cruz',
    this.department = 'Santa Cruz',
    this.address = '',
    this.invoiceFooter = '¡Gracias por su compra!',
    this.showNitOnInvoice = true,
    this.showLogoOnInvoice = true,
    this.defaultMinStock = 0,
    this.lowStockThreshold = 3,
    this.confirmClearCart = true,
    this.autoClearCartAfterSale = true,
    this.showOutOfStockInPOS = true,
    this.lowStockAlertsEnabled = true,
  });

  BusinessProfile copyWith({
    String? businessName,
    String? ownerName,
    String? businessType,
    String? logoPath,
    String? nit,
    String? ci,
    String? invoicePrefix,
    String? phone,
    String? whatsapp,
    String? email,
    String? city,
    String? department,
    String? address,
    String? invoiceFooter,
    bool? showNitOnInvoice,
    bool? showLogoOnInvoice,
    int? defaultMinStock,
    int? lowStockThreshold,
    bool? confirmClearCart,
    bool? autoClearCartAfterSale,
    bool? showOutOfStockInPOS,
    bool? lowStockAlertsEnabled,
  }) {
    return BusinessProfile(
      businessName: businessName ?? this.businessName,
      ownerName: ownerName ?? this.ownerName,
      businessType: businessType ?? this.businessType,
      logoPath: logoPath ?? this.logoPath,
      nit: nit ?? this.nit,
      ci: ci ?? this.ci,
      invoicePrefix: invoicePrefix ?? this.invoicePrefix,
      phone: phone ?? this.phone,
      whatsapp: whatsapp ?? this.whatsapp,
      email: email ?? this.email,
      city: city ?? this.city,
      department: department ?? this.department,
      address: address ?? this.address,
      invoiceFooter: invoiceFooter ?? this.invoiceFooter,
      showNitOnInvoice: showNitOnInvoice ?? this.showNitOnInvoice,
      showLogoOnInvoice: showLogoOnInvoice ?? this.showLogoOnInvoice,
      defaultMinStock: defaultMinStock ?? this.defaultMinStock,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      confirmClearCart: confirmClearCart ?? this.confirmClearCart,
      autoClearCartAfterSale:
          autoClearCartAfterSale ?? this.autoClearCartAfterSale,
      showOutOfStockInPOS: showOutOfStockInPOS ?? this.showOutOfStockInPOS,
      lowStockAlertsEnabled:
          lowStockAlertsEnabled ?? this.lowStockAlertsEnabled,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'businessName': businessName,
      'ownerName': ownerName,
      'businessType': businessType,
      'logoPath': logoPath,
      'nit': nit,
      'ci': ci,
      'invoicePrefix': invoicePrefix,
      'phone': phone,
      'whatsapp': whatsapp,
      'email': email,
      'city': city,
      'department': department,
      'address': address,
      'invoiceFooter': invoiceFooter,
      'showNitOnInvoice': showNitOnInvoice,
      'showLogoOnInvoice': showLogoOnInvoice,
      'defaultMinStock': defaultMinStock,
      'lowStockThreshold': lowStockThreshold,
      'confirmClearCart': confirmClearCart,
      'autoClearCartAfterSale': autoClearCartAfterSale,
      'showOutOfStockInPOS': showOutOfStockInPOS,
      'lowStockAlertsEnabled': lowStockAlertsEnabled,
    };
  }

  factory BusinessProfile.fromMap(Map<String, dynamic> map) {
    return BusinessProfile(
      businessName: map['businessName'] ?? 'Mi Negocio',
      ownerName: map['ownerName'] ?? '',
      businessType: map['businessType'] ?? '',
      logoPath: map['logoPath'],
      nit: map['nit'] ?? '',
      ci: map['ci'] ?? '',
      invoicePrefix: map['invoicePrefix'] ?? 'VTA',
      phone: map['phone'] ?? '',
      whatsapp: map['whatsapp'] ?? '',
      email: map['email'] ?? '',
      city: map['city'] ?? 'Santa Cruz',
      department: map['department'] ?? 'Santa Cruz',
      address: map['address'] ?? '',
      invoiceFooter: map['invoiceFooter'] ?? '¡Gracias por su compra!',
      showNitOnInvoice: map['showNitOnInvoice'] ?? true,
      showLogoOnInvoice: map['showLogoOnInvoice'] ?? true,
      defaultMinStock: map['defaultMinStock']?.toInt() ?? 0,
      lowStockThreshold: map['lowStockThreshold']?.toInt() ?? 3,
      confirmClearCart: map['confirmClearCart'] ?? true,
      autoClearCartAfterSale: map['autoClearCartAfterSale'] ?? true,
      showOutOfStockInPOS: map['showOutOfStockInPOS'] ?? true,
      lowStockAlertsEnabled: map['lowStockAlertsEnabled'] ?? true,
    );
  }

  BusinessProfile clearLogo() {
    return BusinessProfile(
      businessName: businessName,
      ownerName: ownerName,
      businessType: businessType,
      logoPath: null, // Clear the logo
      nit: nit,
      ci: ci,
      invoicePrefix: invoicePrefix,
      phone: phone,
      whatsapp: whatsapp,
      email: email,
      city: city,
      department: department,
      address: address,
      invoiceFooter: invoiceFooter,
      showNitOnInvoice: showNitOnInvoice,
      showLogoOnInvoice: showLogoOnInvoice,
      defaultMinStock: defaultMinStock,
      lowStockThreshold: lowStockThreshold,
      confirmClearCart: confirmClearCart,
      autoClearCartAfterSale: autoClearCartAfterSale,
      showOutOfStockInPOS: showOutOfStockInPOS,
      lowStockAlertsEnabled: lowStockAlertsEnabled,
    );
  }
}
