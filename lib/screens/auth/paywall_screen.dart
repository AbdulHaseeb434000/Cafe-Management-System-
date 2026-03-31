import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
// Note: SupabaseService removed — sign-out now goes through signOutAndClear()

/// Shown when the trial has expired and no active plan exists.
/// Displays pricing tiers and a contact/upgrade prompt.
class PaywallScreen extends ConsumerWidget {
  const PaywallScreen({super.key});

  static const _plans = [
    _PlanInfo(
      name: 'Starter',
      price: 'Rs. 2,000',
      period: '/month',
      devices: '1 device',
      highlights: ['All core features', 'Unlimited orders', 'PDF receipts & reports'],
      recommended: false,
    ),
    _PlanInfo(
      name: 'Standard',
      price: 'Rs. 4,500',
      period: '/month',
      devices: 'Up to 3 devices',
      highlights: ['Everything in Starter', 'Multi-staff roles', 'Priority support'],
      recommended: true,
    ),
    _PlanInfo(
      name: 'Business',
      price: 'Rs. 9,000',
      period: '/month',
      devices: 'Up to 8 devices',
      highlights: ['Everything in Standard', 'Cloud backup & sync', 'Advanced analytics'],
      recommended: false,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Sign out'),
            onPressed: () async {
              await signOutAndClear(ref);
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.lock_clock_outlined, size: 48, color: AppColors.primary),
              const SizedBox(height: 12),
              Text(
                'Your free trial has ended',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.brown,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Choose a plan to continue using ${AppConstants.appName}.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              ..._plans.map((plan) => _PlanCard(plan: plan)),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.phone_outlined, color: AppColors.brown),
                    const SizedBox(height: 6),
                    Text(
                      'To activate your plan, contact us on WhatsApp or email.\n'
                      'We\'ll enable your subscription within minutes.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 10),
                    // Placeholder — replace with real contact info
                    Text(
                      'support@platodesk.app',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan});
  final _PlanInfo plan;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: plan.recommended ? AppColors.primary : AppColors.border,
          width: plan.recommended ? 2 : 1,
        ),
        boxShadow: plan.recommended
            ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 4))]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(plan.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700, color: AppColors.brown)),
                if (plan.recommended)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Popular',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: plan.price,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.brown,
                        ),
                  ),
                  TextSpan(
                    text: plan.period,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Text(plan.devices,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 10),
            ...plan.highlights.map((h) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, size: 15, color: AppColors.success),
                      const SizedBox(width: 6),
                      Text(h, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _PlanInfo {
  const _PlanInfo({
    required this.name,
    required this.price,
    required this.period,
    required this.devices,
    required this.highlights,
    required this.recommended,
  });

  final String name;
  final String price;
  final String period;
  final String devices;
  final List<String> highlights;
  final bool recommended;
}
