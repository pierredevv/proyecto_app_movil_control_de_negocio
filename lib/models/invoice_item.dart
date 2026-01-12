class InvoiceItem {
  final int? id;
  final int? transactionId;
  final int productId;
  final String productName; // Snapshot cache
  final double quantity; // Changed to double
  final double unitPrice;
  final double subtotal;

  InvoiceItem({
    this.id,
    this.transactionId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    double? subtotal,
  }) : subtotal = subtotal ?? (quantity * unitPrice);

  InvoiceItem copyWith({
    int? id,
    int? transactionId,
    int? productId,
    String? productName,
    double? quantity,
    double? unitPrice,
    double? subtotal,
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
    };
  }

  factory InvoiceItem.fromMap(Map<String, dynamic> map) {
    return InvoiceItem(
      id: map['id'],
      transactionId: map['transaction_id'],
      productId: map['product_id'],
      productName: map['product_name'],
      quantity: (map['quantity'] as num).toDouble(), // Handle int from old DB
      unitPrice: (map['unit_price'] as num).toDouble(),
      subtotal: map['subtotal'], // Load if exists, otherwise calc
    );
  }
}
