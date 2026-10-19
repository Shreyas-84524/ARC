# Firebase integration plan

Status: **Reusable backend identified; configuration and console verification required**.

The Flutter client references Firebase project `arc-productivity-shreyas`, package `com.arc.arc`, Firebase Auth, Firestore, and Google sign-in. `firestore.rules` enforces user-scoped access under `users/{uid}/...`, admin access through a token or profile role, admin-only `admin_logs`, and authenticated read-only legacy root collections.

Reuse the project only after the owner verifies the registered Android app, SHA-1/SHA-256 fingerprints, enabled Email/Password and Google providers, authorized support email, Firestore indexes/rules deployment state, App Check plan, environments, quotas, and backup/export strategy. No cloud resources were changed in Phase 0.

For Phase 1 use Firebase BoM and main modules (`firebase-auth`, `firebase-firestore`), not retired KTX artifacts. Download `google-services.json` from the console only after review; it remains ignored until the team explicitly decides its repository policy. Preserve Firebase UID ownership and collection/document IDs. No Firebase Storage usage was found, and no Functions or Storage rules source was found locally; verify these in the console rather than assuming absence.
