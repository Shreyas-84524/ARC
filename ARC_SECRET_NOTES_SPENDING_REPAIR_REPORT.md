# Secret Notes and automatic spending repair

## Changes

- Secret Notes now uses declarative navigation from Tasks. This prevents a router refresh after authentication from evaluating the underlying Tasks route and invalidating the newly unlocked session. A regression test uses the production redirect and refresh notifier.
- Unlock initialization checks the PIN lockout before attempting automatic biometrics. Successful PIN authentication also suppresses delayed biometric prompting, and disposed unlock screens cannot complete authentication.
- Spending tracking initializes at application startup instead of depending on visiting Money or Settings. Profile-only changes no longer recreate the money repository and automation notifier.
- Transactions reserve their fingerprint and reference while saving, preventing overlapping SMS deliveries from creating duplicates without blocking unrelated purchases behind a network operation.
- A missing money repository now produces an error status instead of marking an unsaved expense processed. Listener-start failures are reflected in status, and tracking is enabled before buffered events can arrive.
- Parsing now accepts a debit equal to the remaining balance, rejects prose such as “UPI payment” as a reference, distinguishes separate equal purchases without references using SMS timestamps, and rejects invalid calendar dates.
- Automatic expense logs no longer print spending amounts.

## Validation

- Full Flutter suite, one test file at a time: 507 tests passed.
- Final spending regression/integration run after the concurrency adjustment: 37 tests passed.
- `dart analyze lib test`: no issues found.
- The initial concurrent test run and repository-wide analyzer exhausted memory. Serial tests and source-scoped analysis completed successfully.
- No physical Android device verification or release build was performed.

## Remaining reliability work

The Android bridge receives SMS, not payment-app notifications. It retains at most five pending raw events in memory; these do not survive process termination. Consequently, this feature is not yet reliable for spending that occurs while Android has terminated ARC. Closing this gap requires a background processing design with durable, user-scoped, sanitized transaction candidates and acknowledgements. Raw SMS/OTP bodies should continue to stay out of persistent storage.

The parser currently accepts INR debits conservatively. Unsupported formats can still be missed. More anonymized bank-message fixtures and real-device checks for permission revocation, process termination, reboot, and account switching are needed before claiming comprehensive automatic tracking.

The repository saves locally before awaiting cloud synchronization, but UI refresh and final dedup recording still wait for that save method to return. A follow-up should separate local completion from cloud delivery and reconcile persisted automatic expenses after interruption.
