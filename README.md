# ARC

ARC is a cross-platform Flutter productivity app for managing tasks, habits,
personal finances, reminders, and feedback from one account-aware workspace.

## Features

- Dashboard with daily progress, productivity, budget, savings, streaks,
  deadlines, and recent activity
- Task creation, reminders, priorities, categories, labels, filters, and search
- Habit tracking with daily completion, streaks, reminders, and analytics
- Income, expense, and monthly budget tracking
- Optional Android SMS transaction recognition
- Centralized local notifications and scheduled-reminder diagnostics
- Firebase authentication, cloud synchronization, and account isolation
- Structured feedback submission through a Cloudflare Worker
- Light and dark themes with responsive phone and tablet layouts

## Technology

- Flutter and Dart
- Riverpod for state management
- GoRouter for navigation
- Hive for immediate local persistence and offline queues
- Firebase Authentication and Cloud Firestore
- Flutter Local Notifications
- Cloudflare Workers for feedback delivery

## Requirements

- Flutter compatible with the Dart constraint in `pubspec.yaml`
- Android Studio and an Android SDK for Android development
- A Firebase configuration for the intended environment
- Node.js when working on the feedback Worker
- Windows Developer Mode when Flutter plugin symlinks are required

## Setup

Clone the repository and install Flutter dependencies:

```powershell
git clone <repository-url>
cd ARC
flutter pub get
```

Confirm that `android/app/google-services.json` belongs to the Firebase project
you intend to use. Never commit private service-account credentials or local
Worker secret files.

Run ARC:

```powershell
flutter run
```

## Verification

Run formatting, static analysis, and tests before submitting changes:

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub
```

Focused dashboard and notification checks:

```powershell
flutter test --no-pub test/dashboard_repository_test.dart
flutter test --no-pub test/responsive_ui_test.dart
flutter test --no-pub test/central_notification_test.dart
flutter test --no-pub test/notification_center_screen_test.dart
```

## Android release builds

Create a release APK:

```powershell
flutter build apk --release --no-pub
```

Create the preferred Play Store artifact:

```powershell
flutter build appbundle --release --no-pub
```

Release shrinking is currently disabled because authentication and plugin
reflection must be verified on a physical device before R8 is enabled. The
rules in `android/app/proguard-rules.pro` preserve generic metadata required by
the notification plugin when shrinking is tested again.

## Project layout

```text
android/                              Android host and native integrations
assets/                               Application icons and bundled assets
cloudflare_workers/feedback_delivery Feedback delivery Worker
docs/                                 Maintained application documentation
lib/core/                             Shared services, notifications, and UI
lib/features/                         Feature-oriented application code
lib/providers/                        Shared Riverpod providers
lib/routes/                           Navigation and authentication redirects
test/                                 Unit, widget, security, and sync tests
```

## Data and storage

ARC writes user actions to Hive first and synchronizes authenticated data with
Firestore. User-scoped box names keep local account data isolated. Offline
queues retain failed mutations for a later retry.

Storage growth is controlled through Hive compaction, a bounded Firestore disk
cache, reduced timezone data, dependency pruning, and cleanup for retired
local-only functionality.

## Feedback Worker

From `cloudflare_workers/feedback_delivery`:

```powershell
npm install
npm test
npx wrangler dev
```

Use `.dev.vars.example` as the local configuration template. `.dev.vars` and
credential files are intentionally ignored.

## Documentation

Read [ARC Application Documentation](docs/APP_DOCUMENTATION.md) for the full
architecture, persistence model, synchronization behavior, Android channels,
storage controls, release guidance, and troubleshooting notes.

Security and administration details are also available in
[SECURITY_ADMIN_SYSTEM.md](SECURITY_ADMIN_SYSTEM.md).

## Contribution guidelines

- Keep state contracts typed and repositories responsible for persistence.
- Add regression coverage for repaired production failures.
- Do not render native stack traces or secrets in user-facing screens.
- Preserve account-scoped storage boundaries.
- Update the documentation when setup, architecture, storage, or release
  behavior changes.
