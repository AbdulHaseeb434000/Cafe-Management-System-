import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds the current signed-in staff's role.
/// Roles: 'owner' | 'manager' | 'waiter' | 'kitchen'
final staffRoleProvider = StateProvider<String>((ref) => 'owner');

/// Days left in the trial (null = not on trial / paid plan).
/// Set during splash; used by MainScaffold for the expiry banner.
final trialDaysProvider = StateProvider<int?>((ref) => null);

/// Cached restaurant row fetched on login/splash.
/// Used by settings screen to avoid a network call every time it opens.
final restaurantProvider = StateProvider<Map<String, dynamic>?>((ref) => null);
