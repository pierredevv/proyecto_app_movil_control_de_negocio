import 'invoice_item.dart';

enum TransactionType { sale, purchase, expense, payment, order }

abstract class Transaction {
  final int? id;
  final TransactionType type;
  final DateTime date;
  final double totalAmount;
  final double adjustmentAmount;
  final String status;
  final List<InvoiceItem> items;

  Transaction({
    this.id,
    required this.type,
    required this.date,
    required this.totalAmount,
    this.adjustmentAmount = 0.0,
    this.status = 'COMPLETED',
    this.items = const [],
  });

  Map<String, dynamic> toMap();
}

class Sale extends Transaction {
  final int? customerId;
  final String? customerName;
  final String? clientCiNit;
  final double amountPaid;
  final double amountTendered;
  final DateTime? paymentDueDate;

  Sale({
    super.id,
    required super.date,
    required super.totalAmount,
    super.adjustmentAmount,
    super.status,
    super.items,
    this.customerId,
    this.customerName,
    this.clientCiNit,
    this.amountPaid = 0.0,
    this.amountTendered = 0.0,
    this.paymentDueDate,
  }) : super(type: TransactionType.sale);

  double get pendingAmount => totalAmount - amountPaid;
  bool get isFullyPaid => pendingAmount <= 0;
  String get paymentStatus {
    if (amountPaid <= 0) return 'CREDIT';
    if (pendingAmount > 0) return 'PARTIAL';
    return 'COMPLETED';
  }

  Sale copyWith({
    int? id,
    DateTime? date,
    double? totalAmount,
    double? adjustmentAmount,
    String? status,
    List<InvoiceItem>? items,
    int? customerId,
    String? customerName,
    String? clientCiNit,
    double? amountPaid,
    double? amountTendered,
    DateTime? paymentDueDate,
  }) {
    return Sale(
      id: id ?? this.id,
      date: date ?? this.date,
      totalAmount: totalAmount ?? this.totalAmount,
      adjustmentAmount: adjustmentAmount ?? this.adjustmentAmount,
      status: status ?? this.status,
      items: items ?? this.items,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      clientCiNit: clientCiNit ?? this.clientCiNit,
      amountPaid: amountPaid ?? this.amountPaid,
      amountTendered: amountTendered ?? this.amountTendered,
      paymentDueDate: paymentDueDate ?? this.paymentDueDate,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name, // 'sale'
      'entity_id': customerId,
      'entity_name': customerName,
      'client_ci_nit': clientCiNit,
      'date': date.millisecondsSinceEpoch,
      'total_amount': totalAmount,
      'adjustment_amount': adjustmentAmount,
      'amount_paid': amountPaid,
      'amount_tendered': amountTendered,
      'payment_due_date': paymentDueDate?.millisecondsSinceEpoch,
      'status': status,
    };
  }

  factory Sale.fromMap(Map<String, dynamic> map, List<InvoiceItem> items) {
    return Sale(
      id: map['id'],
      date: DateTime.fromMillisecondsSinceEpoch(map['date']),
      totalAmount: map['total_amount'],
      adjustmentAmount: map['adjustment_amount'] != null ? (map['adjustment_amount'] as num).toDouble() : 0.0,
      status: map['status'] ?? 'COMPLETED',
      customerId: map['entity_id'],
      customerName: map['entity_name'],
      clientCiNit: map['client_ci_nit'],
      amountPaid: map['amount_paid'] != null
          ? (map['amount_paid'] as num).toDouble()
          : (map['status'] == 'COMPLETED' ? (map['total_amount'] as num).toDouble() : 0.0),
      amountTendered: map['amount_tendered'] != null
          ? (map['amount_tendered'] as num).toDouble()
          : 0.0,
      paymentDueDate: map['payment_due_date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['payment_due_date'])
          : null,
      items: items,
    );
  }
}

class Purchase extends Transaction {
  final int? supplierId;
  final String? supplierName;
  final String? supplierInvoiceRef;
  final double amountPaid;
  final DateTime? paymentDueDate;

  Purchase({
    super.id,
    required super.date,
    required super.totalAmount,
    super.adjustmentAmount,
    super.status,
    super.items,
    this.supplierId,
    this.supplierName,
    this.supplierInvoiceRef,
    this.amountPaid = 0.0,
    this.paymentDueDate,
  }) : super(type: TransactionType.purchase);

  double get pendingAmount => totalAmount - amountPaid;
  bool get isFullyPaid => pendingAmount <= 0;
  String get paymentStatus {
    if (amountPaid <= 0) return 'CREDIT';
    if (pendingAmount > 0) return 'PARTIAL';
    return 'COMPLETED';
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name, // 'purchase'
      'entity_id': supplierId,
      'entity_name': supplierName, // Storing name directly for simple purchases
      'supplier_invoice_ref': supplierInvoiceRef,
      'date': date.millisecondsSinceEpoch,
      'total_amount': totalAmount,
      'adjustment_amount': adjustmentAmount,
      'amount_paid': amountPaid,
      'payment_due_date': paymentDueDate?.millisecondsSinceEpoch,
      'status': status,
    };
  }

  factory Purchase.fromMap(Map<String, dynamic> map, List<InvoiceItem> items) {
    return Purchase(
      id: map['id'],
      date: DateTime.fromMillisecondsSinceEpoch(map['date']),
      totalAmount: map['total_amount'],
      adjustmentAmount: map['adjustment_amount'] != null ? (map['adjustment_amount'] as num).toDouble() : 0.0,
      status: map['status'] ?? 'COMPLETED',
      supplierId: map['entity_id'],
      supplierName: map['entity_name'],
      supplierInvoiceRef: map['supplier_invoice_ref'],
      amountPaid: map['amount_paid'] != null
          ? (map['amount_paid'] as num).toDouble()
          : (map['status'] == 'COMPLETED' ? (map['total_amount'] as num).toDouble() : 0.0),
      paymentDueDate: map['payment_due_date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['payment_due_date'])
          : null,
      items: items,
    );
  }
}

class Payment extends Transaction {
  final int? customerId;

  Payment({
    super.id,
    required super.date,
    required super.totalAmount,
    super.adjustmentAmount,
    super.status,
    this.customerId,
  }) : super(type: TransactionType.payment);

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name, // 'payment'
      'entity_id': customerId,
      'date': date.millisecondsSinceEpoch,
      'total_amount': totalAmount,
      'adjustment_amount': adjustmentAmount,
      'status': 'COMPLETED',
    };
  }

  factory Payment.fromMap(Map<String, dynamic> map) {
    return Payment(
      id: map['id'],
      date: DateTime.fromMillisecondsSinceEpoch(map['date']),
      totalAmount: map['total_amount'],
      adjustmentAmount: map['adjustment_amount'] != null ? (map['adjustment_amount'] as num).toDouble() : 0.0,
      status: map['status'] ?? 'COMPLETED',
      customerId: map['entity_id'],
    );
  }
}

class Expense extends Transaction {
  final String description;

  Expense({
    super.id,
    required super.date,
    required super.totalAmount,
    super.adjustmentAmount,
    super.status,
    required this.description,
  }) : super(type: TransactionType.expense);

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name, // 'expense'
      'entity_name': description,
      'date': date.millisecondsSinceEpoch,
      'total_amount': totalAmount,
      'adjustment_amount': adjustmentAmount,
      'status': status,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'],
      date: DateTime.fromMillisecondsSinceEpoch(map['date']),
      totalAmount: map['total_amount'],
      adjustmentAmount: map['adjustment_amount'] != null ? (map['adjustment_amount'] as num).toDouble() : 0.0,
      status: map['status'] ?? 'COMPLETED',
      description: map['entity_name'] ?? 'Gasto sin descripción',
    );
  }
}

class Order extends Transaction {
  final int? supplierId;
  final String? supplierName;
  final DateTime? deliveryDate;

  Order({
    super.id,
    required super.date,
    required super.totalAmount,
    super.adjustmentAmount,
    required super.status, // Status is required and dynamic for Orders
    super.items,
    this.supplierId,
    this.supplierName,
    this.deliveryDate,
  }) : super(type: TransactionType.order);

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name, // 'order'
      'entity_id': supplierId,
      'entity_name': supplierName,
      'date': date.millisecondsSinceEpoch,
      'total_amount': totalAmount,
      'adjustment_amount': adjustmentAmount,
      'status': status,
      'payment_due_date': deliveryDate?.millisecondsSinceEpoch,
    };
  }

  factory Order.fromMap(Map<String, dynamic> map, List<InvoiceItem> items) {
    return Order(
      id: map['id'],
      date: DateTime.fromMillisecondsSinceEpoch(map['date']),
      totalAmount: map['total_amount'],
      adjustmentAmount: map['adjustment_amount'] != null ? (map['adjustment_amount'] as num).toDouble() : 0.0,
      status: map['status'] ?? 'PENDING',
      supplierId: map['entity_id'],
      supplierName: map['entity_name'],
      deliveryDate: map['payment_due_date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['payment_due_date'])
          : null,
      items: items,
    );
  }
}
