# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Flutter deferred components use Play Core — ignore missing stubs (not used by this app)
-dontwarn com.google.android.play.core.**

# Firebase / Firestore
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Firestore models (prevent field stripping)
-keepclassmembers class * {
    @com.google.firebase.firestore.PropertyName <fields>;
}

# url_launcher
-keep class androidx.browser.** { *; }

# image_picker / file_provider
-keep class androidx.core.content.FileProvider { *; }

# share_plus
-keep class dev.fluttercommunity.plus.share.** { *; }

# printing plugin
-keep class com.github.DavBfr.dart_pdf.** { *; }

# Kotlin coroutines
-keepclassmembernames class kotlinx.** {
    volatile <fields>;
}
