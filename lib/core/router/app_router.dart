import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_providers.dart';
import '../../screens/auth/splash_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/paywall_screen.dart';
// signup_screen.dart exports SignupForm which is embedded as a tab inside
// LoginScreen — no separate /signup route is needed.
import '../../screens/dashboard/dashboard_screen.dart';
import '../../screens/menu/menu_screen.dart';
import '../../screens/orders/orders_screen.dart';
import '../../screens/orders/new_order_screen.dart';
import '../../screens/orders/order_detail_screen.dart';
import '../../screens/tables/tables_screen.dart';
import '../../screens/kitchen/kitchen_screen.dart';
import '../../screens/billing/billing_screen.dart';
import '../../screens/inventory/inventory_screen.dart';
import '../../screens/reports/reports_screen.dart';
import '../../screens/settings/settings_screen.dart';
import '../../screens/activity_log/activity_log_screen.dart';
import '../../screens/expenses/expenses_screen.dart';
import '../../screens/staff/staff_screen.dart';
import '../../screens/subscription/subscription_screen.dart';
import '../../widgets/main_scaffold.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> _shellNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'shell');

/// Routes that each role is allowed to access.
/// Any route not listed for a role redirects to /dashboard.
const _ownerRoutes = {
  '/dashboard', '/orders', '/menu', '/tables', '/kitchen',
  '/inventory', '/reports', '/settings', '/activity-log',
  '/expenses', '/staff',
};
const _managerRoutes = {
  '/dashboard', '/orders', '/menu', '/tables', '/kitchen',
  '/inventory', '/reports', '/settings', '/activity-log', '/expenses',
};
const _waiterRoutes = {'/dashboard', '/orders', '/tables', '/settings'};
const _kitchenRoutes = {'/kitchen'};

Set<String> _allowedRoutes(String role) => switch (role) {
      'owner'   => _ownerRoutes,
      'manager' => _managerRoutes,
      'waiter'  => _waiterRoutes,
      'kitchen' => _kitchenRoutes,
      _         => _waiterRoutes, // default to most restrictive
    };

String? _roleRedirect(GoRouterState state) {
  final path = state.matchedLocation;
  // Skip auth/public routes
  // Note: /signup is NOT a separate route — SignupForm is a tab inside LoginScreen.
  if (path == '/splash' || path == '/login' || path == '/paywall' ||
      path == '/subscription') return null;
  // Full-screen transient routes: everyone who is logged in can reach these
  if (path.startsWith('/orders/new') ||
      path.startsWith('/orders/') ||
      path.startsWith('/billing/')) return null;

  final role = roleRouterNotifier.value;
  final allowed = _allowedRoutes(role);
  // Check if any allowed route is a prefix of the current path
  final permitted = allowed.any((r) => path == r || path.startsWith('$r/'));
  return permitted ? null : '/dashboard';
}

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/splash',
  refreshListenable: roleRouterNotifier,
  redirect: (context, state) => _roleRedirect(state),
  routes: [
    // ── Auth / onboarding ────────────────────────────────────────────────
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/paywall',
      builder: (context, state) => const PaywallScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/subscription',
      builder: (context, state) => const SubscriptionScreen(),
    ),

    // ── Full-screen routes outside the shell ─────────────────────────────
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/orders/new',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return NewOrderScreen(
          preselectedTableId: extra?['tableId'] as int?,
          preselectedTableUuid: extra?['tableUuid'] as String?,
          preselectedTableName: extra?['tableName'] as String?,
        );
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/orders/:id',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return OrderDetailScreen(orderId: id);
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/billing/:orderId',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['orderId']!);
        return BillingScreen(orderId: id);
      },
    ),

    // ── Shell routes (persistent nav) ────────────────────────────────────
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => MainScaffold(child: child),
      routes: [
        GoRoute(
          path: '/',
          redirect: (_, __) => '/dashboard',
        ),
        GoRoute(
          path: '/dashboard',
          pageBuilder: (c, s) =>
              const NoTransitionPage(child: DashboardScreen()),
        ),
        GoRoute(
          path: '/orders',
          pageBuilder: (c, s) =>
              const NoTransitionPage(child: OrdersScreen()),
        ),
        GoRoute(
          path: '/menu',
          pageBuilder: (c, s) =>
              const NoTransitionPage(child: MenuScreen()),
        ),
        GoRoute(
          path: '/tables',
          pageBuilder: (c, s) =>
              const NoTransitionPage(child: TablesScreen()),
        ),
        GoRoute(
          path: '/kitchen',
          pageBuilder: (c, s) =>
              const NoTransitionPage(child: KitchenScreen()),
        ),
        GoRoute(
          path: '/inventory',
          pageBuilder: (c, s) =>
              const NoTransitionPage(child: InventoryScreen()),
        ),
        GoRoute(
          path: '/reports',
          pageBuilder: (c, s) =>
              const NoTransitionPage(child: ReportsScreen()),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (c, s) =>
              const NoTransitionPage(child: SettingsScreen()),
        ),
        GoRoute(
          path: '/activity-log',
          pageBuilder: (c, s) =>
              const NoTransitionPage(child: ActivityLogScreen()),
        ),
        GoRoute(
          path: '/expenses',
          pageBuilder: (c, s) =>
              const NoTransitionPage(child: ExpensesScreen()),
        ),
        GoRoute(
          path: '/staff',
          pageBuilder: (c, s) =>
              const NoTransitionPage(child: StaffScreen()),
        ),
      ],
    ),
  ],
);
