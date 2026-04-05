import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/plan_constants.dart';
import '../subscription/subscription_screen.dart';

/// Shown when the trial has expired and no active plan exists.
/// Displays pricing tiers and actionable contact buttons.
class PaywallScreen extends ConsumerWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restaurant = ref.watch(restaurantProvider);
    final restaurantName =
        restaurant?['name'] as String? ?? AppConstants.appName;

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
              const Icon(Icons.lock_clock_outlined,
                  size: 48, color: AppColors.primary),
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
              ...PlanConstants.plans.map((plan) => _PlanCard(plan: plan)),
              const SizedBox(height: 20),

              // ── Primary CTA — in-app payment ─────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.credit_card_outlined),
                  label: const Text('Subscribe Now'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const SubscriptionScreen()),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── Secondary — support contacts ─────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Need help choosing a plan?',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _launchWhatsApp(restaurantName),
                            icon: const Icon(Icons.chat_outlined, size: 16),
                            label: const Text('WhatsApp'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _launchEmail(restaurantName),
                            icon: const Icon(Icons.email_outlined, size: 16),
                            label: const Text('Email'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                            ),
                          ),
                        ),
                      ],
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

  Future<void> _launchWhatsApp(String restaurantName) async {
    final msg = Uri.encodeFull(
        'Hi, I\'d like to upgrade PlatoDesk for $restaurantName');
    final uri = Uri.parse(
        'https://wa.me/${PlanConstants.supportWhatsApp}?text=$msg');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _launchEmail(String restaurantName) async {
    final subject =
        Uri.encodeFull('Upgrade PlatoDesk — $restaurantName');
    final uri = Uri.parse(
        'mailto:${PlanConstants.supportEmail}?subject=$subject');
    await launchUrl(uri);
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan});
  final PlanInfo plan;

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
            ? [
                BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4))
              ]
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
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700, color: AppColors.brown)),
                if (plan.recommended)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Popular',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
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
                      const Icon(Icons.check_circle_outline,
                          size: 15, color: AppColors.success),
                      const SizedBox(width: 6),
                      Text(h,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
