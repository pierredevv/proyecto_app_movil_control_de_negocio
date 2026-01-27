class Product {
  final int? id;
  final String name;
  final String barcode;
  final double price;
  final double cost;
  final double stock; // Changed to double
  final int minStock;
  final int? categoryId;
  final int? supplierId;
  final String unitType; // 'UN', 'BX', 'KG'
  final double unitsPerBox; // Conversion factor, default 1.0
  final DateTime createdAt;
  final String? imagePath;

  Product({
    this.id,
    required this.name,
    required this.barcode,
    required this.price,
    required this.cost,
    required this.stock,
    this.minStock = 0,
    this.categoryId,
    this.supplierId,
    this.unitType = 'UN',
    this.unitsPerBox = 1.0,
    DateTime? createdAt,
    this.imagePath,
  }) : createdAt = createdAt ?? DateTime.now();

  Product copyWith({
    int? id,
    String? name,
    String? barcode,
    double? price,
    double? cost,
    double? stock,
    int? minStock,
    int? categoryId,
    int? supplierId,
    String? unitType,
    double? unitsPerBox,
    DateTime? createdAt,
    String? imagePath,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      barcode: barcode ?? this.barcode,
      price: price ?? this.price,
      cost: cost ?? this.cost,
      stock: stock ?? this.stock,
      minStock: minStock ?? this.minStock,
      categoryId: categoryId ?? this.categoryId,
      supplierId: supplierId ?? this.supplierId,
      unitType: unitType ?? this.unitType,
      unitsPerBox: unitsPerBox ?? this.unitsPerBox,
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
      'stock': stock,
      'min_stock': minStock,
      'category_id': categoryId,
      'supplier_id': supplierId,
      'unit_type': unitType,
      'units_per_box': unitsPerBox,
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
      stock: (map['stock'] as num).toDouble(), // Handle int from old DB
      minStock: map['min_stock'] ?? 0,
      categoryId: map['category_id'],
      supplierId: map['supplier_id'],
      unitType: map['unit_type'] ?? 'UN',
      unitsPerBox: (map['units_per_box'] as num?)?.toDouble() ?? 1.0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      imagePath: map['image_path'],
    );
  }
}
