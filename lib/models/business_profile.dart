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
  final String zone;
  final String streetNumber;
  final String branchNumber;
  final String posNumber;

  final String invoiceFooter;
  final bool showNitOnInvoice;
  final bool showLogoOnInvoice;
  final bool printLogoOnThermal;
  final double logoSpacing;

  // POS & Inventory settings
  final int defaultMinStock;
  final int lowStockThreshold;
  final bool confirmClearCart;
  final bool autoClearCartAfterSale;
  final bool showOutOfStockInPOS;
  final bool lowStockAlertsEnabled;
  final bool allowNegativeStock;
  final bool allowInvoiceAdjustments;

  // Advanced Printer Settings
  final String printerProfile; // 'default', 'epson', 'xprinter'
  final String codePage; 
  final int printDensity; 
  final bool enableExpertMode;
  final bool disableAutoCut;
  final int leftMargin;

  // Currency & Locale settings
  final String currencySymbol;
  final String currencyCode;
  final String currencyName;
  final String locale;

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
    this.zone = '',
    this.streetNumber = '',
    this.branchNumber = '0',
    this.posNumber = '0',
    this.invoiceFooter = '¡Gracias por su compra!',
    this.showNitOnInvoice = true,
    this.showLogoOnInvoice = true,
    this.printLogoOnThermal = false,
    this.logoSpacing = 6.0,
    this.defaultMinStock = 0,
    this.lowStockThreshold = 3,
    this.confirmClearCart = true,
    this.autoClearCartAfterSale = true,
    this.showOutOfStockInPOS = true,
    this.lowStockAlertsEnabled = true,
    this.allowNegativeStock = false,
    this.allowInvoiceAdjustments = false,
    this.printerProfile = 'default',
    this.codePage = 'CP858',
    this.printDensity = 0,
    this.enableExpertMode = false,
    this.disableAutoCut = false,
    this.leftMargin = 0,
    this.currencySymbol = 'Bs.',
    this.currencyCode = 'BOB',
    this.currencyName = 'Bolivianos',
    this.locale = 'es_BO',
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
    String? zone,
    String? streetNumber,
    String? branchNumber,
    String? posNumber,
    String? invoiceFooter,
    bool? showNitOnInvoice,
    bool? showLogoOnInvoice,
    bool? printLogoOnThermal,
    double? logoSpacing,
    int? defaultMinStock,
    int? lowStockThreshold,
    bool? confirmClearCart,
    bool? autoClearCartAfterSale,
    bool? showOutOfStockInPOS,
    bool? lowStockAlertsEnabled,
    bool? allowNegativeStock,
    bool? allowInvoiceAdjustments,
    String? printerProfile,
    String? codePage,
    int? printDensity,
    bool? enableExpertMode,
    bool? disableAutoCut,
    int? leftMargin,
    String? currencySymbol,
    String? currencyCode,
    String? currencyName,
    String? locale,
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
      zone: zone ?? this.zone,
      streetNumber: streetNumber ?? this.streetNumber,
      branchNumber: branchNumber ?? this.branchNumber,
      posNumber: posNumber ?? this.posNumber,
      invoiceFooter: invoiceFooter ?? this.invoiceFooter,
      showNitOnInvoice: showNitOnInvoice ?? this.showNitOnInvoice,
      showLogoOnInvoice: showLogoOnInvoice ?? this.showLogoOnInvoice,
      printLogoOnThermal: printLogoOnThermal ?? this.printLogoOnThermal,
      logoSpacing: logoSpacing ?? this.logoSpacing,
      defaultMinStock: defaultMinStock ?? this.defaultMinStock,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      confirmClearCart: confirmClearCart ?? this.confirmClearCart,
      autoClearCartAfterSale:
          autoClearCartAfterSale ?? this.autoClearCartAfterSale,
      showOutOfStockInPOS: showOutOfStockInPOS ?? this.showOutOfStockInPOS,
      lowStockAlertsEnabled:
          lowStockAlertsEnabled ?? this.lowStockAlertsEnabled,
      allowNegativeStock: allowNegativeStock ?? this.allowNegativeStock,
      allowInvoiceAdjustments:
          allowInvoiceAdjustments ?? this.allowInvoiceAdjustments,
      printerProfile: printerProfile ?? this.printerProfile,
      codePage: codePage ?? this.codePage,
      printDensity: printDensity ?? this.printDensity,
      enableExpertMode: enableExpertMode ?? this.enableExpertMode,
      disableAutoCut: disableAutoCut ?? this.disableAutoCut,
      leftMargin: leftMargin ?? this.leftMargin,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      currencyCode: currencyCode ?? this.currencyCode,
      currencyName: currencyName ?? this.currencyName,
      locale: locale ?? this.locale,
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
      'zone': zone,
      'streetNumber': streetNumber,
      'branchNumber': branchNumber,
      'posNumber': posNumber,
      'invoiceFooter': invoiceFooter,
      'showNitOnInvoice': showNitOnInvoice,
      'showLogoOnInvoice': showLogoOnInvoice,
      'printLogoOnThermal': printLogoOnThermal,
      'logoSpacing': logoSpacing,
      'defaultMinStock': defaultMinStock,
      'lowStockThreshold': lowStockThreshold,
      'confirmClearCart': confirmClearCart,
      'autoClearCartAfterSale': autoClearCartAfterSale,
      'showOutOfStockInPOS': showOutOfStockInPOS,
      'lowStockAlertsEnabled': lowStockAlertsEnabled,
      'allowNegativeStock': allowNegativeStock,
      'allowInvoiceAdjustments': allowInvoiceAdjustments,
      'printerProfile': printerProfile,
      'codePage': codePage,
      'printDensity': printDensity,
      'enableExpertMode': enableExpertMode,
      'disableAutoCut': disableAutoCut,
      'leftMargin': leftMargin,
      'currencySymbol': currencySymbol,
      'currencyCode': currencyCode,
      'currencyName': currencyName,
      'locale': locale,
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
      zone: map['zone'] ?? '',
      streetNumber: map['streetNumber'] ?? '',
      branchNumber: map['branchNumber'] ?? '0',
      posNumber: map['posNumber'] ?? '0',
      invoiceFooter: map['invoiceFooter'] ?? '¡Gracias por su compra!',
      showNitOnInvoice: map['showNitOnInvoice'] ?? true,
      showLogoOnInvoice: map['showLogoOnInvoice'] ?? true,
      printLogoOnThermal: map['printLogoOnThermal'] ?? false,
      logoSpacing: (map['logoSpacing'] as num?)?.toDouble() ?? 6.0,
      defaultMinStock: map['defaultMinStock']?.toInt() ?? 0,
      lowStockThreshold: map['lowStockThreshold']?.toInt() ?? 3,
      confirmClearCart: map['confirmClearCart'] ?? true,
      autoClearCartAfterSale: map['autoClearCartAfterSale'] ?? true,
      showOutOfStockInPOS: map['showOutOfStockInPOS'] ?? true,
      lowStockAlertsEnabled: map['lowStockAlertsEnabled'] ?? true,
      allowNegativeStock: map['allowNegativeStock'] ?? false,
      allowInvoiceAdjustments: map['allowInvoiceAdjustments'] ?? false,
      printerProfile: map['printerProfile'] ?? 'default',
      codePage: map['codePage'] ?? 'CP858',
      printDensity: map['printDensity']?.toInt() ?? 0,
      enableExpertMode: map['enableExpertMode'] ?? false,
      disableAutoCut: map['disableAutoCut'] ?? false,
      leftMargin: map['leftMargin']?.toInt() ?? 0,
      currencySymbol: map['currencySymbol'] ?? 'Bs.',
      currencyCode: map['currencyCode'] ?? 'BOB',
      currencyName: map['currencyName'] ?? 'Bolivianos',
      locale: map['locale'] ?? 'es_BO',
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
      zone: zone,
      streetNumber: streetNumber,
      branchNumber: branchNumber,
      posNumber: posNumber,
      invoiceFooter: invoiceFooter,
      showNitOnInvoice: showNitOnInvoice,
      showLogoOnInvoice: showLogoOnInvoice,
      printLogoOnThermal: printLogoOnThermal,
      logoSpacing: logoSpacing,
      defaultMinStock: defaultMinStock,
      lowStockThreshold: lowStockThreshold,
      confirmClearCart: confirmClearCart,
      autoClearCartAfterSale: autoClearCartAfterSale,
      showOutOfStockInPOS: showOutOfStockInPOS,
      lowStockAlertsEnabled: lowStockAlertsEnabled,
      allowNegativeStock: allowNegativeStock,
      allowInvoiceAdjustments: allowInvoiceAdjustments,
      printerProfile: printerProfile,
      codePage: codePage,
      printDensity: printDensity,
      enableExpertMode: enableExpertMode,
      disableAutoCut: disableAutoCut,
      leftMargin: leftMargin,
      currencySymbol: currencySymbol,
      currencyCode: currencyCode,
      currencyName: currencyName,
      locale: locale,
    );
  }
}
