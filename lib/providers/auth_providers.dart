import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds the current signed-in staff's role.
/// Set after login / splash resolves. Defaults to 'owner' so that
/// if the role can't be fetched the user still sees the full app.
///
/// Roles: 'owner' | 'manager' | 'waiter' | 'kitchen'
final staffRoleProvider = StateProvider<String>((ref) => 'owner');
