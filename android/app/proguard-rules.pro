# The Flutter embedding references Play Core (deferred components), which the app does not ship.
-dontwarn com.google.android.play.core.**

-keep class io.flutter.** { *; }
