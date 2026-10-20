# ARC Money Automation — Phase 2: Local Listener Infrastructure Report

## Executive Summary

Phase 2 builds the **local Android listener infrastructure** for Automatic Spending Tracking in ARC. It bridges system SMS telephonic broadcast events on Android directly into ARC's transient Riverpod layer, completely client-side.

All architectural boundaries, privacy requirements, and quality criteria were strictly enforced:
- **Local-Only Guarantee**: Zero cloud processing, zero Firebase/FCM usage, zero remote queueing.
- **Privacy Enforcement**: Raw SMS bodies are never persisted in Hive, Firestore, Firebase, device logs, or analytics.
- **Pre-Inspection Drop**: If the user has not enabled Automatic Spending Tracking, incoming broadcasts are dropped immediately before inspecting message contents.
- **Explicit Permission Flow**: `RECEIVE_SMS` is requested only when the user explicitly opts in or enables the toggle. Never on startup, login, or screen open.
- **Multi-User Isolation**: Settings and listener state are strictly scoped to the active Firebase Auth UID. User logout halts listening and drops transient events.
- **Phase Boundary**: No transaction classification, deep regex parsing, categorization, or Money Tracker transaction creation was implemented (reserved for Phase 3).

---

## 1. Architectural Components

```
Android OS Telephony Broadcast (`SMS_RECEIVED`)
                      │
                      ▼
   [com.arc.arc.MoneySmsReceiver]
   - Checks `MoneyAutomationBridge.isEnabled`
   - If false: DROPS IMMEDIATELY without PDU parse
   - If true: Extracts sender, body, timestamp
                      │
                      ▼
   [com.arc.arc.MoneyAutomationBridge]
   - MethodChannel: `com.arc.arc/money_automation`
   - EventChannel: `com.arc.arc/money_automation_events`
                      │
                      ▼ (Platform Channel Event Stream)
 [MethodChannelMoneyAutomationBridge]
   - Platform boundary abstraction
   - Web/desktop safe fallback (returns `unavailable`)
                      │
                      ▼
 [MoneyAutomationListenerService]
   - Manages start/stop listening lifecycle
   - Sanitized diagnostic logging (redacted lengths & timestamps only)
                      │
                      ▼
 [MoneyAutomationNotifier / moneyAutomationProvider]
   - Transient `eventStream` (broadcast StreamController)
   - Synchronizes `listenerStatus` (`disabled`, `permissionRequired`, `ready`, `unavailable`, `error`)
   - Reconciles state on app resume / screen visit
   - Detaches listener on user logout
```

---

## 2. File Inventory

| Category | File Path | Description |
|---|---|---|
| **Android Manifest** | `android/app/src/main/AndroidManifest.xml` | Declares `<uses-permission android:name="android.permission.RECEIVE_SMS"/>` and registers `MoneySmsReceiver` with `BROADCAST_SMS` permission. |
| **Native Kotlin** | `android/app/src/main/kotlin/com/arc/arc/MoneyAutomationBridge.kt` | Native singleton managing MethodChannel and EventChannel handlers, runtime permission requests, and transient SMS event dispatch. |
| **Native Kotlin** | `android/app/src/main/kotlin/com/arc/arc/MoneySmsReceiver.kt` | Broadcast receiver that checks `isEnabled` upfront and forwards multi-part SMS messages to the bridge. |
| **Native Kotlin** | `android/app/src/main/kotlin/com/arc/arc/MainActivity.kt` | Wires `MoneyAutomationBridge.setup` into `configureFlutterEngine` and forwards `onRequestPermissionsResult`. |
| **Dart Models** | `lib/features/money_tracker/models/money_automation_listener_status.dart` | `MoneyAutomationListenerStatus` enum (`disabled`, `permissionRequired`, `ready`, `unavailable`, `error`). |
| **Dart Models** | `lib/features/money_tracker/models/money_automation_raw_event.dart` | Transient in-memory event model with sanitized `toString()`. |
| **Dart Models** | `lib/features/money_tracker/models/money_automation_state.dart` | Extended with `listenerStatus` field and copyWith helper. |
| **Dart Services** | `lib/features/money_tracker/services/money_automation_platform_bridge.dart` | Platform bridge abstraction with standard Method/EventChannel implementation and web safety. |
| **Dart Services** | `lib/features/money_tracker/services/money_automation_listener_service.dart` | High-level listener lifecycle manager with safe sanitized logging. |
| **Dart Provider** | `lib/features/money_tracker/providers/money_automation_provider.dart` | `MoneyAutomationNotifier` integrating health verification, permission flows, transient event emission, and logout handling. |
| **UI Integration** | `lib/features/money_tracker/widgets/money_tracker_settings_sheet.dart` | Listener status indicator badge and "Enable Access" button for `permissionRequired`. |
| **UI Integration** | `lib/features/settings/screens/settings_screen.dart` | Subtitle status rendering, permission-required alert banner, and logout listener detachment. |
| **UI Integration** | `lib/features/money_tracker/screens/money_screen.dart` | Calls `checkListenerHealth()` on screen visit to detect external permission changes. |
| **Test Suite** | `test/money_automation_phase2_test.dart` | 8 targeted unit & integration tests validating Phase 2 behaviors. |
| **Memory** | `Brain.md` | Persistent architectural memory updated with Phase 2 documentation. |

---

## 3. Permission & Listener State Machine

```
              ┌──────────────────────────────────────────────┐
              │                   disabled                   │◄─────────────┐
              │ (feature OFF or logged out; listener halted) │              │
              └──────────────────────┬───────────────────────┘              │
                                     │ User enables                         │
                                     ▼                                      │
               [Check Platform / Request Permission]                        │
                 /                   │                   \                  │
       Web/Desktop             User Denies            User Grants           │
               /                     │                     \                │
              ▼                      ▼                      ▼               │
      ┌─────────────┐      ┌────────────────────┐     ┌───────────┐         │ User disables /
      │ unavailable │      │ permissionRequired │     │   ready   │─────────┤ logs out
      └─────────────┘      └─────────┬──────────┘     └─────┬─────┘         │
                                     │                      │               │
                                     │ User re-requests     │ System Revoke │
                                     │ in Settings          │ detected      │
                                     └──────────────────────┴───────────────┘
```

---

## 4. Test Verification & Quality Gates

### A. Phase 2 Targeted Test Suite (`test/money_automation_phase2_test.dart`)
1. **Automation OFF -> Listener Inactive**: Verifies native listener is stopped and raw events are dropped. (PASSED)
2. **Automation ON + Permission -> Ready**: Verifies bridge starts listening, enters `ready` state, and pushes event into `eventStream`. (PASSED)
3. **Permission Denied -> PermissionRequired**: Verifies permission rejection properly sets state without crashing. (PASSED)
4. **Permission Revoked -> Detected by Health Check**: Simulates external revocation via Android Settings; confirms graceful transition to `permissionRequired`. (PASSED)
5. **Logout -> Complete Cleanup**: Verifies `onLogout()` immediately halts native listening and resets status to `disabled`. (PASSED)
6. **Multi-User Isolation**: Verifies User A enabling automation does not leak active listening or state to User B. (PASSED)
7. **Platform Safety**: Verifies unsupported platforms (web/desktop) return `unavailable` safely without `MissingPluginException`. (PASSED)
8. **Transient Event Sanitization**: Verifies `MoneyAutomationRawEvent` redacts body/sender in `toString()` and never exposes raw text. (PASSED)

### B. Regression Test Suites
- `test/money_automation_model_and_repository_test.dart`: All 9 tests PASSED.
- `test/money_automation_ui_and_flow_test.dart`: All 9 tests PASSED.
- `test/money_edit_removal_test.dart`: All 10 tests PASSED.
- **Combined Run**: 36 of 36 tests passing with 0 failures.

### C. Static Analysis & Builds
- `flutter analyze`: **0 issues found** (clean).
- `flutter build web`: **Succeeded** (`√ Built build\web`).
- `flutter build apk --debug`: **Succeeded** (`√ Built build\app\outputs\flutter-apk\app-debug.apk`).

---

## 5. Handoff to Phase 3

Phase 2 is complete. All incoming transaction events are emitted transiently onto `MoneyAutomationNotifier.eventStream`.
**Phase 3 will consume this stream to implement**:
1. Indian bank / financial institution SMS pattern identification.
2. Debit vs credit vs OTP classification (ignoring OTPs, credits, balances, promo spam).
3. Transaction amount, currency, and merchant / payee extraction.
4. Duplicate transaction prevention.
5. Auto-creation of Money Tracker expense entries.
