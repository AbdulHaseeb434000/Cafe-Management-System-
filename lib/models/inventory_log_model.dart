import '../core/utils/date_helpers.dart';

class InventoryLogModel {
  final int? id;
  final int inventoryItemId;
  final double changeAmount;
  final String? reason;
  final DateTime createdAt;

  const InventoryLogModel({
    this.id,
    required this.inventoryItemId,
    required this.changeAmount,
    this.reason,
    required this.createdAt,
  });

  bool get isAddition => changeAmount > 0;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'inventory_item_id': inventoryItemId,
        'change_amount': changeAmount,
        'reason': reason,
        'created_at': DateHelpers.toIso(createdAt),
      };

  factory InventoryLogModel.fromMap(Map<String, dynamic> map) =>
      InventoryLogModel(
        id: map['id'] as int,
        inventoryItemId: map['inventory_item_id'] as int,
        changeAmount: (map['change_amount'] as num).toDouble(),
        reason: map['reason'] as String?,
        createdAt: DateHelpers.fromIso(map['created_at'] as String),
      );
}
