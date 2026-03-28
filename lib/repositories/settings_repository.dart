import '../core/database/database_helper.dart';
import '../core/constants/app_constants.dart';

class SettingsRepository {
  final DatabaseHelper _db;
  SettingsRepository(this._db);

  static const _table = 'settings';

  Future<String?> get(String key) async {
    final rows = await _db.query(_table, where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> set(String key, String value) async {
    await _db.insert(_table, {'key': key, 'value': value});
  }

  Future<Map<String, String>> getAll() async {
    final rows = await _db.query(_table);
    return {for (final r in rows) r['key'] as String: r['value'] as String};
  }

  Future<String> getCafeName() async =>
      (await get(AppConstants.settingCafeName)) ?? 'My Cafe';

  Future<String> getCafeAddress() async =>
      (await get(AppConstants.settingCafeAddress)) ?? '';

  Future<String> getCafePhone() async =>
      (await get(AppConstants.settingCafePhone)) ?? '';

  Future<double> getTaxPercent() async =>
      double.tryParse((await get(AppConstants.settingTaxPercent)) ?? '0') ?? 0;

  Future<String> getReceiptHeader() async =>
      (await get(AppConstants.settingReceiptHeader)) ?? '';

  Future<String> getReceiptFooter() async =>
      (await get(AppConstants.settingReceiptFooter)) ?? '';

  Future<String> getCurrencySymbol() async =>
      (await get(AppConstants.settingCurrencySymbol)) ?? AppConstants.defaultCurrencySymbol;

}
