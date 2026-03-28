import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../models/menu_item_model.dart';
import 'activity_log_repository.dart';

class MenuItemRepository {
  final DatabaseHelper _db;
  MenuItemRepository(this._db);

  static const _table = 'menu_items';

  Future<List<MenuItemModel>> getAll() async {
    final rows = await _db.query(_table, orderBy: 'name ASC');
    return rows.map(MenuItemModel.fromMap).toList();
  }

  Future<List<MenuItemModel>> getByCategory(int categoryId) async {
    final rows = await _db.query(
      _table,
      where: 'category_id = ?',
      whereArgs: [categoryId],
      orderBy: 'name ASC',
    );
    return rows.map(MenuItemModel.fromMap).toList();
  }

  Future<List<MenuItemModel>> getAvailableByCategory(int categoryId) async {
    final rows = await _db.query(
      _table,
      where: 'category_id = ? AND is_available = 1',
      whereArgs: [categoryId],
      orderBy: 'name ASC',
    );
    return rows.map(MenuItemModel.fromMap).toList();
  }

  Future<MenuItemModel?> getById(int id) async {
    final rows = await _db.query(_table, where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : MenuItemModel.fromMap(rows.first);
  }

  Future<MenuItemModel> insert(MenuItemModel item) async {
    final id = await _db.insert(_table, item.toMap());
    ActivityLogRepository.instance.log(
      actionType: 'menu_item_created',
      entityType: 'menu_item',
      entityName: item.name,
      details: 'Price: ${item.price.toStringAsFixed(2)}',
    );
    return item.copyWith(id: id);
  }

  Future<void> update(MenuItemModel item) async {
    final existing = await getById(item.id!);
    await _db.update(_table, item.toMap(), 'id = ?', [item.id]);
    if (existing != null && existing.price != item.price) {
      ActivityLogRepository.instance.log(
        actionType: 'menu_item_price_changed',
        entityType: 'menu_item',
        entityName: item.name,
        details:
            '${existing.price.toStringAsFixed(2)} → ${item.price.toStringAsFixed(2)}',
      );
    } else {
      ActivityLogRepository.instance.log(
        actionType: 'menu_item_updated',
        entityType: 'menu_item',
        entityName: item.name,
      );
    }
  }

  Future<void> toggleAvailability(int id, bool isAvailable) async {
    await _db.update(_table, {'is_available': isAvailable ? 1 : 0}, 'id = ?', [id]);
    final item = await getById(id);
    if (item != null) {
      ActivityLogRepository.instance.log(
        actionType: 'menu_item_toggled',
        entityType: 'menu_item',
        entityName: item.name,
        details: isAvailable ? 'Available' : 'Unavailable',
      );
    }
  }

  Future<void> delete(int id) async {
    final item = await getById(id);
    await _db.delete(_table, 'id = ?', [id]);
    if (item != null) {
      ActivityLogRepository.instance.log(
        actionType: 'menu_item_deleted',
        entityType: 'menu_item',
        entityName: item.name,
      );
    }
  }

  Future<void> insertOrIgnore(MenuItemModel item) async {
    await _db.insert(_table, item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }
}
