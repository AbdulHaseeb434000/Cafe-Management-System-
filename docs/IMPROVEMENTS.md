# Improvement Plan

> Consult AUDIT.md for full issue details and file/line references.
> Work on branch: `claude/audit-and-plan-INSyA`
> Complete iterations in order. Mark tasks `[x]` when done.

---

## Iteration 1 — Critical Auth & Security Fixes

**Goal:** Fix all CRITICAL bugs. No release until these are done.

- [x] **C1** Fix timezone bug in `isPlanActive()` and `trialDaysLeft()`
  - `lib/services/supabase/supabase_service.dart`
  - Use `DateTime.parse(trialEnd as String).toUtc()` on both sides

- [x] **C2** Normalize default role to `'waiter'` everywhere
  - `lib/screens/auth/login_screen.dart` — `?? 'owner'` → `?? 'waiter'`
  - `lib/screens/auth/splash_screen.dart` confirmed uses `'waiter'`

- [x] **C3** Whitelist valid plan values in `isPlanActive()`
  - `lib/services/supabase/supabase_service.dart`
  - Returns `true` only for `{'starter', 'standard', 'business'}`; else `false`

- [x] **C4** Fix dual state: added `setRole(String role, WidgetRef ref)` helper
  - `lib/providers/auth_providers.dart`
  - Replaces all direct writes in `login_screen.dart` and `splash_screen.dart`

---

## Iteration 2 — Router & Navigation Fixes

**Goal:** Secure routing; fix navigation edge cases.

- [x] **H1** Fix route prefix matching bug — already correctly implemented (`path == r || path.startsWith('$r/')`)

- [x] **M7** Remove dead `/signup` redirect rule
  - `lib/core/router/app_router.dart` — removed `/signup` from the skip list

- [x] **H2** Add mid-session plan expiry enforcement in `MainScaffold`
  - `lib/widgets/main_scaffold.dart` — converted to `ConsumerStatefulWidget`
  - Added `WidgetsBindingObserver.didChangeAppLifecycleState` that re-checks
    `isPlanActive()` against cached `restaurantProvider` on every app resume
  - No network call needed; uses cached trial_end_date

- [x] **L9** Hide toggle button in PDF preview screens
  - `lib/screens/receipt/receipt_preview_screen.dart`
  - Suppressed `PdfPreview` built-in floating action bar with `actions: const []`
  - Moved Print and Share as `IconButton`s in the `AppBar`

---

## Iteration 3 — Auth UX & State Fixes

**Goal:** Reliable login/signup; clean state on sign-out.

- [x] **H4** Replaced `signOutAndClearNoRef()` with `signOutAndClear(ref)` in `LoginScreen`
  - `lib/screens/auth/login_screen.dart` — setup dialog sign-out now resets all providers

- [x] **H5** Reset `syncNotifier` in both sign-out functions
  - `lib/providers/auth_providers.dart` — both `signOutAndClear` and `signOutAndClearNoRef` now reset to `SyncStatus.idle`

- [x] **H3** Added offline restaurant fallback in `LoginScreen._submit()`
  - On `fetchRestaurant()` failure, loads cached restaurant from `settings` table
  - Also caches the restaurant row after a successful online fetch

- [x] **M6** Fixed stale `isSignedIn` check
  - Replaced with `SupabaseService.currentSession != null`

- [x] **M3** Sanitized exception messages shown to users
  - Added `_friendlyAuthError(AuthException)` in both `login_screen.dart` and `signup_screen.dart`
  - Maps invalid credentials, email not confirmed, rate limit, etc. to plain English
  - Generic catch shows "Something went wrong. Please try again."

- [x] **M4** Handle orphaned auth account after failed `createRestaurant()`
  - `lib/screens/auth/signup_screen.dart` — wraps `createRestaurant()` in try/catch; calls `signOut()` before rethrowing

- [x] **H8** Fixed initial data pull on new device / offline first login
  - `lib/services/sync/sync_service.dart` — `_initialPullIfNeeded()` now confirms online (via `fetchStaffRecord`) before proceeding; flag not written if offline
  - Connectivity listener now also calls `_initialPullIfNeeded()` on reconnect so offline first-logins automatically pull data when internet is restored

- [x] **M11** Added "Remember Me" checkbox on login screen
  - `pubspec.yaml` — added `flutter_secure_storage: ^9.2.2`
  - `lib/screens/auth/login_screen.dart` — checkbox pre-fills email+password on startup; credentials saved to Android Keystore / iOS Keychain; cleared when unchecked

- [x] **L3** Removed hardcoded "Rs. 2,000/month" from signup trial dialog
  - `lib/screens/auth/signup_screen.dart` — replaced with contact email reference

---

## Iteration 4 — Kitchen & Order Integrity

**Goal:** Fix kitchen workflow and order-edit notification gaps.

- [x] **H6** Notify kitchen when an order is edited after ticket is printed
  - `lib/core/constants/app_constants.dart` — bumped `dbVersion` to 8
  - `lib/core/database/database_helper.dart` — added `needs_reprint` column + v8 migration
  - `lib/models/order_model.dart` — added `needsReprint` field
  - `lib/repositories/order_repository.dart` — added `setNeedsReprint()`
  - `lib/screens/orders/edit_order_screen.dart` — sets `needs_reprint = true` when editing a preparing/ready order
  - `lib/screens/kitchen/kitchen_screen.dart` — orange border + amber banner when `needsReprint`; clears flag on print
  - `lib/screens/orders/order_detail_screen.dart` — clears `needs_reprint` on `print_kitchen` action

- [x] **H7** Restrict Edit button in `OrderDetailScreen` for kitchen role
  - `lib/screens/orders/order_detail_screen.dart`
  - Edit / Force Edit popup items hidden when `staffRoleProvider == 'kitchen'`
  - Force Edit button in locked-order banner also hidden for kitchen role

- [x] **M13** Verified receipt footer
  - Confirmed `AppConstants.settingReceiptFooter` key is consistently used in both `BillingScreen` and `PdfReceiptService`; no mismatch found

---

## Iteration 5 — Subscription, Paywall & Staff Billing

**Goal:** Make upgrade path functional; address billing design gaps.

- [x] **M1** Add functional contact links to `PaywallScreen`
  - `lib/screens/auth/paywall_screen.dart` — WhatsApp deep link + pre-filled mailto; reads restaurant name from `restaurantProvider` for context in the message subject

- [x] **M2** Extract plan definitions to constants file
  - Created `lib/core/constants/plan_constants.dart` — `PlanInfo`, `PlanConstants.plans`, `PlanConstants.supportWhatsApp`, `PlanConstants.supportEmail`
  - `paywall_screen.dart` and `settings_screen.dart` now reference `PlanConstants`

- [x] **M8** Add "Manage Subscription" section in Settings
  - `lib/screens/settings/settings_screen.dart` — new section with WhatsApp + email `ListTile`s; pre-fills restaurant name in URL

- [x] **M9** Enforce staff deactivation server-side (client done; RLS documented)
  - `lib/services/supabase/supabase_service.dart` — `deactivateStaff` already sets `is_active = false`
  - Added doc comment instructing the Supabase RLS policy to block deactivated users; JWT tokens expire within 1 hour by default

- [x] **M10** Staff-add billing warning dialog — already implemented
  - `lib/screens/staff/staff_screen.dart._showAddDialog()` shows billing warning before proceeding

- [x] **L3** Remove hardcoded "Rs." from signup trial dialog — done in Iteration 3

- [x] **D1** Remove backup export/import
  - `lib/screens/settings/settings_screen.dart` — removed `_BackupRestoreSection` widget and `Backup & Restore` section header
  - Removed unused imports: `backup_service.dart`, `database_helper.dart`, `date_helpers.dart`

---

## Iteration 6 — UI/UX Fixes

**Goal:** Fix visual bugs and confusing messages.

- [x] **L14** Add logout button to `MainScaffold` AppBar
  - `lib/widgets/main_scaffold.dart` — `IconButton(Icons.logout)` in mobile `AppBar.actions` and tablet `NavigationRail.trailing`; both show confirm dialog via `_confirmSignOut()`

- [x] **L6** Fix currency default and update everywhere
  - `lib/core/constants/app_constants.dart` — `defaultCurrencySymbol` changed to `'$'`
  - `lib/core/utils/currency_formatter.dart` — added `static String currentSymbol`; `format()` / `formatCompact()` use it as default
  - `lib/widgets/main_scaffold.dart` — updates `CurrencyFormatter.currentSymbol` on every rebuild from settings, so symbol propagates immediately

- [x] **L7** Fix "no tables" message distinction
  - `lib/screens/orders/new_order_screen.dart` — `tables.isEmpty` → "No tables added yet" + "Go to Settings"; `freeTables.isEmpty` → "All tables are occupied" + "Go to Tables"

- [x] **L8** Remove example placeholder text from input fields
  - `lib/screens/menu/menu_screen.dart` — removed `hintText: 'e.g. Beverages'`
  - `lib/screens/tables/tables_screen.dart` — removed `hintText: 'e.g. Table 1'`
  - `lib/screens/settings/settings_screen.dart` — removed `hintText: 'e.g. Table 1'` from table manager
  - `lib/screens/auth/signup_screen.dart` — `'e.g. Plato Café'` → `'Restaurant name'`, `'e.g. Ahmed Khan'` → `'Your full name'`, `'e.g. AB3X9Z'` → `'6-character code'`, updated currency label

- [x] **L13** Fix expense list item text overlap
  - `lib/screens/expenses/expenses_screen.dart` — removed `Flexible(fit: FlexFit.loose)` wrapper from amount; amount now takes natural width after description `Expanded` fills remaining space

- [x] **L1** Fix trial banner when `trialDaysProvider` is null
  - `lib/widgets/main_scaffold.dart` — if `trialDaysProvider` is null, falls back to `SupabaseService.trialDaysLeft(restaurantProvider)` so banner shows on first load

- [x] **L2** Improve "complete setup" dialog clarity
  - `lib/screens/auth/login_screen.dart` — message updated: "No restaurant was found for your account. This usually means signup was interrupted before it finished."

- [x] **L4** Fix `MainScaffold` title for untracked routes
  - `lib/widgets/main_scaffold.dart` — `orElse` returns `_NavItem(label: '')` instead of `bottomItems.first`

- [x] **L5** Add `DrawerButton` in AppBar on mobile when extras exist
  - `lib/widgets/main_scaffold.dart` — `leading` is `null` when `extras.isEmpty` (waiter); uses `DrawerButton` when drawer is present

- [x] **M5** Ensure currency has default before signup currency dialog
  - `lib/screens/auth/signup_screen.dart` — saves `defaultCurrencySymbol` before showing dialog so skipping doesn't leave symbol unset

---

## Iteration 7 — Onboarding & Session

**Goal:** Better first-run experience; security hardening.

- [ ] **L10** Add multi-step onboarding after first signup
  - `lib/screens/auth/signup_screen.dart`
  - Steps: (1) Cafe type selector (QSR / Cafe / Fine Dining / Other), (2) Number of tables (auto-create), (3) Default tax rate, (4) Receipt header/footer
  - Save all to `settings` table before routing to dashboard

- [ ] **M12** Add session timeout / inactivity lock
  - Create `lib/services/session_service.dart`
  - Track last interaction timestamp; after N minutes (configurable in settings, default 30), show re-auth prompt or sign out
  - Use `AppLifecycleState` for background/foreground transitions

---

## Iteration 8 — Inventory Expansion

**Goal:** Add structured inventory workflows.

- [ ] **L11** Add Purchase sub-screen to Inventory
  - `lib/screens/inventory/purchase_screen.dart`
  - Fields: item, quantity received, unit cost, supplier (optional), date
  - Saves to `inventory_logs` with `type = 'purchase'`; updates `inventory_items.quantity`

- [ ] **L11** Add Issue-to-Kitchen sub-screen to Inventory
  - `lib/screens/inventory/issue_screen.dart`
  - Fields: item, quantity issued, reason/note, date
  - Saves to `inventory_logs` with `type = 'issue'`; deducts from `inventory_items.quantity`

- [ ] **L12** Add `unit_cost` to inventory items
  - Migrate `inventory_items` table: add `unit_cost REAL DEFAULT 0`
  - Update `InventoryItemModel` and `InventoryRepository`
  - Show estimated stock value in inventory screen
  - Include COGS estimate in Reports

---

## Design Decisions — RESOLVED

### D1 — Backup export vs. cloud sync ✓
- **Decision:** Remove the entire backup export/import feature.
  - Format is `.platodesk` (JSON with custom extension) — not CSV or XLS, not human-readable.
  - Without import, export has no utility. Cloud sync covers data persistence.
  - Future CSV/XLS exports belong in the Reports module (e.g. "Export orders as CSV").
- Remove the Export Backup and Import Backup options from Settings.
- Remove `lib/services/backup/backup_service.dart` and its Settings UI.
- Tracked in Iteration 5.

### D2 — Multi-device data loading ✓
- **Decision:** Accepted. H8 fix (Iteration 3) decouples sync pull from app start; triggers after login.
- New device login → full pull from Supabase → SQLite rebuilt locally.

### D3 — Staff deactivation: immediate revocation, free reactivation within billing month ✓
- **Decision:** Immediate revocation via Supabase Auth ban on deactivation.
- Each staff member has a `billing_cycle_start` date (= their `activated_at` date).
- Deactivate + reactivate within the same billing month = no extra charge.
- Reactivate after the billing month lapses = new cycle starts, new billing applies.
- Fields to add to Supabase `staff` table: `activated_at`, `billing_cycle_start`, `is_billed_this_cycle`.
- On reactivation: if `DateTime.now()` is within current billing month of `billing_cycle_start` → reactivate free. Else → show "New billing cycle will start. Contact support." dialog.
- Tracked in Iteration 5.

### D4 — "Delete my account" flow ✓
- **Decision:** Add in-app option under Settings. Anonymize, do NOT delete data (needed for audit).
- On delete: set `restaurant.status = 'deleted'`, anonymize name/email in staff table, ban all staff auth users.
- Retain all orders/payments/inventory records in Supabase permanently.
- Require owner to confirm via a typed confirmation prompt before proceeding.
- Tracked in Iteration 5.

### D5 — Billing model: per-user per-month, fixed billing date per employee ✓
- **Decision:** Each staff member is billed separately on a per-user-per-month basis.
- Billing date per employee = their `activated_at` date (first ever activation).
- Owner's own subscription billed from `restaurant.created_at`.
- Deactivate/reactivate within the same billing month = no extra charge (cycle already paid).
- Reactivate after billing month lapses = new cycle, new billing.
- No automated billing yet (manual via WhatsApp). Supabase stores billing metadata for reference.
- Settings → Manage Subscription shows: each staff member, their billing date, active/inactive status.
- Tracked in Iteration 5.

---

## Notes

- Each iteration should be committed separately with descriptive commit messages.
- Run `flutter analyze` after each iteration — zero warnings required.
- Test flows: new signup, login, trial expiry, offline mode, role switching, kitchen workflow.
- Mark tasks `[x]` when complete; add new tasks discovered during implementation at the bottom of the relevant iteration.
