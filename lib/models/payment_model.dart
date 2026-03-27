import '../core/utils/date_helpers.dart';

class PaymentModel {
  final int? id;
  final int orderId;
  final String method;
  final double amountTendered;
  final double changeAmount;
  final DateTime paidAt;

  const PaymentModel({
    this.id,
    required this.orderId,
    required this.method,
    required this.amountTendered,
    this.changeAmount = 0,
    required this.paidAt,
  });

  PaymentModel copyWith({
    int? id,
    int? orderId,
    String? method,
    double? amountTendered,
    double? changeAmount,
    DateTime? paidAt,
  }) {
    return PaymentModel(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      method: method ?? this.method,
      amountTendered: amountTendered ?? this.amountTendered,
      changeAmount: changeAmount ?? this.changeAmount,
      paidAt: paidAt ?? this.paidAt,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'order_id': orderId,
        'method': method,
        'amount_tendered': amountTendered,
        'change_amount': changeAmount,
        'paid_at': DateHelpers.toIso(paidAt),
      };

  factory PaymentModel.fromMap(Map<String, dynamic> map) => PaymentModel(
        id: map['id'] as int,
        orderId: map['order_id'] as int,
        method: map['method'] as String,
        amountTendered: (map['amount_tendered'] as num).toDouble(),
        changeAmount: (map['change_amount'] as num?)?.toDouble() ?? 0,
        paidAt: DateHelpers.fromIso(map['paid_at'] as String),
      );
}
