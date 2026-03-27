import 'package:uuid/uuid.dart';

class OrderItemModel {
  final int? id;
  final String uuid;
  final int orderId;
  final String orderUuid;
  final int menuItemId;
  final String menuItemUuid;
  final String nameSnapshot;
  final double priceSnapshot;
  final int quantity;
  final String? note;

  const OrderItemModel({
    this.id,
    required this.uuid,
    required this.orderId,
    required this.orderUuid,
    required this.menuItemId,
    required this.menuItemUuid,
    required this.nameSnapshot,
    required this.priceSnapshot,
    this.quantity = 1,
    this.note,
  });

  double get lineTotal => priceSnapshot * quantity;

  OrderItemModel copyWith({
    int? id,
    String? uuid,
    int? orderId,
    String? orderUuid,
    int? menuItemId,
    String? menuItemUuid,
    String? nameSnapshot,
    double? priceSnapshot,
    int? quantity,
    String? note,
  }) {
    return OrderItemModel(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      orderId: orderId ?? this.orderId,
      orderUuid: orderUuid ?? this.orderUuid,
      menuItemId: menuItemId ?? this.menuItemId,
      menuItemUuid: menuItemUuid ?? this.menuItemUuid,
      nameSnapshot: nameSnapshot ?? this.nameSnapshot,
      priceSnapshot: priceSnapshot ?? this.priceSnapshot,
      quantity: quantity ?? this.quantity,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'uuid': uuid,
        'order_id': orderId,
        'order_uuid': orderUuid,
        'menu_item_id': menuItemId,
        'menu_item_uuid': menuItemUuid,
        'name_snapshot': nameSnapshot,
        'price_snapshot': priceSnapshot,
        'quantity': quantity,
        'note': note,
      };

  factory OrderItemModel.fromMap(Map<String, dynamic> map) => OrderItemModel(
        id: map['id'] as int?,
        uuid: map['uuid'] as String,
        orderId: map['order_id'] as int,
        orderUuid: map['order_uuid'] as String? ?? '',
        menuItemId: map['menu_item_id'] as int,
        menuItemUuid: map['menu_item_uuid'] as String? ?? '',
        nameSnapshot: map['name_snapshot'] as String,
        priceSnapshot: (map['price_snapshot'] as num).toDouble(),
        quantity: map['quantity'] as int? ?? 1,
        note: map['note'] as String?,
      );

  factory OrderItemModel.create({
    required int orderId,
    required String orderUuid,
    required int menuItemId,
    required String menuItemUuid,
    required String nameSnapshot,
    required double priceSnapshot,
    int quantity = 1,
    String? note,
  }) =>
      OrderItemModel(
        uuid: const Uuid().v4(),
        orderId: orderId,
        orderUuid: orderUuid,
        menuItemId: menuItemId,
        menuItemUuid: menuItemUuid,
        nameSnapshot: nameSnapshot,
        priceSnapshot: priceSnapshot,
        quantity: quantity,
        note: note,
      );
}
