# Codebase Audit — Issues Found

> Status: Updated with second-pass observations.
> See IMPROVEMENTS.md for the fix plan.

---

## CRITICAL

### C1 — Timezone bug in `isPlanActive()` / `trialDaysLeft()`
**File:** `lib/services/supabase/supabase_service.dart`
- `DateTime.parse(trialEnd as String).isAfter(DateTime.now().toUtc())` — the parsed DateTime is UTC but `DateTime.now()` returns local time without timezone. Comparison unreliable near midnight in non-UTC zones.
- **Fix:** Ensure `DateTime.parse(...).toUtc()` on both sides consistently.

### C2 — Inconsistent default role — privilege escalation
**Files:** `lib/screens/auth/login_screen.dart:165`, `lib/screens/auth/splash_screen.dart:88`
- `login_screen.dart:165`: `staff?['role'] as String? ?? 'owner'` — defaults to highest privilege.
- `splash_screen.dart`: defaults to `'waiter'`.
- **Fix:** Always default to `'waiter'` (least privilege) everywhere.

### C3 — `isPlanActive()` grants access on unknown plan values
**File:** `lib/services/supabase/supabase_service.dart`
- Any plan that isn't `'trial'` or `'suspended'` returns `true`. A corrupted/misspelled plan string silently grants access.
- **Fix:** Explicitly whitelist `['starter', 'standard', 'business']`; everything else returns `false`.

### C4 — Dual role state: `roleRouterNotifier` and `staffRoleProvider` can desync
**File:** `lib/providers/auth_providers.dart`
- Two separate stores must be kept in sync manually. If one is updated without the other, router and UI disagree on user role — routing guard bypassed.
- **Fix:** Add a `setRole(String, WidgetRef)` helper that updates both atomically.

---

## HIGH

### H1 — Router prefix matching: `/ordersX` falsely matches `/orders` guard
**File:** `lib/core/router/app_router.dart`
- `path.startsWith(r)` matches `/ordersABC` against allowed route `/orders`.
- **Fix:** `path == r || path.startsWith('$r/')`

### H2 — Trial expiry: no mid-session enforcement in `MainScaffold`
**Files:** `lib/screens/auth/splash_screen.dart`, `lib/widgets/main_scaffold.dart`
- `splash_screen.dart` routes expired users to `/paywall`. But if trial expires while the app is open, `MainScaffold` only shows a banner — no redirect. User stays indefinitely.
- **Fix:** Add periodic plan re-check in `MainScaffold`; redirect to `/paywall` on expiry.

### H3 — No offline restaurant fetch fallback in `LoginScreen`
**File:** `lib/screens/auth/login_screen.dart:140`
- `fetchRestaurant()` fails silently if offline; user can't proceed even with a valid cached session.
- **Fix:** Fall back to cached restaurant from `settings` table (same as `splash_screen.dart`).

### H4 — `signOutAndClearNoRef()` used where `ref` is available
**File:** `lib/screens/auth/login_screen.dart:230`
- Does not reset Riverpod providers; stale role/trial/restaurant state persists.
- **Fix:** Use `signOutAndClear(ref)`.

### H5 — `syncNotifier` not reset on sign-out
**File:** `lib/providers/auth_providers.dart`
- Old sync status leaks into next account session on same device.
- **Fix:** Reset to `SyncStatus.idle` in both sign-out functions.

### H6 — No kitchen notification when order is edited
**File:** `lib/screens/orders/edit_order_screen.dart`
- After editing an order's items/quantities, kitchen has no indication the ticket has changed. Kitchen staff may prepare the old ticket.
- **Fix:** After saving edits, mark order as `edited_after_print` (new status flag or note), and show a warning banner on the kitchen card + re-print prompt on the order detail screen.

### H7 — Kitchen screen allows navigating into order detail where editing is possible
**File:** `lib/screens/kitchen/kitchen_screen.dart`
- Kitchen staff tap an order → opens `OrderDetailScreen` → which has an Edit button (accessible to waiter/manager/owner). Kitchen role should not be able to trigger edits.
- **Fix:** Hide the Edit action in `OrderDetailScreen` when `staffRole == 'kitchen'`.

### H8 — Data does not persist across fresh app install or deletion
**Files:** `lib/services/sync/sync_service.dart`, `lib/main.dart`
- `SyncService.start()` is called in `main()` before the user is authenticated. The pull-from-Supabase only works when a valid session exists. On fresh install, the sync pull may run before login completes, loading nothing.
- **Fix:** Trigger a full pull explicitly after successful login/signup, not just on app start.

---

## MEDIUM

### M1 — Paywall has no functional upgrade path
**File:** `lib/screens/auth/paywall_screen.dart`
- Plans are displayed but no way to purchase. Only a placeholder email.
- **Fix:** Add `url_launcher` — WhatsApp deep link + mailto with pre-filled subject/body.

### M2 — Plan prices hardcoded; require rebuild to change
**File:** `lib/screens/auth/paywall_screen.dart`
- **Fix:** Extract to `lib/core/constants/plan_constants.dart`.

### M3 — Raw exception messages exposed to users
**Files:** `lib/screens/auth/login_screen.dart:250`, `lib/screens/auth/signup_screen.dart:62`
- `e.toString()` can surface Supabase/DB internals.
- **Fix:** Map `AuthException` error codes to user-friendly strings.

### M4 — Dangling auth account if `createRestaurant()` fails
**File:** `lib/screens/auth/signup_screen.dart:74`
- Auth user created but restaurant creation fails → orphaned account.
- **Fix:** On failure, sign out + guide user through retry.

### M5 — Currency dialog skippable; setting may not persist
**File:** `lib/screens/auth/signup_screen.dart:93`
- Force-quitting during the post-signup currency dialog may leave no currency saved.
- **Fix:** Set a default before showing the dialog.

### M6 — Stale `SupabaseService.isSignedIn` check
**File:** `lib/screens/auth/login_screen.dart:335`
- **Fix:** Replace with `Supabase.instance.client.auth.currentSession != null`.

### M7 — `/signup` dead route in redirect rules
**File:** `lib/core/router/app_router.dart:55`
- `SignupForm` is embedded in `LoginScreen`, no separate `/signup` route exists.
- **Fix:** Remove from redirect whitelist.

### M8 — No "End Plan / Cancel Subscription" option
**File:** `lib/screens/settings/settings_screen.dart`
- Owner has no way to cancel their subscription from within the app.
- **Fix:** Add a "Manage Subscription" section in Settings with a cancel/downgrade contact link.

### M9 — Staff deactivation: saved token may still allow local access
**File:** `lib/screens/staff/staff_screen.dart`
- When a staff member is deactivated on Supabase, their Supabase JWT token (if still valid) may not be revoked server-side immediately. On a device where the app is open or token is cached, they may retain access until the token expires.
- **Fix:** Deactivation should call Supabase Admin API to revoke/ban the user, or enforce a server-side check on each API call against the `is_active` flag.

### M10 — Subscription billing model: no upfront billing, no staff-add warning
**Design decision required:**
- No billing is charged upfront at plan activation — manual process via WhatsApp.
- No warning when owner adds a staff member that it increases billing.
- **Fix:** When adding a staff member, show a dialog: "Adding this member may affect your billing. Contact support to confirm." Log the addition with a timestamp. Bill at start of each cycle (not mid-cycle additions).

### M11 — No "Remember Me" / saved credentials on login screen
**File:** `lib/screens/auth/login_screen.dart`
- Users must re-enter credentials every time unless Supabase token is still valid.
- **Fix:** Add a "Remember me" checkbox. If checked, persist the Supabase session using `flutter_secure_storage` so credentials reload on startup.

### M12 — No session timeout / inactivity lock
**All screens** — No auto sign-out after inactivity period.
- **Fix:** Add configurable session timeout (e.g., 30 min inactivity). Use `AppLifecycleState` changes to track idle time. Show lock screen or sign out.

### M13 — Receipt footer not printing on bill (to verify)
**Files:** `lib/screens/billing/billing_screen.dart`, `lib/services/pdf/pdf_receipt_service.dart`
- Code review shows footer IS passed to `buildReceipt()` and IS included in PDF. If user reports it missing, issue may be that `settingReceiptFooter` key is not being read from local `settings` table correctly.
- **Fix:** Verify settings key constant matches what is saved in DB. Add a debug log.

### M14 — Export backup relevance with cloud sync
**File:** `lib/screens/settings/settings_screen.dart`
**Design question:** Now that Supabase cloud sync exists, the `.platodesk` local backup export may be redundant. However, it serves as a user-controlled offline archive.
- **Decision:** Keep export but change description to "Local Backup Archive — your data is also synced to cloud." Remove the import feature or warn that importing will conflict with cloud data.

---

## LOW / UX

### L1 — Trial banner silently suppressed when `trialDaysProvider` is null
**File:** `lib/widgets/main_scaffold.dart:67`
- **Fix:** Fall back to `restaurantProvider` to compute days if provider is null.

### L2 — Vague "complete setup" dialog
**File:** `lib/screens/auth/login_screen.dart:148`
- **Fix:** Pass which record is missing (restaurant vs. staff); show targeted message.

### L3 — Hardcoded "Rs." currency in signup trial dialog
**File:** `lib/screens/auth/signup_screen.dart:187`
- **Fix:** Remove price from dialog; reference support contact for pricing.

### L4 — App title fallback shows wrong label for untracked routes
**File:** `lib/widgets/main_scaffold.dart:97`
- **Fix:** Return empty string or derive from route name.

### L5 — No visual indicator that a drawer exists on mobile
**File:** `lib/widgets/main_scaffold.dart:129`
- **Fix:** Show `DrawerButton` in `AppBar.leading` when extras are non-empty.

### L6 — Currency default should be `$`; and currency doesn't update everywhere
**Files:** `lib/core/constants/app_constants.dart`, multiple screens
- `defaultCurrencySymbol` is likely `'Rs.'`. User expects `'$'` as neutral default (or whatever was chosen at onboarding).
- Currency change in Settings does not update light/hint text in some screens.
- **Fix:** Set `defaultCurrencySymbol = '\$'`. Audit all hardcoded `'Rs.'` strings — replace with `CurrencyFormatter.format()` or `AppConstants.defaultCurrencySymbol`.

### L7 — "No free tables" shown when there are zero tables; should say "Add Tables"
**File:** `lib/screens/orders/new_order_screen.dart:350`
- Currently shows "No free tables available" regardless of whether tables exist.
- When `allTables.isEmpty` → show "No tables added yet — go to Settings to add tables."
- When `allTables.isNotEmpty && freeTables.isEmpty` → show "No free tables available."
- **Fix:** Check total table count separately.

### L8 — Placeholder hint text uses specific names/examples in input fields
**Multiple screens** — `hintText: 'e.g. John'`, `hintText: 'e.g. Rs. 500'` etc. are distracting.
- **Fix:** Replace with generic hints: `'Customer name'`, `'Amount'`.

### L9 — Floating Action Button (FAB) visible during PDF preview screens
**File:** Kitchen ticket / bill preview screens
- A toggle button or FAB shows in the bottom-right during preview — likely the main scaffold's FAB bleeding through.
- **Fix:** Hide FAB/bottom nav when navigating to full-screen preview routes.

### L10 — No onboarding configuration questions
**File:** `lib/screens/auth/signup_screen.dart`
- Only asks for currency after signup. Missing: cafe type (QSR/Fine Dining/Cafe), number of tables, default tax rate, receipt header.
- **Fix:** Add a multi-step onboarding after first signup: cafe details → table count → tax → receipt settings. Save to `settings` table.

### L11 — Inventory module missing Purchase and Issue-to-Kitchen sub-screens
**File:** `lib/screens/inventory/inventory_screen.dart`
- Only manual stock adjustment exists. No structured "Purchase" (stock in with supplier/cost) or "Issue to Kitchen" (stock out for production) workflow.
- **Fix:** Add two sub-screens: `PurchaseScreen` (add stock with purchase price and supplier) and `IssueScreen` (deduct stock with reason: kitchen use). Update `inventory_logs` to record type.

### L12 — Inventory items have no purchase price; can't calculate COGS
**File:** `lib/models/inventory_item_model.dart`
- No `unit_cost` or `purchase_price` field.
- **Fix:** Add `unit_cost` to `inventory_items` table and model. Show cost value in reports.

### L13 — Expense list item: name/details/amount can overlap on small screens
**File:** `lib/screens/expenses/expenses_screen.dart:209`
- Amount is in `Flexible(fit: FlexFit.loose)` — can get squished by long description.
- **Fix:** Use `Text` with `overflow: TextOverflow.ellipsis` on description; give amount a `minWidth` constraint.

### L14 — Logout not prominent; no logout from main navigation
**File:** `lib/screens/settings/settings_screen.dart:247`
- Logout exists but is buried in Settings. Users expect a logout option in the top app bar or profile menu, not only in settings.
- **Fix:** Add a logout icon button to the `AppBar` of `MainScaffold`, visible to all roles.
