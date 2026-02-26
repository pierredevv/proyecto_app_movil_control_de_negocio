class SaleUnitOption {
  final String label; // "Caja (18X250)", "Bolsa suelta", "Unidad"
  final String unitCode; // "CAJ", "BOL", "UNI", "KG"
  final double unitsPerSaleUnit; // 18 para CAJ de 18, 1 para UNI
  final double price; // precio en esta presentación

  const SaleUnitOption({
    required this.label,
    required this.unitCode,
    required this.unitsPerSaleUnit,
    required this.price,
  });

  // Precio por unidad base calculado
  double get pricePerBaseUnit {
    if (unitsPerSaleUnit <= 0) return price;
    return price / unitsPerSaleUnit;
  }

  @override
  String toString() => "$label ($unitCode) — $unitsPerSaleUnit u. — Bs. $price";
}
