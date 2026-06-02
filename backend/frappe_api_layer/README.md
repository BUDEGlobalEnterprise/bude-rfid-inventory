# Frappe API Layer (`bude_api`)

Server-side extension for an ERPNext / Frappe site. Exposes whitelisted API methods that the Flutter client calls; **never** modifies ERPNext standard DocTypes.

## Status

Phase 1 — skeleton. No business logic. Modules contain stubs marking the four required services:

| Module | Purpose |
|---|---|
| `services/auth_service.py` | Wraps Frappe login/logout/session; token issuance |
| `services/erpnext_client.py` | Thin wrapper over Frappe ORM for standard DocTypes (Item, Stock Entry, Warehouse, etc.) |
| `api/health.py` | Whitelisted `ping` endpoint for client connectivity checks |
| `config/settings.py` | Reads environment + Frappe site_config values |

## Layout

```
frappe_api_layer/
├── __init__.py
├── hooks.py                # Frappe app entrypoint
├── modules.txt
├── requirements.txt
├── config/
│   └── settings.py
├── services/
│   ├── auth_service.py
│   └── erpnext_client.py
├── api/
│   └── health.py
├── middleware/
│   └── request_logger.py
├── utils/
│   └── response.py
└── tests/
    └── test_health.py
```

## Install onto a Frappe bench (later)

```bash
# from your frappe-bench directory
bench get-app bude_api /path/to/bude-rfid-inventory/backend/frappe_api_layer
bench --site <site> install-app bude_api
bench restart
```

## Calling endpoints

```
POST /api/method/login                            # Frappe built-in
GET  /api/method/bude_api.api.health.ping         # custom — returns service status
GET  /api/resource/Item?filters=[["disabled","=",0]]   # standard ERPNext REST
```

## Constraints

- No custom DocTypes.
- All persistence goes through ERPNext standard entities.
- Connectors for SAP / Zoho / other ERPs land under a future `integrations/` package using the Adapter pattern.
