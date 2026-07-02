# Bude HR

Bude HR is a separate Flutter employee self-service app for ERPNext and HRMS.
It was bootstrapped from the MIT-licensed Momentous Bude HR App, then
trimmed and reworked for Bude HR flows.

See [ROADMAP.md](ROADMAP.md) for the staged HR app delivery plan.

## Scope

- ERPNext/Frappe login using `bude_api.api.auth.login`
- Employee dashboard
- Attendance check-in/check-out with an offline queue
- Leave balances and leave application
- Expense claim list and submission
- Salary slip list
- Employee profile
- Notifications
- Settings and sign out

## Identity

- App name: `Bude HR`
- Dart package: `bude_hr`
- Android application id: `com.budeglobal.hr`

## Run

```bash
flutter pub get
flutter test
flutter run
```

Flutter was not available in the implementation environment, so run the above
commands locally before release work.

## Versioning

Use semantic app versions with monotonically increasing build numbers:

```text
version: <major>.<minor>.<patch>+<build>
```

Examples:

- `0.1.0+1` for the first internal build
- `0.1.1+2` for a patch build
- `0.2.0+3` for the next feature build

Update `pubspec.yaml` before every APK/AAB submitted to internal testing or
Play Store review.

## Android Signing

The Android release build currently uses the debug signing config as a
placeholder in `android/app/build.gradle.kts`. Before any production or Play
Store release:

- create a Bude HR upload keystore
- store keystore credentials outside git
- wire release signing through Gradle properties or CI secrets
- verify `flutter build appbundle --release` uses the release signing config

Never commit keystore files or signing passwords.

## Release Build

Android is the first production target:

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
flutter build appbundle --release
```

Run these from `mobile-app/hr_flutter_app` with Flutter installed.
