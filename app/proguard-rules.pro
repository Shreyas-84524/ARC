# ==============================================================================
# ARC Native Android Application — ProGuard & R8 Optimization Configuration
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. General Optimization & Obfuscation Settings
# ------------------------------------------------------------------------------
-optimizationpasses 5
-dontusemixedcaseclassnames
-dontskipnonpubliclibraryclasses
-verbose

# Preserve line numbers and source files for meaningful crash stack traces
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Preserve runtime and type annotations for reflection, Room, and serialization
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod

# ------------------------------------------------------------------------------
# 2. Room Database & Persistence Keep Rules
# ------------------------------------------------------------------------------
-keep class * extends androidx.room.RoomDatabase
-keep @androidx.room.Entity class * { *; }
-keep @androidx.room.Dao interface * { *; }
-keep class * extends androidx.room.migration.Migration { *; }
-keep class * extends androidx.room.RoomOpenHelper$Delegate { *; }
-keep class com.arc.arc.core.database.** { *; }
-dontwarn androidx.room.paging.**

# ------------------------------------------------------------------------------
# 3. Domain Models & JSON Serialization (Gson / DataStore)
# ------------------------------------------------------------------------------
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}
-keep class com.arc.arc.core.model.** { *; }
-keep class com.google.gson.** { *; }
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# ------------------------------------------------------------------------------
# 4. BiometricPrompt, Keystore & Cryptographic Vault Security
# ------------------------------------------------------------------------------
-keep class androidx.biometric.** { *; }
-keep interface androidx.biometric.** { *; }
-keep class com.arc.arc.core.security.** { *; }
-dontwarn javax.crypto.**
-dontwarn java.security.**

# ------------------------------------------------------------------------------
# 5. Jetpack Compose & UI Keep Rules
# ------------------------------------------------------------------------------
-keep class androidx.compose.runtime.** { *; }
-keep class androidx.compose.ui.** { *; }
-keep class androidx.compose.material3.** { *; }
-keep class com.arc.arc.core.designsystem.** { *; }
-dontwarn androidx.compose.**

# ------------------------------------------------------------------------------
# 6. Kotlin Coroutines & Asynchronous Dispatchers
# ------------------------------------------------------------------------------
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-keepclassmembernames class kotlinx.coroutines.** {
    volatile <fields>;
}
-dontwarn kotlinx.coroutines.**

# ------------------------------------------------------------------------------
# 7. Notifications, BroadcastReceivers & System Services
# ------------------------------------------------------------------------------
-keep class com.arc.arc.core.notifications.** { *; }
-keep class com.arc.arc.core.notifications.ArcReminderReceiver { *; }

# ------------------------------------------------------------------------------
# 8. Firebase, Firestore & Authentication
# ------------------------------------------------------------------------------
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# ------------------------------------------------------------------------------
# 9. AndroidX Credentials Manager & GoogleId
# ------------------------------------------------------------------------------
-keep class androidx.credentials.** { *; }
-dontwarn androidx.credentials.**
-keep class com.google.android.libraries.identity.googleid.** { *; }

# ------------------------------------------------------------------------------
# 10. WorkManager Background Tasks
# ------------------------------------------------------------------------------
-keep class androidx.work.** { *; }
-keep class com.arc.arc.core.sync.ArcSyncWorker { *; }
-dontwarn androidx.work.**
