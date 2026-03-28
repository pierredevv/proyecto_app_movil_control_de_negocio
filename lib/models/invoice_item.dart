class InvoiceItem {
  final int? id;
  final int? transactionId;
  final int productId;
  final String productName; // Snapshot cache
  final double quantity; // Changed to double
  final double unitPrice;
  final double subtotal;
  final double unitCostAtSaleTime;
  final double? maxBaseStock; // Cached DB stock for paginated validation

  // NUEVO SISTEMA (Snapshot al momento de la venta):
  final String saleUnit; // ej: 'CAJ', 'UNI', 'BOL'
  final double unitsPerSaleUnit; // ej: 36 (36 uds base por cada venta)
  final String packagingInfo; // ej: '36x32g'

  InvoiceItem({
    this.id,
    this.transactionId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    double? subtotal,
    this.unitCostAtSaleTime = 0.0,
    this.maxBaseStock,
    this.saleUnit = 'UNI',
    this.unitsPerSaleUnit = 1.0,
    this.packagingInfo = '',
  }) : subtotal = subtotal ?? (quantity * unitPrice);

  // Cálculo de unidades base para la lógica de stock (NUEVO)
  double get baseUnitsTotal => quantity * unitsPerSaleUnit;

  InvoiceItem copyWith({
    int? id,
    int? transactionId,
    int? productId,
    String? productName,
    double? quantity,
    double? unitPrice,
    double? subtotal,
    double? unitCostAtSaleTime,
    double? maxBaseStock,
    String? saleUnit,
    double? unitsPerSaleUnit,
    String? packagingInfo,
  }) {
    return InvoiceItem(
      id: id ?? this.id,
      transactionId: transactionId ?? this.transactionId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      subtotal: subtotal ??
          (quantity != null || unitPrice != null
              ? (quantity ?? this.quantity) * (unitPrice ?? this.unitPrice)
              : this.subtotal),
      unitCostAtSaleTime: unitCostAtSaleTime ?? this.unitCostAtSaleTime,
      maxBaseStock: maxBaseStock ?? this.maxBaseStock,
      saleUnit: saleUnit ?? this.saleUnit,
      unitsPerSaleUnit: unitsPerSaleUnit ?? this.unitsPerSaleUnit,
      packagingInfo: packagingInfo ?? this.packagingInfo,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'transaction_id': transactionId,
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'unit_price': unitPrice,
      'subtotal': subtotal,
      'unit_cost_at_sale_time': unitCostAtSaleTime,
      'sale_unit': saleUnit,
      'units_per_sale_unit': unitsPerSaleUnit,
      'packaging_info': packagingInfo,
    };
  }

  factory InvoiceItem.fromMap(Map<String, dynamic> map) {
    return InvoiceItem(
      id: map['id'],
      transactionId: map['transaction_id'],
      productId: map['product_id'],
      productName: map['product_name'],
      quantity: (map['quantity'] as num).toDouble(),
      unitPrice: (map['unit_price'] as num).toDouble(),
      subtotal: (map['subtotal'] as num).toDouble(),
      unitCostAtSaleTime: (map['unit_cost_at_sale_time'] as num?)?.toDouble() ?? 0.0,
      saleUnit: map['sale_unit'] as String? ?? 'UNI',
      unitsPerSaleUnit: (map['units_per_sale_unit'] as num?)?.toDouble() ?? 1.0,
      packagingInfo: map['packaging_info'] as String? ?? '',
    );
  }
}
