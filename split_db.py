import os
import re

file_path = r'd:\Documents\Proyectos\Proyectos Antigravity\Proyectos Flutter\proyecto_app_movil_control_de_negocio\lib\services\database_service.dart'
output_dir = r'd:\Documents\Proyectos\Proyectos Antigravity\Proyectos Flutter\proyecto_app_movil_control_de_negocio\lib\services\database'

with open(file_path, 'r', encoding='utf-8') as f:
    text = f.read()

class_start = text.find('class DatabaseService {')
if class_start == -1:
    class_start = text.find('class DatabaseService ')

imports = text[:class_start].strip() + '\n'

body_start = text.find('{', class_start) + 1
body_end = text.rfind('}')
body = text[body_start:body_end]

declarations = []
current_decl = []
for line in body.split('\n'):
    if len(current_decl) == 0 and line.strip() == '': continue
    current_decl.append(line)
    
    if line == '  }' or re.match(r'^  [a-zA-Z].*;$', line):
        declarations.append('\n'.join(current_decl))
        current_decl = []

parsed_decls = []
for d in declarations:
    if d.strip() == '': continue
    
    # determine name based on the FIRST NON-EMPTY LINE ONLY
    name = "UNKNOWN"
    first_line = ""
    for line in d.split('\n'):
        if line.strip() != '' and not line.strip().startswith('//') and not line.strip().startswith('@'):
            first_line = line
            break
            
    if 'DatabaseService._internal' in first_line: name = 'constructor'
    elif 'static final DatabaseService' in first_line: name = 'singleton'
    elif 'factory DatabaseService' in first_line: name = 'factory'
    elif '_database;' in first_line: name = '_database_prop'
    elif '_testDbPath;' in first_line: name = '_testDbPath_prop'
    else:
        # Match only on the first line to avoid matching body code!
        m = re.search(r'\s(?:get\s+)?([a-zA-Z0-9_]+)\s*\(', first_line)
        if m:
            name = m.group(1)
        else:
            m2 = re.search(r'\sget\s+([a-zA-Z0-9_]+)', first_line)
            if m2:
                name = m2.group(1)
            else:
                m3 = re.search(r'\s([a-zA-Z0-9_]+)\s*=>', first_line)
                if m3:
                    name = m3.group(1)
                
    parsed_decls.append({'name': name, 'text': d.strip('\n')})

groups = {
    'core_db_mixin': ['_database_prop', '_testDbPath_prop', 'setTestDbPath', 'database', '_initDatabase', 'exportDatabase'],
    'schema_db_mixin': ['_runMigrations', '_createNotesTable', '_createTables', '_createCategoriesTable', '_createSuppliersTable'],
    'categories_db_mixin': ['insertCategory', 'getCategories', 'updateCategory', 'deleteCategory'],
    'products_db_mixin': ['insertProduct', 'getProducts', 'getProductsByIds', 'updateProduct', 'deleteProduct', 'insertImportedProducts', 'adjustStock'],
    'customers_db_mixin': ['insertCustomer', 'getCustomers', 'updateCustomer', 'deleteCustomer'],
    'suppliers_db_mixin': ['insertSupplier', 'getSuppliers', 'updateSupplier', 'deleteSupplier'],
    'notes_db_mixin': ['insertNote', 'getNotes', 'updateNote', 'deleteNote'],
    'transactions_db_mixin': [
        'getTransactionPayments', 'insertSale', 'deleteSale', 'receiveSalePayment',
        'receiveSupplierPayment', 'receiveGlobalPayment', 'receiveSupplierGlobalPayment',
        'insertPurchase', 'deletePurchase', 'insertOrder', 'getOrders', 'updateOrderStatus', 'deleteOrder',
        'insertExpense', 'deleteExpense', 'insertPayment', 'deletePayment',
        'getTransactions', 'getTransactionById', 'getRecentTransactions', 'getSales', 'getPurchases',
        'getCustomerHistory', 'getSupplierHistory'
    ],
    'reports_db_mixin': [
        'getTodaySummary', 'getWeeklySales', 'getFrequentProductIds',
        'getOverdueSales', 'getPendingSalesCount', 'getAgingReport', 'getEntityLedgers', 'getTransactionsByDateRange'
    ]
}

os.makedirs(output_dir, exist_ok=True)

for mixin_name, methods in groups.items():
    file_path = os.path.join(output_dir, f"{mixin_name}.dart")
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write("part of '../database_service.dart';\n\n")
        class_title = mixin_name.replace('_mixin', '').replace('_', ' ').title().replace(' ', '')
        if mixin_name == 'core_db_mixin':
            f.write(f"mixin {class_title} {{\n")
        else:
            f.write(f"mixin {class_title} on CoreDb {{\n")
            
        for d in parsed_decls:
            if d['name'] in methods:
                f.write("  " + d['text'].strip() + "\n\n")
        f.write("}\n")

# Rewrite database_service.dart
main_file_path = r'd:\Documents\Proyectos\Proyectos Antigravity\Proyectos Flutter\proyecto_app_movil_control_de_negocio\lib\services\database_service.dart'

with open(main_file_path, 'w', encoding='utf-8') as f:
    f.write(imports)
    f.write("\n")
    for mixin_name in groups.keys():
        f.write(f"part 'database/{mixin_name}.dart';\n")
    
    f.write("\n")
    mixin_classes = [m.replace('_mixin', '').replace('_', ' ').title().replace(' ', '') for m in groups.keys()]
    f.write(f"class DatabaseService with {', '.join(mixin_classes)} {{\n")
    
    for d in parsed_decls:
        if d['name'] in ['singleton', 'factory', 'constructor', 'UNKNOWN']:
            if d['name'] == 'UNKNOWN':
                f.write("  // UNMATCHED DECLARATION: " + d['text'].split('\n')[0] + "\n")
            f.write("  " + d['text'].strip() + "\n\n")
            
    f.write("}\n")

print("Done grouping accurately via indentation AND CORRECT NAME PARSING!")
