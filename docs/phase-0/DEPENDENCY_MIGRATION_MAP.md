# Dependency migration map

| Flutter dependency (declared version) | Current purpose | Native direction | Complexity / risk |
|---|---|---|---|
| flutter_riverpod 2.5.1 | state/DI | ViewModel + StateFlow; DI library only when needed | High, broad state rewrite |
| hive 2.2.3 / hive_flutter 1.1.0 | local objects, queues, settings, secrets | Room + DataStore + Keystore encryption | Critical data compatibility |
| cloud_firestore 5.0.2 | user cloud data/admin logs | Firebase Firestore main Android module | Medium; retain paths and offline semantics |
| firebase_core 3.1.1 / firebase_auth 5.1.1 | Firebase bootstrap/auth | Firebase Android BoM, core initialization, Auth | High identity/config risk |
| google_sign_in 6.2.1 | Google authentication | Credential Manager + Firebase Auth | Medium; OAuth fingerprints |
| flutter_local_notifications 17.2.1 / timezone 0.9.4 | scheduled reminders | AlarmManager where exact/user-visible, WorkManager where deferrable, notification APIs | High scheduling semantics |
| fl_chart 0.69.0 | dashboard charts | Compose Canvas or a vetted Compose chart library | Direct replacement not required initially |
| shared_preferences 2.2.3 | login rate limit | Preferences DataStore | Low |
| local_auth 3.0.2 | Secret Notes biometric gate | AndroidX BiometricPrompt | Medium/high crypto binding |
| crypto 3.0.3 | PIN/hash/crypto helpers | JCA + Android Keystore; audited KDF/AEAD | Critical |
| go_router 14.2.0 | navigation/redirects | Navigation Compose | Medium |
| intl 0.19.0 | formatting | java.time + ICU/resources | Low/medium |
| uuid 4.4.0 | identifiers | `java.util.UUID` | Low; preserve existing strings |
| flutter_slidable 3.1.1 | swipe actions | Compose gesture/swipe APIs | Low |
| flutter_animate 4.5.0 | animations | Compose animation APIs | Low |
| lucide_icons local override | icon set | Existing vector assets or vetted Compose icon package | Medium visual parity |

Do not add Room, Firebase, WorkManager, Biometric, or navigation dependencies until the feature using them starts; Phase 0 stays minimal. Proposed stable references as of audit: Room 2.8.5, DataStore 1.2.1, WorkManager 2.11.1, and Firebase BoM 35.0.2.
