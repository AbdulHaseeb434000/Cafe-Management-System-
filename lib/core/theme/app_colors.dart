import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary palette — warm cream & amber
  static const Color background = Color(0xFFFFF8F0);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFFFF0DC);

  static const Color primary = Color(0xFFFFB300);
  static const Color primaryLight = Color(0xFFFFD54F);
  static const Color primaryDark = Color(0xFFF57F17);

  static const Color brown = Color(0xFF5D4037);
  static const Color brownLight = Color(0xFF8D6E63);
  static const Color brownDark = Color(0xFF3E2723);

  // Order type badges
  static const Color dineIn = Color(0xFFFFB300);    // amber
  static const Color takeaway = Color(0xFF8D6E63);  // brown
  static const Color delivery = Color(0xFF00897B);  // teal

  // Table status
  static const Color tableFree = Color(0xFF43A047);
  static const Color tableOccupied = Color(0xFFE53935);
  static const Color tableReserved = Color(0xFFFFA000);

  // Order status
  static const Color statusPending = Color(0xFF9E9E9E);
  static const Color statusPreparing = Color(0xFF1E88E5);
  static const Color statusReady = Color(0xFF43A047);
  static const Color statusCompleted = Color(0xFF5D4037);
  static const Color statusCancelled = Color(0xFFE53935);

  // Semantic
  static const Color error = Color(0xFFD32F2F);
  static const Color success = Color(0xFF388E3C);
  static const Color warning = Color(0xFFF57C00);
  static const Color info = Color(0xFF1976D2);

  // Text
  static const Color textPrimary = Color(0xFF3E2723);
  static const Color textSecondary = Color(0xFF8D6E63);
  static const Color textDisabled = Color(0xFFBCAAA4);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Borders & dividers
  static const Color divider = Color(0xFFEFEBE9);
  static const Color border = Color(0xFFD7CCC8);
}
