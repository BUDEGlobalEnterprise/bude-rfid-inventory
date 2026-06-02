# Features

Each module follows Clean Architecture and is split into three layers:

```
<module>/
├── data/         # API clients, DTOs, repository implementations
├── domain/       # Entities, repository contracts, use cases
└── presentation/ # Screens, widgets, state notifiers
```

## Rules

- `presentation` may depend on `domain` only — never on `data`.
- `data` may depend on `domain` only.
- `domain` has no Flutter or networking imports — pure Dart.
- Cross-module communication goes through `domain` interfaces, never direct imports.

## Modules

| Module | Purpose |
|---|---|
| `authentication` | Login, session persistence, token refresh |
| `dashboard` | Home view, KPIs |
| `inventory` | Item search, stock levels |
| `barcode` | Camera-based scanning; hardware adapters added later |
| `warehouse` | Warehouse selection, transfers |
| `settings` | App preferences, ERPNext connection config |

`authentication` is the reference implementation showing the layer pattern. The other modules are Phase 1 placeholders with a single `_module.dart` marker file in each layer.
