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

The mobile app talks to a `Scanner` interface:

```
abstract class Scanner {
  Stream<ScanEvent> get events;
  Future<void> start();
  Future<void> stop();
}
```

Implementations land in `mobile-app/flutter_app/lib/shared/services/scanners/`:

| Implementation | Devices |
|---|---|
| `CameraScanner` (Phase 2) | Any device with a camera |
| `ChainwayScanner` (Phase 4) | Chainway C72, C66 |
| `ZebraScanner` (Phase 4) | Zebra RFID handhelds |
| `UrovoScanner` (Phase 4) | Urovo RFID devices |
| `GenericUhfScanner` (Phase 4) | Other UHF readers via vendor SDKs |

Each implementation is selected at runtime via dependency injection — the rest of the app is unaware of which hardware is in use.

## ERP abstraction

`backend/bude_api/services/erpnext_client.py` is the first implementation of an `ErpClient` interface. When SAP B1, Zoho, NetSuite, or Dynamics 365 connectors are added, they will live alongside `erpnext_client.py` and conform to the same interface. The mobile client stays unchanged.

## Out of scope (Phase 1)

- Custom DocTypes — never.
- Real RFID SDK integration.
- SAP / Zoho connectors.
- Push notifications.
- Multi-language UI.
