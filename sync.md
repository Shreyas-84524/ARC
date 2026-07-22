# Project Arc — Offline-First Synchronization Engine

> **Version:** 1.0.0 (Production Release)  
> **Document Purpose:** Technical specification of the Hive-first, Firestore background sync pipeline, mutation queueing, retry execution, and conflict resolution rules.

---

## 1. Offline-First Pipeline

Project Arc guarantees **instant local execution**. All user mutations (creates, updates, deletes) complete locally in Hive before network calls are attempted.

```
[ User Interaction ]
        │
        ▼
[ Local Hive Read/Write ]  ──►  (Instant UI Refresh <1ms)
        │
        ▼
[ Queue Item Written to Hive sync_queue_box ]
        │
        ▼
[ SyncService Background Batch Execution ]
        │
        ├──────────────────────┬──────────────────────┐
        ▼ (Online)             ▼ (Offline)            ▼ (Retry Queue)
[ Firestore Batch Committed ]  [ Retained in Hive ]  [ Retried on Reconnect ]
```

---

## 2. Sync Queue Item Structure

Every mutation written to `sync_queue_box` contains full serialized data to prevent data loss or partial writes:

```json
{
  "id": "UUID string",
  "collection": "tasks | habits | habitEntries | transactions | budgets | monthlySummaries",
  "documentId": "Target Document ID String",
  "action": "upsert | delete",
  "data": { ...full serialized document fields... },
  "queuedAt": "ISO8601 Timestamp String"
}
```

---

## 3. Conflict Resolution & Reliability Rules

- **Single-User Scope**: Because Project Arc is intentionally a single-user personal app, incoming cloud data and local queue items operate on **last-write-wins** based on timestamp string evaluation.
- **Batching**: `SyncService.syncAllPending()` groups queue items into Firestore WriteBatches (up to 500 operations per batch) to minimize network roundtrips.
- **Idempotency**: All Firestore write operations use `SetOptions(merge: true)` or direct document reference set/delete, guaranteeing that retrying a queue item produces the exact same state without creating duplicate records.
