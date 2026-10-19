# Automatic Financial Expense Detection Engine

## 1. Overview

The `MoneyTransactionParser` (`com.arc.arc.features.money.automation.MoneyTransactionParser`) is an on-device, privacy-preserving transactional parsing engine. It extracts transaction amounts, merchant names, bank identifiers, and expense categories from structured bank notification texts using deterministic regular expressions without cloud API roundtrips.

---

## 2. Parsing Architecture

```
Raw Event (Sender, Body, Timestamp)
                 │
                 ▼
   Rejection Filters Check
   ├── Contains OTP / Verification Code? ──────────► REJECT_OTP
   ├── Contains Credit Card Limit / Balance? ──────► REJECT_BALANCE_ALERT
   ├── Failed / Declined Transaction? ─────────────► REJECT_FAILED
   ├── Promotional / Loan Offer / EMI Advert? ─────► REJECT_PROMOTIONAL
   └── Credit / Refund / Salary? ──────────────────► REJECT_CREDIT_ALERT
                 │
                 ▼ (Passed Filters)
     Amount Extraction (Regex)
     - Rs. / INR / ₹ pattern matching
     - Strict conversion to integer Long paise
                 │
                 ▼
   Merchant & Category Inference
   - Known vendors (Swiggy, Amazon, Uber, Netflix...)
   - Account identifier (HDFC, SBI, ICICI, Axis...)
                 │
                 ▼
    SHA-256 Fingerprint Generation
    - sha256("$ownerUid:$sender:$body:$timestamp")
                 │
                 ▼
    Deduplication Service Check
    - If fingerprint exists in Room ───────────────► Skip (Duplicate)
    - Else ────────────────────────────────────────► Save Transaction
```

---

## 3. Supported Bank Syntaxes

The engine includes robust patterns verified against major Indian banks and payment networks:

| Bank / Provider | Sample Pattern Matched | Extracted Fields |
|---|---|---|
| **HDFC Bank** | `Alert: Rs.450.00 debited from HDFC Bank A/c xx1234 to SWIGGY on 18-OCT-26` | Amount: 45,000 paise; Account: HDFC-xx1234; Merchant: Swiggy; Category: Food |
| **State Bank of India (SBI)** | `Dear SBI User, your A/C ending 5678 debited by Rs.1200.50 on 18Oct26 by UPI/UBER` | Amount: 120,050 paise; Account: SBI-5678; Merchant: Uber; Category: Travel |
| **ICICI Bank** | `Acct XX9012 debited for INR 2,999.00 on 18-Oct-26. Info: AMAZON. Available Bal: Rs.45,000` | Amount: 299,900 paise; Account: ICICI-XX9012; Merchant: Amazon; Category: Shopping |
| **Axis Bank / UPI** | `Sent Rs.350 to CHAI POINT on 18-10-2026. Ref: 239012. UPI: 1234@okaxis` | Amount: 35,000 paise; Account: Axis-UPI; Merchant: Chai Point; Category: Food |

---

## 4. Strict Rejection Logic

To avoid false positive transaction generation, the parser strictly rejects:
1. **OTPs and 2FA:** Messages containing `OTP`, `verification code`, `one time password`, `do not share`, or `valid for`.
2. **Account Balances:** Messages containing `balance is`, `available balance`, `bal:`, without a preceding debit verb.
3. **Failed / Declined Transactions:** Messages containing `failed`, `declined`, `unsuccessful`, `insufficient funds`, or `cancelled`.
4. **Promotional Offers & Pre-approved Loans:** Messages containing `pre-approved`, `apply now`, `discount`, `coupon`, `cashback of up to`, or `claim offer`.
5. **Credit Alerts:** Notifications of funds received, credits, refunds, or reversals are categorized as `CREDIT_INCOME` or rejected depending on user automation preferences.

---

## 5. Deduplication & Idempotency

Every parsed event generates a cryptographic signature:
```kotlin
val rawKey = "$ownerUid:${rawEvent.sender.trim()}:${rawEvent.body.trim()}:${rawEvent.timestamp}"
val fingerprint = MessageDigest.getInstance("SHA-256")
    .digest(rawKey.toByteArray())
    .joinToString("") { "%02x".format(it) }
```
The `MoneyDeduplicationService` verifies this fingerprint against the indexed `automationFingerprint` column in Room's `transactions` table before persisting.
