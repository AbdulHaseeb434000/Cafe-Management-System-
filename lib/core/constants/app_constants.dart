class AppConstants {
  AppConstants._();

  static const String appName = 'PlatoDesk';
  static const String appVersion = '1.0.0';
  static const String dbName = 'platodesk.db';
  static const int dbVersion = 8;

  // Settings keys
  static const String settingCafeName = 'cafe_name';
  static const String settingCafeAddress = 'cafe_address';
  static const String settingCafePhone = 'cafe_phone';
  static const String settingTaxPercent = 'tax_percent';
  static const String settingReceiptHeader = 'receipt_header';
  static const String settingReceiptFooter = 'receipt_footer';
  static const String settingLogoPath = 'logo_path';
  static const String settingCurrencySymbol = 'currency_symbol';

  // Default values
  static const double defaultTaxPercent = 0.0;
  static const String defaultCurrencySymbol = 'Rs.';

  // Order types
  static const String orderTypeDineIn = 'dine_in';
  static const String orderTypeTakeaway = 'takeaway';
  static const String orderTypeDelivery = 'delivery';

  // Order statuses
  static const String orderStatusPending = 'pending';
  static const String orderStatusPreparing = 'preparing';
  static const String orderStatusReady = 'ready';
  static const String orderStatusCompleted = 'completed';
  static const String orderStatusCancelled = 'cancelled';

  // Table statuses
  static const String tableStatusFree = 'free';
  static const String tableStatusOccupied = 'occupied';
  static const String tableStatusReserved = 'reserved';

  // Discount types
  static const String discountTypeFlat = 'flat';
  static const String discountTypePercent = 'percent';

  // Payment methods
  static const String paymentMethodCash = 'cash';
  static const String paymentMethodCard = 'card';
}
