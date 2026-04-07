import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/plan_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_providers.dart';
import '../../services/payment/safepay_service.dart';
import '../../services/supabase/supabase_service.dart';
import 'safepay_webview_screen.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() =>
      _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  bool _loading = false;

  String get _currentPlan =>
      ref.watch(restaurantProvider)?['plan'] as String? ?? 'trial';

  DateTime? get _renewalDate {
    final raw = ref.watch(restaurantProvider)?['subscription_renewed_at']
        as String?;
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  DateTime? get _trialEnd {
    final raw =
        ref.watch(restaurantProvider)?['trial_end_date'] as String?;
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Subscription')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CurrentPlanBanner(
              plan: _currentPlan,
              renewalDate: _renewalDate,
              trialEnd: _trialEnd,
            ),
            const SizedBox(height: 28),
            Text(
              _currentPlan == 'trial'
                  ? 'Choose a plan to continue'
                  : 'Change your plan',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            ...PlanConstants.plans.map(
              (plan) => _PlanCard(
                plan: plan,
                isCurrent: plan.slug == _currentPlan,
                onSubscribe: _loading
                    ? null
                    : () => _startPayment(plan),
              ),
            ),
            const SizedBox(height: 16),
            _PaymentHistoryButton(),
          ],
        ),
      ),
    );
  }

  Future<void> _startPayment(PlanInfo plan) async {
    // Show payment method bottom sheet
    final method = await _pickPaymentMethod(plan);
    if (method == null) return;

    setState(() => _loading = true);
    try {
      final order = await SafepayService.createOrder(
        plan: plan.slug,
        paymentMethod: method,
      );

      if (!mounted) return;

      final paid = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => SafepayWebviewScreen(
            checkoutUrl: order.checkoutUrl,
            orderId: order.orderId,
            planName: plan.name,
          ),
        ),
      );

      if (paid == true && mounted) {
        // Refresh restaurant data so the banner updates immediately
        final restaurant = await _refreshRestaurant();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              restaurant != null
                  ? 'Subscription activated! Plan: ${plan.name}'
                  : 'Payment received — refreshing...',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } on SafepayException catch (e) {
      if (mounted) {
        _showErrorDialog(e.message);
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('$e');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String?> _pickPaymentMethod(PlanInfo plan) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _PaymentMethodSheet(plan: plan),
    );
  }

  Future<Map<String, dynamic>?> _refreshRestaurant() async {
    try {
      final restaurant = await SupabaseService.fetchRestaurant();
      if (mounted && restaurant != null) {
        ref.read(restaurantProvider.notifier).state = restaurant;
      }
      return restaurant;
    } catch (_) {
      return null;
    }
  }

  /// Shows a persistent error dialog so the user can read — and share —
  /// the exact technical message instead of a vanishing SnackBar.
  void _showErrorDialog(String msg) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: AppColors.error, size: 20),
            SizedBox(width: 8),
            Text('Payment Error'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Something went wrong. The exact error is shown below — '
              'please share it with support or check Supabase Edge Function logs.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                msg,
                style: const TextStyle(
                    fontSize: 12, fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tip: Go to Supabase Dashboard → Edge Functions → '
              'create-safepay-order → Logs to see server-side details.',
              style: TextStyle(
                  fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

// ── Current plan banner ───────────────────────────────────────────────────────

class _CurrentPlanBanner extends StatelessWidget {
  final String plan;
  final DateTime? renewalDate;
  final DateTime? trialEnd;

  const _CurrentPlanBanner({
    required this.plan,
    this.renewalDate,
    this.trialEnd,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy');
    final isTrial = plan == 'trial';
    final color = isTrial ? AppColors.warning : AppColors.success;
    final label = isTrial ? 'Free Trial' : plan[0].toUpperCase() + plan.substring(1);

    String subtitle;
    if (isTrial && trialEnd != null) {
      final daysLeft = trialEnd!.difference(DateTime.now()).inDays;
      subtitle = daysLeft > 0
          ? 'Trial ends in $daysLeft day${daysLeft == 1 ? '' : 's'}'
          : 'Trial has expired';
    } else if (!isTrial && renewalDate != null) {
      subtitle = 'Active since ${fmt.format(renewalDate!)}';
    } else {
      subtitle = isTrial ? 'Trial period' : 'Active subscription';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              subtitle,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Plan card ─────────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  final PlanInfo plan;
  final bool isCurrent;
  final VoidCallback? onSubscribe;

  const _PlanCard({
    required this.plan,
    required this.isCurrent,
    required this.onSubscribe,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor =
        plan.recommended ? AppColors.primary : AppColors.border;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrent ? AppColors.success : borderColor,
          width: isCurrent || plan.recommended ? 2 : 1,
        ),
        color: AppColors.surface,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  plan.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 8),
                if (plan.recommended && !isCurrent)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Popular',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                if (isCurrent)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Current',
                      style: TextStyle(
                          color: AppColors.success,
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      plan.price,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: AppColors.brown,
                      ),
                    ),
                    Text(
                      plan.period,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              plan.devices,
              style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 10),
            ...plan.highlights.map(
              (h) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline,
                        size: 15, color: AppColors.success),
                    const SizedBox(width: 6),
                    Text(h, style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ),
            if (!isCurrent) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onSubscribe,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: plan.recommended
                        ? AppColors.primary
                        : AppColors.surface,
                    foregroundColor: plan.recommended
                        ? Colors.white
                        : AppColors.primary,
                    side: plan.recommended
                        ? null
                        : const BorderSide(color: AppColors.primary),
                  ),
                  child: const Text('Subscribe'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Payment method bottom sheet ───────────────────────────────────────────────

class _PaymentMethodSheet extends StatelessWidget {
  final PlanInfo plan;
  const _PaymentMethodSheet({required this.plan});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Pay for ${plan.name} — ${plan.price}${plan.period}',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'All payments are processed securely by Safepay.',
            style: TextStyle(
                fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          _MethodTile(
            icon: Icons.phone_android_outlined,
            label: 'Easypaisa',
            subtitle: 'Pay via Easypaisa mobile wallet',
            onTap: () => Navigator.pop(context, 'easypaisa'),
          ),
          const SizedBox(height: 8),
          _MethodTile(
            icon: Icons.phone_android_outlined,
            label: 'JazzCash',
            subtitle: 'Pay via JazzCash mobile wallet',
            onTap: () => Navigator.pop(context, 'jazzcash'),
          ),
          const SizedBox(height: 8),
          _MethodTile(
            icon: Icons.credit_card_outlined,
            label: 'Card',
            subtitle: 'Visa or Mastercard',
            onTap: () => Navigator.pop(context, 'card'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _MethodTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceVariant,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Payment history button ────────────────────────────────────────────────────

class _PaymentHistoryButton extends ConsumerStatefulWidget {
  @override
  ConsumerState<_PaymentHistoryButton> createState() =>
      _PaymentHistoryButtonState();
}

class _PaymentHistoryButtonState
    extends ConsumerState<_PaymentHistoryButton> {
  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      icon: const Icon(Icons.receipt_long_outlined, size: 18),
      label: const Text('Payment History'),
      onPressed: () => _showHistory(context),
    );
  }

  Future<void> _showHistory(BuildContext context) async {
    final payments = await SafepayService.getHistory();
    if (!context.mounted) return;

    final fmt = DateFormat('d MMM yyyy HH:mm');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        builder: (_, sc) => Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Payment History',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            const Divider(height: 1),
            Expanded(
              child: payments.isEmpty
                  ? const Center(child: Text('No payments yet'))
                  : ListView.separated(
                      controller: sc,
                      itemCount: payments.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 16),
                      itemBuilder: (_, i) {
                        final p = payments[i];
                        return ListTile(
                          leading: Icon(
                            p.isPaid
                                ? Icons.check_circle_outline
                                : Icons.cancel_outlined,
                            color: p.isPaid
                                ? AppColors.success
                                : AppColors.error,
                          ),
                          title: Text(
                            '${p.plan[0].toUpperCase()}${p.plan.substring(1)} — Rs. ${p.amount.toStringAsFixed(0)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          subtitle: Text(
                            '${p.paymentMethod} · ${fmt.format(p.createdAt.toLocal())}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (p.isPaid
                                      ? AppColors.success
                                      : AppColors.error)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              p.status,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: p.isPaid
                                      ? AppColors.success
                                      : AppColors.error,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
