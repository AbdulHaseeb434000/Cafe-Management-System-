class AppConstants {
  AppConstants._();

  static const String appName = 'CafeDesk';
  static const String appVersion = '1.0.0';
  static const String dbName = 'cafedesk.db';
  static const int dbVersion = 1;

  // Settings keys
  static const String settingCafeName = 'cafe_name';
  static const String settingCafeAddress = 'cafe_address';
  static const String settingCafePhone = 'cafe_phone';
  static const String settingTaxPercent = 'tax_percent';
  static const String settingReceiptHeader = 'receipt_header';
  static const String settingReceiptFooter = 'receipt_footer';
  static const String settingPosPrinterAddress = 'pos_printer_address';
  static const String settingPosPrinterName = 'pos_printer_name';
  static const String settingKitchenPrinterAddress = 'kitchen_printer_address';
  static const String settingKitchenPrinterName = 'kitchen_printer_name';
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
