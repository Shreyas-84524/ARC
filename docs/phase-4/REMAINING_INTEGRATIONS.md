# Remaining Integrations Heading into Phase 5

## 1. Migration Inventory Status

With Phase 4 complete, the core functional modules of ARC have been successfully migrated to native Kotlin:

| Module | Status | Technology |
|---|---|---|
| **Architecture Foundation** | Complete (Phase 1) | MVVM, UDF, Repository, Dev Auth |
| **Tasks & Productivity** | Complete (Phase 1) | Room V1, Compose, Offline-First |
| **Dashboard & Habits** | Complete (Phase 2) | Room V2, Heatmap, Streak Engine |
| **Money Manager** | Complete (Phase 3) | Room V3, Minor Units (paise), Budget Tracking |
| **Secret Notes & Vault** | Complete (Phase 4) | Room V4, AES-256-GCM, PBKDF2, Biometrics |
| **Settings & Preferences** | Ready for Phase 5 | DataStore, Notifications, Themes, Backup |
| **Global Search & Filter** | Ready for Phase 5 | Cross-module indexing across Tasks, Habits, Money |
| **Notifications & Alarms** | Ready for Phase 5 | WorkManager, AlarmManager, Exact Alarms |
| **Admin & User Management** | Ready for Phase 5 | Multi-role user administration |

---

## 2. Dependencies & Invariants to Preserve in Phase 5

1. **Local-Only Vault Integrity:** Keep Secret Notes strictly local; do not expose or sync them with cloud backup or search services.
2. **Flag Secure & Privacy:** Maintain `FLAG_SECURE` boundaries so global search or notifications do not leak sensitive note contents to notification banners or previews.
