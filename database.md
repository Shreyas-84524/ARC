# Project Arc — Database & Data Layer Specification

> **Version:** 1.0.0 (Production Release)  
> **Document Purpose:** Complete specification of Hive local encrypted database boxes, Hive Type Adapters, Cloud Firestore collections, JSON document structures, and offline synchronization queues.

---

## 1. Hive Local Database Architecture

Project Arc uses **Hive** for ultra-fast, key-value local object storage. Boxes are opened synchronously during `main()` app initialization.

### Hive Box Registry
| Box Name | Type Adapter | Model Class | Purpose |
| :--- | :--- | :--- | :--- |
| `tasks_box` | TypeId `1` (`TaskAdapter`) | `Task` | Task items & scheduling |
| `habits_box` | TypeId `2` (`HabitAdapter`) | `Habit` | Habit items & goals |
| `habit_entries_box` | TypeId `3` (`HabitEntryAdapter`) | `HabitEntry` | Habit check-in logs |
| `transactions_box` | TypeId `4` (`TransactionAdapter`) | `Transaction` | Income/Expense ledger |
| `settings_box` | TypeId `5` (`MonthlySummaryAdapter`) / Map | `MonthlySummary` / Map | Budget caps & app settings |
| `sync_queue_box` | Map | `Map<String, dynamic>` | Pending mutation queue |

---

## 2. Cloud Firestore Schema

Firestore operates as a secondary, asynchronous mirror collection set for single-user cloud sync:

### 1. `/tasks/{taskId}`
```json
{
  "id": "String (UUID v4)",
  "title": "String",
  "description": "String",
  "priority": "Low | Medium | High | Much",
  "category": "Work | Personal | Health | Finance | Other",
  "labels": ["String"],
  "completed": "Boolean",
  "dueDate": "ISO8601 Timestamp String",
  "dueTime": "HH:mm String",
  "reminder": "ISO8601 Timestamp String",
  "createdAt": "ISO8601 Timestamp String",
  "updatedAt": "ISO8601 Timestamp String"
}
```

### 2. `/habits/{habitId}`
```json
{
  "id": "String (UUID v4)",
  "name": "String",
  "category": "String",
  "colorValue": "Integer (ARGB)",
  "goalType": "Daily | Weekly | Monthly",
  "targetDays": "Integer",
  "createdAt": "ISO8601 Timestamp String"
}
```

### 3. `/habitEntries/{entryKey}`
```json
{
  "id": "String ({habitId}_{dateStr})",
  "habitId": "String (UUID v4)",
  "dateStr": "yyyy-MM-dd String",
  "completed": "Boolean"
}
```

### 4. `/transactions/{transactionId}`
```json
{
  "id": "String (UUID v4)",
  "amount": "Double",
  "type": "Income | Expense",
  "category": "String",
  "date": "ISO8601 Timestamp String",
  "time": "HH:mm String",
  "notes": "String",
  "createdAt": "ISO8601 Timestamp String"
}
```

### 5. `/monthlySummaries/{yyyy-MM}`
```json
{
  "month": "yyyy-MM String",
  "monthlyBudget": "Double",
  "totalIncome": "Double",
  "totalExpenses": "Double",
  "savings": "Double",
  "updatedAt": "ISO8601 Timestamp String"
}
```

### 6. `/budgets/{budget_yyyy-MM}`
```json
{
  "monthKey": "yyyy-MM String",
  "amount": "Double"
}
```
