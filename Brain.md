# ARC Project Brain (Persistent Working Memory)

## 1. ARC Architecture Overview

### Major Feature Folders (`lib/features/`):
- `auth/`: Authentication UI (Login, Register, Forgot Password), `AuthRepository`, `authNotifierProvider`, session persistence and validation.
- `dashboard/`: Dashboard view, daily summaries, task/habit quick actions, greeting headers.
- `habits/`: Habit models, habit repository, habit state notifier, frequency & streak tracking.
- `money_tracker/`: Money Tracker UI (`MoneyScreen`), transactions, monthly budgets, analytics charts, and `moneyAutomationProvider`.
- `secret_notes/`: PIN & biometric-protected notes, AES encryption, lockout policies, local Hive storage.
- `settings/`: Settings UI, theme switches, security preferences, Money Tracker automation toggle.
- `tasks/`: Task models, task notifier, category/priority management, reminder scheduling.
- `user_management/`: `UserContextProvider` resolving active Firebase Auth UID and guest fallback.

### Riverpod / Provider Architecture:
- Root `ProviderScope` in `main.dart`.
- `global_providers.dart`: Central exports for repository providers, user session providers, theme providers.
- Feature-scoped state notifiers (e.g. `moneyProvider`, `monthlyBudgetProvider`, `moneyAutomationProvider`, `authNotifierProvider`).

### Hive & Service Architecture:
- `HiveService` (`lib/core/services/hive_service.dart`): Initializes Hive boxes, isolates per-user boxes using `${boxName}_${userId}`, and orchestrates clean close/flush on logout.
- `NotificationService` (`lib/core/services/notification_service.dart`): Manages local system alarms via `flutter_local_notifications` with timezone support and boot receiver resilience.
- `AppHaptics` (`lib/core/services/app_haptics.dart`): Custom platform channel (`com.arc.arc/haptics`) providing tailored haptic feedback.

### Authentication & User Isolation Structure:
- Primary identity: Firebase Auth UID (`userId`).
- User scoping: User-isolated local Hive storage uses `${userId}_<key>` or dedicated box naming `${boxName}_${userId}`.
- Logout lifecycle: Closes user-specific boxes, halts user-specific listeners, resets session providers.

### Money Tracker Architecture:
- Repository: `MoneyRepository` storing transactions and monthly summaries.
- Monthly Budget: Configured per calendar month (`yyyy-MM`).
- Calculations: Dynamic totals for income, expenses, savings rate, and remaining budget limit.

---

## 2. Money Automation

### Phase 1 Foundation:
- **Local-Only Guarantee**: Zero sync with Firebase, Firestore, or cloud queues. No server processing.
- **Default State**: Feature is strictly **OFF by default** (`automatic_spending_tracking_enabled = false`).
- **Hive Box**: `money_automation_preferences` (registered in `HiveService`).
- **Storage Keys**:
  - `${userId}_automatic_spending_tracking_enabled` (bool, default `false`)
  - `${userId}_automation_prompt_month` (String, format `yyyy-MM`)
  - `${userId}_automation_prompt_count` (int, default `0`)
  - `${userId}_automation_info_dialog_accepted` (bool, default `false`)
- **State Model**: `MoneyAutomationState` (`lib/features/money_tracker/models/money_automation_state.dart`).
- **Repository**: `MoneyAutomationRepository` (`lib/features/money_tracker/repository/money_automation_repository.dart`).
- **Notifier/Provider**: `MoneyAutomationNotifier` / `moneyAutomationProvider` (`lib/features/money_tracker/providers/money_automation_provider.dart`).
- **Prompt Rules**:
  - Dependent on `monthlyBudget > 0.0`.
  - Displayed at most 2 times per calendar month (`effectiveCount < 2`).
  - Automatic counter reset on new calendar month.
  - "No" dismisses prompt for session without enabling.
  - "Yes" displays 3-point information dialog.
  - "Enable" persists opt-in locally.
  - Hidden once enabled.
- **UI Elements**:
  - Prompt card: `AutomaticSpendingPromptCard` above Monthly Budget in `MoneyScreen`.
  - Info dialog: `AutomaticSpendingInfoDialog`.
  - Settings sheet: `MoneyTrackerSettingsSheet` in `CustomTopBar` settings icon.
  - Settings screen: Dedicated section in `SettingsScreen`.

---

## 3. Money Automation Phase 2 (Local Listener Infrastructure)

### Technical Approach & Capture Mechanism:
- **Android Capture Mechanism**: System broadcast receiver `com.arc.arc.MoneySmsReceiver` intercepting `android.provider.Telephony.SMS_RECEIVED` protected by `android.permission.BROADCAST_SMS`.
- **Pre-Inspection Drop**: If `MoneyAutomationBridge.isEnabled == false`, the receiver drops the intent immediately without inspecting or parsing SMS PDUs.
- **Flutter Platform Channels**:
  - MethodChannel: `com.arc.arc/money_automation` (`isAvailable`, `checkPermission`, `requestPermission`, `openAppSettings`, `setListenerEnabled`).
  - EventChannel: `com.arc.arc/money_automation_events` (delivers transient SMS event maps: `sender`, `body`, `timestamp`, `sourceType`).
- **Files Created/Modified**:
  - `android/app/src/main/AndroidManifest.xml`: `<uses-permission android:name="android.permission.RECEIVE_SMS"/>` & `MoneySmsReceiver` registration.
  - `android/app/src/main/kotlin/com/arc/arc/MoneyAutomationBridge.kt`: Local singleton managing channels, permission callbacks, and transient stream sinks.
  - `android/app/src/main/kotlin/com/arc/arc/MoneySmsReceiver.kt`: Broadcast receiver with zero-overhead drop when automation is disabled.
  - `android/app/src/main/kotlin/com/arc/arc/MainActivity.kt`: Configures engine bridge and handles `onRequestPermissionsResult`.
  - `lib/features/money_tracker/models/money_automation_listener_status.dart`: Enum (`disabled`, `permissionRequired`, `ready`, `unavailable`, `error`).
  - `lib/features/money_tracker/models/money_automation_raw_event.dart`: Transient in-memory model with sanitized `toString()`.
  - `lib/features/money_tracker/models/money_automation_state.dart`: Extended with `listenerStatus`.
  - `lib/features/money_tracker/services/money_automation_platform_bridge.dart`: Abstraction + Method/Event channel implementation with web/desktop fallback.
  - `lib/features/money_tracker/services/money_automation_listener_service.dart`: High-level listener lifecycle manager with sanitized logging.
  - `lib/features/money_tracker/providers/money_automation_provider.dart`: `MoneyAutomationNotifier` managing listener health checks, startup reconciliation, and logout disconnection.
  - `lib/features/money_tracker/widgets/money_tracker_settings_sheet.dart`: Status badge & "Enable Access" button.
  - `lib/features/settings/screens/settings_screen.dart`: Status subtitle & permission-required alert banner.
  - `lib/features/money_tracker/screens/money_screen.dart`: Health verification on screen focus.
  - `test/money_automation_phase2_test.dart`: 8 targeted tests for Phase 2 behaviors.

### Permission Lifecycle & Status Model:
- **Statuses**:
  - `disabled`: Feature is OFF or user logged out. Listener is stopped.
  - `permissionRequired`: Feature enabled by user, but Android SMS permission is missing or revoked.
  - `ready`: Feature enabled and Android SMS permission is active. Listener is listening.
  - `unavailable`: Running on unsupported platform (web, desktop, or device without SMS capability).
  - `error`: Unexpected platform or channel failure.
- **Permission Flow**:
  - Strictly requested on user opt-in (`Yes -> Info Dialog -> Enable`) or toggle ON in Settings.
  - Never requested on startup, login, or screen open.
  - System permission revocations detected via `checkListenerHealth()`.

### Zero Raw SMS Persistence & Multi-User Isolation:
- Raw SMS content is NEVER saved to Hive, Firestore, Firebase, logs, or analytics.
- Logging prints only sanitized redactions (e.g., `sender: [REDACTED 10 chars]`, timestamp, body length).
- Logout triggers `onLogout()`, stopping native listener and resetting status to `disabled`.
- User switching isolates preferences by Firebase Auth UID. User B never inherits User A's listening status.

### Handoff to Phase 3 Completed:
- Raw listener events are handed to `MoneyTransactionParser` via `MoneyAutomationNotifier._onRawEventReceived`.
- No raw SMS bodies persisted.

---

## 4. Money Automation Phase 3 (Transaction Parsing, Classification & Deduplication)

### Parser Architecture & Principles:
- **Parser Service**: `MoneyTransactionParser` (`lib/features/money_tracker/services/money_transaction_parser.dart`).
- **Conservative Philosophy**: Favors false negatives over false positives. Uncertain messages are rejected (`unknown`).
- **Input / Output**: `MoneyAutomationRawEvent` (transient) → `ParsedMoneyTransaction` (structured local candidate).
- **Safe Execution**: Wrapped in top-level try-catch; malformed or unparseable SMS never crashes the listener or pipeline.

### Transaction Classification Rules:
- **Enum**: `MoneyTransactionClassification` (`lib/features/money_tracker/models/money_transaction_classification.dart`)
  - `confirmedDebit`: Outgoing spending with identifiable INR amount and completion terms.
  - `credit`: Incoming funds, salary, refunds, cashbacks (REJECTED from spending).
  - `otp`: One-time passwords, verification codes (STRICTLY REJECTED unconditionally).
  - `failed`: Declined, reversed, failed, cancelled payments (REJECTED).
  - `balanceAlert`: Available balance updates, mini statements without debits (REJECTED).
  - `promotional`: Loan offers, pre-approvals, marketing ads (REJECTED).
  - `unknown`: Conversational, non-financial, unsupported currency (REJECTED).
- **Confidence Model**: `MoneyTransactionConfidence` (`high`, `medium`, `low`). Only `confirmedDebit` with `high` confidence proceeds as candidate.
- **ATM Cash Withdrawal**: Classified as `confirmedDebit` (represents cash withdrawal/outgoing debit from user's account). Category is left empty for Phase 4.

### Model & Data Privacy:
- **Model**: `ParsedMoneyTransaction` (`lib/features/money_tracker/models/parsed_money_transaction.dart`).
  - Fields: `amount` (double), `currency` ('INR'), `transactionDateTime` (DateTime), `merchantOrDescription` (String?), `referenceId` (String?), `sourceSender` (String), `classification`, `confidence`, `fingerprint` (String), `accountMask` (e.g. "XXXX1234").
  - Privacy: Zero storage of raw SMS body. Financial account/card numbers masked (`XXXX$digits`). Sanitized `toString()`.

### Deduplication Strategy:
- **Service**: `MoneyDeduplicationService` (`lib/features/money_tracker/services/money_deduplication_service.dart`).
- **Deterministic SHA-256 Fingerprint**:
  - Signature: `$amount|$currency|$referenceId|$sender|$merchant|$accountMask|$date`.
  - Computed via `crypto.sha256`.
- **Deduplication Rules**:
  - If `referenceId` is present: duplicate if reference ID has already been processed for active user.
  - If `referenceId` is absent: duplicate if `fingerprint` has already been processed for active user.
  - Memory set backed by `money_automation_preferences` Hive box (`${userId}_dedup_fingerprints` and `${userId}_dedup_refs`), capped at 500 entries.
  - User logout clears in-memory sets and prevents cross-user pollution.

### Pipeline Integration:
- In `MoneyAutomationNotifier` (`lib/features/money_tracker/providers/money_automation_provider.dart`):
  - Stream: `acceptedCandidateStream` emits high-confidence deduplicated `ParsedMoneyTransaction` instances.
  - Phase 3 strictly STOPS here: **Zero Money Tracker writes** (no `addTransaction`, no category assignment, no budget updates).

### Files for Phase 4 Inspected:
- `lib/features/money_tracker/providers/money_automation_provider.dart` (`acceptedCandidateStream`, `_processIncomingRawEvent`)
- `lib/features/money_tracker/models/parsed_money_transaction.dart`
- `lib/features/money_tracker/repository/money_repository.dart`
- `lib/features/money_tracker/models/transaction_model.dart`

---

## 5. Money Automation Phase 4 (Auto-Create Uncategorized Expenses)

### End-to-End Automatic Expense Creation Flow:
Incoming SMS  
→ `MoneySmsReceiver` (Android native)  
→ `MethodChannelMoneyAutomationBridge`  
→ `MoneyAutomationListenerService`  
→ `MoneyAutomationNotifier._onRawEventReceived`  
→ `MoneyTransactionParser.parse` (conservative debit classification)  
→ `MoneyDeduplicationService.isDuplicate` (SHA-256 fingerprint & ref ID check)  
→ Construct `Transaction`:
  - `type`: `'Expense'`
  - `category`: `'Uncategorized'` (never predicted)
  - `amount`: `parsed.amount`
  - `date`: `parsed.transactionDateTime`
  - `time`: `HH:mm`
  - `notes`: `Paid to <Merchant>` or `ATM withdrawal` (raw SMS bodies strictly omitted)
  - `source`: `'sms_auto'`
  - `automationFingerprint`: `parsed.fingerprint`
→ `MoneyRepository.saveTransaction(tx)`  
→ *Only upon successful save*: `MoneyDeduplicationService.recordProcessed(...)` (transactional atomicity)  
→ Emit to `acceptedCandidateStream` & trigger `onTransactionCreated` to refresh `moneyProvider`  
→ Dynamic budget, expenses, and summaries instantly recomputed.

### Category Handling & UI Integration:
- **Zero Prediction**: Categories are strictly initialized to `'Uncategorized'`. No guessing of Food, Bills, Travel, etc.
- **Card Badge**: In `MoneyScreen`, transactions with `source == 'sms_auto'` display an "Auto-added" badge.
- **Prompt Banner**: Uncategorized transactions render an interactive button `"Add category to this transaction?"` directly beneath the transaction row.
- **Category Picker**: Tapping the prompt opens ARC's expense category bottom sheet. Selecting any category updates `tx.category` in Hive and instantly removes the prompt.
- **Gesture Architecture**: Card uses sibling `InkWell` components for the item tap and the category button tap to eliminate nested gesture hierarchy issues.
- **Details Sheet**: `TransactionDetailsSheet` renders `LucideIcons.helpCircle` for Uncategorized transactions and accurately displays transaction source.

### Atomicity & Resilience:
- **Save Before Finalize**: If `MoneyRepository.saveTransaction(tx)` fails or throws, `recordProcessed` is NOT called. The transaction fingerprint is not locked, allowing safe redelivery or retries without silent dropping.
- **Safe Pipeline Execution**: Provider catches repository / parser failures without throwing or disconnecting the background SMS listener.
- **Multi-User Isolation**: Logout immediately halts listener and unloads deduplication caches. Cross-user isolation guarantees User A's transactions and fingerprints are never visible or active for User B.

### Files for Phase 5 Inspected:
- `lib/features/money_tracker/providers/money_automation_provider.dart`: Stream orchestration, lifecycle observer, and notification lifecycle.
- `lib/features/money_tracker/models/transaction_model.dart`: Transaction model with `source` and `automationFingerprint`.
- `lib/features/money_tracker/screens/money_screen.dart`: Transaction list rendering and category assignment UI.
- `lib/features/money_tracker/services/money_deduplication_service.dart`: Fingerprint deduplication and storage.
- `lib/features/money_tracker/repository/money_repository.dart`: Local offline-first persistence.

---

## 6. Money Automation Phase 5 (Final Hardening, Background Reliability & Release)

### Final Architecture Pipeline:
SMS Arrives  
→ `MoneySmsReceiver` (Android BroadcastReceiver)  
  - Reads `isAutomationEnabled(context)` from native `SharedPreferences` without waiting for Flutter.  
  - If disabled, drops intent immediately with zero CPU/memory overhead.  
→ `MoneyAutomationBridge.kt` (Android Kotlin singleton)  
  - If Flutter engine is active: delivers directly via `EventChannel` sink.  
  - If Flutter engine is launching: buffers up to 5 events in transient memory buffer (`pendingEventsBuffer`).  
  - Flushes buffer immediately upon Flutter `onListen`.  
  - Never writes raw SMS text to Android disk or persistent logs.  
→ `MoneyAutomationPlatformBridge` (Dart bridge abstraction)  
→ `MoneyAutomationListenerService` (Dart listener lifecycle service)  
→ `MoneyAutomationNotifier` (Riverpod state notifier)  
  - Registers `WidgetsBindingObserver` for `AppLifecycleState.resumed`.  
  - Reconciles permission status instantly when returning from Android System Settings.  
→ `MoneyTransactionParser` (Conservative classification & extraction)  
  - Strict classification: only `confirmedDebit` with high confidence.  
  - Rejects OTPs, credits, balance alerts, failed payments, promotions.  
  - Zero storage of raw SMS or sensitive card/account numbers.  
→ `MoneyDeduplicationService` (SHA-256 fingerprint & reference ID check)  
  - Rejects duplicate transactions across restarts.  
  - Deleting an auto-added transaction keeps the fingerprint recorded, preventing phantom re-creations.  
→ `MoneyRepository.saveTransaction(tx)` (Offline-first Hive persistence)  
  - Transaction saved with `category: 'Uncategorized'` and `source: 'sms_auto'`.  
  - Fingerprint locked *only after* repository write succeeds.  
→ UI (`MoneyScreen`):  
  - "Add category to this transaction?" rendered strictly when `tx.category == 'Uncategorized' && tx.source == 'sms_auto'`.  
  - Category selection updates transaction and permanently removes the prompt.

### Multi-User & Lifecycle Isolation:
- **User Logout**:
  - `MoneyAutomationNotifier.onLogout()` resets state to `disabled`.
  - Native listener stopped via platform channel; `clearBufferedEvents()` clears any buffered native events.
  - In-memory deduplication cache cleared; user-scoped Hive boxes closed cleanly.
- **User Switching**:
  - User A's automation preference and fingerprints are isolated from User B.
  - User B starts with their own local settings and empty in-memory deduplication state.

### Platform Support & Operational Limitations:
- **Supported**: Android physical devices and emulators with active SMS capabilities and Granted `RECEIVE_SMS` permission.
- **Graceful Fallback**: Web, iOS, macOS, Windows, Linux return `listenerStatus: unavailable` without throwing or crashing.
- **System Constraints**:
  - Background delivery subject to Android OS power management / OEM aggressive battery optimization.
  - Requires standard banking SMS syntax (debit notifications with identifiable amounts and merchants).
  - Strictly local-first: Zero data transmission to Firebase, Firestore, or external cloud servers.



