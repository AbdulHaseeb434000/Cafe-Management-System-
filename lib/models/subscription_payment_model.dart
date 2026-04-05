class SubscriptionPaymentModel {
  const SubscriptionPaymentModel({
    required this.id,
    required this.restaurantId,
    required this.plan,
    required this.amount,
    required this.currency,
    required this.paymentMethod,
    required this.gateway,
    this.gatewayReference,
    required this.status,
    required this.createdAt,
    this.paidAt,
  });

  final String id;
  final String restaurantId;
  final String plan;
  final double amount;
  final String currency;

  /// easypaisa | jazzcash | card
  final String paymentMethod;

  /// safepay | stripe
  final String gateway;

  final String? gatewayReference;

  /// pending | paid | failed | refunded
  final String status;

  final DateTime createdAt;
  final DateTime? paidAt;

  bool get isPaid => status == 'paid';

  factory SubscriptionPaymentModel.fromMap(Map<String, dynamic> map) =>
      SubscriptionPaymentModel(
        id:               map['id'] as String,
        restaurantId:     map['restaurant_id'] as String,
        plan:             map['plan'] as String,
        amount:           (map['amount'] as num).toDouble(),
        currency:         map['currency'] as String? ?? 'PKR',
        paymentMethod:    map['payment_method'] as String,
        gateway:          map['gateway'] as String,
        gatewayReference: map['gateway_reference'] as String?,
        status:           map['status'] as String,
        createdAt:        DateTime.parse(map['created_at'] as String),
        paidAt: map['paid_at'] != null
            ? DateTime.parse(map['paid_at'] as String)
            : null,
      );
}
