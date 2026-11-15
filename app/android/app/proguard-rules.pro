# TFLite (analisis de suelo): las clases se cargan por JNI.
-keep class org.tensorflow.lite.** { *; }
-dontwarn org.tensorflow.lite.**
# Play Core (deferred components de Flutter) no se usa.
-dontwarn com.google.android.play.core.**
