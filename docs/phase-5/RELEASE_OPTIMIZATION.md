# ARC-Kotlin Phase 5 — Release Optimization & R8 Hardening

## 1. Overview and R8 Strategy

To deliver an ultra-responsive, lightweight Android application while maintaining absolute cryptographic safety and offline-first performance, ARC applies full R8 optimization, dead-code elimination, and resource shrinking:

1. **Dead Code Elimination & Minification**: Strips unused standard library utilities and transitive AndroidX classes.
2. **Deterministic Keep Rules**: Protects Room DAOs, Entities, Gson models, BiometricPrompt interfaces, and Keystore crypto primitives from improper renaming or truncation.
3. **Crash Diagnostics Preservation**: Retains `SourceFile` and `LineNumberTable` attributes to allow symbolication of production stack traces without leaking business logic.

---

## 2. Hardened ProGuard / R8 Rules

The rules configured in `app/proguard-rules.pro` cover seven distinct operational layers:

### Layer 1: Global Obfuscation & Line Numbers
- Multi-pass optimization (`-optimizationpasses 5`)
- `-keepattributes SourceFile,LineNumberTable` for stack trace symbolication
- `-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod`

### Layer 2: Room v4 Schema Integrity
- Preserves all classes extending `androidx.room.RoomDatabase`
- Keeps `@androidx.room.Entity` and `@androidx.room.Dao` implementations
- Preserves custom Room migrations (`androidx.room.migration.Migration`)

### Layer 3: Model & JSON Serialization
- Keeps enum reflection methods (`values()`, `valueOf()`)
- Preserves all domain models in `com.arc.arc.core.model.**`
- Keeps `@SerializedName` annotations on fields

### Layer 4: Biometric & Security Enclaves
- Protects `androidx.biometric.**` from reflection failures
- Keeps Android Keystore and AES-256-GCM crypto classes in `com.arc.arc.core.security.**`

### Layer 5: Jetpack Compose Runtime
- Protects Compose compiler metadata, runtime scopes, and UI node hierarchies

### Layer 6: Coroutines & Dispatchers
- Retains internal coroutine dispatcher factories and volatile state fields

### Layer 7: BroadcastReceivers & System Services
- Preserves `ArcReminderReceiver` for AlarmManager wakeups
