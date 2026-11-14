import 'package:flutter/foundation.dart';
import 'package:nexo/data/remote/backend_client.dart';
import 'package:nexo/data/services/directory_service.dart';
import 'package:nexo/domain/unified_models.dart';

/// Integraciones del estudiante: compartir su perfil y horario con un
/// calendario (enlace `.ics`) y con apps externas ("Conectar con Nexo").
///
/// Nada se comparte hasta que el estudiante lo activa, y desactivarlo borra
/// los datos del servidor, el enlace del calendario y el acceso de las apps.
class IntegrationService extends ChangeNotifier {
  IntegrationService({required DirectoryService directory})
    : _directory = directory;

  final DirectoryService _directory;
  BackendClient get _client => _directory.client;

  IntegrationStatus _status = IntegrationStatus.empty;
  CalendarLinks? _links;
  bool _loading = false;
  bool _loaded = false;
  Object? _error;

  IntegrationStatus get status => _status;

  /// El enlace recién creado. El backend solo lo entrega una vez: tras
  /// reiniciar la app, un calendario activo se muestra sin enlace.
  CalendarLinks? get links => _links;
  bool get loading => _loading;
  bool get loaded => _loaded;
  Object? get error => _error;

  Future<void> load() => _run(() async {
    _status = await _client.integrationStatus();
    _loaded = true;
  });

  /// Sube (o actualiza) el perfil y el horario compartidos.
  Future<void> share({
    required Student? profile,
    required List<ScheduleClass> schedule,
    String? term,
  }) => _run(() async {
    await _client.putShared(
      sharedPayload(profile: profile, schedule: schedule, term: term),
    );
    _status = await _client.integrationStatus();
  });

  Future<void> stopSharing() => _run(() async {
    await _client.deleteShared();
    _links = null;
    _status = await _client.integrationStatus();
  });

  Future<void> enableCalendar() => _run(() async {
    _links = await _client.enableCalendar();
    _status = await _client.integrationStatus();
  });

  Future<void> disableCalendar() => _run(() async {
    await _client.disableCalendar();
    _links = null;
    _status = await _client.integrationStatus();
  });

  /// La app que pide acceso con [code], para mostrar qué pide antes de decidir.
  Future<ConnectionRequest> preview(String code) async {
    await _directory.ensureConnected();
    return _client.previewConnection(code);
  }

  Future<void> decide(String code, {required bool approve}) => _run(() async {
    await _client.decideConnection(code, approve: approve);
    _status = await _client.integrationStatus();
  });

  Future<void> revoke(String id) => _run(() async {
    await _client.revokeConnection(id);
    _status = await _client.integrationStatus();
  });

  Future<void> _run(Future<void> Function() action) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await _directory.ensureConnected();
      await action();
    } catch (e) {
      _error = e;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}

final _hhmm = RegExp(r'^([01]\d|2[0-3]):[0-5]\d');

/// Lo que se envía al backend: solo identificación y horario semanal. Nunca
/// notas, pagos ni datos de contacto.
@visibleForTesting
Map<String, dynamic> sharedPayload({
  required Student? profile,
  required List<ScheduleClass> schedule,
  String? term,
}) {
  String? clean(String? value) {
    final v = value?.trim() ?? '';
    return v.isEmpty ? null : v;
  }

  String? hm(String raw) => _hhmm.firstMatch(raw.trim())?.group(0);

  final seen = <String>{};
  final classes = <Map<String, dynamic>>[];
  for (final c in schedule) {
    final start = hm(c.startTime);
    final end = hm(c.endTime);
    final course = clean(c.subject);
    if (course == null || start == null || end == null) continue;
    if (c.weekday < 1 || c.weekday > 7 || start.compareTo(end) >= 0) continue;
    if (!seen.add('$course|${c.weekday}|$start')) continue;
    classes.add({
      'course': course,
      'weekday': c.weekday,
      'start': start,
      'end': end,
      'section': ?clean(c.section),
      'room': ?clean(c.locationFull),
      'teacher': ?clean(c.teacher),
      'modality': ?clean(c.modality),
    });
  }

  return {
    'profile': {
      'code': ?clean(profile?.id),
      'name': ?clean(profile?.fullName),
      'career': ?clean(profile?.career),
      'faculty': ?clean(profile?.faculty),
    },
    'schedule': {
      'term': {'name': ?clean(term)},
      'classes': classes,
    },
  };
}
