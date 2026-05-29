import 'package:flutter/foundation.dart' hide Category;
import 'package:sqflite/sqflite.dart' hide Transaction;
import 'package:path/path.dart';
import '../models/product.dart';
import '../models/customer.dart';
import '../models/transaction_model.dart';
import '../models/invoice_item.dart';
import '../models/category.dart';
import '../models/supplier.dart';
import '../models/note.dart';
import '../models/import_result.dart'; // Added for ImportResult
import '../models/cash_register.dart'; // Added for CashRegister
import '../models/expense_category.dart'; // Added for ExpenseCategory
import '../models/app_notification.dart'; // Added for AppNotification

part 'database/core_db_mixin.dart';
part 'database/schema_db_mixin.dart';
part 'database/categories_db_mixin.dart';
part 'database/products_db_mixin.dart';
part 'database/customers_db_mixin.dart';
part 'database/suppliers_db_mixin.dart';
part 'database/notes_db_mixin.dart';
part 'database/transactions_db_mixin.dart';
part 'database/reports_db_mixin.dart';
part 'database/cash_register_db_mixin.dart'; // Added cash_register mixin
part 'database/notifications_db_mixin.dart'; // Added notifications mixin

class DatabaseService
    with
        CoreDb,
        SchemaDb,
        CategoriesDb,
        ProductsDb,
        CustomersDb,
        SuppliersDb,
        NotesDb,
        TransactionsDb,
        ReportsDb,
        CashRegisterDb,
        NotificationsDb {
  static final DatabaseService _instance = DatabaseService._internal();

  factory DatabaseService() => _instance;

  DatabaseService._internal();

  // UNMATCHED DECLARATION:   /// Constructor for mocking in tests
  /// Constructor for mocking in tests
  @visibleForTesting
  DatabaseService.forTesting();
}
