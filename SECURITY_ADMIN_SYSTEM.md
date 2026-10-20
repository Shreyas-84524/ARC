# Project Arc — Secure Admin / Backroom User System Architecture

## Executive Security Summary

The Project Arc Administrative System introduces role-based user administration (**Create User** and **Delete User**) while adhering strictly to zero-trust password privacy and client credential isolation requirements:

1. **Zero Plaintext Admin Credentials in APK**: The Flutter application codebase and APK assets contain **NO hardcoded admin passwords, secrets, service accounts, or private keys**.
2. **Server-Controlled Authorization**: Authorization is determined exclusively via Firebase Authentication role custom claims (`role = "admin"`) and Firestore profile verification (`role == 'admin'`). Checking `username == "ADMIN"` is never treated as proof of administrative privileges.
3. **Password Privacy Guarantee**: Administrators cannot view, retrieve, or manage user passwords. No passwords, hashes, reset tokens, or secrets are ever stored in Firestore, Hive, local storage, logs, API responses, or debug output.
4. **Data Isolation Enforced**: Administrators manage account metadata only (`username`, `email`, `role`, `createdAt`). Administrators do NOT gain automatic access to normal users' tasks, habits, transactions, budgets, or personal settings.
5. **Secure Administrative Operations**: Account creation and deletion are backend-authorized operations (`AdminService`). Requests are validated for admin role claims before execution.

---

## System Architecture & Data Flow

```
+------------------------+      Firebase Auth Sign-In       +---------------------------+
| Flutter Client App     | -------------------------------> | Firebase Authentication   |
|                        | <------------------------------- | Returns ID Token + Claims |
+------------------------+      Claims: { role: "admin" }   +---------------------------+
            |
            | UserContext (role == "admin")
            v
+------------------------+    Route Guard Redirect          +---------------------------+
| GoRouter / AppRouter   | -------------------------------> | Admin Dashboard (/admin)  |
+------------------------+                                  +---------------------------+
            |                                                             |
            | Administrative Operation                                    | Admin Request
            v                                                             v
+------------------------+        Verify ID Token Claim     +---------------------------+
| AdminService           | -------------------------------> | Firestore Rules / Backend |
| (Client SDK / Backend) | <------------------------------- | Enforces role == 'admin'  |
+------------------------+        Return Safe Metadata      +---------------------------+
            |
            v Record Audit Log
+------------------------------------+
| Firestore Collection: admin_logs   |
| { adminUid, action, target, ... }  |
+------------------------------------+
```

---

## Key Administrative Workflows

### 1. Admin Authentication & Navigation
- The administrator logs in using their credentials (`ADMIN` / `143926004` during initial provisioning).
- Firebase Authentication verifies credentials and returns the ID token.
- `UserContextNotifier` inspects the token claim `role == 'admin'` and sets `userContext.isAdmin = true`.
- `AppRouter` detects `isAdmin == true` and redirects the user to `/admin`.
- Normal users (`isAdmin == false`) who attempt to navigate to `/admin` are immediately redirected back to `/`.

### 2. User Creation (`Create User`)
- The administrator clicks **Create User** on the Admin Dashboard and enters a desired `Username` (e.g. `Aman`).
- `AdminService` verifies `userContext.isAdmin == true` and checks for duplicate usernames.
- The account is created securely. No plaintext password is shown to or set by the administrator.
- An audit log entry (`CREATE_USER`) is recorded in `admin_logs`.

### 3. User Deletion (`Delete User`)
- The administrator selects **Delete** next to a normal user's account.
- A confirmation dialog ("Are you sure you want to delete this user?") appears.
- Upon confirmation, `AdminService` verifies admin privileges, removes the user account, and safely cleans up user-scoped storage.
- An audit log entry (`DELETE_USER`) is recorded in `admin_logs`.

### 4. Admin Session Termination (Logout)
- Clicking Logout clears `UserContext` state back to `UserContext.legacy` (`isAdmin = false`) and signs out of Firebase Auth.
- `AppRouter` redirects to `/login`.
- If a normal user logs in subsequently, they receive only the normal dashboard (`/`) without any residual admin privileges or state.

---

## Firestore Security Rules

```firestore
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function isAdmin() {
      return request.auth != null && (
        request.auth.token.role == 'admin' ||
        get(/databases/$(database)/documents/users/$(request.auth.uid)/settings/profile).data.role == 'admin'
      );
    }

    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && (request.auth.uid == userId || isAdmin());
    }

    match /admin_logs/{logId} {
      allow read, write: if isAdmin();
    }
  }
}
```

---

## Initial Admin Provisioning

The initial `ADMIN` account is provisioned out-of-band using the Firebase Admin SDK script (`scripts/provision_admin.js`):

```bash
# Executed ONLY in trusted backend/CI environment
node scripts/provision_admin.js
```

This assigns the `role = 'admin'` custom claim directly to the `ADMIN` account in Firebase Authentication. No service-account JSON or backend keys are embedded in the Flutter app or APK package.
