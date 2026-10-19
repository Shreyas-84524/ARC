# Phase 1 Remaining Integrations and Pre-Requisites

## 1. Overview

Phase 1 successfully implemented ARC's offline-first native foundation, UI system, development authentication, and the complete Tasks vertical slice without modifying production Firebase or Flutter resources. This document details the specific external integrations and configurations required for subsequent phases.

---

## 2. Firebase Android Integration

### 2.1 Current State
- **Development Auth:** `DevFakeAuthRepository` provides isolated in-memory authentication seeded with realistic ARC profiles (`shreyas`, `aman`, `rohit`, `demo`).
- **Safety Safeguard:** All session objects carry `isDevFake = true`.
- **Package Identity:** `com.arc.arc.native.dev` (debug build applicationId).

### 2.2 Requirements for Real Firebase Integration (Phase 2)
To transition from `DevFakeAuthRepository` to live Firebase Authentication:
1. **Firebase Console Configuration:** Register the package identity `com.arc.arc.native.dev` in the Firebase Console (either a dedicated development project or within `arc-productivity-shreyas` with strict development isolation).
2. **Configuration File:** Obtain the registered `google-services.json` and place it in `app/`.
3. **Google Sign-In SHA Fingerprints:** Add development debug SHA-1 and SHA-256 keystore fingerprints to the Firebase Console project.
4. **Implementation:** Implement `FirebaseAuthRepository` implementing `IAuthRepository`, utilizing the Credential Manager API and Firebase Auth Android SDK.

---

## 3. Firestore Two-Way Synchronization Engine

### 3.1 Contract and Schema Alignment
The Firestore schema has been fully mapped and verified in `TaskContractTest.kt`:
- **Document Path:** `users/{userId}/tasks/{taskId}`
- **Field Structure:**
  - `title`: String
  - `description`: String
  - `completed`: Boolean
  - `priority`: String ("Must", "Should", "Could", "None")
  - `category`: String
  - `dueDate`: String (ISO-8601 UTC) or null
  - `dueTime`: String ("HH:mm") or null
  - `reminderTime`: String (ISO-8601 UTC) or null
  - `labels`: Array of Strings
  - `subtasks`: Array of Strings
  - `createdAt`: String (ISO-8601 UTC)
  - `updatedAt`: String (ISO-8601 UTC)

### 3.2 Sync Strategy for Phase 2
- **Sync Architecture:** Background worker (`TaskSyncWorker`) utilizing Android Jetpack WorkManager.
- **Conflict Resolution:** Last-Write-Wins (LWW) resolution based on the `updatedAt` ISO timestamp.
- **Offline Outbox:** Introduce a `sync_state` column (`SYNCED`, `PENDING_INSERT`, `PENDING_UPDATE`, `PENDING_DELETE`) in the Room database schema for delta sync.

---

## 4. Hive-to-Room Data Migration

### 4.1 Safeguards
- Real Flutter Hive boxes (`C:\dev\ARC`) were **not** accessed or modified during Phase 1.
- `IHiveToRoomMigrator` defines the deterministic, idempotent migration interface.

### 4.2 Execution Plan for Later Phase
1. Read serialized Hive records from app internal storage upon first launch of migrated app.
2. Convert records using verified domain models (`TaskModel`, `HabitModel`, `TransactionModel`).
3. Execute Room batch insertion within a single database transaction.
4. Mark migration flag as `true` in DataStore preferences to ensure idempotency.
