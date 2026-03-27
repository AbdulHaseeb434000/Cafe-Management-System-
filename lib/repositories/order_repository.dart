import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../core/constants/app_constants.dart';
import '../models/order_model.dart';
import '../models/order_item_model.dart';

class OrderRepository {
  final DatabaseHelper _db;
  OrderRepository(this._db);

  static const _ordersTable = 'orders';
  static const _itemsTable = 'order_items';

  // ── Orders ───────────────────────────────────────────────────────────

  Future<List<OrderModel>> getActive() async {
    final rows = await _db.rawQuery('''
      SELECT o.*,
             t.name AS table_name,
             c.name AS customer_name
      FROM orders o
      LEFT JOIN cafe_tables t ON t.id = o.table_id
      LEFT JOIN customers   c ON c.id = o.customer_id
      WHERE o.status NOT IN ('completed', 'cancelled')
      ORDER BY o.created_at DESC
    ''');
    return rows.map(OrderModel.fromMap).toList();
  }

  Future<List<OrderModel>> getHistory({
    DateTime? from,
    DateTime? to,
    int limit = 100,
    int offset = 0,
  }) async {
    String where = "o.status = 'completed'";
    final args = <dynamic>[];
    if (from != null) {
      where += ' AND o.created_at >= ?';
      args.add(from.toIso8601String());
    }
    if (to != null) {
      where += ' AND o.created_at <= ?';
      args.add(to.toIso8601String());
    }
    final rows = await _db.rawQuery('''
      SELECT o.*,
             t.name AS table_name,
             c.name AS customer_name
      FROM orders o
      LEFT JOIN cafe_tables t ON t.id = o.table_id
      LEFT JOIN customers   c ON c.id = o.customer_id
      WHERE $where
      ORDER BY o.created_at DESC
      LIMIT ? OFFSET ?
    ''', [...args, limit, offset]);
    return rows.map(OrderModel.fromMap).toList();
  }

  Future<OrderModel?> getById(int id) async {
    final rows = await _db.rawQuery('''
      SELECT o.*,
             t.name AS table_name,
             c.name AS customer_name
      FROM orders o
      LEFT JOIN cafe_tables t ON t.id = o.table_id
      LEFT JOIN customers   c ON c.id = o.customer_id
      WHERE o.id = ?
    ''', [id]);
    if (rows.isEmpty) return null;
    final order = OrderModel.fromMap(rows.first);
    final items = await getItems(id);
    return order.copyWith(items: items);
  }

  Future<OrderModel?> getActiveByTable(int tableId) async {
    final rows = await _db.rawQuery('''
      SELECT o.*,
             t.name AS table_name,
             c.name AS customer_name
      FROM orders o
      LEFT JOIN cafe_tables t ON t.id = o.table_id
      LEFT JOIN customers   c ON c.id = o.customer_id
      WHERE o.table_id = ? AND o.status NOT IN ('completed', 'cancelled')
      LIMIT 1
    ''', [tableId]);
    if (rows.isEmpty) return null;
    final order = OrderModel.fromMap(rows.first);
    final items = await getItems(order.id!);
    return order.copyWith(items: items);
  }

  Future<OrderModel> insert(OrderModel order) async {
    final id = await _db.insert(_ordersTable, order.toMap());
    return order.copyWith(id: id);
  }

  Future<void> update(OrderModel order) async {
    await _db.update(_ordersTable, order.toMap(), 'id = ?', [order.id]);
  }

  Future<void> updateStatus(int id, String status) async {
    final data = <String, dynamic>{'status': status};
    if (status == AppConstants.orderStatusCompleted) {
      data['completed_at'] = DateTime.now().toIso8601String();
    }
    await _db.update(_ordersTable, data, 'id = ?', [id]);
  }

  Future<void> updateTotals(OrderModel order) async {
    await _db.update(_ordersTable, {
      'subtotal': order.subtotal,
      'discount_type': order.discountType,
      'discount_value': order.discountValue,
      'discount_amount': order.discountAmount,
      'tax_percent': order.taxPercent,
      'tax_amount': order.taxAmount,
      'total': order.total,
    }, 'id = ?', [order.id]);
  }

  Future<void> cancel(int id) => updateStatus(id, AppConstants.orderStatusCancelled);

  // ── Order items ──────────────────────────────────────────────────────

  Future<List<OrderItemModel>> getItems(int orderId) async {
    final rows = await _db.query(
      _itemsTable,
      where: 'order_id = ?',
      whereArgs: [orderId],
      orderBy: 'id ASC',
    );
    return rows.map(OrderItemModel.fromMap).toList();
  }

  Future<OrderItemModel> insertItem(OrderItemModel item) async {
    final id = await _db.insert(_itemsTable, item.toMap());
    return item.copyWith(id: id);
  }

  Future<void> updateItem(OrderItemModel item) async {
    await _db.update(_itemsTable, item.toMap(), 'id = ?', [item.id]);
  }

  Future<void> deleteItem(int id) async {
    await _db.delete(_itemsTable, 'id = ?', [id]);
  }

  Future<void> deleteAllItems(int orderId) async {
    await _db.delete(_itemsTable, 'order_id = ?', [orderId]);
  }

  // ── Reports queries ──────────────────────────────────────────────────

  Future<Map<String, dynamic>> getDailySummary(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day).toIso8601String();
    final end = DateTime(date.year, date.month, date.day, 23, 59, 59, 999).toIso8601String();
    final rows = await _db.rawQuery('''
      SELECT
        COUNT(*)           AS order_count,
        COALESCE(SUM(total), 0) AS revenue,
        COALESCE(AVG(total), 0) AS avg_order
      FROM orders
      WHERE status = 'completed'
        AND created_at BETWEEN ? AND ?
    ''', [start, end]);
    return rows.first;
  }

  Future<List<Map<String, dynamic>>> getTopItems({
    required DateTime from,
    required DateTime to,
    int limit = 10,
  }) async {
    return _db.rawQuery('''
      SELECT oi.name_snapshot AS name,
             SUM(oi.quantity) AS total_qty,
             SUM(oi.quantity * oi.price_snapshot) AS revenue
      FROM order_items oi
      INNER JOIN orders o ON o.id = oi.order_id
      WHERE o.status = 'completed'
        AND o.created_at BETWEEN ? AND ?
      GROUP BY oi.name_snapshot
      ORDER BY total_qty DESC
      LIMIT ?
    ''', [from.toIso8601String(), to.toIso8601String(), limit]);
  }

  Future<List<Map<String, dynamic>>> getDailyRevenue({
    required DateTime from,
    required DateTime to,
  }) async {
    return _db.rawQuery('''
      SELECT
        DATE(created_at) AS day,
        COUNT(*)          AS order_count,
        SUM(total)        AS revenue
      FROM orders
      WHERE status = 'completed'
        AND created_at BETWEEN ? AND ?
      GROUP BY DATE(created_at)
      ORDER BY day ASC
    ''', [from.toIso8601String(), to.toIso8601String()]);
  }

  Future<List<Map<String, dynamic>>> getRevenueByType({
    required DateTime from,
    required DateTime to,
  }) async {
    return _db.rawQuery('''
      SELECT type, COUNT(*) AS order_count, SUM(total) AS revenue
      FROM orders
      WHERE status = 'completed'
        AND created_at BETWEEN ? AND ?
      GROUP BY type
    ''', [from.toIso8601String(), to.toIso8601String()]);
  }

  // ── Backup ───────────────────────────────────────────────────────────

  Future<void> insertOrIgnoreOrder(OrderModel order) async {
    await _db.insert(_ordersTable, order.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> insertOrIgnoreItem(OrderItemModel item) async {
    await _db.insert(_itemsTable, item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }
}
