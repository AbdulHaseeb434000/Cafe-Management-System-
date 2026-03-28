import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
import '../../widgets/main_scaffold.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> _shellNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'shell');

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/dashboard',
  routes: [
    // Full-screen routes outside the shell
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

    // Shell routes (persistent nav)
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => MainScaffold(child: child),
      routes: [
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
      ],
    ),
  ],
);
