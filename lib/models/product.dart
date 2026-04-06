class Product {
  final int? id;
  final String name;
  final String barcode;
  final double price;
  final double cost;
  final double weightedAverageCost;
  final double stock; // Changed to double
  final int minStock;
  final int? categoryId;
  final int? supplierId;
  final String saleUnit; // 'CAJ', 'BOL', 'UNI', 'KG'
  final double
      unitsPerSaleUnit; // how many base units are in 1 saleUnit (ex: 36)
  final String? secondaryUnit; // 'TIR', 'PAQ'
  final double? unitsPerSecondary; // how many base units are in 1 secondaryUnit (ex: 18)
  final String
      packagingInfo; // visual string "36x32g", "18x250", "" if not applicable
  final DateTime createdAt;
  final String? imagePath;

  Product({
    this.id,
    required this.name,
    required this.barcode,
    required this.price,
    required this.cost,
    this.weightedAverageCost = 0.0,
    required this.stock,
    this.minStock = 0,
    this.categoryId,
    this.supplierId,
    this.saleUnit = 'UNI',
    this.unitsPerSaleUnit = 1.0,
    this.secondaryUnit,
    this.unitsPerSecondary,
    this.packagingInfo = '',
    DateTime? createdAt,
    this.imagePath,
  }) : createdAt = createdAt ?? DateTime.now();

  // Computed: how many "boxes" (saleUnits) are available in stock
  double get stockInSaleUnits {
    if (unitsPerSaleUnit <= 0) return stock;
    return stock / unitsPerSaleUnit;
  }

  // Computed: display string for UI → "36x32g" or "" if it is simple UNI
  String get displayPackaging {
    if (packagingInfo.isNotEmpty) return packagingInfo;
    if (saleUnit != 'UNI' && unitsPerSaleUnit > 1) {
      return '${unitsPerSaleUnit.toInt()}u';
    }
    return '';
  }

  Product copyWith({
    int? id,
    String? name,
    String? barcode,
    double? price,
    double? cost,
    double? weightedAverageCost,
    double? stock,
    int? minStock,
    int? categoryId,
    int? supplierId,
    String? saleUnit,
    double? unitsPerSaleUnit,
    String? secondaryUnit,
    double? unitsPerSecondary,
    String? packagingInfo,
    DateTime? createdAt,
    String? imagePath,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      barcode: barcode ?? this.barcode,
      price: price ?? this.price,
      cost: cost ?? this.cost,
      weightedAverageCost: weightedAverageCost ?? this.weightedAverageCost,
      stock: stock ?? this.stock,
      minStock: minStock ?? this.minStock,
      categoryId: categoryId ?? this.categoryId,
      supplierId: supplierId ?? this.supplierId,
      saleUnit: saleUnit ?? this.saleUnit,
      unitsPerSaleUnit: unitsPerSaleUnit ?? this.unitsPerSaleUnit,
      secondaryUnit: secondaryUnit ?? this.secondaryUnit,
      unitsPerSecondary: unitsPerSecondary ?? this.unitsPerSecondary,
      packagingInfo: packagingInfo ?? this.packagingInfo,
      createdAt: createdAt ?? this.createdAt,
      imagePath: imagePath ?? this.imagePath,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'barcode': barcode,
      'price': price,
      'cost': cost,
      'weighted_average_cost': weightedAverageCost,
      'stock': stock,
      'min_stock': minStock,
      'category_id': categoryId,
      'supplier_id': supplierId,
      'unit_type': saleUnit, // same column name for backward compatibility
      'units_per_box': unitsPerSaleUnit, // same column name
      'secondary_unit': secondaryUnit,
      'units_per_secondary': unitsPerSecondary,
      'packaging_info': packagingInfo, // NEW column
      'created_at': createdAt.millisecondsSinceEpoch,
      'image_path': imagePath,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      name: map['name'],
      barcode: map['barcode'],
      price: map['price'],
      cost: map['cost'],
      weightedAverageCost: (map['weighted_average_cost'] as num?)?.toDouble() ?? (map['cost'] as num?)?.toDouble() ?? 0.0,
      stock: (map['stock'] as num).toDouble(), // Handle int from old DB
      minStock: map['min_stock'] ?? 0,
      categoryId: map['category_id'],
      supplierId: map['supplier_id'],
      saleUnit: map['unit_type'] ?? 'UNI',
      unitsPerSaleUnit: (map['units_per_box'] as num?)?.toDouble() ?? 1.0,
      secondaryUnit: map['secondary_unit'],
      unitsPerSecondary: (map['units_per_secondary'] as num?)?.toDouble(),
      packagingInfo: map['packaging_info'] ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      imagePath: map['image_path'],
    );
  }
}
