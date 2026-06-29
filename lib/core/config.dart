/// Configuración del autoupdater de la app.
///
/// El repo en GitHub (`auralix-studio/nexo`) hostea releases de la **app**:
/// tag semver (`v1.3.0`) con los artefactos: APK universal + APKs split por
/// ABI (Android) y el zip/instalador de Windows. El release "Latest" en
/// GitHub es el target del autoupdater (`/releases/latest`). El updater
/// elige el artefacto por plataforma y, en Android, prefiere el **universal**.
class UpdateConfig {
  static const String repo = 'auralix-studio/nexo';
  static const String latestReleaseApi =
      'https://api.github.com/repos/$repo/releases/latest';

  /// APKs aptos para el autoupdate (Android). Si el release no trae ninguno,
  /// se ignora (puede ser un release exclusivo de modelos).
  static bool isApkAsset(String name) => name.toLowerCase().endsWith('.apk');

  /// Artefacto de Windows (instalador o zip portable).
  static bool isWindowsAsset(String name) {
    final n = name.toLowerCase();
    return n.endsWith('.exe') || n.endsWith('.msix') || n.endsWith('.zip');
  }

  /// El APK **universal** corre en todo dispositivo; se prefiere sobre los
  /// split por ABI (arm64-v8a, armeabi-v7a, x86_64) para el auto-update.
  static bool isUniversalApk(String name) =>
      isApkAsset(name) && name.toLowerCase().contains('universal');

  /// Throttle del chequeo automático en el arranque para no martillar el
  /// rate limit anónimo de GitHub API (60 req/h por IP).
  static const Duration checkInterval = Duration(hours: 24);
}

/// Configuración global de la aplicación.
class AppConfig {
  /// Versión semver de la app. Fuente única — usar en UI y user-agent.
  /// Mantener sincronizada con `version:` en pubspec.yaml.
  static const String appVersion = '1.3.1';
  static const int appBuild = 6;

  static const String apiBaseUrl = 'https://sigma.upla.edu.pe/api';
  static const String nomSys = 'SIGMA';
  static const Duration httpTimeout = Duration(seconds: 30);
  static const String userAgent =
      'Nexo-UPLA/$appVersion (Flutter; multiplatform)';

  /// Tipo de documento por defecto que usan los endpoints de pagos.
  static const String tipDI = '12';

  /// Foto de perfil del estudiante. Patrón visto en el bundle de SIGMA.
  /// Si no existe, el servidor responde 404 (manejar con errorBuilder).
  static String photoUrlFor(String codigo) =>
      'https://academico.upla.edu.pe/FotosAlum/037000$codigo.jpg';
}

/// Configuración de la integración Microsoft 365 / Teams (Graph Education).
///
/// El login es OAuth2 **Device Code Flow** con peticiones HTTP propias
/// (sin SDK): la app pide un código, el alumno lo confirma en el navegador
/// y luego sondeamos el token. Funciona igual en Android, iOS, Escritorio y
/// (con la salvedad de CORS) Web.
///
/// ⚠ Falta el registro de la app en Azure AD. Para probar de extremo a
/// extremo, registra un *public client* en el portal de Azure y pega aquí su
/// Application (client) ID. Pasos en [README]/abajo:
///   1. Azure Portal → Microsoft Entra ID → App registrations → New.
///   2. Supported account types: cuentas del directorio organizacional.
///   3. Authentication → Advanced → "Allow public client flows" = Yes
///      (imprescindible para Device Code).
///   4. API permissions → Microsoft Graph → Delegated:
///      EduRoster.ReadBasic, EduAssignments.ReadBasic (+ offline_access,
///      openid, profile, User.Read).
///   5. Copia el Application (client) ID → [msClientId].
class MsConfig {
  /// Application (client) ID del registro en Azure AD.
  /// TODO: reemplazar por el ID real del registro de la universidad.
  static const String clientId = 'TODO_AZURE_CLIENT_ID';

  /// Tenant. `organizations` acepta cualquier cuenta institucional; si la
  /// universidad exige su propio tenant, usa su GUID o dominio
  /// (p.ej. `upla.edu.pe`).
  static const String tenant = 'organizations';

  static String get _authority =>
      'https://login.microsoftonline.com/$tenant/oauth2/v2.0';
  static String get deviceCodeUrl => '$_authority/devicecode';
  static String get tokenUrl => '$_authority/token';

  static const String graphBaseUrl = 'https://graph.microsoft.com/v1.0';

  /// Permisos delegados mínimos para leer clases y tareas propias del alumno.
  /// `offline_access` habilita el refresh token.
  static const List<String> scopes = [
    'offline_access',
    'openid',
    'profile',
    'User.Read',
    'EduRoster.ReadBasic',
    'EduAssignments.ReadBasic',
  ];

  static String get scopeParam => scopes.join(' ');

  /// `true` cuando aún no se ha configurado el registro de Azure AD.
  static bool get isConfigured => clientId != 'TODO_AZURE_CLIENT_ID';
}



