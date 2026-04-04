import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/category_model.dart';
import '../../models/menu_item_model.dart';
import '../../providers/menu_providers.dart';
import '../../providers/settings_providers.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/confirm_dialog.dart';

class MenuScreen extends ConsumerStatefulWidget {
  const MenuScreen({super.key});

  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen>
    with SingleTickerProviderStateMixin {
  int? _selectedCategoryId;

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final itemsAsync = ref.watch(menuItemsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Add Category',
            onPressed: () => _showCategoryDialog(context),
          ),
        ],
      ),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (categories) {
          if (categories.isEmpty) {
            return EmptyState(
              icon: Icons.restaurant_menu_outlined,
              title: 'No menu yet',
              subtitle: 'Add a category to get started',
              action: ElevatedButton.icon(
                onPressed: () => _showCategoryDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('Add Category'),
              ),
            );
          }

          final selected = _selectedCategoryId ??
              (categories.isNotEmpty ? categories.first.id : null);

          return Column(
            children: [
              // Category chips
              SizedBox(
                height: 56,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  itemCount: categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final cat = categories[i];
                    final isSelected = selected == cat.id;
                    return GestureDetector(
                      onTap: () =>
                          setState(() => _selectedCategoryId = cat.id),
                      onLongPress: () =>
                          _showCategoryOptions(context, cat),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 0),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.border,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            cat.name,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textPrimary,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              // Items list
              Expanded(
                child: itemsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (allItems) {
                    final items = allItems
                        .where((i) => i.categoryId == selected)
                        .toList();
                    if (items.isEmpty) {
                      return EmptyState(
                        icon: Icons.fastfood_outlined,
                        title: 'No items in this category',
                        subtitle: 'Tap + to add a menu item',
                      );
                    }
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth >= 600) {
                          return GridView.builder(
                            padding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 8),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 0,
                              mainAxisSpacing: 0,
                              childAspectRatio: 4,
                            ),
                            itemCount: items.length,
                            itemBuilder: (_, i) =>
                                _ItemTile(item: items[i]),
                          );
                        }
                        return ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, indent: 16),
                          itemBuilder: (_, i) =>
                              _ItemTile(item: items[i]),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final cats =
              ref.read(categoriesProvider).valueOrNull ?? [];
          if (cats.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Add a category first')),
            );
            return;
          }
          final catId = _selectedCategoryId ?? cats.first.id!;
          final cat = cats.firstWhere(
            (c) => c.id == catId,
            orElse: () => cats.first,
          );
          _showItemDialog(context, category: cat);
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showCategoryDialog(BuildContext context,
      {CategoryModel? existing}) {
    final controller =
        TextEditingController(text: existing?.name ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add Category' : 'Edit Category'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
              labelText: 'Category name'),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              if (existing == null) {
                ref.read(categoriesProvider.notifier).add(
                      CategoryModel.create(
                        name: name,
                        sortOrder: ref
                                .read(categoriesProvider)
                                .valueOrNull
                                ?.length ??
                            0,
                      ),
                    );
              } else {
                ref.read(categoriesProvider.notifier).edit(
                      existing.copyWith(name: name),
                    );
              }
              setState(() => _selectedCategoryId = null);
              Navigator.pop(ctx);
            },
            child: Text(existing == null ? 'Add' : 'Save'),
          ),
        ],
      ),
    );
  }

  void _showCategoryOptions(BuildContext context, CategoryModel cat) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit Category'),
              onTap: () {
                Navigator.pop(ctx);
                _showCategoryDialog(context, existing: cat);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: AppColors.error),
              title: const Text('Delete Category',
                  style: TextStyle(color: AppColors.error)),
              onTap: () async {
                Navigator.pop(ctx);
                final confirmed = await showConfirmDialog(
                  context,
                  title: 'Delete Category',
                  message:
                      'Delete "${cat.name}" and all its items?',
                  confirmLabel: 'Delete',
                  destructive: true,
                );
                if (confirmed) {
                  ref
                      .read(categoriesProvider.notifier)
                      .remove(cat.id!);
                  ref.read(menuItemsProvider.notifier).load();
                  setState(() => _selectedCategoryId = null);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showItemDialog(BuildContext context,
      {MenuItemModel? existing, required CategoryModel category}) {
    final settings = ref.read(settingsNotifierProvider).valueOrNull ?? {};
    final currencySymbol = settings[AppConstants.settingCurrencySymbol] ??
        AppConstants.defaultCurrencySymbol;
    final nameCtrl =
        TextEditingController(text: existing?.name ?? '');
    final priceCtrl = TextEditingController(
        text: existing?.price.toStringAsFixed(2) ?? '');
    final descCtrl =
        TextEditingController(text: existing?.description ?? '');

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
                decoration: const InputDecoration(labelText: 'Item name *'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceCtrl,
                decoration: InputDecoration(
                  labelText: 'Price *',
                  prefixText: '$currencySymbol ',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                decoration:
                    const InputDecoration(labelText: 'Description (optional)'),
                maxLines: 2,
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
              final price =
                  double.tryParse(priceCtrl.text.trim()) ?? 0;
              if (name.isEmpty || price <= 0) return;
              if (existing == null) {
                ref.read(menuItemsProvider.notifier).add(
                      MenuItemModel.create(
                        categoryId: category.id!,
                        categoryUuid: category.uuid,
                        name: name,
                        price: price,
                        description: descCtrl.text.trim().isEmpty
                            ? null
                            : descCtrl.text.trim(),
                      ),
                    );
              } else {
                ref.read(menuItemsProvider.notifier).edit(
                      existing.copyWith(
                        name: name,
                        price: price,
                        description: descCtrl.text.trim().isEmpty
                            ? null
                            : descCtrl.text.trim(),
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
}

class _ItemTile extends ConsumerWidget {
  final MenuItemModel item;
  const _ItemTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsNotifierProvider).valueOrNull ?? {};
    final currencySymbol = settings[AppConstants.settingCurrencySymbol] ??
        AppConstants.defaultCurrencySymbol;
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(
        item.name,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: item.isAvailable
              ? AppColors.textPrimary
              : AppColors.textDisabled,
          decoration:
              item.isAvailable ? null : TextDecoration.lineThrough,
        ),
      ),
      subtitle: item.description != null
          ? Text(item.description!,
              maxLines: 1, overflow: TextOverflow.ellipsis)
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            CurrencyFormatter.format(item.price, symbol: currencySymbol),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(width: 8),
          Switch.adaptive(
            value: item.isAvailable,
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withValues(alpha: 0.5),
            onChanged: (v) => ref
                .read(menuItemsProvider.notifier)
                .toggleAvailability(item.id!, v),
          ),
        ],
      ),
      onTap: () {
        final cats =
            ref.read(categoriesProvider).valueOrNull ?? [];
        final cat = cats.firstWhere(
          (c) => c.id == item.categoryId,
          orElse: () => cats.first,
        );
        _showItemOptions(context, ref, item, cat);
      },
    );
  }

  void _showItemOptions(BuildContext context, WidgetRef ref,
      MenuItemModel item, CategoryModel category) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit Item'),
              onTap: () {
                Navigator.pop(ctx);
                (context
                        .findAncestorStateOfType<_MenuScreenState>())!
                    ._showItemDialog(context,
                        existing: item, category: category);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline,
                  color: AppColors.error),
              title: const Text('Delete Item',
                  style: TextStyle(color: AppColors.error)),
              onTap: () async {
                Navigator.pop(ctx);
                final confirmed = await showConfirmDialog(
                  context,
                  title: 'Delete Item',
                  message: 'Delete "${item.name}"?',
                  confirmLabel: 'Delete',
                  destructive: true,
                );
                if (confirmed) {
                  ref
                      .read(menuItemsProvider.notifier)
                      .remove(item.id!);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
