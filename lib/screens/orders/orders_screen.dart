import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_helpers.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/order_model.dart';
import '../../providers/order_providers.dart';
import '../../providers/repository_providers.dart';
import '../../widgets/order_type_badge.dart';
import '../../widgets/empty_state.dart';

// ── Period selector enum ───────────────────────────────────────────────────────

enum _Period { today, week, month, year, all }

extension _PeriodLabel on _Period {
  String get label => switch (this) {
        _Period.today => 'Today',
        _Period.week => 'This Week',
        _Period.month => 'This Month',
        _Period.year => 'This Year',
        _Period.all => 'All Time',
      };
}

// ── Orders screen ──────────────────────────────────────────────────────────────

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
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
          // Active orders tab
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
          // History tab
          const _HistoryTab(),
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

// ── History tab ────────────────────────────────────────────────────────────────

class _HistoryTab extends ConsumerStatefulWidget {
  const _HistoryTab();

  @override
  ConsumerState<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends ConsumerState<_HistoryTab>
    with AutomaticKeepAliveClientMixin {
  static const _pageSize = 50;

  _Period _period = _Period.today;
  Map<String, dynamic> _summary = {};
  List<OrderModel> _orders = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  bool _exporting = false;

  final ScrollController _scroll = ScrollController();

  @override
  bool get wantKeepAlive => false; // always reload when tab revisited

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >=
            _scroll.position.maxScrollExtent - 200 &&
        !_loadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  (DateTime, DateTime) get _dateRange {
    final now = DateTime.now();
    return switch (_period) {
      _Period.today => (DateHelpers.todayStart, DateHelpers.todayEnd),
      _Period.week => (DateHelpers.weekStart(now), DateHelpers.todayEnd),
      _Period.month =>
        (DateHelpers.monthStart(now), DateHelpers.monthEnd(now)),
      _Period.year =>
        (DateHelpers.yearStart(now), DateHelpers.yearEnd(now)),
      _Period.all =>
        (DateHelpers.epochStart, DateHelpers.yearEnd(now)),
    };
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _orders = [];
        _summary = {};
        _hasMore = false;
      });
    }

    final (from, to) = _dateRange;
    final repo = ref.read(orderRepositoryProvider);

    final fSummary = repo.getSummary(from: from, to: to);
    final fOrders = repo.getHistory(
        from: from, to: to, limit: _pageSize, offset: 0);

    final summary = await fSummary;
    final orders = await fOrders;

    if (!mounted) return;
    setState(() {
      _summary = summary;
      _orders = orders;
      _hasMore = orders.length == _pageSize;
      _loading = false;
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);

    final (from, to) = _dateRange;
    final more = await ref.read(orderRepositoryProvider).getHistory(
          from: from,
          to: to,
          limit: _pageSize,
          offset: _orders.length,
        );

    if (!mounted) return;
    setState(() {
      _orders.addAll(more);
      _hasMore = more.length == _pageSize;
      _loadingMore = false;
    });
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final (from, to) = _dateRange;
      final rows = await ref
          .read(orderRepositoryProvider)
          .getHistoryForExport(from: from, to: to);

      final buf = StringBuffer();
      buf.writeln(
          'Order ID,Date,Time,Type,Table/Customer,Items,Subtotal,Discount,Tax,Total,Status');

      for (final r in rows) {
        final id = r['id'] as int?;
        final displayId = '#${id?.toString().padLeft(4, '0') ?? '0000'}';
        final createdAt = DateTime.parse(r['created_at'] as String);
        final date = DateFormat('dd/MM/yyyy').format(createdAt);
        final time = DateFormat('hh:mm a').format(createdAt);
        final type = r['type'] == 'dine_in'
            ? 'Dine-In'
            : r['type'] == 'delivery'
                ? 'Delivery'
                : 'Takeaway';
        final ref_ = (r['table_name'] ?? r['customer_name'] ?? '-') as String;
        final items = (r['items_summary'] as String? ?? '');
        final row = [
          displayId,
          date,
          time,
          type,
          '"$ref_"',
          '"$items"',
          (r['subtotal'] as num?)?.toStringAsFixed(2) ?? '0.00',
          (r['discount_amount'] as num?)?.toStringAsFixed(2) ?? '0.00',
          (r['tax_amount'] as num?)?.toStringAsFixed(2) ?? '0.00',
          (r['total'] as num?)?.toStringAsFixed(2) ?? '0.00',
          r['status'] as String? ?? '',
        ].join(',');
        buf.writeln(row);
      }

      final dir = await getTemporaryDirectory();
      final label = _period.label.replaceAll(' ', '_').toLowerCase();
      final ts = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final file = File('${dir.path}/orders_${label}_$ts.csv');
      await file.writeAsString(buf.toString());

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'text/csv')],
          subject: 'Orders – ${_period.label}',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  // ── Date group helpers ─────────────────────────────────────────────────

  String _groupKey(DateTime dt) {
    final today = DateHelpers.todayStart;
    final yesterday = today.subtract(const Duration(days: 1));
    if (dt.year == today.year &&
        dt.month == today.month &&
        dt.day == today.day) { return '__today__'; }
    if (dt.year == yesterday.year &&
        dt.month == yesterday.month &&
        dt.day == yesterday.day) { return '__yesterday__'; }
    return DateFormat('yyyy-MM-dd').format(dt);
  }

  String _groupLabel(String key) {
    if (key == '__today__') {
      return 'Today, ${DateFormat('d MMM yyyy').format(DateTime.now())}';
    }
    if (key == '__yesterday__') {
      final y = DateTime.now().subtract(const Duration(days: 1));
      return 'Yesterday, ${DateFormat('d MMM yyyy').format(y)}';
    }
    final dt = DateTime.parse(key);
    return DateFormat('EEE, d MMM yyyy').format(dt);
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final revenue = (_summary['revenue'] as num?)?.toDouble() ?? 0;
    final orderCount = (_summary['order_count'] as num?)?.toInt() ?? 0;
    final avgOrder = (_summary['avg_order'] as num?)?.toDouble() ?? 0;
    final cancelled = (_summary['cancelled_count'] as num?)?.toInt() ?? 0;

    // Build ordered list of (groupKey, [orders]) for the loaded slice
    final grouped = <String, List<OrderModel>>{};
    final groupOrder = <String>[];
    for (final o in _orders) {
      final k = _groupKey(o.createdAt);
      if (!grouped.containsKey(k)) {
        grouped[k] = [];
        groupOrder.add(k);
      }
      grouped[k]!.add(o);
    }

    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: CustomScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // ── Sticky header: period chips + summary ──────────────────
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Period chips
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _Period.values.map((p) {
                              final sel = _period == p;
                              return Padding(
                                padding:
                                    const EdgeInsets.only(right: 6),
                                child: GestureDetector(
                                  onTap: () {
                                    if (_period == p) return;
                                    setState(() => _period = p);
                                    _load(reset: true);
                                  },
                                  child: AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 160),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: sel
                                          ? AppColors.primary
                                          : AppColors.surfaceVariant,
                                      borderRadius:
                                          BorderRadius.circular(20),
                                      border: Border.all(
                                        color: sel
                                            ? AppColors.primary
                                            : AppColors.border,
                                      ),
                                    ),
                                    child: Text(
                                      p.label,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: sel
                                            ? Colors.white
                                            : AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Export button
                      _exporting
                          ? const SizedBox(
                              width: 32,
                              height: 32,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2),
                            )
                          : IconButton(
                              icon: const Icon(
                                  Icons.file_download_outlined),
                              tooltip: 'Export CSV',
                              onPressed:
                                  orderCount == 0 ? null : _export,
                            ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Summary card
                if (!_loading)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: _SummaryBanner(
                      revenue: revenue,
                      orderCount: orderCount,
                      avgOrder: avgOrder,
                      cancelledCount: cancelled,
                    ),
                  ),

                const SizedBox(height: 4),
              ],
            ),
          ),

          // ── Loading spinner ────────────────────────────────────────
          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )

          // ── Empty state ────────────────────────────────────────────
          else if (_orders.isEmpty)
            SliverFillRemaining(
              child: EmptyState(
                icon: Icons.history_outlined,
                title: 'No orders found',
                subtitle: 'No completed or cancelled orders\nin this period',
              ),
            )

          // ── Grouped order list ─────────────────────────────────────
          else ...[
            for (final key in groupOrder) ...[
              // Date group header
              SliverToBoxAdapter(
                child: _DateGroupHeader(label: _groupLabel(key)),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) {
                    final order = grouped[key]![i];
                    return _HistoryOrderTile(order: order);
                  },
                  childCount: grouped[key]!.length,
                ),
              ),
            ],

            // Load more / end indicator
            SliverToBoxAdapter(
              child: _loadingMore
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child:
                          Center(child: CircularProgressIndicator()),
                    )
                  : _hasMore
                      ? Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 16, horizontal: 16),
                          child: OutlinedButton.icon(
                            onPressed: _loadMore,
                            icon: const Icon(Icons.expand_more),
                            label: const Text('Load More'),
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 20),
                          child: Center(
                            child: Text(
                              '${_orders.length} order${_orders.length == 1 ? '' : 's'} shown',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                      color: AppColors.textSecondary),
                            ),
                          ),
                        ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Summary banner ─────────────────────────────────────────────────────────────

class _SummaryBanner extends StatelessWidget {
  final double revenue;
  final int orderCount;
  final double avgOrder;
  final int cancelledCount;

  const _SummaryBanner({
    required this.revenue,
    required this.orderCount,
    required this.avgOrder,
    required this.cancelledCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _Metric(
                label: 'Revenue',
                value: CurrencyFormatter.formatCompact(revenue),
                color: AppColors.primaryDark,
              ),
              _vDivider(),
              _Metric(
                label: 'Orders',
                value: '$orderCount',
                color: AppColors.brown,
              ),
              _vDivider(),
              _Metric(
                label: 'Avg',
                value: CurrencyFormatter.formatCompact(avgOrder),
                color: AppColors.delivery,
              ),
            ],
          ),
          if (cancelledCount > 0) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 14, color: AppColors.warning),
                  const SizedBox(width: 6),
                  Text(
                    '$cancelledCount ${cancelledCount == 1 ? 'order' : 'orders'} cancelled',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.warning,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _vDivider() => Container(
        width: 1,
        height: 36,
        color: AppColors.divider,
        margin: const EdgeInsets.symmetric(horizontal: 12),
      );
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Metric(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ── Date group header ──────────────────────────────────────────────────────────

class _DateGroupHeader extends StatelessWidget {
  final String label;
  const _DateGroupHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Row(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
          ),
          const SizedBox(width: 8),
          const Expanded(child: Divider(height: 1)),
        ],
      ),
    );
  }
}

// ── History order tile ─────────────────────────────────────────────────────────

class _HistoryOrderTile extends StatelessWidget {
  final OrderModel order;
  const _HistoryOrderTile({required this.order});

  @override
  Widget build(BuildContext context) {
    final isCancelled =
        order.status == 'cancelled';

    return InkWell(
      onTap: () => context.push('/orders/${order.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: type indicator bar
            Container(
              width: 3,
              height: 48,
              decoration: BoxDecoration(
                color: isCancelled
                    ? AppColors.statusCancelled
                    : _typeColor(order.type),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),

            // Center: order info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        order.displayId,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 6),
                      OrderTypeBadge(type: order.type, small: true),
                      if (isCancelled) ...[
                        const SizedBox(width: 4),
                        OrderStatusBadge(status: order.status),
                      ],
                      const Spacer(),
                      Text(
                        CurrencyFormatter.format(order.total),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: isCancelled
                              ? AppColors.textSecondary
                              : AppColors.primaryDark,
                          decoration: isCancelled
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.access_time_outlined,
                          size: 11, color: AppColors.textSecondary),
                      const SizedBox(width: 3),
                      Text(
                        DateHelpers.formatTime(order.createdAt),
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
                      if (order.tableName != null) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.table_restaurant_outlined,
                            size: 11, color: AppColors.textSecondary),
                        const SizedBox(width: 3),
                        Text(
                          order.tableName!,
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary),
                        ),
                      ] else if (order.customerName != null) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.person_outline,
                            size: 11, color: AppColors.textSecondary),
                        const SizedBox(width: 3),
                        Text(
                          order.customerName!,
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary),
                        ),
                      ],
                      const Spacer(),
                      if ((order.itemCount ?? 0) > 0)
                        Text(
                          '${order.itemCount} item${order.itemCount == 1 ? '' : 's'}',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textSecondary),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _typeColor(String type) => switch (type) {
        'dine_in' => AppColors.dineIn,
        'delivery' => AppColors.delivery,
        _ => AppColors.takeaway,
      };
}

// ── Active order tile (unchanged) ──────────────────────────────────────────────

class _OrderTile extends StatelessWidget {
  final OrderModel order;
  const _OrderTile({required this.order});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      onTap: () => context.push('/orders/${order.id}'),
      title: Row(
        children: [
          Text(
            order.displayId,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          Text(
            CurrencyFormatter.format(order.total),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Wrap(
          spacing: 4,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OrderTypeBadge(type: order.type, small: true),
            OrderStatusBadge(status: order.status),
            Text(
              '${order.displayLabel} · ${DateHelpers.formatTime(order.createdAt)}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
