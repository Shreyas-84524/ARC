# ARC-Kotlin Phase 5 — System Architecture & Cross-Module Integration

## 1. Executive Summary

Phase 5 completes the native system integration of ARC's Flutter-to-Kotlin migration. All primary feature modules, system services, persistence layers, and security policies are now interconnected into a unified, performant, offline-first native Android architecture.

---

## 2. Integrated Module Ecosystem

The native architecture is organized into 8 interconnected modules:

```
                                  +-----------------------+
                                  |      MainActivity     |
                                  +-----------+-----------+
                                              |
                                              v
                                  +-----------------------+
                                  |       ArcNavHost      |
                                  +-----------+-----------+
                                              |
                  +---------------------------+---------------------------+
                  |                                                       |
                  v                                                       v
        +-------------------+                                   +-------------------+
        |    LoginScreen    | (Unauthenticated)                 |  MainShellScreen  | (Authenticated)
        +-------------------+                                   +---------+---------+
                                                                          |
                  +---------------------+-------------------+-------------+-------------+---------------------+
                  |                     |                   |                           |                     |
                  v                     v                   v                           v                     v
        +-------------------+ +-------------------+ +-------------------+     +-------------------+ +-------------------+
        |   DashboardRoute  | |    TasksRoute     | |    HabitsRoute    |     |    MoneyRoute     | |    VaultRoute     |
        +-------------------+ +-------------------+ +-------------------+     +-------------------+ +-------------------+
                  |                     |                   |                           |                     |
                  |                     |                   |                           |                     |
                  +---------------------+-------------------+---------------------------+                     |
                                        |                                                                     |
                                        v                                                                     |
                        +-------------------------------+                                                     |
                        |      GlobalSearchScreen       | <--- Strictly Excluded From Vault ------------------+
                        +-------------------------------+
                                        |
                                        v
                        +-------------------------------+
                        |        SettingsScreen         |
                        +-------------------------------+
                                        |
                                        v
                        +-------------------------------+
                        |    ArcNotificationManager     | <--- Inexact Alarms (No USE_EXACT_ALARM)
                        +-------------------------------+
```

### Module Matrix

| Module | Persistence | State Management | Cross-Module Dependencies | Vault Exclusion Guarantee |
|---|---|---|---|---|
| **Tasks** | Room v4 (`tasks`) | `StateFlow` + MVVM | Dashboard, Search, Notifications | Full |
| **Habits** | Room v4 (`habits`, `habit_entries`) | `StateFlow` + StreakEngine | Dashboard, Search, Notifications | Full |
| **Dashboard** | In-memory aggregation | `StateFlow` + UDF | Tasks, Habits, Money | Full |
| **Money Manager** | Room v4 (`transactions`, `budgets`) | `StateFlow` + Analytics | Dashboard, Search, Notifications | Full |
| **Secret Notes Vault** | Room v4 Encrypted (`secret_notes`) + Keystore AES-256-GCM | Encrypted in-memory + Auto-lock | Isolated / Local-Only | **100% Zero-Cloud Isolated** |
| **Settings** | DataStore (`arc_preferences`) | `StateFlow` + MVVM | All modules (Theme, Reminders) | Full |
| **Global Search** | In-memory indexing | 300ms Debounced `StateFlow` | Tasks, Habits, Money | **Strict Compile-Time Omission** |
| **Notifications** | Inexact `AlarmManager` | Broadcast Receiver + Compat | Tasks, Habits, Settings | **Strict Runtime Dropping** |

---

## 3. Navigation & Screen Overlay System

Navigation is orchestrated by `MainShellScreen` and `ArcNavHost`:
1. **Primary Bottom Navigation Tabs**:
   - `ArcNavTab.DASHBOARD`: Daily productivity score, streak status, upcoming deadlines, recent activity.
   - `ArcNavTab.TASKS`: Task list, filtering, sorting, task editor bottom sheet.
   - `ArcNavTab.HABITS`: Habit streak tracker, completion toggle, weekly view.
   - `ArcNavTab.MONEY`: Transaction history, income/expense breakdown, monthly analytics.
   - `ArcNavTab.VAULT`: Hardware-bound biometric/PIN protected encrypted notes vault.
2. **Top App Bar Controls**:
   - **Branding & User Badge**: Displays active user initials and admin indicator.
   - **Global Search Button**: Opens `GlobalSearchScreen` with instant query debouncing.
   - **Settings Button**: Opens `SettingsScreen` with notification toggles, theme options, and data stats.
   - **Theme Toggle**: Instantly flips between Dark and Light mode, persisting to DataStore.
   - **Sign Out Button**: Displays confirmation dialog and clears active auth session safely.
3. **Cross-Navigation Deep Links**:
   - Clicking a task in Global Search closes search and focuses `ArcNavTab.TASKS`.
   - Clicking a habit in Global Search closes search and focuses `ArcNavTab.HABITS`.
   - Clicking a transaction in Global Search closes search and focuses `ArcNavTab.MONEY`.
   - Clicking "Secret Notes Vault" in Settings closes settings and navigates to `ArcNavTab.VAULT`.

---

## 4. Policy Compliance and Privacy Verification

1. **Zero-Cloud Vault Isolation**:
   - Secret Notes never appear in search queries, notification reminders, logs, or unencrypted storage.
   - Global Search repository and notification manager interfaces omit note repositories entirely.
2. **No High-Risk Permissions**:
   - Zero SMS permissions declared or requested.
   - Zero `USE_EXACT_ALARM` or `SCHEDULE_EXACT_ALARM` permissions.
   - Battery-friendly inexact alarms (`setAndAllowWhileIdle`) with soft fallback.
3. **Multi-Tenant User Isolation**:
   - Switching user accounts in `DevFakeAuthRepository` immediately purges on-device notifications, re-indexes search results, and refreshes all ViewModel states.
