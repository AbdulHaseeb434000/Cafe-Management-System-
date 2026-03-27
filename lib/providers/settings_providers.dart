import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'repository_providers.dart';

final settingsProvider = FutureProvider<Map<String, String>>((ref) async {
  return ref.read(settingsRepositoryProvider).getAll();
});

class SettingsNotifier extends StateNotifier<AsyncValue<Map<String, String>>> {
  SettingsNotifier(this._ref) : super(const AsyncValue.loading()) {
    load();
  }

  final Ref _ref;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final data = await _ref.read(settingsRepositoryProvider).getAll();
      state = AsyncValue.data(data);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  Future<void> set(String key, String value) async {
    await _ref.read(settingsRepositoryProvider).set(key, value);
    await load();
  }

  Future<void> setAll(Map<String, String> values) async {
    final repo = _ref.read(settingsRepositoryProvider);
    for (final entry in values.entries) {
      await repo.set(entry.key, entry.value);
    }
    await load();
  }

  String? get(String key) {
    return state.valueOrNull?[key];
  }
}

final settingsNotifierProvider =
    StateNotifierProvider<SettingsNotifier, AsyncValue<Map<String, String>>>(
        (ref) => SettingsNotifier(ref));
