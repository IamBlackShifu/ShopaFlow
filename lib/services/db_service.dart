import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'shopaflow.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Products table
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        price REAL NOT NULL,
        cost REAL,
        stock_quantity INTEGER NOT NULL DEFAULT 0,
        min_stock_level INTEGER DEFAULT 0,
        barcode TEXT,
        category TEXT,
        sku TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // Sales table
    await db.execute('''
      CREATE TABLE sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        total_amount REAL NOT NULL,
        payment_method TEXT NOT NULL,
        sale_date TEXT NOT NULL,
        receipt_number TEXT NOT NULL,
        created_at TEXT
      )
    ''');

    // Sale items table
    await db.execute('''
      CREATE TABLE sale_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        unit_price REAL NOT NULL,
        total_price REAL NOT NULL,
        FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');

    // Customers table
    await db.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT,
        phone TEXT,
        address TEXT,
        created_at TEXT
      )
    ''');
  }

  // Product methods
  Future<List<Map<String, dynamic>>> getAllProducts() async {
    final db = await database;
    return await db.query('products', orderBy: 'name ASC');
  }

  Future<int> addProduct(Map<String, dynamic> product) async {
    final db = await database;
    product['created_at'] = DateTime.now().toIso8601String();
    product['updated_at'] = DateTime.now().toIso8601String();
    return await db.insert('products', product);
  }

  Future<int> updateProduct(int id, Map<String, dynamic> product) async {
    final db = await database;
    product['updated_at'] = DateTime.now().toIso8601String();
    return await db.update(
      'products',
      product,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteProduct(int id) async {
    final db = await database;
    return await db.delete(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Map<String, dynamic>?> getProductById(int id) async {
    final db = await database;
    final results = await db.query(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  // Sales methods
  Future<int> addSale(Map<String, dynamic> sale, List<Map<String, dynamic>> items) async {
    final db = await database;
    sale['created_at'] = DateTime.now().toIso8601String();
    
    // Start a transaction
    return await db.transaction((txn) async {
      // Insert sale
      final saleId = await txn.insert('sales', sale);
      
      // Insert sale items and update product stock
      for (var item in items) {
        item['sale_id'] = saleId;
        await txn.insert('sale_items', item);
        
        // Update product stock
        final productId = item['product_id'];
        final quantity = item['quantity'];
        await txn.rawUpdate(
          'UPDATE products SET stock_quantity = stock_quantity - ? WHERE id = ?',
          [quantity, productId],
        );
      }
      
      return saleId;
    });
  }

  Future<List<Map<String, dynamic>>> getAllSales() async {
    final db = await database;
    return await db.query('sales', orderBy: 'sale_date DESC');
  }

  Future<List<Map<String, dynamic>>> getSalesByDate(DateTime date) async {
    final db = await database;
    final startOfDay = DateTime(date.year, date.month, date.day).toIso8601String();
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59).toIso8601String();
    
    return await db.query(
      'sales',
      where: 'sale_date >= ? AND sale_date <= ?',
      whereArgs: [startOfDay, endOfDay],
      orderBy: 'sale_date DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getSaleItems(int saleId) async {
    final db = await database;
    return await db.query(
      'sale_items',
      where: 'sale_id = ?',
      whereArgs: [saleId],
    );
  }

  Future<Map<String, dynamic>> getDailySalesSummary(DateTime date) async {
    final db = await database;
    final startOfDay = DateTime(date.year, date.month, date.day).toIso8601String();
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59).toIso8601String();
    
    final result = await db.rawQuery('''
      SELECT 
        COUNT(*) as count,
        COALESCE(SUM(total_amount), 0) as total
      FROM sales
      WHERE sale_date >= ? AND sale_date <= ?
    ''', [startOfDay, endOfDay]);
    
    return {
      'count': result.first['count'] ?? 0,
      'total': result.first['total'] ?? 0.0,
    };
  }

  // Customer methods
  Future<List<Map<String, dynamic>>> getAllCustomers() async {
    final db = await database;
    return await db.query('customers', orderBy: 'name ASC');
  }

  Future<int> addCustomer(Map<String, dynamic> customer) async {
    final db = await database;
    customer['created_at'] = DateTime.now().toIso8601String();
    return await db.insert('customers', customer);
  }

  Future<int> updateCustomer(int id, Map<String, dynamic> customer) async {
    final db = await database;
    return await db.update(
      'customers',
      customer,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteCustomer(int id) async {
    final db = await database;
    return await db.delete(
      'customers',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Export/Import methods
  Future<Map<String, dynamic>> exportData() async {
    final db = await database;
    
    final products = await db.query('products');
    final sales = await db.query('sales');
    final saleItems = await db.query('sale_items');
    final customers = await db.query('customers');
    
    return {
      'products': products,
      'sales': sales,
      'sale_items': saleItems,
      'customers': customers,
      'exported_at': DateTime.now().toIso8601String(),
    };
  }

  Future<void> importData(Map<String, dynamic> data) async {
    final db = await database;
    
    await db.transaction((txn) async {
      // Clear existing data
      await txn.delete('sale_items');
      await txn.delete('sales');
      await txn.delete('products');
      await txn.delete('customers');
      
      // Import products
      if (data['products'] != null) {
        for (var product in data['products']) {
          await txn.insert('products', product);
        }
      }
      
      // Import customers
      if (data['customers'] != null) {
        for (var customer in data['customers']) {
          await txn.insert('customers', customer);
        }
      }
      
      // Import sales
      if (data['sales'] != null) {
        for (var sale in data['sales']) {
          await txn.insert('sales', sale);
        }
      }
      
      // Import sale items
      if (data['sale_items'] != null) {
        for (var item in data['sale_items']) {
          await txn.insert('sale_items', item);
        }
      }
    });
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('sale_items');
      await txn.delete('sales');
      await txn.delete('products');
      await txn.delete('customers');
    });
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
