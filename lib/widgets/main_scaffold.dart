import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/currency_formatter.dart';
import '../providers/auth_providers.dart';
import '../providers/settings_providers.dart';
import '../services/session_service.dart';
import '../services/supabase/supabase_service.dart';

class MainScaffold extends ConsumerStatefulWidget {
  final Widget child;

  const MainScaffold({super.key, required this.child});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold>
    with WidgetsBindingObserver {
  /// User dismissed the trial warning banner this session.
  /// Resets when the app is restarted. Expiry banner (≤0 days) is never
  /// dismissible — it forces the user to take action.
  bool _trialBannerDismissed = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Re-checks plan validity against the locally cached restaurant row
  /// whenever the app returns to the foreground. No network call needed —
  /// the trial_end_date is already in the cached restaurantProvider.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPlanExpiry();
      _checkSessionTimeout();
    }
  }

  void _checkPlanExpiry() {
    final restaurant = ref.read(restaurantProvider);
    if (restaurant != null && !SupabaseService.isPlanActive(restaurant)) {
      if (mounted) context.go('/paywall');
    }
  }

  void _checkSessionTimeout() {
    if (!SessionService.instance.checkTimeout()) return;
    SessionService.instance.clear();
    signOutAndClear(ref);
    if (!mounted) return;
    context.go('/login');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Session expired. Please sign in again.'),
        duration: Duration(seconds: 4),
      ),
    );
  }

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

  Future<void> _confirmSignOut(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await signOutAndClear(ref);
      if (mounted) context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(staffRoleProvider);
    // Pre-load settings so they are ready for PDF generation on any screen.
    final settings = ref.watch(settingsNotifierProvider).valueOrNull ?? {};
    // Keep CurrencyFormatter in sync with the user's chosen symbol.
    CurrencyFormatter.currentSymbol =
        settings[AppConstants.settingCurrencySymbol] ??
            AppConstants.defaultCurrencySymbol;
    // Sync session timeout from settings so changes apply immediately.
    final timeoutMin = int.tryParse(
            settings[AppConstants.settingSessionTimeout] ?? '') ??
        AppConstants.defaultSessionTimeoutMinutes;
    SessionService.instance.timeout = Duration(minutes: timeoutMin);
    // L1: Use trialDaysProvider if set; fall back to computing from restaurant.
    final restaurant = ref.watch(restaurantProvider);
    int? trialDays = ref.watch(trialDaysProvider);
    if (trialDays == null && restaurant != null) {
      trialDays = SupabaseService.trialDaysLeft(restaurant);
    }
    final isWaiter = role == 'waiter';
    final bottomItems = isWaiter ? _waiterNavItems : _navItems;
    final extras = isWaiter ? const <_NavItem>[] : _railExtras;
    final isTablet = MediaQuery.of(context).size.width >= 600;
    // Wrap child in a transparent GestureDetector to reset the inactivity
    // timer on any tap or drag, without blocking child hit-tests.
    final trackedChild = GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (_) => SessionService.instance.touch(),
      onPanDown: (_) => SessionService.instance.touch(),
      child: widget.child,
    );
    final base = isTablet
        ? _buildTabletLayout(context, bottomItems, extras, trackedChild)
        : _buildMobileLayout(context, bottomItems, extras, trackedChild);

    // Trial warning banners:
    // ≤0 days  → urgent expiry banner (NOT dismissible — forces action)
    // ≤2 days  → soft amber warning (dismissible for the current session)
    if (trialDays != null && trialDays <= 2) {
      final expired = trialDays <= 0;
      // Show warning only if not dismissed; expiry is always shown
      if (expired || !_trialBannerDismissed) {
        return Column(
          children: [
            expired
                ? _TrialExpiryBanner(
                    onUpgrade: () => context.go('/paywall'))
                : _TrialWarnBanner(
                    daysLeft: trialDays,
                    onUpgrade: () => context.go('/paywall'),
                    onDismiss: () =>
                        setState(() => _trialBannerDismissed = true),
                  ),
            Expanded(child: base),
          ],
        );
      }
    }
    return base;
  }

  Widget _buildMobileLayout(BuildContext context, List<_NavItem> bottomItems,
      List<_NavItem> extras, Widget child) {
    final path = _currentPath(context);
    final idx = _bottomIndex(path, bottomItems);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 48,
        leading: extras.isEmpty
            ? null
            : Builder(
                builder: (ctx) => DrawerButton(
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              ),
        title: Text(
          bottomItems
              .firstWhere((e) => path.startsWith(e.path),
                  orElse: () => extras.firstWhere(
                      (e) => path.startsWith(e.path),
                      orElse: () => const _NavItem(
                          label: '',
                          icon: Icons.home_outlined,
                          activeIcon: Icons.home,
                          path: '')))
              .label,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => _confirmSignOut(context),
          ),
          const _SyncIcon(),
        ],
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

  Widget _buildTabletLayout(BuildContext context, List<_NavItem> bottomItems,
      List<_NavItem> extras, Widget child) {
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
              trailing: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: IconButton(
                  icon: const Icon(Icons.logout),
                  tooltip: 'Sign out',
                  color: AppColors.textSecondary,
                  onPressed: () => _confirmSignOut(context),
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
/// Has an [onDismiss] callback so users can hide it for the session.
class _TrialWarnBanner extends StatelessWidget {
  const _TrialWarnBanner({
    required this.daysLeft,
    required this.onUpgrade,
    required this.onDismiss,
  });
  final int daysLeft;
  final VoidCallback onUpgrade;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final label = daysLeft == 1 ? '1 day left' : '$daysLeft days left';
    return Material(
      color: const Color(0xFFFFF3CD),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            const Icon(Icons.info_outline,
                size: 15, color: Color(0xFF856404)),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: onUpgrade,
                child: Text(
                  'Trial ending soon ($label) — tap to upgrade.',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF856404)),
                ),
              ),
            ),
            const SizedBox(width: 4),
            TextButton(
              onPressed: onUpgrade,
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Upgrade',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            // Dismiss button — hides banner for the rest of this session
            IconButton(
              onPressed: onDismiss,
              icon: const Icon(Icons.close, size: 15),
              color: const Color(0xFF856404),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              tooltip: 'Dismiss',
            ),
          ],
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
