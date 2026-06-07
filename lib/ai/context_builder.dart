import '../data/app_store.dart';

/// Construye el "system preamble" que se prepende al primer mensaje del
/// usuario en cada sesión de chat con Lumen.
///
/// **v1: preámbulo mínimo (~150 tokens).** Aprendizaje doloroso de los
/// primeros tests reales: Gemma 3 1B con 3000+ tokens de contexto entra
/// en mode collapse y devuelve basura (`**\n\n**\n\n**` infinito). El
/// 270M directamente no responde. La conclusión: para modelos chicos
/// (<2B), inyectar KB + horario + cuotas no escala — el modelo se ahoga.
///
/// v1 envía solo identidad + nombre del estudiante + ciclo + fecha. Si
/// el usuario pregunta cosas específicas ("¿cuándo es mi próxima clase?")
/// el modelo no las responderá con precisión. v1.1 podría hacer RAG real
/// (resolver la query → recuperar el bloque relevante → inyectar solo
/// ese bloque) en vez de mandar todo el contexto siempre.
class LumenContextBuilder {
  LumenContextBuilder(this._store);

  final AppStore _store;

  /// Devuelve el preámbulo listo para concatenar al primer mensaje del
  /// usuario.
  ///
  /// [modelId] se acepta por compatibilidad con la sesión, aunque por
  /// ahora el preámbulo es el mismo para todos los modelos.
  Future<String> buildPreamble({required String modelId}) async {
    final p = _store.profile.value;
    final name = p?.estudiante.split(' ').first ?? 'estudiante';
    final carrera = p?.carrera ?? '';
    final ciclo = p?.nivel ?? '';
    final now = DateTime.now();
    final today = '${_weekday(now.weekday)} ${now.day} de ${_month(now.month)}';

    return 'Eres Lumen, un asistente conversacional breve y amable de la '
        'app Nexo, para estudiantes de la Universidad Peruana Los Andes. '
        'Hoy es $today. El estudiante se llama $name'
        '${carrera.isEmpty ? '' : ' y estudia $carrera'}'
        '${ciclo.isEmpty ? '' : ' (ciclo $ciclo)'}'
        '. Responde en español, conciso (1-3 oraciones). Si no sabes algo, '
        'dilo con honestidad.\n\n';
  }

  static String _weekday(int w) => const [
        '', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes',
        'sábado', 'domingo'
      ][w.clamp(0, 7)];

  static String _month(int m) => const [
        '', 'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
        'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
      ][m.clamp(0, 12)];
}
