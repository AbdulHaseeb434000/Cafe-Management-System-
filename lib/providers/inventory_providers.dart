import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/inventory_item_model.dart';
import 'repository_providers.dart';

class InventoryNotifier
    extends StateNotifier<AsyncValue<List<InventoryItemModel>>> {
  InventoryNotifier(this._ref) : super(const AsyncValue.loading()) {
    load();
  }

  final Ref _ref;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final data = await _ref.read(inventoryRepositoryProvider).getAll();
      state = AsyncValue.data(data);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  Future<void> add(InventoryItemModel item) async {
    await _ref.read(inventoryRepositoryProvider).insert(item);
    await load();
  }

  Future<void> edit(InventoryItemModel item) async {
    await _ref.read(inventoryRepositoryProvider).update(item);
    await load();
  }

  Future<void> remove(int id) async {
    await _ref.read(inventoryRepositoryProvider).delete(id);
    await load();
  }

  Future<InventoryItemModel?> adjust(
      InventoryItemModel item, double change, String? reason) async {
    final updated = await _ref
        .read(inventoryRepositoryProvider)
        .adjust(item, change, reason);
    await load();
    return updated;
  }

  Future<InventoryItemModel> purchase(
    InventoryItemModel item, {
    required double quantity,
    required double unitCost,
    String? note,
  }) async {
    final updated = await _ref.read(inventoryRepositoryProvider).purchase(
          item,
          quantity: quantity,
          unitCost: unitCost,
          note: note,
        );
    await load();
    return updated;
  }

  Future<InventoryItemModel> issue(
    InventoryItemModel item, {
    required double quantity,
    String? reason,
  }) async {
    final updated = await _ref.read(inventoryRepositoryProvider).issue(
          item,
          quantity: quantity,
          reason: reason,
        );
    await load();
    return updated;
  }
}

final inventoryProvider = StateNotifierProvider<InventoryNotifier,
    AsyncValue<List<InventoryItemModel>>>(
  (ref) => InventoryNotifier(ref),
);

final lowStockProvider = FutureProvider<List<InventoryItemModel>>((ref) async {
  return ref.read(inventoryRepositoryProvider).getLowStock();
});
