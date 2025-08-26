import 'dart:async';
import 'dart:io';

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
    await _insertSampleData(db);
  }

  /// Handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database schema upgrades in future versions
    if (oldVersion < 2) {
      // Add new columns or tables for version 2
    }
  }

  /// Insert sample data for development and testing
  Future<void> _insertSampleData(Database db) async {
    final now = DateTime.now().toIso8601String();
    
    // Sample products
    await db.insert('products', {
      'name': 'Coca Cola 500ml',
      'description': 'Refreshing cola drink',
      'price': 1.50,
      'cost': 0.80,
      'stock_quantity': 25,
      'min_stock_level': 10,
      'barcode': '1234567890123',
      'category': 'Beverages',
      'sku': 'COKE-500',
      'created_at': now,
      'updated_at': now,
    });

    await db.insert('products', {
      'name': 'Bread Loaf',
      'description': 'Fresh white bread',
      'price': 0.80,
      'cost': 0.50,
      'stock_quantity': 15,
      'min_stock_level': 5,
      'barcode': '2345678901234',
      'category': 'Bakery',
      'sku': 'BREAD-WHITE',
      'created_at': now,
      'updated_at': now,
    });

    await db.insert('products', {
      'name': 'Milk 1L',
      'description': 'Fresh whole milk',
      'price': 2.20,
      'cost': 1.50,
      'stock_quantity': 8,
      'min_stock_level': 10,
      'barcode': '3456789012345',
      'category': 'Dairy',
      'sku': 'MILK-1L',
      'created_at': now,
      'updated_at': now,
    });

    await db.insert('products', {
      'name': 'Rice 2kg',
      'description': 'Long grain white rice',
      'price': 4.50,
      'cost': 3.00,
      'stock_quantity': 12,
      'min_stock_level': 5,
      'barcode': '4567890123456',
      'category': 'Groceries',
      'sku': 'RICE-2KG',
      'created_at': now,
      'updated_at': now,
    });
  }

  // PRODUCTS CRUD OPERATIONS

  /// Get all products
  Future<List<Map<String, dynamic>>> getAllProducts() async {
    final db = await database;
    return await db.query(
      'products',
      where: 'is_active = ?',
      whereArgs: [1],
      orderBy: 'name ASC',
    );
  }

  /// Get products with low stock
  Future<List<Map<String, dynamic>>> getLowStockProducts() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT * FROM products 
      WHERE is_active = 1 AND stock_quantity <= min_stock_level
      ORDER BY stock_quantity ASC
    ''');
  }

  /// Get product by ID
  Future<Map<String, dynamic>?> getProductById(int id) async {
    final db = await database;
    final results = await db.query(
      'products',
      where: 'id = ? AND is_active = ?',
      whereArgs: [id, 1],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// Get product by barcode
  Future<Map<String, dynamic>?> getProductByBarcode(String barcode) async {
    final db = await database;
    final results = await db.query(
      'products',
      where: 'barcode = ? AND is_active = ?',
      whereArgs: [barcode, 1],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// Insert new product
  Future<int> insertProduct(Map<String, dynamic> product) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    
    product['created_at'] = now;
    product['updated_at'] = now;
    product['synced'] = 0;
    
    final id = await db.insert('products', product);
    
    // Add to sync queue
    await _addToSyncQueue('products', id, 'INSERT', product);
    
    return id;
  }

  /// Update product
  Future<int> updateProduct(int id, Map<String, dynamic> product) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    
    product['updated_at'] = now;
    product['synced'] = 0;
    
    final result = await db.update(
      'products',
      product,
      where: 'id = ?',
      whereArgs: [id],
    );
    
    // Add to sync queue
    await _addToSyncQueue('products', id, 'UPDATE', product);
    
    return result;
  }

  /// Update product stock
  Future<int> updateProductStock(int productId, int newQuantity) async {
    final now = DateTime.now().toIso8601String();
    return await updateProduct(productId, {
      'stock_quantity': newQuantity,
      'updated_at': now,
    });
  }

  /// Delete product (soft delete)
  Future<int> deleteProduct(int id) async {
    final now = DateTime.now().toIso8601String();
    return await updateProduct(id, {
      'is_active': 0,
      'updated_at': now,
    });
  }

  // SALES CRUD OPERATIONS

  /// Insert new sale
  Future<int> insertSale(Map<String, dynamic> sale, List<Map<String, dynamic>> saleItems) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    
    return await db.transaction((txn) async {
      // Insert sale record
      sale['created_at'] = now;
      sale['synced'] = 0;
      final saleId = await txn.insert('sales', sale);
      
      // Insert sale items and update stock
      for (final item in saleItems) {
        item['sale_id'] = saleId;
        item['created_at'] = now;
        await txn.insert('sale_items', item);
        
        // Update product stock
        await txn.rawUpdate('''
          UPDATE products 
          SET stock_quantity = stock_quantity - ?, updated_at = ?
          WHERE id = ?
        ''', [item['quantity'], now, item['product_id']]);
      }
      
      // Add to sync queue
      await _addToSyncQueue('sales', saleId, 'INSERT', sale);
      
      return saleId;
    });
  }

  /// Get sales by date range
  Future<List<Map<String, dynamic>>> getSalesByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;
    return await db.query(
      'sales',
      where: 'sale_date BETWEEN ? AND ?',
      whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
      orderBy: 'sale_date DESC',
    );
  }

  /// Get sale items for a sale
  Future<List<Map<String, dynamic>>> getSaleItems(int saleId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT si.*, p.name as product_name, p.sku
      FROM sale_items si
      JOIN products p ON si.product_id = p.id
      WHERE si.sale_id = ?
      ORDER BY si.created_at ASC
    ''', [saleId]);
  }

  /// Get daily sales summary
  Future<Map<String, dynamic>> getDailySalesSummary(DateTime date) async {
    final db = await database;
    final startOfDay = DateTime(date.year, date.month, date.day).toIso8601String();
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59).toIso8601String();
    
    final results = await db.rawQuery('''
      SELECT 
        COUNT(*) as total_sales,
        SUM(total_amount) as total_revenue,
        SUM(tax_amount) as total_tax,
        SUM(discount_amount) as total_discounts
      FROM sales
      WHERE sale_date BETWEEN ? AND ?
    ''', [startOfDay, endOfDay]);
    
    return results.first;
  }

  // CUSTOMERS CRUD OPERATIONS (Phase 3)

  /// Get all customers
  Future<List<Map<String, dynamic>>> getAllCustomers() async {
    final db = await database;
    return await db.query(
      'customers',
      orderBy: 'name ASC',
    );
  }

  /// Insert new customer
  Future<int> insertCustomer(Map<String, dynamic> customer) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    
    customer['created_at'] = now;
    customer['updated_at'] = now;
    customer['synced'] = 0;
    
    final id = await db.insert('customers', customer);
    
    // Add to sync queue
    await _addToSyncQueue('customers', id, 'INSERT', customer);
    
    return id;
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

  /// Close database connection
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}