import 'dart:ffi';

/// Clave de `version.json` para este dispositivo. La arquitectura es la del
/// proceso: un teléfono de 64 bits con Android de 32 (Android Go) corre la
/// app en ARMv7 y necesita ese APK, no el ARM64.
String? currentTargetKey() => switch (Abi.current()) {
  Abi.androidArm64 => 'android-arm64',
  Abi.androidArm => 'android-armv7',
  Abi.androidX64 => 'android-x86_64',
  Abi.windowsX64 => 'windows-x64',
  _ => null,
};
