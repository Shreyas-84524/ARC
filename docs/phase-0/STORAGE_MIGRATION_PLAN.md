# Storage migration plan

Status: **Design complete; production migration intentionally not executed**.

## Existing storage

Hive type IDs: Task 0, Habit 1, HabitEntry 2, Transaction 3. Typed boxes are `tasks_box`, `habits_box`, `habit_entries_box`, and `money_box`. Untyped boxes include three pending-sync queues, `settings_box`, Secret Notes security/preferences/data, and money-automation preferences. Authenticated data uses the suffix `_<Firebase UID>`; legacy unsuffixed boxes remain as migration sources.

Firestore uses `users/{uid}/tasks`, `habits`, `habitEntries`, `transactions`, `budgets`, `monthlySummaries`, and `settings/profile`. Legacy root collections remain read-only by rules. IDs are client strings/UUIDs; model timestamps are serialized ISO-8601 strings. The sync engine performs Hive-first writes, queues mutations, full pull/push, and real-time listeners; explicit conflict-resolution beyond updated timestamps was not found.

Secret Notes are deliberately local-only. Their records and security metadata must never enter Firestore. The current crypto/PIN implementation must receive a dedicated cryptographic review before any conversion.

## Native design

- Room tables: tasks, habits, habit_entries, transactions, budgets, monthly_summaries, pending_mutations, and sync_metadata, all owner-scoped.
- DataStore: non-sensitive preferences and UI settings.
- Android Keystore-backed keys + authenticated encryption: Secret Notes and secret security material.
- Firebase Android SDK repositories: existing remote collections.
- WorkManager: network-constrained retry/reconciliation, not exact reminders.

## Deterministic migration

Use the production application ID only in a separately approved signed migration build. Read Hive files without mutating them, decode known adapters, validate schema/field types, and write into a new Room database transactionally. Maintain a migration journal and source fingerprint; reruns must upsert by `(ownerUid, id)` and remain idempotent. Validate per-box counts, stable IDs, nullable fields, ISO timestamps, habit-entry foreign keys, and field-level hashes. Mark completion only after validation; retain Hive files and provide rollback to the Flutter build. Interrupted runs roll back the active Room transaction and resume from the journal. If Kotlin-compatible Hive decoding is not trustworthy, ship a signed transitional Flutter export producing an authenticated, encrypted archive and import that archive in Kotlin.
