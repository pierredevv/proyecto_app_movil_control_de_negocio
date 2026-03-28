class Supplier {
  final int? id;
  final String name;
  final String? phone;
  final String? email;
  final String? category;
  final String? address;
  final double totalDebt;
  final DateTime createdAt;

  Supplier({
    this.id,
    required this.name,
    this.phone,
    this.email,
    this.category,
    this.address,
    this.totalDebt = 0.0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Supplier copyWith({
    int? id,
    String? name,
    String? phone,
    String? email,
    String? category,
    String? address,
    double? totalDebt,
    DateTime? createdAt,
  }) {
    return Supplier(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      category: category ?? this.category,
      address: address ?? this.address,
      totalDebt: totalDebt ?? this.totalDebt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'category': category,
      'address': address,
      // We don't save totalDebt to the suppliers table, it's computed
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory Supplier.fromMap(Map<String, dynamic> map) {
    return Supplier(
      id: map['id'],
      name: map['name'],
      phone: map['phone'],
      email: map['email'],
      category: map['category'],
      address: map['address'],
      totalDebt: (map['total_debt'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
    );
  }
}
