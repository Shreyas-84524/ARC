# Project Arc
## architecture.md
Version: 1.0

---

# 1. Architecture Overview

Project Arc follows a **Modular Feature-Based Architecture** designed specifically for a **single-user personal productivity application**.

The architecture prioritizes:

- Simplicity
- Scalability
- Offline-first experience
- Fast UI rendering
- Reusable components
- Clean separation of concerns

The application consists of three independent modules:

1. Task Manager
2. Habit Tracker
3. Money Tracker

Each module is isolated and communicates only through shared services.

---

# 2. Architectural Principles

The application must follow these principles throughout the codebase.

- Single Responsibility Principle
- Modular Architecture
- Feature-first Development
- Component Reusability
- Offline-first
- Optimistic UI
- Reactive State Management
- Separation of UI and Business Logic
- Clean Folder Structure
- Easily Extendable

---

# 3. Technology Stack

## Frontend

Flutter

Reason

- Native Android Performance
- Smooth Animations
- Material 3 Support
- Cross Platform Future Support

---

## State Management

Riverpod

Reason

- Reactive
- Compile-time Safe
- Lightweight
- Highly Scalable

---

## Local Database

Hive

Purpose

- Offline Storage
- Instant Loading
- Local Cache

---

## Cloud Database

Firebase Cloud Firestore

Purpose

- Cloud Backup
- Device Recovery
- Data Synchronization

Authentication is **NOT USED**.

---

## Notifications

flutter_local_notifications

Purpose

- Task Reminders
- Habit Reminders
- Money Reminders

---

## Charts

fl_chart

Charts

- Pie Chart
- Line Chart
- Bar Chart

---

## Haptic Feedback

Flutter Services

Purpose

- Completion Feedback
- Delete Feedback
- Save Feedback

---

## Dependency Injection

Riverpod Providers

---

# 4. High-Level Architecture

```
                    ┌────────────────────┐
                    │        UI          │
                    └─────────┬──────────┘
                              │
                    Presentation Layer
                              │
                              ▼
                    ┌────────────────────┐
                    │    Controllers     │
                    └─────────┬──────────┘
                              │
                       Business Logic
                              │
                              ▼
                    ┌────────────────────┐
                    │     Services       │
                    └─────────┬──────────┘
                              │
             ┌────────────────┴───────────────┐
             ▼                                ▼
      Local Database                    Cloud Firestore
            Hive                          Firebase
```

---

# 5. Folder Structure

```
lib/

│
├── app/
│
├── core/
│     ├── constants/
│     ├── theme/
│     ├── widgets/
│     ├── services/
│     ├── notifications/
│     ├── utilities/
│     ├── extensions/
│     └── helpers/
│
├── models/
│
├── features/
│
│     ├── dashboard/
│
│     ├── task_manager/
│     │      ├── data/
│     │      ├── models/
│     │      ├── providers/
│     │      ├── repository/
│     │      ├── services/
│     │      ├── screens/
│     │      ├── widgets/
│     │      └── controllers/
│
│     ├── habit_tracker/
│
│     ├── money_tracker/
│
│     └── settings/
│
├── routes/
│
├── providers/
│
└── main.dart
```

---

# 6. Feature Architecture

Each module follows the same architecture.

```
Feature

↓

Screens

↓

Widgets

↓

Controller

↓

Repository

↓

Service

↓

Database
```

---

# 7. Core Modules

---

## Task Manager

Responsible for

- CRUD
- Search
- Filters
- Notifications
- Statistics
- Priorities
- Categories

---

Internal Components

```
Task List

↓

Task Card

↓

Task Detail

↓

Task Editor

↓

Reminder Scheduler

↓

Statistics Engine
```

---

## Habit Tracker

Responsible for

- Habit CRUD
- Habit Completion
- Pie Chart
- Streak Calculation
- Statistics
- Daily Reminder

---

Internal Components

```
Habit List

↓

Habit Table

↓

Pie Chart

↓

Statistics

↓

Reminder Service
```

---

## Money Tracker

Responsible for

- Monthly Budget
- Transactions
- Monthly Summary
- Analytics
- Spending Reports

---

Internal Components

```
Budget

↓

Transactions

↓

Analytics

↓

Charts

↓

Monthly Summary
```

---

# 8. Dashboard Architecture

Dashboard aggregates data from all modules.

Displays

Today's Tasks

Today's Habits

Remaining Budget

Today's Progress

Recent Transactions

Upcoming Deadlines

Quick Statistics

Dashboard contains no business logic.

It only consumes providers.

---

# 9. State Management

Global Providers

- Theme
- Dashboard
- Notifications
- Settings

Feature Providers

Task Provider

Habit Provider

Money Provider

Statistics Provider

---

Each module manages its own state independently.

---

# 10. Data Flow

## Task Manager

```
User

↓

Create Task

↓

Controller

↓

Repository

↓

Hive

↓

UI Updates

↓

Firestore Sync
```

---

## Habit Tracker

```
Checkbox

↓

Controller

↓

Streak Calculator

↓

Hive

↓

UI Updates

↓

Firestore Sync
```

---

## Money Tracker

```
Transaction

↓

Repository

↓

Budget Calculator

↓

Hive

↓

Firestore Sync

↓

Dashboard Updates
```

---

# 11. Firestore Collections

```
tasks
```

Stores

- title
- description
- priority
- dueDate
- dueTime
- category
- labels
- reminder
- completed
- createdAt
- updatedAt

---

```
habits
```

Stores

- name
- goalType
- reminderTime
- color
- category

---

```
habitEntries
```

Stores

- habitId
- date
- completed

---

```
budgets
```

Stores

- month
- monthlyBudget

---

```
transactions
```

Stores

- amount
- type
- category
- notes
- timestamp

---

```
monthlySummaries
```

Stores

- month
- budget
- income
- expenses
- savings

---

```
settings
```

Stores

- theme
- notificationSettings
- reminderTimes

---

# 12. Local Database

Hive acts as the primary runtime database.

Advantages

- Instant loading
- Works offline
- Extremely fast
- Lightweight

Whenever data changes

```
Hive Updates

↓

UI Refreshes

↓

Firestore Sync
```

---

# 13. Synchronization Strategy

Application uses optimistic updates.

```
User Action

↓

Hive

↓

UI Updates

↓

Background Firestore Sync
```

If internet is unavailable

```
Hive

↓

Queue Sync

↓

Automatic Upload Later
```

---

# 14. Notification Architecture

## Task Notifications

Trigger

Due Time

Notifications

- One Hour Before
- Thirty Minutes Before
- Due Time

---

## Habit Notifications

Every evening

Check

Today's completion

If incomplete

Notify user

---

## Money Notifications

Daily

8 PM

10 PM

Ask

"Have you recorded today's transactions?"

---

All notifications use

flutter_local_notifications

---

# 15. Budget Engine

The monthly budget is immutable after being set (unless explicitly edited by the user).

Remaining budget is always calculated dynamically.

```
Remaining Budget

=

Monthly Budget

+

Income

-

Expenses
```

Never overwrite remaining budget.

---

# 16. Analytics Engine

Task Statistics

- Total
- Completed
- Pending

Habit Statistics

- Current Streak
- Longest Streak
- Completion %

Money Statistics

- Income
- Expenses
- Savings
- Remaining Budget

Dashboard combines all statistics.

---

# 17. Error Handling

Every database operation should return

- Success
- Failure
- Loading

Failures should display friendly messages.

No crashes should occur due to invalid input.

---

# 18. Security

Although the application is single-user,

all input should be validated.

Prevent

- Empty Tasks
- Invalid Dates
- Invalid Amounts
- Negative Budgets
- Duplicate IDs

Firestore security rules should only allow access from the application's configured Firebase project.

---

# 19. Performance Optimization

Use lazy loading where possible.

Avoid unnecessary widget rebuilds.

Use Riverpod selectors.

Paginate transaction history if it grows large.

Cache charts.

Debounce search.

Use const widgets whenever possible.

---

# 20. Future Scalability

Future modules should plug into the same architecture without affecting existing features.

Examples

```
Pomodoro

↓

Journal

↓

Notes

↓

Calendar

↓

Workout Tracker

↓

Reading Tracker

↓

AI Assistant

↓

Knowledge Vault

↓

Goal Planner
```

Each new module should follow the same feature structure:

```
feature/

data/

models/

repository/

services/

providers/

controllers/

screens/

widgets/
```

---

# 21. Coding Standards

- Flutter Lints enabled
- Dart formatting enforced
- Strong typing throughout
- Feature-based organization
- Reusable widgets only
- Business logic separated from UI
- Repository pattern for data access
- Consistent naming conventions
- Clear documentation for public classes
- Modular imports
- Minimal code duplication

---

# 22. Architecture Summary

Project Arc is built as a **single-user, offline-first, modular productivity system**. Hive serves as the primary local database for instant responsiveness, while Firebase Cloud Firestore provides secure cloud backup and synchronization. Riverpod manages application state, `flutter_local_notifications` handles reminders, and `fl_chart` powers analytics. Each feature—Task Manager, Habit Tracker, and Money Tracker—is self-contained, ensuring maintainability and allowing future modules to be added without restructuring the existing codebase. The architecture emphasizes clean separation of concerns, high performance, reliability, and long-term extensibility.