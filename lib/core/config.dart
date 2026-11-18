class UpdateConfig {
  static const String repo = 'auralix-studio/nexo';

  /// Lo publica el release en el sitio (GitHub Pages, servido por CDN). La
  /// revisión diaria nativa de Android usa la misma URL (UpdateCheckJob.kt).
  static const String manifestUrl = 'https://nexo.aurx.pro/version.json';

  /// El mismo archivo, subido al último release.
  static const String manifestFallbackUrl =
      'https://github.com/$repo/releases/latest/download/version.json';
  static bool isWindowsAsset(String name) {
    final n = name.toLowerCase();
    return RegExp(r'^nexo-v\d+\.\d+\.\d+-setup-x64\.exe$').hasMatch(n);
  }

  static const Duration checkInterval = Duration(hours: 24);
}

class StoreBuild {
  static const bool isStore = bool.fromEnvironment('STORE_BUILD');
}

class AppConfig {
  static const String appVersion = '2.0.1';
  static const int appBuild = 34;

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
  // v6: avisos de notas al registrar el docente (FCM) y caché temporal en el
  // servidor.
  // v5: la app solo habla con la API de Nexo (Azure + MongoDB Atlas), que
  // inicia sesión en la UPLA en nombre del usuario sin guardar contraseñas.
  //
  // Es la versión que viaja con la app (textos en assets/legal/). La vigente
  // la publica el backend (`GET /legal`, `Nexo.Legal`): si es mayor, se pide
  // aceptarla sin esperar una actualización (ver LegalUpdates).
  static const int version = 6;
  static final DateTime updatedAt = DateTime(2026, 11, 15);
}

/// Nexo's own API (repository nexo-backend): the only server the app talks
/// to. It reads SIGMA, the Intranet and the Language Center on the app's
/// behalf.
class BackendConfig {
  static const String baseUrl = String.fromEnvironment(
    'NEXO_BACKEND_URL',
    defaultValue: 'https://api.nexo.aurx.pro',
  );
  static String get apiBaseUrl => '$baseUrl/api/v1';
  // El servidor se apaga sin uso y tarda hasta ~30 s en despertar: la
  // primera petición necesita margen.
  static const Duration timeout = Duration(seconds: 45);
}
