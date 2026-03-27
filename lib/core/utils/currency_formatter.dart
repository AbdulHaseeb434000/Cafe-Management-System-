import 'package:intl/intl.dart';

class CurrencyFormatter {
  CurrencyFormatter._();

  static String format(double amount, {String symbol = 'Rs.'}) {
    final formatter = NumberFormat('#,##0.00');
    return '$symbol ${formatter.format(amount)}';
  }

  static String formatCompact(double amount, {String symbol = 'Rs.'}) {
    final formatter = NumberFormat('#,##0');
    return '$symbol ${formatter.format(amount)}';
  }
}
