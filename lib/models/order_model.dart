import '../core/constants/app_constants.dart';
import '../core/utils/date_helpers.dart';
import 'order_item_model.dart';

class OrderModel {
  final int? id;
  final String type;
  final int? tableId;
  final int? customerId;
  final String? deliveryAddress;
  final String status;
  final String? discountType;
  final double discountValue;
  final double taxPercent;
  final double subtotal;
  final double discountAmount;
  final double taxAmount;
  final double total;
  final String? note;
  final DateTime createdAt;
  final DateTime? completedAt;

  // Eagerly loaded relations (not stored in DB)
  final List<OrderItemModel> items;
  final String? tableName;
  final String? customerName;

  const OrderModel({
    this.id,
    required this.type,
    this.tableId,
    this.customerId,
    this.deliveryAddress,
    this.status = AppConstants.orderStatusPending,
    this.discountType,
    this.discountValue = 0,
    this.taxPercent = 0,
    this.subtotal = 0,
    this.discountAmount = 0,
    this.taxAmount = 0,
    this.total = 0,
    this.note,
    required this.createdAt,
    this.completedAt,
    this.items = const [],
    this.tableName,
    this.customerName,
  });

  bool get isDineIn => type == AppConstants.orderTypeDineIn;
  bool get isTakeaway => type == AppConstants.orderTypeTakeaway;
  bool get isDelivery => type == AppConstants.orderTypeDelivery;

  bool get isPending => status == AppConstants.orderStatusPending;
  bool get isPreparing => status == AppConstants.orderStatusPreparing;
  bool get isReady => status == AppConstants.orderStatusReady;
  bool get isCompleted => status == AppConstants.orderStatusCompleted;
  bool get isCancelled => status == AppConstants.orderStatusCancelled;
  bool get isActive => !isCompleted && !isCancelled;

  String get displayId => '#${id?.toString().padLeft(4, '0') ?? '0000'}';

  OrderModel copyWith({
    int? id,
    String? type,
    int? tableId,
    int? customerId,
    String? deliveryAddress,
    String? status,
    String? discountType,
    double? discountValue,
    double? taxPercent,
    double? subtotal,
    double? discountAmount,
    double? taxAmount,
    double? total,
    String? note,
    DateTime? createdAt,
    DateTime? completedAt,
    List<OrderItemModel>? items,
    String? tableName,
    String? customerName,
  }) {
    return OrderModel(
      id: id ?? this.id,
      type: type ?? this.type,
      tableId: tableId ?? this.tableId,
      customerId: customerId ?? this.customerId,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      status: status ?? this.status,
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      taxPercent: taxPercent ?? this.taxPercent,
      subtotal: subtotal ?? this.subtotal,
      discountAmount: discountAmount ?? this.discountAmount,
      taxAmount: taxAmount ?? this.taxAmount,
      total: total ?? this.total,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      items: items ?? this.items,
      tableName: tableName ?? this.tableName,
      customerName: customerName ?? this.customerName,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'type': type,
        'table_id': tableId,
        'customer_id': customerId,
        'delivery_address': deliveryAddress,
        'status': status,
        'discount_type': discountType,
        'discount_value': discountValue,
        'tax_percent': taxPercent,
        'subtotal': subtotal,
        'discount_amount': discountAmount,
        'tax_amount': taxAmount,
        'total': total,
        'note': note,
        'created_at': DateHelpers.toIso(createdAt),
        'completed_at': completedAt != null ? DateHelpers.toIso(completedAt!) : null,
      };

  factory OrderModel.fromMap(Map<String, dynamic> map) => OrderModel(
        id: map['id'] as int,
        type: map['type'] as String,
        tableId: map['table_id'] as int?,
        customerId: map['customer_id'] as int?,
        deliveryAddress: map['delivery_address'] as String?,
        status: map['status'] as String? ?? AppConstants.orderStatusPending,
        discountType: map['discount_type'] as String?,
        discountValue: (map['discount_value'] as num?)?.toDouble() ?? 0,
        taxPercent: (map['tax_percent'] as num?)?.toDouble() ?? 0,
        subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0,
        discountAmount: (map['discount_amount'] as num?)?.toDouble() ?? 0,
        taxAmount: (map['tax_amount'] as num?)?.toDouble() ?? 0,
        total: (map['total'] as num?)?.toDouble() ?? 0,
        note: map['note'] as String?,
        createdAt: DateHelpers.fromIso(map['created_at'] as String),
        completedAt: map['completed_at'] != null
            ? DateHelpers.fromIso(map['completed_at'] as String)
            : null,
        tableName: map['table_name'] as String?,
        customerName: map['customer_name'] as String?,
      );
}
