import 'dart:async';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Database service for local SQLite storage
/// Handles CRUD operations for products, sales, and transactions
class DatabaseService {
  static const String _databaseName = 'shopaflow.db';
  static const int _databaseVersion = 1;

  static Database? _database;

  /// Singleton instance
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  /// Get database instance
  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  /// Initialize the database
  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, _databaseName);
    
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Create database tables
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
        min_stock_level INTEGER DEFAULT 5,
        barcode TEXT UNIQUE,
        category TEXT,
        sku TEXT UNIQUE,
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0
      )
    ''');

    // Sales table
    await db.execute('''
      CREATE TABLE sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        total_amount REAL NOT NULL,
        tax_amount REAL DEFAULT 0,
        discount_amount REAL DEFAULT 0,
        payment_method TEXT NOT NULL,
        payment_status TEXT DEFAULT 'completed',
        customer_id INTEGER,
        employee_id INTEGER,
        receipt_number TEXT UNIQUE,
        notes TEXT,
        sale_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0
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
        discount_amount REAL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');

    // Customers table (for Phase 3)
    await db.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT,
        phone TEXT,
        address TEXT,
        loyalty_points INTEGER DEFAULT 0,
        total_spent REAL DEFAULT 0,
        last_visit TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0
      )
    ''');

    // Sync queue table
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        record_id INTEGER NOT NULL,
        operation TEXT NOT NULL,
        data TEXT,
        created_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0
      )
    ''');

    // Insert sample data for development
    // await _insertSampleData(db);
  }

  /// Handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database schema upgrades in future versions
    if (oldVersion < 2) {
      // Add new columns or tables for version 2
    }
  }

  
  // PRODUCTS CRUD OPERATIONS

  /// Get all products
  Future<List<Map<String, dynamic>>> getAllProducts() async {
    final db = await database;
    return await db.query('products', where: 'is_active = ?', whereArgs: [1]);
  }

  /// Get product by ID
  Future<Map<String, dynamic>?> getProductById(int id) async {
    final db = await database;
    final results = await db.query('products', where: 'id = ?', whereArgs: [id]);
    return results.isNotEmpty ? results.first : null;
  }

  /// Get product by barcode
  Future<Map<String, dynamic>?> getProductByBarcode(String barcode) async {
    final db = await database;
    final results = await db.query('products', where: 'barcode = ?', whereArgs: [barcode]);
    return results.isNotEmpty ? results.first : null;
  }

  /// Search products
  Future<List<Map<String, dynamic>>> searchProducts(String query) async {
    final db = await database;
    return await db.query(
      'products',
      where: 'is_active = ? AND (name LIKE ? OR category LIKE ? OR barcode LIKE ?)',
      whereArgs: [1, '%$query%', '%$query%', '%$query%'],
      orderBy: 'name ASC',
    );
  }

  /// Add new product
  Future<int> addProduct(Map<String, dynamic> product) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    
    return await db.insert('products', {
      ...product,
      'created_at': now,
      'updated_at': now,
    });
  }

  /// Update product
  Future<int> updateProduct(int id, Map<String, dynamic> product) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    
    return await db.update(
      'products',
      {
        ...product,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete product (soft delete)
  Future<int> deleteProduct(int id) async {
    final db = await database;
    return await db.update(
      'products',
      {'is_active': 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Update product stock
  Future<int> updateProductStock(int productId, int newStock) async {
    final db = await database;
    return await db.update(
      'products',
      {
        'stock_quantity': newStock,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [productId],
    );
  }

  /// Get low stock products
  Future<List<Map<String, dynamic>>> getLowStockProducts() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT * FROM products 
      WHERE is_active = 1 AND stock_quantity <= min_stock_level
      ORDER BY stock_quantity ASC
    ''');
  }

  /// Get products by category
  Future<List<Map<String, dynamic>>> getProductsByCategory(String category) async {
    final db = await database;
    return await db.query(
      'products',
      where: 'is_active = ? AND category = ?',
      whereArgs: [1, category],
      orderBy: 'name ASC',
    );
  }

  // SALES CRUD OPERATIONS

  /// Add new sale
  Future<int> addSale(Map<String, dynamic> sale, List<Map<String, dynamic>> items) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    
    // Start transaction
    return await db.transaction((txn) async {
      // Insert sale record
      final saleId = await txn.insert('sales', {
        ...sale,
        'created_at': now,
      });

      // Insert sale items
      for (var item in items) {
        await txn.insert('sale_items', {
          'sale_id': saleId,
          ...item,
          'created_at': now,
        });

        // Update product stock
        await txn.rawUpdate('''
          UPDATE products 
          SET stock_quantity = stock_quantity - ?
          WHERE id = ?
        ''', [item['quantity'], item['product_id']]);
      }

      return saleId;
    });
  }

  /// Get sales for a specific date
  Future<List<Map<String, dynamic>>> getSalesByDate(DateTime date) async {
    final db = await database;
    final dateStr = date.toIso8601String().substring(0, 10);

    return await db.query(
      'sales',
      where: 'DATE(sale_date) = ?',
      whereArgs: [dateStr],
      orderBy: 'created_at DESC',
    );
  }

  /// Get sales between dates
  Future<List<Map<String, dynamic>>> getSalesBetweenDates(DateTime startDate, DateTime endDate) async {
    final db = await database;
    final startStr = startDate.toIso8601String().substring(0, 10);
    final endStr = endDate.toIso8601String().substring(0, 10);

    return await db.query(
      'sales',
      where: 'DATE(sale_date) BETWEEN ? AND ?',
      whereArgs: [startStr, endStr],
      orderBy: 'created_at DESC',
    );
  }

  /// Get sale items for a sale
  Future<List<Map<String, dynamic>>> getSaleItems(int saleId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT si.*, p.name as product_name, p.category
      FROM sale_items si
      JOIN products p ON si.product_id = p.id
      WHERE si.sale_id = ?
      ORDER BY si.id
    ''', [saleId]);
  }

  /// Get all sales
  Future<List<Map<String, dynamic>>> getAllSales() async {
    final db = await database;
    return await db.query('sales', orderBy: 'created_at DESC');
  }

  /// Get daily sales summary
  Future<Map<String, dynamic>> getDailySalesSummary([DateTime? date]) async {
    final db = await database;
    final targetDate = date ?? DateTime.now();
    final dateStr = targetDate.toIso8601String().substring(0, 10);

    final result = await db.rawQuery('''
      SELECT 
        COUNT(*) as transaction_count,
        SUM(total_amount) as total_sales,
        SUM(tax_amount) as total_tax,
        SUM(discount_amount) as total_discount,
        AVG(total_amount) as average_sale
      FROM sales 
      WHERE DATE(sale_date) = ?
    ''', [dateStr]);

    return result.isNotEmpty ? result.first : {
      'transaction_count': 0,
      'total_sales': 0.0,
      'total_tax': 0.0,
      'total_discount': 0.0,
      'average_sale': 0.0,
    };
  }

  /// Get payment method breakdown
  Future<List<Map<String, dynamic>>> getPaymentMethodBreakdown([DateTime? date]) async {
    final db = await database;
    final targetDate = date ?? DateTime.now();
    final dateStr = targetDate.toIso8601String().substring(0, 10);

    return await db.rawQuery('''
      SELECT 
        payment_method,
        COUNT(*) as count,
        SUM(total_amount) as total
      FROM sales 
      WHERE DATE(sale_date) = ?
      GROUP BY payment_method
      ORDER BY total DESC
    ''', [dateStr]);
  }

  /// Get top selling products
  Future<List<Map<String, dynamic>>> getTopSellingProducts([DateTime? date, int limit = 10]) async {
    final db = await database;
    final targetDate = date ?? DateTime.now();
    final dateStr = targetDate.toIso8601String().substring(0, 10);

    return await db.rawQuery('''
      SELECT 
        p.id,
        p.name,
        p.category,
        SUM(si.quantity) as total_quantity,
        SUM(si.total_price) as total_revenue
      FROM sale_items si
      JOIN sales s ON si.sale_id = s.id
      JOIN products p ON si.product_id = p.id
      WHERE DATE(s.sale_date) = ?
      GROUP BY p.id, p.name, p.category
      ORDER BY total_quantity DESC
      LIMIT ?
    ''', [dateStr, limit]);
  }

  // SYNC OPERATIONS

  /// Add operation to sync queue
  Future<void> _addToSyncQueue(
    String tableName,
    int recordId,
    String operation,
    Map<String, dynamic> data,
  ) async {
    final db = await database;
    await db.insert('sync_queue', {
      'table_name': tableName,
      'record_id': recordId,
      'operation': operation,
      'data': data.toString(), // JSON encode in production
      'created_at': DateTime.now().toIso8601String(),
      'synced': 0,
    });
  }

  /// Get unsynced records
  Future<List<Map<String, dynamic>>> getUnsyncedRecords() async {
    final db = await database;
    return await db.query(
      'sync_queue',
      where: 'synced = ?',
      whereArgs: [0],
      orderBy: 'created_at ASC',
    );
  }

  /// Mark record as synced
  Future<void> markAsSynced(int syncQueueId) async {
    final db = await database;
    await db.update(
      'sync_queue',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [syncQueueId],
    );
  }

  // UTILITY METHODS

  /// Get database stats
  Future<Map<String, int>> getDatabaseStats() async {
    final db = await database;
    
    final productCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM products WHERE is_active = 1'),
    ) ?? 0;
    
    final salesCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM sales'),
    ) ?? 0;
    
    final customerCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM customers'),
    ) ?? 0;
    
    final unsyncedCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM sync_queue WHERE synced = 0'),
    ) ?? 0;
    
    return {
      'products': productCount,
      'sales': salesCount,
      'customers': customerCount,
      'unsynced': unsyncedCount,
    };
  }

  /// Clear all data (for testing purposes)
  Future<void> clearAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('sale_items');
      await txn.delete('sales');
      await txn.delete('products');
      await txn.delete('customers');
      await txn.delete('sync_queue');
    });
  }

  /// Export data to JSON
  Future<Map<String, dynamic>> exportData() async {
    final db = await database;

    final products = await db.query('products');
    final sales = await db.query('sales');
    final saleItems = await db.query('sale_items');
    final customers = await db.query('customers');

    return {
      'export_date': DateTime.now().toIso8601String(),
      'products': products,
      'sales': sales,
      'sale_items': saleItems,
      'customers': customers,
    };
  }

  /// Close database
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}