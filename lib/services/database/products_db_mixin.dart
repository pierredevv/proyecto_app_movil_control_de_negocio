part of '../database_service.dart';

mixin ProductsDb on CoreDb {
  // ---------------------------------------------------------------------------
  // PRODUCT OPERATIONS
  // ---------------------------------------------------------------------------
  Future<int> insertProduct(Product product) async {
    final db = await database;
    final map = product.toMap();
    if (map['weighted_average_cost'] == null ||
        map['weighted_average_cost'] == 0.0) {
      final double unitsPerBox =
          (map['units_per_box'] as num?)?.toDouble() ?? 1.0;
      final cost = (map['cost'] as num?)?.toDouble() ?? 0.0;
      map['weighted_average_cost'] =
          cost / (unitsPerBox > 0 ? unitsPerBox : 1.0);
    }
    final id = await db.insert('products', map);
    if (product.stock > 0) {
      await db.insert('inventory_movements', {
        'product_id': id,
        'movement_type': 'INITIAL_STOCK',
        'quantity': product.stock,
        'unit_cost_at_movement': product.cost,
        'created_timestamp': DateTime.now().millisecondsSinceEpoch
      });
    }
    return id;
  }

  Future<List<Product>> getProducts({
    String? searchQuery,
    List<int>? categoryIds,
    List<String>? stockStatuses, // 'sufficient', 'moderate', 'critical'
    double? minPrice,
    double? maxPrice,
    double? minStock,
    double? maxStock,
    String sortColumn = 'name',
    bool sortAscending = true,
    int? limit,
    int? offset,
  }) async {
    final db = await database;

    String whereClause = 'is_active = 1';
    List<dynamic> args = [];

    // 1. Search
    if (searchQuery != null && searchQuery.isNotEmpty) {
      whereClause += ' AND (name LIKE ? OR barcode LIKE ?)';
      args.add('%$searchQuery%');
      args.add('%$searchQuery%');
    }

    // 2. Categories
    if (categoryIds != null && categoryIds.isNotEmpty) {
      final placeholders = List.filled(categoryIds.length, '?').join(',');
      whereClause += ' AND category_id IN ($placeholders)';
      args.addAll(categoryIds);
    }

    // 3. Stock Status
    // Logic must match Provider: Critical (<3), Moderate (3-10), Sufficient (>10)
    if (stockStatuses != null && stockStatuses.isNotEmpty) {
      List<String> statusClauses = [];
      for (var status in stockStatuses) {
        if (status == 'critical') {
          statusClauses
              .add('(min_stock > 0 AND stock / units_per_box <= min_stock)');
        } else if (status == 'moderate') {
          statusClauses.add(
              '(min_stock > 0 AND stock / units_per_box > min_stock AND stock / units_per_box <= min_stock * 2)');
        } else if (status == 'sufficient') {
          statusClauses
              .add('(min_stock = 0 OR stock / units_per_box > min_stock * 2)');
        }
      }
      if (statusClauses.isNotEmpty) {
        whereClause += ' AND (${statusClauses.join(' OR ')})';
      }
    }

    // 4. Price Range
    if (minPrice != null) {
      whereClause += ' AND price >= ?';
      args.add(minPrice);
    }
    if (maxPrice != null) {
      whereClause += ' AND price <= ?';
      args.add(maxPrice);
    }

    // 5. Stock Range
    if (minStock != null) {
      whereClause += ' AND stock >= ?';
      args.add(minStock);
    }
    if (maxStock != null) {
      whereClause += ' AND stock <= ?';
      args.add(maxStock);
    }

    // 6. Sorting — whitelist to prevent SQL injection via sortColumn
    const allowedSortColumns = {
      'name', 'price', 'cost', 'stock', 'category_id',
      'created_at', 'updated_at', 'barcode', 'weighted_average_cost',
    };
    final safeSortColumn = allowedSortColumns.contains(sortColumn)
        ? sortColumn
        : 'name';
    String orderBy = '$safeSortColumn ${sortAscending ? 'ASC' : 'DESC'}';

    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: whereClause,
      whereArgs: args,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
    return List.generate(maps.length, (i) => Product.fromMap(maps[i]));
  }

  Future<List<Product>> getProductsByIds(List<int> ids) async {
    if (ids.isEmpty) return [];
    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(',');
    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
    return List.generate(maps.length, (i) => Product.fromMap(maps[i]));
  }

  Future<int> updateProduct(Product product) async {
    final db = await database;

    return await db.transaction((txn) async {
      // Query old stock to detect changes
      final oldRecord = await txn.query('products',
          columns: ['stock'], where: 'id = ?', whereArgs: [product.id]);
      double oldStock = oldRecord.isNotEmpty
          ? (oldRecord.first['stock'] as num).toDouble()
          : 0.0;

      final map = product.toMap();
      if ((map['weighted_average_cost'] as double?) == 0.0) {
        final double unitsPerBox =
            (map['units_per_box'] as num?)?.toDouble() ?? 1.0;
        final cost = (map['cost'] as num?)?.toDouble() ?? 0.0;
        map['weighted_average_cost'] =
            cost / (unitsPerBox > 0 ? unitsPerBox : 1.0);
      }

      final result = await txn.update(
        'products',
        map,
        where: 'id = ?',
        whereArgs: [product.id],
      );

      if (product.id != null && oldStock != product.stock) {
        final diff = product.stock - oldStock;
        await txn.insert('inventory_movements', {
          'product_id': product.id,
          'movement_type': 'INVENTORY_ADJUSTMENT',
          'quantity': diff,
          'reference_type': 'MANUAL_EDIT',
          'reference_id': product.id,
          'unit_cost_at_movement': product.cost,
          'created_timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      }
      return result;
    });
  }

  Future<int> deleteProduct(int id) async {
    final db = await database;
    return await db.update(
      'products',
      {'is_active': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ---------------------------------------------------------------------------
  // IMPORT OPERATIONS
  // ---------------------------------------------------------------------------
  Future<Map<String, int>> insertImportedProducts(
      List<ProductImportRow> rows) async {
    final db = await database;
    int insertedCount = 0;
    int updatedCount = 0;
    int errorCount = 0;

    await db.transaction((txn) async {
      for (final row in rows) {
        try {
          // 1. Resolve Category ID
          int? categoryId;
          final catQuery = row.category.trim();
          if (catQuery.isNotEmpty) {
            final existingCat = await txn.query(
              'categories',
              where: 'name LIKE ?',
              whereArgs: [catQuery],
              limit: 1,
            );

            if (existingCat.isNotEmpty) {
              categoryId = existingCat.first['id'] as int;
            } else {
              categoryId = await txn.insert('categories', {
                'name': catQuery,
              });
            }
          }

          // 2. Check Barcode Collision
          final bcQuery = row.barcode.trim();
          bool exists = false;
          int? existingId;

          if (bcQuery.isNotEmpty) {
            final existingProd = await txn.query(
              'products',
              where: 'barcode = ?',
              whereArgs: [bcQuery],
              limit: 1,
            );
            if (existingProd.isNotEmpty) {
              exists = true;
              existingId = existingProd.first['id'] as int;
            }
          }

          if (exists && existingId != null) {
            // Update existing product stock
            final existingItem = await txn.query('products',
                where: 'id = ?', whereArgs: [existingId], limit: 1);
            final currentStock =
                (existingItem.first['stock'] as num).toDouble();

            final oldWac = (existingItem.first['weighted_average_cost'] as num?)
                    ?.toDouble() ??
                0.0;
            final newTotalStock = currentStock + row.stockBase;
            final newCost = row.cost > 0
                ? row.cost
                : (existingItem.first['cost'] as num).toDouble();
            final costPerBaseUnit = row.unitsPerSaleUnit > 0
                ? (newCost / row.unitsPerSaleUnit)
                : newCost;
            final newWac = newTotalStock > 0
                ? ((currentStock * oldWac) +
                        (row.stockBase * costPerBaseUnit)) /
                    newTotalStock
                : 0.0;

            await txn.update(
              'products',
              {
                'stock': newTotalStock,
                'price':
                    row.price > 0 ? row.price : existingItem.first['price'],
                'cost': newCost,
                'weighted_average_cost': newWac,
                'is_active': 1,
              },
              where: 'id = ?',
              whereArgs: [existingId],
            );

            await txn.insert('inventory_movements', {
              'product_id': existingId,
              'movement_type': 'INVENTORY_ADJUSTMENT',
              'quantity': row.stockBase,
              'reference_type': 'IMPORT',
              'unit_cost_at_movement': costPerBaseUnit,
              'created_timestamp': DateTime.now().millisecondsSinceEpoch,
            });

            updatedCount++;
          } else {
            // Insert new product
            final costPerBaseUnitNew = row.unitsPerSaleUnit > 0
                ? (row.cost / row.unitsPerSaleUnit)
                : row.cost;
            await txn.insert('products', {
              'name': row.name,
              'barcode': row.barcode,
              'price': row.price,
              'cost': row.cost,
              'weighted_average_cost': costPerBaseUnitNew,
              'stock': row.stockBase, // Always in base units
              'min_stock': 0,
              'category_id': categoryId,
              'supplier_id': null,
              'unit_type': row.saleUnit,
              'units_per_box': row.unitsPerSaleUnit,
              'packaging_info': row.packagingInfo,
              'created_at': DateTime.now().millisecondsSinceEpoch,
              'image_path': null,
              'is_active': 1,
            });
            insertedCount++;
          }
        } catch (e) {
          debugPrint('Error inserting row ${row.name}: $e');
          errorCount++;
        }
      }
    });

    return {
      'inserted': insertedCount,
      'updated': updatedCount,
      'errors': errorCount,
    };
  }

  // ---------------------------------------------------------------------------
  // INVENTORY ADJUSTMENT HELPER
  // ---------------------------------------------------------------------------
  Future<void> adjustStock(
    int productId,
    double deltaBaseUnits,
    String reason, {
    String? note,
    double? unitCost, // UX #6: optional cost to recalculate WAC on entry adjustments
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query('products',
          columns: ['stock', 'weighted_average_cost'], where: 'id = ?', whereArgs: [productId]);
      if (rows.isEmpty) throw Exception('Product not found: $productId');
      final currentStock = (rows.first['stock'] as num).toDouble();
      final oldWac = (rows.first['weighted_average_cost'] as num?)?.toDouble() ?? 0.0;
      final newStock = currentStock + deltaBaseUnits;
      if (newStock < -0.001) {
        throw Exception(
            'El ajuste resultaría en stock negativo (${newStock.toStringAsFixed(2)} u.b.)');
      }

      // UX #6: Recalculate WAC if unit cost is provided for an entry adjustment
      double newWac = oldWac;
      if (unitCost != null && unitCost > 0 && deltaBaseUnits > 0) {
        final totalStock = newStock > 0 ? newStock : 1.0;
        newWac = ((currentStock * oldWac) + (deltaBaseUnits * unitCost)) / totalStock;
      }

      await txn.rawUpdate(
          'UPDATE products SET stock = ?, weighted_average_cost = ? WHERE id = ?',
          [newStock < 0 ? 0.0 : newStock, newWac, productId]);
      await txn.insert('inventory_movements', {
        'product_id': productId,
        'movement_type': 'INVENTORY_ADJUSTMENT',
        'quantity': deltaBaseUnits,
        'reference_type': reason,
        'reference_id': null,
        'unit_cost_at_movement': unitCost ?? newWac,
        'created_timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    });
  }
}
