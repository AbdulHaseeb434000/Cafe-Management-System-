import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../models/inventory_item_model.dart';
import '../models/inventory_log_model.dart';
import '../core/utils/date_helpers.dart';
import 'activity_log_repository.dart';

class InventoryRepository {
  final DatabaseHelper _db;
  InventoryRepository(this._db);

  static const _itemsTable = 'inventory_items';
  static const _logsTable = 'inventory_logs';

  Future<List<InventoryItemModel>> getAll() async {
    final rows = await _db.query(_itemsTable, orderBy: 'name ASC');
    return rows.map(InventoryItemModel.fromMap).toList();
  }

  Future<List<InventoryItemModel>> getLowStock() async {
    final rows = await _db.rawQuery('''
      SELECT * FROM inventory_items
      WHERE low_stock_threshold > 0 AND quantity <= low_stock_threshold
      ORDER BY name ASC
    ''');
    return rows.map(InventoryItemModel.fromMap).toList();
  }

  Future<InventoryItemModel?> getById(int id) async {
    final rows =
        await _db.query(_itemsTable, where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : InventoryItemModel.fromMap(rows.first);
  }

  Future<InventoryItemModel> insert(InventoryItemModel item) async {
    final id = await _db.insert(_itemsTable, item.toMap());
    ActivityLogRepository.instance.log(
      actionType: 'inventory_item_created',
      entityType: 'inventory_item',
      entityName: item.name,
      details: 'Unit: ${item.unit}, Qty: ${item.quantity}',
    );
    return item.copyWith(id: id);
  }

  Future<void> update(InventoryItemModel item) async {
    await _db.update(_itemsTable, item.toMap(), 'id = ?', [item.id]);
    ActivityLogRepository.instance.log(
      actionType: 'inventory_item_updated',
      entityType: 'inventory_item',
      entityName: item.name,
    );
  }

  Future<void> delete(int id) async {
    final existing = await getById(id);
    await _db.delete(_itemsTable, 'id = ?', [id]);
    if (existing != null) {
      ActivityLogRepository.instance.log(
        actionType: 'inventory_item_deleted',
        entityType: 'inventory_item',
        entityName: existing.name,
      );
    }
  }

  Future<InventoryItemModel> adjust(
    InventoryItemModel item,
    double change,
    String? reason,
  ) async {
    final newQty = (item.quantity + change).clamp(0.0, double.infinity);
    final updated = item.copyWith(quantity: newQty, updatedAt: DateTime.now());
    await _db.update(_itemsTable, {
      'quantity': newQty,
      'updated_at': DateHelpers.toIso(updated.updatedAt),
    }, 'id = ?', [item.id]);

    final log = InventoryLogModel.create(
      inventoryItemId: item.id!,
      inventoryItemUuid: item.uuid,
      changeAmount: change,
      reason: reason,
    );
    await _db.insert(_logsTable, log.toMap());
    final sign = change >= 0 ? '+' : '';
    ActivityLogRepository.instance.log(
      actionType: 'inventory_adjusted',
      entityType: 'inventory_item',
      entityName: item.name,
      details: '$sign${change.toStringAsFixed(2)} ${item.unit}'
          '${reason != null && reason.isNotEmpty ? ' — $reason' : ''}',
    );
    return updated;
  }

  Future<List<InventoryLogModel>> getLogs(int itemId) async {
    final rows = await _db.query(
      _logsTable,
      where: 'inventory_item_id = ?',
      whereArgs: [itemId],
      orderBy: 'created_at DESC',
      limit: 50,
    );
    return rows.map(InventoryLogModel.fromMap).toList();
  }

  Future<void> insertOrIgnoreItem(InventoryItemModel item) async {
    await _db.insert(_itemsTable, item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertOrIgnoreLog(InventoryLogModel log) async {
    await _db.insert(_logsTable, log.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }
}
