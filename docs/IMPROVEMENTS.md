# Improvement Plan

> Consult AUDIT.md for full issue details.
> Work on branch: `claude/audit-and-plan-INSyA`
> Complete iterations in order. Mark tasks `[x]` when done.

---

## Iteration 1 — Critical Auth & Security Fixes

**Goal:** Fix all CRITICAL bugs that could allow unauthorized access or cause auth failures.

- [ ] **C1** Fix timezone bug in `isPlanActive()` and `trialDaysLeft()`
  - `lib/services/supabase/supabase_service.dart`
  - Ensure both comparisons use `DateTime.now().toUtc()`

- [ ] **C2** Normalize default role to `'waiter'` (least privilege) everywhere
  - `lib/screens/auth/login_screen.dart:165` — change `?? 'owner'` → `?? 'waiter'`
  - Verify `lib/screens/auth/splash_screen.dart` already uses `'waiter'`

- [ ] **C3** Whitelist valid plan values in `isPlanActive()`
  - `lib/services/supabase/supabase_service.dart`
  - Return `true` only for `['starter', 'standard', 'business']`; everything else returns `false`

- [ ] **C4** Fix dual state: `roleRouterNotifier` vs `staffRoleProvider`
  - `lib/providers/auth_providers.dart`
  - Whenever `staffRoleProvider` is written, update `roleRouterNotifier` in the same call
  - Add a helper `setRole(String role, WidgetRef ref)` that updates both atomically

---

## Iteration 2 — Router & Navigation Fixes

**Goal:** Fix routing security and navigation correctness.

- [ ] **H1** Fix route prefix matching bug
  - `lib/core/router/app_router.dart`
  - Replace `path.startsWith(r)` with `path == r || path.startsWith('$r/')`

- [ ] **M7** Remove dead `/signup` redirect rule
  - `lib/core/router/app_router.dart`
  - Remove `/signup` from the redirect whitelist

- [ ] **H2** Add mid-session plan expiry enforcement in `MainScaffold`
  - `lib/widgets/main_scaffold.dart`
  - Watch `trialDaysProvider`; if it drops to 0 AND plan is trial, call `context.go('/paywall')`
  - Or add a periodic `Timer` (e.g., every 5 minutes) that re-checks plan status

---

## Iteration 3 — Auth UX & State Fixes

**Goal:** Fix state management issues and improve login/signup reliability.

- [ ] **H4** Replace `signOutAndClearNoRef()` with `signOutAndClear(ref)` in `LoginScreen`
  - `lib/screens/auth/login_screen.dart:230`

- [ ] **H5** Reset `syncNotifier` in both sign-out functions
  - `lib/providers/auth_providers.dart`
  - Set `syncNotifier.value = SyncStatus.idle`

- [ ] **H3** Add offline restaurant fallback in `LoginScreen._submit()`
  - `lib/screens/auth/login_screen.dart`
  - Load cached restaurant from `settings` table if `fetchRestaurant()` returns null

- [ ] **M6** Fix stale `SupabaseService.isSignedIn` check
  - Replace with `Supabase.instance.client.auth.currentSession != null`

- [ ] **M3** Sanitize exception messages shown to users
  - `lib/screens/auth/login_screen.dart`, `lib/screens/auth/signup_screen.dart`
  - Map `AuthException` error codes to user-friendly strings
  - Show a generic fallback for unknown errors

- [ ] **M4** Handle orphaned auth account after failed `createRestaurant()`
  - `lib/screens/auth/signup_screen.dart`
  - On `createRestaurant()` failure: attempt sign-out + show retry guidance

---

## Iteration 4 — Subscription & Paywall

**Goal:** Make the paywall functional and the subscription system more robust.

- [ ] **M1** Add functional contact links to `PaywallScreen`
  - `lib/screens/auth/paywall_screen.dart`
  - Add `url_launcher` calls: WhatsApp deep link + mailto with pre-filled subject
  - Replace placeholder email text with tappable `InkWell`

- [ ] **M2** Move plan definitions to a constants file
  - Create `lib/core/constants/plan_constants.dart`
  - Move `_plans` list there; add a comment explaining how to update pricing

- [ ] **L3** Remove hardcoded "Rs." from signup trial dialog
  - `lib/screens/auth/signup_screen.dart:187`
  - Replace price reference with a note to check email for pricing

---

## Iteration 5 — UI/UX Polish

**Goal:** Fix UI bugs and improve discoverability.

- [ ] **L1** Fix trial banner when `trialDaysProvider` is null
  - `lib/widgets/main_scaffold.dart`
  - If provider is null, attempt to compute days from cached `restaurantProvider`

- [ ] **L2** Improve "complete setup" dialog with specific guidance
  - `lib/screens/auth/login_screen.dart`
  - Pass which record is missing (restaurant vs. staff) and show targeted instructions

- [ ] **L4** Fix `MainScaffold` title for untracked routes
  - `lib/widgets/main_scaffold.dart`
  - Return empty string or route-derived label instead of falling back to first item

- [ ] **L5** Add `DrawerButton` in AppBar when drawer exists
  - `lib/widgets/main_scaffold.dart`
  - Show hamburger icon in `AppBar.leading` when `extras.isNotEmpty` on mobile

- [ ] **M5** Ensure currency has a default before showing dialog
  - `lib/screens/auth/signup_screen.dart`
  - Set `currency_symbol = 'Rs.'` in settings before showing the picker dialog

---

## Notes

- Each iteration should be committed separately.
- Run `flutter analyze` after each iteration — zero warnings/errors required.
- Test auth flows manually: new signup, login, trial expiry, offline mode, role switching.
