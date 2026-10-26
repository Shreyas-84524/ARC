# Project Arc — Phase 1: Firebase Feedback Infrastructure Report

**Date:** October 25, 2026  
**Status:** Completed & Verified  
**Target Environment:** Firebase Spark (Free) Plan  

---

## 1. Repository Audit Findings

### Architecture & Tech Stack
- **Framework & Language:** Flutter (Dart SDK `^3.11.3`)
- **State Management:** Riverpod `^2.5.1` with `Provider`, `FutureProvider`, and `StreamProvider`
- **Local Persistence:** Hive `^2.2.3` with user-scoped box isolation (`ensureUserBoxesOpened`)
- **Backend & Cloud Services:** Cloud Firestore `^5.0.2`, Firebase Auth `^5.1.1`, Firebase Core `^3.1.1`
- **Navigation:** GoRouter `^14.2.0` with path-based route guarding (`RouterNotifier`)

### Existing Collections & Security Baseline
- **Active Firestore Collections:** `users`, `tasks`, `habits`, `habitEntries`, `transactions`, `budgets`, `monthlySummaries`, `settings`, `admin_logs`
- **Data Boundary:** User-isolated namespace pattern (`users/{userId}/{document=**}`). Normal users are restricted to their own UID.
- **Administrator System:** Zero plaintext credentials. Authorization is governed server-side via Firebase Authentication custom claims (`role == 'admin'`). Client-controlled documents cannot confer administrative privileges.
- **Sync Architecture:** Scheduled 12-hour sync window (`SyncManager`, `SyncService`) with max 2 full syncs per rolling 24-hour window. The feedback infrastructure operates completely independently of this 12-hour cycle.

### Help & Feedback Section Audit
- In `lib/features/settings/screens/settings_screen.dart`, sections exist for User Profile, App Preferences, Notifications, Security, and Backup & Maintenance.
- **Findings:** No pre-existing Help & Feedback form or user interface existed. In strict accordance with Phase 1 boundary guidelines, all UI creation has been deferred to Phase 2.

---

## 2. Firebase Project and Plan Verification

| Attribute | Value | Verification Source |
|---|---|---|
| **Project ID** | `arc-productivity-shreyas` | `.firebaserc`, `firebase_options.dart`, `firebase projects:list` |
| **Project Number** | `729643761637` | Firebase CLI & MCP Environment |
| **Billing / Plan** | **Spark (Free Plan)** | Firebase Environment (`Billing Enabled: No`) |
| **Active Auth Account** | `shreyas84524@gmail.com` | `firebase login:list` |
| **Firestore Database** | `(default)` | `nam5` location |
| **Cost Impact** | **$0.00** | Uses standard free-tier quotas (rules & 3 composite indexes) |

*Confirmation: No billable services or Blaze upgrades were activated. Existing project associations were strictly preserved.*

---

## 3. Files Created or Modified

### Created Files
- `lib/features/feedback/models/feedback_model.dart`: Typed data model with immutability, `FeedbackCategory`, `FeedbackStatus`, and Firestore conversion helpers.
- `lib/features/feedback/services/feedback_remote_data_source.dart`: Firestore-backed remote data source (`IFeedbackRemoteDataSource`) handling queries, real-time streams, creation, and status updates.
- `lib/features/feedback/repository/feedback_repository.dart`: Repository layer (`IFeedbackRepository`) enforcing authentication validation, message limits, and Firebase UID-based ownership.
- `lib/features/feedback/providers/feedback_providers.dart`: Riverpod providers (`feedbackRepositoryProvider`, `currentUserFeedbackProvider`, `feedbackStatusProvider`, `adminFeedbackListProvider`).
- `test/feedback_model_test.dart`: Unit tests for model serialization, validation, and copy logic.
- `test/feedback_repository_test.dart`: Unit tests for ownership enforcement, input sanitization, and admin operations.
- `scripts/test_firestore_rules.js`: Automated 10-scenario test suite running against the local Firebase Firestore Emulator.
- `arc_feedback_phase1_report.md`: Phase 1 documentation and audit summary.

### Modified Files
- `firestore.rules`: Enhanced by the mandatory `firestore-rules-author` subagent to incorporate the `feedback/{feedbackId}` security boundary, custom claim administrator validation, and CEL safe getters.
- `firestore.indexes.json`: Configured with composite indexes for feedback querying (`userId + createdAt`, `status + createdAt`, `category + createdAt`).
- `package.json` & `package-lock.json`: Added dev-dependency `@firebase/rules-unit-testing: ^6.0.0` for local emulator test automation.

---

## 4. Firestore Feedback Schema

**Collection Path:** `feedback/{feedbackId}`

| Field Name | Firestore Type | Nullable | Description & Constraints |
|---|---|---|---|
| `feedbackId` | `String` | No | Unique feedback identifier; must match document key. |
| `userId` | `String` | No | Firebase Auth UID of the submitter (immutable). |
| `category` | `String` | No | One of: `bug_report`, `feature_request`, `general_feedback`, `app_rating`. |
| `module` | `String` | No | Affected app feature area (1–100 chars, e.g. `task_manager`, `general`). |
| `message` | `String` | No | User feedback narrative (1–5000 chars, non-empty, trimmed). |
| `rating` | `Integer` | Yes | App/feature rating between 1 and 5, or `null`. |
| `contactEmail` | `String` | Yes | Contact email address (max 254 chars, or `null`). |
| `appVersion` | `String` | No | Client app version (e.g. `1.3.5`, max 50 chars). |
| `createdAt` | `Timestamp` | No | Server timestamp set upon creation (`FieldValue.serverTimestamp()`). |
| `status` | `String` | No | Lifecycle status: `submitted`, `emailed`, `reviewed`, `acknowledged`. Defaults to `submitted`. |
| `emailedAt` | `Timestamp` | Yes | Dispatch timestamp managed by trusted delivery workers in later phases. |
| `reviewedAt` | `Timestamp` | Yes | Administrator review timestamp; updatable only by admins. |
| `acknowledgedAt` | `Timestamp` | Yes | Administrator acknowledgement timestamp; updatable only by admins. |
| `notificationDelivered`| `Boolean` | No | In-app or push acknowledgement notification marker; defaults to `false`. |

---

## 5. Security Rules Implemented

The rules were designed and authored following the strict Validator Function Pattern via the `firestore-rules-author` subagent and validated with zero warnings or errors.

### Security Highlights
1. **Zero-Trust Ownership**:
   - Authenticated users can only create feedback where `request.resource.data.userId == request.auth.uid`.
   - Users can only read documents where `resource.data.userId == request.auth.uid`. Cross-user inspection is denied.
2. **Post-Submission Immutability**:
   - Normal users are granted `allow update: if false;` and `allow delete: if false;`.
   - No user can edit feedback content or alter lifecycle statuses.
3. **Verified Administrator RBAC**:
   - Administrative access is guarded via `isCustomClaimAdmin()` checking cryptographically signed token claims (`role == 'admin'` or `admin == true`).
   - Tampering with client-side profile documents (`users/{userId}/settings/profile`) grants **zero** admin rights to the `feedback` collection.
   - Admins can update only `status`, `reviewedAt`, and `acknowledgedAt`. Core submission fields (`userId`, `message`, `createdAt`, etc.) remain immutable.
4. **Reserved Worker Fields**:
   - `emailedAt` and `notificationDelivered` cannot be modified by users or client admins, reserving them for secure backend automation in subsequent phases.
5. **CEL Safe Getters**:
   - All optional and token lookups use `.get(field, defaultValue)` to prevent runtime CEL crashes on missing keys.

```firestore
// User Feedback collection
match /feedback/{feedbackId} {
  allow read: if isAuthenticated() && (resource.data.userId == request.auth.uid || isCustomClaimAdmin());
  allow create: if isValidFeedbackCreate(feedbackId);
  allow update: if isCustomClaimAdmin() && isValidFeedbackUpdate();
  allow delete: if false;
}
```

---

## 6. Firebase CLI Operations Performed

| Operation | Command Executed | Result |
|---|---|---|
| **Version Verification** | `firebase --version` | `15.29.0` verified |
| **Account Check** | `firebase login:list` | Logged in as `shreyas84524@gmail.com` |
| **Project Verification** | `firebase projects:list` | Active: `arc-productivity-shreyas` |
| **Index Inspection** | `firebase firestore:indexes` | Baseline empty; deployed 3 composite indexes |
| **Emulator Test Suite** | `firebase emulators:exec --only firestore` | 10/10 automated scenarios passed |
| **Targeted Deployment** | `firebase deploy --only firestore:rules,firestore:indexes` | Successfully compiled, deployed & released |
| **Post-Deploy Audit** | `firebase firestore:indexes` | 3 composite indexes active in cloud |

---

## 7. Test Results

### 1. Firestore Security Rules Emulator Tests (`scripts/test_firestore_rules.js`)
All 10 mandatory security scenarios were executed against the Firestore Emulator (JDK 25 runtime):

- **Scenario 1:** Authenticated user creates valid feedback -> **PASS**
- **Scenario 2:** Unauthenticated submission is rejected -> **PASS**
- **Scenario 3:** User A cannot read User B's feedback (owner can read own) -> **PASS**
- **Scenario 4:** User cannot forge another user's UID -> **PASS**
- **Scenario 5:** User cannot edit feedback or change status after submission -> **PASS**
- **Scenario 6:** User cannot set review/acknowledgement timestamps or delivery markers -> **PASS**
- **Scenario 7:** User cannot gain admin access via profile document tampering -> **PASS**
- **Scenario 8:** Authorized admin (custom claim) can read all feedback, update review status, but cannot delete or tamper core fields -> **PASS**
- **Scenario 9:** Invalid categories, oversized messages (>5000 chars), and extra field injections are rejected -> **PASS**
- **Scenario 10:** Existing security rules (`users/{userId}`, `admin_logs`, legacy backup collections) continue operating intact -> **PASS**

### 2. Flutter Unit Test Suite
- `test/feedback_model_test.dart`: **5/5 tests passed**
- `test/feedback_repository_test.dart`: **11/11 tests passed**
- Complete project test suite: **395/395 tests passed** (0 failures, 0 regressions)

### 3. Static Code Analysis
- `flutter analyze`: **No issues found!** (Clean across all packages and libraries)

---

## 8. Deployment Status

- **Status:** **DEPLOYED & LIVE**
- **Deployed Services:** Cloud Firestore Security Rules and Composite Indexes
- **Target Project:** `arc-productivity-shreyas`
- **Confirmation:** Verified via Firebase CLI and Firebase REST endpoints. Rules and indexes are live in the `(default)` database in region `nam5`.

---

## 9. Human Interventions Required

- **None required.**
- All CLI authentication, project targeting, rule creation, emulator execution, and targeted deployments executed safely and non-destructively through the Firebase CLI and MCP tooling without requiring manual overrides or credentials in chat.

---

## 10. Pending Phase 2 Requirements

The following features belong strictly to future phases and were intentionally not implemented in Phase 1:
1. **User Interface:**
   - Feedback submission form and modal sheets in `lib/features/settings`.
   - Category selector chips (`Bug Report`, `Feature Request`, `General Feedback`, `App Rating`).
   - Star rating widget and character counters.
2. **Email Delivery Workers:**
   - Brevo / transactional email dispatch workers.
   - Email templates for acknowledging feedback submissions.
   - Automated worker update of `emailedAt`.
3. **Acknowledgement & Notifications:**
   - Deep links for email acknowledgement.
   - Local notification triggers upon admin status change (`notificationDelivered: true`).
4. **Administrative UI:**
   - Admin feedback dashboard screen for filtering, reviewing, and acknowledging tickets.
