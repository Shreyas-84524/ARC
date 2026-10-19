# Phase 1 Tasks Module Implementation

## 1. Overview and Objectives

The Tasks module represents ARC-Kotlin's first fully functional, production-oriented vertical slice. It provides a complete offline-first task management experience matching the original Flutter application's capabilities, data contracts, and visual styling, backed by Room persistence and reactive Kotlin StateFlow observation.

---

## 2. Component Architecture

The module spans from persistent storage to Compose presentation:

```
Tasks Feature Stack:
┌────────────────────────────────────────────────────────┐
│ TasksScreen & TaskEditorSheet (Jetpack Compose UI)     │
└───────────────────────────▲────────────────────────────┘
                            │ observes StateFlow<TasksUiState>
                            │ calls intent methods
┌───────────────────────────┴────────────────────────────┐
│ TasksViewModel (State management & filtering logic)    │
└───────────────────────────▲────────────────────────────┘
                            │ observes Flow<List<TaskModel>>
                            │ executes CRUD coroutines
┌───────────────────────────┴────────────────────────────┐
│ OfflineFirstTaskRepository (ITaskRepository)           │
└───────────────────────────▲────────────────────────────┘
                            │ maps TaskEntity <-> TaskModel
┌───────────────────────────┴────────────────────────────┐
│ RoomTaskDataSource & TaskDao (Room Persistence, SQLite)│
└────────────────────────────────────────────────────────┘
```

---

## 3. Data Layer: Offline-First Repository

### 3.1 Interface Contract (`ITaskRepository.kt`)
Defines the reactive contract:
- `observeTasks(userId: String): Flow<List<TaskModel>>`
- `getTaskById(taskId: String, userId: String): TaskModel?`
- `upsertTask(task: TaskModel)`
- `deleteTask(taskId: String, userId: String)`
- `toggleTaskCompletion(taskId: String, userId: String): TaskModel?`
- `syncPendingQueue(userId: String): Result<Unit>` (Cloud sync contract prepared for Phase 2)

### 3.2 Room Implementation (`OfflineFirstTaskRepository.kt`)
- All writes are committed locally to Room via `RoomTaskDataSource` on `Dispatchers.IO`.
- `observeTasks` emits continuously via SQLite triggers whenever tasks change.
- User scoping is strictly enforced on all queries and mutations: `WHERE user_id = :userId`.

---

## 4. Presentation Layer: TasksViewModel

### 4.1 State Structure (`TasksUiState`)
```kotlin
data class TasksUiState(
    val allTasks: List<TaskModel> = emptyList(),
    val filteredTasks: List<TaskModel> = emptyList(),
    val statistics: TaskStatistics = TaskStatistics(),
    val selectedFilter: TaskStatusFilter = TaskStatusFilter.ALL,
    val selectedCategory: String? = null,
    val selectedSort: TaskSort = TaskSort.DUE_DATE,
    val searchQuery: String = "",
    val isLoading: Boolean = false,
    val isEditorOpen: Boolean = false,
    val editingTask: TaskModel? = null,
    val userMessage: String? = null,
    val recentlyCompletedTask: TaskModel? = null,
)
```

### 4.2 Filtering and Sorting Capabilities
- **Status Filters:**
  - `ALL`: All non-deleted tasks.
  - `PENDING`: Non-completed tasks whose due date has not passed.
  - `UPCOMING`: Non-completed tasks due within the next 7 days.
  - `OVERDUE`: Non-completed tasks with a due date strictly in the past.
  - `COMPLETED`: Completed tasks.
- **Category Filter:** Dynamic filtering matching categories from `TaskConstants.CATEGORIES` ("General", "Work", "Personal", "Health", "Finance", "Study").
- **Search Query:** Real-time query matching task title, description, or labels.
- **Sorting Options:**
  - `DUE_DATE`: Due date ascending (nulls last) followed by due time.
  - `PRIORITY`: Priority descending (`MUST` > `SHOULD` > `COULD` > `NONE`).
  - `CREATION_DATE`: Created timestamp descending (newest first).
  - `ALPHABETICAL`: Case-insensitive title ascending.

### 4.3 Real-Time Statistics Engine
Computes real-time metrics across the active user's tasks:
- `totalTasks`, `completedTasks`, `pendingTasks`, `overdueTasks`, `upcomingTasks`, `todayTasks`.
- `completionPercentage`: Integer 0-100% computed as `(completed / total) * 100`.

### 4.4 Completion Toggle with Undo Support
- When a task's checkbox is tapped, its completion status is toggled and persisted immediately.
- If completed, the task reference is captured in `recentlyCompletedTask` and a Snackbar event is triggered with an "Undo" action.
- Invoking `undoToggleCompletion()` reverts the completion status locally and updates the statistics.

---

## 5. UI Layer: Compose Presentation

### 5.1 `TasksScreen.kt`
- **Top Summary Banner:** Displays task completion percentage, circular progress indicator, and active count chips (Pending, Today, Overdue).
- **Search and Filter Bar:** Search input field with real-time text debouncing, scrollable category chips, and sort dropdown menu.
- **Filter Tabs:** Scrollable row of filter chips (`All`, `Pending`, `Upcoming`, `Overdue`, `Completed`) with badge counts.
- **Task List:** Animated, scrollable `LazyColumn` rendering `TaskCard` items.
- **Empty States:** Dynamic `ArcEmptyState` with distinct illustrations for "No tasks found", "No overdue tasks", or "All caught up".
- **Floating Action Button:** Prominent ARC primary FAB with an `Add` icon to trigger task creation.
- **Snackbar Host:** Native Material 3 snackbar host displaying action messages with interactive "Undo".

### 5.2 `TaskCard.kt`
- Clean Material 3 card styled with ARC elevation and subtle borders.
- Left-edge colored priority indicator strip (Red for Must, Orange for Should, Blue for Could, Slate for None).
- Checkbox with animated strikethrough title transition upon completion.
- Formatted due date and time chips with visual warning coloring when overdue.
- Category tag and priority badge (`ArcPriorityBadge`).
- Edit and Delete contextual actions.

### 5.3 `TaskEditorSheet.kt`
- Modal bottom sheet with smooth drag handles and keyboard-aware padding.
- Input fields for Title (required) and Description (optional).
- Category and Priority selection using `ExposedDropdownMenuBox` with `ExposedDropdownMenuAnchorType.PrimaryNotEditable`.
- Date selection dialog utilizing Compose Material 3 `DatePickerDialog`.
- Time selection dialog utilizing Compose Material 3 `TimePicker`.
- Label and tag entry chips.
- Validation and save button with loading indicator.

---

## 6. Verification and Test Results

The `TasksModuleTest` suite verifies:
1. **Flow Observation:** Emits updated lists immediately when repository changes.
2. **Filtering Logic:** Accurately isolates Pending, Upcoming, Overdue, and Completed tasks.
3. **Sorting Consistency:** Orders by Due Date, Priority, Creation Date, and Title accurately.
4. **Statistics Precision:** Correctly tallies counts and percentage across edge cases (0 tasks, 100% completed).
5. **Undo Toggle:** Toggling completion stores rollback state and successfully reverts upon undo.
6. **User Isolation:** Multiple users operate with 100% isolated task lists.
