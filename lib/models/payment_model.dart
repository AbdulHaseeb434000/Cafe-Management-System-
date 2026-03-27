import 'package:uuid/uuid.dart';
import '../core/utils/date_helpers.dart';

class PaymentModel {
  final int? id;
  final String uuid;
  final int orderId;
  final String orderUuid;
  final String method;
  final double amountTendered;
  final double changeAmount;
  final DateTime paidAt;

  const PaymentModel({
    this.id,
    required this.uuid,
    required this.orderId,
    required this.orderUuid,
    required this.method,
    required this.amountTendered,
    this.changeAmount = 0,
    required this.paidAt,
  });

  PaymentModel copyWith({
    int? id,
    String? uuid,
    int? orderId,
    String? orderUuid,
    String? method,
    double? amountTendered,
    double? changeAmount,
    DateTime? paidAt,
  }) {
    return PaymentModel(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      orderId: orderId ?? this.orderId,
      orderUuid: orderUuid ?? this.orderUuid,
      method: method ?? this.method,
      amountTendered: amountTendered ?? this.amountTendered,
      changeAmount: changeAmount ?? this.changeAmount,
      paidAt: paidAt ?? this.paidAt,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'uuid': uuid,
        'order_id': orderId,
        'order_uuid': orderUuid,
        'method': method,
        'amount_tendered': amountTendered,
        'change_amount': changeAmount,
        'paid_at': DateHelpers.toIso(paidAt),
      };

  factory PaymentModel.fromMap(Map<String, dynamic> map) => PaymentModel(
        id: map['id'] as int?,
        uuid: map['uuid'] as String,
        orderId: map['order_id'] as int,
        orderUuid: map['order_uuid'] as String? ?? '',
        method: map['method'] as String,
        amountTendered: (map['amount_tendered'] as num).toDouble(),
        changeAmount: (map['change_amount'] as num?)?.toDouble() ?? 0,
        paidAt: DateHelpers.fromIso(map['paid_at'] as String),
      );

  factory PaymentModel.create({
    required int orderId,
    required String orderUuid,
    required String method,
    required double amountTendered,
    double changeAmount = 0,
  }) =>
      PaymentModel(
        uuid: const Uuid().v4(),
        orderId: orderId,
        orderUuid: orderUuid,
        method: method,
        amountTendered: amountTendered,
        changeAmount: changeAmount,
        paidAt: DateTime.now(),
      );
}
