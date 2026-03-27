import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/database/database_helper.dart';
import '../repositories/category_repository.dart';
import '../repositories/menu_item_repository.dart';
import '../repositories/table_repository.dart';
import '../repositories/customer_repository.dart';
import '../repositories/order_repository.dart';
import '../repositories/payment_repository.dart';
import '../repositories/inventory_repository.dart';
import '../repositories/settings_repository.dart';

final _db = DatabaseHelper.instance;

final categoryRepositoryProvider = Provider((_) => CategoryRepository(_db));
final menuItemRepositoryProvider = Provider((_) => MenuItemRepository(_db));
final tableRepositoryProvider = Provider((_) => TableRepository(_db));
final customerRepositoryProvider = Provider((_) => CustomerRepository(_db));
final orderRepositoryProvider = Provider((_) => OrderRepository(_db));
final paymentRepositoryProvider = Provider((_) => PaymentRepository(_db));
final inventoryRepositoryProvider = Provider((_) => InventoryRepository(_db));
final settingsRepositoryProvider = Provider((_) => SettingsRepository(_db));
