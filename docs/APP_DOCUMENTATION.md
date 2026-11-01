# ARC Application Documentation

## Overview

ARC is a Flutter productivity application that combines task management, habit
tracking, personal finance tracking, reminders, feedback, search, and account
synchronization. The application is designed for Android first and retains the
standard Flutter platform projects for iOS, macOS, Linux, Windows, and web.

The current application version is declared in `pubspec.yaml`. Flutter and Dart
version requirements should always be read from the same file before setting up
a development machine.

## User-facing capabilities

### Dashboard

The dashboard presents a typed snapshot assembled from task, habit, and money
repositories. It includes:

- today's task and habit completion;
- productivity score;
- remaining monthly budget;
- current habit streak;
- today's income and expenses;
- monthly savings;
- upcoming task deadlines; and
- recent task, habit, and transaction activity.

Dashboard calculations live in
`lib/features/dashboard/repository/dashboard_repository.dart`. The screen must
consume `DashboardData` instead of reconstructing metrics independently.

### Task manager

Tasks support creation, editing, deletion, completion, priority, category,
labels, dates, times, reminders, filtering, sorting, and search. Task changes
are persisted to Hive immediately and synchronized to Firestore when an
authenticated connection is available.

### Habit tracker

Habits support creation, editing, daily completion, streaks, reminders, and
analytics. Habit completion records are stored separately from habit
definitions so daily history can be calculated without rewriting the habit.

### Money tracker

The money tracker stores income and expense transactions, monthly budgets,
summaries, and optional Android SMS-based transaction recognition. Automatic
recognition is local to the device and uses a native Android bridge.

### Notifications

ARC uses a centralized notification controller and policy. The policy creates
the desired reminder set from the current application snapshot, while the
controller reconciles desired reminders with Android or iOS pending reminders.

The Scheduled Reminders screen displays expected reminders and health status.
Native exception details are logged for development but are not rendered to
users. Android release shrinking must retain Gson generic signatures required
by `flutter_local_notifications`; the required rules are in
`android/app/proguard-rules.pro`.

### Feedback and administration

Users can submit bug reports, feature requests, general feedback, and ratings.
Feedback delivery is implemented through the Cloudflare Worker under
`cloudflare_workers/feedback_delivery`. Administrative access is protected by
the account role and routed separately from the normal application shell.

## Architecture

ARC uses feature-oriented Flutter source organization:

```text
lib/
  core/                 Shared notifications, services, theme, and widgets
  features/             Product features grouped by domain
  providers/            Shared Riverpod state and repository wiring
  routes/               GoRouter configuration and access redirects
  firebase_options.dart Generated Firebase platform configuration
  main.dart              Startup, synchronization, and app shell
```

Each product area generally contains its own models, repositories, providers or
notifiers, screens, services, and widgets. Cross-cutting behavior belongs in
`lib/core`.

### State management

Riverpod owns reactive application state. Repository providers supply the
storage boundary, state notifiers expose mutations, and derived providers
calculate filtered or combined state.

When adding a feature:

1. keep persistence inside its repository;
2. expose mutations through a notifier or service;
3. derive display state through typed providers; and
4. keep widgets focused on rendering and user interaction.

Dynamic maps should not be used for complex screen state when a typed model can
represent the same contract.

### Navigation

`lib/routes/app_router.dart` defines authentication redirects and routes. The
main shell provides Dashboard, Tasks, Habits, and Money destinations. Settings,
search, notifications, feedback, and administration are outside the tab shell.

Unknown routes render a not-found screen. Authentication state determines
whether a user sees the login flow, normal shell, or administration screen.

## Persistence and synchronization

### Hive

Hive is the immediate local source for tasks, habits, habit entries,
transactions, settings, and pending synchronization queues. Authenticated
records use user-scoped box names to avoid account data crossing between local
sessions.

Boxes use a compaction policy to reclaim append-only tombstones. Successful
queue synchronization also compacts open base and user-scoped boxes. Do not
delete account boxes during logout; closing them preserves offline data for the
next login.

### Firestore

Firestore supplies authenticated cloud persistence and real-time updates. ARC
limits the local Firestore cache to 10 MiB because the working data is already
stored in Hive. Repositories queue unsuccessful writes locally and retry them
during synchronization.

User-owned collections are stored below the authenticated user document.
Security behavior must remain consistent with `firestore.rules` and
`firestore.indexes.json`.

### Removed local data

Older installations may contain storage created by a retired private-notes
feature. Startup removes its former Hive boxes and local media directory. Those
records were local-only and were never uploaded to Firestore.

## Authentication and account isolation

Firebase Authentication is the account authority. Google and password-based
authentication are supported by the repository and service layers. The user
context provider contains the current identifier, role, profile, and startup
status.

Important rules:

- never run authenticated background synchronization without a user ID;
- open user-scoped Hive boxes before creating user repositories;
- refresh notifiers after a full pull; and
- close scoped boxes when switching accounts without deleting their files.

## Android integration

`MainActivity.kt` configures:

- the money automation method and event channels; and
- the application haptics channel.

The manifest declares the permissions and receivers needed by these features.
Any new native permission must have a visible user action, denial handling, and
a testable Dart boundary.

Release shrinking is disabled until authentication, notifications, and native
integrations have a repeatable physical-device smoke test. Keep rules should be
as narrow as possible and must be validated with a signed release build before
shrinking is enabled again.

## Cloudflare Worker

The feedback delivery Worker is a separate TypeScript package:

```text
cloudflare_workers/feedback_delivery/
  src/       Worker source
  test/      Unit and integration-style tests
  scripts/   Verification helpers
```

Copy `.dev.vars.example` to a local `.dev.vars` file for local credentials.
Secret files are ignored and must never be committed.

Common commands from the Worker directory:

```powershell
npm install
npm test
npx wrangler dev
```

## Development setup

Prerequisites:

- Flutter matching the SDK constraint in `pubspec.yaml`;
- Android Studio and an Android SDK for Android builds;
- a valid `android/app/google-services.json` for the intended Firebase project;
- Node.js for feedback Worker development; and
- Windows Developer Mode when Flutter needs plugin symlinks on Windows.

Install Flutter dependencies:

```powershell
flutter pub get
```

Run the application:

```powershell
flutter run
```

## Quality checks

Run formatting, analysis, and tests before merging:

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub
```

Useful focused checks include:

```powershell
flutter test --no-pub test/dashboard_repository_test.dart
flutter test --no-pub test/responsive_ui_test.dart
flutter test --no-pub test/central_notification_test.dart
```

Build Android artifacts with:

```powershell
flutter build apk --release
flutter build appbundle --release
```

Use an App Bundle for store distribution. Use split-per-ABI APKs only when APK
distribution is required.

## Storage controls

ARC controls installed and runtime storage through:

- dependency and plugin pruning;
- a reduced timezone database covering the recent ten-year window;
- removal of unused native plugin dependency trees;
- a 10 MiB Firestore disk-cache limit;
- Hive compaction on box growth and successful synchronization; and
- cleanup of storage belonging to retired functionality.

Repository-generated directories such as `build`, `.dart_tool`, `.gradle`,
`.wrangler`, and `node_modules` must remain untracked.

## Troubleshooting

### Scheduled reminders cannot be read

Confirm release shrinking is disabled, reinstall the corrected build, and pull
down on Scheduled Reminders to refresh the health state. The rules in
`android/app/proguard-rules.pro` must be used if shrinking is enabled again.

### Flutter plugin symlink error on Windows

Enable Windows Developer Mode, close the terminal, and run `flutter pub get`
again.

### Data appears to belong to another account

Stop immediately and inspect user-scoped Hive box creation, repository provider
dependencies, and logout box-closing behavior. Do not repair account isolation
by deleting all local boxes.

### Firestore writes remain queued

Verify authentication, Firestore rules, network access, and the corresponding
queue box. A successful sync should remove the queued record and compact the
open storage.

## Maintenance rules

- Add regression coverage for every repaired production failure.
- Keep dashboard data contracts typed.
- Do not expose native stack traces in user-facing widgets.
- Keep credentials and generated build output out of Git.
- Update this document and the root README whenever features, setup, storage,
  or release behavior changes.
