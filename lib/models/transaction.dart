class Transaction {
  final String id;
  final String entityName; // Customer or Supplier name
  final String type; // 'Venta', 'Compra', 'Gasto'
  final DateTime date;
  final double totalAmount;
  final double balance; // Amount pending

  Transaction({
    required this.id,
    required this.entityName,
    required this.type,
    required this.date,
    required this.totalAmount,
    required this.balance,
  });
}
