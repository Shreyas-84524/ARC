# ARC Money Automation — Phase 1: Opt-In UX & Local Preference Foundation Report

## 1. Overview & Objective
Phase 1 establishes the opt-in user experience, monthly eligibility rules, user preference settings, and local multi-user isolation foundation for automatic spending tracking in the ARC Money Tracker. 

In strict compliance with privacy guarantees and task instructions:
- **Feature is OFF by default** (`automatic_spending_tracking_enabled = false`).
- **No SMS parsing, notification listeners, background receivers, or sensitive permissions** have been implemented or requested.
- **Preferences are strictly local-only** and never sent or synced with Firebase Firestore or remote queues.

---

## 2. Local Preference Architecture

Preferences are stored in a dedicated Hive box (`money_automation_preferences`) opened and managed through [HiveService](file:///c:/dev/ARC/lib/core/services/hive_service.dart).

### Conceptual Fields & Storage Keys:
- `automatic_spending_tracking_enabled` (bool, default: `false`) — Whether the user has opted in.
- `automation_prompt_month` (String, format `yyyy-MM`) — The calendar month during which the prompt was last shown.
- `automation_prompt_count` (int, default: `0`) — The number of times the prompt was displayed in `automation_prompt_month`.
- `automation_info_dialog_accepted` (bool, default: `false`) — Record of user acknowledging the privacy information modal.

All keys are prefixed with the active user's Firebase UID (`${userId}_<key>`), guaranteeing isolation between multiple authenticated accounts on the same device.

---

## 3. Business Logic & Prompt Rules

The business logic is encapsulated in [MoneyAutomationState](file:///c:/dev/ARC/lib/features/money_tracker/models/money_automation_state.dart) and orchestrated via [MoneyAutomationNotifier](file:///c:/dev/ARC/lib/features/money_tracker/providers/money_automation_provider.dart).

### Prompt Rules:
1. **Monthly Budget Dependency**: The prompt is only eligible if the user has an active Monthly Budget for the current month (`monthlyBudget > 0.0`). If `monthlyBudget == 0.0`, the prompt is never shown and the monthly appearance counter is never incremented.
2. **Disabled State**: Only shown when `automatic_spending_tracking_enabled == false`. Once enabled, the prompt is completely hidden.
3. **Twice-Per-Month Cap**:
   - The prompt can be displayed at most **2 times per calendar month**.
   - If `effectiveCount >= 2`, the prompt is suppressed.
   - When a new calendar month begins (e.g. `2026-10` to `2026-11`), `effectiveCount` evaluates to 0, resetting prompt eligibility.
4. **Session Dismissal ("No" Behavior)**:
   - When the user taps "No", the prompt is dismissed for the duration of that screen visit/session (`isDismissedForSession = true`).
   - Feature remains `false`.
   - The appearance was counted toward the monthly maximum, preventing nagging during subsequent revisits in that session.
5. **Session Active State**:
   - During an active visit where the prompt is displayed, `isPromptActiveThisVisit` keeps the card stably mounted until user interaction, preventing mid-render unmounting or layout flicker.

---

## 4. UI Components

### A. Money Tracker Prompt Card
- [AutomaticSpendingPromptCard](file:///c:/dev/ARC/lib/features/money_tracker/widgets/automatic_spending_prompt_card.dart): Positioned directly above the Monthly Budget section in [MoneyScreen](file:///c:/dev/ARC/lib/features/money_tracker/screens/money_screen.dart).
- Styled according to ARC design standards (accent color border, sparkles badge, clear typography).
- Provides `Yes` and `No` actions with haptic feedback.

### B. Information Popup
- [AutomaticSpendingInfoDialog](file:///c:/dev/ARC/lib/features/money_tracker/widgets/automatic_spending_info_dialog.dart): Displayed when the user taps `Yes`.
- Clearly discloses the three core pillars:
  1. **Only confirmed spending is added** — ARC will only try to detect confirmed debit/spending transactions. OTPs, credits, balance alerts, failed payments, and unrelated messages will not be added.
  2. **Your transaction data stays local** — Transaction SMS/notification processing will happen on your device. Raw messages will not be uploaded to Firebase or cloud services.
  3. **You remain in control** — Automatic spending tracking can be disabled at any time from Money Tracker Settings.
- Action buttons: `Cancel` (leaves disabled) and `Enable` (stores opt-in locally).

### C. Money Tracker Settings & Settings Screen Toggle
- [MoneyTrackerSettingsSheet](file:///c:/dev/ARC/lib/features/money_tracker/widgets/money_tracker_settings_sheet.dart): Opened via the settings gear icon in [CustomTopBar](file:///c:/dev/ARC/lib/core/widgets/top_bar.dart) on the Money Tracker screen.
- [SettingsScreen](file:///c:/dev/ARC/lib/features/settings/screens/settings_screen.dart): Dedicated "Money Tracker" card with "Automatic Spending Tracking" switch.
- When toggling ON from Settings, the info dialog is presented first for explicit user confirmation.
- When toggling OFF, the feature reverts to disabled immediately and becomes eligible for monthly prompts in subsequent visits (subject to the 2x/month cap).

---

## 5. Multi-User Safety & Isolation

- ARC scopes local preferences using `${userId}_<preference_key>`.
- [MoneyAutomationRepository](file:///c:/dev/ARC/lib/features/money_tracker/repository/money_automation_repository.dart) resolves the active `userId` from `userContextProvider` (using Firebase UID).
- Verified in automated tests:
  - User A opting in does not set User B's preference.
  - User A's prompt appearance count does not advance User B's prompt count.

---

## 6. Privacy & Cloud Behavior

- **Zero Remote Writes**: `MoneyAutomationRepository` does not interact with Firestore, Firebase Database, or remote sync queues.
- **Zero Permissions**: No SMS (`READ_SMS`, `RECEIVE_SMS`), notification listener service (`BIND_NOTIFICATION_LISTENER_SERVICE`), or phone state permissions are declared or requested.
- **Zero Transaction Detection**: No background listeners or parsing services are run in Phase 1.

---

## 7. Verification & Quality Gate Results

### A. Static Analysis (`flutter analyze`)
```
Analyzing ARC...
No issues found! (ran in 16.3s)
```

### B. Automated Test Suite (`flutter test`)
- All unit and widget test suites passed:
  - `test/money_automation_model_and_repository_test.dart` (15/15 passed)
  - `test/money_automation_ui_and_flow_test.dart` (10/10 passed)
  - `test/money_edit_removal_test.dart` (3/3 passed)
  - Full project test suite: **356 / 356 tests passed (0 failures)**.

### C. Build Verification
- **Web Build**: `flutter build web` — `√ Built build\web` (completed in 79.0s).
- **Android Debug Compilation**: `flutter build apk --debug` — `√ Built build\app\outputs\flutter-apk\app-debug.apk` (completed in 44.5s).

---

## 8. Files Created & Modified

### New Files Created:
1. `lib/features/money_tracker/models/money_automation_state.dart` — State model and `shouldShowPrompt` evaluation logic.
2. `lib/features/money_tracker/repository/money_automation_repository.dart` — Local-only Hive persistence with user UID scoping and memory fallback.
3. `lib/features/money_tracker/providers/money_automation_provider.dart` — Riverpod StateNotifier managing state transitions.
4. `lib/features/money_tracker/widgets/automatic_spending_prompt_card.dart` — Money Tracker prompt UI card with Yes / No actions.
5. `lib/features/money_tracker/widgets/automatic_spending_info_dialog.dart` — Privacy and transparency info popup with 3 pillars.
6. `lib/features/money_tracker/widgets/money_tracker_settings_sheet.dart` — Money Tracker settings sheet with ON/OFF switch.
7. `test/money_automation_model_and_repository_test.dart` — 15 unit tests verifying defaults, budget dependency, cap, reset, and UID isolation.
8. `test/money_automation_ui_and_flow_test.dart` — 10 widget/integration tests verifying prompt lifecycle, dialog, sheet, and settings toggle.
9. `ARC_MONEY_AUTOMATION_PHASE_1_REPORT.md` — This phase documentation report.

### Modified Files:
1. `lib/core/services/hive_service.dart` — Added `moneyAutomationPreferencesBoxName` to initialization, user box opening, and close lifecycle.
2. `lib/core/widgets/top_bar.dart` — Added `onSettingsPressed` callback support to `CustomTopBar`.
3. `lib/features/money_tracker/screens/money_screen.dart` — Integrated top bar settings action and prompt card above monthly budget section.
4. `lib/features/settings/screens/settings_screen.dart` — Added Money Tracker card with Automatic Spending Tracking toggle.
5. `test/money_edit_removal_test.dart` — Updated test harness with `moneyAutomationProvider` test notifier override.
6. `.gitignore` — Added `lib/**/*.md` rule.

---

## 9. Known Limitations & Next Steps

- **No Active Listener**: Enabling the toggle sets the user's opt-in preference locally but does not yet trigger SMS or notification captures. The app accurately informs the user that automatic tracking preference is saved.
- **Phase 2 Scope**: The actual notification listener, permission workflows, and local-only transaction parsers will be implemented in subsequent phases.
