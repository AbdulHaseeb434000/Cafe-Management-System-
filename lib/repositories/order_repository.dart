import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../core/constants/app_constants.dart';
import '../models/order_model.dart';
import '../models/order_item_model.dart';
import 'activity_log_repository.dart';

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
    String where = "o.status IN ('completed', 'cancelled')";
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
             c.name AS customer_name,
             (SELECT COUNT(*) FROM order_items oi WHERE oi.order_id = o.id) AS item_count
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
    final saved = order.copyWith(id: id);
    ActivityLogRepository.instance.log(
      actionType: 'order_created',
      entityType: 'order',
      entityName: saved.displayId,
      details: _typeLabel(order.type),
    );
    return saved;
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
    if (status == AppConstants.orderStatusCompleted ||
        status == AppConstants.orderStatusCancelled) {
      final order = await getById(id);
      if (order != null) {
        ActivityLogRepository.instance.log(
          actionType: status == AppConstants.orderStatusCompleted
              ? 'order_completed'
              : 'order_cancelled',
          entityType: 'order',
          entityName: order.displayId,
          details: _typeLabel(order.type),
        );
      }
    }
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

  String _typeLabel(String type) {
    return switch (type) {
      'dine_in' => 'Dine-In',
      'delivery' => 'Delivery',
      _ => 'Takeaway',
    };
  }

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

  Future<Map<String, dynamic>> getSummary({
    required DateTime from,
    required DateTime to,
  }) async {
    final f = from.toIso8601String();
    final t = to.toIso8601String();
    final rows = await _db.rawQuery('''
      SELECT
        COUNT(CASE WHEN status = 'completed' THEN 1 END)               AS order_count,
        COALESCE(SUM(CASE WHEN status = 'completed' THEN total END), 0) AS revenue,
        COALESCE(AVG(CASE WHEN status = 'completed' THEN total END), 0) AS avg_order,
        COUNT(CASE WHEN status = 'cancelled' THEN 1 END)               AS cancelled_count
      FROM orders
      WHERE created_at BETWEEN ? AND ?
    ''', [f, t]);
    final result = Map<String, dynamic>.from(rows.first);
    final itemRows = await _db.rawQuery('''
      SELECT COALESCE(SUM(oi.quantity), 0) AS items_sold
      FROM order_items oi
      INNER JOIN orders o ON o.id = oi.order_id
      WHERE o.status = 'completed'
        AND o.created_at BETWEEN ? AND ?
    ''', [f, t]);
    result['items_sold'] = itemRows.first['items_sold'] ?? 0;
    return result;
  }

  Future<List<Map<String, dynamic>>> getHourlyRevenue({
    required DateTime from,
    required DateTime to,
  }) async {
    return _db.rawQuery('''
      SELECT
        CAST(strftime('%H', created_at) AS INTEGER) AS hour,
        COUNT(*)                                    AS order_count,
        SUM(total)                                  AS revenue,
        COUNT(DISTINCT customer_id)                 AS customer_count
      FROM orders
      WHERE status = 'completed'
        AND created_at BETWEEN ? AND ?
      GROUP BY hour
      ORDER BY hour ASC
    ''', [from.toIso8601String(), to.toIso8601String()]);
  }

  Future<List<Map<String, dynamic>>> getPaymentSplit({
    required DateTime from,
    required DateTime to,
  }) async {
    return _db.rawQuery('''
      SELECT p.method,
             COUNT(*)          AS count,
             COALESCE(SUM(o.total), 0) AS amount
      FROM payments p
      INNER JOIN orders o ON o.id = p.order_id
      WHERE o.status = 'completed'
        AND o.created_at BETWEEN ? AND ?
      GROUP BY p.method
      ORDER BY amount DESC
    ''', [from.toIso8601String(), to.toIso8601String()]);
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

  /// Returns raw rows for CSV export — includes items_summary via GROUP_CONCAT.
  Future<List<Map<String, dynamic>>> getHistoryForExport({
    required DateTime from,
    required DateTime to,
  }) async {
    return _db.rawQuery('''
      SELECT o.id,
             o.type,
             o.status,
             o.subtotal,
             o.discount_amount,
             o.tax_amount,
             o.total,
             o.created_at,
             t.name  AS table_name,
             c.name  AS customer_name,
             COALESCE(
               GROUP_CONCAT(oi.quantity || 'x ' || oi.name_snapshot, ' | '),
               ''
             ) AS items_summary
      FROM orders o
      LEFT JOIN cafe_tables  t  ON t.id  = o.table_id
      LEFT JOIN customers    c  ON c.id  = o.customer_id
      LEFT JOIN order_items  oi ON oi.order_id = o.id
      WHERE o.status IN ('completed', 'cancelled')
        AND o.created_at BETWEEN ? AND ?
      GROUP BY o.id
      ORDER BY o.created_at DESC
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
