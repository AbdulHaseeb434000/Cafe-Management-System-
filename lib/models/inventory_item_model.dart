import 'package:uuid/uuid.dart';
import '../core/utils/date_helpers.dart';

class InventoryItemModel {
  final int? id;
  final String uuid;
  final String name;
  final String unit;
  final double quantity;
  final double lowStockThreshold;
  final double unitCost;
  final DateTime updatedAt;
  final bool isDeleted;

  const InventoryItemModel({
    this.id,
    required this.uuid,
    required this.name,
    required this.unit,
    this.quantity = 0,
    this.lowStockThreshold = 0,
    this.unitCost = 0,
    required this.updatedAt,
    this.isDeleted = false,
  });

  bool get isLowStock => lowStockThreshold > 0 && quantity <= lowStockThreshold;

  /// Estimated stock value: quantity × unit cost (0 if unit cost unset).
  double get stockValue => quantity * unitCost;

  InventoryItemModel copyWith({
    int? id,
    String? uuid,
    String? name,
    String? unit,
    double? quantity,
    double? lowStockThreshold,
    double? unitCost,
    DateTime? updatedAt,
    bool? isDeleted,
  }) {
    return InventoryItemModel(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      quantity: quantity ?? this.quantity,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      unitCost: unitCost ?? this.unitCost,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'uuid': uuid,
        'name': name,
        'unit': unit,
        'quantity': quantity,
        'low_stock_threshold': lowStockThreshold,
        'unit_cost': unitCost,
        'updated_at': DateHelpers.toIso(updatedAt),
        'is_deleted': isDeleted ? 1 : 0,
      };

  factory InventoryItemModel.fromMap(Map<String, dynamic> map) =>
      InventoryItemModel(
        id: map['id'] as int?,
        uuid: map['uuid'] as String,
        name: map['name'] as String,
        unit: map['unit'] as String,
        quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
        lowStockThreshold: (map['low_stock_threshold'] as num?)?.toDouble() ?? 0,
        unitCost: (map['unit_cost'] as num?)?.toDouble() ?? 0,
        updatedAt: DateHelpers.fromIso(map['updated_at'] as String),
        isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
      );

  factory InventoryItemModel.create({
    required String name,
    required String unit,
    double quantity = 0,
    double lowStockThreshold = 0,
    double unitCost = 0,
  }) =>
      InventoryItemModel(
        uuid: const Uuid().v4(),
        name: name,
        unit: unit,
        quantity: quantity,
        lowStockThreshold: lowStockThreshold,
        unitCost: unitCost,
        updatedAt: DateTime.now(),
      );
}
