# Bude HR

Bude HR is a separate Flutter employee self-service app for ERPNext and HRMS.
It was bootstrapped from the MIT-licensed Momentous Bude HR App, then
trimmed and reworked for Bude HR flows.

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
