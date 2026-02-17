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

  Sale({
    super.id,
    required super.date,
    required super.totalAmount,
    super.status,
    super.items,
    this.customerId,
    this.customerName,
  }) : super(type: TransactionType.sale);

  Sale copyWith({
    int? id,
    DateTime? date,
    double? totalAmount,
    String? status,
    List<InvoiceItem>? items,
    int? customerId,
    String? customerName,
  }) {
    return Sale(
      id: id ?? this.id,
      date: date ?? this.date,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      items: items ?? this.items,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
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
      'status': status,
    };
  }

  factory Sale.fromMap(Map<String, dynamic> map, List<InvoiceItem> items) {
    return Sale(
      id: map['id'],
      date: DateTime.fromMillisecondsSinceEpoch(map['date']),
      totalAmount: map['total_amount'],
      status: map['status'],
      customerId: map['entity_id'],
      customerName: map['entity_name'],
      items: items,
    );
  }
}

class Purchase extends Transaction {
  final String? supplierName;

  Purchase({
    super.id,
    required super.date,
    required super.totalAmount,
    super.status,
    super.items,
    this.supplierName,
  }) : super(type: TransactionType.purchase);

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name, // 'purchase'
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
      status: map['status'],
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
      status: map['status'],
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
      status: map['status'],
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
