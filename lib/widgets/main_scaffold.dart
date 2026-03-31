import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_colors.dart';
import '../providers/auth_providers.dart';
import '../providers/settings_providers.dart';

class MainScaffold extends ConsumerWidget {
  final Widget child;

  const MainScaffold({super.key, required this.child});

  // Full nav for owner / manager
  static const _navItems = [
    _NavItem(label: 'Dashboard', icon: Icons.home_outlined, activeIcon: Icons.home, path: '/dashboard'),
    _NavItem(label: 'Orders', icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long, path: '/orders'),
    _NavItem(label: 'Menu', icon: Icons.restaurant_menu_outlined, activeIcon: Icons.restaurant_menu, path: '/menu'),
    _NavItem(label: 'Tables', icon: Icons.table_restaurant_outlined, activeIcon: Icons.table_restaurant, path: '/tables'),
    _NavItem(label: 'Settings', icon: Icons.settings_outlined, activeIcon: Icons.settings, path: '/settings'),
  ];

  static const _railExtras = [
    _NavItem(label: 'Kitchen', icon: Icons.soup_kitchen_outlined, activeIcon: Icons.soup_kitchen, path: '/kitchen'),
    _NavItem(label: 'Inventory', icon: Icons.inventory_2_outlined, activeIcon: Icons.inventory_2, path: '/inventory'),
    _NavItem(label: 'Expenses', icon: Icons.account_balance_wallet_outlined, activeIcon: Icons.account_balance_wallet, path: '/expenses'),
    _NavItem(label: 'Reports', icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart, path: '/reports'),
    _NavItem(label: 'History', icon: Icons.history_outlined, activeIcon: Icons.history, path: '/activity-log'),
  ];

  // Restricted nav for waiter role
  static const _waiterNavItems = [
    _NavItem(label: 'Dashboard', icon: Icons.home_outlined, activeIcon: Icons.home, path: '/dashboard'),
    _NavItem(label: 'Orders', icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long, path: '/orders'),
    _NavItem(label: 'Tables', icon: Icons.table_restaurant_outlined, activeIcon: Icons.table_restaurant, path: '/tables'),
  ];

  String _currentPath(BuildContext context) =>
      GoRouterState.of(context).matchedLocation;

  int _bottomIndex(String path, List<_NavItem> items) {
    final idx = items.indexWhere((e) => path.startsWith(e.path));
    return idx == -1 ? 0 : idx;
  }

  int _railIndex(String path, List<_NavItem> all) {
    final idx = all.indexWhere((e) => path.startsWith(e.path));
    return idx == -1 ? 0 : idx;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(staffRoleProvider);
    final trialDays = ref.watch(trialDaysProvider);
    // Pre-load settings so they are ready for PDF generation on any screen.
    ref.watch(settingsNotifierProvider);
    final isWaiter = role == 'waiter';
    final bottomItems = isWaiter ? _waiterNavItems : _navItems;
    final extras = isWaiter ? const <_NavItem>[] : _railExtras;
    final isTablet = MediaQuery.of(context).size.width >= 600;
    final base = isTablet
        ? _buildTabletLayout(context, bottomItems, extras)
        : _buildMobileLayout(context, bottomItems, extras);

    // Show trial warning banner.
    // ≤2 days remaining → soft amber "heads up" notice.
    // ≤0 days            → urgent red expiry banner.
    if (trialDays != null && trialDays <= 2) {
      return Column(
        children: [
          trialDays <= 0
              ? _TrialExpiryBanner(onUpgrade: () => context.go('/paywall'))
              : _TrialWarnBanner(
                  daysLeft: trialDays,
                  onUpgrade: () => context.go('/paywall'),
                ),
          Expanded(child: base),
        ],
      );
    }
    return base;
  }

  Widget _buildMobileLayout(BuildContext context, List<_NavItem> bottomItems, List<_NavItem> extras) {
    final path = _currentPath(context);
    final idx = _bottomIndex(path, bottomItems);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 48,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'More',
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Text(
          bottomItems.firstWhere((e) => path.startsWith(e.path),
                  orElse: () => extras.firstWhere(
                      (e) => path.startsWith(e.path),
                      orElse: () => bottomItems.first))
              .label,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        actions: const [_SyncIcon()],
      ),
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: BottomNavigationBar(
          currentIndex: idx,
          onTap: (i) => context.go(bottomItems[i].path),
          items: bottomItems
              .map(
                (e) => BottomNavigationBarItem(
                  icon: Icon(e.icon),
                  activeIcon: Icon(e.activeIcon),
                  label: e.label,
                ),
              )
              .toList(),
        ),
      ),
      // Drawer for extra items on mobile (hidden for waiter)
      drawer: extras.isEmpty ? null : _buildDrawer(context, path, extras),
    );
  }

  Widget _buildTabletLayout(BuildContext context, List<_NavItem> bottomItems, List<_NavItem> extras) {
    final path = _currentPath(context);
    final allItems = [...bottomItems, ...extras];
    final idx = _railIndex(path, allItems);
    return Scaffold(
      body: Row(
        children: [
          Container(
            decoration: const BoxDecoration(
              border: Border(right: BorderSide(color: AppColors.divider)),
            ),
            child: NavigationRail(
              selectedIndex: idx,
              onDestinationSelected: (i) => context.go(allItems[i].path),
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.local_cafe, color: Colors.white, size: 22),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'PlatoDesk',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
              destinations: allItems
                  .map(
                    (e) => NavigationRailDestination(
                      icon: Icon(e.icon),
                      selectedIcon: Icon(e.activeIcon),
                      label: Text(e.label),
                    ),
                  )
                  .toList(),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, String path, List<_NavItem> extras) {
    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              color: AppColors.primary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.local_cafe, color: Colors.white, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    'PlatoDesk',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
            ...extras.map(
              (e) => ListTile(
                leading: Icon(
                  path.startsWith(e.path) ? e.activeIcon : e.icon,
                  color: path.startsWith(e.path) ? AppColors.primary : AppColors.textSecondary,
                ),
                title: Text(
                  e.label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: path.startsWith(e.path) ? AppColors.primary : AppColors.textPrimary,
                        fontWeight: path.startsWith(e.path) ? FontWeight.w600 : FontWeight.normal,
                      ),
                ),
                selected: path.startsWith(e.path),
                selectedTileColor: AppColors.primaryLight.withValues(alpha: 0.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                onTap: () {
                  Navigator.of(context).pop();
                  context.go(e.path);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows cloud-sync state in the app bar (cloud-done / syncing spinner / cloud-off).
class _SyncIcon extends StatelessWidget {
  const _SyncIcon();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SyncStatus>(
      valueListenable: syncNotifier,
      builder: (_, status, __) {
        switch (status) {
          case SyncStatus.syncing:
            return const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          case SyncStatus.error:
            return Tooltip(
              message: 'Sync error — will retry when online',
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.cloud_off_outlined,
                    size: 20, color: AppColors.statusCancelled),
              ),
            );
          case SyncStatus.idle:
            return const SizedBox.shrink();
        }
      },
    );
  }
}

/// Soft amber warning shown 1-2 days before trial expiry.
class _TrialWarnBanner extends StatelessWidget {
  const _TrialWarnBanner({required this.daysLeft, required this.onUpgrade});
  final int daysLeft;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final label = daysLeft == 1 ? '1 day left' : '$daysLeft days left';
    return Material(
      color: const Color(0xFFFFF3CD),
      child: InkWell(
        onTap: onUpgrade,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.info_outline,
                  size: 16, color: Color(0xFF856404)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Trial ending soon ($label) — upgrade to keep access.',
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF856404)),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Upgrade',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrialExpiryBanner extends StatelessWidget {
  const _TrialExpiryBanner({required this.onUpgrade});
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFF3CD), // amber-50
      child: InkWell(
        onTap: onUpgrade,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  size: 18, color: Color(0xFF856404)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Your free trial ends today — upgrade in Settings to keep access.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF856404)),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Upgrade',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String path;
  const _NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.path,
  });
}
