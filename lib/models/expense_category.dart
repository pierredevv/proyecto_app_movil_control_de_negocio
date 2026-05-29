class ExpenseCategory {
  final int? id;
  final String name;
  final String icon;
  final String color;

  ExpenseCategory({
    this.id,
    required this.name,
    this.icon = 'category',
    this.color = '0xFF6B7494',
  });

  factory ExpenseCategory.fromMap(Map<String, dynamic> map) {
    return ExpenseCategory(
      id: map['id'] as int?,
      name: map['name'] as String,
      icon: (map['icon'] as String?) ?? 'category',
      color: (map['color'] as String?) ?? '0xFF6B7494',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'color': color,
    };
  }
}
