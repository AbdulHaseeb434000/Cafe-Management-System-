import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/database/database_helper.dart';
import '../supabase/supabase_service.dart';

/// Offline-first sync between local SQLite and Supabase.
///
/// Push: local rows with sync_pending=1 → upserted to Supabase by uuid.
/// Pull: all Supabase rows for the restaurant → upserted into local SQLite.
///       Pull is performed once per device (first login); after that only push runs.
///
/// Call [SyncService.instance.start] once in main() after Supabase is ready.
class SyncService {
  SyncService._();
  static final instance = SyncService._();

  bool _pushing = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  // Tables pushed in insertion order (no FK issues for push)
  static const _pushOrder = [
    'categories',
    'menu_items',
    'cafe_tables',
    'customers',
    'orders',
    'order_items',
    'payments',
    'inventory_items',
    'inventory_logs',
    'expenses',
  ];

  // ── Lifecycle ────────────────────────────────────────────────────────────

  /// Call once after Supabase.initialize(). Starts push + connectivity watcher.
  void start() {
    unawaited(_syncOnStart());
    _connectivitySub ??= Connectivity()
        .onConnectivityChanged
        .listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online) unawaited(push());
    });
  }

  /// Re-trigger sync after login without adding another connectivity listener.
  Future<void> triggerOnLogin() => _syncOnStart();

  void dispose() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
  }

  Future<void> _syncOnStart() async {
    if (!SupabaseService.isSignedIn) return;
    await push();
    await _initialPullIfNeeded();
  }

  // ── Push: local → Supabase ───────────────────────────────────────────────

  /// Upserts all sync_pending=1 rows to Supabase for the current restaurant.
  Future<void> push() async {
    if (_pushing) return;
    if (!SupabaseService.isSignedIn) return;
    _pushing = true;
    try {
      final staff = await SupabaseService.fetchStaffRecord();
      if (staff == null) return;
      final restaurantId = staff['restaurant_id'] as String;
      final db = await DatabaseHelper.instance.database;

      for (final table in _pushOrder) {
        try {
          final pending = await db.query(table, where: 'sync_pending = 1');
          if (pending.isEmpty) continue;

          // Capture the exact UUIDs we are about to push so that rows written
          // to the DB between the SELECT and the mark-synced UPDATE are not
          // incorrectly cleared (they would never reach Supabase otherwise).
          final pushedUuids =
              pending.map((row) => row['uuid'] as String).toList();

          final payload = pending.map((row) {
            return {
              ...Map<String, dynamic>.from(row)
                ..remove('id')
                ..remove('sync_pending'),
              'restaurant_id': restaurantId,
            };
          }).toList();

          await SupabaseService.client
              .from(table)
              .upsert(payload, onConflict: 'uuid');

          // Mark only the rows we just pushed as synced.
          final placeholders = List.filled(pushedUuids.length, '?').join(', ');
          await db.rawUpdate(
            'UPDATE $table SET sync_pending = 0 WHERE uuid IN ($placeholders)',
            pushedUuids,
          );
        } catch (_) {
          // Per-table failure is non-fatal; try remaining tables
        }
      }
    } finally {
      _pushing = false;
    }
  }

  // ── Pull: Supabase → local (first login / new device) ───────────────────

  Future<void> _initialPullIfNeeded() async {
    final db = await DatabaseHelper.instance.database;
    final flag = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: ['initial_pull_done'],
    );
    if (flag.isNotEmpty) return;

    await _fullPull();

    await db.insert(
      'settings',
      {'key': 'initial_pull_done', 'value': '1'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _fullPull() async {
    final staff = await SupabaseService.fetchStaffRecord();
    if (staff == null) return;
    final restaurantId = staff['restaurant_id'] as String;
    final db = await DatabaseHelper.instance.database;

    // Pull in dependency order so FK resolution works
    await _pull(db, restaurantId, 'categories', _upsertCategory);
    await _pull(db, restaurantId, 'menu_items', _upsertMenuItem);
    await _pull(db, restaurantId, 'cafe_tables', _upsertCafeTable);
    await _pull(db, restaurantId, 'customers', _upsertCustomer);
    await _pull(db, restaurantId, 'orders', _upsertOrder);
    await _pull(db, restaurantId, 'order_items', _upsertOrderItem);
    await _pull(db, restaurantId, 'payments', _upsertPayment);
    await _pull(db, restaurantId, 'inventory_items', _upsertInventoryItem);
    await _pull(db, restaurantId, 'inventory_logs', _upsertInventoryLog);
    await _pull(db, restaurantId, 'expenses', _upsertExpense);
  }

  Future<void> _pull(
    Database db,
    String restaurantId,
    String table,
    Future<void> Function(Database, Map<String, dynamic>) upsertFn,
  ) async {
    try {
      final rows = await SupabaseService.client
          .from(table)
          .select()
          .eq('restaurant_id', restaurantId);
      for (final row in rows as List) {
        await upsertFn(db, Map<String, dynamic>.from(row as Map));
      }
    } catch (_) {}
  }

  // ── Per-table upsert helpers ─────────────────────────────────────────────

  Future<void> _upsertCategory(Database db, Map<String, dynamic> r) =>
      _upsertByUuid(db, 'categories', {
        'uuid': r['uuid'],
        'name': r['name'],
        'icon': r['icon'] ?? 'restaurant',
        'sort_order': r['sort_order'] ?? 0,
        'created_at': r['created_at'],
        'sync_pending': 0,
      });

  Future<void> _upsertMenuItem(Database db, Map<String, dynamic> r) async {
    final catId = await _localId(db, 'categories', r['category_uuid'] as String?);
    if (catId == null) return;
    await _upsertByUuid(db, 'menu_items', {
      'uuid': r['uuid'],
      'category_id': catId,
      'category_uuid': r['category_uuid'],
      'name': r['name'],
      'price': r['price'],
      'description': r['description'],
      'is_available': (r['is_available'] == true) ? 1 : 0,
      'image_path': r['image_path'],
      'created_at': r['created_at'],
      'sync_pending': 0,
    });
  }

  Future<void> _upsertCafeTable(Database db, Map<String, dynamic> r) =>
      _upsertByUuid(db, 'cafe_tables', {
        'uuid': r['uuid'],
        'name': r['name'],
        'capacity': r['capacity'] ?? 4,
        'status': r['status'] ?? 'free',
        'sync_pending': 0,
      });

  Future<void> _upsertCustomer(Database db, Map<String, dynamic> r) =>
      _upsertByUuid(db, 'customers', {
        'uuid': r['uuid'],
        'name': r['name'],
        'phone': r['phone'],
        'address': r['address'],
        'created_at': r['created_at'],
        'sync_pending': 0,
      });

  Future<void> _upsertOrder(Database db, Map<String, dynamic> r) async {
    final tableId = await _localId(db, 'cafe_tables', r['table_uuid'] as String?);
    final customerId = await _localId(db, 'customers', r['customer_uuid'] as String?);
    await _upsertByUuid(db, 'orders', {
      'uuid': r['uuid'],
      'type': r['type'],
      'table_id': tableId,
      'table_uuid': r['table_uuid'],
      'customer_id': customerId,
      'customer_uuid': r['customer_uuid'],
      'delivery_address': r['delivery_address'],
      'status': r['status'],
      'discount_type': r['discount_type'] ?? 'flat',
      'discount_value': r['discount_value'] ?? 0,
      'tax_percent': r['tax_percent'] ?? 0,
      'subtotal': r['subtotal'] ?? 0,
      'discount_amount': r['discount_amount'] ?? 0,
      'tax_amount': r['tax_amount'] ?? 0,
      'total': r['total'] ?? 0,
      'note': r['note'],
      'created_at': r['created_at'],
      'completed_at': r['completed_at'],
      'sync_pending': 0,
    });
  }

  Future<void> _upsertOrderItem(Database db, Map<String, dynamic> r) async {
    final orderId = await _localId(db, 'orders', r['order_uuid'] as String?);
    if (orderId == null) return;
    final menuItemId = await _localId(db, 'menu_items', r['menu_item_uuid'] as String?);
    await _upsertByUuid(db, 'order_items', {
      'uuid': r['uuid'],
      'order_id': orderId,
      'order_uuid': r['order_uuid'],
      'menu_item_id': menuItemId ?? 0,
      'menu_item_uuid': r['menu_item_uuid'],
      'name_snapshot': r['name_snapshot'],
      'price_snapshot': r['price_snapshot'],
      'quantity': r['quantity'] ?? 1,
      'note': r['note'],
      'sync_pending': 0,
    });
  }

  Future<void> _upsertPayment(Database db, Map<String, dynamic> r) async {
    final orderId = await _localId(db, 'orders', r['order_uuid'] as String?);
    if (orderId == null) return;
    await _upsertByUuid(db, 'payments', {
      'uuid': r['uuid'],
      'order_id': orderId,
      'order_uuid': r['order_uuid'],
      'method': r['method'],
      'amount_tendered': r['amount_tendered'] ?? 0,
      'change_amount': r['change_amount'] ?? 0,
      'paid_at': r['paid_at'],
      'sync_pending': 0,
    });
  }

  Future<void> _upsertInventoryItem(Database db, Map<String, dynamic> r) =>
      _upsertByUuid(db, 'inventory_items', {
        'uuid': r['uuid'],
        'name': r['name'],
        'unit': r['unit'],
        'quantity': r['quantity'] ?? 0,
        'low_stock_threshold': r['low_stock_threshold'] ?? 0,
        'updated_at': r['updated_at'],
        'sync_pending': 0,
      });

  Future<void> _upsertInventoryLog(Database db, Map<String, dynamic> r) async {
    final itemId = await _localId(db, 'inventory_items', r['inventory_item_uuid'] as String?);
    if (itemId == null) return;
    await _upsertByUuid(db, 'inventory_logs', {
      'uuid': r['uuid'],
      'inventory_item_id': itemId,
      'inventory_item_uuid': r['inventory_item_uuid'],
      'change_amount': r['change_amount'],
      'reason': r['reason'],
      'created_at': r['created_at'],
      'sync_pending': 0,
    });
  }

  Future<void> _upsertExpense(Database db, Map<String, dynamic> r) =>
      _upsertByUuid(db, 'expenses', {
        'uuid': r['uuid'],
        'category': r['category'] ?? 'other',
        'amount': r['amount'],
        'description': r['description'] ?? '',
        'date': r['date'],
        'created_at': r['created_at'],
        'sync_pending': 0,
      });

  // ── SQLite helpers ───────────────────────────────────────────────────────

  /// Resolve local integer id by uuid (returns null if not found).
  Future<int?> _localId(Database db, String table, String? uuid) async {
    if (uuid == null) return null;
    final rows = await db.query(
      table,
      columns: ['id'],
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
    return rows.isEmpty ? null : rows.first['id'] as int?;
  }

  /// Insert-or-update a row keyed by uuid, preserving the existing local id.
  Future<void> _upsertByUuid(
    Database db,
    String table,
    Map<String, dynamic> row,
  ) async {
    final uuid = row['uuid'] as String;
    final existing = await db.query(
      table,
      columns: ['id'],
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
    if (existing.isEmpty) {
      await db.insert(table, row, conflictAlgorithm: ConflictAlgorithm.ignore);
    } else {
      await db.update(table, row, where: 'uuid = ?', whereArgs: [uuid]);
    }
  }
}
