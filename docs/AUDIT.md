# Codebase Audit — Issues Found

> Status: Audit complete. See IMPROVEMENTS.md for the fix plan.

---

## CRITICAL

### C1 — Timezone bug in `isPlanActive()` / `trialDaysLeft()`
**File:** `lib/services/supabase/supabase_service.dart`
- `DateTime.parse(trialEnd as String).isAfter(DateTime.now().toUtc())` — the parsed DateTime is already UTC but `DateTime.now()` returns local time. Comparison is unreliable across timezones.
- **Fix:** Use `DateTime.now().toUtc()` (already done in `trialDaysLeft` but not consistently checked).

### C2 — Inconsistent default role on null — privilege escalation vs. lock-out
**Files:** `lib/screens/auth/login_screen.dart:165`, `lib/screens/auth/splash_screen.dart:88`
- `login_screen.dart` defaults missing `role` → `'owner'` (highest privilege).
- `splash_screen.dart` defaults missing `role` → `'waiter'` (lowest privilege).
- **Fix:** Always default to `'waiter'` (least privilege) everywhere.

### C3 — `isPlanActive()` returns `true` for unknown/misspelled plan values
**File:** `lib/services/supabase/supabase_service.dart`
- Any plan that isn't `'trial'` or `'suspended'` returns `true`. A corrupted or unknown plan string silently grants full access.
- **Fix:** Explicitly whitelist `['starter', 'standard', 'business']`; default to `false`.

### C4 — Dual state between `roleRouterNotifier` and `staffRoleProvider` is unsynchronized
**File:** `lib/providers/auth_providers.dart`
- `roleRouterNotifier` (ValueNotifier for GoRouter) and `staffRoleProvider` (Riverpod) must be kept in sync manually. If one is updated without the other, the router and UI disagree on user role.
- **Fix:** Create a single source of truth; derive `roleRouterNotifier` from the Riverpod state or use a listener.

---

## HIGH

### H1 — Router prefix matching: `/ordersX` falsely matches `/orders` guard
**File:** `lib/core/router/app_router.dart`
- `path.startsWith(r)` matches `/ordersABC` against allowed route `/orders`.
- **Fix:** Match `path == r || path.startsWith('$r/')` to require exact match or sub-path.

### H2 — Trial expiry: inconsistent enforcement between splash and MainScaffold
**Files:** `lib/screens/auth/splash_screen.dart`, `lib/widgets/main_scaffold.dart`
- `splash_screen.dart` routes expired trial users to `/paywall`.
- `main_scaffold.dart` only shows a banner for `trialDays <= 0` without redirecting.
- A user who reaches `MainScaffold` with an expired trial (e.g., trial expires mid-session) stays in the app indefinitely.
- **Fix:** Add a periodic or `didChangeDependencies` plan re-check in `MainScaffold` that redirects to `/paywall` if plan is expired.

### H3 — No offline restaurant fetch fallback in `login_screen.dart`
**File:** `lib/screens/auth/login_screen.dart:140`
- `fetchRestaurant()` fails silently if offline; user cannot proceed even with a valid session.
- **Fix:** Fall back to cached restaurant from `settings` table (same pattern as `splash_screen.dart`).

### H4 — `signOutAndClearNoRef()` used in LoginScreen instead of `signOutAndClear(ref)`
**File:** `lib/screens/auth/login_screen.dart:230`
- `signOutAndClearNoRef()` does not reset Riverpod providers. Stale role/trial/restaurant state persists.
- **Fix:** Use `signOutAndClear(ref)` in contexts where `ref` is available.

### H5 — `syncNotifier` not reset on sign-out
**File:** `lib/providers/auth_providers.dart`
- Old sync status persists when a different account logs in on the same device.
- **Fix:** Reset `syncNotifier` to `SyncStatus.idle` inside both sign-out functions.

---

## MEDIUM

### M1 — Paywall has no functional upgrade path
**File:** `lib/screens/auth/paywall_screen.dart`
- Plans are displayed but there is no way to purchase, no WhatsApp deep link, no in-app-purchase integration. Only a placeholder email.
- **Fix:** Add `url_launcher` links — WhatsApp deep link + mailto link with pre-filled subject/body.

### M2 — Plan prices are hardcoded; require rebuild to change
**File:** `lib/screens/auth/paywall_screen.dart`
- Plan names, prices, and feature lists are compile-time constants.
- **Fix:** Move to a remote config table in Supabase or a local `constants` file with a clear comment that changes need to be made there.

### M3 — Raw exception messages exposed to users
**Files:** `lib/screens/auth/login_screen.dart:250`, `lib/screens/auth/signup_screen.dart:62`
- `e.toString()` can surface internal Supabase/DB error strings to users.
- **Fix:** Map common Supabase error codes to friendly messages; show generic fallback for others.

### M4 — Dangling auth account if `createRestaurant()` fails after `signUp()`
**File:** `lib/screens/auth/signup_screen.dart:74`
- If `signUp()` succeeds but `createRestaurant()` throws, an orphaned auth account exists with no restaurant.
- The "complete setup" dialog in `login_screen.dart` partially mitigates this, but the dialog itself has no retry/error feedback.
- **Fix:** Wrap in a try/catch that attempts to delete the orphaned auth user, or guide user through setup completion more robustly.

### M5 — Currency dialog can be skipped; setting may not persist
**File:** `lib/screens/auth/signup_screen.dart:93-136`
- If the user force-quits during the post-signup currency dialog, the currency symbol may not be saved.
- **Fix:** Ensure currency has a sensible default before showing the dialog, and confirm persistence before routing to dashboard.

### M6 — `SupabaseService.isSignedIn` may return stale value
**File:** `lib/screens/auth/login_screen.dart:335`
- The static getter may not reflect session state accurately after a failed login attempt.
- **Fix:** Re-check session freshness from `Supabase.instance.client.auth.currentSession`.

### M7 — `/signup` route listed in redirect rules but doesn't exist
**File:** `lib/core/router/app_router.dart:55`
- Dead code in redirect logic; `SignupForm` is embedded in `LoginScreen`, not a separate route.
- **Fix:** Remove `/signup` from the redirect whitelist.

---

## LOW / UX

### L1 — Trial banner `trialDaysProvider` null → banner never shows
**File:** `lib/widgets/main_scaffold.dart:67`
- If `trialDaysProvider` is null (not set during session check), the trial warning banner is silently suppressed even when trial is about to expire.
- **Fix:** Fetch trial days independently in `MainScaffold` if provider is null.

### L2 — Vague "complete setup" dialog
**File:** `lib/screens/auth/login_screen.dart:148`
- Dialog does not explain *what* is missing (restaurant row, staff row, or both).
- **Fix:** Pass diagnostic info to the dialog so it shows actionable text.

### L3 — Hard-coded "Rs." in trial dialog assumes Indian locale
**File:** `lib/screens/auth/signup_screen.dart:187`
- Non-localized pricing string.
- **Fix:** Replace with `AppConstants.supportEmail` reference and remove price from dialog, or use the currency symbol from settings.

### L4 — App title fallback in `MainScaffold` shows wrong label
**File:** `lib/widgets/main_scaffold.dart:97-101`
- `firstWhere(orElse: ...)` falls back to first nav item label (Dashboard) for untracked routes.
- **Fix:** Include full-screen route titles in the lookup or return an empty string.

### L5 — No visual indicator that a drawer exists on mobile
**File:** `lib/widgets/main_scaffold.dart:129`
- Users with extra nav items (owner/manager) may not discover the hamburger drawer on narrow screens.
- **Fix:** Show a `DrawerButton` in the `AppBar` when extras are non-empty.
