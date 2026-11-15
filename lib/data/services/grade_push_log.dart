/// Cursos de los que acaba de llegar un push de notas.
///
/// El push (el docente guardó una nota) y el aviso local de la boleta
/// (`_checkGrades`, al ver que la nota cambió) describen el mismo cambio. Si
/// el push de un curso llegó hace menos de [window], el aviso local de ese
/// curso se omite para no notificar dos veces.
class GradePushLog {
  GradePushLog({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  static GradePushLog instance = GradePushLog();

  static const window = Duration(minutes: 10);

  final DateTime Function() _clock;
  final Map<String, DateTime> _seen = {};

  /// Registra un push de notas: [code] es `data.course` (código del curso) y
  /// [title] el título visible (`Nueva nota · <curso>`).
  void record({String? code, String? title}) {
    final now = _clock();
    _seen.removeWhere((_, at) => now.difference(at) >= window);
    for (final key in [_key(code), _key(_courseFromTitle(title))]) {
      if (key != null) _seen[key] = now;
    }
  }

  /// Llegó un push de este curso (por código o por nombre) hace poco.
  bool wasRecent({String? code, String? name}) {
    final now = _clock();
    for (final key in [_key(code), _key(name)]) {
      final at = key == null ? null : _seen[key];
      if (at != null && now.difference(at) < window) return true;
    }
    return false;
  }

  static String? _courseFromTitle(String? title) {
    if (title == null) return null;
    final i = title.indexOf('·');
    return i < 0 ? null : title.substring(i + 1);
  }

  static String? _key(String? value) {
    final v = value?.trim().toUpperCase();
    return v == null || v.isEmpty ? null : v;
  }
}
