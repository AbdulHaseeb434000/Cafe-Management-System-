import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/customer_model.dart';
import '../../models/menu_item_model.dart';
import '../../models/order_model.dart';
import '../../models/order_item_model.dart';
import '../../providers/menu_providers.dart';
import '../../providers/order_providers.dart';
import '../../providers/table_providers.dart';
import '../../providers/repository_providers.dart';
import '../../providers/settings_providers.dart';

class NewOrderScreen extends ConsumerStatefulWidget {
  final int? preselectedTableId;
  final String? preselectedTableUuid;
  final String? preselectedTableName;

  const NewOrderScreen({
    super.key,
    this.preselectedTableId,
    this.preselectedTableUuid,
    this.preselectedTableName,
  });

  @override
  ConsumerState<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends ConsumerState<NewOrderScreen> {
  // 0=type, 1=table(dine-in)/customer(others), 2=optional-customer(dine-in), 3=menu
  int _step = 0;

  @override
  void initState() {
    super.initState();
    // Reset cart on open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(cartProvider.notifier).clear();
      if (widget.preselectedTableId != null) {
        ref.read(cartProvider.notifier)
          ..setOrderType(AppConstants.orderTypeDineIn)
          ..setTable(
            widget.preselectedTableId!,
            widget.preselectedTableUuid!,
            widget.preselectedTableName!,
          );
        setState(() => _step = 2); // skip to optional customer step for dine-in
      }
    });
  }

  void _goBack() {
    if (widget.preselectedTableId != null) {
      context.pop();
      return;
    }
    final orderType = ref.read(cartProvider).orderType;
    // When going back from menu (step 3) for non-dine-in, skip step 2
    if (_step == 3 && orderType != AppConstants.orderTypeDineIn) {
      setState(() => _step = 1);
    } else if (_step > 0) {
      setState(() => _step--);
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Order'),
        leading: BackButton(onPressed: _goBack),
      ),
      body: IndexedStack(
        index: _step,
        children: [
          // Step 0: order type
          _TypeSelectionStep(onSelected: (type) {
            ref.read(cartProvider.notifier).setOrderType(type);
            setState(() => _step = 1); // all types go to step 1
          }),
          // Step 1: table selection (dine-in) OR customer form (takeaway/delivery)
          if (cart.orderType == AppConstants.orderTypeDineIn)
            _TableSelectionStep(onSelected: () => setState(() => _step = 2))
          else
            _CustomerFormStep(onContinue: () => setState(() => _step = 3)),
          // Step 2: optional customer info for dine-in (after table selection)
          _DineInCustomerStep(onContinue: () => setState(() => _step = 3)),
          // Step 3: menu
          _MenuStep(onPlaceOrder: _placeOrder),
        ],
      ),
    );
  }

  Future<void> _placeOrder() async {
    final cart = ref.read(cartProvider);
    if (cart.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one item')),
      );
      return;
    }

    final settings = ref.read(settingsNotifierProvider).valueOrNull ?? {};
    final taxPercent = double.tryParse(
            settings[AppConstants.settingTaxPercent] ?? '0') ??
        0;

    final subtotal = cart.subtotal;
    final taxAmount = subtotal * taxPercent / 100;
    final total = subtotal + taxAmount;

    // Insert order
    var order = OrderModel.create(type: cart.orderType);
    order = order.copyWith(
      tableId: cart.tableId,
      tableUuid: cart.tableUuid,
      customerId: cart.customerId,
      customerUuid: cart.customerUuid,
      deliveryAddress: cart.deliveryAddress,
      note: cart.orderNote,
      taxPercent: taxPercent,
      subtotal: subtotal,
      taxAmount: taxAmount,
      total: total,
      status: AppConstants.orderStatusPending,
    );

    final repo = ref.read(orderRepositoryProvider);
    final saved = await repo.insert(order);

    // Insert order items
    for (final cartItem in cart.items) {
      final item = OrderItemModel.create(
        orderId: saved.id!,
        orderUuid: saved.uuid,
        menuItemId: cartItem.menuItem.id!,
        menuItemUuid: cartItem.menuItem.uuid,
        nameSnapshot: cartItem.menuItem.name,
        priceSnapshot: cartItem.menuItem.price,
        quantity: cartItem.quantity,
        note: cartItem.note,
      );
      await repo.insertItem(item);
    }

    // Mark table as occupied
    if (cart.tableId != null) {
      await ref.read(tableRepositoryProvider).setOccupied(cart.tableId!);
      ref.read(tablesProvider.notifier).load();
    }

    ref.read(activeOrdersProvider.notifier).load();
    ref.read(cartProvider.notifier).clear();

    if (context.mounted) {
      context.pop();
      context.push('/orders/${saved.id}');
    }
  }
}

// ── Step 1: Order Type ────────────────────────────────────────────────────────

class _TypeSelectionStep extends StatelessWidget {
  final void Function(String type) onSelected;
  const _TypeSelectionStep({required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth >= 600;
        final padding = isTablet ? 24.0 : 16.0;

        final dineInCard = _TypeCard(
          icon: Icons.table_restaurant,
          label: 'Dine-In',
          subtitle: 'Customer sits at a table',
          color: AppColors.dineIn,
          onTap: () => onSelected(AppConstants.orderTypeDineIn),
        );
        final takeawayCard = _TypeCard(
          icon: Icons.shopping_bag_outlined,
          label: 'Takeaway',
          subtitle: 'Customer picks up at counter',
          color: AppColors.takeaway,
          onTap: () => onSelected(AppConstants.orderTypeTakeaway),
        );
        final deliveryCard = _TypeCard(
          icon: Icons.delivery_dining,
          label: 'Delivery',
          subtitle: 'Deliver to customer\'s address',
          color: AppColors.delivery,
          onTap: () => onSelected(AppConstants.orderTypeDelivery),
        );

        return Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Select Order Type',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text('How will the customer be served?',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 32),
              if (isTablet)
                Row(
                  children: [
                    Expanded(child: dineInCard),
                    const SizedBox(width: 16),
                    Expanded(child: takeawayCard),
                    const SizedBox(width: 16),
                    Expanded(child: deliveryCard),
                  ],
                )
              else ...[
                dineInCard,
                const SizedBox(height: 16),
                takeawayCard,
                const SizedBox(height: 16),
                deliveryCard,
              ],
            ],
          ),
        );
      },
    );
  }
}

class _TypeCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _TypeCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color),
          ],
        ),
      ),
    );
  }
}

// ── Step 1b: Table Selection ──────────────────────────────────────────────────

class _TableSelectionStep extends ConsumerWidget {
  final VoidCallback onSelected;
  const _TableSelectionStep({required this.onSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tablesAsync = ref.watch(tablesProvider);
    return tablesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (tables) {
        final freeTables =
            tables.where((t) => t.isFree || t.isReserved).toList();
        if (freeTables.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.table_restaurant_outlined,
                      size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text('No free tables available',
                      style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Go to Tables'),
                    onPressed: () => context.go('/tables'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: onSelected,
                    child: const Text('Continue without table'),
                  ),
                ],
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Text('Select a Table',
                  style: Theme.of(context).textTheme.headlineSmall),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth >= 600 ? 4 : 2;
                  return GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.2,
                    ),
                    itemCount: freeTables.length,
                    itemBuilder: (_, i) {
                      final t = freeTables[i];
                      return InkWell(
                        onTap: () {
                          ref
                              .read(cartProvider.notifier)
                              .setTable(t.id!, t.uuid, t.name);
                          onSelected();
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.table_restaurant,
                                  size: 32, color: AppColors.primary),
                              const SizedBox(height: 8),
                              Text(t.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700)),
                              Text('${t.capacity} seats',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Step 2: Optional Customer Info for Dine-In ───────────────────────────────

class _DineInCustomerStep extends ConsumerStatefulWidget {
  final VoidCallback onContinue;
  const _DineInCustomerStep({required this.onContinue});

  @override
  ConsumerState<_DineInCustomerStep> createState() => _DineInCustomerStepState();
}

class _DineInCustomerStepState extends ConsumerState<_DineInCustomerStep> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Customer Info',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Optional — identify the customer for this table',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Name',
              prefixIcon: Icon(Icons.person_outline),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _phoneCtrl,
            decoration: const InputDecoration(
              labelText: 'Phone',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                final name = _nameCtrl.text.trim();
                final phone = _phoneCtrl.text.trim();
                if (name.isNotEmpty) {
                  final custRepo = ref.read(customerRepositoryProvider);
                  CustomerModel? existing;
                  if (phone.isNotEmpty) {
                    existing = await custRepo.getByPhone(phone);
                  }
                  final customer = existing ??
                      await custRepo.insert(CustomerModel.create(
                        name: name,
                        phone: phone.isEmpty ? null : phone,
                      ));
                  ref.read(cartProvider.notifier).setCustomer(
                        id: customer.id,
                        uuid: customer.uuid,
                        name: customer.name,
                      );
                }
                widget.onContinue();
              },
              child: const Text('Continue to Menu'),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: widget.onContinue,
              child: const Text('Skip — No Customer Info'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step 1c: Customer Form (Takeaway optional / Delivery required) ────────────

class _CustomerFormStep extends ConsumerStatefulWidget {
  final VoidCallback onContinue;
  const _CustomerFormStep({required this.onContinue});

  @override
  ConsumerState<_CustomerFormStep> createState() => _CustomerFormStepState();
}

class _CustomerFormStepState extends ConsumerState<_CustomerFormStep> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final isDelivery = cart.orderType == AppConstants.orderTypeDelivery;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Customer Info',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            isDelivery
                ? 'Required for delivery'
                : 'Optional — skip if not needed',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: isDelivery ? 'Name *' : 'Name',
              prefixIcon: const Icon(Icons.person_outline),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _phoneCtrl,
            decoration: InputDecoration(
              labelText: isDelivery ? 'Phone *' : 'Phone',
              prefixIcon: const Icon(Icons.phone_outlined),
            ),
            keyboardType: TextInputType.phone,
          ),
          if (isDelivery) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _addressCtrl,
              decoration: const InputDecoration(
                labelText: 'Delivery Address *',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              maxLines: 2,
            ),
          ],
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                final name = _nameCtrl.text.trim();
                final phone = _phoneCtrl.text.trim();
                final address = _addressCtrl.text.trim();

                if (isDelivery &&
                    (name.isEmpty ||
                        phone.isEmpty ||
                        address.isEmpty)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Please fill all required fields')),
                  );
                  return;
                }

                if (name.isNotEmpty) {
                  // Save or find customer
                  final custRepo =
                      ref.read(customerRepositoryProvider);
                  CustomerModel? existing;
                  if (phone.isNotEmpty) {
                    existing = await custRepo.getByPhone(phone);
                  }
                  final customer = existing ??
                      await custRepo.insert(CustomerModel.create(
                        name: name,
                        phone: phone.isEmpty ? null : phone,
                        address: address.isEmpty ? null : address,
                      ));
                  ref.read(cartProvider.notifier).setCustomer(
                        id: customer.id,
                        uuid: customer.uuid,
                        name: customer.name,
                        deliveryAddress:
                            address.isEmpty ? null : address,
                      );
                }
                widget.onContinue();
              },
              child: const Text('Continue to Menu'),
            ),
          ),
          if (!isDelivery)
            Center(
              child: TextButton(
                onPressed: widget.onContinue,
                child: const Text('Skip — No Customer Info'),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Step 2: Menu Browser + Cart ───────────────────────────────────────────────

class _MenuStep extends ConsumerStatefulWidget {
  final Future<void> Function() onPlaceOrder;
  const _MenuStep({required this.onPlaceOrder});

  @override
  ConsumerState<_MenuStep> createState() => _MenuStepState();
}

class _MenuStepState extends ConsumerState<_MenuStep> {
  int? _selectedCategoryId;
  String _search = '';
  bool _placing = false;

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final itemsAsync = ref.watch(menuItemsProvider);
    final cart = ref.watch(cartProvider);

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search menu...',
              prefixIcon: Icon(Icons.search, size: 20),
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onChanged: (v) => setState(() => _search = v.toLowerCase()),
          ),
        ),
        // Category chips
        categoriesAsync.when(
          loading: () => const SizedBox(),
          error: (_, __) => const SizedBox(),
          data: (cats) => SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: cats.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                if (i == 0) {
                  return _chip('All', _selectedCategoryId == null,
                      () => setState(() => _selectedCategoryId = null));
                }
                final cat = cats[i - 1];
                return _chip(
                  cat.name,
                  _selectedCategoryId == cat.id,
                  () => setState(() => _selectedCategoryId = cat.id),
                );
              },
            ),
          ),
        ),
        const Divider(height: 1),
        // Items grid
        Expanded(
          child: itemsAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (allItems) {
              var items = allItems.where((it) => it.isAvailable).toList();
              if (_selectedCategoryId != null) {
                items = items
                    .where((it) => it.categoryId == _selectedCategoryId)
                    .toList();
              }
              if (_search.isNotEmpty) {
                items = items
                    .where((it) =>
                        it.name.toLowerCase().contains(_search))
                    .toList();
              }
              if (items.isEmpty) {
                return const Center(child: Text('No items found'));
              }
              return LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth >= 600 ? 4 : 2;
                  return GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.35,
                    ),
                    itemCount: items.length,
                    itemBuilder: (_, i) =>
                        _MenuItemCard(item: items[i], cart: cart),
                  );
                },
              );
            },
          ),
        ),
        // Cart summary bar
        if (cart.items.isNotEmpty)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: const Border(
                  top: BorderSide(color: AppColors.divider)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, -2))
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${cart.totalItems}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${cart.items.length} item${cart.items.length == 1 ? '' : 's'}',
                          style:
                              Theme.of(context).textTheme.labelMedium,
                        ),
                        Text(
                          CurrencyFormatter.format(cart.subtotal),
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryDark),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _placing
                        ? null
                        : () async {
                            setState(() => _placing = true);
                            await widget.onPlaceOrder();
                            if (mounted) {
                              setState(() => _placing = false);
                            }
                          },
                    icon: _placing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white))
                        : const Icon(Icons.send, size: 18),
                    label: const Text('Place Order'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: selected ? AppColors.primary : AppColors.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: selected ? Colors.white : AppColors.textPrimary,
              fontWeight:
                  selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      );
}

class _MenuItemCard extends ConsumerWidget {
  final MenuItemModel item;
  final CartState cart;
  const _MenuItemCard({required this.item, required this.cart});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qty = cart.items
        .where((e) => e.menuItem.id == item.id)
        .fold(0, (s, e) => s + e.quantity);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color:
                qty > 0 ? AppColors.primary : AppColors.border,
            width: qty > 0 ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.description != null)
                    Text(
                      item.description!,
                      style: Theme.of(context).textTheme.labelSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 8, 8),
            child: Row(
              children: [
                Text(
                  CurrencyFormatter.formatCompact(item.price),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                if (qty == 0)
                  GestureDetector(
                    onTap: () =>
                        ref.read(cartProvider.notifier).addItem(item),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.add,
                          size: 18, color: Colors.white),
                    ),
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () => ref
                            .read(cartProvider.notifier)
                            .removeItem(item.id!),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.remove, size: 14),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _showQtyDialog(context, ref, item, qty),
                        child: Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 6),
                          child: Text('$qty',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  decoration: TextDecoration.underline)),
                        ),
                      ),
                      GestureDetector(
                        onTap: () =>
                            ref.read(cartProvider.notifier).addItem(item),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.add,
                              size: 14, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showQtyDialog(
      BuildContext context, WidgetRef ref, MenuItemModel item, int currentQty) {
    final ctrl = TextEditingController(text: '$currentQty');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item.name),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Quantity'),
          onSubmitted: (_) {
            final v = int.tryParse(ctrl.text.trim());
            if (v != null && v > 0) {
              ref.read(cartProvider.notifier).setQuantity(item.id!, v);
            }
            Navigator.pop(ctx);
          },
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final v = int.tryParse(ctrl.text.trim());
              if (v != null && v > 0) {
                ref.read(cartProvider.notifier).setQuantity(item.id!, v);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
  }
}
