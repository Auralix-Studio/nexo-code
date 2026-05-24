import 'package:nexo/data/intranet_client.dart';
import 'package:nexo/domain/models.dart';

/// Mapea endpoints de Intranet → modelos. Usa las credenciales guardadas
/// (mismas que SIGMA) para abrir su propia sesión por cookie.
class IntranetRepository {
  IntranetRepository(this._client);
  final IntranetClient _client;

  bool _ready = false;

  /// Asegura una sesión Intranet activa antes de consultar.
  Future<bool> ensureSession(String usuario, String contrasena) async {
    if (_ready && _client.isLoggedIn) return true;
    _ready = await _client.login(usuario, contrasena);
    return _ready;
  }

  /// Boleta de notas del periodo (modelo nuevo 2026-1+).
  /// `consultarconstanciaNotasDetallado` → lista de cursos.
  Future<List<BoletaCurso>> boleta(int anio, int periodo) async {
    final rows = await _client.postJsonList(
      'consultarconstanciaNotasDetallado',
      {'anio': '$anio', 'periodo': '$periodo'},
      referer: 'repRankingPromocionalEst',
    );
    return rows
        .whereType<List<dynamic>>()
        .where((r) => r.length >= 11) // descarta legacy/errores
        .map(BoletaCurso.fromRow)
        .where((c) => c.nombre.isNotEmpty && c.matriculaAsignaturaId.isNotEmpty)
        .toList();
  }

  /// Boleta legacy (≤2025): el mismo endpoint devuelve filas de 50 columnas
  /// posicionales, idénticas al modelo de 2 parciales.
  Future<List<NotaAsignatura>> boletaLegacy(int anio, int periodo) async {
    final rows = await _client.postJsonList(
      'consultarconstanciaNotasDetallado',
      {'anio': '$anio', 'periodo': '$periodo'},
      referer: 'repRankingPromocionalEst',
    );
    return rows
        .whereType<List<dynamic>>()
        .where((r) => r.length >= 24) // legacy ~50 cols
        .map(NotaAsignatura.fromLegacyRow)
        .where((n) => n.asignatura.isNotEmpty)
        .toList();
  }

  /// Detalle por unidad/evidencia de un curso.
  /// `consultarDetalleBoletaNotas` → unidades + evidencias + promedios.
  Future<CursoDetalleNotas> detalleCurso(
    int anio,
    int periodo,
    String matriculaAsignaturaId,
  ) async {
    final rows = await _client.postJsonList(
      'consultarDetalleBoletaNotas',
      {
        'anio': '$anio',
        'periodo': '$periodo',
        'matricula_asignatura_id': matriculaAsignaturaId,
      },
      referer: 'repRankingPromocionalEst',
    );
    return CursoDetalleNotas.fromRows(rows);
  }

  /// Record histórico consolidado (plan de estudios, todas las notas finales).
  Future<List<RecordCurso>> recordAcademico(String codest) async {
    final rows = await _client.postJsonList(
      'consultarProgresoCurricular',
      {'codest': codest},
      referer: 'repProgresoCurricularEst',
    );
    return rows
        .whereType<List<dynamic>>()
        .map(RecordCurso.fromRow)
        .where((c) => c.nombre.isNotEmpty)
        .toList();
  }

  void invalidate() => _ready = false;
}
