# Migration roadmap

1. **Phase 1 foundation:** test harness, navigation/auth state shell, design tokens, Room schema prototypes, Firebase dev configuration, and migration fixtures. No real-user migration.
2. **Tasks and habits:** port models/repositories first, verify Hive/Firestore field parity, then screens and reminders.
3. **Money:** manual tracking, budgets, summaries, charts; add automatic ingestion only after Play-policy decision and privacy review.
4. **Settings/dashboard/search/notifications:** integrate shared data and validate scheduling across reboot/time-zone changes.
5. **Secret Notes:** separate security workstream with threat model, cryptographic review, Keystore design, migration/rollback tests, and biometric fallback UX.
6. **Admin and operational hardening:** claims/rules testing, audit logging, App Check, observability, release signing, shrinker rules.
7. **Migration release:** signed internal rollout, synthetic and copied-device backups, interrupted migration tests, staged rollout, rollback window, and performance/regression gates.

Each slice follows contract tests → data migration fixture → repository → ViewModel → Compose UI → accessibility/screenshot tests → release benchmark.
