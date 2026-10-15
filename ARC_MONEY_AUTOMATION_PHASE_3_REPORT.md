# ARC Money Automation — Phase 3: Transaction Parsing, Classification & Deduplication Report

## Executive Summary

Phase 3 implements the **conservative local transaction parser**, **classification engine**, and **cryptographic deduplication service** for Automatic Spending Tracking in ARC.

All architectural principles and privacy guarantees were strictly maintained:
- **Local-Only Guarantee**: 100% Dart-based parsing and deduplication on-device. Zero cloud processing, zero Firebase/Firestore writes.
- **Conservative Classification**: Favors false negatives over false positives. Uncertain messages are rejected as `unknown`.
- **Strict Rejections**: OTPs, credits/incoming funds, failed/declined transactions, pure balance alerts, and promotional messages are completely excluded from automatic entry.
- **Privacy Enforcement**: The raw SMS body is never stored in any model, repository, database, log, or cloud service. Sensitive account/card numbers are masked (`XXXX$digits`).
- **Deduplication Resistance**: Deterministic SHA-256 fingerprinting and bank reference ID checking prevent duplicate entries from duplicate SMS deliveries, system intents, or app restarts.
- **Phase Boundary**: Zero writes to Money Tracker (`Transaction`, `MoneyRepository`, categories, budgets). Phase 3 terminates with an in-memory `acceptedCandidateStream` ready for Phase 4.

---

## 1. Parser Architecture

```
Incoming Broadcast (`MoneySmsReceiver`)
                   │
                   ▼
  `MoneyAutomationRawEvent` (transient in-memory)
                   │
                   ▼
     [MoneyTransactionParser]
                   │
                   ├── 1. OTP Check ────────────────────────► REJECT (otp)
                   ├── 2. Failed / Declined Check ──────────► REJECT (failed)
                   ├── 3. Credit / Incoming Funds Check ────► REJECT (credit)
                   ├── 4. Promotional Ad Check ─────────────► REJECT (promotional)
                   ├── 5. Balance Alert Only Check ─────────► REJECT (balanceAlert)
                   ├── 6. Foreign Currency Check ───────────► REJECT (unknown)
                   └── 7. Confirmed Debit & Amount Check
                                    │
                                    ▼
                      [ParsedMoneyTransaction]
                                    │
                                    ▼
                   [MoneyDeduplicationService]
                   - Check bank reference ID seen?
                   - Check deterministic SHA-256 fingerprint seen?
                                    │
                     ┌──────────────┴──────────────┐
                     ▼                             ▼
                 [Duplicate]                   [Unique]
                   (Dropped)                       │
                                                   ▼
                                     `acceptedCandidateStream`
                                    (Ready for Phase 4 Consumption)
```

---

## 2. File Inventory

| Category | File Path | Description |
|---|---|---|
| **Models** | `lib/features/money_tracker/models/money_transaction_classification.dart` | `MoneyTransactionClassification` (`confirmedDebit`, `credit`, `otp`, `failed`, `balanceAlert`, `promotional`, `unknown`) and `MoneyTransactionConfidence` (`high`, `medium`, `low`). |
| **Models** | `lib/features/money_tracker/models/parsed_money_transaction.dart` | Structured candidate model. Contains parsed amount, currency, timestamp, masked account, reference ID, sender, and SHA-256 fingerprint. No raw SMS text stored. |
| **Services** | `lib/features/money_tracker/services/money_transaction_parser.dart` | Deterministic local parser with conservative classification, amount extraction distinguishing from balances, reference extraction, and masking. |
| **Services** | `lib/features/money_tracker/services/money_deduplication_service.dart` | Multi-user isolated deduplication engine using bank reference IDs and SHA-256 fingerprints backed by local Hive storage. |
| **Providers** | `lib/features/money_tracker/providers/money_automation_provider.dart` | Wires parser and deduplication service into `MoneyAutomationNotifier`. Exposes `acceptedCandidateStream` for Phase 4. |
| **Test Suite** | `test/money_automation_phase3_test.dart` | 14 targeted unit and pipeline integration tests covering classification, rejection, amount extraction, deduplication, and privacy rules. |
| **Memory** | `Brain.md` | Persistent architectural reference updated with Phase 3 specifications. |

---

## 3. Classification & Decision Rules

1. **OTP Messages**:
   - Matches phrases such as "OTP", "one time password", "verification code", "do not share", "authentication code", "login code", "valid for X mins".
   - **Result**: `classification = otp`, `confidence = high`, `amount = 0.0`. Strictly rejected even if debit words or amounts are present.
2. **Credits / Incoming Money**:
   - Matches "credited with", "credited to", "received in", "refund credited", "cashback credited", "salary credited", "deposit".
   - **Result**: `classification = credit`, rejected from outgoing spending.
3. **Failed / Declined Transactions**:
   - Matches "failed", "declined", "unsuccessful", "could not be completed", "reversed", "reversal".
   - **Result**: `classification = failed`, rejected from spending.
4. **Balance Alerts**:
   - Matches "available balance", "account balance", "avl bal", "mini statement", "low balance", without confirmed debit.
   - **Result**: `classification = balanceAlert`, rejected.
5. **Promotional Messages**:
   - Matches "pre-approved", "apply now", "special offer", "discount code", "loan offer", "credit card offer".
   - **Result**: `classification = promotional`, rejected.
6. **Confirmed Debits**:
   - Requires verified debit keywords ("debited", "spent", "paid", "withdrawn", "purchase of", "atm cash withdrawal", "upi payment") combined with an explicit INR amount.
   - **Result**: `classification = confirmedDebit`, `confidence = high`.
7. **ATM Cash Withdrawals**:
   - Classified as `confirmedDebit` outgoing spending (represents cash withdrawn from account). Category is left empty for Phase 4.

---

## 4. Amount Extraction & Data Privacy

- **Amount vs Balance Separation**: Indian bank SMS messages typically include both a debit amount and an available balance (e.g. *Rs 450 debited ... Avl Bal Rs 15,400*). The parser specifically isolates and excludes the balance portion, reliably extracting the true transaction amount.
- **Sensitive Identifier Masking**: Any account or card numbers found in headers, bodies, or merchant descriptions are masked as `XXXX$lastDigits` (e.g. `XXXX1234`).
- **Fingerprint Signature**: Computed using `sha256(amount|currency|referenceId|sender|merchant|accountMask|date)`.
- **Sanitized Logging**: All debug logs use redacted fingerprints (`${fp.substring(0, 8)}...`) and never output raw message contents, OTPs, or full account numbers.

---

## 5. Verification & Test Results

### Targeted Phase 3 Tests (`test/money_automation_phase3_test.dart`)
1. **Confirmed Debit Accepted**: Validates `confirmedDebit` classification, high confidence, INR currency, reference extraction, and account masking. (PASSED)
2. **OTP Rejected**: Validates OTP messages are rejected even when amounts are mentioned. (PASSED)
3. **Credit Rejected**: Validates credited/refund/cashback messages are rejected. (PASSED)
4. **Failed Transaction Rejected**: Validates declined/failed/reversed messages are rejected. (PASSED)
5. **Balance Alert Rejected**: Validates pure balance enquiries are rejected. (PASSED)
6. **Amount Distinguishing**: Validates debit amount is correctly extracted while ignoring the larger balance amount. (PASSED)
7. **Duplicate Fingerprint Rejected**: Validates deduplication service blocks identical fingerprints. (PASSED)
8. **Duplicate Reference ID Rejected**: Validates deduplication service blocks duplicate bank reference IDs across different fingerprints. (PASSED)
9. **Malformed SMS Safety**: Validates empty and garbage strings safely produce `unknown` without crashing. (PASSED)
10. **Non-Transactional Conversational SMS**: Validates casual chat messages are rejected as `unknown`. (PASSED)
11. **Raw Content Not Persisted**: Validates `ParsedMoneyTransaction` does not store raw SMS text and `toString()` is sanitized. (PASSED)
12. **Sensitive Identifier Masking**: Validates 12-digit account/card numbers in descriptions are redacted to `XXXX$digits`. (PASSED)
13. **ATM Cash Withdrawal**: Validates ATM withdrawals are accepted as `confirmedDebit`. (PASSED)
14. **Pipeline Integration**: Validates end-to-end flow through `MoneyAutomationNotifier` emitting to `acceptedCandidateStream` while dropping duplicates and OTPs. (PASSED)

### Static Analysis & Regression Results
- `flutter analyze`: **0 issues found** (clean).
- Full regression test suites (Phase 1, Phase 2, Phase 3, and Money Tracker): **50 of 50 tests passed**.

---

## 6. Known Limitations & Files for Phase 4

- **No Categorization**: Transactions remain uncategorized. Phase 4 will implement merchant matching and category assignment rules.
- **No Money Tracker Writes**: Transactions are not yet added to `MoneyRepository` or displayed in `MoneyScreen`.
- **Candidate Stream**: Candidates are currently emitted on `MoneyAutomationNotifier.acceptedCandidateStream`.

### Files for Phase 4 to Inspect First:
1. `lib/features/money_tracker/providers/money_automation_provider.dart` (`acceptedCandidateStream`)
2. `lib/features/money_tracker/models/parsed_money_transaction.dart`
3. `lib/features/money_tracker/providers/money_provider.dart` (`MoneyRepository.addTransaction`)
4. `lib/features/money_tracker/models/transaction_model.dart`
