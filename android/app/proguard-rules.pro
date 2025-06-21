# -------------------------------
# FLUTTER CORE (VERY IMPORTANT)
# -------------------------------
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Entry points
-keep class * extends io.flutter.embedding.android.FlutterActivity { *; }
-keep class * extends io.flutter.embedding.engine.FlutterEngine { *; }

# -------------------------------
# FIREBASE (you use multiple)
# -------------------------------
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# -------------------------------
# GOOGLE MOBILE ADS
# -------------------------------
-keep class com.google.android.gms.ads.** { *; }
-dontwarn com.google.android.gms.ads.**

# -------------------------------
# SUPABASE
# -------------------------------
-keep class io.supabase.** { *; }
-dontwarn io.supabase.**

# -------------------------------
# WORKMANAGER
# -------------------------------
-keep class androidx.work.** { *; }
-keep class * extends androidx.work.Worker
-dontwarn androidx.work.**

# -------------------------------
# BILLING (purchases_flutter)
# -------------------------------
-keep class com.android.billingclient.** { *; }
-dontwarn com.android.billingclient.**

# -------------------------------
# QR / SCANNER
# -------------------------------
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# -------------------------------
# NETWORKING (http, okhttp)
# -------------------------------
-dontwarn okhttp3.**
-dontwarn okio.**

# -------------------------------
# IMAGE / CACHE
# -------------------------------
-keep class com.bumptech.glide.** { *; }
-dontwarn com.bumptech.glide.**

# -------------------------------
# GENERAL SAFETY NET
# -------------------------------
-keep class kotlin.** { *; }
-dontwarn kotlin.**

# Keep annotations
-keepattributes *Annotation*

# Keep enums
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Play Core (REQUIRED for Flutter)
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**