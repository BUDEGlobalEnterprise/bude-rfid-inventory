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

- ERPNext/Frappe login wired to `bude_api.api.auth.login`
- secure session storage
- dashboard shell and bottom navigation
- attendance check-in/check-out screen with initial offline queue support
- leave balance and leave application screens
- expense claim list and submission screens
- salary slip list screen
- employee profile screen
- notifications screen
- settings and sign out
- initial backend HR endpoints in `backend/bude_api/bude_api/api/hr.py`
- initial Flutter and backend tests

Known gaps:

- Flutter build/test has not yet been verified locally with Flutter installed.
- UI is scaffold-level, not production-polished.
- Offline sync only exists for attendance and needs a proper pending queue UX.
- Leave, expense, salary, profile, and notifications need stronger detail flows.
- Manager approval workflows are not yet implemented.
- Android release signing, icons, privacy policy, and Play Store assets are not ready.

## Release Milestones

### M0 - Scaffold Stabilization

- Make Flutter build and tests pass:
  - `flutter pub get`
  - `flutter analyze`
  - `flutter test`
  - Android debug build
- Clean native metadata:
  - app name: `Bude HR`
  - Android package: `com.budeglobal.hr`
  - iOS bundle id: `com.budeglobal.hr`
  - remove leftover template names and unused starter assets
- Fix first-run quality:
  - production launcher icon placeholder
  - splash screen placeholder
  - version/build number convention
  - app signing placeholders documented
- Harden auth/session:
  - validate ERPNext URL
  - handle wrong credentials
  - handle no linked Employee
  - handle missing HRMS installation
  - secure sign out and token cleanup

### M1 - Employee ESS Core

- Login and session restore:
  - remember tenant URL
  - restore session on app launch
  - show loading state while restoring
  - route unauthenticated users to login
- Dashboard:
  - attendance status card
  - leave balance summary
  - pending approval/request summary
  - quick actions for check-in, leave, expenses, salary, profile
- Attendance:
  - check-in/check-out
  - current status
  - latest check-in/out time
  - attendance history list
- Leave:
  - leave balances
  - apply leave
  - leave request list
  - status tracking
- Expenses:
  - expense claim list
  - create claim
  - claim detail
  - approval/payment status
- Salary:
  - salary slip list
  - salary slip detail
  - PDF download/share where permissions allow
- Profile:
  - employee details
  - contact and emergency fields if available
  - company, department, designation, reports-to
- Notifications:
  - notification list
  - read/unread state if supported
  - notification detail

### M2 - Offline-First HR

- Build a general pending operation model for HR operations:
  - attendance check-in/out
  - leave application drafts
  - expense claim drafts
- Add pending queue screen:
  - operation type
  - created time
  - status
  - retry action
  - discard action
  - last error message
- Add sync behavior:
  - retry when app opens
  - retry when network returns
  - manual sync button
  - network-aware banner
  - conflict/error messages from ERPNext
- Keep offline guarantees clear:
  - attendance can queue offline
  - leave and expenses can save drafts offline
  - salary/profile/notifications are read-only cache unless explicitly supported later

### M3 - Manager And Approvals

- Add manager mode for eligible roles:
  - HR Manager
  - Leave Approver
  - Expense Approver
  - System Manager
- Manager dashboard:
  - pending leave approvals
  - pending expense approvals
  - team attendance exceptions
  - direct report count
- Approval flows:
  - approve/reject leave
  - approve/reject expense claim
  - comments/reason capture
  - approval audit trail summary
- Team views:
  - direct reports
  - employee attendance overview
  - leave calendar
  - employee request history
- Routing/security:
  - hide manager navigation for normal employees
  - backend must re-check permissions on every manager endpoint

### M4 - HRMS Expansion

- Attendance expansion:
  - holiday list awareness
  - shift information
  - late arrival and early exit indicators
  - monthly attendance calendar
  - geofencing support if the customer requires location-based check-in
  - selfie/photo proof as optional later feature
- Leave expansion:
  - leave calendar
  - company holidays and weekly-offs
  - half-day leave
  - leave cancellation
  - attachment support for medical/certified leave
- Documents and policies:
  - company policies
  - employee documents
  - downloadable files from ERPNext `File`
  - acknowledgment tracking if backed by ERPNext workflow
- Directory and engagement:
  - employee directory
  - announcements
  - posts
  - polls
  - birthday/work anniversary notices if available
- Tasks and projects:
  - assigned ToDos
  - workflow approvals
  - project task status
  - CRM/sales task support only if product scope explicitly expands beyond HR

### M5 - Production Release

- CI:
  - Flutter analyze/test for `mobile-app/hr_flutter_app`
  - backend HR test job
  - optional APK build artifact
- Android release:
  - production launcher icons
  - app signing config
  - release flavor or env config
  - Play Store listing assets
  - screenshots
  - privacy policy
  - internal testing track
- ERPNext deployment docs:
  - required ERPNext/HRMS versions
  - required roles
  - required permissions
  - endpoint smoke test checklist
  - demo data setup
- Release acceptance:
  - login works on production ERPNext site
  - attendance online/offline works
  - leave apply/approve works
  - expense submit/approve works
  - salary slip access respects permissions
  - no HR features leak into the RFID inventory app

## Feature Roadmap

### Attendance

- Check-in/check-out with status.
- Attendance history by day and month.
- Shift-aware attendance state.
- Holiday and weekly-off awareness.
- Late arrival and early exit indicators.
- Offline check-in/out queue.
- Geofencing support if required by customer policy.
- Optional selfie/photo proof if required by customer policy.
- Manager exception review for missed check-ins or irregular attendance.

### Leave

- Leave balance cards by leave type.
- Apply leave with date picker, reason, and optional attachment.
- Half-day leave support.
- Cancel leave where ERPNext allows it.
- Leave request list with draft/open/approved/rejected/cancelled states.
- Leave calendar with team/company visibility.
- Holiday and weekly-off awareness.
- Manager approval and rejection with comments.

### Expenses

- Expense claim list and detail.
- Create claim with expense type, amount, date, and description.
- Receipt attachment support.
- Expense type configuration from ERPNext.
- Approval and payment status.
- Manager approval/rejection with comments.
- Offline draft support.

### Salary

- Salary slip list.
- Salary slip detail.
- PDF download/share.
- Permission-safe access only for the logged-in employee or authorized HR users.
- Optional year/month filters.

### Profile

- Employee details.
- Department, designation, company, and reports-to.
- Contact and emergency fields where available.
- Employee documents.
- Profile update request as a later feature if backed by ERPNext workflow.

### Notifications And Engagement

- Notification center.
- Read/unread state where supported.
- Announcements.
- Posts and polls.
- Push notifications later, after backend notification routing is stable.

### Tasks And Projects

- Assigned ToDos.
- Workflow approvals.
- Project task status.
- Future CRM/sales task support only if product scope requires it.

## Backend/API Roadmap

- Keep `bude_api` as the mobile API gateway.
- Use standard ERPNext/HRMS DocTypes first:
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
- Maintain the existing response envelope:
  - `{ ok, data, message, code }`
- Keep all reads and writes permission-aware.
- Use `ignore_permissions=False` for write operations.
- No custom DocTypes in V1 unless a standard ERPNext workflow cannot support the feature.
- Split backend code later from one `hr.py` into modules if it grows:
  - `hr_profile.py`
  - `hr_attendance.py`
  - `hr_leave.py`
  - `hr_expenses.py`
  - `hr_salary.py`
  - `hr_notifications.py`
  - `hr_approvals.py`
- Add endpoint groups:
  - employee profile and directory
  - attendance status/history/check-in
  - leave balances/applications/approvals
  - expense claims/approvals
  - salary slips
  - documents/files
  - notifications/announcements
  - manager dashboard

## Mobile UX Roadmap

- Move from scaffold UI to polished HR app UX:
  - dense employee dashboard
  - clear status cards
  - quick actions
  - bottom navigation for employee flows
  - manager section only for eligible roles
- Improve form quality:
  - date pickers
  - time pickers where needed
  - attachment picker
  - validation messages
  - disabled submit while saving
  - success/error snackbars
- Improve data display:
  - empty states
  - retry states
  - skeleton/loading states
  - filters for history screens
  - detail screens for requests and documents
- Add localization:
  - English first
  - Arabic and RTL before release
  - no hard-coded user-facing strings in final release flows
- Add accessibility:
  - proper labels
  - readable contrast
  - touch targets suitable for mobile
  - no clipped text on small screens

## Security, Privacy, And Compliance

- Secure API keys in platform secure storage.
- Clear all credentials on sign out.
- Add biometric app lock if required.
- Add inactivity lock if required.
- Never expose another employee's salary/profile data unless backend permission allows it.
- Avoid storing salary slips or sensitive documents unencrypted long term.
- Document what data the app uses:
  - employee identity
  - attendance time
  - optional location data
  - expense attachments
  - salary data
- Prepare privacy policy before Play Store internal testing.
- Use permission checks on both mobile UI and backend endpoints.

## Offline And Sync Strategy

- Attendance:
  - queue check-in/out while offline
  - retry automatically when network returns
  - show pending state clearly
- Leave:
  - allow offline draft creation
  - submit only when online unless backend conflict handling is mature
- Expenses:
  - allow offline draft creation
  - queue attachment metadata carefully
  - upload files only when online
- Read-only data:
  - cache recent profile, leave balances, salary list, and notifications
  - label cached data with last refreshed time
- Sync UI:
  - pending operation count
  - retry/discard actions
  - last error
  - manual sync

## Testing And QA Plan

### Flutter Tests

- Unit tests:
  - API envelope parsing
  - auth/session handling
  - attendance queue persistence
  - leave/expense/salary/profile DTO parsing
  - offline operation serialization
- Widget tests:
  - login
  - dashboard
  - attendance screen
  - leave application
  - expense claim form
  - salary slip list/detail
  - settings/sign out
- Golden-flow tests:
  - login to dashboard
  - attendance check-in online
  - attendance check-in offline then sync
  - leave apply flow
  - expense submit flow
  - salary slip view flow

### Backend Tests

- HR role guard.
- Linked Employee lookup.
- Permission denied envelope.
- Missing HRMS/DocType behavior.
- Attendance status and check-in writes.
- Leave balance and leave application writes.
- Expense claim reads/writes.
- Salary slip permission-safe reads.
- Notification list reads.
- Manager approval permissions.

### Manual QA

- Login to ERPNext HRMS demo site.
- Check in/out online.
- Check in/out offline and sync later.
- Apply leave and approve as manager.
- Submit expense and approve as manager.
- View salary slip.
- View profile and notifications.
- Switch network on/off during submit flows.
- Verify normal employees cannot access manager screens.
- Verify no HR features leak into the RFID inventory app.

## Release And Play Store Plan

- Android release preparation:
  - final app icon
  - final splash screen
  - production signing key
  - Play Store app name and short description
  - screenshots for key flows
  - privacy policy URL
  - internal testing track
- Versioning:
  - use semantic app version
  - increment build number for every release artifact
  - document release notes per milestone
- Deployment checklist:
  - ERPNext/HRMS installed
  - `bude_api` installed
  - HR roles configured
  - employee users linked to Employee records
  - salary slip permissions verified
  - attendance/leave/expense workflows configured

## Future Ideas

- Push notifications.
- Employee chat or helpdesk integration.
- Training/onboarding checklist.
- Asset requests or IT requests.
- Travel requests.
- Timesheets.
- Performance review summaries.
- Payroll tax document downloads.
- Sales/CRM mobile tasks only if Bude HR intentionally expands beyond HR.

## Assumptions

- Bude HR remains a separate app, not merged into the RFID inventory app.
- Android and Play Store are the first release targets.
- ERPNext/HRMS standard DocTypes remain the source of truth.
- `/hr-ex-1` and `/hr-ex-2` stay as workflow references only; no GPL implementation is copied.
- Current V0 scaffold is acceptable as the starting point, but M0 must validate build/test locally with Flutter installed.
