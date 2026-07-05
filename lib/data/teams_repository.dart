import 'package:nexo/data/graph_client.dart';
import 'package:nexo/domain/models.dart';

class TeamsRepository {
  TeamsRepository(this._client);
  final GraphClient _client;
  List<Map<String, dynamic>> _values(Map<String, dynamic> body) {
    final v = body['value'];
    if (v is! List) return const [];
    return v.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }

  Future<List<TeamsClass>> classes() async {
    final body = await _client.get('education/me/classes');
    return _values(body).map(TeamsClass.fromJson).toList();
  }

  Future<List<TeamsAssignment>> assignments() async {
    final body = await _client.get('education/me/assignments');
    return _values(body).map(TeamsAssignment.fromJson).toList();
  }

  Future<List<TeamsAssignment>> classAssignments(String classId) async {
    final body = await _client.get('education/classes/$classId/assignments');
    return _values(body).map(TeamsAssignment.fromJson).toList();
  }
}
