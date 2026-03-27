import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category_model.dart';
import '../models/menu_item_model.dart';
import 'repository_providers.dart';

// ── Categories ───────────────────────────────────────────────────────────────

class CategoriesNotifier
    extends StateNotifier<AsyncValue<List<CategoryModel>>> {
  CategoriesNotifier(this._ref) : super(const AsyncValue.loading()) {
    load();
  }

  final Ref _ref;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final data = await _ref.read(categoryRepositoryProvider).getAll();
      state = AsyncValue.data(data);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  Future<void> add(CategoryModel category) async {
    await _ref.read(categoryRepositoryProvider).insert(category);
    await load();
  }

  Future<void> edit(CategoryModel category) async {
    await _ref.read(categoryRepositoryProvider).update(category);
    await load();
  }

  Future<void> remove(int id) async {
    await _ref.read(categoryRepositoryProvider).delete(id);
    await load();
  }

  Future<void> reorder(List<CategoryModel> categories) async {
    await _ref.read(categoryRepositoryProvider).updateSortOrder(categories);
    await load();
  }
}

final categoriesProvider =
    StateNotifierProvider<CategoriesNotifier, AsyncValue<List<CategoryModel>>>(
        (ref) => CategoriesNotifier(ref));

// ── Menu items ───────────────────────────────────────────────────────────────

final selectedCategoryIdProvider = StateProvider<int?>((ref) => null);

class MenuItemsNotifier extends StateNotifier<AsyncValue<List<MenuItemModel>>> {
  MenuItemsNotifier(this._ref) : super(const AsyncValue.loading()) {
    load();
  }

  final Ref _ref;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final data = await _ref.read(menuItemRepositoryProvider).getAll();
      state = AsyncValue.data(data);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  Future<void> add(MenuItemModel item) async {
    await _ref.read(menuItemRepositoryProvider).insert(item);
    await load();
  }

  Future<void> edit(MenuItemModel item) async {
    await _ref.read(menuItemRepositoryProvider).update(item);
    await load();
  }

  Future<void> toggleAvailability(int id, bool isAvailable) async {
    await _ref
        .read(menuItemRepositoryProvider)
        .toggleAvailability(id, isAvailable);
    await load();
  }

  Future<void> remove(int id) async {
    await _ref.read(menuItemRepositoryProvider).delete(id);
    await load();
  }
}

final menuItemsProvider =
    StateNotifierProvider<MenuItemsNotifier, AsyncValue<List<MenuItemModel>>>(
        (ref) => MenuItemsNotifier(ref));
