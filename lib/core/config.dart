/// Configuración global de la aplicación.
class AppConfig {
  static const String apiBaseUrl = 'https://sigma.upla.edu.pe/api';
  static const String nomSys = 'SIGMA';
  static const Duration httpTimeout = Duration(seconds: 30);
  static const String userAgent =
      'Nexo-UPLA/0.1 (Flutter; multiplatform)';

  /// Tipo de documento por defecto que usan los endpoints de pagos.
  static const String tipDI = '12';

  /// Foto de perfil del estudiante. Patrón visto en el bundle de SIGMA.
  /// Si no existe, el servidor responde 404 (manejar con errorBuilder).
  static String photoUrlFor(String codigo) =>
      'https://academico.upla.edu.pe/FotosAlum/037000$codigo.jpg';
}
