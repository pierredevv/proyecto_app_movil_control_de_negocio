import 'invoice_item.dart';

enum TransactionType { sale, purchase, expense, payment, order }

abstract class Transaction {
  final int? id;
  final TransactionType type;
  final DateTime date;
  final double totalAmount;
  final String status;
  final List<InvoiceItem> items;

  Transaction({
    this.id,
    required this.type,
    required this.date,
    required this.totalAmount,
    this.status = 'COMPLETED',
    this.items = const [],
  });

  Map<String, dynamic> toMap();
}

class Sale extends Transaction {
  final int? customerId;
  final String? customerName;
  final double amountPaid;
  final DateTime? paymentDueDate;

  Sale({
    super.id,
    required super.date,
    required super.totalAmount,
    super.status,
    super.items,
    this.customerId,
    this.customerName,
    this.amountPaid = 0.0,
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
    String? status,
    List<InvoiceItem>? items,
    int? customerId,
    String? customerName,
    double? amountPaid,
    DateTime? paymentDueDate,
  }) {
    return Sale(
      id: id ?? this.id,
      date: date ?? this.date,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      items: items ?? this.items,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      amountPaid: amountPaid ?? this.amountPaid,
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
      'date': date.millisecondsSinceEpoch,
      'total_amount': totalAmount,
      'amount_paid': amountPaid,
      'payment_due_date': paymentDueDate?.millisecondsSinceEpoch,
      'status': status,
    };
  }

  factory Sale.fromMap(Map<String, dynamic> map, List<InvoiceItem> items) {
    return Sale(
      id: map['id'],
      date: DateTime.fromMillisecondsSinceEpoch(map['date']),
      totalAmount: map['total_amount'],
      status: map['status'] ?? 'COMPLETED',
      customerId: map['entity_id'],
      customerName: map['entity_name'],
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

class Purchase extends Transaction {
  final int? supplierId;
  final String? supplierName;

  Purchase({
    super.id,
    required super.date,
    required super.totalAmount,
    super.status,
    super.items,
    this.supplierId,
    this.supplierName,
  }) : super(type: TransactionType.purchase);

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name, // 'purchase'
      'entity_id': supplierId,
      'entity_name': supplierName, // Storing name directly for simple purchases
      'date': date.millisecondsSinceEpoch,
      'total_amount': totalAmount,
      'status': status,
    };
  }

  factory Purchase.fromMap(Map<String, dynamic> map, List<InvoiceItem> items) {
    return Purchase(
      id: map['id'],
      date: DateTime.fromMillisecondsSinceEpoch(map['date']),
      totalAmount: map['total_amount'],
      status: map['status'] ?? 'COMPLETED',
      supplierId: map['entity_id'],
      supplierName: map['entity_name'],
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
      'status': 'COMPLETED',
    };
  }

  factory Payment.fromMap(Map<String, dynamic> map) {
    return Payment(
      id: map['id'],
      date: DateTime.fromMillisecondsSinceEpoch(map['date']),
      totalAmount: map['total_amount'],
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
      'status': status,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'],
      date: DateTime.fromMillisecondsSinceEpoch(map['date']),
      totalAmount: map['total_amount'],
      status: map['status'] ?? 'COMPLETED',
      description: map['entity_name'] ?? 'Gasto sin descripción',
    );
  }
}

class Order extends Transaction {
  final String? supplierName;
  final DateTime? deliveryDate;

  Order({
    super.id,
    required super.date,
    required super.totalAmount,
    required super.status, // Status is required and dynamic for Orders
    super.items,
    this.supplierName,
    this.deliveryDate,
  }) : super(type: TransactionType.order);

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name, // 'order'
      'entity_name': supplierName,
      'date': date.millisecondsSinceEpoch,
      'total_amount': totalAmount,
      'status': status,
      // We might need to store deliveryDate in a generic field or new column if needed
      // For now, let's skip persisting deliveryDate unless we add a column.
    };
  }

  factory Order.fromMap(Map<String, dynamic> map, List<InvoiceItem> items) {
    return Order(
      id: map['id'],
      date: DateTime.fromMillisecondsSinceEpoch(map['date']),
      totalAmount: map['total_amount'],
      status: map['status'] ?? 'PENDING',
      supplierName: map['entity_name'],
      items: items,
    );
  }
}
