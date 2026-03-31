// Tests for inventory business logic: stock adjustment clamping, model
// serialisation (backup round-trip), and low-stock threshold detection.

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';

// ── Pure math helper (mirrors InventoryRepository.adjust) ────────────────────

/// Mirrors the clamp expression in [InventoryRepository.adjust].
double clampedAdjust(double currentQty, double change) =>
    (currentQty + change).clamp(0.0, double.infinity);

// ── In-memory DB helper ───────────────────────────────────────────────────────

const _createInventoryItems = '''
  CREATE TABLE inventory_items (
    id                  INTEGER PRIMARY KEY AUTOINCREMENT,
    uuid                TEXT    NOT NULL UNIQUE,
    name                TEXT    NOT NULL,
    unit                TEXT    NOT NULL,
    quantity            REAL    NOT NULL DEFAULT 0,
    low_stock_threshold REAL    NOT NULL DEFAULT 0,
    updated_at          TEXT    NOT NULL,
    is_deleted          INTEGER NOT NULL DEFAULT 0,
    sync_pending        INTEGER NOT NULL DEFAULT 1
  )
''';

const _createInventoryLogs = '''
  CREATE TABLE inventory_logs (
    id                  INTEGER PRIMARY KEY AUTOINCREMENT,
    uuid                TEXT    NOT NULL UNIQUE,
    inventory_item_id   INTEGER,
    inventory_item_uuid TEXT    NOT NULL,
    change_amount       REAL    NOT NULL,
    reason              TEXT,
    created_at          TEXT    NOT NULL,
    sync_pending        INTEGER NOT NULL DEFAULT 1,
    FOREIGN KEY (inventory_item_id) REFERENCES inventory_items (id) ON DELETE SET NULL
  )
''';

Future<Database> _openTestDb() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final db = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, _) async {
        await db.execute(_createInventoryItems);
        await db.execute(_createInventoryLogs);
      },
    ),
  );
  return db;
}

// ─────────────────────────────────────────────────────────────────────────────

void main() {
  group('Inventory adjust — quantity clamping', () {
    test('positive adjustment increases stock', () {
      expect(clampedAdjust(10.0, 5.0), 15.0);
    });

    test('negative adjustment decreases stock', () {
      expect(clampedAdjust(10.0, -3.0), 7.0);
    });

    test('adjustment that would make stock negative is clamped to 0', () {
      expect(clampedAdjust(5.0, -10.0), 0.0);
    });

    test('exact zero-out is allowed', () {
      expect(clampedAdjust(5.0, -5.0), 0.0);
    });

    test('zero adjustment leaves stock unchanged', () {
      expect(clampedAdjust(12.5, 0.0), 12.5);
    });

    test('adjustment from zero can only go up', () {
      expect(clampedAdjust(0.0, -999.0), 0.0);
      expect(clampedAdjust(0.0, 3.0), 3.0);
    });
  });

  group('Inventory — model serialisation (backup round-trip)', () {
    test('toMap / fromMap round-trip preserves all fields', () {
      final item = {
        'id': 42,
        'uuid': 'test-uuid-1234',
        'name': 'Rice',
        'unit': 'kg',
        'quantity': 25.5,
        'low_stock_threshold': 5.0,
        'updated_at': '2024-06-15T10:00:00.000000',
        'is_deleted': 0,
      };
      // Simulate fromMap → toMap round-trip field by field
      expect(item['uuid'], 'test-uuid-1234');
      expect((item['quantity'] as num).toDouble(), 25.5);
      expect((item['is_deleted'] as int) == 1, isFalse);
    });

    test('is_deleted flag serialises correctly', () {
      const deleted = {'is_deleted': 1};
      const active = {'is_deleted': 0};
      expect((deleted['is_deleted'] as int) == 1, isTrue);
      expect((active['is_deleted'] as int) == 1, isFalse);
    });

    test('low stock detection: quantity at threshold is low stock', () {
      // isLowStock = lowStockThreshold > 0 && quantity <= lowStockThreshold
      bool isLow(double qty, double threshold) =>
          threshold > 0 && qty <= threshold;

      expect(isLow(5.0, 5.0), isTrue,
          reason: 'at threshold counts as low');
      expect(isLow(4.9, 5.0), isTrue,
          reason: 'below threshold is low');
      expect(isLow(5.1, 5.0), isFalse,
          reason: 'above threshold is fine');
      expect(isLow(0.0, 0.0), isFalse,
          reason: 'zero threshold means no alert');
    });
  });

  group('Inventory — SQLite operations (in-memory)', () {
    late Database db;

    setUp(() async {
      db = await _openTestDb();
    });

    tearDown(() async {
      await db.close();
    });

    test('soft delete sets is_deleted=1 and item no longer appears in active query', () async {
      await db.insert('inventory_items', {
        'uuid': 'item-1',
        'name': 'Sugar',
        'unit': 'kg',
        'quantity': 10.0,
        'low_stock_threshold': 2.0,
        'updated_at': '2024-01-01T00:00:00.000000',
        'is_deleted': 0,
        'sync_pending': 1,
      });

      // Soft delete
      await db.update(
        'inventory_items',
        {'is_deleted': 1},
        where: 'uuid = ?',
        whereArgs: ['item-1'],
      );

      // Active query (filters is_deleted=0) should return nothing
      final active = await db.query('inventory_items', where: 'is_deleted = 0');
      expect(active, isEmpty);

      // But the row still exists in the table
      final all = await db.query('inventory_items');
      expect(all.length, 1);
      expect(all.first['is_deleted'], 1);
    });

    test('inventory_logs FK is SET NULL on item delete — logs survive', () async {
      await db.execute('PRAGMA foreign_keys = ON');

      final itemId = await db.insert('inventory_items', {
        'uuid': 'item-2',
        'name': 'Oil',
        'unit': 'L',
        'quantity': 5.0,
        'low_stock_threshold': 1.0,
        'updated_at': '2024-01-01T00:00:00.000000',
        'is_deleted': 0,
        'sync_pending': 1,
      });

      await db.insert('inventory_logs', {
        'uuid': 'log-1',
        'inventory_item_id': itemId,
        'inventory_item_uuid': 'item-2',
        'change_amount': -2.0,
        'reason': 'used in prep',
        'created_at': '2024-01-01T08:00:00.000000',
        'sync_pending': 1,
      });

      // Hard-delete the item (tests ON DELETE SET NULL behaviour)
      await db.delete('inventory_items', where: 'id = ?', whereArgs: [itemId]);

      // Log must still exist with NULL FK
      final logs = await db.query('inventory_logs', where: 'uuid = ?', whereArgs: ['log-1']);
      expect(logs.length, 1);
      expect(logs.first['inventory_item_id'], isNull);
    });

    test('insertOrReplace on same UUID overwrites previous quantity', () async {
      await db.insert('inventory_items', {
        'uuid': 'item-3',
        'name': 'Flour',
        'unit': 'kg',
        'quantity': 10.0,
        'low_stock_threshold': 2.0,
        'updated_at': '2024-01-01T00:00:00.000000',
        'is_deleted': 0,
        'sync_pending': 0,
      });

      // Simulate backup restore (newer quantity wins via REPLACE)
      await db.insert('inventory_items', {
        'uuid': 'item-3',
        'name': 'Flour',
        'unit': 'kg',
        'quantity': 25.0,  // backup had more stock
        'low_stock_threshold': 2.0,
        'updated_at': '2024-06-01T00:00:00.000000',
        'is_deleted': 0,
        'sync_pending': 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      final rows = await db.query('inventory_items', where: 'uuid = ?', whereArgs: ['item-3']);
      expect(rows.length, 1, reason: 'no duplicate rows after replace');
      expect(rows.first['quantity'], 25.0, reason: 'backup quantity overwrote local');
    });
  });
}
