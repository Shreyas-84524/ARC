# Project Arc — Username Customization & Google Profile Synchronization Report

**Release Date:** October 26, 2026  
**Implementation Phase:** Username Customization & Profile Synchronization  
**Environment:** Flutter 3.x / Dart 3.x / Firebase Spark (Free Tier) / Hive Local Storage  

---

## 1. Executive Summary

This phase addresses the user identity and profile synchronization architecture in Project Arc. Previously, users could not customize their in-app display name, outdated Google account names persisted indefinitely due to one-way conditional fallback checks, and full display names with surnames or trailing spaces cluttered the dashboard greeting.

We have engineered and validated an end-to-end, offline-first profile management solution:
1. **In-App Display Name Customization:** Users can edit their display name via an accessible dialog in Settings & Profile with live validation, whitespace collapsing, emoji rejection, length bounds (2–50 characters), and comprehensive international Unicode support (including Devanagari, Bengali, Tamil, Telugu, Malayalam, Gujarati, Gurmukhi, Kannada, Latin accents, and umlauts).
2. **Explicit Attribution & Precedence Hierarchy:** The user profile schema now tracks `displayNameSource` (`'user_customized'` vs `'google'` vs `'default'`) and `displayNameUpdatedAt`. When a user customizes their name, it is permanently locked against Google Sign-In overwrites.
3. **Stale Google Name Resolution:** When a user who has *not* customized their name signs in via Google, any updated name from their Google Account is immediately reconciled and persisted across Firestore and local Hive cache.
4. **First-Name-Only Dashboard Greeting:** The dynamic time-of-day greeting extracts *only* the first non-empty word from the display name across English, Indian, and international Unicode scripts (e.g. "Shreyas Shigwan" &rarr; "Good Morning, Shreyas", "श्रेयस शिगवण" &rarr; "Good Morning, श्रेयस").
5. **Hive-First Offline Synchronization:** Local profile state is cached in the user-scoped Hive box (`settings_box_$userId`, key `'cached_user_profile'`). If the user modifies their name while offline, changes apply immediately locally, a mutation flag (`'profile_sync_pending': true`) is queued, and automatic remote sync flushes to Firestore upon reconnection without any 12-hour cooldown timer.

---

## 2. Root Cause Analysis of Stale Google Profile Names

Our architectural audit revealed two critical flaws in the legacy implementation that prevented Google name updates from reflecting in-app:

### Flaw 1: One-Way Fallback Guard in `AuthRepository.signInWithGoogle()`
```dart
// Legacy auth_repository.dart line 302
displayName: existingProfile.displayName.isNotEmpty
    ? existingProfile.displayName
    : (user.displayName ?? existingProfile.displayName),
```
*Impact:* Once a user profile was created during the first login, `existingProfile.displayName` was non-empty. Subsequent Google logins always evaluated `existingProfile.displayName.isNotEmpty` to `true`, discarding the fresh `user.displayName` provided by the Google credential and freezing outdated names forever.

### Flaw 2: Hive & Firestore Bypass in `UserContextNotifier._setFromFirebaseUser()`
```dart
// Legacy user_context_provider.dart lines 49-56
final displayName = (user.displayName != null && user.displayName!.isNotEmpty)
    ? user.displayName!
    : ...
```
*Impact:* On application boot and during `authStateChanges()` emissions, `UserContextNotifier` constructed an in-memory `UserProfile` directly from Firebase Auth's local cached token (`user.displayName`), completely ignoring any customized name persisted in Firestore (`users/{uid}`) or local Hive user settings boxes.

---

## 3. Architecture & Technical Design

```
┌────────────────────────────────────────────────────────────────────────┐
│                        Project Arc Client UI                           │
├───────────────────────────────────┬────────────────────────────────────┤
│   TopBar (GreetingUtils)          │   SettingsScreen & Dialog          │
│   "Good Morning, Shreyas"         │   Edit Display Name Modal          │
│   (extracts first name only)      │   (Validates Unicode, rejects emoji)
└─────────────────┬─────────────────┴──────────────────┬─────────────────┘
                  │                                    │
                  ▼                                    ▼
       ┌─────────────────────┐              ┌─────────────────────┐
       │ userContextProvider │◄─────────────┤     AuthService     │
       │ (StateNotifier)     │              └──────────┬──────────┘
       └──────────┬──────────┘                         │
                  │                                    ▼
                  │                         ┌─────────────────────┐
                  │                         │   AuthRepository    │
                  │                         └──────────┬──────────┘
                  ▼                                    ▼
┌───────────────────────────────────┐       ┌────────────────────────────┐
│      Hive Local Storage           │       │    Cloud Firestore Remote  │
│  settings_box_$userId             │◄─────►│    users/{uid}             │
│  - cached_user_profile            │       │    users/{uid}/settings/   │
│  - profile_sync_pending           │       │      profile               │
└───────────────────────────────────┘       └────────────────────────────┘
```

### 3.1 Data Model Extensions (`UserProfile`)
We augmented `UserProfile` in `lib/features/user_management/models/user_profile.dart`:
- `displayNameSource` (`String`, default `'default'`): Tracks provenance (`'user_customized'`, `'google'`, `'default'`).
- `displayNameUpdatedAt` (`DateTime?`): Timestamp of the last display name update.
- `bool get isCustomizedName => displayNameSource == 'user_customized'`: Clean helper property for business logic checks.

All serialization methods (`toMap`, `fromMap`, `copyWith`, `==`, `hashCode`) were updated and round-trip verified.

### 3.2 Display Name Validation Engine (`DisplayNameUtils`)
Located at `lib/core/utils/display_name_utils.dart`, this zero-dependency utility enforces strict sanitization without relying on regex lookarounds or unsupported Dart VM Unicode properties:
- **Normalization:** Trims leading/trailing whitespace and collapses consecutive internal whitespace/newlines/tabs into a single standard space.
- **First Name Extraction:** Returns the first non-empty word, preserving native capitalization and script encoding.
- **Emoji & Pictograph Rejection:** Evaluates rune code points across all Unicode emoji blocks (`0x1F600`–`0x1F64F`, `0x1F300`–`0x1F5FF`, `0x1F680`–`0x1F6FF`, `0x2600`–`0x26FF`, `0x2700`–`0x27BF`, `0x1F900`–`0x1F9FF`, `0x1FA70`–`0x1FAFF`, etc.).
- **Legitimate Unicode Support:** Permits alphabetic characters across Latin, Devanagari (Hindi/Marathi), Bengali, Gurmukhi, Gujarati, Oriya, Tamil, Telugu, Kannada, Malayalam, Sinhala, Cyrillic, Greek, Arabic, and CJK ideographs, along with Zero Width Joiner/Non-Joiner (`\u200C`, `\u200D`).
- **Punctuation Rules:** Permits spaces, periods, apostrophes, and hyphens within names (e.g. `Dr. John Smith`, `O'Connor`, `Aman-Sharma`). Rejects numbers, HTML/XML tags (`<script>`), and special symbols (`@`, `#`, `$`, `%`, etc.).
- **Length Boundaries:** Strictly enforces 2 to 50 characters.

### 3.3 Google Sign-In Reconciliation Strategy
In `AuthRepository.signInWithGoogle()`, display name resolution follows deterministic precedence:
```dart
final isCustomized = existingProfile.displayNameSource == 'user_customized';
String resolvedDisplayName;
String resolvedSource;
DateTime? resolvedUpdatedAt = existingProfile.displayNameUpdatedAt;

if (isCustomized) {
  // 1. User customization ALWAYS takes precedence over Google account changes
  resolvedDisplayName = existingProfile.displayName;
  resolvedSource = 'user_customized';
} else {
  // 2. If not customized, update with fresh Google name if available
  final freshGoogleName = (user.displayName != null && user.displayName!.trim().isNotEmpty)
      ? user.displayName!.trim()
      : null;
  if (freshGoogleName != null && freshGoogleName.isNotEmpty) {
    resolvedDisplayName = freshGoogleName;
    resolvedSource = 'google';
    resolvedUpdatedAt = now;
  } else {
    resolvedDisplayName = existingProfile.displayName.isNotEmpty
        ? existingProfile.displayName
        : (user.email != null ? _displayNameFromEmail(user.email!) : 'Google User');
    resolvedSource = existingProfile.displayNameSource;
  }
}
```

### 3.4 Hive-First Caching & Offline Resilience
- **Immediate Local Persistence:** Whenever `updateDisplayName` is invoked, the updated `UserProfile` is written to `settings_box_$userId` under key `'cached_user_profile'`.
- **Offline Mutation Queue:** If the Firestore remote write fails (e.g. device is offline), `profile_sync_pending` is marked `true` in the user's settings box.
- **Reconciliation & Flusher:** When the app launches or `_setFromFirebaseUser` initializes, `UserContextNotifier` immediately serves the cached profile from Hive for zero-latency UI rendering, then triggers `_reconcileProfile()` in the background to flush any pending offline mutations and reconcile with Firestore.

### 3.5 UI Integration (`EditDisplayNameDialog`)
Integrated into `lib/features/settings/screens/settings_screen.dart` within the **Account & Security** card:
- Tapping the pencil icon or the "Edit Display Name" link opens `EditDisplayNameDialog`.
- Autofocused text field pre-populated with current display name.
- Live character counter (`X / 50`).
- Clear button (`suffixIcon` with `LucideIcons.x`).
- Real-time error feedback displaying inline danger text upon invalid input.
- Animated Save button with loading indicator and immediate floating SnackBar feedback upon success.

---

## 4. Verification & Automated Test Results

A comprehensive test suite was executed covering all unit, model, repository, synchronization, and widget interaction paths.

### 4.1 Test Execution Summary

| Test Suite | Tests Run | Result | Coverage Area |
| :--- | :---: | :---: | :--- |
| `test/display_name_utils_test.dart` | 8 | **PASSED** | Normalization, first-name extraction, Indian Unicode, emojis, markup |
| `test/dashboard_greeting_user_test.dart` | 7 | **PASSED** | Time-of-day greeting with first name extraction, user switching |
| `test/username_customization_test.dart` | 17 | **PASSED** | Precedence rules, Google sync, offline queueing, restart, dialog UI |
| `test/step5_final_auth_isolation_test.dart` | 5 | **PASSED** | Multi-user box isolation, UID paths |
| `test/session_persistence_restoration_test.dart` | 4 | **PASSED** | Splash routing, session restore on reboot |
| **Total Automated Tests** | **41** | **ALL PASSED** | Zero failures across full regression suite |

### 4.2 Static Analysis (`dart analyze`)
```
Analyzing ARC...
No issues found!
```
The entire codebase passed static analysis with **zero errors, zero warnings, and zero linter hints**.

---

## 5. Security & Production Checklist

1. **Injection & XSS Protection:** Name input sanitization strips control characters (`0x00`–`0x1F`, `0x7F`–`0x9F`) and rejects markup (`<`, `>`, `&`), preventing stored XSS or injection vulnerabilities.
2. **Access Control & UID Scope:** All Hive writes target `settings_box_$userId`. All Firestore writes target `users/{uid}` and `users/{uid}/settings/profile`, fully authorized under `firestore.rules` where `request.auth.uid == userId`.
3. **No Paid Dependencies:** Entirely compliant with Firebase Spark (Free Tier), Brevo Free, and Cloudflare Workers Free. No Cloud Functions or Blaze requirements introduced.
4. **Offline Resilience:** App operates with 100% functionality without network connectivity. Offline name updates persist across app restarts and sync automatically when network connectivity resumes.
