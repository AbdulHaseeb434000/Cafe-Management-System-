import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/session_service.dart';
import '../services/supabase/supabase_service.dart';

/// Cloud sync status shown in the app bar.
enum SyncStatus { idle, syncing, error }

/// Holds the current signed-in staff's role.
/// Roles: 'owner' | 'manager' | 'waiter' | 'kitchen'
///
/// Defaults to 'waiter' (least privilege) so that if role loading fails the
/// user cannot accidentally access owner/manager-only features.
final staffRoleProvider = StateProvider<String>((ref) => 'waiter');

/// Days left in the trial (null = not on trial / paid plan).
/// Set during splash; used by MainScaffold for the expiry banner.
final trialDaysProvider = StateProvider<int?>((ref) => null);

/// Cached restaurant row fetched on login/splash.
/// Used by settings screen to avoid a network call every time it opens.
final restaurantProvider = StateProvider<Map<String, dynamic>?>((ref) => null);

/// Notifies the UI of the current cloud-sync state (idle / syncing / error).
///
/// Updated by [SyncService.push]. Watched in [MainScaffold] via
/// [ValueListenableBuilder] to show a cloud icon in the app bar.
final syncNotifier = ValueNotifier<SyncStatus>(SyncStatus.idle);

/// A [ValueNotifier] that mirrors [staffRoleProvider] so that [GoRouter]
/// (a non-Riverpod object) can react to role changes via [refreshListenable].
///
/// Must be updated alongside [staffRoleProvider] in every place the role is
/// written (splash screen, sign-out). Defaults to 'waiter' to match the
/// provider's least-privilege default.
final roleRouterNotifier = ValueNotifier<String>('waiter');

/// Sets the staff role atomically in both the Riverpod provider (for UI) and
/// the [roleRouterNotifier] bridge (for GoRouter redirect).
///
/// Always use this helper instead of writing to either store directly so they
/// can never fall out of sync.
void setRole(String role, WidgetRef ref) {
  ref.read(staffRoleProvider.notifier).state = role;
  roleRouterNotifier.value = role;
}

/// Signs out the current user and atomically resets all auth-related state.
///
/// Call this at every sign-out site instead of calling
/// [SupabaseService.signOut] directly. Resets Riverpod providers and the
/// [roleRouterNotifier] bridge so that a subsequent login on the same device
/// starts with clean state (no stale role / plan data).
///
/// When a [WidgetRef] is available (ConsumerWidget / ConsumerState) prefer
/// this overload so that all three Riverpod providers are also reset.
Future<void> signOutAndClear(WidgetRef ref) async {
  await SupabaseService.signOut();
  ref.read(staffRoleProvider.notifier).state = 'waiter';
  ref.read(trialDaysProvider.notifier).state = null;
  ref.read(restaurantProvider.notifier).state = null;
  roleRouterNotifier.value = 'waiter';
  syncNotifier.value = SyncStatus.idle;
  SessionService.instance.clear();
}

/// Ref-free sign-out for contexts without a [WidgetRef] (e.g. plain
/// [StatefulWidget] dialogs). Resets the router bridge notifier so the
/// router immediately enforces waiter-level guards. Riverpod providers
/// are reset on the next splash/login cycle.
Future<void> signOutAndClearNoRef() async {
  await SupabaseService.signOut();
  roleRouterNotifier.value = 'waiter';
  syncNotifier.value = SyncStatus.idle;
  SessionService.instance.clear();
}
