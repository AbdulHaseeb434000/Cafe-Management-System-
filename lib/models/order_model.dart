import 'package:uuid/uuid.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/date_helpers.dart';
import 'order_item_model.dart';

class OrderModel {
  final int? id;
  final String uuid;
  final String type;
  final int? tableId;
  final String? tableUuid;
  final int? customerId;
  final String? customerUuid;
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
  final bool isLocked;

  // Eagerly loaded (not in DB columns)
  final List<OrderItemModel> items;
  final String? tableName;
  final String? customerName;
  /// Item count populated by history queries via a COUNT subquery.
  /// Null when items are fully loaded instead (active/detail screens).
  final int? itemCount;

  const OrderModel({
    this.id,
    required this.uuid,
    required this.type,
    this.tableId,
    this.tableUuid,
    this.customerId,
    this.customerUuid,
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
    this.isLocked = false,
    this.items = const [],
    this.tableName,
    this.customerName,
    this.itemCount,
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

  String get displayLabel {
    if (isDineIn) return tableName ?? 'Table';
    if (isDelivery) return customerName ?? 'Delivery';
    return customerName ?? 'Takeaway';
  }

  OrderModel copyWith({
    int? id,
    String? uuid,
    String? type,
    int? tableId,
    String? tableUuid,
    int? customerId,
    String? customerUuid,
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
    bool? isLocked,
    List<OrderItemModel>? items,
    String? tableName,
    String? customerName,
    int? itemCount,
  }) {
    return OrderModel(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      type: type ?? this.type,
      tableId: tableId ?? this.tableId,
      tableUuid: tableUuid ?? this.tableUuid,
      customerId: customerId ?? this.customerId,
      customerUuid: customerUuid ?? this.customerUuid,
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
      isLocked: isLocked ?? this.isLocked,
      items: items ?? this.items,
      tableName: tableName ?? this.tableName,
      customerName: customerName ?? this.customerName,
      itemCount: itemCount ?? this.itemCount,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'uuid': uuid,
        'type': type,
        'table_id': tableId,
        'table_uuid': tableUuid,
        'customer_id': customerId,
        'customer_uuid': customerUuid,
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
        'is_locked': isLocked ? 1 : 0,
      };

  factory OrderModel.fromMap(Map<String, dynamic> map) => OrderModel(
        id: map['id'] as int?,
        uuid: map['uuid'] as String,
        type: map['type'] as String,
        tableId: map['table_id'] as int?,
        tableUuid: map['table_uuid'] as String?,
        customerId: map['customer_id'] as int?,
        customerUuid: map['customer_uuid'] as String?,
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
        isLocked: (map['is_locked'] as int? ?? 0) == 1,
        tableName: map['table_name'] as String?,
        customerName: map['customer_name'] as String?,
        itemCount: (map['item_count'] as num?)?.toInt(),
      );

  factory OrderModel.create({required String type, String uuid = ''}) =>
      OrderModel(
        uuid: uuid.isEmpty ? const Uuid().v4() : uuid,
        type: type,
        createdAt: DateTime.now(),
      );
}
