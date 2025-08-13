# Flutter & plugins keep rules
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Supabase / Kotlin coroutines / serialization
-dontwarn kotlinx.coroutines.**
-dontwarn kotlin.**
-keep class kotlinx.** { *; }
-keep class kotlin.** { *; }

# AndroidX typical keeps
-dontwarn androidx.**
-keep class androidx.** { *; }

# Local auth
-dontwarn io.flutter.plugins.localauth.**
-keep class io.flutter.plugins.localauth.** { *; }

# If any JSON via reflection (adjust as needed)
-keepclassmembers class ** {
    @com.google.gson.annotations.SerializedName <fields>;
}

# WorkManager (if used)
-dontwarn androidx.work.**
-keep class androidx.work.** { *; }

# Prevent obfuscation of app entry points
-keep class com.example.library_registration_app.** { *; }
