import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_helpers.dart';
import '../../providers/repository_providers.dart';

enum _Range { today, week, month, custom }

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  _Range _range = _Range.today;
  DateTime? _customFrom;
  DateTime? _customTo;
  bool _loading = false;

  // Report data
  Map<String, dynamic> _summary = {};
  List<Map<String, dynamic>> _topItems = [];
  List<Map<String, dynamic>> _byType = [];
  List<Map<String, dynamic>> _daily = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  (DateTime, DateTime) get _dateRange {
    final now = DateTime.now();
    return switch (_range) {
      _Range.today => (DateHelpers.todayStart, DateHelpers.todayEnd),
      _Range.week => (
          DateHelpers.weekStart(now),
          DateHelpers.todayEnd
        ),
      _Range.month => (
          DateHelpers.monthStart(now),
          DateHelpers.monthEnd(now)
        ),
      _Range.custom => (
          _customFrom ?? DateHelpers.todayStart,
          _customTo ?? DateHelpers.todayEnd
        ),
    };
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final (from, to) = _dateRange;
    final repo = ref.read(orderRepositoryProvider);

    final summary = await repo.getDailySummary(from);
    final topItems =
        await repo.getTopItems(from: from, to: to, limit: 10);
    final byType =
        await repo.getRevenueByType(from: from, to: to);
    final daily =
        await repo.getDailyRevenue(from: from, to: to);

    setState(() {
      _summary = summary;
      _topItems = topItems;
      _byType = byType;
      _daily = daily;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final revenue =
        (_summary['revenue'] as num?)?.toDouble() ?? 0;
    final orderCount =
        (_summary['order_count'] as num?)?.toInt() ?? 0;
    final avgOrder =
        (_summary['avg_order'] as num?)?.toDouble() ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Date range chips
                  _DateRangeRow(
                    selected: _range,
                    onChanged: (r) async {
                      if (r == _Range.custom) {
                        final picked = await _pickCustomRange();
                        if (!picked) return;
                      }
                      setState(() => _range = r);
                      _load();
                    },
                  ),
                  const SizedBox(height: 16),

                  // Summary cards
                  Row(
                    children: [
                      Expanded(
                          child: _SummaryCard(
                              label: 'Revenue',
                              value: CurrencyFormatter.format(revenue),
                              icon: Icons.payments_outlined,
                              color: AppColors.primary)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _SummaryCard(
                              label: 'Orders',
                              value: '$orderCount',
                              icon: Icons.receipt_long_outlined,
                              color: AppColors.brown)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _SummaryCard(
                              label: 'Avg Order',
                              value: CurrencyFormatter.formatCompact(avgOrder),
                              icon: Icons.analytics_outlined,
                              color: AppColors.delivery)),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Daily trend
                  if (_daily.isNotEmpty) ...[
                    _sectionTitle('Daily Revenue'),
                    const SizedBox(height: 8),
                    _DailyChart(data: _daily),
                    const SizedBox(height: 20),
                  ],

                  // Top items
                  if (_topItems.isNotEmpty) ...[
                    _sectionTitle('Top Selling Items'),
                    const SizedBox(height: 8),
                    _TopItemsChart(items: _topItems),
                    const SizedBox(height: 20),
                  ],

                  // By order type
                  if (_byType.isNotEmpty) ...[
                    _sectionTitle('Revenue by Order Type'),
                    const SizedBox(height: 8),
                    _TypePieChart(data: _byType),
                    const SizedBox(height: 20),
                  ],

                  if (_topItems.isEmpty &&
                      _daily.isEmpty &&
                      _byType.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(
                        child: Text('No completed orders in this period'),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _sectionTitle(String t) => Text(t,
      style: Theme.of(context)
          .textTheme
          .titleSmall
          ?.copyWith(fontWeight: FontWeight.w700));

  Future<bool> _pickCustomRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: _customFrom ?? DateHelpers.todayStart,
        end: _customTo ?? DateTime.now(),
      ),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
    if (range == null) return false;
    setState(() {
      _customFrom = range.start;
      _customTo = range.end;
    });
    return true;
  }
}

class _DateRangeRow extends StatelessWidget {
  final _Range selected;
  final void Function(_Range) onChanged;
  const _DateRangeRow(
      {required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip('Today', _Range.today),
          const SizedBox(width: 8),
          _chip('This Week', _Range.week),
          const SizedBox(width: 8),
          _chip('This Month', _Range.month),
          const SizedBox(width: 8),
          _chip('Custom', _Range.custom),
        ],
      ),
    );
  }

  Widget _chip(String label, _Range range) {
    final sel = selected == range;
    return GestureDetector(
      onTap: () => onChanged(range),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? AppColors.primary : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: sel ? AppColors.primary : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
              color: sel ? Colors.white : AppColors.textPrimary,
              fontWeight: FontWeight.w500,
              fontSize: 13),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _SummaryCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

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
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: color),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(label,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: AppColors.textSecondary)),
          ],
        ),
      );
}

class _DailyChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const _DailyChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final spots = data.asMap().entries.map((e) {
      final rev = (e.value['revenue'] as num?)?.toDouble() ?? 0;
      return FlSpot(e.key.toDouble(), rev);
    }).toList();

    return Container(
      height: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (v, _) {
                  final idx = v.toInt();
                  if (idx < 0 || idx >= data.length) {
                    return const SizedBox();
                  }
                  final day = data[idx]['day'] as String? ?? '';
                  final parts = day.split('-');
                  final label =
                      parts.length == 3 ? '${parts[2]}/${parts[1]}' : day;
                  return Text(label,
                      style: const TextStyle(fontSize: 10));
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppColors.primary,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.primary.withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopItemsChart extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  const _TopItemsChart({required this.items});

  @override
  Widget build(BuildContext context) {
    final maxQty = items.fold<double>(
        0,
        (m, e) =>
            ((e['total_qty'] as num?)?.toDouble() ?? 0) > m
                ? (e['total_qty'] as num).toDouble()
                : m);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: items.take(8).map((item) {
          final name = item['name'] as String? ?? '';
          final qty = (item['total_qty'] as num?)?.toDouble() ?? 0;
          final ratio = maxQty > 0 ? qty / maxQty : 0.0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 100,
                  child: Text(name,
                      style: const TextStyle(fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ratio,
                      backgroundColor: AppColors.surfaceVariant,
                      color: AppColors.primary,
                      minHeight: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${qty.toInt()}',
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _TypePieChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const _TypePieChart({required this.data});

  Color _colorForType(String type) => switch (type) {
        AppConstants.orderTypeDineIn => AppColors.dineIn,
        AppConstants.orderTypeDelivery => AppColors.delivery,
        _ => AppColors.takeaway,
      };

  String _labelForType(String type) => switch (type) {
        AppConstants.orderTypeDineIn => 'Dine-In',
        AppConstants.orderTypeDelivery => 'Delivery',
        _ => 'Takeaway',
      };

  @override
  Widget build(BuildContext context) {
    final total = data.fold<double>(
        0, (s, e) => s + ((e['revenue'] as num?)?.toDouble() ?? 0));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 30,
                sections: data.map((e) {
                  final type = e['type'] as String? ?? '';
                  final rev =
                      (e['revenue'] as num?)?.toDouble() ?? 0;
                  final pct = total > 0 ? rev / total * 100 : 0;
                  return PieChartSectionData(
                    color: _colorForType(type),
                    value: rev,
                    title: '${pct.toStringAsFixed(0)}%',
                    radius: 30,
                    titleStyle: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: data.map((e) {
                final type = e['type'] as String? ?? '';
                final rev =
                    (e['revenue'] as num?)?.toDouble() ?? 0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                              color: _colorForType(type),
                              shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Text(_labelForType(type),
                              style:
                                  const TextStyle(fontSize: 12))),
                      Text(CurrencyFormatter.formatCompact(rev),
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
