class ProductImportRow {
  final String name;
  final String barcode;
  final double cost;
  final double price;
  final double stockBase; // Important: already in base units
  final String category;

  // Packaging Info
  final String saleUnit;
  final double unitsPerSaleUnit;
  final String packagingInfo;

  ProductImportRow({
    required this.name,
    this.barcode = '',
    this.cost = 0.0,
    this.price = 0.0,
    this.stockBase = 0.0,
    this.category = '',
    this.saleUnit = 'UNI',
    this.unitsPerSaleUnit = 1.0,
    this.packagingInfo = '',
  });

  ProductImportRow copyWith({
    String? name,
    String? barcode,
    double? cost,
    double? price,
    double? stockBase,
    String? category,
    String? saleUnit,
    double? unitsPerSaleUnit,
    String? packagingInfo,
  }) {
    return ProductImportRow(
      name: name ?? this.name,
      barcode: barcode ?? this.barcode,
      cost: cost ?? this.cost,
      price: price ?? this.price,
      stockBase: stockBase ?? this.stockBase,
      category: category ?? this.category,
      saleUnit: saleUnit ?? this.saleUnit,
      unitsPerSaleUnit: unitsPerSaleUnit ?? this.unitsPerSaleUnit,
      packagingInfo: packagingInfo ?? this.packagingInfo,
    );
  }
}

class ImportRowError {
  final int rowIndex;
  final String message;

  ImportRowError(this.rowIndex, this.message);
}

class ImportParseResult {
  final List<ProductImportRow> rows;
  final List<ImportRowError> errors;
  final Map<String, String> columnMapping;
  final List<String> rawHeaders;
  final List<List<String>> rawStringRows;

  ImportParseResult({
    required this.rows,
    required this.errors,
    required this.columnMapping,
    required this.rawHeaders,
    required this.rawStringRows,
  });
}
