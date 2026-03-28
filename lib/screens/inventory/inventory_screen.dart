import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_helpers.dart';
import '../../models/inventory_item_model.dart';
import '../../models/inventory_log_model.dart';
import '../../providers/inventory_providers.dart';
import '../../providers/repository_providers.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/confirm_dialog.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final inventoryAsync = ref.watch(inventoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Add Item',
            onPressed: () => _showItemDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search inventory...',
                prefixIcon: Icon(Icons.search, size: 20),
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
            ),
          ),
          Expanded(
            child: inventoryAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (items) {
                var filtered = items;
                if (_search.isNotEmpty) {
                  filtered = items
                      .where((i) =>
                          i.name.toLowerCase().contains(_search))
                      .toList();
                }

                if (filtered.isEmpty) {
                  return EmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: items.isEmpty
                        ? 'No inventory items'
                        : 'No results',
                    subtitle: items.isEmpty
                        ? 'Tap + to add stock items'
                        : null,
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.read(inventoryProvider.notifier).load(),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 16),
                    itemBuilder: (_, i) => _InventoryTile(
                      item: filtered[i],
                      onAdjust: () =>
                          _showAdjustDialog(context, filtered[i]),
                      onEdit: () =>
                          _showItemDialog(context, existing: filtered[i]),
                      onDelete: () =>
                          _deleteItem(context, filtered[i]),
                      onViewLog: () =>
                          _showLog(context, filtered[i]),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showItemDialog(BuildContext context,
      {InventoryItemModel? existing}) {
    final nameCtrl =
        TextEditingController(text: existing?.name ?? '');
    final unitCtrl =
        TextEditingController(text: existing?.unit ?? '');
    final qtyCtrl = TextEditingController(
        text: existing?.quantity.toString() ?? '0');
    final thresholdCtrl = TextEditingController(
        text: existing?.lowStockThreshold.toString() ?? '0');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title:
            Text(existing == null ? 'Add Item' : 'Edit Item'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration:
                    const InputDecoration(labelText: 'Item name *'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: unitCtrl,
                decoration: const InputDecoration(
                    labelText: 'Unit *',
                    hintText: 'kg, litres, pcs…'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qtyCtrl,
                decoration:
                    const InputDecoration(labelText: 'Initial Quantity'),
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: thresholdCtrl,
                decoration: const InputDecoration(
                    labelText: 'Low Stock Alert At',
                    hintText: '0 = disabled'),
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final unit = unitCtrl.text.trim();
              if (name.isEmpty || unit.isEmpty) return;
              final qty =
                  double.tryParse(qtyCtrl.text.trim()) ?? 0;
              final threshold =
                  double.tryParse(thresholdCtrl.text.trim()) ?? 0;

              if (existing == null) {
                ref.read(inventoryProvider.notifier).add(
                      InventoryItemModel.create(
                        name: name,
                        unit: unit,
                        quantity: qty,
                        lowStockThreshold: threshold,
                      ),
                    );
              } else {
                ref.read(inventoryProvider.notifier).edit(
                      existing.copyWith(
                        name: name,
                        unit: unit,
                        lowStockThreshold: threshold,
                      ),
                    );
              }
              Navigator.pop(ctx);
            },
            child: Text(existing == null ? 'Add' : 'Save'),
          ),
        ],
      ),
    );
  }

  void _showAdjustDialog(
      BuildContext context, InventoryItemModel item) {
    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    String direction = 'add';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          title: Text('Adjust — ${item.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Current: ${item.quantity} ${item.unit}',
                style: Theme.of(ctx)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _SegmentButton(
                      label: '+ Add Stock',
                      selected: direction == 'add',
                      color: AppColors.success,
                      onTap: () =>
                          setLocalState(() => direction = 'add'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SegmentButton(
                      label: '− Remove',
                      selected: direction == 'remove',
                      color: AppColors.error,
                      onTap: () => setLocalState(
                          () => direction = 'remove'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                autofocus: true,
                decoration: InputDecoration(
                    labelText: 'Amount (${item.unit})'),
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(
                    labelText: 'Reason (optional)'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final amount =
                    double.tryParse(amountCtrl.text.trim()) ?? 0;
                if (amount <= 0) return;
                final change =
                    direction == 'add' ? amount : -amount;
                ref.read(inventoryProvider.notifier).adjust(
                      item,
                      change,
                      reasonCtrl.text.trim().isEmpty
                          ? null
                          : reasonCtrl.text.trim(),
                    );
                Navigator.pop(ctx);
              },
              child: const Text('Adjust'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteItem(
      BuildContext context, InventoryItemModel item) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete Item',
      message: 'Delete "${item.name}" from inventory?',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (ok) ref.read(inventoryProvider.notifier).remove(item.id!);
  }

  Future<void> _showLog(
      BuildContext context, InventoryItemModel item) async {
    final logs = await ref
        .read(inventoryRepositoryProvider)
        .getLogs(item.id!);

    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (_, sc) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('${item.name} — Log',
                  style: Theme.of(ctx).textTheme.titleMedium),
            ),
            const Divider(height: 1),
            Expanded(
              child: logs.isEmpty
                  ? const Center(child: Text('No adjustments yet'))
                  : ListView.separated(
                      controller: sc,
                      itemCount: logs.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1),
                      itemBuilder: (_, i) =>
                          _LogTile(log: logs[i], unit: item.unit),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InventoryTile extends StatelessWidget {
  final InventoryItemModel item;
  final VoidCallback onAdjust;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onViewLog;

  const _InventoryTile({
    required this.item,
    required this.onAdjust,
    required this.onEdit,
    required this.onDelete,
    required this.onViewLog,
  });

  @override
  Widget build(BuildContext context) {
    final isLow = item.isLowStock;
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isLow
              ? AppColors.warning.withValues(alpha: 0.15)
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          Icons.inventory_2_outlined,
          color: isLow ? AppColors.warning : AppColors.textSecondary,
          size: 22,
        ),
      ),
      title: Text(item.name,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${item.quantity} ${item.unit}'),
          if (isLow)
            const Text('Low stock!',
                style: TextStyle(
                    color: AppColors.warning,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.tune_outlined, size: 20),
            tooltip: 'Adjust',
            onPressed: onAdjust,
            color: AppColors.primary,
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'log') onViewLog();
              if (v == 'edit') onEdit();
              if (v == 'delete') onDelete();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                  value: 'log', child: Text('View Log')),
              const PopupMenuItem(
                  value: 'edit', child: Text('Edit')),
              const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete',
                      style: TextStyle(color: AppColors.error))),
            ],
          ),
        ],
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  final InventoryLogModel log;
  final String unit;
  const _LogTile({required this.log, required this.unit});

  @override
  Widget build(BuildContext context) {
    final isAdd = log.isAddition;
    return ListTile(
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: (isAdd ? AppColors.success : AppColors.error)
            .withValues(alpha: 0.15),
        child: Icon(
          isAdd ? Icons.add : Icons.remove,
          size: 16,
          color: isAdd ? AppColors.success : AppColors.error,
        ),
      ),
      title: Text(
        '${isAdd ? '+' : ''}${log.changeAmount} $unit',
        style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isAdd ? AppColors.success : AppColors.error),
      ),
      subtitle: Text(log.reason ?? 'No reason'),
      trailing: Text(
        DateHelpers.formatDateTime(log.createdAt),
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _SegmentButton(
      {required this.label,
      required this.selected,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.15) : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: selected ? color : AppColors.border),
          ),
          child: Text(label,
              style: TextStyle(
                  color: selected ? color : AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12)),
        ),
      );
}
