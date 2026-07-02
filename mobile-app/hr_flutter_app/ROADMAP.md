# Bude HR App Roadmap

## Product Vision

Bude HR is a separate Flutter employee self-service app for ERPNext and HRMS.
It should let employees complete everyday HR tasks from a mobile device without
opening the ERPNext desk: check in/out, request leave, submit expenses, view
salary slips, read announcements, and track approvals.

The app must stay clean-room and ERPNext-first. `/hr-ex-1` and `/hr-ex-2` are
workflow references only; no GPL implementation is copied. The backend source
of truth remains standard ERPNext/HRMS DocTypes wherever possible.

Android and Play Store release are the first production targets. iOS remains
supported by the scaffold, but Android readiness takes priority.

## Current State

The current app is a V0 scaffold under `mobile-app/hr_flutter_app` with:

- [x] ERPNext/Frappe login wired to `bude_api.api.auth.login`
- [x] secure session storage
- [x] dashboard shell and bottom navigation
- [x] attendance check-in/check-out screen with initial offline queue support
- [x] leave balance and leave application screens
- [x] expense claim list and submission screens
- [x] salary slip list screen
- [x] employee profile screen
- [x] notifications screen
- [x] settings and sign out
- [x] initial backend HR endpoints in `backend/bude_api/bude_api/api/hr.py`
- [x] initial Flutter and backend tests

Known gaps:

- [ ] Flutter build/test has not yet been verified locally with Flutter installed.
- [ ] UI is scaffold-level, not production-polished.
- [ ] Offline sync only exists for attendance and needs a proper pending queue UX.
- [ ] Leave, expense, salary, profile, and notifications need stronger detail flows.
- [ ] Manager approval workflows are not yet implemented.
- [ ] Android release signing, icons, privacy policy, and Play Store assets are not ready.

## Microtask Backlog

This roadmap is intentionally split into small implementation tasks, not broad
milestones. Each task should be small enough for one focused implementation
pass and should include tests where practical.

Status legend:

- [x] Done and verified from the current repository.
- [ ] Pending.
- Blocked: Cannot verify or finish until an external dependency is available.

## Next Task Queue

1. [x] Install or enable Flutter in the environment. ✓ Flutter 3.44.4 installed
   with JDK 17 and Android SDK locally.
2. [x] Run `flutter pub get` in `mobile-app/hr_flutter_app`. ✓ Clean, 78 new
   dependencies resolved.
3. [x] Fix dependency or SDK issues from `flutter pub get`. ✓ No issues.
4. [x] Run `flutter analyze`. ✓ All issues fixed (see Build And Project Setup).
5. [x] Fix analyzer errors. ✓ 2 invalid build() overrides and 2 const lints fixed.
6. [x] Run `flutter test`. ✓ All 51 tests pass (see Build And Project Setup).
7. [x] Fix failing tests. ✓ 3 test failures fixed (normalizeBaseUrl, manager
   tab selection, dashboard overflow).
8. [x] Build Android debug APK. ✓ Built successfully (151MB, app-debug.apk).

## Completed To Date

- [x] HR app scaffold exists under `mobile-app/hr_flutter_app`.
- [x] Android package is `com.budeglobal.hr`.
- [x] iOS bundle id is `com.budeglobal.hr`.
- [x] Android app label is `Bude HR`.
- [x] README links to `ROADMAP.md`.
- [x] Backend HR API file exists at `backend/bude_api/bude_api/api/hr.py`.
- [x] Initial Flutter tests exist for auth, attendance queue, expenses, leave, salary, and settings.
- [x] Initial backend HR tests exist at `backend/bude_api/bude_api/tests/test_hr.py`.
- [x] No known template app data remains in the HR app.

## Microtasks

### Build And Project Setup

- [x] Verify `flutter pub get` in `mobile-app/hr_flutter_app`. ✓ Clean, no issues.
- [x] Fix dependency or SDK issues from `flutter pub get`. ✓ No issues.
- [x] Run `flutter analyze`. ✓ Fixed 4 issues (see below).
- [x] Fix all analyzer errors. ✓ 2 invalid overrides in attendance/salary screens; 2 const lints in dashboard/settings.
- [x] Run `flutter test`. ✓ All 51 tests pass.
- [x] Fix failing unit/widget tests. ✓ Fixed auth normalizeBaseUrl (reject ftp://), manager Leave tab selection, dashboard card overflow.
- [x] Build Android debug APK. ✓ Debug APK built successfully (151MB).
- [x] Fix Android build errors. ✓ Reduced Gradle heap to 2G in gradle.properties to prevent OOM kill.
- [x] Verify Android application id is `com.budeglobal.hr`.
- [x] Verify Android app label is `Bude HR`.
- [x] Verify iOS bundle id is `com.budeglobal.hr`.
- [x] Remove any remaining template names from native metadata.
- [x] Replace starter launcher icons with temporary Bude HR icons.
- [x] Replace starter splash assets with temporary Bude HR splash.
- [x] Add version/build number convention to README.
- [x] Document Android signing placeholder.
- [x] Add CI job for HR Flutter analyze/test.
- [x] Add CI job for backend HR tests.

Acceptance checks:

- [x] `flutter pub get` succeeds. ✓ Verified.
- [x] `flutter analyze` succeeds. ✓ Verified, no issues.
- [x] `flutter test` succeeds. ✓ Verified, 51/51 tests pass.
- [x] Android debug build succeeds. ✓ Verified, 151MB APK built and ready.
- [x] No `flutter_starter`, `com.momentous`, or unrelated starter branding remains. ✓ Verified.

### Authentication And Tenant Setup

- [x] Add ERPNext URL validation before login submit.
- [x] Normalize base URL by trimming spaces and trailing slash.
- [x] Show invalid URL error inline.
- [x] Show invalid credentials error inline.
- [x] Show network unavailable error inline.
- [x] Show missing linked Employee error inline.
- [x] Show missing HRMS/unsupported site error inline.
- [x] Add loading state during login.
- [x] Disable login button while submitting.
- [x] Persist last tenant URL after successful login.
- [x] Restore session on app launch.
- [x] Add auth restore loading state.
- [x] Add splash/loading screen while session restores.
- [x] Redirect unauthenticated users to login.
- [x] Redirect authenticated users to dashboard.
- [x] Add secure logout confirmation.
- [x] Clear secure storage on logout.
- [x] Add unit tests for base URL normalization.
- [x] Add widget test for empty login validation.
- [x] Add widget test for login failure state.
- [x] Add widget test for login success navigation.

Acceptance checks:

- [x] User cannot submit empty URL, username, or password.
- [x] Wrong credentials show a human-readable error.
- [x] A valid login lands on dashboard.
- [x] Restarting the app restores the session.
- [x] Logout clears credentials and returns to login.

### Dashboard

- [x] Add attendance status card.
- [x] Add check-in/check-out quick action.
- [x] Add leave balance summary card.
- [x] Add pending leave request count.
- [x] Add pending expense claim count.
- [x] Add salary slip shortcut.
- [x] Add profile shortcut.
- [x] Add notifications shortcut.
- [x] Add manager section placeholder for eligible roles only.
- [x] Add refresh action.
- [ ] Add dashboard loading skeleton.
- [x] Add dashboard empty state for missing HR data.
- [x] Add dashboard error state with retry.
- [x] Add widget test for normal employee dashboard.
- [x] Add widget test for manager dashboard visibility.

Acceptance checks:

- [x] Dashboard shows useful HR status without opening sub-screens.
- [x] Manager content is hidden from normal employees.
- [x] Refresh updates dashboard data without logging out.

### Attendance

- [x] Add backend endpoint for attendance history.
- [x] Add Flutter model for attendance history rows.
- [x] Add repository method for attendance history.
- [x] Show latest check-in and latest check-out time.
- [x] Show current checked-in state.
- [x] Add check-in button.
- [x] Add check-out button.
- [x] Disable invalid action based on current state.
- [x] Add attendance history list.
- [x] Add day/month filter.
- [x] Add empty history state.
- [x] Add failed load retry.
- [x] Queue check-in when offline.
- [x] Queue check-out when offline.
- [x] Show pending attendance count.
- [x] Add retry action for pending attendance.
- [x] Add discard action for pending attendance.
- [x] Add last sync error display.
- [x] Add shift name display if backend returns it.
- [x] Add late/early indicator if backend returns it.
- [x] Add holiday/weekly-off label if backend returns it.
- [x] Add optional geofence fields to backend contract, disabled by default.
- [x] Add tests for online check-in.
- [x] Add tests for offline check-in queue.
- [x] Add backend test for attendance history.
- [x] Add model parsing test for attendance history rows.
- [x] Add tests for retrying queued attendance.

Acceptance checks:

- [ ] Online check-in creates an ERPNext `Employee Checkin`.
- [x] Offline check-in is saved locally and visible as pending.
- [x] Retried pending check-in syncs when network is available.
- [x] Attendance history is permission-safe for the logged-in employee.

### Leave

- [x] Add backend endpoint for leave request list.
- [x] Add backend endpoint for leave request detail.
- [x] Add backend endpoint for leave cancellation where ERPNext allows it.
- [x] Add Flutter model for leave applications.
- [x] Add repository method for leave request list.
- [x] Add repository method for leave detail.
- [x] Add repository method for cancellation.
- [x] Replace text date fields with date pickers.
- [x] Add leave type picker from backend.
- [x] Add from date validation.
- [x] Add to date validation.
- [x] Add half-day option.
- [x] Add reason field.
- [ ] Add optional attachment field.
- [x] Show leave balances by leave type.
- [x] Show leave request list.
- [x] Show leave status chips.
- [x] Show leave detail screen.
- [x] Add cancel action for cancellable requests.
- [ ] Add leave calendar view.
- [ ] Add holiday and weekly-off hints.
- [x] Add empty state for no leave requests.
- [x] Add failed load retry.
- [x] Add widget test for leave application validation.
- [x] Add widget test for leave list.
- [x] Add backend tests for leave list, detail, apply, and cancel.

Acceptance checks:

- [x] Employee can view leave balances.
- [x] Employee can apply leave with valid dates.
- [x] Invalid date ranges are blocked before submit.
- [x] Employee can track leave status.
- [x] Cancellation is shown only when ERPNext allows it.

### Expenses

- [x] Add backend endpoint for expense type list.
- [x] Add backend endpoint for expense claim detail.
- [ ] Add backend endpoint for expense attachment upload.
- [x] Add Flutter model for expense types.
- [x] Add Flutter model for expense claim detail.
- [x] Add repository method for expense types.
- [x] Add repository method for expense detail.
- [ ] Add repository method for attachment upload.
- [x] Add expense type picker.
- [x] Add expense date field.
- [x] Add amount validation.
- [x] Add description field.
- [ ] Add receipt attachment picker.
- [ ] Add attachment preview.
- [x] Add claim detail screen.
- [x] Add status timeline for draft/open/approved/paid/rejected.
- [x] Add offline expense draft save.
- [x] Add retry submit for offline draft.
- [x] Add discard draft action.
- [x] Add empty state for no claims.
- [x] Add failed load retry.
- [x] Add widget test for expense form validation.
- [ ] Add widget test for attachment selection state.
- [x] Add backend tests for claim list, detail, create, and attachments.

Acceptance checks:

- [x] Employee can create an expense claim with a positive amount.
- [ ] Receipt attachment can be selected and submitted when online.
- [x] Offline expense drafts do not disappear after app restart.
- [x] Status is visible after submission.

### Salary

- [x] Add backend endpoint for salary slip detail.
- [x] Add backend endpoint or URL for salary slip PDF.
- [x] Add Flutter model for salary slip detail.
- [x] Add repository method for salary detail.
- [x] Add repository method for salary slip PDF URL.
- [x] Add salary slip detail screen.
- [x] Add year/month filters.
- [x] Add empty state for no salary slips.
- [x] Add permission denied state.
- [x] Add copy PDF link action.
- [ ] Add download action.
- [ ] Add share action.
- [ ] Avoid long-term unencrypted storage of salary PDFs.
- [ ] Add widget test for salary list.
- [ ] Add widget test for permission denied state.
- [x] Add backend tests for permission-safe salary list and detail reads.

Acceptance checks:

- [x] Employee can view only permitted salary slips.
- [x] Salary slip detail opens from the list.
- [ ] PDF download/share works only when backend allows access.
- [x] Permission denied state is clear and non-leaky.

### Profile And Documents

- [x] Add backend fields for contact and emergency details where available.
- [x] Add backend endpoint for employee documents.
- [ ] Add backend endpoint for profile update request if supported.
- [x] Add Flutter model for profile details.
- [x] Add Flutter model for employee documents.
- [x] Add profile sections for job, contact, emergency, and reporting details.
- [x] Add document list screen.
- [x] Add document link copy action.
- [ ] Add document download action.
- [ ] Add profile update request form.
- [ ] Add validation for editable profile fields.
- [ ] Add profile update status list.
- [x] Add empty state for no documents.
- [x] Add model parsing tests for profile details and employee documents.
- [ ] Add widget test for profile detail sections.
- [x] Add backend tests for profile and document permission safety.

Acceptance checks:

- [x] Employee profile shows useful job and contact details.
- [x] Employee documents are visible only when permission allows.
- [ ] Profile update request is available only if backend supports it.

### Notifications And Engagement

- [x] Add backend endpoint for notification detail.
- [x] Add backend endpoint for marking notification read.
- [ ] Add backend endpoint for announcements.
- [ ] Add backend endpoint for posts/polls only when scoped.
- [x] Add Flutter model for notification detail.
- [x] Add read/unread state.
- [x] Add notification detail screen.
- [x] Add mark-as-read action.
- [ ] Add announcements list.
- [ ] Add announcement detail screen.
- [x] Add empty state for no notifications.
- [x] Add failed load retry.
- [ ] Add push notification groundwork after notification routing is stable.
- [ ] Add widget test for notifications list.
- [x] Add backend tests for notification list/detail/read state.

Acceptance checks:

- [x] Employee can see notifications from ERPNext.
- [x] Opening a notification shows full content.
- [x] Read/unread state is updated if backend supports it.

### Manager And Approvals

- [x] Define manager role buckets.
- [x] Add backend endpoint for manager dashboard summary.
- [x] Add backend endpoint for direct reports.
- [x] Add backend endpoint for pending leave approvals.
- [x] Add backend endpoint for pending expense approvals.
- [x] Add backend endpoint for approve/reject leave.
- [x] Add backend endpoint for approve/reject expense.
- [ ] Add backend endpoint for team attendance exceptions.
- [x] Add mobile manager dashboard.
- [x] Add direct reports screen.
- [x] Add pending leave approvals screen.
- [x] Add pending expense approvals screen.
- [x] Add approval detail screen.
- [x] Add approval comment field.
- [x] Add approve action.
- [x] Add reject action.
- [x] Add confirmation dialog before approval action.
- [x] Hide manager routes from normal employees.
- [x] Guard manager deep links in router.
- [x] Add backend permission checks for every manager endpoint.
- [x] Add widget tests for manager route visibility.
- [x] Add widget test for direct reports list.
- [x] Add backend tests for manager permission denial.
- [x] Add backend tests for approve/reject success.
- [x] Add backend test for direct reports scoping.

Acceptance checks:

- [x] Normal employees cannot see or access manager screens.
- [x] Managers can approve/reject permitted requests.
- [ ] Approval actions require comments where configured.
- [x] Backend rejects unauthorized approval attempts.

### Offline And Sync

- [x] Define shared `PendingHrOperation` model.
- [ ] Add operation types for attendance, leave draft, and expense draft.
      (attendance + expense done; leave draft pending an offline apply path)
- [x] Add local persistence for pending operations.
- [x] Add pending queue screen.
- [x] Add operation detail bottom sheet.
- [x] Add retry action.
- [x] Add discard action.
- [x] Add manual sync action.
- [x] Add automatic retry on app start.
- [ ] Add automatic retry on connectivity restore.
- [ ] Add network status provider.
- [ ] Add offline banner.
- [x] Add sync status indicator.
- [x] Add last refreshed timestamp for cached read-only data.
- [x] Cache profile summary.
- [x] Cache leave balances.
- [x] Cache recent salary slip list without PDFs.
- [x] Cache notification list.
- [x] Add unit tests for operation serialization.
- [x] Add unit tests for retry/discard.
- [x] Add widget tests for pending queue.

Acceptance checks:

- [x] Pending HR operations survive app restart.
- [x] User can see what is waiting to sync.
- [x] Failed syncs show actionable error messages.
- [x] Read-only cached data is labeled with last refreshed time.

### Backend/API Structure

- [x] Keep `bude_api` as the mobile API gateway.
- [x] Keep `{ ok, data, message, code }` envelope for all HR endpoints.
- [x] Keep all writes permission-aware with `ignore_permissions=False`.
- [x] Add HR endpoint smoke tests.
- [ ] Split `hr.py` into smaller modules when it becomes hard to maintain:
  - `hr_profile.py`
  - `hr_attendance.py`
  - `hr_leave.py`
  - `hr_expenses.py`
  - `hr_salary.py`
  - `hr_notifications.py`
  - `hr_approvals.py`
- [x] Use standard ERPNext/HRMS DocTypes first:
  - `Employee`
  - `Employee Checkin`
  - `Attendance`
  - `Leave Application`
  - `Leave Allocation`
  - `Expense Claim`
  - `Salary Slip`
  - `Holiday List`
  - `Shift Type`
  - `Notification Log`
  - `File`
  - `ToDo`
- [x] Avoid custom DocTypes in V1 unless a standard ERPNext workflow cannot support the feature.

Acceptance checks:

- [x] HR endpoint failures use consistent error codes.
- [x] Permission denied never leaks sensitive data.
- [x] Standard ERPNext DocTypes remain the source of truth.

### Mobile UX And Accessibility

- [ ] Replace scaffold dashboard layout.
- [ ] Add compact employee status header.
- [ ] Add quick action row.
- [ ] Add consistent card components.
- [ ] Add consistent list item components.
- [x] Add empty state component.
- [x] Add error state component.
- [ ] Add loading skeleton component.
- [ ] Add reusable date picker field.
- [ ] Add reusable amount field.
- [ ] Add reusable attachment picker.
- [x] Add success snackbar pattern.
- [x] Add error snackbar pattern.
- [x] Add confirmation dialog pattern.
- [x] Add accessible labels for icon buttons.
- [ ] Check text overflow on small Android screens.
- [ ] Check touch target size.
- [x] Add dark theme pass.
- [ ] Add Arabic RTL pass.
- [ ] Move user-facing strings to localization files before release.

Acceptance checks:

- [ ] Primary screens are usable on small phones.
- [ ] Text does not clip or overlap.
- [x] Icon-only buttons have tooltips/labels.
- [ ] Arabic RTL layout is not broken before release.

### Security, Privacy, And Compliance

- [x] Confirm API keys are stored only in secure storage.
- [x] Clear secure storage on logout.
- [ ] Add optional biometric app lock. (needs `local_auth` plugin)
- [ ] Add optional inactivity lock.
- [x] Prevent salary slip caching unless encrypted or temporary.
      (salary cache routed through encrypted `flutter_secure_storage`)
- [x] Prevent cross-employee salary/profile access from mobile and backend.
      (backend owned-record checks + scoping tests; mobile cannot bypass)
- [ ] Document location usage if geofencing is enabled. (no geofencing yet)
- [ ] Document camera/file usage if attachments or selfie proof are enabled.
- [ ] Draft privacy policy for Play Store internal testing.
- [ ] Add account/data deletion support policy text.
- [ ] Add role/permission setup documentation.

Acceptance checks:

- [x] Sensitive data is protected at rest.
- [x] Salary data is only visible to permitted users.
- [ ] Privacy policy covers HR, salary, attendance, location, and attachments.

### Release And Play Store

- [ ] Create production app icon.
- [ ] Create production splash screen.
- [ ] Configure Android signing.
- [ ] Add release build instructions.
- [ ] Add environment/flavor strategy if needed.
- [ ] Prepare Play Store title.
- [ ] Prepare Play Store short description.
- [ ] Prepare Play Store long description.
- [ ] Prepare screenshots for login, dashboard, attendance, leave, expenses, salary.
- [ ] Prepare privacy policy URL.
- [ ] Prepare internal testing checklist.
- [ ] Prepare ERPNext setup guide.
- [ ] Prepare demo data guide.
- [ ] Prepare release notes template.
- [ ] Build internal testing APK/AAB.
- [ ] Smoke test release build against demo ERPNext site.

Acceptance checks:

- [ ] Android release artifact builds.
- [ ] Play Store internal testing submission is ready.
- [ ] Demo checklist can be followed by a non-developer.

## Future Feature Ideas

- Push notifications.
- Employee chat or helpdesk integration.
- Training/onboarding checklist.
- Asset requests or IT requests.
- Travel requests.
- Timesheets.
- Performance review summaries.
- Payroll tax document downloads.
- Sales/CRM mobile tasks only if Bude HR intentionally expands beyond HR.

## Definition Of Done For Any Microtask

- Code follows existing app/backend patterns.
- UI has loading, empty, and error states where relevant.
- Backend reads/writes are permission-aware.
- Tests are added or updated when behavior changes.
- User-facing strings are prepared for localization when the screen is production-facing.
- No GPL code is copied from reference apps.
- The RFID inventory app is not changed unless the task explicitly requires shared infrastructure.

## Assumptions

- Bude HR remains a separate app, not merged into the RFID inventory app.
- Android and Play Store are the first release targets.
- ERPNext/HRMS standard DocTypes remain the source of truth.
- `/hr-ex-1` and `/hr-ex-2` stay as workflow references only; no GPL implementation is copied.
- Current V0 scaffold is acceptable as the starting point, but build/test must
  be validated locally with Flutter installed.
