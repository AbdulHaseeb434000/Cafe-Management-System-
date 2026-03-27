import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../models/payment_model.dart';

class PaymentRepository {
  final DatabaseHelper _db;
  PaymentRepository(this._db);

  static const _table = 'payments';

  Future<PaymentModel> insert(PaymentModel payment) async {
    final id = await _db.insert(_table, payment.toMap());
    return payment.copyWith(id: id);
  }

  Future<PaymentModel?> getByOrderId(int orderId) async {
    final rows =
        await _db.query(_table, where: 'order_id = ?', whereArgs: [orderId]);
    return rows.isEmpty ? null : PaymentModel.fromMap(rows.first);
  }

  Future<List<PaymentModel>> getAll() async {
    final rows = await _db.query(_table, orderBy: 'paid_at DESC');
    return rows.map(PaymentModel.fromMap).toList();
  }

  Future<void> insertOrIgnore(PaymentModel payment) async {
    await _db.insert(_table, payment.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }
}
