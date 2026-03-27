import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/table_model.dart';
import 'repository_providers.dart';

class TablesNotifier extends StateNotifier<AsyncValue<List<TableModel>>> {
  TablesNotifier(this._ref) : super(const AsyncValue.loading()) {
    load();
  }

  final Ref _ref;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final data = await _ref.read(tableRepositoryProvider).getAll();
      state = AsyncValue.data(data);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  Future<void> add(TableModel table) async {
    await _ref.read(tableRepositoryProvider).insert(table);
    await load();
  }

  Future<void> edit(TableModel table) async {
    await _ref.read(tableRepositoryProvider).update(table);
    await load();
  }

  Future<void> remove(int id) async {
    await _ref.read(tableRepositoryProvider).delete(id);
    await load();
  }

  Future<void> updateStatus(int id, String status) async {
    await _ref.read(tableRepositoryProvider).updateStatus(id, status);
    await load();
  }
}

final tablesProvider =
    StateNotifierProvider<TablesNotifier, AsyncValue<List<TableModel>>>(
        (ref) => TablesNotifier(ref));
