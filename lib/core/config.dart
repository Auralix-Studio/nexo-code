/// Configuración global de la aplicación.
class AppConfig {
  /// Versión semver de la app. Fuente única — usar en UI y user-agent.
  /// Mantener sincronizada con `version:` en pubspec.yaml.
  static const String appVersion = '1.0.0';
  static const int appBuild = 1;

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

/// Configuración del asistente IA **Lumen**.
///
/// Filosofía:
/// - 100% on-device. Toda la inferencia corre vía MediaPipe LLM Inference
///   (CPU/GPU del dispositivo). Cero llamadas a APIs externas.
/// - Opt-in. La descarga del modelo solo ocurre cuando el usuario activa
///   Lumen y acepta los términos.
/// - Gratis y sin fricción. El modelo se mirror-ea en GitHub Releases del
///   repo Nexo (la licencia Gemma se aceptó al subirlo). El usuario no
///   necesita cuenta de HuggingFace ni token.
///
/// Para publicar un modelo nuevo:
///   1. Aceptar términos Gemma en https://huggingface.co/litert-community
///   2. Descargar el .task de la variante deseada.
///   3. Subirlo como release asset al repo `Alexito-Hub/nexo` con el tag
///      indicado en [modelReleaseTag].
///   4. Verificar el SHA-256 y actualizarlo en [modelSha256] (el manager
///      rechaza descargas con checksum distinto).
class LumenConfig {
  /// Modelo por defecto: Gemma 3 1B IT, quantizado int4 (QAT) por Google.
  /// ~529 MB descarga, ~800 MB RAM en runtime, 15-25 tok/s en móvil moderno.
  /// Origen: https://huggingface.co/litert-community/Gemma3-1B-IT
  static const String modelFilename = 'gemma3-1b-it-int4.task';

  /// Tag del release de GitHub donde está alojado el .task.
  static const String modelReleaseTag = 'lumen-models-v1';

  /// URL pública de descarga directa (sin auth).
  static const String modelDownloadUrl =
      'https://github.com/Alexito-Hub/nexo/releases/download/'
      '$modelReleaseTag/$modelFilename';

  /// SHA-256 esperado del archivo. TODO: completar tras subir el release.
  /// Para calcularlo: `sha256sum gemma3-1b-it-int4.task` (Linux/macOS) o
  /// `Get-FileHash -Algorithm SHA256 gemma3-1b-it-int4.task` (PowerShell).
  static const String modelSha256 = 'TODO_SHA256_OF_GEMMA_1B_INT4';

  /// Tamaño esperado en bytes (para el progress bar). ~529 MB.
  /// TODO: completar exacto tras subir el release.
  static const int modelSizeBytes = 529 * 1024 * 1024;

  /// `true` si el operador (Alessandro) ya subió el modelo al release y
  /// pegó el checksum real. Mientras esté en `TODO_*`, la app no intentará
  /// descargar y mostrará un mensaje claro en el onboarding.
  static bool get isConfigured => modelSha256 != 'TODO_SHA256_OF_GEMMA_1B_INT4';

  /// Etiqueta humana del modelo activo (para UI/settings).
  static const String modelDisplayName = 'Gemma 3 · 1B';
}
