# Security and Android compliance

Status: **Completed static audit; policy and cryptographic verification remain**.

## Critical findings

1. `RECEIVE_SMS` is declared and an exported receiver handles `SMS_RECEIVED`. Google Play treats SMS access as restricted. SMS-based money management is an eligible exception only after declaration/review, prominent disclosure/consent, data minimization, privacy policy, and proof that it is core functionality. Kotlin does not change this policy.
2. The receiver is protected with `BROADCAST_SMS` and drops events when disabled, but raw sender/body enters process memory and a five-item in-memory buffer. Verify logging, crash reporting, clipboard, analytics, and backup never capture it. Consider user-imported notifications/receipts or manual entry as a non-SMS distribution variant.
3. Flutter release currently uses debug signing. Production continuity requires the existing Play signing identity; never copy a signing key into Git.
4. Secret Notes use local Hive plus custom crypto/PIN services and biometrics. Native migration must use Android Keystore, BiometricPrompt CryptoObject when appropriate, a memory-hard/password KDF with per-user salt, AEAD, constant-time verification, retry throttling, zero sensitive logs, FLAG_SECURE, and a tested recovery policy.
5. The current manifest requests exact alarms, notification permission, boot receive, biometrics, vibration, and SMS. Each must be justified and requested contextually. WorkManager is preferred for deferrable work; exact alarms need platform/Play eligibility.

## Native baseline controls

Phase 0 declares no dangerous permissions, no exported component except the launcher activity, no Firebase config, no network security override, and disables backup/device transfer. Debug uses a distinct application ID. Add deep links only with explicit host validation. Separate debug/release endpoints and logging, redact identifiers and financial data, enable R8/resource shrinking, audit dependencies, and test manifest merger output before release.
