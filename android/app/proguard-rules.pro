# flutter_local_notifications deserializes scheduled notifications through
# Gson TypeToken. R8 must retain the generic signatures used by TypeToken.
-keepattributes Signature
-keepattributes RuntimeVisibleAnnotations,RuntimeInvisibleAnnotations,AnnotationDefault
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken

# Keep the plugin's scheduled-notification data models and Gson adapters.
-keep class com.dexterous.flutterlocalnotifications.models.** { *; }
-keep class com.dexterous.flutterlocalnotifications.**$* extends com.google.gson.reflect.TypeToken { *; }
