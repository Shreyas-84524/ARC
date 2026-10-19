# Feature inventory

Status values are based on source and tests, not successful device execution.

| Feature | Status | Evidence / migration note |
|---|---|---|
| Email/password signup, login, reset | Implemented, unverified runtime | `features/user_management/repository/auth_repository.dart`, login/signup/forgot-password views |
| Google sign-in and provider linking | Implemented, configuration-sensitive | auth repository/service and tracked Firebase Android config; SHA fingerprints must be revalidated |
| Admin dashboard/user management/audit log | Implemented, unverified | `features/admin`; Firestore `admin_logs`; authorization depends on token/profile role |
| Tasks | Implemented with tests | task model/repository/screen/editor; Hive type 0; reminders and pending sync queue |
| Habits and daily entries | Implemented with tests | habit type 1, entry type 2, repository/screen/editor |
| Money, budgets, summaries | Implemented with tests | transaction type 3, money repository/screens/widgets |
| Automatic expense detection | Implemented but policy/configuration blocked | native `RECEIVE_SMS` receiver → method/event channel → parser/deduplication; requires Play declaration |
| Dashboard/statistics | Implemented | dashboard repository/screen, charts and aggregate providers |
| Search | Implemented | `global_search_screen.dart` searches app state |
| Local notifications | Implemented, runtime unverified | notification service/reconciler, exact-alarm and boot receivers |
| Settings/theme/sync controls | Implemented | settings model/repository/screen and shared theme |
| Secret Notes | Implemented but security migration high-risk | local-only repository, crypto, PIN, biometrics, secure-window flag, auto-lock; working tree has newer uncommitted edits |
| App-level PIN authentication | Not found | PIN is specific to Secret Notes, not the primary Firebase auth flow |
| Firebase cloud sync/offline queues | Implemented, runtime unverified | per-user Hive boxes, pending queues, full + real-time Firestore sync |

Routes include `/splash`, `/login`, `/signup`, `/forgot-password`, `/admin`, `/`, `/tasks`, `/habits`, `/money`, `/settings`, `/search`, `/notifications`, and Secret Notes setup/unlock/list/editor/settings routes.
