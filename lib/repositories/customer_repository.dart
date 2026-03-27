import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../models/customer_model.dart';

class CustomerRepository {
  final DatabaseHelper _db;
  CustomerRepository(this._db);

  static const _table = 'customers';

  Future<List<CustomerModel>> getAll() async {
    final rows = await _db.query(_table, orderBy: 'name ASC');
    return rows.map(CustomerModel.fromMap).toList();
  }

  Future<CustomerModel?> getById(int id) async {
    final rows = await _db.query(_table, where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : CustomerModel.fromMap(rows.first);
  }

  Future<CustomerModel?> getByPhone(String phone) async {
    final rows = await _db.query(_table, where: 'phone = ?', whereArgs: [phone]);
    return rows.isEmpty ? null : CustomerModel.fromMap(rows.first);
  }

  Future<CustomerModel> insert(CustomerModel customer) async {
    final id = await _db.insert(_table, customer.toMap());
    return customer.copyWith(id: id);
  }

  Future<void> update(CustomerModel customer) async {
    await _db.update(_table, customer.toMap(), 'id = ?', [customer.id]);
  }

  Future<void> delete(int id) async {
    await _db.delete(_table, 'id = ?', [id]);
  }

  Future<void> insertOrIgnore(CustomerModel customer) async {
    await _db.insert(_table, customer.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }
}
