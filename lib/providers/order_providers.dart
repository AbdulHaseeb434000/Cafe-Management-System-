import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/order_model.dart';
import '../models/menu_item_model.dart';
import '../core/constants/app_constants.dart';
import 'repository_providers.dart';

// ── Active orders ─────────────────────────────────────────────────────────────

class ActiveOrdersNotifier
    extends StateNotifier<AsyncValue<List<OrderModel>>> {
  ActiveOrdersNotifier(this._ref) : super(const AsyncValue.loading()) {
    load();
  }

  final Ref _ref;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final data = await _ref.read(orderRepositoryProvider).getActive();
      state = AsyncValue.data(data);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  Future<void> updateStatus(int id, String status) async {
    await _ref.read(orderRepositoryProvider).updateStatus(id, status);
    await load();
  }

  Future<void> cancel(int id) async {
    await _ref.read(orderRepositoryProvider).cancel(id);
    await load();
  }
}

final activeOrdersProvider = StateNotifierProvider<ActiveOrdersNotifier,
    AsyncValue<List<OrderModel>>>((ref) => ActiveOrdersNotifier(ref));

// ── Cart (in-progress new order) ─────────────────────────────────────────────

class CartItem {
  final MenuItemModel menuItem;
  final int quantity;
  final String? note;

  const CartItem({
    required this.menuItem,
    required this.quantity,
    this.note,
  });

  CartItem copyWith({int? quantity, String? note}) => CartItem(
        menuItem: menuItem,
        quantity: quantity ?? this.quantity,
        note: note ?? this.note,
      );

  double get lineTotal => menuItem.price * quantity;
}

class CartState {
  final String orderType;
  final int? tableId;
  final String? tableUuid;
  final String? tableName;
  final int? customerId;
  final String? customerUuid;
  final String? customerName;
  final String? deliveryAddress;
  final String? orderNote;
  final List<CartItem> items;

  const CartState({
    this.orderType = AppConstants.orderTypeDineIn,
    this.tableId,
    this.tableUuid,
    this.tableName,
    this.customerId,
    this.customerUuid,
    this.customerName,
    this.deliveryAddress,
    this.orderNote,
    this.items = const [],
  });

  double get subtotal =>
      items.fold(0, (sum, item) => sum + item.lineTotal);

  int get totalItems =>
      items.fold(0, (sum, item) => sum + item.quantity);

  CartState copyWith({
    String? orderType,
    int? tableId,
    String? tableUuid,
    String? tableName,
    int? customerId,
    String? customerUuid,
    String? customerName,
    String? deliveryAddress,
    String? orderNote,
    List<CartItem>? items,
  }) =>
      CartState(
        orderType: orderType ?? this.orderType,
        tableId: tableId ?? this.tableId,
        tableUuid: tableUuid ?? this.tableUuid,
        tableName: tableName ?? this.tableName,
        customerId: customerId ?? this.customerId,
        customerUuid: customerUuid ?? this.customerUuid,
        customerName: customerName ?? this.customerName,
        deliveryAddress: deliveryAddress ?? this.deliveryAddress,
        orderNote: orderNote ?? this.orderNote,
        items: items ?? this.items,
      );
}

class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(const CartState());

  void setOrderType(String type) => state = CartState(orderType: type);

  void setTable(int id, String uuid, String name) => state = state.copyWith(
        tableId: id,
        tableUuid: uuid,
        tableName: name,
      );

  void setCustomer({
    int? id,
    String? uuid,
    String? name,
    String? deliveryAddress,
  }) =>
      state = state.copyWith(
        customerId: id,
        customerUuid: uuid,
        customerName: name,
        deliveryAddress: deliveryAddress,
      );

  void setOrderNote(String note) => state = state.copyWith(orderNote: note);

  void addItem(MenuItemModel menuItem) {
    final items = List<CartItem>.from(state.items);
    final idx = items.indexWhere((e) => e.menuItem.id == menuItem.id);
    if (idx >= 0) {
      items[idx] = items[idx].copyWith(quantity: items[idx].quantity + 1);
    } else {
      items.add(CartItem(menuItem: menuItem, quantity: 1));
    }
    state = state.copyWith(items: items);
  }

  void removeItem(int menuItemId) {
    final items = List<CartItem>.from(state.items);
    final idx = items.indexWhere((e) => e.menuItem.id == menuItemId);
    if (idx < 0) return;
    if (items[idx].quantity > 1) {
      items[idx] = items[idx].copyWith(quantity: items[idx].quantity - 1);
    } else {
      items.removeAt(idx);
    }
    state = state.copyWith(items: items);
  }

  void setQuantity(int menuItemId, int quantity) {
    if (quantity <= 0) return;
    final items = List<CartItem>.from(state.items);
    final idx = items.indexWhere((e) => e.menuItem.id == menuItemId);
    if (idx >= 0) items[idx] = items[idx].copyWith(quantity: quantity);
    state = state.copyWith(items: items);
  }

  void setItemNote(int menuItemId, String note) {
    final items = List<CartItem>.from(state.items);
    final idx = items.indexWhere((e) => e.menuItem.id == menuItemId);
    if (idx >= 0) items[idx] = items[idx].copyWith(note: note);
    state = state.copyWith(items: items);
  }

  void clear() => state = const CartState();
}

final cartProvider =
    StateNotifierProvider<CartNotifier, CartState>((ref) => CartNotifier());

// ── Order detail ─────────────────────────────────────────────────────────────

final orderDetailProvider =
    FutureProvider.family<OrderModel?, int>((ref, orderId) async {
  return ref.read(orderRepositoryProvider).getById(orderId);
});
