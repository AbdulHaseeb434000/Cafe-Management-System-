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
      onUpgrade: _onUpgrade,
      onConfigure: (db) async => await db.execute('PRAGMA foreign_keys = ON'),
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();
    batch.execute(_createCategories);
    batch.execute(_createMenuItems);
    batch.execute(_createTables);
    batch.execute(_createCustomers);
    batch.execute(_createOrders);
    batch.execute(_createOrderItems);
    batch.execute(_createPayments);
    batch.execute(_createInventoryItems);
    batch.execute(_createInventoryLogs);
    batch.execute(_createSettings);
    batch.execute(_createActivityLogs);
    await batch.commit(noResult: true);
    await _seedDefaultSettings(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(_createActivityLogs);
    }
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
      AppConstants.settingPosPrinterAddress: '',
      AppConstants.settingPosPrinterName: '',
      AppConstants.settingKitchenPrinterAddress: '',
      AppConstants.settingKitchenPrinterName: '',
    };
    for (final entry in defaults.entries) {
      await db.insert('settings', {'key': entry.key, 'value': entry.value},
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  // ── DDL ─────────────────────────────────────────────────────────────

  static const _createCategories = '''
    CREATE TABLE categories (
      id         INTEGER PRIMARY KEY AUTOINCREMENT,
      uuid       TEXT    NOT NULL UNIQUE,
      name       TEXT    NOT NULL,
      icon       TEXT    NOT NULL DEFAULT 'restaurant',
      sort_order INTEGER NOT NULL DEFAULT 0,
      created_at TEXT    NOT NULL
    )
  ''';

  static const _createMenuItems = '''
    CREATE TABLE menu_items (
      id            INTEGER PRIMARY KEY AUTOINCREMENT,
      uuid          TEXT    NOT NULL UNIQUE,
      category_id   INTEGER NOT NULL,
      category_uuid TEXT    NOT NULL,
      name          TEXT    NOT NULL,
      price         REAL    NOT NULL,
      description   TEXT,
      is_available  INTEGER NOT NULL DEFAULT 1,
      image_path    TEXT,
      created_at    TEXT    NOT NULL,
      FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE CASCADE
    )
  ''';

  static const _createTables = '''
    CREATE TABLE cafe_tables (
      id       INTEGER PRIMARY KEY AUTOINCREMENT,
      uuid     TEXT    NOT NULL UNIQUE,
      name     TEXT    NOT NULL,
      capacity INTEGER NOT NULL DEFAULT 4,
      status   TEXT    NOT NULL DEFAULT 'free'
    )
  ''';

  static const _createCustomers = '''
    CREATE TABLE customers (
      id         INTEGER PRIMARY KEY AUTOINCREMENT,
      uuid       TEXT NOT NULL UNIQUE,
      name       TEXT NOT NULL,
      phone      TEXT,
      address    TEXT,
      created_at TEXT NOT NULL
    )
  ''';

  static const _createOrders = '''
    CREATE TABLE orders (
      id               INTEGER PRIMARY KEY AUTOINCREMENT,
      uuid             TEXT    NOT NULL UNIQUE,
      type             TEXT    NOT NULL,
      table_id         INTEGER,
      table_uuid       TEXT,
      customer_id      INTEGER,
      customer_uuid    TEXT,
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
      uuid           TEXT    NOT NULL UNIQUE,
      order_id       INTEGER NOT NULL,
      order_uuid     TEXT    NOT NULL,
      menu_item_id   INTEGER NOT NULL,
      menu_item_uuid TEXT    NOT NULL,
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
      uuid            TEXT    NOT NULL UNIQUE,
      order_id        INTEGER NOT NULL UNIQUE,
      order_uuid      TEXT    NOT NULL,
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
      uuid                TEXT NOT NULL UNIQUE,
      name                TEXT NOT NULL,
      unit                TEXT NOT NULL,
      quantity            REAL NOT NULL DEFAULT 0,
      low_stock_threshold REAL NOT NULL DEFAULT 0,
      updated_at          TEXT NOT NULL
    )
  ''';

  static const _createInventoryLogs = '''
    CREATE TABLE inventory_logs (
      id                  INTEGER PRIMARY KEY AUTOINCREMENT,
      uuid                TEXT    NOT NULL UNIQUE,
      inventory_item_id   INTEGER NOT NULL,
      inventory_item_uuid TEXT    NOT NULL,
      change_amount       REAL    NOT NULL,
      reason              TEXT,
      created_at          TEXT    NOT NULL,
      FOREIGN KEY (inventory_item_id) REFERENCES inventory_items (id) ON DELETE CASCADE
    )
  ''';

  static const _createSettings = '''
    CREATE TABLE settings (
      key   TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )
  ''';

  static const _createActivityLogs = '''
    CREATE TABLE activity_logs (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      uuid        TEXT    NOT NULL UNIQUE,
      action_type TEXT    NOT NULL,
      entity_type TEXT    NOT NULL,
      entity_name TEXT    NOT NULL,
      details     TEXT,
      created_at  TEXT    NOT NULL
    )
  ''';

  // ── Generic helpers ──────────────────────────────────────────────────

  Future<int> insert(String table, Map<String, dynamic> data,
      {ConflictAlgorithm conflictAlgorithm = ConflictAlgorithm.replace}) async {
    final db = await database;
    return db.insert(table, data, conflictAlgorithm: conflictAlgorithm);
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

  Future<int> delete(String table, String where, List<dynamic> whereArgs) async {
    final db = await database;
    return db.delete(table, where: where, whereArgs: whereArgs);
  }

  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    return db.query(table,
        where: where,
        whereArgs: whereArgs,
        orderBy: orderBy,
        limit: limit,
        offset: offset);
  }

  Future<List<Map<String, dynamic>>> rawQuery(String sql,
      [List<dynamic>? args]) async {
    final db = await database;
    return db.rawQuery(sql, args);
  }

  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    final db = await database;
    return db.transaction(action);
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
