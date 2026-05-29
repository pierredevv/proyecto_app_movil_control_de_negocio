class CashRegister {
  final int? id;
  final int? userId;
  final DateTime openDate;
  final DateTime? closeDate;
  final double openingBalance;
  final double? closingBalance;
  final double? expectedBalance;
  final double? difference;
  final String status; // 'OPEN' or 'CLOSED'
  final String? notes;

  CashRegister({
    this.id,
    this.userId,
    required this.openDate,
    this.closeDate,
    required this.openingBalance,
    this.closingBalance,
    this.expectedBalance,
    this.difference,
    this.status = 'OPEN',
    this.notes,
  });

  factory CashRegister.fromMap(Map<String, dynamic> map) {
    return CashRegister(
      id: map['id'] as int?,
      userId: map['user_id'] as int?,
      openDate: DateTime.fromMillisecondsSinceEpoch(map['open_date'] as int),
      closeDate: map['close_date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['close_date'] as int)
          : null,
      openingBalance: (map['opening_balance'] as num).toDouble(),
      closingBalance: map['closing_balance'] != null
          ? (map['closing_balance'] as num).toDouble()
          : null,
      expectedBalance: map['expected_balance'] != null
          ? (map['expected_balance'] as num).toDouble()
          : null,
      difference: map['difference'] != null
          ? (map['difference'] as num).toDouble()
          : null,
      status: (map['status'] as String?) ?? 'OPEN',
      notes: map['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'open_date': openDate.millisecondsSinceEpoch,
      'close_date': closeDate?.millisecondsSinceEpoch,
      'opening_balance': openingBalance,
      'closing_balance': closingBalance,
      'expected_balance': expectedBalance,
      'difference': difference,
      'status': status,
      'notes': notes,
    };
  }

  CashRegister copyWith({
    int? id,
    int? userId,
    DateTime? openDate,
    DateTime? closeDate,
    double? openingBalance,
    double? closingBalance,
    double? expectedBalance,
    double? difference,
    String? status,
    String? notes,
  }) {
    return CashRegister(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      openDate: openDate ?? this.openDate,
      closeDate: closeDate ?? this.closeDate,
      openingBalance: openingBalance ?? this.openingBalance,
      closingBalance: closingBalance ?? this.closingBalance,
      expectedBalance: expectedBalance ?? this.expectedBalance,
      difference: difference ?? this.difference,
      status: status ?? this.status,
      notes: notes ?? this.notes,
    );
  }
}
