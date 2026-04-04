import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/order_model.dart';
import '../../models/order_item_model.dart';
import '../../models/menu_item_model.dart';
import '../../providers/order_providers.dart';
import '../../providers/menu_providers.dart';
import '../../providers/repository_providers.dart';
import '../../providers/settings_providers.dart';

class EditOrderScreen extends ConsumerStatefulWidget {
  final OrderModel order;
  const EditOrderScreen({super.key, required this.order});

  @override
  ConsumerState<EditOrderScreen> createState() => _EditOrderScreenState();
}

class _EditOrderScreenState extends ConsumerState<EditOrderScreen> {
  late List<OrderItemModel> _items;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.order.items);
  }

  double get _subtotal =>
      _items.fold(0, (s, i) => s + i.lineTotal);

  double get _taxAmount {
    final settings = ref.read(settingsNotifierProvider).valueOrNull ?? {};
    final taxPct = double.tryParse(
            settings[AppConstants.settingTaxPercent] ?? '0') ??
        widget.order.taxPercent;
    return _subtotal * taxPct / 100;
  }

  double get _total => _subtotal + _taxAmount - widget.order.discountAmount;

  void _increment(int index) {
    setState(() {
      _items[index] =
          _items[index].copyWith(quantity: _items[index].quantity + 1);
    });
  }

  void _decrement(int index) {
    if (_items[index].quantity <= 1) {
      _removeItem(index);
    } else {
      setState(() {
        _items[index] =
            _items[index].copyWith(quantity: _items[index].quantity - 1);
      });
    }
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index));
  }

  void _addMenuItem(MenuItemModel menuItem) {
    final existing = _items.indexWhere(
        (i) => i.menuItemId == menuItem.id);
    if (existing >= 0) {
      setState(() {
        _items[existing] = _items[existing]
            .copyWith(quantity: _items[existing].quantity + 1);
      });
    } else {
      setState(() {
        _items.add(OrderItemModel.create(
          orderId: widget.order.id!,
          orderUuid: widget.order.uuid,
          menuItemId: menuItem.id!,
          menuItemUuid: menuItem.uuid,
          nameSnapshot: menuItem.name,
          priceSnapshot: menuItem.price,
          quantity: 1,
        ));
      });
    }
  }

  Future<void> _save() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order must have at least one item')),
      );
      return;
    }
    setState(() => _saving = true);

    final repo = ref.read(orderRepositoryProvider);

    // Delete all existing items and re-insert
    await repo.deleteAllItems(widget.order.id!);
    for (final item in _items) {
      if (item.id != null) {
        // existing item — re-insert with same uuid to preserve history
        await repo.insertItem(item.copyWith(id: null));
      } else {
        await repo.insertItem(item);
      }
    }

    // Recalculate and save totals
    final settings = ref.read(settingsNotifierProvider).valueOrNull ?? {};
    final taxPct = double.tryParse(
            settings[AppConstants.settingTaxPercent] ?? '0') ??
        widget.order.taxPercent;
    final subtotal = _subtotal;
    final taxAmount = subtotal * taxPct / 100;
    final total = subtotal + taxAmount - widget.order.discountAmount;

    await repo.updateTotals(widget.order.copyWith(
      subtotal: subtotal,
      taxAmount: taxAmount,
      total: total.clamp(0, double.infinity),
    ));

    // Flag the kitchen card for reprint if the order is already in-progress.
    // Kitchen staff will see an "Updated" badge until they reprint the ticket.
    if (widget.order.isPreparing || widget.order.isReady) {
      await repo.setNeedsReprint(widget.order.id!, value: true);
    }

    ref.read(activeOrdersProvider.notifier).load();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit ${widget.order.displayId}'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save',
                    style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Current items
          Expanded(
            child: _items.isEmpty
                ? const Center(
                    child: Text('No items — add from menu below',
                        style: TextStyle(color: AppColors.textSecondary)),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) => _ItemRow(
                      item: _items[i],
                      onIncrement: () => _increment(i),
                      onDecrement: () => _decrement(i),
                      onRemove: () => _removeItem(i),
                    ),
                  ),
          ),
          // Total bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppColors.surfaceVariant,
            child: Row(
              children: [
                Text('${_items.length} item${_items.length != 1 ? 's' : ''}',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
                const Spacer(),
                if (widget.order.discountAmount > 0)
                  Text(
                    'Discount: -${CurrencyFormatter.format(widget.order.discountAmount)}  ',
                    style: const TextStyle(
                        color: AppColors.success, fontSize: 12),
                  ),
                Text('Total: ${CurrencyFormatter.format(_total)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
              ],
            ),
          ),
          // Add from menu
          _MenuPicker(onAdd: _addMenuItem),
        ],
      ),
    );
  }
}

// ── Item row ──────────────────────────────────────────────────────────────────

class _ItemRow extends StatelessWidget {
  final OrderItemModel item;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;

  const _ItemRow({
    required this.item,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.nameSnapshot,
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 14)),
                Text(CurrencyFormatter.format(item.priceSnapshot),
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          // Quantity controls
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                color: AppColors.primary,
                iconSize: 22,
                padding: EdgeInsets.zero,
                onPressed: onDecrement,
              ),
              SizedBox(
                width: 32,
                child: Text('${item.quantity}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                color: AppColors.primary,
                iconSize: 22,
                padding: EdgeInsets.zero,
                onPressed: onIncrement,
              ),
              const SizedBox(width: 4),
              Text(CurrencyFormatter.format(item.lineTotal),
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                color: AppColors.error,
                padding: const EdgeInsets.only(left: 4),
                onPressed: onRemove,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Menu picker (compact) ─────────────────────────────────────────────────────

class _MenuPicker extends ConsumerStatefulWidget {
  final void Function(MenuItemModel) onAdd;
  const _MenuPicker({required this.onAdd});

  @override
  ConsumerState<_MenuPicker> createState() => _MenuPickerState();
}

class _MenuPickerState extends ConsumerState<_MenuPicker> {
  String _search = '';
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(menuItemsProvider);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: _expanded ? 280 : 56,
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, -2))
        ],
      ),
      child: Column(
        children: [
          // Toggle bar
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.add, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  const Text('Add Items from Menu',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary)),
                  const Spacer(),
                  Icon(
                      _expanded
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_up,
                      color: AppColors.primary),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Search items...',
                  prefixIcon: Icon(Icons.search, size: 18),
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onChanged: (v) => setState(() => _search = v.toLowerCase()),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: itemsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, __) => const SizedBox(),
                data: (items) {
                  final filtered = items
                      .where((i) =>
                          i.isAvailable &&
                          (_search.isEmpty ||
                              i.name.toLowerCase().contains(_search)))
                      .toList();
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final item = filtered[i];
                      return ListTile(
                        dense: true,
                        title: Text(item.name,
                            style: const TextStyle(fontSize: 13)),
                        trailing: Text(CurrencyFormatter.format(item.price),
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary)),
                        onTap: () => widget.onAdd(item),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
