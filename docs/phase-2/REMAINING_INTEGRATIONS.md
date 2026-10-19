# Remaining Integrations Roadmap: Post-Phase 2

## 1. Executive Summary

With the successful completion of Phase 1 (Native Architecture, Authentication Foundation, and Tasks) and Phase 2 (Productivity Dashboard, Habit Tracker, Room Schema v2, and Offline-First Productivity Integration), the core productivity pillars of ARC have been natively established.

This document details the remaining unmigrated modules and platform capabilities from the original Flutter application (`C:\dev\ARC`), providing a precise architectural roadmap for Phase 3 and Phase 4.

---

## 2. Feature Migration Status Matrix

| Module / Capability | Flutter Reference Path | Current Status | Target Phase |
|---|---|---|---|
| **Core Architecture & Design System** | `lib/theme/`, `lib/widgets/` | **COMPLETED** (Phase 1) | — |
| **Tasks Vertical Slice** | `lib/views/tasks/`, `lib/models/task_model.dart` | **COMPLETED** (Phase 1) | — |
| **Room Persistence (v1 & v2)** | Hive boxes (`tasks`, `habits`, `entries`) | **COMPLETED** (Phase 1 & 2) | — |
| **Productivity Dashboard** | `lib/views/dashboard/` | **COMPLETED** (Phase 2) | — |
| **Habit Tracker Vertical Slice** | `lib/views/habits/`, `lib/models/habit_model.dart` | **COMPLETED** (Phase 2) | — |
| **Money Manager / Expense Tracker** | `lib/views/money/`, `lib/models/transaction_model.dart` | **Deferred / Next** | **Phase 3** |
| **Budgeting & Financial Analytics** | `lib/views/money/analytics/` | **Deferred / Next** | **Phase 3** |
| **Secret Notes / Vault** | `lib/views/notes/`, `lib/models/note_model.dart` | **Deferred** | **Phase 4** |
| **Biometric Authentication (Vault)** | `lib/services/biometric_service.dart` | **Deferred** | **Phase 4** |
| **Production Firebase Auth & Google Sign-In** | `lib/services/auth_service.dart` | **Deferred** | **Phase 5** |
| **Cloud Firestore 2-Way Synchronization** | `lib/services/sync_service.dart` | **Deferred** | **Phase 5** |
| **FCM Push Notifications & Reminders** | `lib/services/notification_service.dart` | **Deferred** | **Phase 5** |

---

## 3. Immediate Next Focus: Phase 3 (Money Manager & Finance)

### 3.1 Scope of Phase 3
The Money Manager is the next vertical slice in ARC's migration roadmap:
1. **Room Persistence Evolution (v2 -> v3):**
   - Define `TransactionEntity.java` in `com.arc.arc.core.database`.
   - Update `ArcDatabase.java` to version 3 with explicit `MIGRATION_2_3`.
   - Implement `TransactionDao.java` with date-range queries, category aggregations, and balance calculations.
2. **Domain & Repository Layer:**
   - Implement `ITransactionRepository` and `OfflineFirstTransactionRepository`.
   - Validate compatibility against `TransactionContractTest` (established in Phase 1).
   - Support transaction types (`Income`, `Expense`, `Transfer`), categories, tags, and recurrence.
3. **Financial Analytics & Budgeting Engine:**
   - Port cashflow aggregation and category breakdown calculations.
   - Monthly and weekly budget thresholds and warning triggers.
4. **Jetpack Compose Money Screen:**
   - Replace `MoneyPlaceholderScreen.kt` with full `MoneyScreen.kt`.
   - Balance cards (Total Balance, Monthly Income, Monthly Expense).
   - Filterable transaction history (date, category, payment method).
   - `TransactionEditorSheet` for adding/editing income and expense records.

---

## 4. Phase 4: Secret Notes & Security Vault

### 4.1 Scope of Phase 4
- Secure Notes schema (Room encrypted table or SQLCipher integration).
- AndroidX BiometricPrompt API integration for vault unlock.
- Markdown rendering support in Compose for notes.
- Secure note tagging and archiving.

---

## 5. Phase 5: Cloud Synchronization & Production Infrastructure

### 5.1 Scope of Phase 5
- Transition from `DevFakeAuthRepository` to live `FirebaseAuthRepository` with real `google-services.json` and OAuth credentials.
- WorkManager background synchronization service replicating Room records to Cloud Firestore (`users/{userId}/tasks`, `users/{userId}/habits`, `users/{userId}/transactions`).
- Android NotificationManager / AlarmManager for task and habit reminder notifications.
