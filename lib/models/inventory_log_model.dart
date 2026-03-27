import 'package:uuid/uuid.dart';
import '../core/utils/date_helpers.dart';

class InventoryLogModel {
  final int? id;
  final String uuid;
  final int inventoryItemId;
  final String inventoryItemUuid;
  final double changeAmount;
  final String? reason;
  final DateTime createdAt;

  const InventoryLogModel({
    this.id,
    required this.uuid,
    required this.inventoryItemId,
    required this.inventoryItemUuid,
    required this.changeAmount,
    this.reason,
    required this.createdAt,
  });

  bool get isAddition => changeAmount > 0;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'uuid': uuid,
        'inventory_item_id': inventoryItemId,
        'inventory_item_uuid': inventoryItemUuid,
        'change_amount': changeAmount,
        'reason': reason,
        'created_at': DateHelpers.toIso(createdAt),
      };

  factory InventoryLogModel.fromMap(Map<String, dynamic> map) =>
      InventoryLogModel(
        id: map['id'] as int?,
        uuid: map['uuid'] as String,
        inventoryItemId: map['inventory_item_id'] as int,
        inventoryItemUuid: map['inventory_item_uuid'] as String? ?? '',
        changeAmount: (map['change_amount'] as num).toDouble(),
        reason: map['reason'] as String?,
        createdAt: DateHelpers.fromIso(map['created_at'] as String),
      );

  factory InventoryLogModel.create({
    required int inventoryItemId,
    required String inventoryItemUuid,
    required double changeAmount,
    String? reason,
  }) =>
      InventoryLogModel(
        uuid: const Uuid().v4(),
        inventoryItemId: inventoryItemId,
        inventoryItemUuid: inventoryItemUuid,
        changeAmount: changeAmount,
        reason: reason,
        createdAt: DateTime.now(),
      );
}
