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

/// Metadata de un modelo Lumen instalable.
///
/// Cada variante (270M, 1B, etc) es una instancia const de esta clase.
/// El manager opera siempre sobre una instancia activa que el usuario
/// elige en el onboarding y puede cambiar desde settings.
class LumenModelSpec {
  const LumenModelSpec({
    required this.id,
    required this.displayName,
    required this.filename,
    required this.sha256,
    required this.sizeBytes,
    required this.tagline,
    required this.recommendedFor,
  });

  /// Identificador estable, persistido en SharedPreferences.
  /// No cambiar entre releases sin lógica de migración.
  final String id;

  /// Nombre para mostrar en UI. Usamos nombres camuflados ("Lumen Ligero")
  /// en lugar del nombre del modelo subyacente — al usuario no le importa
  /// que sea Gemma/Qwen/Phi, le importa "rápido vs preciso".
  final String displayName;

  /// Nombre del .task tal como está subido al release de GH.
  final String filename;

  /// SHA-256 esperado. Si está en TODO_*, el modelo no se considera
  /// configurado y la UI lo deshabilita.
  final String sha256;

  /// Tamaño exacto en bytes — para progress bar y validación rápida.
  final int sizeBytes;

  /// Una línea corta para el selector ('Ligero · descarga rápida').
  final String tagline;

  /// Para qué hardware se recomienda esta variante.
  final String recommendedFor;

  /// URL pública de descarga directa (sin auth) en GH Releases.
  String get downloadUrl =>
      'https://github.com/Alexito-Hub/nexo/releases/download/'
      '${LumenConfig.releaseTag}/$filename';

  /// `true` cuando el operador ya subió el modelo y pegó el checksum real.
  bool get isConfigured => !sha256.startsWith('TODO_');
}

/// Configuración del asistente IA **Lumen**.
///
/// Filosofía:
/// - 100% on-device. Toda la inferencia corre vía MediaPipe LLM Inference
///   (CPU/GPU del dispositivo). Cero llamadas a APIs externas.
/// - Opt-in. La descarga del modelo solo ocurre cuando el usuario activa
///   Lumen y acepta los términos.
/// - Gratis y sin fricción. Los modelos se mirror-ean en GitHub Releases
///   del repo Nexo (la licencia Gemma se aceptó al subirlos). El usuario
///   no necesita cuenta de HuggingFace ni token.
///
/// Para publicar un modelo nuevo:
///   1. Aceptar términos Gemma en Kaggle o HuggingFace.
///   2. Descargar el .task de la variante deseada.
///   3. Subirlo como release asset al repo `Alexito-Hub/nexo` con el tag
///      indicado en [releaseTag].
///   4. Verificar el SHA-256 y pegarlo en la entrada del modelo en [models]
///      (el manager rechaza descargas con checksum distinto).
class LumenConfig {
  /// Tag del release de GitHub donde están alojados los .task de todos
  /// los modelos.
  static const String releaseTag = 'lumen-models-v1';

  /// Variante ligera — para teléfonos viejos o con poca RAM.
  /// Origen: Kaggle (google/gemma-3/tfLite/gemma3-270m-it-q8 v1)
  /// equivalente a https://huggingface.co/litert-community/gemma-3-270m-it.
  /// ~290 MB en disco, ~500 MB RAM en runtime, 30-50 tok/s en gama media.
  /// Sin int4 disponible para móvil — Google solo publica q8.
  static const LumenModelSpec light = LumenModelSpec(
    id: 'gemma-270m-int8',
    displayName: 'Lumen Ligero',
    filename: 'gemma-3-270m-it-int8.task',
    sha256:
        '0f7147f1c22eaf758b819bbf7841793e4c90096c9352cde7fbe5c631f2265ef5',
    sizeBytes: 303950933,
    tagline: 'Ligero · descarga rápida',
    recommendedFor: 'Teléfonos con 2-3 GB de RAM o gama media-baja.',
  );

  /// Variante estándar — recomendada para hardware moderno.
  /// Origen: Kaggle (google/gemma-3/tfLite/gemma3-1b-it-int4 v1).
  /// ~529 MB en disco, ~800 MB RAM en runtime, 15-25 tok/s en móvil moderno.
  static const LumenModelSpec standard = LumenModelSpec(
    id: 'gemma-1b-int4',
    displayName: 'Lumen Estándar',
    filename: 'gemma3-1B-it-int4.task',
    sha256:
        'e3d981c01aeaaac69a84ffa0d4be13281b3176731063f1bea1c9fe6887bd9dee',
    sizeBytes: 554661243,
    tagline: 'Mejor calidad de respuestas',
    recommendedFor: 'Teléfonos con 4 GB de RAM o más.',
  );

  /// Catálogo completo de modelos disponibles.
  static const List<LumenModelSpec> models = [light, standard];

  /// Modelo seleccionado por defecto si el usuario no elige uno explícito
  /// en el onboarding. Pickeamos el liviano para maximizar compatibilidad.
  static const LumenModelSpec defaultModel = light;

  /// Busca un modelo por id; devuelve [defaultModel] si no se encuentra
  /// (útil para tolerar SharedPreferences viejas con ids removidos).
  static LumenModelSpec byId(String? id) {
    if (id == null) return defaultModel;
    return models.firstWhere(
      (m) => m.id == id,
      orElse: () => defaultModel,
    );
  }

  /// `true` si AL MENOS uno de los modelos del catálogo está listo para
  /// descargar (tiene checksum real). Si todos están en TODO, la app
  /// muestra el aviso de "no disponible aún".
  static bool get anyConfigured => models.any((m) => m.isConfigured);
}
