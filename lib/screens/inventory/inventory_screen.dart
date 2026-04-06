import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
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

class _InventoryScreenState extends ConsumerState<InventoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(icon: Icon(Icons.inventory_2_outlined, size: 18), text: 'Items'),
            Tab(icon: Icon(Icons.add_shopping_cart_outlined, size: 18), text: 'Purchase'),
            Tab(icon: Icon(Icons.outbox_outlined, size: 18), text: 'Issue'),
            Tab(icon: Icon(Icons.bar_chart_outlined, size: 18), text: 'Reports'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _ItemsTab(onSwitchToTab: (i) => _tabCtrl.animateTo(i)),
          _PurchaseTab(onSuccess: () => _tabCtrl.animateTo(0)),
          _IssueTab(onSuccess: () => _tabCtrl.animateTo(0)),
          const _ReportsTab(),
        ],
      ),
    );
  }
}

// ── Items Tab ─────────────────────────────────────────────────────────────────

class _ItemsTab extends ConsumerStatefulWidget {
  const _ItemsTab({required this.onSwitchToTab});
  final void Function(int) onSwitchToTab;

  @override
  ConsumerState<_ItemsTab> createState() => _ItemsTabState();
}

class _ItemsTabState extends ConsumerState<_ItemsTab> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final inventoryAsync = ref.watch(inventoryProvider);

    return Column(
      children: [
        // Stock value summary
        inventoryAsync.maybeWhen(
          data: (items) {
            final totalValue =
                items.fold<double>(0, (sum, i) => sum + i.stockValue);
            final lowCount = items.where((i) => i.isLowStock).length;
            return Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Stock Value',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary)),
                        Text(CurrencyFormatter.format(totalValue),
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15)),
                      ],
                    ),
                  ),
                  if (lowCount > 0) ...[
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$lowCount low stock',
                        style: const TextStyle(
                            color: AppColors.warning,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  // Quick add item button
                  FilledButton.tonalIcon(
                    onPressed: () => _showItemDialog(context),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Item'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      textStyle: const TextStyle(fontSize: 12),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            );
          },
          orElse: () => const SizedBox.shrink(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search items...',
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
                    .where((i) => i.name.toLowerCase().contains(_search))
                    .toList();
              }

              if (filtered.isEmpty) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    EmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: items.isEmpty
                          ? 'No inventory items'
                          : 'No results',
                      subtitle: items.isEmpty
                          ? 'Add items then use Purchase tab to receive stock'
                          : null,
                    ),
                    if (items.isEmpty) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => widget.onSwitchToTab(1),
                        icon: const Icon(
                            Icons.add_shopping_cart_outlined,
                            size: 16),
                        label: const Text('Go to Purchase'),
                      ),
                    ],
                  ],
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
    );
  }

  void _showItemDialog(BuildContext context, {InventoryItemModel? existing}) {
    final nameCtrl =
        TextEditingController(text: existing?.name ?? '');
    final unitCtrl =
        TextEditingController(text: existing?.unit ?? '');
    final thresholdCtrl = TextEditingController(
        text: existing?.lowStockThreshold.toString() ?? '0');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add Item' : 'Edit Item'),
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
                    labelText: 'Unit *', hintText: 'kg, litres, pcs…'),
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
              final threshold =
                  double.tryParse(thresholdCtrl.text.trim()) ?? 0;

              if (existing == null) {
                ref.read(inventoryProvider.notifier).add(
                      InventoryItemModel.create(
                        name: name,
                        unit: unit,
                        quantity: 0,
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
                  ? const Center(child: Text('No log entries yet'))
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
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onViewLog;

  const _InventoryTile({
    required this.item,
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
          if (item.unitCost > 0)
            Text(
              'Unit cost: ${CurrencyFormatter.format(item.unitCost)}',
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary),
            ),
          if (isLow)
            const Text('Low stock!',
                style: TextStyle(
                    color: AppColors.warning,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
        ],
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (v) {
          if (v == 'log') onViewLog();
          if (v == 'edit') onEdit();
          if (v == 'delete') onDelete();
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'log', child: Text('View Log')),
          const PopupMenuItem(value: 'edit', child: Text('Edit')),
          const PopupMenuItem(
              value: 'delete',
              child: Text('Delete',
                  style: TextStyle(color: AppColors.error))),
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
    String typeLabel;
    Color typeColor;
    if (log.type == 'purchase') {
      typeLabel = 'Purchase';
      typeColor = AppColors.success;
    } else if (log.type == 'issue') {
      typeLabel = 'Issue to kitchen';
      typeColor = AppColors.error;
    } else {
      typeLabel = 'Adjustment';
      typeColor = AppColors.textSecondary;
    }

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
      subtitle: Text([
        typeLabel,
        if (log.reason != null && log.reason!.isNotEmpty)
          '· ${log.reason}',
      ].join(' '),
          style: TextStyle(fontSize: 12, color: typeColor)),
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

// ── Purchase Tab ──────────────────────────────────────────────────────────────

class _PurchaseTab extends ConsumerStatefulWidget {
  final VoidCallback onSuccess;
  const _PurchaseTab({required this.onSuccess});

  @override
  ConsumerState<_PurchaseTab> createState() => _PurchaseTabState();
}

class _PurchaseTabState extends ConsumerState<_PurchaseTab> {
  final _formKey = GlobalKey<FormState>();
  InventoryItemModel? _selectedItem;
  final _qtyCtrl  = TextEditingController();
  final _costCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _costCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save(List<InventoryItemModel> items) async {
    if (!_formKey.currentState!.validate()) return;
    final item = _selectedItem;
    if (item == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Select an item')));
      return;
    }
    final qty  = double.tryParse(_qtyCtrl.text.trim()) ?? 0;
    final cost = double.tryParse(_costCtrl.text.trim()) ?? 0;

    setState(() => _saving = true);
    try {
      await ref.read(inventoryProvider.notifier).purchase(
            item,
            quantity: qty,
            unitCost: cost,
            note: _noteCtrl.text.trim().isEmpty
                ? null
                : _noteCtrl.text.trim(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Received ${qty.toStringAsFixed(2)} ${item.unit} of ${item.name}'),
            backgroundColor: AppColors.success,
          ),
        );
        _formKey.currentState!.reset();
        setState(() {
          _selectedItem = null;
          _qtyCtrl.clear();
          _costCtrl.clear();
          _noteCtrl.clear();
        });
        widget.onSuccess();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inventoryAsync = ref.watch(inventoryProvider);

    return inventoryAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (items) => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Section header
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.add_shopping_cart_outlined,
                        color: AppColors.success, size: 20),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Receive Stock',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: AppColors.success)),
                        Text(
                            'Record items received from supplier',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.success
                                    .withValues(alpha: 0.8))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              DropdownButtonFormField<InventoryItemModel>(
                value: _selectedItem,
                decoration: const InputDecoration(
                  labelText: 'Item *',
                  border: OutlineInputBorder(),
                ),
                items: items
                    .map((item) => DropdownMenuItem(
                          value: item,
                          child: Text(item.name),
                        ))
                    .toList(),
                onChanged: (v) => setState(() {
                  _selectedItem = v;
                  if (v != null && v.unitCost > 0) {
                    _costCtrl.text = v.unitCost.toStringAsFixed(2);
                  }
                }),
                validator: (v) => v == null ? 'Select an item' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _qtyCtrl,
                decoration: InputDecoration(
                  labelText: 'Quantity Received *',
                  border: const OutlineInputBorder(),
                  suffixText: _selectedItem?.unit ?? '',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if ((double.tryParse(v.trim()) ?? 0) <= 0) {
                    return 'Must be greater than 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _costCtrl,
                decoration: const InputDecoration(
                  labelText: 'Unit Cost (optional)',
                  border: OutlineInputBorder(),
                  hintText: '0.00',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Supplier / Note (optional)',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 24),

              FilledButton.icon(
                onPressed: _saving ? null : () => _save(items),
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Saving…' : 'Save Purchase'),
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.success),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Issue Tab ─────────────────────────────────────────────────────────────────

class _IssueTab extends ConsumerStatefulWidget {
  final VoidCallback onSuccess;
  const _IssueTab({required this.onSuccess});

  @override
  ConsumerState<_IssueTab> createState() => _IssueTabState();
}

class _IssueTabState extends ConsumerState<_IssueTab> {
  final _formKey = GlobalKey<FormState>();
  InventoryItemModel? _selectedItem;
  final _qtyCtrl    = TextEditingController();
  final _reasonCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final item = _selectedItem;
    if (item == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Select an item')));
      return;
    }
    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 0;
    if (qty > item.quantity) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Insufficient stock (available: ${item.quantity} ${item.unit})')));
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(inventoryProvider.notifier).issue(
            item,
            quantity: qty,
            reason: _reasonCtrl.text.trim().isEmpty
                ? null
                : _reasonCtrl.text.trim(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Issued ${qty.toStringAsFixed(2)} ${item.unit} of ${item.name} to kitchen'),
            backgroundColor: AppColors.success,
          ),
        );
        _formKey.currentState!.reset();
        setState(() {
          _selectedItem = null;
          _qtyCtrl.clear();
          _reasonCtrl.clear();
        });
        widget.onSuccess();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inventoryAsync = ref.watch(inventoryProvider);

    return inventoryAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (items) => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Section header
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.outbox_outlined,
                        color: AppColors.primary, size: 20),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Issue to Kitchen',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: AppColors.primary)),
                        Text(
                            'Deduct items sent to kitchen / consumed',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.primary
                                    .withValues(alpha: 0.8))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              DropdownButtonFormField<InventoryItemModel>(
                value: _selectedItem,
                decoration: const InputDecoration(
                  labelText: 'Item *',
                  border: OutlineInputBorder(),
                ),
                items: items
                    .map((item) => DropdownMenuItem(
                          value: item,
                          child: Text(
                              '${item.name}  (${item.quantity} ${item.unit} available)'),
                        ))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _selectedItem = v),
                validator: (v) => v == null ? 'Select an item' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _qtyCtrl,
                decoration: InputDecoration(
                  labelText: 'Quantity to Issue *',
                  border: const OutlineInputBorder(),
                  suffixText: _selectedItem?.unit ?? '',
                  helperText: _selectedItem != null
                      ? 'Available: ${_selectedItem!.quantity} ${_selectedItem!.unit}'
                      : null,
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  final n = double.tryParse(v.trim()) ?? 0;
                  if (n <= 0) return 'Must be greater than 0';
                  if (_selectedItem != null && n > _selectedItem!.quantity) {
                    return 'Exceeds available stock (${_selectedItem!.quantity})';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _reasonCtrl,
                decoration: const InputDecoration(
                  labelText: 'Reason / Note (optional)',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 24),

              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.outbox_outlined),
                label: Text(_saving ? 'Saving…' : 'Issue to Kitchen'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Reports Tab ───────────────────────────────────────────────────────────────

class _ReportsTab extends ConsumerStatefulWidget {
  const _ReportsTab();

  @override
  ConsumerState<_ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends ConsumerState<_ReportsTab> {
  // Period selector: 0=Today, 1=7 days, 2=30 days
  int _period = 1;
  double _purchaseCost = 0;
  double _issueCost    = 0;
  bool _loading = false;

  static const _periodLabels = ['Today', '7 Days', '30 Days'];

  DateTime get _from {
    final now = DateTime.now();
    return switch (_period) {
      0 => DateTime(now.year, now.month, now.day),
      1 => DateTime(now.year, now.month, now.day - 6),
      _ => DateTime(now.year, now.month, now.day - 29),
    };
  }

  @override
  void initState() {
    super.initState();
    _loadCosts();
  }

  Future<void> _loadCosts() async {
    setState(() => _loading = true);
    final repo = ref.read(inventoryRepositoryProvider);
    final from = _from;
    final to   = DateTime.now();
    try {
      final purchase = await repo.getPurchaseCostForPeriod(from: from, to: to);
      // Issue cost: sum of (|change_amount| * unit_cost) for type='issue'
      // Re-use purchase query pattern — get logs directly
      final logs     = await repo.getLogsForPeriod(type: 'issue', from: from, to: to);
      final issue = logs.fold<double>(0, (s, l) => s + l.totalCost);
      if (mounted) {
        setState(() {
          _purchaseCost = purchase;
          _issueCost    = issue;
          _loading      = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inventoryAsync = ref.watch(inventoryProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Period selector
          SegmentedButton<int>(
            segments: [
              for (var i = 0; i < _periodLabels.length; i++)
                ButtonSegment(value: i, label: Text(_periodLabels[i])),
            ],
            selected: {_period},
            onSelectionChanged: (s) {
              setState(() => _period = s.first);
              _loadCosts();
            },
            style: SegmentedButton.styleFrom(
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(height: 16),

          // Cost summary cards
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.add_shopping_cart_outlined,
                  label: 'Purchases',
                  value: CurrencyFormatter.format(_purchaseCost),
                  color: AppColors.success,
                  loading: _loading,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.outbox_outlined,
                  label: 'Issued (Cost)',
                  value: CurrencyFormatter.format(_issueCost),
                  color: AppColors.primary,
                  loading: _loading,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Stock overview
          inventoryAsync.maybeWhen(
            data: (items) {
              final totalValue =
                  items.fold<double>(0, (s, i) => s + i.stockValue);
              final lowItems =
                  items.where((i) => i.isLowStock).toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _StatCard(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Total Stock Value',
                    value: CurrencyFormatter.format(totalValue),
                    color: AppColors.brown,
                    loading: false,
                    wide: true,
                  ),
                  if (lowItems.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const _SectionHeader(
                        title: 'Low Stock Alerts',
                        subtitle: 'Items below threshold'),
                    const SizedBox(height: 8),
                    ...lowItems.map((item) => Padding(
                          padding:
                              const EdgeInsets.only(bottom: 6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.warning
                                  .withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: AppColors.warning
                                      .withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber,
                                    size: 16,
                                    color: AppColors.warning),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(item.name,
                                        style: const TextStyle(
                                            fontWeight:
                                                FontWeight.w600,
                                            fontSize: 13))),
                                Text(
                                  '${item.quantity} ${item.unit}',
                                  style: const TextStyle(
                                      color: AppColors.warning,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        )),
                  ] else ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline,
                              color: AppColors.success, size: 18),
                          SizedBox(width: 8),
                          Text('All items are well stocked',
                              style: TextStyle(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ],

                  // Top items by stock value
                  const SizedBox(height: 16),
                  const _SectionHeader(
                      title: 'Top Items by Stock Value',
                      subtitle: 'Current on-hand value'),
                  const SizedBox(height: 8),
                  ...(() {
                    final sorted = [...items]
                      ..sort((a, b) =>
                          b.stockValue.compareTo(a.stockValue));
                    return sorted.take(5).map((item) => Padding(
                          padding:
                              const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Expanded(
                                  child: Text(item.name,
                                      style: const TextStyle(
                                          fontSize: 13))),
                              Text(
                                '${item.quantity} ${item.unit}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                CurrencyFormatter.format(
                                    item.stockValue),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13),
                              ),
                            ],
                          ),
                        ));
                  })(),
                ],
              );
            },
            orElse: () => const Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool loading;
  final bool wide;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.loading,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        color: color.withValues(alpha: 0.8))),
                loading
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child:
                            CircularProgressIndicator(strokeWidth: 2))
                    : Text(value,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: wide ? 16 : 14,
                            color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 14)),
          Text(subtitle,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
        ],
      );
}
