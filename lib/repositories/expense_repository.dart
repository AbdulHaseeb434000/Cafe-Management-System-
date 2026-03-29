import '../core/database/database_helper.dart';
import '../models/expense_model.dart';

class ExpenseRepository {
  final DatabaseHelper _db;
  ExpenseRepository(this._db);

  static const _table = 'expenses';

  Future<List<ExpenseModel>> getAll() async {
    final rows = await _db.query(_table, orderBy: 'date DESC, id DESC');
    return rows.map(ExpenseModel.fromMap).toList();
  }

  Future<List<ExpenseModel>> getFiltered({
    required DateTime from,
    required DateTime to,
  }) async {
    final rows = await _db.query(
      _table,
      where: 'date >= ? AND date <= ?',
      whereArgs: [_dayStart(from), _dayEnd(to)],
      orderBy: 'date DESC, id DESC',
    );
    return rows.map(ExpenseModel.fromMap).toList();
  }

  Future<double> getTotalForPeriod({
    required DateTime from,
    required DateTime to,
  }) async {
    final rows = await _db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) AS total FROM expenses WHERE date >= ? AND date <= ?',
      [_dayStart(from), _dayEnd(to)],
    );
    return (rows.first['total'] as num?)?.toDouble() ?? 0;
  }

  Future<List<Map<String, dynamic>>> getByCategory({
    required DateTime from,
    required DateTime to,
  }) async {
    return _db.rawQuery('''
      SELECT category, COALESCE(SUM(amount), 0) AS total, COUNT(*) AS count
      FROM expenses
      WHERE date >= ? AND date <= ?
      GROUP BY category
      ORDER BY total DESC
    ''', [_dayStart(from), _dayEnd(to)]);
  }

  Future<ExpenseModel> insert(ExpenseModel expense) async {
    final id = await _db.insert(_table, expense.toMap());
    return expense.copyWith(id: id);
  }

  Future<void> update(ExpenseModel expense) async {
    await _db.update(_table, expense.toMap(), 'id = ?', [expense.id]);
  }

  Future<void> delete(int id) async {
    await _db.delete(_table, 'id = ?', [id]);
  }

  String _dayStart(DateTime d) =>
      DateTime(d.year, d.month, d.day).toIso8601String();

  String _dayEnd(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999).toIso8601String();
}
