import 'package:uuid/uuid.dart';
import '../core/utils/date_helpers.dart';

class InventoryLogModel {
  final int? id;
  final String uuid;
  final int inventoryItemId;
  final String inventoryItemUuid;
  final double changeAmount;
  final String type;
  final double unitCost;
  final String? reason;
  final DateTime createdAt;

  const InventoryLogModel({
    this.id,
    required this.uuid,
    required this.inventoryItemId,
    required this.inventoryItemUuid,
    required this.changeAmount,
    this.type = 'adjustment',
    this.unitCost = 0,
    this.reason,
    required this.createdAt,
  });

  bool get isAddition => changeAmount > 0;

  /// Total cost value of this log entry (qty × unit cost).
  double get totalCost => changeAmount.abs() * unitCost;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'uuid': uuid,
        'inventory_item_id': inventoryItemId,
        'inventory_item_uuid': inventoryItemUuid,
        'change_amount': changeAmount,
        'type': type,
        'unit_cost': unitCost,
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
        type: map['type'] as String? ?? 'adjustment',
        unitCost: (map['unit_cost'] as num?)?.toDouble() ?? 0,
        reason: map['reason'] as String?,
        createdAt: DateHelpers.fromIso(map['created_at'] as String),
      );

  factory InventoryLogModel.create({
    required int inventoryItemId,
    required String inventoryItemUuid,
    required double changeAmount,
    String type = 'adjustment',
    double unitCost = 0,
    String? reason,
  }) =>
      InventoryLogModel(
        uuid: const Uuid().v4(),
        inventoryItemId: inventoryItemId,
        inventoryItemUuid: inventoryItemUuid,
        changeAmount: changeAmount,
        type: type,
        unitCost: unitCost,
        reason: reason,
        createdAt: DateTime.now(),
      );
}
