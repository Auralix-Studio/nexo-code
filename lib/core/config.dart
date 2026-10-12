class UpdateConfig {
  static const String repo = 'auralix-studio/nexo';
  static const String latestReleaseApi =
      'https://api.github.com/repos/$repo/releases/latest';
  static bool isApkAsset(String name) => name.toLowerCase().endsWith('.apk');
  static bool isWindowsAsset(String name) {
    final n = name.toLowerCase();
    return RegExp(r'^nexo-v\d+\.\d+\.\d+-setup-x64\.exe$').hasMatch(n);
  }

  static bool isUniversalApk(String name) =>
      isApkAsset(name) && name.toLowerCase().contains('universal');
  static const Duration checkInterval = Duration(hours: 24);
}

class StoreBuild {
  static const bool isStore = bool.fromEnvironment('STORE_BUILD');
}

class AppConfig {
  static const String appVersion = '1.7.2';
  static const int appBuild = 20;
  static const String apiBaseUrl = 'https://sigma.upla.edu.pe/api';
  static const String nomSys = 'SIGMA';
  static const Duration httpTimeout = Duration(seconds: 30);
  static const String userAgent =
      'Nexo-UPLA/$appVersion (Flutter; multiplatform)';
  static const String tipDI = '12';

  /// Foto institucional. Igual que el cliente oficial de SIGMA: los códigos
  /// de alumno (7 caracteres, p. ej. U01025B) están en `FotosAlum/037000…`;
  /// los de docente (DNI de 8 dígitos) en `PhotD/…`.
  static String photoUrlFor(String code) {
    final c = code.trim();
    return c.length == 7
        ? 'https://academico.upla.edu.pe/FotosAlum/037000$c.jpg'
        : 'https://academico.upla.edu.pe/PhotD/$c.jpg';
  }
}

class LegalTerms {
  // v4: documentos formales (Términos y Condiciones, Política de Privacidad y
  // Política de Cookies) con ley aplicable y límites de responsabilidad.
  static const int version = 4;
  static final DateTime updatedAt = DateTime(2026, 10, 8);
}
