# Flutter ProGuard Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# flutter_inappwebview rules
-keep class com.pichillilorenzo.flutter_inappwebview.** { *; }

# Keep security related classes
-keep class com.Bledo.browser.MainActivity { *; }

# Ignore Play Core warnings (deferred components)
-dontwarn com.google.android.play.core.**
