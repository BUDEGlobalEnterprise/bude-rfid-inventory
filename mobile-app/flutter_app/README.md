# Bude Inventory - Flutter App

Mobile/desktop client for the Bude RFID Inventory platform. Cross-platform (Android, iOS, Windows, Web) built on Flutter with Clean Architecture.

## Status

Phase 1 — Skeleton only. No business logic. Module folders contain placeholder files marking the data / domain / presentation layers per Clean Architecture.

## Prerequisites

1. Install [Flutter SDK](https://flutter.dev/docs/get-started/install) (>= 3.19)
2. Install Android Studio (for the Android SDK + emulator) — VS Code alone is not sufficient for Android builds
3. Run `flutter doctor` and resolve any platform issues

## Bootstrap

From this directory:

```bash
flutter pub get
flutter create . --platforms=android,ios,windows,web --org=com.bude --project-name=bude_inventory
flutter pub get
```

The second `flutter create` generates the native platform folders (android/, ios/, windows/, web/) without overwriting `lib/`.

### After `flutter create` — required platform tweaks

**Android camera permission** (for barcode scanner). Edit `android/app/src/main/AndroidManifest.xml` and add inside `<manifest>`:

```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-feature android:name="android.hardware.camera" android:required="false"/>
```

**Android minSdkVersion** for `mobile_scanner` — edit `android/app/build.gradle`:

```gradle
defaultConfig {
    minSdkVersion 21
}
```

**iOS camera permission** — edit `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Used to scan item barcodes.</string>
```

## Architecture

```text
lib/
├── core/              # Cross-cutting concerns (config, errors, network, utils)
├── features/          # One folder per module — each follows Clean Architecture
│   └── <module>/
│       ├── data/         # API clients, models, repository implementations
│       ├── domain/       # Entities, repository contracts, use cases
│       └── presentation/ # Widgets, screens, state notifiers
└── shared/            # Reusable widgets, models, services
```

## Modules (Phase 1 placeholders)

- `authentication` — Login, session, token refresh
- `dashboard` — Home / KPIs
- `inventory` — Item lookup, stock levels
- `barcode` — Camera-based scanning (future: hardware scanner adapters)
- `warehouse` — Warehouse selection, transfers
- `settings` — App preferences, ERPNext connection config

## Run

```bash
flutter run                    # Default device
flutter run -d chrome          # Web
flutter run -d windows         # Windows desktop
```
