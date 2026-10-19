# ARC Vault PIN & Biometric Authentication

## 1. Resolution of Legacy Flutter Issues

### Issue 1: Biometric Authentication Prompting Twice on Vault Entry
- **Legacy Root Cause:** Unsynchronized async calls between route guards, lifecycle listeners, and widget `initState()` spawned multiple `BiometricPrompt` dialogs.
- **Native Solution:** `BiometricAuthManager` introduces an atomic single-prompt lock:
  ```kotlin
  private val isPromptInFlight = AtomicBoolean(false)
  override fun canPrompt(): Boolean = isPromptInFlight.compareAndSet(false, true)
  override fun onPromptDismissed() { isPromptInFlight.set(false) }
  ```
  Any concurrent or redundant trigger is immediately and safely discarded.

### Issue 2: PIN Indicator Dots Displayed Before User Input
- **Legacy Root Cause:** Static dot widgets pre-rendered active states.
- **Native Solution:** Compose `VaultPinDots` renders circles starting strictly empty (`○ ○ ○ ○ ○ ○`) and fills dynamically (`● ● ● ○ ○ ○`) based on `enteredLength`.

### Issue 3: Variable PIN Length Support (3 to 6 Digits)
- **Legacy Root Cause:** UI hardcoded 6 digits despite backend supporting 3–6.
- **Native Solution:** Supports length selection `[3, 4, 5, 6]`. Displays an explicit entropy warning for $< 6$ digits:
  `⚠️ Short PIN (3 digits). 6 digits strongly recommended.`

---

## 2. Persistent Exponential Rate Limiting

To prevent brute-force attacks on low-entropy PINs, attempt counters and lockout timestamps are persisted to DataStore, surviving application restarts:

| Consecutive Failed Attempts | Enforced Lockout Duration | Behavior |
|---|---|---|
| **1 to 4** | None (0s) | Increments counter; provides immediate retry. |
| **5** | **30 seconds** | Keypad locked; countdown banner displayed. |
| **6** | **60 seconds** | Lockout doubled to 60 seconds. |
| **7+** | **120 seconds** | Lockout set to 120 seconds per subsequent failure. |

**Lockout Expiry:** Keypad unlocks only when `currentTimeMs >= lockoutUntilEpochMs`.  
**Success Reset:** Entering the correct PIN resets `failedAttempts` to 0 and clears the lockout timestamp.
