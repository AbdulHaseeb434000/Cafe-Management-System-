import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../core/constants/app_constants.dart';
import '../models/table_model.dart';

class TableRepository {
  final DatabaseHelper _db;
  TableRepository(this._db);

  static const _table = 'cafe_tables';

  Future<List<TableModel>> getAll() async {
    final rows = await _db.query(_table, orderBy: 'name ASC');
    return rows.map(TableModel.fromMap).toList();
  }

  Future<TableModel?> getById(int id) async {
    final rows = await _db.query(_table, where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : TableModel.fromMap(rows.first);
  }

  Future<TableModel> insert(TableModel table) async {
    final id = await _db.insert(_table, table.toMap());
    return table.copyWith(id: id);
  }

  Future<void> update(TableModel table) async {
    await _db.update(_table, table.toMap(), 'id = ?', [table.id]);
  }

  Future<void> updateStatus(int id, String status) async {
    await _db.update(_table, {'status': status}, 'id = ?', [id]);
  }

  Future<void> setOccupied(int id) => updateStatus(id, AppConstants.tableStatusOccupied);
  Future<void> setFree(int id) => updateStatus(id, AppConstants.tableStatusFree);
  Future<void> setReserved(int id) => updateStatus(id, AppConstants.tableStatusReserved);

  Future<void> delete(int id) async {
    await _db.delete(_table, 'id = ?', [id]);
  }

  Future<void> insertOrIgnore(TableModel table) async {
    await _db.insert(_table, table.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }
}
