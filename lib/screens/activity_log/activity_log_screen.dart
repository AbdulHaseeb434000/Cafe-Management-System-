import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_colors.dart';
import '../../models/activity_log_model.dart';
import '../../providers/activity_log_providers.dart';

class ActivityLogScreen extends ConsumerStatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  ConsumerState<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends ConsumerState<ActivityLogScreen> {
  DateTime? _from;
  DateTime? _to;

  List<ActivityLogModel> _applyFilter(List<ActivityLogModel> logs) {
    if (_from == null && _to == null) return logs;
    final endOfTo = _to != null
        ? DateTime(_to!.year, _to!.month, _to!.day, 23, 59, 59, 999)
        : null;
    return logs.where((l) {
      if (_from != null && l.createdAt.isBefore(_from!)) return false;
      if (endOfTo != null && l.createdAt.isAfter(endOfTo)) return false;
      return true;
    }).toList();
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: (_from != null && _to != null)
          ? DateTimeRange(start: _from!, end: _to!)
          : null,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
                primary: AppColors.primary,
                onPrimary: Colors.white,
              ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _from = picked.start;
        _to = picked.end;
      });
    }
  }

  Future<void> _exportCsv(List<ActivityLogModel> logs) async {
    if (logs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No entries to export')),
      );
      return;
    }

    final dateFmt = DateFormat('yyyy-MM-dd');
    final timeFmt = DateFormat('HH:mm:ss');
    final buf = StringBuffer();
    buf.writeln('Date,Time,Action,Entity Type,Name,Details');

    for (final log in logs) {
      final date = dateFmt.format(log.createdAt);
      final time = timeFmt.format(log.createdAt);
      final action = _ActionMeta.of(log.actionType).label;
      final details = (log.details ?? '').replaceAll('"', '""');
      final name = log.entityName.replaceAll('"', '""');
      buf.writeln('$date,$time,"$action","${log.entityType}","$name","$details"');
    }

    final dir = await getTemporaryDirectory();
    final today = dateFmt.format(DateTime.now());
    final file = File('${dir.path}/cafedesk_activity_$today.csv');
    await file.writeAsString(buf.toString());

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/csv')],
        subject: 'CafeDesk Activity Log — $today',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(activityLogsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Log'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range_outlined),
            tooltip: 'Filter by date',
            onPressed: _pickDateRange,
          ),
          Consumer(builder: (ctx, ref2, _) {
            return logsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (logs) {
                final filtered = _applyFilter(logs);
                return IconButton(
                  icon: const Icon(Icons.download_outlined),
                  tooltip: 'Export to CSV',
                  onPressed: () => _exportCsv(filtered),
                );
              },
            );
          }),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear history',
            onPressed: () => _confirmClear(context),
          ),
        ],
      ),
      body: logsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (logs) {
          final filtered = _applyFilter(logs);
          final grouped = _groupByDate(filtered);
          final isTablet = MediaQuery.of(context).size.width >= 600;

          Widget content;
          if (filtered.isEmpty && (_from != null || _to != null)) {
            content = _EmptyState(hasFilter: true);
          } else if (logs.isEmpty) {
            content = _EmptyState(hasFilter: false);
          } else if (filtered.isEmpty) {
            content = _EmptyState(hasFilter: false);
          } else {
            content = ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: _countItems(grouped),
              itemBuilder: (context, index) =>
                  _buildItem(context, grouped, index),
            );
          }

          Widget body = Column(
            children: [
              if (_from != null || _to != null) _FilterChip(
                from: _from,
                to: _to,
                onClear: () => setState(() {
                  _from = null;
                  _to = null;
                }),
              ),
              Expanded(child: content),
            ],
          );

          if (isTablet) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: body,
              ),
            );
          }
          return body;
        },
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> _groupByDate(List<ActivityLogModel> logs) {
    final groups = <String, List<ActivityLogModel>>{};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (final log in logs) {
      final d = DateTime(
          log.createdAt.year, log.createdAt.month, log.createdAt.day);
      String header;
      if (d == today) {
        header = 'Today';
      } else if (d == yesterday) {
        header = 'Yesterday';
      } else {
        header = '${d.day} ${_monthName(d.month)} ${d.year}';
      }
      groups.putIfAbsent(header, () => []).add(log);
    }

    return groups.entries
        .map((e) => {'header': e.key, 'items': e.value})
        .toList();
  }

  int _countItems(List<Map<String, dynamic>> grouped) {
    int count = 0;
    for (final g in grouped) {
      count += 1 + (g['items'] as List).length;
    }
    return count;
  }

  Widget _buildItem(
      BuildContext context, List<Map<String, dynamic>> grouped, int index) {
    int i = 0;
    for (final group in grouped) {
      if (index == i) return _DateHeader(label: group['header'] as String);
      i++;
      final items = group['items'] as List<ActivityLogModel>;
      if (index < i + items.length) return _LogTile(log: items[index - i]);
      i += items.length;
    }
    return const SizedBox.shrink();
  }

  Future<void> _confirmClear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear History'),
        content: const Text(
            'This will permanently delete all activity log entries. Continue?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Clear',
                  style:
                      TextStyle(color: Theme.of(ctx).colorScheme.error))),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(activityLogRepositoryProvider).clear();
      ref.invalidate(activityLogsProvider);
    }
  }

  String _monthName(int month) {
    const names = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return names[month];
  }
}

// ── Filter chip bar ──────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final DateTime? from;
  final DateTime? to;
  final VoidCallback onClear;

  const _FilterChip({required this.from, required this.to, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM');
    String label;
    if (from != null && to != null) {
      label = '${fmt.format(from!)} – ${fmt.format(to!)}';
    } else if (from != null) {
      label = 'From ${fmt.format(from!)}';
    } else {
      label = 'Until ${fmt.format(to!)}';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.primaryLight.withValues(alpha: 0.2),
      child: Row(
        children: [
          const Icon(Icons.filter_alt_outlined,
              size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  )),
          const Spacer(),
          GestureDetector(
            onTap: onClear,
            child: const Icon(Icons.close, size: 16, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

// ── Date header ──────────────────────────────────────────────────────────────

class _DateHeader extends StatelessWidget {
  final String label;
  const _DateHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
      ),
    );
  }
}

// ── Individual log tile ──────────────────────────────────────────────────────

class _LogTile extends StatelessWidget {
  final ActivityLogModel log;
  const _LogTile({required this.log});

  @override
  Widget build(BuildContext context) {
    final meta = _ActionMeta.of(log.actionType);
    final timeStr = _formatTime(log.createdAt);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: meta.color.withValues(alpha: 0.12),
          child: Icon(meta.icon, color: meta.color, size: 18),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                meta.label,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              timeStr,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              log.entityName,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textPrimary,
                  ),
              overflow: TextOverflow.ellipsis,
            ),
            if (log.details != null && log.details!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                log.details!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool hasFilter;
  const _EmptyState({required this.hasFilter});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasFilter ? Icons.search_off : Icons.history,
            size: 64,
            color: AppColors.textSecondary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            hasFilter
                ? 'No entries in this period'
                : 'No activity recorded yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            hasFilter
                ? 'Try adjusting the date range filter.'
                : 'Actions like adding menu items,\ncreating orders, and more will appear here.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

// ── Action metadata map ───────────────────────────────────────────────────────

class _ActionMeta {
  final String label;
  final IconData icon;
  final Color color;

  const _ActionMeta(this.label, this.icon, this.color);

  static _ActionMeta of(String actionType) {
    return _map[actionType] ??
        const _ActionMeta(
            'Activity', Icons.info_outline, AppColors.textSecondary);
  }

  static const _map = <String, _ActionMeta>{
    'category_created': _ActionMeta(
        'Category Added', Icons.add_circle_outline, Colors.green),
    'category_updated': _ActionMeta(
        'Category Updated', Icons.edit_outlined, AppColors.primary),
    'category_deleted':
        _ActionMeta('Category Deleted', Icons.delete_outline, Colors.red),

    'menu_item_created':
        _ActionMeta('Item Added', Icons.fastfood, Colors.green),
    'menu_item_updated':
        _ActionMeta('Item Updated', Icons.edit_outlined, AppColors.primary),
    'menu_item_price_changed':
        _ActionMeta('Price Changed', Icons.attach_money, Colors.orange),
    'menu_item_deleted':
        _ActionMeta('Item Deleted', Icons.delete_outline, Colors.red),
    'menu_item_toggled': _ActionMeta(
        'Availability Changed', Icons.toggle_on_outlined, Colors.blue),

    'table_created': _ActionMeta(
        'Table Added', Icons.table_restaurant, Colors.green),
    'table_updated': _ActionMeta(
        'Table Updated', Icons.edit_outlined, AppColors.primary),
    'table_deleted':
        _ActionMeta('Table Deleted', Icons.delete_outline, Colors.red),

    'order_created': _ActionMeta(
        'Order Created', Icons.receipt_long_outlined, Colors.green),
    'order_cancelled': _ActionMeta(
        'Order Cancelled', Icons.cancel_outlined, Colors.red),
    'order_completed': _ActionMeta(
        'Order Completed', Icons.check_circle_outline, Colors.teal),

    'payment_received':
        _ActionMeta('Payment Received', Icons.payments_outlined, Colors.teal),

    'inventory_item_created': _ActionMeta(
        'Stock Item Added', Icons.inventory_2_outlined, Colors.green),
    'inventory_item_updated': _ActionMeta(
        'Stock Item Updated', Icons.edit_outlined, AppColors.primary),
    'inventory_item_deleted': _ActionMeta(
        'Stock Item Deleted', Icons.delete_outline, Colors.red),
    'inventory_adjusted':
        _ActionMeta('Stock Adjusted', Icons.tune, Colors.deepPurple),
  };
}
