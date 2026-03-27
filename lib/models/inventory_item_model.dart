import '../core/utils/date_helpers.dart';

class InventoryItemModel {
  final int? id;
  final String name;
  final String unit;
  final double quantity;
  final double lowStockThreshold;
  final DateTime updatedAt;

  const InventoryItemModel({
    this.id,
    required this.name,
    required this.unit,
    this.quantity = 0,
    this.lowStockThreshold = 0,
    required this.updatedAt,
  });

  bool get isLowStock =>
      lowStockThreshold > 0 && quantity <= lowStockThreshold;

  InventoryItemModel copyWith({
    int? id,
    String? name,
    String? unit,
    double? quantity,
    double? lowStockThreshold,
    DateTime? updatedAt,
  }) {
    return InventoryItemModel(
      id: id ?? this.id,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      quantity: quantity ?? this.quantity,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'unit': unit,
        'quantity': quantity,
        'low_stock_threshold': lowStockThreshold,
        'updated_at': DateHelpers.toIso(updatedAt),
      };

  factory InventoryItemModel.fromMap(Map<String, dynamic> map) =>
      InventoryItemModel(
        id: map['id'] as int,
        name: map['name'] as String,
        unit: map['unit'] as String,
        quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
        lowStockThreshold: (map['low_stock_threshold'] as num?)?.toDouble() ?? 0,
        updatedAt: DateHelpers.fromIso(map['updated_at'] as String),
      );
}
