import 'package:intl/intl.dart';
import '../constants/app_constants.dart';

class CurrencyFormatter {
  CurrencyFormatter._();

  /// Updated by [MainScaffold] whenever settings change, so all screens
  /// automatically pick up the user-configured symbol without needing to
  /// thread it through every call site.
  static String currentSymbol = AppConstants.defaultCurrencySymbol;

  static String format(double amount, {String? symbol}) {
    final sym = symbol ?? currentSymbol;
    final formatter = NumberFormat('#,##0.00');
    return '$sym ${formatter.format(amount)}';
  }

  static String formatCompact(double amount, {String? symbol}) {
    final sym = symbol ?? currentSymbol;
    final formatter = NumberFormat('#,##0');
    return '$sym ${formatter.format(amount)}';
  }

  /// Amount only, no symbol — used for share receipt text alignment
  static String formatRaw(double amount) =>
      NumberFormat('#,##0.00').format(amount);
}
