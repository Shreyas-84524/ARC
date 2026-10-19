# ARC Kotlin Agent Instructions

1. **Review Phase Handoffs:** Before starting work, review `docs/phase-0/`, `docs/phase-1/`, `docs/phase-2/`, `docs/phase-3/`, `docs/phase-4/`, `docs/phase-5/`, and all files under `docs/phase-6/`, particularly `docs/phase-6/PHASE_6_FINAL_REPORT.md`, `docs/phase-6/FIREBASE_AUTH_INTEGRATION.md`, `docs/phase-6/FIRESTORE_SYNC_IMPLEMENTATION.md`, `docs/phase-6/LEGACY_DATA_MIGRATION.md`, and `docs/phase-6/PRODUCTION_READINESS_CHECKLIST.md`.
2. **Workspace Boundaries:** `C:\dev\ARC` is the active native Kotlin workspace. Treat both `C:\dev\ARC-Backup` (the complete legacy Flutter snapshot) and `C:\dev\ARC-Kotlin` (the original native-source provenance checkout) as strictly read-only. Never edit, format, generate into, clean, reset, or restructure either reference without explicit user permission.
3. **Architecture & Persistence Standards:**
   - Follow the established native architecture in `com.arc.arc`.
   - Domain models reside in `core/model/`.
   - Room database entities and DAOs reside in `core/database/` (authored in Java to interoperate with AGP built-in Kotlin annotation processing), with Kotlin extension mappers alongside the persistence layer.
   - Reusable UI elements must use `ArcTheme` tokens in `core/designsystem/`.
   - ViewModels must implement a companion `ViewModelProvider.Factory` and be retrieved via `viewModel(factory = ...)`.
4. **Data Contract Integrity:** Preserve verified record schemas, timestamp formatting (ISO-8601 UTC / epoch ms), enum mappings, composite key patterns (`${habitId}_${dateStr}` for HabitEntry, `${ownerUid}_${month}` for Budget), non-floating-point financial math (integer paise `Long`), and user scoping (`ownerUid` / `userId`).
5. **Security Safeguards:**
   - Never commit credentials, keystores, production `google-services.json`, service accounts, `.env` secrets, or local databases.
   - Development auth must maintain `isDevFake = true` and keep development records strictly isolated from production Firebase.
   - Never request or add restricted SMS permissions without an approved Play Store policy exception.
   - **Secret Vault Integrity:** Secret notes are strictly local-only and must never sync to Firebase. Encrypt them with the hardware-backed Android Keystore AES-256-GCM master key and PBKDF2 HMAC-SHA256 derived keys. Dynamic `FLAG_SECURE` window protection must protect vault screens.
   - **Zero-Cloud Vault Guarantee:** Secret Notes are prohibited from global search indexing, notifications, and Cloud Firestore sync via fatal assertion (`assertVaultExcluded`).
   - **Battery & Policy Safety:** Never declare `USE_EXACT_ALARM` or `SCHEDULE_EXACT_ALARM`; use inexact alarms with graceful fallback.
6. **Toolchain Discipline:** Do not reintroduce legacy plugins such as `id("kotlin-kapt")` or external `kotlin-android`, which are incompatible with AGP 9.4.1 built-in Kotlin support.
7. **Quality Gates:** Every phase or major feature must verify clean compilation, 100% test pass rate (`:app:testDebugUnitTest`), zero Android Lint errors (`:app:lintDebug`), and successful packaging (`:app:assembleRelease` and `:app:bundleRelease`).
8. **Git Best Practices:** Use conventional commits. Never force-push, rewrite history, discard existing work, or push the migration branch to the legacy Flutter remote without explicit authorization.
