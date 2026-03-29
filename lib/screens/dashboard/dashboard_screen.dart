import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_helpers.dart';
import '../../models/order_model.dart';
import '../../models/table_model.dart';
import '../../providers/order_providers.dart';
import '../../providers/table_providers.dart';
import '../../providers/inventory_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/repository_providers.dart';
import '../../widgets/order_type_badge.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Map<String, dynamic> _todayStats = {};
  bool _loadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final stats = await ref
        .read(orderRepositoryProvider)
        .getSummary(from: DateHelpers.todayStart, to: DateHelpers.todayEnd);
    if (mounted) setState(() { _todayStats = stats; _loadingStats = false; });
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsNotifierProvider);
    final activeAsync = ref.watch(activeOrdersProvider);
    final tablesAsync = ref.watch(tablesProvider);
    final lowStockAsync = ref.watch(lowStockProvider);
    final cafeName = settingsAsync.valueOrNull?[AppConstants.settingCafeName] ?? 'PlatoDesk';

    final revenue = (_todayStats['revenue'] as num?)?.toDouble() ?? 0;
    final orderCount = (_todayStats['order_count'] as num?)?.toInt() ?? 0;
    final avgOrder = (_todayStats['avg_order'] as num?)?.toDouble() ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.local_cafe, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Text(cafeName),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                DateHelpers.formatDate(DateTime.now()),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadStats();
          ref.read(activeOrdersProvider.notifier).load();
          ref.read(tablesProvider.notifier).load();
          ref.invalidate(lowStockProvider);
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isTablet = constraints.maxWidth >= 600;

            // Shared alert banner widget
            final alertBanner = lowStockAsync.when(
              data: (items) => items.isEmpty
                  ? const SizedBox()
                  : _AlertBanner(
                      message:
                          '${items.length} item${items.length == 1 ? '' : 's'} running low on stock',
                      icon: Icons.warning_amber_outlined,
                      color: AppColors.warning,
                      onTap: () => context.go('/inventory'),
                    ),
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
            );

            // Stats row widget
            final statsSection = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Today's Summary",
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                _loadingStats
                    ? const Center(child: CircularProgressIndicator())
                    : Row(
                        children: [
                          Expanded(
                              child: _StatCard(
                                  label: 'Revenue',
                                  value: CurrencyFormatter.format(revenue),
                                  icon: Icons.payments_outlined,
                                  color: AppColors.primary)),
                          const SizedBox(width: 10),
                          Expanded(
                              child: _StatCard(
                                  label: 'Orders',
                                  value: '$orderCount',
                                  icon: Icons.receipt_long_outlined,
                                  color: AppColors.brown)),
                          const SizedBox(width: 10),
                          Expanded(
                              child: _StatCard(
                                  label: 'Avg',
                                  value: CurrencyFormatter.formatCompact(avgOrder),
                                  icon: Icons.analytics_outlined,
                                  color: AppColors.delivery)),
                        ],
                      ),
                const SizedBox(height: 20),
              ],
            );

            // Quick actions widget
            final quickActionsSection = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Quick Actions',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.add_shopping_cart_outlined,
                        label: 'New Order',
                        color: AppColors.primary,
                        onTap: () => context.push('/orders/new'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.soup_kitchen_outlined,
                        label: 'Kitchen',
                        color: AppColors.brown,
                        onTap: () => context.go('/kitchen'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.bar_chart_outlined,
                        label: 'Reports',
                        color: AppColors.delivery,
                        onTap: () => context.go('/reports'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            );

            // Active orders widget
            final activeOrdersSection = activeAsync.when(
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
              data: (orders) {
                final active = orders.take(5).toList();
                if (active.isEmpty) return const SizedBox();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Active Orders',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        TextButton(
                          onPressed: () => context.go('/orders'),
                          child: Text('See all (${orders.length})',
                              style: const TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...active.map((o) => _ActiveOrderCard(order: o)),
                    const SizedBox(height: 20),
                  ],
                );
              },
            );

            // Tables section widget
            final tablesSection = tablesAsync.when(
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
              data: (tables) {
                if (tables.isEmpty) return const SizedBox();
                final free = tables.where((t) => t.isFree).length;
                final occ = tables.where((t) => t.isOccupied).length;
                final res = tables.where((t) => t.isReserved).length;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Tables',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        TextButton(
                          onPressed: () => context.go('/tables'),
                          child: const Text('Manage',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _TableStat(count: free, label: 'Free', color: AppColors.tableFree),
                        const SizedBox(width: 10),
                        _TableStat(count: occ, label: 'Occupied', color: AppColors.tableOccupied),
                        const SizedBox(width: 10),
                        _TableStat(count: res, label: 'Reserved', color: AppColors.tableReserved),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _MiniTableGrid(tables: tables, isTablet: isTablet),
                  ],
                );
              },
            );

            if (isTablet) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  alertBanner,
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            statsSection,
                            quickActionsSection,
                            activeOrdersSection,
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: tablesSection,
                      ),
                    ],
                  ),
                ],
              );
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                alertBanner,
                const SizedBox(height: 4),
                statsSection,
                quickActionsSection,
                activeOrdersSection,
                tablesSection,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AlertBanner extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _AlertBanner({
    required this.message,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(message,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
              ),
              Icon(Icons.chevron_right, size: 16, color: color),
            ],
          ),
        ),
      );
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: color)),
            ),
            Text(label,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: AppColors.textSecondary)),
          ],
        ),
      );
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 6),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
}

class _ActiveOrderCard extends StatelessWidget {
  final OrderModel order;
  const _ActiveOrderCard({required this.order});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => context.push('/orders/${order.id}'),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              OrderTypeBadge(type: order.type, small: true),
              const SizedBox(width: 8),
              Text(order.displayId,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(width: 8),
              Text(order.displayLabel,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
              const Spacer(),
              OrderStatusBadge(status: order.status),
            ],
          ),
        ),
      );
}

class _TableStat extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  const _TableStat(
      {required this.count, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Text('$count',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                      color: color)),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      );
}

class _MiniTableGrid extends StatelessWidget {
  final List<TableModel> tables;
  final bool isTablet;
  const _MiniTableGrid({required this.tables, this.isTablet = false});

  @override
  Widget build(BuildContext context) {
    final cellSize = isTablet ? 56.0 : 44.0;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tables.take(12).map((t) {
        final color = switch (t.status) {
          AppConstants.tableStatusOccupied => AppColors.tableOccupied,
          AppConstants.tableStatusReserved => AppColors.tableReserved,
          _ => AppColors.tableFree,
        };
        return GestureDetector(
          onTap: () => context.go('/tables'),
          child: Container(
            width: cellSize,
            height: cellSize,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.5)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.table_restaurant, size: 16, color: color),
                Text(
                  t.name.length > 5 ? t.name.substring(0, 5) : t.name,
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: color),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
