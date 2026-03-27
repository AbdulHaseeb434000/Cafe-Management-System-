import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../screens/dashboard/dashboard_screen.dart';
import '../../screens/menu/menu_screen.dart';
import '../../screens/orders/orders_screen.dart';
import '../../screens/tables/tables_screen.dart';
import '../../screens/kitchen/kitchen_screen.dart';
import '../../screens/inventory/inventory_screen.dart';
import '../../screens/reports/reports_screen.dart';
import '../../screens/settings/settings_screen.dart';
import '../../widgets/main_scaffold.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/dashboard',
  routes: [
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => MainScaffold(child: child),
      routes: [
        GoRoute(
          path: '/dashboard',
          pageBuilder: (context, state) => const NoTransitionPage(child: DashboardScreen()),
        ),
        GoRoute(
          path: '/orders',
          pageBuilder: (context, state) => const NoTransitionPage(child: OrdersScreen()),
        ),
        GoRoute(
          path: '/menu',
          pageBuilder: (context, state) => const NoTransitionPage(child: MenuScreen()),
        ),
        GoRoute(
          path: '/tables',
          pageBuilder: (context, state) => const NoTransitionPage(child: TablesScreen()),
        ),
        GoRoute(
          path: '/kitchen',
          pageBuilder: (context, state) => const NoTransitionPage(child: KitchenScreen()),
        ),
        GoRoute(
          path: '/inventory',
          pageBuilder: (context, state) => const NoTransitionPage(child: InventoryScreen()),
        ),
        GoRoute(
          path: '/reports',
          pageBuilder: (context, state) => const NoTransitionPage(child: ReportsScreen()),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) => const NoTransitionPage(child: SettingsScreen()),
        ),
      ],
    ),
  ],
);
