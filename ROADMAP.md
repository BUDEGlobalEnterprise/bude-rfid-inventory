# Bude RFID Inventory — Roadmap

Enterprise inventory management platform built on ERPNext, Frappe, and Flutter, delivering barcode and RFID-driven inventory visibility through standard ERPNext workflows.

---

## Legend

| Badge | Meaning |
|-------|---------|
| ✅ Done | Shipped and on `main` |
| 🔄 In Progress | Active development |
| 🔲 Planned | Scoped, not yet started |
| 💡 Idea | Under consideration, not formally scoped |

---

## Phase 1 — Core Inventory Workflows ✅

Foundation: authentication, item lookup, barcode scanning, stock operations, and offline sync.

| Area | Feature | Status |
|------|---------|--------|
| **Backend** | `bude_api` Frappe app skeleton — whitelist decorator, `success`/`failure` envelope | ✅ |
| **Backend** | `auth.login` / `auth.session_info` — API key auth, session dict | ✅ |
| **Backend** | `items.search`, `items.get_by_barcode`, `items.get_stock` | ✅ |
| **Backend** | `warehouses.list` | ✅ |
| **Backend** | `stock.create_transfer`, `stock.create_receipt`, `stock.create_reconciliation` | ✅ |
| **Backend** | `purchase_orders.list_open` | ✅ |
| **Backend** | `health.ping` (version endpoint) | ✅ |
| **Mobile** | Onboarding — company URL setup, connection probe | ✅ |
| **Mobile** | Login screen + JWT / API-key session management | ✅ |
| **Mobile** | Item search + item detail (stock by warehouse) | ✅ |
| **Mobile** | Camera barcode scanner (`mobile_scanner`, `CameraBarcodeAdapter`) | ✅ |
| **Mobile** | Stock transfer screen (warehouse → warehouse) | ✅ |
| **Mobile** | Goods receipt screen (against PO or free) | ✅ |
| **Mobile** | Stock reconciliation / count screen | ✅ |
| **Mobile** | Offline-first sync queue (Hive) + `SyncEngine` + `PendingQueueScreen` | ✅ |
| **Mobile** | Hardware Abstraction Layer (HAL) — `BarcodeAdapter`, `RfidAdapter`, `DeviceAdapter` interfaces | ✅ |
| **Mobile** | `AndroidDeviceProbe` via `bude.hardware/probe` method channel | ✅ |
| **Mobile** | Vendor stubs: Chainway, Zebra, Urovo, Honeywell, GenericUHF | ✅ |
| **Mobile** | Animated splash, polished nav cards, branding (logo, company name) | ✅ |
| **Infra** | CI/CD skeleton (GitHub Actions) | ✅ |

---

## Phase 2 — Enterprise Foundation ✅

Design system, internationalisation, settings architecture, and dashboard intelligence.

| Area | Feature | Status |
|------|---------|--------|
| **Backend** | `branding.get` — feature flags from installed apps (`transfer`, `receipt`, `reconciliation`) | ✅ |
| **Mobile** | Design token system — `AppColors`, `AppSpacing`, `AppRadius`, `AppTypography` (Inter) | ✅ |
| **Mobile** | Material 3 light / dark / system theme — `AppTheme.light()` / `AppTheme.dark()` | ✅ |
| **Mobile** | `themeModeProvider` + `localeProvider` derived from `SettingsNotifier` | ✅ |
| **Mobile** | i18n foundation — `flutter_localizations`, English + Arabic ARBs (80+ keys) | ✅ |
| **Mobile** | RTL layout via `Locale('ar')` — automatic direction flip | ✅ |
| **Mobile** | `AppSettings` model expanded to 13 typed fields (theme, locale, scan behaviour, sync, defaults, auto-logout) | ✅ |
| **Mobile** | `SettingsNotifier` with typed mutators; `SharedPreferences` persistence | ✅ |
| **Mobile** | Settings screen redesigned — 6 sections (Appearance, Connection, Defaults, Scanning, Sync & Offline, Account) | ✅ |
| **Mobile** | `OfflineBanner` — animated, driven by `connectivityProvider` | ✅ |
| **Mobile** | `SyncStatusIndicator` — AppBar chip with live pending count, taps to `/sync` | ✅ |
| **Mobile** | `EmptyStateView`, `ShimmerList`, `BudeSectionHeader` core UI components | ✅ |
| **Mobile** | Dashboard — offline banner, adaptive 2→3 column grid (≥600 dp), feature-flag gated cards, recently-used chip row | ✅ |
| **Mobile** | `Branding.featureFlags` field — disables nav cards when ERPNext feature is unavailable | ✅ |

---

## Phase 3 — Operational Intelligence ✅

Item movement history, warehouse overview, and bulk multi-item scan sessions.

| Area | Feature | Status |
|------|---------|--------|
| **Backend** | `items.get_ledger` — Stock Ledger Entry history, newest-first, optional warehouse, limit 1–200 | ✅ |
| **Backend** | `warehouses.get_stock` — Bin rows per warehouse (actual / reserved / projected qty), limit 1–500 | ✅ |
| **Mobile** | `StockLedgerEntry` entity + model, `getLedger` on `ItemRepository` | ✅ |
| **Mobile** | `ItemDetailScreen` — tab controller: **Stock** tab (existing) + **History** tab (ledger timeline grouped by date, +/− colour) | ✅ |
| **Mobile** | `WarehouseStockLine` entity + model, `WarehouseRepository` + `WarehouseRemoteDataSourceImpl` | ✅ |
| **Mobile** | `WarehouseListScreen` (`/warehouses`) — shimmer, empty state, tap to detail | ✅ |
| **Mobile** | `WarehouseDetailScreen` (`/warehouse/:name`) — stock lines with actual / reserved quantities, item count header | ✅ |
| **Mobile** | Warehouses nav card on dashboard | ✅ |
| **Mobile** | `ScannedItem` value object, `ScanSessionMode` enum (`transfer \| receipt \| reconcile`) | ✅ |
| **Mobile** | `CameraPreviewAdapter` interface; `CameraBarcodeAdapter` implements it via `buildPreview()` | ✅ |
| **Mobile** | `ScanSessionScreen` (`/scan-session?mode=`) — continuous scan stream, duplicate-bump, qty editing, live camera viewfinder, "Use N items" FAB | ✅ |
| **Mobile** | Transfer / Receipt / Reconciliation — replaced single-shot scan with `_startScanSession`; reconciliation pre-fetches `expectedQty` for all items via `Future.wait` | ✅ |
| **Router** | 15 routes total — added `/warehouses`, `/warehouse/:name`, `/scan-session` | ✅ |

---

## Phase 4 — RFID Hardware Integration 🔲

Activate real vendor SDKs behind the existing HAL interfaces. Each vendor is an independent, self-contained task.

| Vendor | Adapter | Devices | Status |
|--------|---------|---------|--------|
| **Chainway** | `ChainwayBarcodeAdapter` + `ChainwayRfidAdapter` | C72, C66, R6 | 🔲 |
| **Zebra** | `ZebraBarcodeAdapter` + `ZebraRfidAdapter` | TC-series + RFD40 / RFID8500 sled | 🔲 |
| **Urovo** | `UrovoBarcodeAdapter` + `UrovoRfidAdapter` | DT40 RFID, i9000s | 🔲 |
| **Honeywell** | `HoneywellBarcodeAdapter` | CT40, EDA52, EDA61k | 🔲 |
| **Generic UHF** | `GenericUhfRfidAdapter` | BLE / USB / LLRP readers | 🔲 |

**Deliverables per vendor**
- Replace stub `throw VendorSdkUnavailableException()` bodies with real SDK calls
- Add `DeviceProbe` detection (model string, package query, or method-channel ping)
- Integration test harness against device emulator or physical unit
- Update `documentation/hardware-roadmap/integration-roadmap.md`

---

## Phase 5 — Analytics & Reporting ✅

KPI dashboards, variance analysis, and data export.

| Feature | Description | Status |
|---------|-------------|--------|
| **Stock aging report** | Items idle for N days per warehouse; threshold picker (7/14/30/60/90 d); sorted by days idle | ✅ |
| **Variance dashboard** | Submitted reconciliation history — counted vs expected per line, colour-coded surplus/deficit, expandable cards | ✅ |
| **Transfer throughput** | Ops per day from local Hive queue; stacked `fl_chart` bar chart; 7/14/30-day period picker | ✅ |
| **Export to CSV** | Warehouse stock or item ledger as `.csv` via system share sheet (`share_plus`) | ✅ |
| **Pull-to-refresh** | `RefreshIndicator` on warehouse list, warehouse detail, and item history tab | ✅ |

**Backend** — `analytics.get_stock_aging`, `analytics.get_reconciliation_history` (standard ERPNext DocTypes, 9 pytest tests)

**New packages** — `fl_chart ^0.69.0`, `share_plus ^10.0.0`, `csv ^6.0.0`, `path_provider ^2.1.4`

---

## Phase 6 — Role-Based Access & Multi-Entity ✅

Enterprise controls for multi-site, multi-company deployments.

| Feature | Description | Status |
|---------|-------------|--------|
| **Role-scoped screens** | Hide or disable screens based on ERPNext user roles (`Stock Manager`, `Stock User`) | 🔲 |
| **Per-user default warehouse** | Pull `default_warehouse` from ERPNext User doc, pre-fill dropdowns | 🔲 |
| **Multi-company switcher** | Select active company from a list; scope all operations to that company | 🔲 |
| **Supervisor approval flow** | Large-variance reconciliations require a second user to approve before queuing | 🔲 |
| **Audit trail screen** | List all submitted ops by this device, with ERPNext doc link | 🔲 |
| **Biometric auto-login** | Face ID / fingerprint re-auth after auto-logout timer fires | 🔲 |

---

## Phase 7 — Additional ERP Connectors 💡

`erpnext_client.py` is the first `ErpClient` implementation. Each new connector lives alongside it and conforms to the same interface; the mobile app is unaware.

| Connector | Status |
|-----------|--------|
| ERPNext / Frappe | ✅ Shipped |
| Zoho Inventory | 💡 |
| SAP Business One (Service Layer) | 💡 |
| NetSuite (SuiteQL REST) | 💡 |
| Microsoft Dynamics 365 Business Central | 💡 |

---

## Phase 8 — Power-User Experience 💡

Quality-of-life features for high-throughput warehouse operators.

| Feature | Description |
|---------|-------------|
| **Command palette** | Keyboard / search shortcut (`⌘K` or swipe) to jump to any screen or barcode | 💡 |
| **Drag-and-drop dashboard** | Operator can re-order, pin, or hide nav cards | 💡 |
| **Print labels** | Generate ZPL / PDF label for a scanned item or bin | 💡 |
| **Batch RFID inventory** | Continuous UHF tag reads → auto-populate reconciliation list | 💡 |
| **Push notifications** | Server-side webhook → FCM/APNs for low-stock alerts or PO arrivals | 💡 |
| **Plugin marketplace** | Third-party bude_api modules discoverable and installable from the app | 💡 |

---

## Architecture Constraints

- **No custom DocTypes** — every read/write uses standard ERPNext DocTypes (`Stock Entry`, `Purchase Receipt`, `Stock Reconciliation`, `Bin`, `Stock Ledger Entry`).
- **HAL isolation** — all hardware-specific code lives in `lib/core/hardware/vendors/`. Business code only imports from `lib/core/hardware/adapters/`.
- **Offline-first** — every user-initiated operation is queued locally first; network is opportunistic.
- **Clean architecture** — each feature has independent `domain / data / presentation` layers; cross-feature dependencies flow only through providers.
- **i18n from day one** — all user-visible strings are ARB keys; new screens must add EN + AR entries before merge.

---

## Contributing

See `documentation/architecture/development-guidelines.md` for branch conventions, commit format, and test requirements. All new backend endpoints need pytest coverage; all new mobile screens need `flutter analyze` to be clean before merge.
