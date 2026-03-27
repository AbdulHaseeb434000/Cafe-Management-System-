import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_helpers.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/order_model.dart';
import '../../providers/order_providers.dart';
import '../../providers/repository_providers.dart';
import '../../widgets/order_type_badge.dart';
import '../../widgets/empty_state.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<OrderModel> _history = [];
  bool _loadingHistory = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() {
      if (_tab.index == 1 && _history.isEmpty) _loadHistory();
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _loadingHistory = true);
    final orders = await ref.read(orderRepositoryProvider).getHistory();
    setState(() {
      _history = orders;
      _loadingHistory = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeAsync = ref.watch(activeOrdersProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [Tab(text: 'Active'), Tab(text: 'History')],
          labelColor: AppColors.primaryDark,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          // Active orders
          RefreshIndicator(
            onRefresh: () async =>
                ref.read(activeOrdersProvider.notifier).load(),
            child: activeAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (orders) {
                if (orders.isEmpty) {
                  return EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No active orders',
                    subtitle: 'Tap + to create a new order',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: orders.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 16),
                  itemBuilder: (_, i) => _OrderTile(order: orders[i]),
                );
              },
            ),
          ),
          // History
          _loadingHistory
              ? const Center(child: CircularProgressIndicator())
              : _history.isEmpty
                  ? EmptyState(
                      icon: Icons.history_outlined,
                      title: 'No order history',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _history.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 16),
                      itemBuilder: (_, i) =>
                          _OrderTile(order: _history[i]),
                    ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/orders/new'),
        icon: const Icon(Icons.add),
        label: const Text('New Order'),
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  final OrderModel order;
  const _OrderTile({required this.order});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      onTap: () => context.push('/orders/${order.id}'),
      title: Row(
        children: [
          Text(
            order.displayId,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(width: 8),
          OrderTypeBadge(type: order.type, small: true),
          const SizedBox(width: 6),
          OrderStatusBadge(status: order.status),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          '${order.displayLabel} · ${DateHelpers.formatTime(order.createdAt)}',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.textSecondary),
        ),
      ),
      trailing: Text(
        CurrencyFormatter.format(order.total),
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
