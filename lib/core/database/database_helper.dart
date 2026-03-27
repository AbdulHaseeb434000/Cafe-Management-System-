import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../constants/app_constants.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConstants.dbName);
    return openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _onCreate,
      onConfigure: (db) async => await db.execute('PRAGMA foreign_keys = ON'),
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute(_createCategories);
    await db.execute(_createMenuItems);
    await db.execute(_createTables);
    await db.execute(_createCustomers);
    await db.execute(_createOrders);
    await db.execute(_createOrderItems);
    await db.execute(_createPayments);
    await db.execute(_createInventoryItems);
    await db.execute(_createInventoryLogs);
    await db.execute(_createSettings);
    await _seedDefaultSettings(db);
  }

  Future<void> _seedDefaultSettings(Database db) async {
    final defaults = {
      AppConstants.settingCafeName: 'My Cafe',
      AppConstants.settingCafeAddress: '',
      AppConstants.settingCafePhone: '',
      AppConstants.settingTaxPercent: '0.0',
      AppConstants.settingReceiptHeader: 'Thank you for visiting!',
      AppConstants.settingReceiptFooter: 'Please come again.',
      AppConstants.settingCurrencySymbol: AppConstants.defaultCurrencySymbol,
    };
    for (final entry in defaults.entries) {
      await db.insert('settings', {'key': entry.key, 'value': entry.value});
    }
  }

  // ── DDL ─────────────────────────────────────────────────────────────

  static const _createCategories = '''
    CREATE TABLE categories (
      id         INTEGER PRIMARY KEY AUTOINCREMENT,
      name       TEXT    NOT NULL,
      icon       TEXT    NOT NULL DEFAULT 'restaurant',
      sort_order INTEGER NOT NULL DEFAULT 0,
      created_at TEXT    NOT NULL
    )
  ''';

  static const _createMenuItems = '''
    CREATE TABLE menu_items (
      id           INTEGER PRIMARY KEY AUTOINCREMENT,
      category_id  INTEGER NOT NULL,
      name         TEXT    NOT NULL,
      price        REAL    NOT NULL,
      description  TEXT,
      is_available INTEGER NOT NULL DEFAULT 1,
      image_path   TEXT,
      created_at   TEXT    NOT NULL,
      FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE CASCADE
    )
  ''';

  static const _createTables = '''
    CREATE TABLE cafe_tables (
      id       INTEGER PRIMARY KEY AUTOINCREMENT,
      name     TEXT    NOT NULL,
      capacity INTEGER NOT NULL DEFAULT 4,
      status   TEXT    NOT NULL DEFAULT 'free'
    )
  ''';

  static const _createCustomers = '''
    CREATE TABLE customers (
      id         INTEGER PRIMARY KEY AUTOINCREMENT,
      name       TEXT NOT NULL,
      phone      TEXT,
      address    TEXT,
      created_at TEXT NOT NULL
    )
  ''';

  static const _createOrders = '''
    CREATE TABLE orders (
      id               INTEGER PRIMARY KEY AUTOINCREMENT,
      type             TEXT    NOT NULL,
      table_id         INTEGER,
      customer_id      INTEGER,
      delivery_address TEXT,
      status           TEXT    NOT NULL DEFAULT 'pending',
      discount_type    TEXT,
      discount_value   REAL    NOT NULL DEFAULT 0,
      tax_percent      REAL    NOT NULL DEFAULT 0,
      subtotal         REAL    NOT NULL DEFAULT 0,
      discount_amount  REAL    NOT NULL DEFAULT 0,
      tax_amount       REAL    NOT NULL DEFAULT 0,
      total            REAL    NOT NULL DEFAULT 0,
      note             TEXT,
      created_at       TEXT    NOT NULL,
      completed_at     TEXT,
      FOREIGN KEY (table_id)    REFERENCES cafe_tables (id),
      FOREIGN KEY (customer_id) REFERENCES customers   (id)
    )
  ''';

  static const _createOrderItems = '''
    CREATE TABLE order_items (
      id             INTEGER PRIMARY KEY AUTOINCREMENT,
      order_id       INTEGER NOT NULL,
      menu_item_id   INTEGER NOT NULL,
      name_snapshot  TEXT    NOT NULL,
      price_snapshot REAL    NOT NULL,
      quantity       INTEGER NOT NULL DEFAULT 1,
      note           TEXT,
      FOREIGN KEY (order_id) REFERENCES orders (id) ON DELETE CASCADE
    )
  ''';

  static const _createPayments = '''
    CREATE TABLE payments (
      id              INTEGER PRIMARY KEY AUTOINCREMENT,
      order_id        INTEGER NOT NULL UNIQUE,
      method          TEXT    NOT NULL,
      amount_tendered REAL    NOT NULL,
      change_amount   REAL    NOT NULL DEFAULT 0,
      paid_at         TEXT    NOT NULL,
      FOREIGN KEY (order_id) REFERENCES orders (id)
    )
  ''';

  static const _createInventoryItems = '''
    CREATE TABLE inventory_items (
      id                  INTEGER PRIMARY KEY AUTOINCREMENT,
      name                TEXT NOT NULL,
      unit                TEXT NOT NULL,
      quantity            REAL NOT NULL DEFAULT 0,
      low_stock_threshold REAL NOT NULL DEFAULT 0,
      updated_at          TEXT NOT NULL
    )
  ''';

  static const _createInventoryLogs = '''
    CREATE TABLE inventory_logs (
      id                INTEGER PRIMARY KEY AUTOINCREMENT,
      inventory_item_id INTEGER NOT NULL,
      change_amount     REAL    NOT NULL,
      reason            TEXT,
      created_at        TEXT    NOT NULL,
      FOREIGN KEY (inventory_item_id) REFERENCES inventory_items (id) ON DELETE CASCADE
    )
  ''';

  static const _createSettings = '''
    CREATE TABLE settings (
      key   TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )
  ''';

  // ── Helper methods ───────────────────────────────────────────────────

  Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await database;
    return db.insert(table, data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> update(
    String table,
    Map<String, dynamic> data,
    String where,
    List<dynamic> whereArgs,
  ) async {
    final db = await database;
    return db.update(table, data, where: where, whereArgs: whereArgs);
  }

  Future<int> delete(
    String table,
    String where,
    List<dynamic> whereArgs,
  ) async {
    final db = await database;
    return db.delete(table, where: where, whereArgs: whereArgs);
  }

  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
  }) async {
    final db = await database;
    return db.query(
      table,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
    );
  }

  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<dynamic>? args,
  ]) async {
    final db = await database;
    return db.rawQuery(sql, args);
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
