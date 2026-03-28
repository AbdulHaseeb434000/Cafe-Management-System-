import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/database/database_helper.dart';
import '../../core/constants/app_constants.dart';

const _backupVersion = 1;

class BackupConflictSummary {
  final Map<String, int> newCounts;
  final Map<String, int> existingCounts;
  final DateTime? exportedAt;
  final String? deviceName;

  const BackupConflictSummary({
    required this.newCounts,
    required this.existingCounts,
    this.exportedAt,
    this.deviceName,
  });

  int get totalNew => newCounts.values.fold(0, (a, b) => a + b);
  int get totalExisting => existingCounts.values.fold(0, (a, b) => a + b);
}

class BackupService {
  final DatabaseHelper _db;
  BackupService(this._db);

  // ── Export ───────────────────────────────────────────────────────────

  Future<void> export() async {
    final payload = await _buildPayload();
    final json = const JsonEncoder.withIndent('  ').convert(payload);

    final dir = await getTemporaryDirectory();
    final now = DateTime.now();
    final fileName =
        'cafedesk_backup_${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}.cafedesk';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(json, encoding: utf8);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        subject: 'CafeDesk Backup - $fileName',
      ),
    );
  }

  Future<Map<String, dynamic>> _buildPayload() async {
    final db = await _db.database;
    return {
      'meta': {
        'version': _backupVersion,
        'app_version': AppConstants.appVersion,
        'exported_at': DateTime.now().toIso8601String(),
        'device': Platform.isAndroid ? 'Android' : 'Unknown',
      },
      'data': {
        'categories': await db.query('categories'),
        'menu_items': await db.query('menu_items'),
        'cafe_tables': await db.query('cafe_tables'),
        'customers': await db.query('customers'),
        'orders': await db.query('orders'),
        'order_items': await db.query('order_items'),
        'payments': await db.query('payments'),
        'inventory_items': await db.query('inventory_items'),
        'inventory_logs': await db.query('inventory_logs'),
        'settings': await db.query('settings'),
      },
    };
  }

  // ── Import ───────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> pickAndParse() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['cafedesk', 'json'],
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return null;
    final path = result.files.single.path;
    if (path == null) return null;

    final content = await File(path).readAsString(encoding: utf8);
    final payload = jsonDecode(content) as Map<String, dynamic>;

    final version = payload['meta']?['version'] as int? ?? 0;
    if (version != _backupVersion) {
      throw Exception('Unsupported backup version: $version');
    }
    return payload;
  }

  Future<BackupConflictSummary> analyze(Map<String, dynamic> payload) async {
    final data = payload['data'] as Map<String, dynamic>;
    final db = await _db.database;

    final tableKeys = {
      'categories': 'categories',
      'menu_items': 'menu_items',
      'cafe_tables': 'cafe_tables',
      'customers': 'customers',
      'orders': 'orders',
      'order_items': 'order_items',
      'payments': 'payments',
      'inventory_items': 'inventory_items',
      'inventory_logs': 'inventory_logs',
    };

    final existingCounts = <String, int>{};
    final newCounts = <String, int>{};

    for (final entry in tableKeys.entries) {
      final items = data[entry.key] as List? ?? [];
      int existing = 0;
      for (final row in items) {
        final uuid = (row as Map<String, dynamic>)['uuid'] as String?;
        if (uuid == null) continue;
        final rows = await db.query(entry.value,
            where: 'uuid = ?', whereArgs: [uuid], limit: 1);
        if (rows.isNotEmpty) existing++;
      }
      existingCounts[entry.key] = existing;
      newCounts[entry.key] = items.length - existing;
    }

    final meta = payload['meta'] as Map<String, dynamic>?;
    return BackupConflictSummary(
      newCounts: newCounts,
      existingCounts: existingCounts,
      exportedAt: meta?['exported_at'] != null
          ? DateTime.tryParse(meta!['exported_at'] as String)
          : null,
      deviceName: meta?['device'] as String?,
    );
  }

  Future<void> importMerge(Map<String, dynamic> payload) async {
    final data = payload['data'] as Map<String, dynamic>;
    await _db.transaction((txn) async {
      await _insertCategories(txn, data['categories'] as List? ?? []);
      await _insertMenuItems(txn, data['menu_items'] as List? ?? []);
      await _insertTables(txn, data['cafe_tables'] as List? ?? []);
      await _insertCustomers(txn, data['customers'] as List? ?? []);
      await _insertOrders(txn, data['orders'] as List? ?? []);
      await _insertOrderItems(txn, data['order_items'] as List? ?? []);
      await _insertPayments(txn, data['payments'] as List? ?? []);
      await _insertInventoryItems(txn, data['inventory_items'] as List? ?? [],
          replace: true);
      await _insertInventoryLogs(txn, data['inventory_logs'] as List? ?? []);
      for (final row in (data['settings'] as List? ?? [])) {
        final m = Map<String, dynamic>.from(row as Map);
        await txn.insert('settings', m,
            conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
  }

  Future<void> importReplace(Map<String, dynamic> payload) async {
    final data = payload['data'] as Map<String, dynamic>;
    await _db.transaction((txn) async {
      for (final t in [
        'inventory_logs', 'inventory_items', 'payments', 'order_items',
        'orders', 'customers', 'cafe_tables', 'menu_items', 'categories', 'settings',
      ]) {
        await txn.delete(t);
      }
      await _insertCategories(txn, data['categories'] as List? ?? []);
      await _insertMenuItems(txn, data['menu_items'] as List? ?? []);
      await _insertTables(txn, data['cafe_tables'] as List? ?? []);
      await _insertCustomers(txn, data['customers'] as List? ?? []);
      await _insertOrders(txn, data['orders'] as List? ?? []);
      await _insertOrderItems(txn, data['order_items'] as List? ?? []);
      await _insertPayments(txn, data['payments'] as List? ?? []);
      await _insertInventoryItems(txn, data['inventory_items'] as List? ?? []);
      await _insertInventoryLogs(txn, data['inventory_logs'] as List? ?? []);
      for (final row in (data['settings'] as List? ?? [])) {
        await txn.insert('settings', Map<String, dynamic>.from(row as Map));
      }
    });
  }

  // ── Private insert helpers (handle FK re-resolution) ─────────────────

  Future<void> _insertCategories(Transaction txn, List rows) async {
    for (final row in rows) {
      final m = Map<String, dynamic>.from(row as Map)..remove('id');
      await txn.insert('categories', m,
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> _insertMenuItems(Transaction txn, List rows) async {
    for (final row in rows) {
      final m = Map<String, dynamic>.from(row as Map)..remove('id');
      final catUuid = m['category_uuid'] as String?;
      if (catUuid != null) {
        final r = await txn.query('categories',
            columns: ['id'], where: 'uuid = ?', whereArgs: [catUuid], limit: 1);
        if (r.isNotEmpty) m['category_id'] = r.first['id'];
      }
      await txn.insert('menu_items', m,
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> _insertTables(Transaction txn, List rows) async {
    for (final row in rows) {
      final m = Map<String, dynamic>.from(row as Map)..remove('id');
      await txn.insert('cafe_tables', m,
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> _insertCustomers(Transaction txn, List rows) async {
    for (final row in rows) {
      final m = Map<String, dynamic>.from(row as Map)..remove('id');
      await txn.insert('customers', m,
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> _insertOrders(Transaction txn, List rows) async {
    for (final row in rows) {
      final m = Map<String, dynamic>.from(row as Map)..remove('id');
      final tUuid = m['table_uuid'] as String?;
      if (tUuid != null) {
        final r = await txn.query('cafe_tables',
            columns: ['id'], where: 'uuid = ?', whereArgs: [tUuid], limit: 1);
        m['table_id'] = r.isNotEmpty ? r.first['id'] : null;
      }
      final cUuid = m['customer_uuid'] as String?;
      if (cUuid != null) {
        final r = await txn.query('customers',
            columns: ['id'], where: 'uuid = ?', whereArgs: [cUuid], limit: 1);
        m['customer_id'] = r.isNotEmpty ? r.first['id'] : null;
      }
      await txn.insert('orders', m,
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> _insertOrderItems(Transaction txn, List rows) async {
    for (final row in rows) {
      final m = Map<String, dynamic>.from(row as Map)..remove('id');
      final oUuid = m['order_uuid'] as String?;
      if (oUuid != null) {
        final r = await txn.query('orders',
            columns: ['id'], where: 'uuid = ?', whereArgs: [oUuid], limit: 1);
        if (r.isNotEmpty) m['order_id'] = r.first['id'];
      }
      final iUuid = m['menu_item_uuid'] as String?;
      if (iUuid != null) {
        final r = await txn.query('menu_items',
            columns: ['id'], where: 'uuid = ?', whereArgs: [iUuid], limit: 1);
        if (r.isNotEmpty) m['menu_item_id'] = r.first['id'];
      }
      await txn.insert('order_items', m,
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> _insertPayments(Transaction txn, List rows) async {
    for (final row in rows) {
      final m = Map<String, dynamic>.from(row as Map)..remove('id');
      final oUuid = m['order_uuid'] as String?;
      if (oUuid != null) {
        final r = await txn.query('orders',
            columns: ['id'], where: 'uuid = ?', whereArgs: [oUuid], limit: 1);
        if (r.isNotEmpty) m['order_id'] = r.first['id'];
      }
      await txn.insert('payments', m,
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> _insertInventoryItems(Transaction txn, List rows,
      {bool replace = false}) async {
    for (final row in rows) {
      final m = Map<String, dynamic>.from(row as Map)..remove('id');
      await txn.insert('inventory_items', m,
          conflictAlgorithm:
              replace ? ConflictAlgorithm.replace : ConflictAlgorithm.ignore);
    }
  }

  Future<void> _insertInventoryLogs(Transaction txn, List rows) async {
    for (final row in rows) {
      final m = Map<String, dynamic>.from(row as Map)..remove('id');
      final iUuid = m['inventory_item_uuid'] as String?;
      if (iUuid != null) {
        final r = await txn.query('inventory_items',
            columns: ['id'], where: 'uuid = ?', whereArgs: [iUuid], limit: 1);
        if (r.isNotEmpty) m['inventory_item_id'] = r.first['id'];
      }
      await txn.insert('inventory_logs', m,
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }
}
