# Phase 5 Native Settings & Preferences Implementation

## 1. Architectural Overview & Flutter Parity

The native ARC Settings module migrates and replaces Flutter's Riverpod/Hive-based `SettingsModel` (`C:\dev\ARC\lib\features\settings\models\settings_model.dart`) and `SettingsScreen` (`C:\dev\ARC\lib\features\settings\screens\settings_screen.dart`).

The implementation is built entirely in Kotlin using Jetpack Compose (Material 3) and reactive typed DataStore preferences (`AppPreferencesDataStore`).

### Feature Parity Matrix

```
┌──────────────────────────────────────┬──────────────────────┬─────────────────────────┬────────┐
│ Setting Domain                       │ Legacy Flutter       │ ARC-Kotlin Native       │ Status │
├──────────────────────────────────────┼──────────────────────┼─────────────────────────┼────────┤
│ Theme (Dark / Light / System)        │ isDarkMode (bool)    │ themeMode (String enum) │ PARITY │
│ Master Notifications Toggle          │ masterNotifications  │ masterNotifications     │ PARITY │
│ Task Reminders Toggle                │ taskRemindersEnabled │ taskRemindersEnabled    │ PARITY │
│ Habit Reminders Toggle               │ habitRemindersEnabled│ habitRemindersEnabled   │ PARITY │
│ Expense Reminders Toggle             │ moneyRemindersEnabled│ expenseRemindersEnabled │ PARITY │
│ Morning Daily Reminder Time          │ remTime ("09:00")    │ remTime ("09:00")       │ PARITY │
│ Evening Check-in Time                │ eveningCheckinTime   │ eveningCheckinTime      │ PARITY │
│ Expense Reminder Time                │ expenseReminderTime  │ expenseReminderTime     │ PARITY │
│ Automatic Expense Detection Toggle   │ SMS listener toggle  │ isMoneyDetectionEnabled │ PARITY │
│ Secret Vault Security Navigation     │ Route redirect       │ onNavigateToVault link  │ PARITY │
│ Room SQLite Storage Footprint        │ Hive box stats       │ Multi-repo entity counts│ PARITY │
│ Cache Cleaning Action                │ Hive box clearing    │ Safe cache cleanup      │ PARITY │
│ User Profile & Session Controls      │ Auth provider        │ DevFake / Auth session  │ PARITY │
└──────────────────────────────────────┴──────────────────────┴─────────────────────────┴────────┘
```

---

## 2. Typed DataStore Preference Architecture

Preferences are persisted using AndroidX DataStore (`arc_settings.preferences_pb`):
- **Reactive Flow:** Exposed as a single `AppPreferences` state model via `preferencesFlow`.
- **Atomic Edits:** Changes are applied via `DataStore.edit { }` transactions, preventing race conditions.
- **Process Persistence:** Values persist across activity recreation, system theme toggles, and process death.
- **Security Invariant:** Cryptographic keys, notes, PINs, and passwords are NEVER persisted in `AppPreferencesDataStore`. The Secret Vault maintains strict isolation in `VaultPreferencesDataStore` and encrypted Room storage.

---

## 3. Local Data Management & Backup Safeguards

1. **Storage Footprint Visibility:** Users can inspect live record counts for Tasks, Habits, Expenses, and Encrypted Vault Notes directly from SQLite Room queries.
2. **Safe Temporary Cache Cleanup:** `clearLocalCache()` cleans temporary memory structures, query caches, and index buffers without touching persisted SQLite records.
3. **No Unencrypted Full Database Export:** Full unencrypted database dumps and cloud backups are blocked in adherence to ARC's zero-cloud-leakage policy.

---

## 4. Test Verification

Validated by automated unit tests in `SettingsModuleTest.kt`:
1. `theme mode updates and persists reactively` - Verified
2. `notification reminder toggles update correctly` - Verified
3. `reminder times update correctly` - Verified
4. `database statistics reflect repository counts accurately` - Verified
5. `sign out delegates to auth repository` - Verified
