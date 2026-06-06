import 'package:nexo/data/graph_client.dart';
import 'package:nexo/domain/models.dart';

/// Mapea los endpoints de Microsoft Graph (Education API) → modelos de
/// dominio. Cada clase = un grupo de Teams = una asignatura.
class TeamsRepository {
  TeamsRepository(this._client);
  final GraphClient _client;

  List<Map<String, dynamic>> _values(Map<String, dynamic> body) {
    final v = body['value'];
    if (v is! List) return const [];
    return v.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }

  /// Clases del alumno: `GET /education/me/classes`.
  Future<List<TeamsClass>> classes() async {
    final body = await _client.get('education/me/classes');
    return _values(body).map(TeamsClass.fromJson).toList();
  }

  /// Todas las tareas del alumno en una sola llamada:
  /// `GET /education/me/assignments`.
  /// Aquí `instructions`/`webUrl` vienen null (usar [classAssignments]).
  Future<List<TeamsAssignment>> assignments() async {
    final body = await _client.get('education/me/assignments');
    return _values(body).map(TeamsAssignment.fromJson).toList();
  }

  /// Detalle completo de tareas de una clase (con instructions/webUrl):
  /// `GET /education/classes/{id}/assignments`.
  Future<List<TeamsAssignment>> classAssignments(String classId) async {
    final body = await _client.get('education/classes/$classId/assignments');
    return _values(body).map(TeamsAssignment.fromJson).toList();
  }
}
