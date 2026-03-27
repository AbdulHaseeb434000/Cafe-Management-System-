# CafeDesk — Flutter Cafe Management System

> Fully offline Flutter Android app for cafes and restaurants.
> No internet required. SQLite local storage. Warm cream/amber theme.

---

## Tech Stack

| Layer | Package |
|---|---|
| Database | `sqflite` + `path` |
| State Management | `flutter_riverpod` |
| Navigation | `go_router` |
| PDF Generation | `pdf` + `printing` |
| Thermal Printing | `esc_pos_utils_plus` + `print_bluetooth_thermal` |
| Responsive UI | `flutter_screenutil` |
| Charts | `fl_chart` |
| Formatting | `intl` |
| Fonts | `google_fonts` (Poppins) |
| Unique IDs | `uuid` |
| File Picking | `file_picker` |
| File Sharing | `share_plus` |
| File System | `path_provider` |
| Permissions | `permission_handler` |

---

## Project Structure

```
lib/
├── main.dart
├── app.dart
├── core/
│   ├── theme/            # AppColors, AppTheme
│   ├── database/         # DatabaseHelper (SQLite)
│   ├── constants/        # AppConstants
│   └── utils/            # CurrencyFormatter, DateHelpers
├── models/               # Pure Dart data models
├── repositories/         # DB CRUD per module
├── providers/            # Riverpod providers
├── services/
│   └── backup/           # BackupService (export + import)
├── screens/
│   ├── dashboard/
│   ├── menu/
│   ├── orders/
│   ├── tables/
│   ├── billing/
│   ├── kitchen/
│   ├── inventory/
│   ├── reports/
│   └── settings/
└── widgets/              # Shared components (MainScaffold, etc.)
```

---

## Database Schema

Every table (except `settings`) carries two identity fields:
- **`id` INTEGER PRIMARY KEY AUTOINCREMENT** — local FK joins (fast, indexed)
- **`uuid` TEXT UNIQUE NOT NULL** — stable global deduplication key for backup/restore

FK columns store both the local `_id` (for joins) **and** the `_uuid` (for cross-device restore resolution).

```
categories        id · uuid · name · icon · sort_order · created_at

menu_items        id · uuid · category_id · category_uuid
                  name · price · description · is_available · image_path · created_at

cafe_tables       id · uuid · name · capacity · status

customers         id · uuid · name · phone · address · created_at

orders            id · uuid · type · table_id · table_uuid
                  customer_id · customer_uuid · delivery_address · status
                  discount_type · discount_value · tax_percent
                  subtotal · discount_amount · tax_amount · total
                  note · created_at · completed_at

order_items       id · uuid · order_id · order_uuid
                  menu_item_id · menu_item_uuid
                  name_snapshot · price_snapshot · quantity · note

payments          id · uuid · order_id · order_uuid
                  method · amount_tendered · change_amount · paid_at

inventory_items   id · uuid · name · unit · quantity · low_stock_threshold · updated_at

inventory_logs    id · uuid · inventory_item_id · inventory_item_uuid
                  change_amount · reason · created_at

settings          key (PK) · value
```

---

## Order Types

| Type | Required | Badge Color |
|---|---|---|
| Dine-In | Table selection | Amber |
| Takeaway | Nothing (customer optional) | Brown |
| Delivery | Customer name + phone + address | Teal |

**Workflow:**
- Dine-In: Select table → Add items → Send to kitchen → Bill → Pay
- Takeaway: Add items → Send to kitchen → Bill → Pay at counter
- Delivery: Fill customer form → Add items → Send to kitchen → Bill → Mark delivered

---

## Modules

### 1 · Dashboard
- Today's revenue, order count, avg order value
- Active orders by type
- Tables overview grid
- Low stock alerts
- Quick actions: New Order, View Kitchen

### 2 · Menu Management
- Categories with icons + drag-to-reorder
- Items per category: name, price, description, availability toggle
- Add / edit / delete categories and items

### 3 · Tables
- Visual table grid
- Status colors: green (free) · red (occupied) · yellow (reserved)
- Tap → open active order or create new dine-in

### 4 · Order Taking
- Order type selector at creation
- Menu browser by category + search
- Cart with quantity, item notes, order note
- Send to Kitchen → prints kitchen ticket via Bluetooth

### 5 · Kitchen
- Kitchen ticket print (Bluetooth thermal):
  - Order #, type badge, table/customer name, items + notes, timestamp
- On-screen order queue
- Mark orders: Preparing → Ready

### 6 · Billing & POS
- Order summary, discount (flat/%), tax
- Cash (shows change) or card payment
- PDF receipt — save or print via Bluetooth

### 7 · Inventory
- Stock items: name, unit, qty, low-stock threshold
- Manual adjustment with reason + log history
- Low stock highlighted + dashboard alert

### 8 · Reports
- Date range: today / week / month / custom
- Revenue summary, top 10 items (bar), type split (pie), daily trend (line)
- Export as PDF

### 9 · Settings
- Cafe info, tax %, receipt header/footer
- Bluetooth printer pairing (POS + kitchen)
- Table management
- **Backup & Restore** ← see section below

---

## Backup & Restore

### Export
1. Tap **Export Backup** in Settings
2. App dumps all tables to a single `.cafedesk` JSON file
3. Android share sheet opens — user saves to **Google Drive, email, WhatsApp, local storage**, etc.

**File format:**
```json
{
  "meta": {
    "version": 1,
    "app_version": "1.0.0",
    "exported_at": "2025-03-27T10:00:00Z",
    "device": "Samsung Galaxy A54"
  },
  "data": {
    "categories":       [...],
    "menu_items":       [...],
    "cafe_tables":      [...],
    "customers":        [...],
    "orders":           [...],
    "order_items":      [...],
    "payments":         [...],
    "inventory_items":  [...],
    "inventory_logs":   [...],
    "settings":         [...]
  }
}
```

### Import
1. Tap **Import Backup** → file picker opens (Google Drive, local, email attachment)
2. App validates file and shows a **Restore Preview**:
   - Backup date & source device
   - Record counts per table
   - Conflict summary: "X new · Y already exist (will be skipped)"
3. User picks restore mode:

| Mode | Behaviour |
|---|---|
| **Merge** (default) | Non-destructive. Adds missing records, skips existing ones by uuid. |
| **Full Replace** | Wipes all data, loads backup entirely. Requires confirmation. |

### Deduplication (Merge mode)

All deduplication is keyed on `uuid` — never on `id`.

| Table | Strategy |
|---|---|
| `categories` | INSERT OR IGNORE by uuid |
| `menu_items` | INSERT OR IGNORE by uuid |
| `cafe_tables` | INSERT OR IGNORE by uuid |
| `customers` | INSERT OR IGNORE by uuid |
| `orders` | INSERT OR IGNORE by uuid (order history is immutable) |
| `order_items` | INSERT OR IGNORE by uuid |
| `payments` | INSERT OR IGNORE by uuid |
| `inventory_items` | INSERT OR REPLACE by uuid (latest stock levels win) |
| `inventory_logs` | INSERT OR IGNORE by uuid |
| `settings` | INSERT OR IGNORE by key (local settings take priority) |

**FK re-resolution on import:**
After inserting, all FK `_id` columns are re-resolved by looking up `id WHERE uuid = _uuid` on the target table.
Insert order follows FK dependency chain:
```
categories → menu_items → cafe_tables → customers
→ orders → order_items → payments
→ inventory_items → inventory_logs
```

---

## UI / UX

| Property | Value |
|---|---|
| Background | `#FFF8F0` cream |
| Primary | `#FFB300` amber |
| Primary Dark | `#5D4037` brown |
| Surface | `#FFFFFF` |
| Error | `#D32F2F` |
| Font | Poppins (via google_fonts) |
| Mobile nav | Bottom navigation bar (5 tabs + drawer) |
| Tablet nav | Navigation rail (all items visible) |

---

## Build Phases

| Phase | Status | Deliverable |
|---|---|---|
| 1 | ✅ Done | Scaffold · theme · DB + uuid · models · navigation |
| 2 | ⏳ Next | Menu management (categories + items CRUD) |
| 3 | — | Tables management + visual grid |
| 4 | — | Order taking (all 3 types) |
| 5 | — | Kitchen ticket print + queue |
| 6 | — | Billing · payments · PDF receipt |
| 7 | — | Bluetooth thermal printer integration |
| 8 | — | Inventory module |
| 9 | — | Reports + charts |
| 10 | — | Settings + **Backup & Restore** |
| 11 | — | Dashboard live stats |
| 12 | — | Responsiveness polish |

---

## Codemagic CI/CD (`codemagic.yaml`)

| Workflow | Trigger | Output |
|---|---|---|
| `android-release` | push to `main`, `release/*` | Signed APK + AAB |
| `android-debug` | push to `claude/*`, `develop` | Debug APK |

Signing via env vars: `KEY_STORE_PATH`, `KEY_STORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`.

---

## Verification

- `flutter analyze` — zero errors
- `flutter test` — models, repositories, BackupService
- `flutter build apk --release`
- Backup round-trip test:
  1. Add data → Export backup
  2. Clear / reinstall → Import backup → verify all data + FK links
  3. Import same backup again → verify zero duplicates in Merge mode
- Responsive test: 360dp phone + 600dp+ tablet
