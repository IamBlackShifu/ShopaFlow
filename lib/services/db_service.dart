import 'dart:convert';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

class DatabaseService {
  static Database? _database;
  static const int _dbVersion = 3;
  static const String defaultCompanyId = 'local-company';
  static const String defaultStoreId = 'local-store';
  static const String defaultRegisterId = 'local-register';
  static const String defaultUserId = 'local-owner';
  static const String _pendingSync = 'pending';
  static const String _synced = 'synced';

  final Uuid _uuid = const Uuid();
  String _companyId = defaultCompanyId;
  String _storeId = defaultStoreId;
  String _registerId = defaultRegisterId;
  String _userId = defaultUserId;
  String _role = 'owner';

  String get companyId => _companyId;
  String get storeId => _storeId;
  String get registerId => _registerId;
  String get userId => _userId;
  String get role => _role;

  void configureTenant({
    required String companyId,
    required String storeId,
    String? registerId,
    required String userId,
    required String role,
  }) {
    _companyId = companyId.trim().isEmpty ? defaultCompanyId : companyId.trim();
    _storeId = storeId.trim().isEmpty ? defaultStoreId : storeId.trim();
    _registerId = (registerId == null || registerId.trim().isEmpty) ? '${_storeId}_register' : registerId.trim();
    _userId = userId.trim().isEmpty ? defaultUserId : userId.trim();
    _role = role.trim().isEmpty ? 'cashier' : role.trim().toLowerCase();
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'shopaflow.db');
    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: _onOpen,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sync_id TEXT UNIQUE NOT NULL,
        company_id TEXT NOT NULL DEFAULT '$defaultCompanyId',
        store_id TEXT NOT NULL DEFAULT '$defaultStoreId',
        name TEXT NOT NULL,
        description TEXT,
        price REAL NOT NULL,
        cost REAL,
        stock_quantity REAL NOT NULL DEFAULT 0,
        min_stock_level REAL DEFAULT 0,
        barcode TEXT,
        category TEXT,
        sku TEXT,
        created_at TEXT,
        updated_at TEXT,
        created_by TEXT DEFAULT '$defaultUserId',
        sync_status TEXT NOT NULL DEFAULT '$_pendingSync',
        deleted_at TEXT,
        version INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sync_id TEXT UNIQUE NOT NULL,
        company_id TEXT NOT NULL DEFAULT '$defaultCompanyId',
        store_id TEXT NOT NULL DEFAULT '$defaultStoreId',
        register_id TEXT NOT NULL DEFAULT '$defaultRegisterId',
        total_amount REAL NOT NULL,
        payment_method TEXT NOT NULL,
        sale_date TEXT NOT NULL,
        receipt_number TEXT NOT NULL,
        created_at TEXT,
        created_by TEXT DEFAULT '$defaultUserId',
        sync_status TEXT NOT NULL DEFAULT '$_pendingSync',
        deleted_at TEXT,
        version INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE sale_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sync_id TEXT UNIQUE NOT NULL,
        company_id TEXT NOT NULL DEFAULT '$defaultCompanyId',
        store_id TEXT NOT NULL DEFAULT '$defaultStoreId',
        sale_id INTEGER NOT NULL,
        sale_sync_id TEXT,
        product_id INTEGER NOT NULL,
        product_sync_id TEXT,
        quantity REAL NOT NULL,
        unit_price REAL NOT NULL,
        total_price REAL NOT NULL,
        created_at TEXT,
        sync_status TEXT NOT NULL DEFAULT '$_pendingSync',
        deleted_at TEXT,
        version INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sync_id TEXT UNIQUE NOT NULL,
        company_id TEXT NOT NULL DEFAULT '$defaultCompanyId',
        store_id TEXT NOT NULL DEFAULT '$defaultStoreId',
        name TEXT NOT NULL,
        email TEXT,
        phone TEXT,
        address TEXT,
        created_at TEXT,
        updated_at TEXT,
        created_by TEXT DEFAULT '$defaultUserId',
        sync_status TEXT NOT NULL DEFAULT '$_pendingSync',
        deleted_at TEXT,
        version INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await _createSaasTables(db);
    await _createIndexes(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.transaction((txn) async {
        await txn.execute('ALTER TABLE products RENAME TO products_old');
        await txn.execute('''
          CREATE TABLE products (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            description TEXT,
            price REAL NOT NULL,
            cost REAL,
            stock_quantity REAL NOT NULL DEFAULT 0,
            min_stock_level REAL DEFAULT 0,
            barcode TEXT,
            category TEXT,
            sku TEXT,
            created_at TEXT,
            updated_at TEXT
          )
        ''');
        await txn.execute('''
          INSERT INTO products (
            id, name, description, price, cost, stock_quantity, min_stock_level,
            barcode, category, sku, created_at, updated_at
          )
          SELECT
            id, name, description, price, cost,
            CAST(stock_quantity AS REAL),
            CAST(min_stock_level AS REAL),
            barcode, category, sku, created_at, updated_at
          FROM products_old
        ''');
        await txn.execute('DROP TABLE products_old');

        await txn.execute('ALTER TABLE sale_items RENAME TO sale_items_old');
        await txn.execute('''
          CREATE TABLE sale_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sale_id INTEGER NOT NULL,
            product_id INTEGER NOT NULL,
            quantity REAL NOT NULL,
            unit_price REAL NOT NULL,
            total_price REAL NOT NULL,
            FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE CASCADE,
            FOREIGN KEY (product_id) REFERENCES products (id)
          )
        ''');
        await txn.execute('''
          INSERT INTO sale_items (id, sale_id, product_id, quantity, unit_price, total_price)
          SELECT id, sale_id, product_id, CAST(quantity AS REAL), unit_price, total_price
          FROM sale_items_old
        ''');
        await txn.execute('DROP TABLE sale_items_old');
      });
    }

    if (oldVersion < 3) {
      await db.transaction((txn) async {
        await _addSyncColumns(txn);
        await _createSaasTables(txn);
        await _createIndexes(txn);
      });
    }
  }

  Future<void> _onOpen(Database db) async {
    await _createSaasTables(db);
    await _addColumnIfMissing(db, 'companies', 'owner_user_id', 'TEXT');
    await _addColumnIfMissing(db, 'app_users', 'store_id', 'TEXT');
    await _addColumnIfMissing(db, 'app_users', 'register_id', 'TEXT');
    await _ensureDefaultTenant(db);
    await _backfillSyncMetadata(db);
  }

  Future<void> _createSaasTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS companies (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        owner_user_id TEXT,
        plan TEXT NOT NULL DEFAULT 'local',
        subscription_status TEXT NOT NULL DEFAULT 'local',
        created_at TEXT,
        updated_at TEXT,
        sync_status TEXT NOT NULL DEFAULT '$_pendingSync'
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS stores (
        id TEXT PRIMARY KEY,
        company_id TEXT NOT NULL,
        name TEXT NOT NULL,
        address TEXT,
        created_at TEXT,
        updated_at TEXT,
        sync_status TEXT NOT NULL DEFAULT '$_pendingSync'
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS registers (
        id TEXT PRIMARY KEY,
        company_id TEXT NOT NULL,
        store_id TEXT NOT NULL,
        name TEXT NOT NULL,
        device_label TEXT,
        created_at TEXT,
        updated_at TEXT,
        sync_status TEXT NOT NULL DEFAULT '$_pendingSync'
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_users (
        id TEXT PRIMARY KEY,
        company_id TEXT NOT NULL,
        store_id TEXT,
        register_id TEXT,
        name TEXT NOT NULL,
        email TEXT,
        role TEXT NOT NULL DEFAULT 'owner',
        created_at TEXT,
        updated_at TEXT,
        sync_status TEXT NOT NULL DEFAULT '$_pendingSync'
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS inventory_movements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sync_id TEXT UNIQUE NOT NULL,
        company_id TEXT NOT NULL DEFAULT '$defaultCompanyId',
        store_id TEXT NOT NULL DEFAULT '$defaultStoreId',
        product_id INTEGER NOT NULL,
        product_sync_id TEXT,
        sale_id INTEGER,
        sale_sync_id TEXT,
        movement_type TEXT NOT NULL,
        quantity_delta REAL NOT NULL,
        reason TEXT,
        created_at TEXT NOT NULL,
        created_by TEXT DEFAULT '$defaultUserId',
        sync_status TEXT NOT NULL DEFAULT '$_pendingSync',
        version INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (product_id) REFERENCES products (id),
        FOREIGN KEY (sale_id) REFERENCES sales (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_queue (
        id TEXT PRIMARY KEY,
        company_id TEXT NOT NULL DEFAULT '$defaultCompanyId',
        store_id TEXT NOT NULL DEFAULT '$defaultStoreId',
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        local_id INTEGER,
        operation TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT '$_pendingSync',
        retry_count INTEGER NOT NULL DEFAULT 0,
        last_error TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createIndexes(DatabaseExecutor db) async {
    await db.execute('CREATE INDEX IF NOT EXISTS idx_products_scope ON products(company_id, store_id, deleted_at)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sales_scope_date ON sales(company_id, store_id, sale_date)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sale_items_sale ON sale_items(sale_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_customers_scope ON customers(company_id, store_id, deleted_at)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_inventory_product ON inventory_movements(product_id, created_at)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sync_queue_status ON sync_queue(status, created_at)');
  }

  Future<void> _addSyncColumns(DatabaseExecutor db) async {
    await _addColumnIfMissing(db, 'products', 'sync_id', 'TEXT');
    await _addColumnIfMissing(db, 'products', 'company_id', "TEXT NOT NULL DEFAULT '$defaultCompanyId'");
    await _addColumnIfMissing(db, 'products', 'store_id', "TEXT NOT NULL DEFAULT '$defaultStoreId'");
    await _addColumnIfMissing(db, 'products', 'created_by', "TEXT DEFAULT '$defaultUserId'");
    await _addColumnIfMissing(db, 'products', 'sync_status', "TEXT NOT NULL DEFAULT '$_synced'");
    await _addColumnIfMissing(db, 'products', 'deleted_at', 'TEXT');
    await _addColumnIfMissing(db, 'products', 'version', 'INTEGER NOT NULL DEFAULT 1');

    await _addColumnIfMissing(db, 'sales', 'sync_id', 'TEXT');
    await _addColumnIfMissing(db, 'sales', 'company_id', "TEXT NOT NULL DEFAULT '$defaultCompanyId'");
    await _addColumnIfMissing(db, 'sales', 'store_id', "TEXT NOT NULL DEFAULT '$defaultStoreId'");
    await _addColumnIfMissing(db, 'sales', 'register_id', "TEXT NOT NULL DEFAULT '$defaultRegisterId'");
    await _addColumnIfMissing(db, 'sales', 'created_by', "TEXT DEFAULT '$defaultUserId'");
    await _addColumnIfMissing(db, 'sales', 'sync_status', "TEXT NOT NULL DEFAULT '$_synced'");
    await _addColumnIfMissing(db, 'sales', 'deleted_at', 'TEXT');
    await _addColumnIfMissing(db, 'sales', 'version', 'INTEGER NOT NULL DEFAULT 1');

    await _addColumnIfMissing(db, 'sale_items', 'sync_id', 'TEXT');
    await _addColumnIfMissing(db, 'sale_items', 'company_id', "TEXT NOT NULL DEFAULT '$defaultCompanyId'");
    await _addColumnIfMissing(db, 'sale_items', 'store_id', "TEXT NOT NULL DEFAULT '$defaultStoreId'");
    await _addColumnIfMissing(db, 'sale_items', 'sale_sync_id', 'TEXT');
    await _addColumnIfMissing(db, 'sale_items', 'product_sync_id', 'TEXT');
    await _addColumnIfMissing(db, 'sale_items', 'created_at', 'TEXT');
    await _addColumnIfMissing(db, 'sale_items', 'sync_status', "TEXT NOT NULL DEFAULT '$_synced'");
    await _addColumnIfMissing(db, 'sale_items', 'deleted_at', 'TEXT');
    await _addColumnIfMissing(db, 'sale_items', 'version', 'INTEGER NOT NULL DEFAULT 1');

    await _addColumnIfMissing(db, 'customers', 'sync_id', 'TEXT');
    await _addColumnIfMissing(db, 'customers', 'company_id', "TEXT NOT NULL DEFAULT '$defaultCompanyId'");
    await _addColumnIfMissing(db, 'customers', 'store_id', "TEXT NOT NULL DEFAULT '$defaultStoreId'");
    await _addColumnIfMissing(db, 'customers', 'updated_at', 'TEXT');
    await _addColumnIfMissing(db, 'customers', 'created_by', "TEXT DEFAULT '$defaultUserId'");
    await _addColumnIfMissing(db, 'customers', 'sync_status', "TEXT NOT NULL DEFAULT '$_synced'");
    await _addColumnIfMissing(db, 'customers', 'deleted_at', 'TEXT');
    await _addColumnIfMissing(db, 'customers', 'version', 'INTEGER NOT NULL DEFAULT 1');
  }

  Future<void> _addColumnIfMissing(DatabaseExecutor db, String table, String column, String definition) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    final exists = columns.any((row) => row['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }

  Future<void> _ensureDefaultTenant(DatabaseExecutor db) async {
    final now = DateTime.now().toIso8601String();
    await db.insert('companies', {
      'id': defaultCompanyId,
      'name': 'Local Company',
      'plan': 'local',
      'subscription_status': 'local',
      'created_at': now,
      'updated_at': now,
      'sync_status': _pendingSync,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    await db.insert('stores', {
      'id': defaultStoreId,
      'company_id': defaultCompanyId,
      'name': 'Main Store',
      'created_at': now,
      'updated_at': now,
      'sync_status': _pendingSync,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    await db.insert('registers', {
      'id': defaultRegisterId,
      'company_id': defaultCompanyId,
      'store_id': defaultStoreId,
      'name': 'Main Register',
      'created_at': now,
      'updated_at': now,
      'sync_status': _pendingSync,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    await db.insert('app_users', {
      'id': defaultUserId,
      'company_id': defaultCompanyId,
      'name': 'Owner',
      'role': 'owner',
      'created_at': now,
      'updated_at': now,
      'sync_status': _pendingSync,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> _backfillSyncMetadata(DatabaseExecutor db) async {
    await _backfillTableSyncIds(db, 'products', 'prd');
    await _backfillTableSyncIds(db, 'sales', 'sale');
    await _backfillTableSyncIds(db, 'sale_items', 'item');
    await _backfillTableSyncIds(db, 'customers', 'cus');
    await _backfillSaleItemReferences(db);
  }

  Future<void> _backfillTableSyncIds(DatabaseExecutor db, String table, String prefix) async {
    final rows = await db.query(
      table,
      columns: ['id'],
      where: 'sync_id IS NULL OR sync_id = ?',
      whereArgs: [''],
    );
    for (final row in rows) {
      await db.update(table, {'sync_id': _newSyncId(prefix)}, where: 'id = ?', whereArgs: [row['id']]);
    }
  }

  Future<void> _backfillSaleItemReferences(DatabaseExecutor db) async {
    await db.rawUpdate('''
      UPDATE sale_items
      SET sale_sync_id = (
        SELECT sales.sync_id FROM sales WHERE sales.id = sale_items.sale_id
      )
      WHERE sale_sync_id IS NULL OR sale_sync_id = ''
    ''');
    await db.rawUpdate('''
      UPDATE sale_items
      SET product_sync_id = (
        SELECT products.sync_id FROM products WHERE products.id = sale_items.product_id
      )
      WHERE product_sync_id IS NULL OR product_sync_id = ''
    ''');
  }

  Future<void> upsertLocalCompanyProfile({
    String? companyId,
    String? storeId,
    required String companyName,
    required String ownerName,
    required String email,
    String? userId,
    String role = 'owner',
    String? storeName,
    String? storeAddress,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final cleanCompanyName = companyName.trim().isEmpty ? 'Local Company' : companyName.trim();
    final cleanOwnerName = ownerName.trim().isEmpty ? 'Owner' : ownerName.trim();
    final cleanStoreName = (storeName == null || storeName.trim().isEmpty) ? cleanCompanyName : storeName.trim();
    final cleanCompanyId = (companyId == null || companyId.trim().isEmpty) ? _companyId : companyId.trim();
    final cleanStoreId = (storeId == null || storeId.trim().isEmpty) ? _storeId : storeId.trim();
    final cleanUserId = (userId == null || userId.trim().isEmpty) ? _userId : userId.trim();
    final cleanRole = role.trim().isEmpty ? 'owner' : role.trim().toLowerCase();

    _companyId = cleanCompanyId;
    _storeId = cleanStoreId;
    _registerId = '${cleanStoreId}_register';
    _userId = cleanUserId;
    _role = cleanRole;

    await db.transaction((txn) async {
      await _migrateLegacyTenantRows(
        txn,
        companyId: cleanCompanyId,
        storeId: cleanStoreId,
        userId: cleanUserId,
      );

      await txn.insert('companies', {
        'id': cleanCompanyId,
        'name': cleanCompanyName,
        'owner_user_id': cleanUserId,
        'plan': 'local',
        'subscription_status': 'local',
        'created_at': now,
        'updated_at': now,
        'sync_status': _pendingSync,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      await txn.insert('stores', {
        'id': cleanStoreId,
        'company_id': cleanCompanyId,
        'name': cleanStoreName,
        'address': storeAddress?.trim(),
        'created_at': now,
        'updated_at': now,
        'sync_status': _pendingSync,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      await txn.insert('app_users', {
        'id': cleanUserId,
        'company_id': cleanCompanyId,
        'store_id': cleanStoreId,
        'register_id': '${cleanStoreId}_register',
        'name': cleanOwnerName,
        'email': email.trim().toLowerCase(),
        'role': cleanRole,
        'created_at': now,
        'updated_at': now,
        'sync_status': _pendingSync,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      await _enqueueSyncChange(txn, 'company', cleanCompanyId, 'upsert', {
        'id': cleanCompanyId,
        'company_id': cleanCompanyId,
        'store_id': cleanStoreId,
        'name': cleanCompanyName,
        'owner_user_id': cleanUserId,
        'plan': 'local',
        'subscription_status': 'local',
        'updated_at': now,
        'sync_status': _pendingSync,
      });
      await _enqueueSyncChange(txn, 'app_user', cleanUserId, 'upsert', {
        'id': cleanUserId,
        'company_id': cleanCompanyId,
        'store_id': cleanStoreId,
        'register_id': '${cleanStoreId}_register',
        'name': cleanOwnerName,
        'email': email.trim().toLowerCase(),
        'role': cleanRole,
        'company_name': cleanCompanyName,
        'updated_at': now,
        'sync_status': _pendingSync,
      });
      await _enqueueSyncChange(txn, 'store', cleanStoreId, 'upsert', {
        'id': cleanStoreId,
        'company_id': cleanCompanyId,
        'name': cleanStoreName,
        'address': storeAddress?.trim(),
        'updated_at': now,
        'sync_status': _pendingSync,
      });
    });
  }

  Future<void> _migrateLegacyTenantRows(
    DatabaseExecutor db, {
    required String companyId,
    required String storeId,
    required String userId,
  }) async {
    if (companyId == defaultCompanyId && storeId == defaultStoreId) return;

    for (final table in const ['products', 'sales', 'sale_items', 'customers', 'inventory_movements']) {
      await db.update(
        table,
        {'company_id': companyId, 'store_id': storeId},
        where: 'company_id = ? AND store_id = ?',
        whereArgs: [defaultCompanyId, defaultStoreId],
      );
    }

    for (final table in const ['products', 'sales', 'customers', 'inventory_movements']) {
      await db.update(
        table,
        {'created_by': userId},
        where: 'created_by = ?',
        whereArgs: [defaultUserId],
      );
    }

    await db.update(
      'sync_queue',
      {'company_id': companyId, 'store_id': storeId, 'updated_at': DateTime.now().toIso8601String()},
      where: 'company_id = ? OR store_id = ?',
      whereArgs: [defaultCompanyId, defaultStoreId],
    );
    await db.update(
      'sync_queue',
      {'entity_id': companyId, 'updated_at': DateTime.now().toIso8601String()},
      where: 'entity_type = ? AND entity_id = ?',
      whereArgs: ['company', defaultCompanyId],
    );
    await db.update(
      'sync_queue',
      {'entity_id': storeId, 'updated_at': DateTime.now().toIso8601String()},
      where: 'entity_type = ? AND entity_id = ?',
      whereArgs: ['store', defaultStoreId],
    );
    await db.update(
      'sync_queue',
      {'entity_id': userId, 'updated_at': DateTime.now().toIso8601String()},
      where: 'entity_type = ? AND entity_id = ?',
      whereArgs: ['app_user', defaultUserId],
    );

    await db.rawUpdate(
      'UPDATE sync_queue SET payload_json = REPLACE(REPLACE(REPLACE(payload_json, ?, ?), ?, ?), ?, ?)',
      [defaultCompanyId, companyId, defaultStoreId, storeId, defaultUserId, userId],
    );
  }

  Future<void> migrateLegacyTenantToActive() async {
    final db = await database;
    await db.transaction((txn) async {
      await _migrateLegacyTenantRows(
        txn,
        companyId: _companyId,
        storeId: _storeId,
        userId: _userId,
      );
    });
  }

  String _newSyncId(String prefix) => '${prefix}_${_uuid.v4()}';

  Future<void> _enqueueSyncChange(
    DatabaseExecutor db,
    String entityType,
    String entityId,
    String operation,
    Map<String, dynamic> payload, {
    int? localId,
  }) async {
    final now = DateTime.now().toIso8601String();
    await db.insert('sync_queue', {
      'id': _newSyncId('sync'),
      'company_id': payload['company_id'] ?? _companyId,
      'store_id': payload['store_id'] ?? _storeId,
      'entity_type': entityType,
      'entity_id': entityId,
      'local_id': localId,
      'operation': operation,
      'payload_json': jsonEncode(payload),
      'status': _pendingSync,
      'retry_count': 0,
      'created_at': now,
      'updated_at': now,
    });
  }

  // Product methods
  Future<List<Map<String, dynamic>>> getAllProducts() async {
    final db = await database;
    return await db.query(
      'products',
      where: 'company_id = ? AND store_id = ? AND deleted_at IS NULL',
      whereArgs: [_companyId, _storeId],
      orderBy: 'name ASC',
    );
  }

  Future<int> addProduct(Map<String, dynamic> product) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    product['sync_id'] ??= _newSyncId('prd');
    product['company_id'] = _companyId;
    product['store_id'] = _storeId;
    product['created_by'] ??= _userId;
    product['created_at'] ??= now;
    product['updated_at'] = now;
    product['sync_status'] = _pendingSync;
    product['version'] ??= 1;

    return await db.transaction((txn) async {
      final id = await txn.insert('products', product);
      final row = await txn.query('products', where: 'id = ?', whereArgs: [id], limit: 1);
      await _enqueueSyncChange(txn, 'product', product['sync_id'].toString(), 'create', row.first, localId: id);
      return id;
    });
  }

  Future<int> updateProduct(int id, Map<String, dynamic> product) async {
    final db = await database;
    product['updated_at'] = DateTime.now().toIso8601String();
    product['sync_status'] = _pendingSync;

    return await db.transaction((txn) async {
      final updated = await txn.update(
        'products',
        product,
        where: 'id = ? AND company_id = ? AND store_id = ?',
        whereArgs: [id, _companyId, _storeId],
      );
      await txn.rawUpdate('UPDATE products SET version = version + 1 WHERE id = ?', [id]);
      final row = await txn.query(
        'products',
        where: 'id = ? AND company_id = ? AND store_id = ?',
        whereArgs: [id, _companyId, _storeId],
        limit: 1,
      );
      if (row.isNotEmpty) {
        await _enqueueSyncChange(txn, 'product', row.first['sync_id'].toString(), 'update', row.first, localId: id);
      }
      return updated;
    });
  }

  Future<int> deleteProduct(int id) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    return await db.transaction((txn) async {
      final updated = await txn.update(
        'products',
        {'deleted_at': now, 'updated_at': now, 'sync_status': _pendingSync},
        where: 'id = ? AND company_id = ? AND store_id = ?',
        whereArgs: [id, _companyId, _storeId],
      );
      await txn.rawUpdate('UPDATE products SET version = version + 1 WHERE id = ?', [id]);
      final row = await txn.query(
        'products',
        where: 'id = ? AND company_id = ? AND store_id = ?',
        whereArgs: [id, _companyId, _storeId],
        limit: 1,
      );
      if (row.isNotEmpty) {
        await _enqueueSyncChange(txn, 'product', row.first['sync_id'].toString(), 'delete', row.first, localId: id);
      }
      return updated;
    });
  }

  Future<Map<String, dynamic>?> getProductById(int id) async {
    final db = await database;
    final results = await db.query(
      'products',
      where: 'id = ? AND company_id = ? AND store_id = ? AND deleted_at IS NULL',
      whereArgs: [id, _companyId, _storeId],
    );
    return results.isNotEmpty ? results.first : null;
  }

  // Sales methods
  Future<int> addSale(Map<String, dynamic> sale, List<Map<String, dynamic>> items) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    sale['sync_id'] ??= _newSyncId('sale');
    sale['company_id'] = _companyId;
    sale['store_id'] = _storeId;
    sale['register_id'] ??= _registerId;
    sale['created_by'] ??= _userId;
    sale['created_at'] = now;
    sale['sync_status'] = _pendingSync;
    sale['version'] ??= 1;

    return await db.transaction((txn) async {
      final saleId = await txn.insert('sales', sale);
      final saleRow = await txn.query('sales', where: 'id = ?', whereArgs: [saleId], limit: 1);
      await _enqueueSyncChange(txn, 'sale', sale['sync_id'].toString(), 'create', saleRow.first, localId: saleId);

      for (var item in items) {
        final productId = item['product_id'];
        final productRows = await txn.query(
          'products',
          columns: ['sync_id'],
          where: 'id = ? AND company_id = ? AND store_id = ? AND deleted_at IS NULL',
          whereArgs: [productId, _companyId, _storeId],
          limit: 1,
        );
        if (productRows.isEmpty) {
          throw StateError('Product does not belong to the active store.');
        }
        final productSyncId = productRows.isNotEmpty ? productRows.first['sync_id']?.toString() : null;

        item['sync_id'] ??= _newSyncId('item');
        item['company_id'] ??= sale['company_id'];
        item['store_id'] ??= sale['store_id'];
        item['sale_id'] = saleId;
        item['sale_sync_id'] = sale['sync_id'];
        item['product_sync_id'] = productSyncId;
        item['created_at'] = now;
        item['sync_status'] = _pendingSync;
        item['version'] ??= 1;
        final saleItemId = await txn.insert('sale_items', item);
        final saleItemRow = await txn.query('sale_items', where: 'id = ?', whereArgs: [saleItemId], limit: 1);
        await _enqueueSyncChange(txn, 'sale_item', item['sync_id'].toString(), 'create', saleItemRow.first, localId: saleItemId);

        double quantity;
        if (item['quantity'] is num) {
          quantity = (item['quantity'] as num).toDouble();
        } else {
          quantity = double.tryParse(item['quantity']?.toString() ?? '') ?? 0.0;
        }
        await txn.rawUpdate(
          'UPDATE products SET stock_quantity = stock_quantity - ? WHERE id = ? AND company_id = ? AND store_id = ?',
          [quantity, productId, _companyId, _storeId],
        );

        final movement = {
          'sync_id': _newSyncId('mov'),
          'company_id': sale['company_id'],
          'store_id': sale['store_id'],
          'product_id': productId,
          'product_sync_id': productSyncId,
          'sale_id': saleId,
          'sale_sync_id': sale['sync_id'],
          'movement_type': 'sale',
          'quantity_delta': -quantity,
          'reason': 'Sale ${sale['receipt_number']}',
          'created_at': now,
          'created_by': sale['created_by'],
          'sync_status': _pendingSync,
          'version': 1,
        };
        final movementId = await txn.insert('inventory_movements', movement);
        final movementRow = await txn.query('inventory_movements', where: 'id = ?', whereArgs: [movementId], limit: 1);
        await _enqueueSyncChange(
          txn,
          'inventory_movement',
          movement['sync_id'].toString(),
          'create',
          movementRow.first,
          localId: movementId,
        );
      }

      return saleId;
    });
  }

  Future<List<Map<String, dynamic>>> getAllSales() async {
    final db = await database;
    return await db.query(
      'sales',
      where: 'company_id = ? AND store_id = ? AND deleted_at IS NULL',
      whereArgs: [_companyId, _storeId],
      orderBy: 'sale_date DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getSalesByDate(DateTime date) async {
    final db = await database;
    final startOfDay = DateTime(date.year, date.month, date.day).toIso8601String();
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59).toIso8601String();

    return await db.query(
      'sales',
      where: 'company_id = ? AND store_id = ? AND sale_date >= ? AND sale_date <= ? AND deleted_at IS NULL',
      whereArgs: [_companyId, _storeId, startOfDay, endOfDay],
      orderBy: 'sale_date DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getSaleItems(int saleId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT si.*, p.name as product_name
      FROM sale_items si
      LEFT JOIN products p ON p.id = si.product_id
      WHERE si.sale_id = ?
        AND si.company_id = ?
        AND si.store_id = ?
        AND si.deleted_at IS NULL
      ORDER BY si.id ASC
    ''', [saleId, _companyId, _storeId]);
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
      WHERE company_id = ? AND store_id = ?
        AND sale_date >= ? AND sale_date <= ?
        AND deleted_at IS NULL
    ''', [_companyId, _storeId, startOfDay, endOfDay]);

    return {
      'count': result.first['count'] ?? 0,
      'total': result.first['total'] ?? 0.0,
    };
  }

  // Customer methods
  Future<List<Map<String, dynamic>>> getAllCustomers() async {
    final db = await database;
    return await db.query(
      'customers',
      where: 'company_id = ? AND store_id = ? AND deleted_at IS NULL',
      whereArgs: [_companyId, _storeId],
      orderBy: 'name ASC',
    );
  }

  Future<int> addCustomer(Map<String, dynamic> customer) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    customer['sync_id'] ??= _newSyncId('cus');
    customer['company_id'] = _companyId;
    customer['store_id'] = _storeId;
    customer['created_by'] ??= _userId;
    customer['created_at'] ??= now;
    customer['updated_at'] = now;
    customer['sync_status'] = _pendingSync;
    customer['version'] ??= 1;

    return await db.transaction((txn) async {
      final id = await txn.insert('customers', customer);
      final row = await txn.query('customers', where: 'id = ?', whereArgs: [id], limit: 1);
      await _enqueueSyncChange(txn, 'customer', customer['sync_id'].toString(), 'create', row.first, localId: id);
      return id;
    });
  }

  Future<int> updateCustomer(int id, Map<String, dynamic> customer) async {
    final db = await database;
    customer['updated_at'] = DateTime.now().toIso8601String();
    customer['sync_status'] = _pendingSync;
    return await db.transaction((txn) async {
      final updated = await txn.update(
        'customers',
        customer,
        where: 'id = ? AND company_id = ? AND store_id = ?',
        whereArgs: [id, _companyId, _storeId],
      );
      await txn.rawUpdate('UPDATE customers SET version = version + 1 WHERE id = ?', [id]);
      final row = await txn.query(
        'customers',
        where: 'id = ? AND company_id = ? AND store_id = ?',
        whereArgs: [id, _companyId, _storeId],
        limit: 1,
      );
      if (row.isNotEmpty) {
        await _enqueueSyncChange(txn, 'customer', row.first['sync_id'].toString(), 'update', row.first, localId: id);
      }
      return updated;
    });
  }

  Future<int> deleteCustomer(int id) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    return await db.transaction((txn) async {
      final updated = await txn.update(
        'customers',
        {'deleted_at': now, 'updated_at': now, 'sync_status': _pendingSync},
        where: 'id = ? AND company_id = ? AND store_id = ?',
        whereArgs: [id, _companyId, _storeId],
      );
      await txn.rawUpdate('UPDATE customers SET version = version + 1 WHERE id = ?', [id]);
      final row = await txn.query(
        'customers',
        where: 'id = ? AND company_id = ? AND store_id = ?',
        whereArgs: [id, _companyId, _storeId],
        limit: 1,
      );
      if (row.isNotEmpty) {
        await _enqueueSyncChange(txn, 'customer', row.first['sync_id'].toString(), 'delete', row.first, localId: id);
      }
      return updated;
    });
  }

  Future<List<Map<String, dynamic>>> getPendingSyncQueue({int limit = 100, bool includeFailed = false}) async {
    final db = await database;
    return await db.query(
      'sync_queue',
      where: includeFailed ? 'company_id = ? AND status IN (?, ?)' : 'company_id = ? AND status = ?',
      whereArgs: includeFailed ? [_companyId, _pendingSync, 'failed'] : [_companyId, _pendingSync],
      orderBy: 'created_at ASC',
      limit: limit,
    );
  }

  Future<int> getPendingSyncCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM sync_queue WHERE company_id = ? AND status = ?',
      [_companyId, _pendingSync],
    );
    return (result.first['count'] as int?) ?? 0;
  }

  Future<int> getRetryableSyncCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM sync_queue WHERE company_id = ? AND status IN (?, ?)',
      [_companyId, _pendingSync, 'failed'],
    );
    return (result.first['count'] as int?) ?? 0;
  }

  Future<int> retryFailedSyncItems() async {
    final db = await database;
    return await db.update(
      'sync_queue',
      {
        'status': _pendingSync,
        'last_error': null,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'company_id = ? AND status = ?',
      whereArgs: [_companyId, 'failed'],
    );
  }

  Future<int> markSyncQueueItemSynced(String queueId) async {
    final db = await database;
    return await db.update(
      'sync_queue',
      {'status': _synced, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [queueId],
    );
  }

  Future<int> markSyncQueueItemFailed(String queueId, String error) async {
    final db = await database;
    return await db.rawUpdate('''
      UPDATE sync_queue
      SET status = ?,
          retry_count = retry_count + 1,
          last_error = ?,
          updated_at = ?
      WHERE id = ?
    ''', ['failed', error, DateTime.now().toIso8601String(), queueId]);
  }

  Future<void> upsertRemoteRows(String table, List<Map<String, dynamic>> rows) async {
    const allowedTables = {
      'products',
      'sales',
      'sale_items',
      'customers',
      'inventory_movements',
    };
    if (!allowedTables.contains(table)) {
      throw ArgumentError('Unsupported sync table: $table');
    }
    final db = await database;
    await db.transaction((txn) async {
      for (final source in rows) {
        final row = Map<String, dynamic>.from(source);
        final syncId = row['sync_id']?.toString().isNotEmpty == true ? row['sync_id'].toString() : row['id']?.toString();
        if (syncId == null || syncId.isEmpty) continue;
        row
          ..remove('id')
          ..remove('sync_meta')
          ..['sync_id'] = syncId
          ..['company_id'] = _companyId
          ..['store_id'] = row['store_id'] ?? _storeId
          ..['sync_status'] = _synced;

        final existing = await txn.query(table, columns: ['id'], where: 'sync_id = ?', whereArgs: [syncId], limit: 1);
        if (existing.isEmpty) {
          await txn.insert(table, row);
        } else {
          await txn.update(table, row, where: 'sync_id = ?', whereArgs: [syncId]);
        }
      }
    });
  }

  // Export/Import methods
  Future<Map<String, dynamic>> exportData() async {
    final db = await database;

    final products = await db.query('products', where: 'company_id = ? AND store_id = ?', whereArgs: [_companyId, _storeId]);
    final sales = await db.query('sales', where: 'company_id = ? AND store_id = ?', whereArgs: [_companyId, _storeId]);
    final saleItems = await db.query('sale_items', where: 'company_id = ? AND store_id = ?', whereArgs: [_companyId, _storeId]);
    final customers = await db.query('customers', where: 'company_id = ? AND store_id = ?', whereArgs: [_companyId, _storeId]);
    final inventoryMovements = await db.query('inventory_movements', where: 'company_id = ? AND store_id = ?', whereArgs: [_companyId, _storeId]);

    return {
      'company_id': _companyId,
      'store_id': _storeId,
      'products': products,
      'sales': sales,
      'sale_items': saleItems,
      'customers': customers,
      'inventory_movements': inventoryMovements,
      'exported_at': DateTime.now().toIso8601String(),
    };
  }

  Future<void> importData(Map<String, dynamic> data) async {
    final db = await database;

    await db.transaction((txn) async {
      await txn.delete('sync_queue', where: 'company_id = ?', whereArgs: [_companyId]);
      await txn.delete('inventory_movements', where: 'company_id = ? AND store_id = ?', whereArgs: [_companyId, _storeId]);
      await txn.delete('sale_items', where: 'company_id = ? AND store_id = ?', whereArgs: [_companyId, _storeId]);
      await txn.delete('sales', where: 'company_id = ? AND store_id = ?', whereArgs: [_companyId, _storeId]);
      await txn.delete('products', where: 'company_id = ? AND store_id = ?', whereArgs: [_companyId, _storeId]);
      await txn.delete('customers', where: 'company_id = ? AND store_id = ?', whereArgs: [_companyId, _storeId]);

      if (data['products'] != null) {
        for (final product in data['products']) {
          await txn.insert('products', {...Map<String, dynamic>.from(product), 'company_id': _companyId, 'store_id': _storeId});
        }
      }

      if (data['customers'] != null) {
        for (final customer in data['customers']) {
          await txn.insert('customers', {...Map<String, dynamic>.from(customer), 'company_id': _companyId, 'store_id': _storeId});
        }
      }

      if (data['sales'] != null) {
        for (final sale in data['sales']) {
          await txn.insert('sales', {...Map<String, dynamic>.from(sale), 'company_id': _companyId, 'store_id': _storeId});
        }
      }

      if (data['sale_items'] != null) {
        for (final item in data['sale_items']) {
          await txn.insert('sale_items', {...Map<String, dynamic>.from(item), 'company_id': _companyId, 'store_id': _storeId});
        }
      }

      if (data['inventory_movements'] != null) {
        for (final movement in data['inventory_movements']) {
          await txn.insert('inventory_movements', {...Map<String, dynamic>.from(movement), 'company_id': _companyId, 'store_id': _storeId});
        }
      }
    });
    await _backfillSyncMetadata(db);
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('sync_queue', where: 'company_id = ?', whereArgs: [_companyId]);
      await txn.delete('inventory_movements', where: 'company_id = ? AND store_id = ?', whereArgs: [_companyId, _storeId]);
      await txn.delete('sale_items', where: 'company_id = ? AND store_id = ?', whereArgs: [_companyId, _storeId]);
      await txn.delete('sales', where: 'company_id = ? AND store_id = ?', whereArgs: [_companyId, _storeId]);
      await txn.delete('products', where: 'company_id = ? AND store_id = ?', whereArgs: [_companyId, _storeId]);
      await txn.delete('customers', where: 'company_id = ? AND store_id = ?', whereArgs: [_companyId, _storeId]);
    });
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
