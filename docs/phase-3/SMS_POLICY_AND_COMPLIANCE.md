# Google Play SMS Policy & Financial Privacy Compliance

## 1. Google Play Developer Policy Compliance

Google Play policies strictly regulate the declaration and use of SMS permissions (`READ_SMS`, `RECEIVE_SMS`, `SEND_SMS`). Apps declaring these permissions must qualify as the default SMS handler or fit within a strictly audited exception category.

### 1.1 Current Application Policy Stance
- **Zero SMS Permissions Declared:** ARC's `AndroidManifest.xml` contains **zero SMS-related permissions**.
- **No Background Telephony Interception:** The app does not listen to incoming SMS via broadcast receivers or inspect telephony content providers.
- **On-Device Synthetic Simulator:** To enable full testing and demonstration of ARC's expense automation capabilities without policy violations or user privacy risk, ARC provides a built-in synthetic **Bank SMS Simulator** inside `MoneySettingsSheet.kt`.
- **Policy Eligibility:** If ARC seeks Google Play approval for real SMS parsing in future updates, the app is already architected to comply with Google Play's Financial App exception requirements:
  - Explicit user opt-in before activation.
  - Transparent privacy disclosure explaining on-device parsing.
  - No remote transmission of raw SMS text.
  - Redaction of sensitive data in all logs and diagnostics.

---

## 2. Privacy Safeguards & Data Minimization

ARC enforces strict privacy controls across all financial data handling:

### 2.1 Explicit User Consent in DataStore
Managed via `AppPreferencesDataStore`:
- `isMoneyDetectionEnabled`: Default `false`. Requires explicit user toggle.
- `isMoneyAutoSaveEnabled`: Default `false`. Requires secondary confirmation before saving transactions without individual user review.
- `hasSeenMoneyPrivacyNotice`: Tracks whether the user has viewed and acknowledged the financial privacy disclosure.

### 2.2 Redacted Log Representation
To prevent accidental leakage of OTPs, account identifiers, or sensitive bank communication into Android Logcat, diagnostic logs, or bug reports:

```kotlin
// MoneyAutomationRawEvent.kt
override fun toString(): String {
    val maskedBody = if (body.length > 20) body.take(10) + "... [REDACTED ${body.length} chars]" else "[REDACTED]"
    return "MoneyAutomationRawEvent(sender='$sender', timestamp=$timestamp, body='$maskedBody')"
}

// ParsedMoneyTransaction.kt
override fun toString(): String {
    val maskedAccount = accountIdentifier?.let { if (it.length > 4) "XX" + it.takeLast(4) else "XX" }
    return "ParsedMoneyTransaction(amountPaise=$amountPaise, type=$type, category='$category', merchant='$merchantName', account=$maskedAccount, confidence=$confidence)"
}
```

### 2.3 Strict Multi-User Isolation
All transactions and budgets are associated with the authenticated user ID (`ownerUid`). In multi-user setups (or when switching test accounts in development), SQLite query filters strictly partition rows:
`WHERE ownerUid = :ownerUid`

---

## 3. Compliance Verification Test Suite

Validated by `MoneyPrivacyComplianceTest.kt` across 4 test suites:
1. `manifestCheck_containsNoRestrictedSmsPermissions()`: Verifies zero `READ_SMS`, `RECEIVE_SMS`, or `SEND_SMS` permissions in `AndroidManifest.xml`.
2. `privacyDefaults_automationIsDisabledByDefault()`: Confirms default opt-out posture.
3. `logRedaction_rawEventRedactsSensitiveBody()`: Verifies that raw SMS content is masked in `toString()`.
4. `logRedaction_parsedTransactionMasksAccountIdentifier()`: Verifies that full bank account numbers are redacted in `toString()`.
