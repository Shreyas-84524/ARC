# Flutter Money Manager Codebase Audit & Specification

## 1. Executive Summary

This document details the audit of the legacy Flutter Money Manager located in `C:\dev\ARC/lib/features/money_tracker/` and corresponding tests in `C:\dev\ARC/test/`. The audit establishes the data contracts, business rules, persistence schemas, automation engine, and UI behavior required for ARC-Kotlin Phase 3.

In strict compliance with project principles:
- The Flutter codebase (`C:\dev\ARC`) is read-only and remains 100% unmodified.
- All legacy Hive and Firestore contracts are preserved to ensure zero migration data loss.
- Financial arithmetic is strictly specified in integer minor units (paise in `Long`) to prevent floating-point rounding errors.
- Real SMS collection is prohibited without platform permission approval; synthetic fixtures and user-provided inputs power the parsing engine.

---

## 2. Inventory of Flutter Money Components

| Path | Type | Purpose | Migration Strategy |
|---|---|---|---|
| `lib/features/money_tracker/models/transaction_model.dart` | Hive Model (Type 3) | Primary transaction model (Income, Expense) | Native Kotlin `TransactionModel` + Room `TransactionEntity` |
| `lib/features/money_tracker/models/monthly_summary_model.dart` | Data Model | Monthly aggregated budget, income, expense, savings | Native Kotlin `MonthlySummaryModel` + derived computation |
| `lib/features/money_tracker/models/money_transaction_classification.dart` | Enum | Classification for incoming transaction events | Kotlin `MoneyTransactionClassification` enum |
| `lib/features/money_tracker/models/parsed_money_transaction.dart` | Model | Structured candidate transaction from parser | Kotlin `ParsedMoneyTransaction` with masked accounts |
| `lib/features/money_tracker/models/money_automation_raw_event.dart` | Model | Transient in-memory raw event (never persisted) | Kotlin `MoneyAutomationRawEvent` (sanitized toString) |
| `lib/features/money_tracker/models/money_automation_state.dart` | Model | User opt-in state, prompt frequency, listener status | Kotlin `MoneyAutomationState` in DataStore preferences |
| `lib/features/money_tracker/models/money_automation_listener_status.dart` | Enum | Status of listener (disabled, ready, permissionRequired, etc.) | Kotlin `MoneyAutomationListenerStatus` enum |
| `lib/features/money_tracker/repository/money_repository.dart` | Repository | Hive box & Firestore sync for transactions & budgets | `OfflineFirstTransactionRepository` + Room DB v3 |
| `lib/features/money_tracker/repository/money_automation_repository.dart` | Repository | Local preferences for automation opt-in | `MoneyAutomationPreferencesRepository` (DataStore) |
| `lib/features/money_tracker/services/money_transaction_parser.dart` | Service | Regex-based Indian SMS transaction parser | `MoneyTransactionParser.kt` with conservative rules |
| `lib/features/money_tracker/services/money_deduplication_service.dart` | Service | Deterministic SHA-256 fingerprint deduplication | `MoneyDeduplicationService.kt` |
| `lib/features/money_tracker/screens/money_screen.dart` | View | Main money screen (Transactions & Analytics tabs) | Jetpack Compose `MoneyScreen.kt` + `MoneyViewModel` |
| `lib/features/money_tracker/widgets/transaction_editor_sheet.dart` | Widget | Add/edit transaction modal sheet | Jetpack Compose `TransactionEditorSheet.kt` |
| `lib/features/money_tracker/widgets/transaction_details_sheet.dart` | Widget | Transaction details & delete dialog | Jetpack Compose `TransactionDetailsSheet.kt` |
| `lib/features/money_tracker/widgets/money_tracker_settings_sheet.dart` | Widget | Automation toggle & status sheet | Jetpack Compose `MoneySettingsSheet.kt` |

---

## 3. Data Schema & Serialization Contracts

### 3.1 Transaction Model (`HiveType(typeId: 3)`)
In Flutter Hive:
```dart
@HiveType(typeId: 3)
class Transaction extends HiveObject {
  @HiveField(0) final String id;
  @HiveField(1) final double amount;
  @HiveField(2) final String type; // 'Income', 'Expense'
  @HiveField(3) final String category;
  @HiveField(4) final DateTime date;
  @HiveField(5) final String time; // e.g. "12:30"
  @HiveField(6) final String notes;
  @HiveField(7) final DateTime createdAt;
  @HiveField(8) final String source; // 'manual', 'sms_auto'
  @HiveField(9) final String? automationFingerprint;
}
```

Firestore mapping (`users/{userId}/transactions/{transactionId}`):
- `id`: String (UUID v4)
- `amount`: Double (in INR, e.g. 1250.75)
- `type`: String ("Income" or "Expense")
- `category`: String (Default "Other")
- `date`: String (ISO-8601 UTC)
- `time`: String ("HH:mm")
- `notes`: String
- `createdAt`: String (ISO-8601 UTC)
- `source`: String ("manual" or "sms_auto")
- `automationFingerprint`: String? (Nullable SHA-256 hash)

### 3.2 Native Precision Rule (Paise Conversion)
To strictly satisfy Non-negotiable Rule 8:
- **Storage & Arithmetic:** Internally represented as `amountPaise: Long`.
  $$\text{amountPaise} = \text{round}(\text{amount} \times 100)$$
  For example, ₹1,250.75 is stored as `125075L`.
- **Serialization:** When converting to/from Firestore or legacy JSON, `amount` is converted via `amountPaise.toDouble() / 100.0`. All internal operations (sums, balances, budgets, savings) are strictly performed using integer math.

### 3.3 Budgets & Monthly Summaries
- **Budget Storage:** Scoped per calendar month formatted as `yyyy-MM` (e.g., `2026-10`).
- **Firestore Path:** `users/{userId}/budgets/{yyyy-MM}`:
  ```json
  {
    "amount": 50000.0,
    "month": "2026-10"
  }
  ```
- **Firestore Path:** `users/{userId}/monthlySummaries/{yyyy-MM}`:
  ```json
  {
    "month": "2026-10",
    "monthlyBudget": 50000.0,
    "totalIncome": 75000.0,
    "totalExpenses": 32450.0,
    "savings": 42550.0,
    "updatedAt": "2026-10-18T12:00:00.000Z"
  }
  ```

---

## 4. Categories & Enums

### 4.1 Expense Categories
1. `Food`
2. `Travel`
3. `Shopping`
4. `Fuel`
5. `Bills`
6. `Entertainment`
7. `Health`
8. `Education`
9. `Other`

### 4.2 Income Categories
1. `Salary`
2. `Freelancing`
3. `Investment`
4. `Gift`
5. `Other`

---

## 5. Automatic Expense Detection Audit

The Flutter engine in `money_transaction_parser.dart` implements a strict conservative pipeline:
1. **Unconditional Rejections:**
   - OTP messages (`otp`, `one time password`, `verification code`, `do not share`, etc.)
   - Failed or reversed payments (`failed`, `declined`, `unsuccessful`, `reversal`)
   - Credits and refunds (`credited`, `cashback`, `salary credited`, `received from`)
   - Promotional text (`pre-approved`, `special offer`, `instant loan`, etc.)
   - Balance-only notifications (`available balance is`, `avl bal`, `mini statement`)
   - Foreign currencies (`USD`, `EUR`, `GBP`, `AUD`, `CAD`, `$`, `€`, `£`)
2. **Confirmed Debit Extraction:**
   - Keywords: `debited`, `spent`, `paid`, `withdrawn`, `purchase of`, `upi payment`.
   - Distinct extraction separating transaction amount from available balance.
   - Account number masking: Extracts last 3-4 digits, masks as `XXXX1234`.
   - Merchant extraction with trailing noise word stripping (`on`, `via`, `using`, `dated`, `ref`, `avl`).
3. **Deterministic Fingerprint:**
   $$\text{signature} = \text{amountStr} \parallel \text{currency} \parallel \text{refId} \parallel \text{sender} \parallel \text{merchant} \parallel \text{accountMask} \parallel \text{dateStr}$$
   $$\text{fingerprint} = \text{SHA-256}(\text{signature})$$
4. **Deduplication:**
   - Prioritizes `referenceId` (UTR/RRN/TxnId) if available.
   - Falls back to `fingerprint`.
   - Caches processed identifiers per user up to 500 records.

---

## 6. Privacy & Policy Compliance Strategy

- **SMS Ingestion Status:** Google Play policy requires high-friction approval for `READ_SMS` / `RECEIVE_SMS`. These permissions **must not** be declared in `AndroidManifest.xml` during Phase 3.
- **Permission-Free Input:** The engine is source-agnostic, accepting:
  - User-pasted transaction text ("Quick Paste" in UI).
  - Synthetic test fixtures.
  - Future platform listeners (gated behind explicit user opt-in and policy approval).
- **Zero Raw Text Storage:** Raw messages or SMS bodies are transient and never stored in Room, DataStore, Firestore, or logs.

---

## 7. Audit Conclusion & Next Steps

The legacy contracts, arithmetic invariants, and UI requirements are fully understood and documented. Sub-Phase 3.1 proceeds with contract tests covering these invariants.
