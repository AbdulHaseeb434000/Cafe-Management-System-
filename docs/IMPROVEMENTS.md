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

- [ ] **H4** Replace `signOutAndClearNoRef()` with `signOutAndClear(ref)` in `LoginScreen`
  - `lib/screens/auth/login_screen.dart:230`

- [ ] **H5** Reset `syncNotifier` in both sign-out functions
  - `lib/providers/auth_providers.dart` — set `syncNotifier.value = SyncStatus.idle`

- [ ] **H3** Add offline restaurant fallback in `LoginScreen._submit()`
  - `lib/screens/auth/login_screen.dart`
  - Load from `settings` table cache if `fetchRestaurant()` returns null

- [ ] **M6** Fix stale `isSignedIn` check
  - Replace `SupabaseService.isSignedIn` with `Supabase.instance.client.auth.currentSession != null`

- [ ] **M3** Sanitize exception messages shown to users
  - Map `AuthException` error codes to user-friendly strings in both `login_screen.dart` and `signup_screen.dart`
  - Generic fallback: "Something went wrong. Please try again."

- [ ] **M4** Handle orphaned auth account after failed `createRestaurant()`
  - `lib/screens/auth/signup_screen.dart`
  - On failure: call `SupabaseService.signOut()` + show "Setup failed — please try again" with retry button

- [ ] **H8** Trigger full data pull explicitly after login/signup
  - `lib/services/sync/sync_service.dart`
  - Add `SyncService.instance.pullAll()` call at end of successful login and signup flows
  - Remove or guard the startup call that runs before auth

- [ ] **M11** Add "Remember Me" checkbox on login screen
  - `lib/screens/auth/login_screen.dart`
  - Add `flutter_secure_storage` dependency
  - If checked: save email + encrypted password; load on startup into form fields
  - If unchecked: clear saved credentials

---

## Iteration 4 — Kitchen & Order Integrity

**Goal:** Fix kitchen workflow and order-edit notification gaps.

- [ ] **H6** Notify kitchen when an order is edited after ticket is printed
  - `lib/screens/orders/edit_order_screen.dart`
  - After saving edits, if order status is `preparing` or `ready`, set a new `needs_reprint` flag (add to orders table or use a note field)
  - `lib/screens/kitchen/kitchen_screen.dart` — show a red "Updated" badge on the order card when `needs_reprint = true`
  - Clear `needs_reprint` flag when kitchen prints new ticket

- [ ] **H7** Restrict Edit button in `OrderDetailScreen` for kitchen role
  - `lib/screens/orders/order_detail_screen.dart`
  - Hide / disable Edit action when `staffRoleProvider == 'kitchen'`

- [ ] **M13** Verify receipt footer is printed correctly
  - `lib/screens/billing/billing_screen.dart` + `lib/services/pdf/pdf_receipt_service.dart`
  - Log the `settings` map passed to `buildReceipt()` in debug mode
  - Confirm `AppConstants.settingReceiptFooter` key matches what is saved in `settings` table

---

## Iteration 5 — Subscription, Paywall & Staff Billing

**Goal:** Make upgrade path functional; address billing design gaps.

- [ ] **M1** Add functional contact links to `PaywallScreen`
  - `lib/screens/auth/paywall_screen.dart`
  - Add `url_launcher`: WhatsApp deep link + mailto with pre-filled subject ("Upgrade to [Plan] — [Restaurant Name]")
  - Replace static email text with tappable widget

- [ ] **M2** Extract plan definitions to constants file
  - Create `lib/core/constants/plan_constants.dart`
  - Move `_plans` list; comment: "Update pricing here before releasing a new version"

- [ ] **M8** Add "Manage Subscription" section in Settings
  - `lib/screens/settings/settings_screen.dart`
  - Show current plan + expiry/renewal date
  - Add "Cancel / Change Plan" link (opens WhatsApp or mailto)

- [ ] **M9** Enforce staff deactivation server-side
  - `lib/services/supabase/supabase_service.dart`
  - On deactivate: set `is_active = false` in Supabase `staff` table
  - Add a Supabase RLS policy or Edge Function that rejects API calls from staff where `is_active = false`
  - Document that JWT tokens expire after Supabase's configured expiry (default 1 hour); deactivated staff will lose access within that window

- [ ] **M10** Add staff-add billing warning dialog
  - `lib/screens/staff/staff_screen.dart`
  - Before adding new staff: show dialog "Adding a staff member may affect your subscription billing. Contact support to confirm your current plan limits."
  - Log addition with timestamp in `activity_log`

- [ ] **L3** Remove hardcoded "Rs." from signup trial dialog
  - `lib/screens/auth/signup_screen.dart:187`
  - Remove price mention; replace with "Contact support@platodesk.app for pricing details"

---

## Iteration 6 — UI/UX Fixes

**Goal:** Fix visual bugs and confusing messages.

- [ ] **L14** Add logout button to `MainScaffold` AppBar
  - `lib/widgets/main_scaffold.dart`
  - Add `IconButton(Icons.logout)` in `AppBar.actions` for all roles
  - Confirm dialog before signing out

- [ ] **L6** Fix currency default and update everywhere
  - `lib/core/constants/app_constants.dart` — set `defaultCurrencySymbol = '\$'`
  - Audit all hardcoded `'Rs.'` strings across all screens — replace with currency from settings
  - Ensure `CurrencyFormatter` reads from `settingsProvider` so changes propagate immediately

- [ ] **L7** Fix "no tables" message distinction
  - `lib/screens/orders/new_order_screen.dart`
  - When `allTables.isEmpty`: "No tables added yet" + button to go to Settings → Tables
  - When `allTables.isNotEmpty && freeTables.isEmpty`: "No free tables available" (current)

- [ ] **L8** Remove example placeholder text from input fields
  - Audit all `hintText` values containing `'e.g.'` or specific names/amounts
  - Replace with generic descriptors: `'Customer name'`, `'Amount'`, `'Phone number'`

- [ ] **L13** Fix expense list item text overlap
  - `lib/screens/expenses/expenses_screen.dart:209`
  - Give description `Expanded` with `overflow: ellipsis`; give amount `constraints: BoxConstraints(minWidth: 80)`

- [ ] **L1** Fix trial banner when `trialDaysProvider` is null
  - `lib/widgets/main_scaffold.dart:67`
  - Fall back to computing days from `restaurantProvider` if `trialDaysProvider` is null

- [ ] **L2** Improve "complete setup" dialog clarity
  - `lib/screens/auth/login_screen.dart:148`
  - Detect whether restaurant row or staff row is missing; show specific instructions

- [ ] **L4** Fix `MainScaffold` title for untracked routes
  - Return `''` instead of falling back to first nav item

- [ ] **L5** Add `DrawerButton` in AppBar on mobile when extras exist
  - `lib/widgets/main_scaffold.dart`

- [ ] **M5** Ensure currency has default before signup currency dialog
  - `lib/screens/auth/signup_screen.dart`
  - Save `currency_symbol = '\$'` before showing picker; update to selection after

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
