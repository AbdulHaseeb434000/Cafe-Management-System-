import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_helpers.dart';
import '../../providers/repository_providers.dart';
import '../../repositories/expense_repository.dart';

enum _Range { today, week, month, custom }

enum _ReportType { sales, peakHours, topItems, payment, profitLoss }

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  _Range _range = _Range.today;
  _ReportType _reportType = _ReportType.sales;
  DateTime? _customFrom;
  DateTime? _customTo;
  bool _loading = false;

  Map<String, dynamic> _summary = {};
  List<Map<String, dynamic>> _topItems = [];
  List<Map<String, dynamic>> _byType = [];
  List<Map<String, dynamic>> _daily = [];
  List<Map<String, dynamic>> _hourly = [];
  List<Map<String, dynamic>> _paymentSplit = [];
  List<Map<String, dynamic>> _expenses = [];
  double _totalExpenses = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  (DateTime, DateTime) get _dateRange {
    final now = DateTime.now();
    return switch (_range) {
      _Range.today => (DateHelpers.todayStart, DateHelpers.todayEnd),
      _Range.week => (DateHelpers.weekStart(now), DateHelpers.todayEnd),
      _Range.month => (DateHelpers.monthStart(now), DateHelpers.monthEnd(now)),
      _Range.custom => (
          _customFrom ?? DateHelpers.todayStart,
          _customTo ?? DateHelpers.todayEnd,
        ),
    };
  }

  String get _dateRangeLabel {
    final (from, to) = _dateRange;
    final fmt = DateFormat('d MMM yyyy');
    if (_range == _Range.today) return fmt.format(from);
    return '${fmt.format(from)} – ${fmt.format(to)}';
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final (from, to) = _dateRange;
    final repo = ref.read(orderRepositoryProvider);
    final expRepo = ref.read(expenseRepositoryProvider);

    final fSummary = repo.getSummary(from: from, to: to);
    final fTop = repo.getTopItems(from: from, to: to, limit: 10);
    final fByType = repo.getRevenueByType(from: from, to: to);
    final fDaily = repo.getDailyRevenue(from: from, to: to);
    final fHourly = _range == _Range.today
        ? repo.getHourlyRevenue(from: from, to: to)
        : Future.value(<Map<String, dynamic>>[]);
    final fPayment = repo.getPaymentSplit(from: from, to: to);
    final fExpenses = expRepo.getByCategory(from: from, to: to);
    final fExpTotal = expRepo.getTotalForPeriod(from: from, to: to);

    final summary = await fSummary;
    final lists = await Future.wait([fTop, fByType, fDaily, fHourly, fPayment, fExpenses]);
    final expTotal = await fExpTotal;

    if (!mounted) return;
    setState(() {
      _summary = summary;
      _topItems = lists[0];
      _byType = lists[1];
      _daily = lists[2];
      _hourly = lists[3];
      _paymentSplit = lists[4];
      _expenses = lists[5];
      _totalExpenses = expTotal;
      _loading = false;
    });
  }

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
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (range == null) return false;
    setState(() {
      _customFrom = range.start;
      _customTo =
          DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59, 999);
    });
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final revenue = (_summary['revenue'] as num?)?.toDouble() ?? 0;
    final orderCount = (_summary['order_count'] as num?)?.toInt() ?? 0;
    final avgOrder = (_summary['avg_order'] as num?)?.toDouble() ?? 0;
    final itemsSold = (_summary['items_sold'] as num?)?.toInt() ?? 0;
    final cancelledCount = (_summary['cancelled_count'] as num?)?.toInt() ?? 0;
    final hasData = orderCount > 0 || _daily.isNotEmpty || _hourly.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  // ── Date range chips ────────────────────────────────
                  _DateChips(
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
                  const SizedBox(height: 6),
                  Text(
                    _dateRangeLabel,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 16),

                  // ── Summary grid 2×2 ────────────────────────────────
                  _SummaryGrid(
                    revenue: revenue,
                    orderCount: orderCount,
                    avgOrder: avgOrder,
                    itemsSold: itemsSold,
                  ),

                  // ── Cancelled warning ───────────────────────────────
                  if (cancelledCount > 0) ...[
                    const SizedBox(height: 10),
                    _CancelledBanner(count: cancelledCount),
                  ],

                  const SizedBox(height: 20),

                  const SizedBox(height: 16),

                  // ── Report type selector ────────────────────────────
                  _ReportTypeChips(
                    selected: _reportType,
                    onChanged: (t) => setState(() => _reportType = t),
                  ),
                  const SizedBox(height: 16),

                  // ── Detail section per report type ──────────────────
                  if (!hasData && _reportType != _ReportType.profitLoss)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Column(
                        children: [
                          Icon(Icons.bar_chart_outlined,
                              size: 48, color: AppColors.textDisabled),
                          const SizedBox(height: 12),
                          Text(
                            'No completed orders in this period',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    if (_reportType == _ReportType.sales) ...[
                      if (_range == _Range.today && _hourly.isNotEmpty) ...[
                        _SectionHeader(
                          title: 'Revenue by Hour',
                          subtitle: 'Today\'s hourly breakdown',
                        ),
                        const SizedBox(height: 8),
                        _HourlyBarChart(data: _hourly),
                        const SizedBox(height: 16),
                      ] else if (_range != _Range.today && _daily.isNotEmpty) ...[
                        _SectionHeader(
                          title: 'Daily Revenue',
                          subtitle: _daily.length == 1
                              ? '1 day with sales'
                              : '${_daily.length} days with sales',
                        ),
                        const SizedBox(height: 8),
                        _DailyBarChart(data: _daily),
                        const SizedBox(height: 16),
                      ],
                      if (_byType.isNotEmpty) ...[
                        _SectionHeader(title: 'Orders by Type'),
                        const SizedBox(height: 8),
                        _TypePieChart(data: _byType),
                      ],
                    ],

                    if (_reportType == _ReportType.peakHours) ...[
                      if (_range != _Range.today) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, size: 15, color: AppColors.warning),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Peak Hours data is available for Today only.',
                                  style: TextStyle(fontSize: 12, color: AppColors.warning),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (_hourly.isNotEmpty) ...[
                        _SectionHeader(
                          title: 'Revenue by Hour',
                          subtitle: 'Today\'s hourly breakdown',
                        ),
                        const SizedBox(height: 8),
                        _HourlyBarChart(data: _hourly),
                        const SizedBox(height: 16),
                        _SectionHeader(
                          title: 'Peak Hours',
                          subtitle: 'Orders & customers by hour',
                        ),
                        const SizedBox(height: 8),
                        _PeakHoursCard(data: _hourly),
                      ] else
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: Text('No hourly data yet today',
                                style: TextStyle(color: AppColors.textSecondary)),
                          ),
                        ),
                    ],

                    if (_reportType == _ReportType.topItems) ...[
                      if (_topItems.isNotEmpty) ...[
                        _SectionHeader(
                          title: 'Top Selling Items',
                          subtitle: 'By quantity sold — top ${_topItems.length}',
                        ),
                        const SizedBox(height: 8),
                        _TopItemsCard(items: _topItems),
                      ] else
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: Text('No items sold in this period',
                                style: TextStyle(color: AppColors.textSecondary)),
                          ),
                        ),
                    ],

                    if (_reportType == _ReportType.payment) ...[
                      if (_paymentSplit.isNotEmpty) ...[
                        _SectionHeader(title: 'Payment Methods'),
                        const SizedBox(height: 8),
                        _PaymentSplitCard(data: _paymentSplit),
                      ] else
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: Text('No payment data in this period',
                                style: TextStyle(color: AppColors.textSecondary)),
                          ),
                        ),
                    ],

                    if (_reportType == _ReportType.profitLoss) ...[
                      _ProfitLossCard(
                        revenue: revenue,
                        totalExpenses: _totalExpenses,
                        expensesByCategory: _expenses,
                      ),
                    ],
                  ],
                ],
              ),
            ),
    );
  }
}

// ── Report type chips ──────────────────────────────────────────────────────────

class _ReportTypeChips extends StatelessWidget {
  final _ReportType selected;
  final void Function(_ReportType) onChanged;
  const _ReportTypeChips({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip(Icons.show_chart, 'Sales', _ReportType.sales),
          const SizedBox(width: 8),
          _chip(Icons.schedule, 'Peak Hours', _ReportType.peakHours),
          const SizedBox(width: 8),
          _chip(Icons.star_border, 'Top Items', _ReportType.topItems),
          const SizedBox(width: 8),
          _chip(Icons.payments_outlined, 'Payments', _ReportType.payment),
          const SizedBox(width: 8),
          _chip(Icons.balance, 'P&L', _ReportType.profitLoss),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label, _ReportType type) {
    final sel = selected == type;
    return GestureDetector(
      onTap: () => onChanged(type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: sel ? AppColors.primary : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? AppColors.primary : AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: sel ? Colors.white : AppColors.textSecondary),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: sel ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Profit & Loss card ─────────────────────────────────────────────────────────

class _ProfitLossCard extends StatelessWidget {
  final double revenue;
  final double totalExpenses;
  final List<Map<String, dynamic>> expensesByCategory;

  const _ProfitLossCard({
    required this.revenue,
    required this.totalExpenses,
    required this.expensesByCategory,
  });

  @override
  Widget build(BuildContext context) {
    final netProfit = revenue - totalExpenses;
    final isProfit = netProfit >= 0;
    final profitColor = isProfit ? AppColors.success : AppColors.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary row
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: profitColor.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: profitColor.withValues(alpha: 0.25)),
          ),
          child: Column(
            children: [
              _plRow(
                label: 'Total Revenue',
                value: CurrencyFormatter.format(revenue),
                color: AppColors.success,
                icon: Icons.arrow_upward,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1, color: AppColors.divider),
              ),
              _plRow(
                label: 'Total Expenses',
                value: CurrencyFormatter.format(totalExpenses),
                color: AppColors.error,
                icon: Icons.arrow_downward,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1, color: AppColors.divider),
              ),
              _plRow(
                label: isProfit ? 'Net Profit' : 'Net Loss',
                value: CurrencyFormatter.format(netProfit.abs()),
                color: profitColor,
                icon: isProfit ? Icons.trending_up : Icons.trending_down,
                bold: true,
              ),
            ],
          ),
        ),
        if (expensesByCategory.isNotEmpty) ...[
          const SizedBox(height: 16),
          _SectionHeader(title: 'Expenses by Category'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              children: expensesByCategory.map((row) {
                final cat = row['category'] as String? ?? 'Other';
                final total = (row['total'] as num?)?.toDouble() ?? 0;
                final count = (row['count'] as num?)?.toInt() ?? 0;
                final ratio = totalExpenses > 0 ? total / totalExpenses : 0.0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(cat,
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w500)),
                          ),
                          Text(CurrencyFormatter.format(total),
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w700)),
                          const SizedBox(width: 8),
                          Text('${(ratio * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: ratio,
                                backgroundColor: AppColors.surfaceVariant,
                                color: AppColors.error.withValues(alpha: 0.7),
                                minHeight: 6,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('$count entries',
                              style: const TextStyle(
                                  fontSize: 10, color: AppColors.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ] else ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider),
            ),
            child: const Center(
              child: Text(
                'No expenses recorded for this period.\nAdd expenses in the Expenses module.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _plRow({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
    bool bold = false,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 13, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: bold ? 14 : 13,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 15 : 13,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ── Date chips ─────────────────────────────────────────────────────────────────

class _DateChips extends StatelessWidget {
  final _Range selected;
  final void Function(_Range) onChanged;
  const _DateChips({required this.selected, required this.onChanged});

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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? AppColors.primary : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? AppColors.primary : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: sel ? Colors.white : AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ── Section header ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  const _SectionHeader({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (subtitle != null) ...[
          const SizedBox(width: 8),
          Text(
            subtitle!,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ],
    );
  }
}

// ── Summary 2×2 grid ───────────────────────────────────────────────────────────

class _SummaryGrid extends StatelessWidget {
  final double revenue;
  final int orderCount;
  final double avgOrder;
  final int itemsSold;
  const _SummaryGrid({
    required this.revenue,
    required this.orderCount,
    required this.avgOrder,
    required this.itemsSold,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Total Revenue',
                value: CurrencyFormatter.formatCompact(revenue),
                icon: Icons.payments_outlined,
                color: AppColors.primaryDark,
                bgColor: AppColors.surfaceVariant,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                label: 'Orders Completed',
                value: '$orderCount',
                icon: Icons.receipt_long_outlined,
                color: AppColors.brown,
                bgColor: const Color(0xFFF3EBE8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Avg Order Value',
                value: CurrencyFormatter.formatCompact(avgOrder),
                icon: Icons.analytics_outlined,
                color: AppColors.delivery,
                bgColor: const Color(0xFFE0F2F1),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                label: 'Items Sold',
                value: '$itemsSold',
                icon: Icons.shopping_basket_outlined,
                color: AppColors.info,
                bgColor: const Color(0xFFE3F2FD),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color bgColor;
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
}

// ── Cancelled banner ───────────────────────────────────────────────────────────

class _CancelledBanner extends StatelessWidget {
  final int count;
  const _CancelledBanner({required this.count});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                size: 16, color: AppColors.warning),
            const SizedBox(width: 8),
            Text(
              '$count ${count == 1 ? 'order was' : 'orders were'} cancelled in this period',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.warning,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
}

// ── Hourly bar chart (Today) ────────────────────────────────────────────────────

class _HourlyBarChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const _HourlyBarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final maxRev = data.fold<double>(
        0, (m, e) => ((e['revenue'] as num?)?.toDouble() ?? 0) > m ? (e['revenue'] as num).toDouble() : m);

    final groups = data.asMap().entries.map((e) {
      final rev = (e.value['revenue'] as num?)?.toDouble() ?? 0;
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: rev,
            color: AppColors.primary,
            width: 18,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
          ),
        ],
      );
    }).toList();

    return _ChartCard(
      height: 180,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxRev * 1.2,
          barGroups: groups,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: AppColors.divider, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (value, _) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= data.length) return const SizedBox();
                  final hour = data[idx]['hour'] as int? ?? 0;
                  final label = hour == 0
                      ? '12a'
                      : hour < 12
                          ? '${hour}a'
                          : hour == 12
                              ? '12p'
                              : '${hour - 12}p';
                  return Text(label,
                      style: const TextStyle(fontSize: 9, color: AppColors.textSecondary));
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.brownDark.withValues(alpha: 0.85),
              getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                CurrencyFormatter.formatCompact(rod.toY),
                const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Daily bar chart (Week / Month / Custom) ────────────────────────────────────

class _DailyBarChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const _DailyBarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final maxRev = data.fold<double>(
        0, (m, e) => ((e['revenue'] as num?)?.toDouble() ?? 0) > m ? (e['revenue'] as num).toDouble() : m);

    final barWidth = data.length <= 7 ? 20.0 : data.length <= 14 ? 14.0 : 8.0;

    final groups = data.asMap().entries.map((e) {
      final rev = (e.value['revenue'] as num?)?.toDouble() ?? 0;
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: rev,
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            width: barWidth,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    }).toList();

    // Show at most ~7 x-axis labels to avoid crowding
    final step = (data.length / 7).ceil().clamp(1, 99);

    return _ChartCard(
      height: 180,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxRev * 1.2,
          barGroups: groups,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: AppColors.divider, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (value, _) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= data.length) return const SizedBox();
                  if (idx % step != 0) return const SizedBox();
                  final day = data[idx]['day'] as String? ?? '';
                  final parts = day.split('-');
                  final label =
                      parts.length == 3 ? '${parts[2]}/${parts[1]}' : day;
                  return Text(label,
                      style: const TextStyle(
                          fontSize: 9, color: AppColors.textSecondary));
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.brownDark.withValues(alpha: 0.85),
              getTooltipItem: (group, groupIdx, rod, __) {
                final day = groupIdx < data.length
                    ? (data[groupIdx]['day'] as String? ?? '')
                    : '';
                final parts = day.split('-');
                final label =
                    parts.length == 3 ? '${parts[2]}/${parts[1]}' : day;
                return BarTooltipItem(
                  '$label\n${CurrencyFormatter.formatCompact(rod.toY)}',
                  const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ── Order type pie chart ───────────────────────────────────────────────────────

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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            height: 110,
            child: PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 28,
                sections: data.map((e) {
                  final type = e['type'] as String? ?? '';
                  final rev = (e['revenue'] as num?)?.toDouble() ?? 0;
                  final pct = total > 0 ? rev / total * 100 : 0;
                  return PieChartSectionData(
                    color: _colorForType(type),
                    value: rev,
                    title: '${pct.toStringAsFixed(0)}%',
                    radius: 30,
                    titleStyle: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: data.map((e) {
                final type = e['type'] as String? ?? '';
                final rev = (e['revenue'] as num?)?.toDouble() ?? 0;
                final cnt = (e['order_count'] as num?)?.toInt() ?? 0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _colorForType(type),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _labelForType(type),
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            CurrencyFormatter.formatCompact(rev),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '$cnt orders',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
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

// ── Payment split card ─────────────────────────────────────────────────────────

class _PaymentSplitCard extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const _PaymentSplitCard({required this.data});

  Color _colorForMethod(String method) => switch (method) {
        AppConstants.paymentMethodCard => AppColors.info,
        _ => AppColors.success,
      };

  IconData _iconForMethod(String method) => switch (method) {
        AppConstants.paymentMethodCard => Icons.credit_card_outlined,
        _ => Icons.payments_outlined,
      };

  String _labelForMethod(String method) => switch (method) {
        AppConstants.paymentMethodCard => 'Card',
        _ => 'Cash',
      };

  @override
  Widget build(BuildContext context) {
    final total = data.fold<double>(
        0, (s, e) => s + ((e['amount'] as num?)?.toDouble() ?? 0));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: data.map((e) {
          final method = e['method'] as String? ?? '';
          final amount = (e['amount'] as num?)?.toDouble() ?? 0;
          final count = (e['count'] as num?)?.toInt() ?? 0;
          final ratio = total > 0 ? amount / total : 0.0;
          final color = _colorForMethod(method);

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(_iconForMethod(method), size: 16, color: color),
                    const SizedBox(width: 8),
                    Text(
                      _labelForMethod(method),
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Text(
                      CurrencyFormatter.formatCompact(amount),
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 36,
                      child: Text(
                        '${(ratio * 100).toStringAsFixed(0)}%',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ratio,
                          backgroundColor: AppColors.surfaceVariant,
                          color: color,
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$count txn',
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Top items card ─────────────────────────────────────────────────────────────

class _TopItemsCard extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  const _TopItemsCard({required this.items});

  @override
  Widget build(BuildContext context) {
    final maxQty = items.fold<double>(
        0,
        (m, e) =>
            ((e['total_qty'] as num?)?.toDouble() ?? 0) > m
                ? (e['total_qty'] as num).toDouble()
                : m);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                const Expanded(
                  flex: 3,
                  child: Text('Item',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary)),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  flex: 4,
                  child: SizedBox(),
                ),
                SizedBox(
                  width: 30,
                  child: Text('Qty',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary)),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 60,
                  child: Text('Revenue',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 4),
          ...items.take(8).toList().asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            final name = item['name'] as String? ?? '';
            final qty = (item['total_qty'] as num?)?.toDouble() ?? 0;
            final rev = (item['revenue'] as num?)?.toDouble() ?? 0;
            final ratio = maxQty > 0 ? qty / maxQty : 0.0;
            final isTop = idx == 0;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Row(
                      children: [
                        if (isTop)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(Icons.star_rounded,
                                size: 12, color: AppColors.primary),
                          ),
                        Expanded(
                          child: Text(
                            name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isTop
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 4,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: ratio,
                        backgroundColor: AppColors.surfaceVariant,
                        color: isTop
                            ? AppColors.primary
                            : AppColors.primaryLight,
                        minHeight: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 30,
                    child: Text(
                      '${qty.toInt()}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 60,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        CurrencyFormatter.formatCompact(rev),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Peak hours card ────────────────────────────────────────────────────────────

class _PeakHoursCard extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const _PeakHoursCard({required this.data});

  String _hourLabel(int hour) {
    if (hour == 0) return '12 AM';
    if (hour < 12) return '${hour} AM';
    if (hour == 12) return '12 PM';
    return '${hour - 12} PM';
  }

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox();

    final maxOrders = data.fold<int>(
        0, (m, e) => ((e['order_count'] as num?)?.toInt() ?? 0) > m ? (e['order_count'] as num).toInt() : m);

    // Sort by order_count descending for display
    final sorted = [...data]..sort((a, b) =>
        ((b['order_count'] as num?)?.toInt() ?? 0)
            .compareTo((a['order_count'] as num?)?.toInt() ?? 0));

    final peakHour = sorted.first['hour'] as int? ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Peak hour highlight
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.trending_up, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  'Peak: ${_hourLabel(peakHour)} — ${sorted.first['order_count']} orders',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: const [
                SizedBox(width: 52, child: Text('Hour', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
                SizedBox(width: 8),
                Expanded(child: SizedBox()),
                SizedBox(width: 8),
                SizedBox(width: 40, child: Text('Orders', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
                SizedBox(width: 8),
                SizedBox(width: 44, child: Text('Customers', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 4),
          ...sorted.map((row) {
            final hour = row['hour'] as int? ?? 0;
            final orders = (row['order_count'] as num?)?.toInt() ?? 0;
            final customers = (row['customer_count'] as num?)?.toInt() ?? 0;
            final ratio = maxOrders > 0 ? orders / maxOrders : 0.0;
            final isPeak = hour == peakHour;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  SizedBox(
                    width: 52,
                    child: Text(
                      _hourLabel(hour),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isPeak ? FontWeight.w700 : FontWeight.w400,
                        color: isPeak ? AppColors.primary : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: ratio,
                        backgroundColor: AppColors.surfaceVariant,
                        color: isPeak ? AppColors.primary : AppColors.primaryLight,
                        minHeight: 7,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '$orders',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isPeak ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 44,
                    child: Text(
                      '$customers',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Chart card wrapper ─────────────────────────────────────────────────────────

class _ChartCard extends StatelessWidget {
  final Widget child;
  final double height;
  const _ChartCard({required this.child, required this.height});

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        padding: const EdgeInsets.fromLTRB(8, 12, 12, 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: child,
      );
}
