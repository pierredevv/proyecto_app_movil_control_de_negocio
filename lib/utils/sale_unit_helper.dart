import '../models/product.dart';
import '../models/sale_unit_option.dart';

class SaleUnitHelper {
  static List<SaleUnitOption> getOptionsForProduct(Product product) {
    final options = <SaleUnitOption>[];

    // Main option (how the product is configured)
    options.add(SaleUnitOption(
      label: _labelForUnit(product.saleUnit, product.packagingInfo),
      unitCode: product.saleUnit,
      unitsPerSaleUnit: product.unitsPerSaleUnit,
      price: product.price,
    ));

    // If the product is sold in boxes/bags, also offer per unit
    if (product.unitsPerSaleUnit > 1) {
      final pricePerUnit = product.price / product.unitsPerSaleUnit;
      options.add(SaleUnitOption(
        label: 'Unidad Suelta',
        unitCode: 'UNI',
        unitsPerSaleUnit: 1.0,
        price: pricePerUnit,
      ));
    }

    return options;
  }

  static String _labelForUnit(String unit, String packagingInfo) {
    final info = packagingInfo.isNotEmpty ? ' ($packagingInfo)' : '';
    switch (unit) {
      case 'CAJ':
        return 'Caja$info';
      case 'BOL':
        return 'Bolsa$info';
      case 'TIR':
        return 'Tira$info';
      default:
        return 'Unidad';
    }
  }
}
