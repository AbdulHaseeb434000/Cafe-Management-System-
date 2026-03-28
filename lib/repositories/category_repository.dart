import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../models/category_model.dart';

class CategoryRepository {
  final DatabaseHelper _db;
  CategoryRepository(this._db);

  static const _table = 'categories';

  Future<List<CategoryModel>> getAll() async {
    final rows = await _db.query(_table, orderBy: 'sort_order ASC, name ASC');
    return rows.map(CategoryModel.fromMap).toList();
  }

  Future<CategoryModel?> getById(int id) async {
    final rows = await _db.query(_table, where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : CategoryModel.fromMap(rows.first);
  }

  Future<CategoryModel?> getByUuid(String uuid) async {
    final rows = await _db.query(_table, where: 'uuid = ?', whereArgs: [uuid]);
    return rows.isEmpty ? null : CategoryModel.fromMap(rows.first);
  }

  Future<CategoryModel> insert(CategoryModel category) async {
    final id = await _db.insert(_table, category.toMap());
    return category.copyWith(id: id);
  }

  Future<void> update(CategoryModel category) async {
    await _db.update(_table, category.toMap(), 'id = ?', [category.id]);
  }

  Future<void> delete(int id) async {
    await _db.delete(_table, 'id = ?', [id]);
  }

  Future<void> updateSortOrder(List<CategoryModel> categories) async {
    final db = await _db.database;
    final batch = db.batch();
    for (var i = 0; i < categories.length; i++) {
      batch.update(
        _table,
        {'sort_order': i},
        where: 'id = ?',
        whereArgs: [categories[i].id],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> insertOrIgnore(CategoryModel category) async {
    await _db.insert(_table, category.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }
}
