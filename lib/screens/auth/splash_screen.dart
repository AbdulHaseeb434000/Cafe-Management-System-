import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_providers.dart';
import '../../services/supabase/supabase_service.dart';
import '../../core/theme/app_colors.dart';

/// First screen shown on app launch.
/// Checks if a Supabase session exists and routes accordingly.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    // Brief pause to show the splash logo cleanly
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    if (SupabaseService.isSignedIn) {
      // Fetch restaurant to check plan status
      final restaurant = await SupabaseService.fetchRestaurant();
      if (!mounted) return;

      if (restaurant == null) {
        // Auth user exists but no restaurant record — go to login
        context.go('/login');
        return;
      }

      if (!SupabaseService.isPlanActive(restaurant)) {
        // Trial expired or suspended — show paywall
        context.go('/paywall');
        return;
      }

      // Fetch staff role, store it, then route
      final staff = await SupabaseService.fetchStaffRecord();
      if (!mounted) return;

      final role = staff?['role'] as String? ?? 'owner';
      ref.read(staffRoleProvider.notifier).state = role;
      _routeByRole(role);
    } else {
      context.go('/login');
    }
  }

  void _routeByRole(String role) {
    switch (role) {
      case 'kitchen':
        context.go('/kitchen');
      default:
        context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.dinner_dining, color: Colors.white, size: 48),
            ),
            const SizedBox(height: 20),
            Text(
              'PlatoDesk',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.brown,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Restaurant Management',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 48),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
