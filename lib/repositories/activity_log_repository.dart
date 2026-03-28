import 'package:uuid/uuid.dart';
import '../core/database/database_helper.dart';
import '../models/activity_log_model.dart';

class ActivityLogRepository {
  ActivityLogRepository._();
  static final ActivityLogRepository instance = ActivityLogRepository._();

  final _db = DatabaseHelper.instance;
  static const _table = 'activity_logs';
  static const _uuid = Uuid();

  Future<void> log({
    required String actionType,
    required String entityType,
    required String entityName,
    String? details,
  }) async {
    final entry = ActivityLogModel(
      uuid: _uuid.v4(),
      actionType: actionType,
      entityType: entityType,
      entityName: entityName,
      details: details,
      createdAt: DateTime.now(),
    );
    try {
      await _db.insert(_table, entry.toMap());
    } catch (_) {
      // Never let logging failures crash the app
    }
  }

  Future<List<ActivityLogModel>> getAll({int limit = 500}) async {
    final rows = await _db.query(
      _table,
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(ActivityLogModel.fromMap).toList();
  }

  Future<List<ActivityLogModel>> getFiltered({
    DateTime? from,
    DateTime? to,
    int limit = 2000,
  }) async {
    String? where;
    List<dynamic>? args;
    if (from != null && to != null) {
      where = 'created_at >= ? AND created_at <= ?';
      args = [from.toIso8601String(), _endOfDay(to).toIso8601String()];
    } else if (from != null) {
      where = 'created_at >= ?';
      args = [from.toIso8601String()];
    } else if (to != null) {
      where = 'created_at <= ?';
      args = [_endOfDay(to).toIso8601String()];
    }
    final rows = await _db.query(
      _table,
      where: where,
      whereArgs: args,
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(ActivityLogModel.fromMap).toList();
  }

  DateTime _endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  Future<void> clear() async {
    final db = await _db.database;
    await db.delete(_table);
  }
}
