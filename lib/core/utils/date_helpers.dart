import 'package:intl/intl.dart';

class DateHelpers {
  DateHelpers._();

  static String toIso(DateTime dt) => dt.toIso8601String();

  static DateTime fromIso(String iso) => DateTime.parse(iso);

  static String formatDate(DateTime dt) => DateFormat('dd MMM yyyy').format(dt);

  static String formatTime(DateTime dt) => DateFormat('hh:mm a').format(dt);

  static String formatDateTime(DateTime dt) =>
      DateFormat('dd MMM yyyy, hh:mm a').format(dt);

  static String formatShort(DateTime dt) => DateFormat('dd/MM/yy').format(dt);

  static DateTime get todayStart {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static DateTime get todayEnd {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
  }

  static DateTime weekStart(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  static DateTime monthStart(DateTime date) =>
      DateTime(date.year, date.month, 1);

  static DateTime monthEnd(DateTime date) =>
      DateTime(date.year, date.month + 1, 0, 23, 59, 59, 999);
}
