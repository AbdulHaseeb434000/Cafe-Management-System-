class OrderItemModel {
  final int? id;
  final int orderId;
  final int menuItemId;
  final String nameSnapshot;
  final double priceSnapshot;
  final int quantity;
  final String? note;

  const OrderItemModel({
    this.id,
    required this.orderId,
    required this.menuItemId,
    required this.nameSnapshot,
    required this.priceSnapshot,
    this.quantity = 1,
    this.note,
  });

  double get lineTotal => priceSnapshot * quantity;

  OrderItemModel copyWith({
    int? id,
    int? orderId,
    int? menuItemId,
    String? nameSnapshot,
    double? priceSnapshot,
    int? quantity,
    String? note,
  }) {
    return OrderItemModel(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      menuItemId: menuItemId ?? this.menuItemId,
      nameSnapshot: nameSnapshot ?? this.nameSnapshot,
      priceSnapshot: priceSnapshot ?? this.priceSnapshot,
      quantity: quantity ?? this.quantity,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'order_id': orderId,
        'menu_item_id': menuItemId,
        'name_snapshot': nameSnapshot,
        'price_snapshot': priceSnapshot,
        'quantity': quantity,
        'note': note,
      };

  factory OrderItemModel.fromMap(Map<String, dynamic> map) => OrderItemModel(
        id: map['id'] as int,
        orderId: map['order_id'] as int,
        menuItemId: map['menu_item_id'] as int,
        nameSnapshot: map['name_snapshot'] as String,
        priceSnapshot: (map['price_snapshot'] as num).toDouble(),
        quantity: map['quantity'] as int? ?? 1,
        note: map['note'] as String?,
      );
}
