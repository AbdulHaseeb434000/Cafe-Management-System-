import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/database/database_helper.dart';
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
      Map<String, dynamic>? restaurant;
      bool fromCache = false;

      try {
        restaurant = await SupabaseService.fetchRestaurant();
        if (restaurant != null) {
          // Persist for offline use
          await _cacheRestaurant(restaurant);
        }
      } catch (_) {
        // Network error — fall back to local cache
        restaurant = await _loadCachedRestaurant();
        fromCache = restaurant != null;
      }

      if (!mounted) return;

      if (restaurant == null) {
        // No restaurant found online and no cache — incomplete setup or new device
        context.go('/login');
        return;
      }

      if (!SupabaseService.isPlanActive(restaurant)) {
        // Trial expired or suspended — show paywall
        context.go('/paywall');
        return;
      }

      // Cache restaurant and trial days for settings/scaffold
      ref.read(restaurantProvider.notifier).state = restaurant;
      ref.read(trialDaysProvider.notifier).state =
          SupabaseService.trialDaysLeft(restaurant);

      String role = 'owner';
      if (!fromCache) {
        // Fetch staff role from Supabase (only possible when online)
        final staff = await SupabaseService.fetchStaffRecord();
        if (!mounted) return;
        role = staff?['role'] as String? ?? 'owner';
        await _cacheStaffRole(role);
      } else {
        // Offline — use cached role
        role = await _loadCachedStaffRole() ?? 'owner';
      }

      ref.read(staffRoleProvider.notifier).state = role;
      _routeByRole(role);
    } else {
      context.go('/login');
    }
  }

  Future<void> _cacheRestaurant(Map<String, dynamic> restaurant) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert(
      'settings',
      {'key': 'cached_restaurant', 'value': jsonEncode(restaurant)},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> _loadCachedRestaurant() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query('settings',
          where: 'key = ?', whereArgs: ['cached_restaurant']);
      if (rows.isEmpty) return null;
      return Map<String, dynamic>.from(
          jsonDecode(rows.first['value'] as String) as Map);
    } catch (_) {
      return null;
    }
  }

  Future<void> _cacheStaffRole(String role) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert(
      'settings',
      {'key': 'cached_staff_role', 'value': role},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> _loadCachedStaffRole() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query('settings',
          where: 'key = ?', whereArgs: ['cached_staff_role']);
      return rows.isEmpty ? null : rows.first['value'] as String?;
    } catch (_) {
      return null;
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
