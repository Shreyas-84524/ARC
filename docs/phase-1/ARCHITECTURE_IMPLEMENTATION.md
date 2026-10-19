# Phase 1 Architecture Implementation

## 1. Architectural Philosophy and Overview

The native Kotlin architecture for ARC is built on Google's modern Android architecture guidelines, prioritizing:
- **Offline-First & Local-First:** Room database serves as the single source of truth for application domain state.
- **Unidirectional Data Flow (UDF):** User actions trigger ViewModel intent methods, which coordinate with repositories and update observable `StateFlow<UiState>` instances. Composables collect state in a lifecycle-aware manner.
- **Strict User Scoping & Data Isolation:** All domain entities, queries, mutations, and persistent storage are explicitly partitioned by authenticated `userId`.
- **Zero Production Risk during Development:** Development authentication (`DevFakeAuthRepository`) is strictly tagged with `isDevFake = true` and sandboxed from production Firebase resources.
- **Maintainable Dependency Injection:** Clean manual dependency injection container (`AppContainer`) registered in `ArcApplication`, providing deterministic lifecycle scoping without KAPT/KSP compiler overhead.

---

## 2. Layered Module Structure

The application code in `com.arc.arc` is structured into cohesive architectural boundaries:

```
app/src/main/java/com/arc/arc/
├── core/
│   ├── auth/
│   │   ├── AuthState.kt                     # Sealed hierarchy: Initializing, Authenticated, Unauthenticated, Error
│   │   ├── DevFakeAuthRepository.kt         # In-memory fake auth seeded with ARC dev users (Shreyas, Aman, Rohit, Demo)
│   │   ├── IAuthRepository.kt               # Auth interface supporting state flow, login, logout, user profile
│   │   └── UserSession.kt                   # Current session model with isDevFake safeguard flag
│   ├── database/
│   │   ├── ArcDatabase.java                 # Room database (v1, exportSchema = true)
│   │   ├── TaskDao.java                     # Room DAO with reactive Flow queries and user scoping
│   │   └── TaskEntity.java                  # Room entity matching verified ARC Task schema
│   ├── datastore/
│   │   └── AppPreferencesDataStore.kt       # DataStore Preferences for theme, sync time, onboarding
│   ├── designsystem/
│   │   ├── components/                      # ARC Atomic Compose components: buttons, cards, dialogs, badges, inputs
│   │   └── theme/                           # Color tokens, typography, dimensions, shape, ArcTheme
│   ├── di/
│   │   └── AppContainer.kt                  # Application dependency graph container
│   ├── migration/
│   │   └── HiveToRoomMigrationContract.kt   # Transactional, idempotent Hive-to-Room migration interface
│   └── model/
│       ├── DateTimeUtils.kt                 # ISO-8601 formatting and UTC parsing
│       ├── HabitEntryModel.kt               # Legacy-compatible HabitEntry contract model
│       ├── HabitModel.kt                    # Legacy-compatible Habit contract model
│       ├── TaskMappers.kt                   # Bidirectional mapper between Room TaskEntity and domain TaskModel
│       ├── TaskModel.kt                     # Core Task domain model
│       ├── TaskPriority.kt                  # Task priority enum (MUST, SHOULD, COULD, NONE) + "Much" normalization
│       ├── TransactionModel.kt              # Legacy-compatible Transaction contract model
│       └── UserProfile.kt                   # User profile model
├── features/
│   ├── auth/
│   │   ├── LoginScreen.kt                   # Native Compose login screen with quick-switch dev presets
│   │   └── LoginViewModel.kt                # Login ViewModel with companion ViewModelProvider.Factory
│   ├── dashboard/
│   │   └── DashboardPlaceholderScreen.kt    # Explicit Phase 2 dashboard placeholder
│   ├── habits/
│   │   └── HabitsPlaceholderScreen.kt       # Explicit Phase 2 habits placeholder
│   ├── money/
│   │   └── MoneyPlaceholderScreen.kt        # Explicit Phase 3 money placeholder
│   ├── navigation/
│   │   ├── ArcNavHost.kt                    # Top-level auth-aware root navigation host
│   │   └── MainShellScreen.kt               # 4-tab bottom navigation shell with user profile header and theme toggle
│   └── tasks/
│       ├── data/
│       │   ├── ITaskRepository.kt           # Task repository contract
│       │   ├── OfflineFirstTaskRepository.kt# Room-backed offline-first repository with cloud sync contracts
│       │   └── RoomTaskDataSource.kt        # Room DAO adapter dispatching to Dispatchers.IO
│       ├── TaskCard.kt                      # Task item card with priority color strips and check animation
│       ├── TaskEditorSheet.kt               # ModalBottomSheet for creating/editing tasks with date/time pickers
│       ├── TasksRoute.kt                    # Tasks feature entry point connecting AppContainer to ViewModel
│       ├── TasksScreen.kt                   # Tasks UI with search, filter chips, sort menu, and stats banner
│       └── TasksViewModel.kt                # Tasks presentation logic, reactive filtering, stats, undo snackbar
├── ArcApplication.kt                        # Application subclass initializing AppContainer
└── MainActivity.kt                          # ComponentActivity hosting ArcTheme and ArcNavHost
```

---

## 3. Toolchain & Compilation Strategy

### AGP 9.4.1 Built-in Kotlin Support
Android Gradle Plugin 9.4.1 introduces native built-in Kotlin compilation, eliminating the legacy external `kotlin-android` Gradle plugin.

### Room Java Annotation Processor Interop
- **Constraint Identified:** AGP 9.4.1 built-in Kotlin support does not support legacy `id("kotlin-kapt")`. Furthermore, KSP does not yet publish a compiler plugin for Kotlin 2.4.21.
- **Architectural Solution:** Room database, DAO, and Entity definitions are authored in standard Java (`ArcDatabase.java`, `TaskDao.java`, `TaskEntity.java`) and compiled via `annotationProcessor(libs.androidx.room.compiler)` with `javac`.
- **Kotlin Interoperability:** Clean Kotlin extension mappers (`TaskMappers.kt`) convert between Java Room entities and immutable Kotlin data models (`TaskModel.kt`). Repository and UI layers remain 100% Kotlin Coroutines and Compose. Schema export is enabled at `app/schemas/com.arc.arc.core.database.ArcDatabase/1.json`.

---

## 4. State Management and Concurrency

- **State Flows:** State is exposed as immutable `StateFlow<T>` from repositories and ViewModels.
- **Dispatchers:** All database I/O is constrained to `Dispatchers.IO` via `RoomTaskDataSource`.
- **Cancellation & Scoping:** Coroutines launched in ViewModels utilize `viewModelScope`, ensuring automatic cancellation when composables leave the backstack.
- **Reactive UI Observation:** Composables observe state via `collectAsState()` and `collectAsStateWithLifecycle()`, triggering minimal recompositions.
