import 'dart:async';
import '../supabase/supabase_service.dart';
import '../../models/subscription_payment_model.dart';

/// Client-side interface to the Safepay payment flow.
/// All secret keys stay on the Supabase Edge Function — this class only
/// calls the Edge Function and reads back results.
class SafepayService {
  SafepayService._();

  // ── Create order ─────────────────────────────────────────────────────────

  /// Calls the [create-safepay-order] Edge Function.
  /// Returns [SafepayOrderResult] with [checkoutUrl] and [orderId].
  /// Throws [SafepayException] on any failure.
  static Future<SafepayOrderResult> createOrder({
    required String plan,
    required String paymentMethod,
  }) async {
    final session = SupabaseService.currentSession;
    if (session == null) throw const SafepayException('Not signed in');

    late final dynamic rawData;
    late final int status;

    try {
      final res = await SupabaseService.client.functions.invoke(
        'create-safepay-order',
        body: {'plan': plan, 'paymentMethod': paymentMethod},
      );
      rawData = res.data;
      status  = res.status;
    } catch (e) {
      throw SafepayException('Network error calling payment service: $e');
    }

    if (status != 200) {
      // Safely extract error regardless of whether data is Map or String
      String msg = 'Payment service error (HTTP $status)';
      if (rawData is Map) {
        msg = rawData['error']?.toString() ?? msg;
      } else if (rawData != null) {
        msg = 'HTTP $status: $rawData';
      }
      throw SafepayException(msg);
    }

    if (rawData is! Map) {
      throw SafepayException(
          'Unexpected response from payment service: $rawData');
    }

    final checkoutUrl = rawData['checkoutUrl'] as String?;
    final orderId     = rawData['orderId']     as String?;

    if (checkoutUrl == null || orderId == null) {
      throw SafepayException(
          'Missing checkoutUrl/orderId in response: $rawData');
    }

    return SafepayOrderResult(checkoutUrl: checkoutUrl, orderId: orderId);
  }

  // ── Poll for payment confirmation ─────────────────────────────────────────

  /// Polls the [subscription_payments] table every 3 seconds for up to
  /// [maxWaitSeconds] until the payment is [paid] or [failed].
  ///
  /// Returns [SubscriptionPaymentModel] with the final status.
  static Future<SubscriptionPaymentModel> pollPaymentStatus(
    String orderId, {
    int maxWaitSeconds = 120,
    Duration interval = const Duration(seconds: 3),
  }) async {
    final deadline = DateTime.now().add(Duration(seconds: maxWaitSeconds));

    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(interval);

      final row = await SupabaseService.client
          .from('subscription_payments')
          .select()
          .eq('id', orderId)
          .maybeSingle();

      if (row == null) continue;

      final payment = SubscriptionPaymentModel.fromMap(
        Map<String, dynamic>.from(row as Map),
      );

      if (payment.status == 'paid' || payment.status == 'failed') {
        return payment;
      }
    }

    throw SafepayException('Payment confirmation timed out. '
        'If you completed payment, it will be reflected shortly.');
  }

  // ── Fetch payment history ─────────────────────────────────────────────────

  /// Returns the last [limit] subscription payments for the current restaurant.
  static Future<List<SubscriptionPaymentModel>> getHistory({
    int limit = 10,
  }) async {
    final staffRow = await SupabaseService.fetchStaffRecord();
    if (staffRow == null) return [];

    final rows = await SupabaseService.client
        .from('subscription_payments')
        .select()
        .eq('restaurant_id', staffRow['restaurant_id'] as String)
        .order('created_at', ascending: false)
        .limit(limit);

    return (rows as List)
        .map((r) => SubscriptionPaymentModel.fromMap(
              Map<String, dynamic>.from(r as Map),
            ))
        .toList();
  }
}

// ── Value objects ─────────────────────────────────────────────────────────────

class SafepayOrderResult {
  const SafepayOrderResult({
    required this.checkoutUrl,
    required this.orderId,
  });
  final String checkoutUrl;
  final String orderId;
}

class SafepayException implements Exception {
  const SafepayException(this.message);
  final String message;
  @override
  String toString() => 'SafepayException: $message';
}
