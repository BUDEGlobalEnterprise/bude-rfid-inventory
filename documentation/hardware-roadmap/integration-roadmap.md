# Integration Roadmap

## Phases

| Phase | Scope | Status |
|---|---|---|
| 1 | Repository skeleton, Flutter base, Frappe API skeleton, CI/CD foundation | In progress |
| 2 | Auth + Item lookup + barcode scan (camera) end-to-end against ERPNext | Planned |
| 3 | Stock entries, warehouse transfers, offline sync | Planned |
| 4 | RFID hardware adapters (Chainway first) | Planned |
| 5 | Additional ERP connectors (Zoho, SAP) behind the same client interface | Planned |

## Hardware abstraction

The mobile app talks to the Hardware Abstraction Layer (HAL) — see [`architecture/hal-design.md`](../architecture/hal-design.md) for the full design.

Business code consumes three vendor-agnostic interfaces from `lib/core/hardware/adapters/`:

```dart
abstract class BarcodeAdapter { /* startScan, stopScan, scanSingle, events */ }
abstract class RfidAdapter    { /* connect, startInventory, readTag, writeTagEpc, ... */ }
abstract class DeviceAdapter  { /* getDeviceInfo, getDeviceStatus, ... */ }
```

`HardwareManager` selects the right implementation at app start based on a `DeviceProbe`. Vendor plugins register themselves via `HardwareRegistry.instance.register(...)`.

| Adapter | Status | Devices |
|---|---|---|
| `CameraBarcodeAdapter` | Shipped | Any device with a camera (always available as fallback) |
| `ChainwayBarcodeAdapter` + `ChainwayRfidAdapter` | Stub (throws `VendorSdkUnavailableException`) | Chainway C72, C66, etc. |
| `ZebraBarcodeAdapter` + `ZebraRfidAdapter` | Stub | Zebra TC-series + RFD40 / RFID8500 sleds |
| `UrovoBarcodeAdapter` + `UrovoRfidAdapter` | Stub | Urovo RFID handhelds |
| `HoneywellBarcodeAdapter` | Stub (barcode only) | Honeywell CT40, EDA series |
| `GenericUhfRfidAdapter` | Stub | Catch-all for BLE / USB / LLRP readers |

Replacing a stub with a real impl is a self-contained per-vendor task — see "Integrating a real vendor SDK" in `hal-design.md`. The rest of the app is unaware of which hardware is in use.

## ERP abstraction

`backend/bude_api/services/erpnext_client.py` is the first implementation of an `ErpClient` interface. When SAP B1, Zoho, NetSuite, or Dynamics 365 connectors are added, they will live alongside `erpnext_client.py` and conform to the same interface. The mobile client stays unchanged.

## Out of scope (Phase 1)

- Custom DocTypes — never.
- Real RFID SDK integration.
- SAP / Zoho connectors.
- Push notifications.
- Multi-language UI.
