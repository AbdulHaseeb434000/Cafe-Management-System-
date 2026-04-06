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

- [x] **L10** Add multi-step onboarding after first signup
  - `lib/screens/auth/signup_screen.dart` — `_showOnboardingDialog()` inserted between currency dialog and trial dialog
  - 4 steps: (1) Café type radio selector, (2) Table count picker with auto-create, (3) Tax rate, (4) Receipt header/footer
  - Settings saved via `settingsNotifierProvider.setAll()`; tables created via `tablesProvider.notifier.add()`

- [x] **M12** Add session timeout / inactivity lock
  - Created `lib/services/session_service.dart` — singleton tracking last activity; `timeout` duration updated from settings
  - `lib/core/constants/app_constants.dart` — added `settingSessionTimeout`, `settingCafeType`, `defaultSessionTimeoutMinutes = 30`
  - `lib/widgets/main_scaffold.dart` — `GestureDetector` wraps body to call `touch()` on tap/drag; `didChangeAppLifecycleState.resumed` calls `_checkSessionTimeout()` → auto-signs-out and shows snackbar
  - `lib/providers/auth_providers.dart` — `signOutAndClear` and `signOutAndClearNoRef` both call `SessionService.instance.clear()`
  - `lib/screens/auth/login_screen.dart` and `signup_screen.dart` — call `SessionService.instance.touch()` on successful auth/navigation

---

## Iteration 8 — Inventory Expansion

**Goal:** Add structured inventory workflows.

- [x] **L11** Add Purchase sub-screen to Inventory
  - `lib/screens/inventory/purchase_screen.dart`
  - Fields: item dropdown, quantity received, unit cost, supplier/note
  - Saves to `inventory_logs` with `type = 'purchase'`; updates `inventory_items.quantity` and `unit_cost`

- [x] **L11** Add Issue-to-Kitchen sub-screen to Inventory
  - `lib/screens/inventory/issue_screen.dart`
  - Fields: item dropdown (shows available qty), quantity issued, reason/note
  - Saves to `inventory_logs` with `type = 'issue'`; deducts from `inventory_items.quantity`
  - Guards against issuing more than available stock

- [x] **L12** Add `unit_cost` to inventory items
  - DB v9 migration: `unit_cost` on `inventory_items`; `type` + `unit_cost` on `inventory_logs`
  - `InventoryItemModel` — added `unitCost`, `stockValue` getter
  - `InventoryLogModel` — added `type` (default `'adjustment'`), `unitCost`, `totalCost` getter
  - `InventoryRepository` — `purchase()`, `issue()`, `getPurchaseCostForPeriod()` methods
  - `InventoryScreen` — stock value summary bar + Purchase/Issue AppBar buttons; log tile shows type label
  - `ReportsScreen` P&L — added COGS (Inventory Purchases) row deducted from Net Profit

---

## Iteration 9 — Subscription Payment System

**Goal:** Replace manual WhatsApp billing with in-app payment. Pakistan: Easypaisa, JazzCash, Card. International: Card only.

### Flutter tasks (Claude implements)

- [ ] **P1** Add `country` field to signup flow and `SubscriptionPaymentModel`
  - `lib/screens/auth/signup_screen.dart` — add country dropdown (default `PK`) to step 1 of onboarding; save to Supabase `restaurants.country`
  - `lib/models/subscription_payment_model.dart` — new model: id, restaurantId, plan, amount, currency, paymentMethod, gateway, gatewayReference, status, createdAt, paidAt

- [ ] **P2** Add `PaymentService` abstraction + Safepay + Stripe implementations
  - `lib/services/payment/payment_service.dart` — abstract interface with `initiatePayment()` and `verifyPayment()`
  - `lib/services/payment/safepay_service.dart` — calls Supabase Edge Function `create-safepay-order` → returns hosted checkout URL
  - `lib/services/payment/stripe_service.dart` — calls Supabase Edge Function `create-stripe-intent` → returns `client_secret`
  - `lib/services/payment/payment_factory.dart` — reads `restaurant.country`; returns `SafepayService` for `'PK'`, `StripeService` otherwise

- [ ] **P3** Build `SubscriptionScreen` (replaces current WhatsApp-only Manage Subscription)
  - `lib/screens/subscription/subscription_screen.dart`
  - Shows: current plan badge, renewal date, price, "Upgrade / Renew" button
  - Reads from `restaurantProvider`; navigates to `PaymentMethodScreen`

- [ ] **P4** Build `PaymentMethodScreen`
  - `lib/screens/subscription/payment_method_screen.dart`
  - Pakistan (`country == 'PK'`): shows 3 tiles — Easypaisa, JazzCash, Card
  - International: shows Card tile only
  - Each tile shows logo icon + label + tap → initiates payment

- [ ] **P5** Build `SafepayWebviewScreen` (Pakistan checkout)
  - `lib/screens/subscription/safepay_webview_screen.dart`
  - Opens Safepay hosted checkout URL in `webview_flutter`
  - Intercepts redirect URLs: `platodesk://payment/success` and `platodesk://payment/cancel`
  - On success: shows loader while polling Supabase for updated `plan` field; refreshes `restaurantProvider`

- [ ] **P6** Build `StripePaymentScreen` (international card)
  - `lib/screens/subscription/stripe_payment_screen.dart`
  - Uses `flutter_stripe` payment sheet: `Stripe.instance.initPaymentSheet()` + `presentPaymentSheet()`
  - On success: refreshes `restaurantProvider`

- [ ] **P7** Wire into Settings and PaywallScreen
  - `lib/screens/settings/settings_screen.dart` — "Manage Subscription" ListTile navigates to `SubscriptionScreen` instead of launching WhatsApp
  - `lib/screens/auth/paywall_screen.dart` — "Subscribe Now" button navigates to `SubscriptionScreen`

- [ ] **P8** Update `plan_constants.dart` with international USD pricing
  - Add `priceUsd` to `PlanInfo`; show PKR when `country == 'PK'`, USD otherwise

- [ ] **P9** Add `pubspec.yaml` dependencies
  - `flutter_stripe: ^10.2.0` — Stripe native card sheet
  - `webview_flutter: ^4.8.0` — Safepay hosted checkout

### Your tasks (must be done before Claude can wire up P2–P6)

- [ ] **YOUR-1** Create a [Safepay merchant account](https://getsafepay.com) → get `API_KEY` and `SECRET_KEY`
  - Safepay supports Easypaisa, JazzCash, and Visa/MC in one checkout — no separate integrations needed
  - Set allowed redirect URLs: `platodesk://payment/success` and `platodesk://payment/cancel`

- [ ] **YOUR-2** Create a [Stripe account](https://stripe.com) → get `STRIPE_PUBLISHABLE_KEY` and `STRIPE_SECRET_KEY`
  - Enable "Card" payment method in the Stripe Dashboard → Payment Methods

- [ ] **YOUR-3** Run this SQL in Supabase → SQL Editor:
  ```sql
  -- Country and subscription status on restaurants
  ALTER TABLE restaurants ADD COLUMN IF NOT EXISTS country TEXT NOT NULL DEFAULT 'PK';
  ALTER TABLE restaurants ADD COLUMN IF NOT EXISTS subscription_status TEXT NOT NULL DEFAULT 'trial';
  ALTER TABLE restaurants ADD COLUMN IF NOT EXISTS subscription_renewed_at TIMESTAMPTZ;

  -- Payment history
  CREATE TABLE IF NOT EXISTS subscription_payments (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    restaurant_id UUID NOT NULL REFERENCES restaurants(id),
    plan         TEXT NOT NULL,
    amount       NUMERIC(10,2) NOT NULL,
    currency     TEXT NOT NULL DEFAULT 'PKR',
    payment_method TEXT NOT NULL,   -- easypaisa | jazzcash | card
    gateway      TEXT NOT NULL,     -- safepay | stripe
    gateway_reference TEXT,
    status       TEXT NOT NULL DEFAULT 'pending', -- pending | paid | failed | refunded
    created_at   TIMESTAMPTZ DEFAULT now(),
    paid_at      TIMESTAMPTZ
  );

  -- Staff billing metadata
  ALTER TABLE staff ADD COLUMN IF NOT EXISTS activated_at TIMESTAMPTZ;
  ALTER TABLE staff ADD COLUMN IF NOT EXISTS billing_cycle_start TIMESTAMPTZ;
  ALTER TABLE staff ADD COLUMN IF NOT EXISTS is_billed_this_cycle BOOLEAN DEFAULT false;
  ```

- [ ] **YOUR-4** Deploy 2 Supabase Edge Functions (Claude will write the code):
  - `create-safepay-order` — creates a Safepay order, returns hosted checkout URL
  - `create-stripe-intent` — creates a Stripe PaymentIntent, returns `client_secret`
  - `stripe-webhook` — marks payment paid + updates `restaurants.plan` on `payment_intent.succeeded`
  - `safepay-webhook` — marks payment paid + updates `restaurants.plan` on Safepay callback

- [ ] **YOUR-5** Set Edge Function secrets in Supabase Dashboard → Project Settings → Edge Functions:
  - `SAFEPAY_API_KEY`, `SAFEPAY_SECRET_KEY`
  - `STRIPE_SECRET_KEY`
  - `STRIPE_WEBHOOK_SECRET` (from Stripe Dashboard → Webhooks)

- [ ] **YOUR-6** Pass Stripe publishable key to Flutter build:
  ```bash
  flutter run --dart-define=STRIPE_PUBLISHABLE_KEY=pk_live_xxx
  ```

---

## Iteration 10 — Account Management & Staff Billing

**Goal:** Implement staff billing lifecycle (D3/D5) and account deletion (D4).

- [ ] **D3a** Staff reactivation billing guard
  - `lib/screens/staff/staff_screen.dart` — on reactivate: check `billing_cycle_start`; if within same month → free; else → show "New billing cycle starts. Contact support." dialog
  - `lib/services/supabase/supabase_service.dart` — `reactivateStaff()` sets `activated_at` on first activation; leaves `billing_cycle_start` if within same month

- [ ] **D5a** Billing dashboard in Manage Subscription
  - `lib/screens/subscription/subscription_screen.dart` — add staff billing section: list each staff member, their `billing_cycle_start`, status (active/inactive), charge amount

- [ ] **D4** "Delete My Account" flow
  - `lib/screens/settings/settings_screen.dart` — add "Delete Account" option (owner-only, bottom of Settings, red color)
  - Typed confirmation dialog: owner must type their restaurant name to confirm
  - Calls `SupabaseService.deleteAccount()` which sets `restaurant.status = 'deleted'`, anonymizes name/email, bans all staff auth users
  - Signs out locally after completion

---

## Iteration 11 — Sync & Reports Polish

**Goal:** Sync new fields; add CSV export.

- [ ] **S1** Update `SyncService` push/pull for inventory `unit_cost` + `type` columns
  - `lib/services/sync/sync_service.dart` — ensure `unit_cost` and `type` are included in `inventory_items` and `inventory_logs` payloads

- [ ] **S2** Update `SyncService` for `restaurants.country` and `subscription_status`
  - Refresh `restaurantProvider` after any subscription payment

- [ ] **R1** CSV export from Reports
  - Reports screen → overflow menu → "Export as CSV"
  - Exports the currently visible report table to a `.csv` file via `share_plus`

- [ ] **R2** Session timeout settings UI
  - `lib/screens/settings/settings_screen.dart` — slider/dropdown for session timeout: 5, 10, 15, 30, 60 min, Never
  - Saves to `settingSessionTimeout`; `SessionService.instance.timeout` updated immediately

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
