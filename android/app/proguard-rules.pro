# ProGuard / R8 rules para release builds.
#
# MediaPipe LLM Inference (usado por Lumen vía flutter_gemma) referencia
# clases proto generadas por reflection desde código nativo (JNI). R8 no
# las "ve" y las strippea, lo que rompe el build con:
#
#   Missing class com.google.mediapipe.proto.CalculatorProfileProto...
#   Missing class com.google.mediapipe.proto.GraphTemplateProto...
#
# Mantenemos todo el package mediapipe + protobuf intacto. El costo en
# tamaño del APK es marginal frente a los ~530 MB del modelo descargado.
-keep class com.google.mediapipe.** { *; }
-keep class com.google.protobuf.** { *; }
-dontwarn com.google.mediapipe.**
-dontwarn com.google.protobuf.**

# TFLite (subyacente a MediaPipe) tambien usa reflection para sus delegates.
-keep class org.tensorflow.lite.** { *; }
-dontwarn org.tensorflow.lite.**
