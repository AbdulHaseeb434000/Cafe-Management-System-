import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../models/table_model.dart';
import '../../providers/table_providers.dart';
import '../../providers/repository_providers.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/confirm_dialog.dart';

class TablesScreen extends ConsumerWidget {
  const TablesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tablesAsync = ref.watch(tablesProvider);
    final isTablet = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tables'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Add Table',
            onPressed: () => _showTableDialog(context, ref),
          ),
        ],
      ),
      body: tablesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (tables) {
          if (tables.isEmpty) {
            return EmptyState(
              icon: Icons.table_restaurant_outlined,
              title: 'No tables added',
              subtitle: 'Add tables to start managing dine-in orders',
              action: ElevatedButton.icon(
                onPressed: () => _showTableDialog(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Add Table'),
              ),
            );
          }

          return Column(
            children: [
              // Legend
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    _Legend(color: AppColors.tableFree, label: 'Free'),
                    const SizedBox(width: 16),
                    _Legend(color: AppColors.tableOccupied, label: 'Occupied'),
                    const SizedBox(width: 16),
                    _Legend(color: AppColors.tableReserved, label: 'Reserved'),
                  ],
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isTablet ? 4 : 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: tables.length,
                  itemBuilder: (_, i) => _TableCard(
                    table: tables[i],
                    onTap: () => _onTableTap(context, ref, tables[i]),
                    onLongPress: () =>
                        _showTableOptions(context, ref, tables[i]),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _onTableTap(
      BuildContext context, WidgetRef ref, TableModel table) async {
    if (table.isFree) {
      context.push('/orders/new', extra: {
        'tableId': table.id,
        'tableUuid': table.uuid,
        'tableName': table.name,
      });
    } else if (table.isOccupied) {
      final order = await ref
          .read(orderRepositoryProvider)
          .getActiveByTable(table.id!);
      if (order != null && context.mounted) {
        context.push('/orders/${order.id}');
      }
    } else {
      _showTableOptions(context, ref, table);
    }
  }

  void _showTableOptions(
      BuildContext context, WidgetRef ref, TableModel table) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(table.name,
                  style: Theme.of(ctx).textTheme.titleMedium),
            ),
            const Divider(height: 1),
            if (!table.isFree)
              ListTile(
                leading: const Icon(Icons.check_circle_outline,
                    color: AppColors.tableFree),
                title: const Text('Mark as Free'),
                onTap: () {
                  Navigator.pop(ctx);
                  ref.read(tablesProvider.notifier).updateStatus(
                      table.id!, AppConstants.tableStatusFree);
                },
              ),
            if (!table.isReserved && table.isFree)
              ListTile(
                leading: const Icon(Icons.event_seat_outlined,
                    color: AppColors.tableReserved),
                title: const Text('Mark as Reserved'),
                onTap: () {
                  Navigator.pop(ctx);
                  ref.read(tablesProvider.notifier).updateStatus(
                      table.id!, AppConstants.tableStatusReserved);
                },
              ),
            if (table.isFree || table.isReserved)
              ListTile(
                leading: const Icon(Icons.add_shopping_cart_outlined),
                title: const Text('New Order'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/orders/new', extra: {
                    'tableId': table.id,
                    'tableUuid': table.uuid,
                    'tableName': table.name,
                  });
                },
              ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit Table'),
              onTap: () {
                Navigator.pop(ctx);
                _showTableDialog(context, ref, existing: table);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.error),
              title: const Text('Delete Table',
                  style: TextStyle(color: AppColors.error)),
              onTap: () async {
                Navigator.pop(ctx);
                final ok = await showConfirmDialog(context,
                    title: 'Delete Table',
                    message: 'Delete "${table.name}"?',
                    confirmLabel: 'Delete',
                    destructive: true);
                if (ok) {
                  ref.read(tablesProvider.notifier).remove(table.id!);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showTableDialog(BuildContext context, WidgetRef ref,
      {TableModel? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final capCtrl = TextEditingController(
        text: existing?.capacity.toString() ?? '4');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add Table' : 'Edit Table'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                  labelText: 'Table name'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: capCtrl,
              decoration: const InputDecoration(labelText: 'Capacity'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              final cap = int.tryParse(capCtrl.text.trim()) ?? 4;
              if (existing == null) {
                ref.read(tablesProvider.notifier).add(
                      TableModel.create(name: name, capacity: cap),
                    );
              } else {
                ref.read(tablesProvider.notifier).edit(
                      existing.copyWith(name: name, capacity: cap),
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
}

class _TableCard extends StatelessWidget {
  final TableModel table;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _TableCard({
    required this.table,
    required this.onTap,
    required this.onLongPress,
  });

  Color get _statusColor => switch (table.status) {
        AppConstants.tableStatusOccupied => AppColors.tableOccupied,
        AppConstants.tableStatusReserved => AppColors.tableReserved,
        _ => AppColors.tableFree,
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _statusColor, width: 2),
          boxShadow: [
            BoxShadow(
              color: _statusColor.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _statusColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.table_restaurant,
                  color: _statusColor, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              table.name,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline,
                    size: 12, color: AppColors.textSecondary),
                const SizedBox(width: 3),
                Text(
                  '${table.capacity}',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
              width: 10,
              height: 10,
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: AppColors.textSecondary)),
        ],
      );
}
