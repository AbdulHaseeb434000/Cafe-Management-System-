import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_colors.dart';

class MainScaffold extends StatelessWidget {
  final Widget child;

  const MainScaffold({super.key, required this.child});

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

  String _currentPath(BuildContext context) =>
      GoRouterState.of(context).matchedLocation;

  int _bottomIndex(String path) {
    final idx = _navItems.indexWhere((e) => path.startsWith(e.path));
    return idx == -1 ? 0 : idx;
  }

  int _railIndex(String path) {
    final allItems = [..._navItems, ..._railExtras];
    final idx = allItems.indexWhere((e) => path.startsWith(e.path));
    return idx == -1 ? 0 : idx;
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    return isTablet ? _buildTabletLayout(context) : _buildMobileLayout(context);
  }

  Widget _buildMobileLayout(BuildContext context) {
    final path = _currentPath(context);
    final idx = _bottomIndex(path);
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
          _navItems.firstWhere((e) => path.startsWith(e.path),
                  orElse: () => _railExtras.firstWhere(
                      (e) => path.startsWith(e.path),
                      orElse: () => _navItems.first))
              .label,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: BottomNavigationBar(
          currentIndex: idx,
          onTap: (i) => context.go(_navItems[i].path),
          items: _navItems
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
      // Drawer for extra items on mobile
      drawer: _buildDrawer(context, path),
    );
  }

  Widget _buildTabletLayout(BuildContext context) {
    final path = _currentPath(context);
    final allItems = [..._navItems, ..._railExtras];
    final idx = _railIndex(path);
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

  Widget _buildDrawer(BuildContext context, String path) {
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
            ..._railExtras.map(
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
