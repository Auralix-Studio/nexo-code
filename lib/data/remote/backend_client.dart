import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:nexo/core/config.dart';
import 'package:nexo/core/errors.dart';
import 'package:nexo/core/session_scope.dart';
import 'package:nexo/data/services/app_attestation.dart';
import 'package:nexo/data/remote/integration_models.dart';
import 'package:nexo/data/remote/secure_http.dart';

export 'package:nexo/data/remote/integration_models.dart';

/// Resultado de un intento de re-autenticación. Distingue un fallo
/// transitorio (conservar la sesión) de un rechazo real de credenciales
/// (cerrar la sesión).
enum ReauthOutcome {
  /// Hay tokens nuevos: se reintenta la petición original.
  refreshed,

  /// El backend rechazó las credenciales: terminar la sesión.
  invalidCredentials,

  /// No se pudo verificar ahora (sin red, backend caído): NO cerrar sesión.
  unavailable,
}

/// Cliente de la API de Nexo: el único servidor con el que habla la app.
///
/// El backend verifica la clave contra la universidad, abre allí las
/// sesiones y devuelve los datos ya ordenados. La app no llama a SIGMA, la
/// Intranet ni el Centro de Idiomas.
///
/// Los tokens viven aquí; [SessionService] los guarda en el almacén seguro
/// ([onTokensChanged]) para volver a entrar al abrir la app. Si el de acceso
/// venció se renueva con `POST /auth/refresh` (una sola renovación para
/// todas las peticiones que reciban 401 a la vez) y, si eso no basta, se
/// inicia sesión otra vez con las credenciales del dispositivo
/// ([reauthenticate]).
class BackendClient {
  BackendClient({
    http.Client? transport,
    AppAttestation? attestation,
    SessionScope? scope,
  }) : _given = transport,
       _attestation = attestation ?? AppAttestation.none,
       scope = scope ?? SessionScope();

  final http.Client? _given;
  final AppAttestation _attestation;
  http.Client? _http;

  /// Sesión a la que pertenece cada petición: una respuesta tardía de una
  /// sesión anterior nunca se aplica a la nueva.
  final SessionScope scope;

  String? _access;
  String? _refresh;

  // Solo en memoria: si la sesión de la universidad vence en el servidor
  // (`reauth_required`), se vuelve a iniciar sesión sin molestar al usuario.
  String? _user;
  String? _password;

  /// Vuelve a iniciar sesión con las credenciales guardadas cuando el token
  /// venció y no se pudo renovar. Lo pone [SessionService].
  Future<ReauthOutcome> Function()? reauthenticate;

  /// Las credenciales ya no sirven: la sesión debe terminar.
  void Function()? onSessionInvalid;

  /// `POST /auth/refresh` entregó tokens nuevos ([access] y [refresh]) o
  /// rechazó el refresh token (ambos `null`): [SessionService] los persiste.
  Future<void> Function(String? access, String? refresh)? onTokensChanged;

  /// Renovación en curso: las peticiones que reciben 401 a la vez esperan
  /// esta misma, porque el refresh token es de un solo uso.
  Future<ReauthOutcome>? _renewal;

  bool get isConnected => _access != null;
  String? get accessToken => _access;
  String? get refreshToken => _refresh;

  /// Restaura (o borra) los tokens guardados en el dispositivo. Sin token de
  /// acceso también se olvida el refresh token.
  void setToken(String? access, {String? refresh}) {
    _access = access;
    _refresh = access == null ? null : refresh ?? _refresh;
    if (access == null) _renewal = null;
  }

  Future<http.Client> _client() async =>
      _http ??= _given ?? await createSecureClient();

  /// Inicia sesión en el backend, que verifica la clave contra SIGMA (o la
  /// Intranet si SIGMA no responde) y abre allí las sesiones de la
  /// universidad. La contraseña no se guarda en el servidor. Devuelve la
  /// sesión (`access_token`, `refresh_token`, `user`…).
  Future<Map<String, dynamic>> login({
    required String usuario,
    required String clave,
  }) async {
    final body = await _send(
      'POST',
      '/auth/login',
      body: {'user': usuario, 'password': clave},
      authorize: false,
      module: true,
    );
    _access = body['access_token'] as String?;
    _refresh = body['refresh_token'] as String?;
    _user = usuario;
    _password = clave;
    return body;
  }

  /// Cierra la sesión en el servidor (revoca el refresh token). Sin red no
  /// pasa nada: el token vence solo.
  Future<void> logout() async {
    final token = _refresh;
    if (token == null) return;
    try {
      await _send(
        'POST',
        '/auth/logout',
        body: {'refresh_token': token},
        authorize: false,
        retried: true,
        module: true,
      );
    } on BackendException {
      // Sin red o ya revocado.
    }
  }

  // --- Datos del estudiante (formato limpio del backend) --------------------

  /// Perfil del estudiante (`GET /profile`).
  Future<Map<String, dynamic>> profile() =>
      _send('GET', '/profile', module: true);

  /// Periodos, el más reciente primero (`GET /terms`).
  Future<List<Map<String, dynamic>>> terms() async {
    final body = await _send('GET', '/terms', module: true);
    final raw = body['data'];
    return raw is List
        ? raw.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
        : const [];
  }

  /// Horario semanal de un periodo (`GET /schedule`), Idiomas incluido.
  /// [term] en formato `"2026-2"`; sin él, el periodo activo.
  Future<Map<String, dynamic>> schedule({String? term}) =>
      _send('GET', '/schedule', query: {'term': ?term}, module: true);

  /// Notas de un periodo (`GET /grades`); [term] como `"2026-1"`.
  Future<Map<String, dynamic>> grades({String? term}) =>
      _send('GET', '/grades', query: {'term': ?term}, module: true);

  /// Unidades y evidencias de un curso (`GET /grades/{term}/courses/{id}`).
  Future<Map<String, dynamic>> courseGrades(String term, String id) => _send(
    'GET',
    '/grades/$term/courses/${Uri.encodeComponent(id)}',
    module: true,
  );

  /// Promedio acumulado, créditos y promedio por periodo (`GET /grades/summary`).
  Future<Map<String, dynamic>> gradesSummary() =>
      _send('GET', '/grades/summary', module: true);

  /// Cambia la contraseña de la universidad (`POST /auth/password`). El
  /// backend no la guarda.
  Future<void> changePassword(String current, String newPassword) => _send(
    'POST',
    '/auth/password',
    body: {'current_password': current, 'new_password': newPassword},
    module: true,
  );

  /// Avance curricular (`GET /curriculum`).
  Future<Map<String, dynamic>> curriculum() =>
      _send('GET', '/curriculum', module: true);

  /// Deuda: vencidos, pendientes, tasas y totales (`GET /payments`).
  Future<Map<String, dynamic>> payments() =>
      _send('GET', '/payments', module: true);

  /// Cronograma de cuotas del periodo (`GET /payments/schedule`).
  Future<Map<String, dynamic>> paymentSchedule() =>
      _send('GET', '/payments/schedule', module: true);

  /// Operaciones pagadas, la más reciente primero (`GET /payments/history`).
  Future<Map<String, dynamic>> paymentHistory() =>
      _send('GET', '/payments/history', module: true);

  /// Datos de la constancia de matrícula (`GET /enrollment`).
  Future<Map<String, dynamic>> enrollment({String? term}) =>
      _send('GET', '/enrollment', query: {'term': ?term}, module: true);

  /// Anuncios de la universidad (`GET /publications`).
  Future<List<Map<String, dynamic>>> publications() async {
    final body = await _send('GET', '/publications', module: true);
    final raw = body['data'];
    return raw is List
        ? raw.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
        : const [];
  }

  /// Credencial wifi del campus (`GET /wifi`). Es un secreto: no se guarda.
  Future<Map<String, dynamic>> wifi() => _send('GET', '/wifi', module: true);

  /// Cursos del Centro de Idiomas con sus notas (`GET /languages`).
  Future<List<Map<String, dynamic>>> languages() async {
    final body = await _send('GET', '/languages', module: true);
    final raw = body['courses'];
    return raw is List
        ? raw.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
        : const [];
  }

  // --- Docente (`/teaching/*`) -------------------------------------------------

  /// Lista de un endpoint docente (la respuesta es una lista en `data`).
  Future<List<Map<String, dynamic>>> _teachingList(
    String path, {
    Map<String, String>? query,
  }) async {
    final body = await _send('GET', path, query: query, module: true);
    final raw = body['data'];
    return raw is List
        ? raw.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
        : const [];
  }

  /// Secciones del docente, una por sección real (`GET /teaching/sections`).
  Future<List<Map<String, dynamic>>> teachingSections() =>
      _teachingList('/teaching/sections');

  /// Alumnos de una sección con sus notas por unidad.
  Future<Map<String, dynamic>> teachingRoster(String section) =>
      _send('GET', '/teaching/sections/$section/students', module: true);

  /// Unidades de la sección con sus tipos de nota.
  Future<List<Map<String, dynamic>>> teachingGradeUnits(String section) =>
      _teachingList('/teaching/sections/$section/grade-units');

  /// Guarda una columna de notas; el backend decide insertar o actualizar.
  Future<Map<String, dynamic>> teachingWriteGrades(
    String section,
    Map<String, dynamic> body,
  ) => _send(
    'PUT',
    '/teaching/sections/$section/grades',
    body: body,
    module: true,
  );

  /// Hoja de asistencia de la sección.
  Future<Map<String, dynamic>> teachingAttendance(String section) =>
      _send('GET', '/teaching/sections/$section/attendance', module: true);

  /// Registra una sesión nueva con la hora de la universidad.
  Future<Map<String, dynamic>> teachingTakeAttendance(
    String section,
    Map<String, dynamic> body,
  ) => _send(
    'POST',
    '/teaching/sections/$section/attendance',
    body: body,
    module: true,
  );

  /// Corrige marcas de una sesión ya registrada ([session] = su fecha y hora).
  Future<Map<String, dynamic>> teachingCorrectAttendance(
    String section,
    String session,
    Map<String, dynamic> body,
  ) => _send(
    'PATCH',
    '/teaching/sections/$section/attendance/$session',
    body: body,
    module: true,
  );

  /// Clases de hoy para la marcación virtual.
  Future<List<Map<String, dynamic>>> teachingVirtualClasses() =>
      _teachingList('/teaching/virtual-classes');

  /// Marca entrada o salida de una clase de hoy.
  Future<Map<String, dynamic>> teachingPunch(String classId) => _send(
    'POST',
    '/teaching/virtual-classes/${Uri.encodeComponent(classId)}/punch',
    module: true,
  );

  /// Historial de marcación del docente entre dos fechas `yyyy-MM-dd`.
  Future<List<Map<String, dynamic>>> teachingPunches(String from, String to) =>
      _teachingList('/teaching/punches', query: {'from': from, 'to': to});

  /// Clases programadas con su estado de marcación.
  Future<List<Map<String, dynamic>>> teachingCompliance(
    String from,
    String to,
  ) => _teachingList('/teaching/compliance', query: {'from': from, 'to': to});

  /// Perfil del propio docente (`GET /teaching/me`).
  Future<Map<String, dynamic>> teachingMe() =>
      _send('GET', '/teaching/me', module: true);

  /// Hora oficial de la universidad (`GET /teaching/server-time`).
  Future<Map<String, dynamic>> teachingServerTime() =>
      _send('GET', '/teaching/server-time', module: true);

  /// Registro auxiliar de la sección como archivo (`pdf` o `xlsx`).
  Future<({Uint8List bytes, String? filename, String? contentType})>
  teachingReport(String section, String format) => _download(
    '/teaching/sections/$section/report',
    query: {'format': format},
  );

  /// Entrada de un apoderado: DNI + PIN, sin cuenta de la UPLA. Devuelve los
  /// estudiantes que tiene autorizados, que suelen ser uno.
  Future<List<StudentSummary>> guardianLogin({
    required String dni,
    required String pin,
  }) async {
    final body = await _send(
      'POST',
      '/guardian/login',
      body: {'dni': dni, 'pin': pin},
      authorize: false,
    );
    _access = body['access_token'] as String?;
    _refresh = body['refresh_token'] as String?;
    return (body['estudiantes'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => StudentSummary.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// Ficha de un hijo o tutelado. El backend comprueba el vínculo.
  Future<StudentRecord> guardianStudent(String codigo) async {
    final body = await _send('GET', '/guardian/students/$codigo');
    return StudentRecord.fromJson(
      (body['estudiante'] as Map).cast<String, dynamic>(),
    );
  }

  /// Si esta cuenta tiene acceso al directorio, y con qué rol.
  Future<DirectoryAccess> access() async {
    final body = await _send('GET', '/directory/access');
    return DirectoryAccess.fromJson(body);
  }

  Future<DirectoryPage> students({
    String? query,
    String? school,
    int? cycle,
    int page = 1,
    int limit = 25,
  }) async {
    final params = <String, String>{
      'pagina': '$page',
      'limite': '$limit',
      if (query != null && query.isNotEmpty) 'q': query,
      if (school != null && school.isNotEmpty) 'escuela': school,
      if (cycle != null) 'ciclo': cycle.toString(),
    };
    final body = await _send('GET', '/directory/students', query: params);
    return DirectoryPage.fromJson(body);
  }

  Future<List<String>> schools() async {
    final body = await _send('GET', '/directory/schools');
    final raw = body['escuelas'];
    return raw is List ? raw.map((e) => e.toString()).toList() : const [];
  }

  Future<StudentRecord> student(String codigo) async {
    final body = await _send('GET', '/directory/students/$codigo');
    return StudentRecord.fromJson(
      (body['estudiante'] as Map).cast<String, dynamic>(),
    );
  }

  // --- Administración del acceso -------------------------------------------

  Future<AccessGrants> grants() async {
    final body = await _send('GET', '/directory/grants');
    return AccessGrants.fromJson(body);
  }

  Future<AccessGrant> setGrant(
    String codigo, {
    required String estado,
    String? nota,
  }) async {
    final body = await _send(
      'PUT',
      '/directory/grants/$codigo',
      body: {'estado': estado, 'nota': ?nota},
    );
    return AccessGrant.fromJson(
      (body['acceso'] as Map).cast<String, dynamic>(),
    );
  }

  void disconnect() {
    _access = null;
    _refresh = null;
    _renewal = null;
    _user = null;
    _password = null;
  }

  // --- Integraciones (rutas por módulo, sin prefijo de versión) -------------

  /// Lo que el estudiante comparte, si el calendario está activo y qué apps
  /// tienen acceso.
  Future<IntegrationStatus> integrationStatus() async =>
      IntegrationStatus.fromJson(
        await _send('GET', '/me/shared', module: true),
      );

  Future<void> putShared(Map<String, dynamic> payload) async {
    await _send('PUT', '/me/shared', body: payload, module: true);
  }

  /// Deja de compartir: borra los datos, el calendario y el acceso de las apps.
  Future<void> deleteShared() async {
    await _send('DELETE', '/me/shared', module: true);
  }

  /// Crea o renueva el enlace privado del calendario. Solo se muestra una vez.
  Future<CalendarLinks> enableCalendar() async =>
      CalendarLinks.fromJson(await _send('POST', '/me/calendar', module: true));

  Future<void> disableCalendar() async {
    await _send('DELETE', '/me/calendar', module: true);
  }

  Future<ConnectionRequest> previewConnection(String code) async =>
      ConnectionRequest.fromJson(
        await _send(
          'GET',
          '/me/connections/requests/${Uri.encodeComponent(code)}',
          module: true,
        ),
      );

  Future<void> decideConnection(String code, {required bool approve}) async {
    await _send(
      'POST',
      '/me/connections/requests/${Uri.encodeComponent(code)}',
      body: {'decision': approve ? 'approve' : 'deny'},
      module: true,
    );
  }

  Future<void> revokeConnection(String id) async {
    await _send('DELETE', '/me/connections/$id', module: true);
  }

  // --- Transporte ----------------------------------------------------------

  /// [module]: rutas nuevas del backend (raíz del host, respuesta
  /// `{"ok", "data" | "error"}`); si no, las rutas heredadas de `/api/v1`.
  ///
  /// Corre en la sesión de quien llama ([scope]): si la sesión cambia
  /// mientras espera, la respuesta se descarta ([StaleSessionException]) y
  /// nunca se renueva el token con datos de la sesión anterior.
  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
    bool authorize = true,
    bool retried = false,
    bool module = false,
    String? bearer,
  }) => scope.run(() async {
    final client = await _client();
    final base = module ? BackendConfig.baseUrl : BackendConfig.apiBaseUrl;
    final uri = Uri.parse('$base$path').replace(queryParameters: query);
    final sentWith = bearer ?? _access;

    final res = await _request(
      client,
      http.Request(method, uri),
      accept: 'application/json',
      body: body,
      authorize: authorize,
      bearer: bearer,
    );

    final decoded = _decode(res);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (!module) return decoded;
      // Sin `ok: true` la API no confirmó nada (p. ej. una escritura): no
      // se da por hecha.
      if (decoded['ok'] != true) {
        throw BackendException(
          'invalid_response',
          'La API de Nexo no confirmó la operación.',
          res.statusCode,
        );
      }
      final data = decoded['data'];
      return data is Map ? data.cast<String, dynamic>() : {'data': data};
    }

    final rawError = decoded['error'];
    final error = module && rawError is Map
        ? rawError['code']?.toString() ?? 'error_${res.statusCode}'
        : rawError?.toString() ?? 'error_${res.statusCode}';
    final detail = module && rawError is Map
        ? rawError['message']?.toString()
        : decoded['detail']?.toString();

    if (authorize && !retried && _needsAuth(res.statusCode, error)) {
      await _recover(error, sentWith);
      return _send(
        method,
        path,
        query: query,
        body: body,
        authorize: authorize,
        retried: true,
        module: module,
      );
    }

    throw BackendException(
      error,
      detail,
      res.statusCode,
      retryAfterOf(res.headers['retry-after']),
    );
  });

  /// Descarga un archivo (no viene en el sobre JSON); el nombre sale de
  /// `content-disposition`.
  Future<({Uint8List bytes, String? filename, String? contentType})> _download(
    String path, {
    Map<String, String>? query,
    bool retried = false,
  }) => scope.run(() async {
    final client = await _client();
    final uri = Uri.parse(
      '${BackendConfig.baseUrl}$path',
    ).replace(queryParameters: query);
    final sentWith = _access;
    final res = await _request(
      client,
      http.Request('GET', uri),
      accept: '*/*',
      authorize: true,
      timeout: BackendConfig.timeout * 2,
    );
    final type = res.headers['content-type'];
    if (res.statusCode >= 200 &&
        res.statusCode < 300 &&
        !(type ?? '').contains('application/json')) {
      return (
        bytes: res.bodyBytes,
        filename: filenameFromDisposition(res.headers['content-disposition']),
        contentType: type,
      );
    }
    final rawError = _decode(res)['error'];
    final error = rawError is Map
        ? rawError['code']?.toString() ?? 'error_${res.statusCode}'
        : 'error_${res.statusCode}';
    if (!retried && _needsAuth(res.statusCode, error)) {
      await _recover(error, sentWith);
      return _download(path, query: query, retried: true);
    }
    throw BackendException(
      error,
      rawError is Map ? rawError['message']?.toString() : null,
      res.statusCode,
      retryAfterOf(res.headers['retry-after']),
    );
  });

  Future<http.Response> _request(
    http.Client client,
    http.Request request, {
    required String accept,
    Map<String, dynamic>? body,
    required bool authorize,
    Duration timeout = BackendConfig.timeout,
    String? bearer,
  }) async {
    // Leído antes de esperar nada: una petición que sale justo al cerrar
    // sesión conserva el token con el que se pidió.
    final access = bearer ?? _access;
    try {
      // Proof that the call comes from the genuine app; the backend refuses
      // requests without it when App Check is enforced.
      final appToken = await _attestation.token();
      request.headers.addAll({
        'Accept': accept,
        if (body != null) 'Content-Type': 'application/json',
        if (authorize && access != null) 'Authorization': 'Bearer $access',
        AppAttestation.header: ?appToken,
      });
      if (body != null) request.body = jsonEncode(body);
      final streamed = await client.send(request).timeout(timeout);
      final res = await http.Response.fromStream(streamed);
      scope.check();
      return res;
    } on StaleSessionException {
      rethrow;
    } catch (e) {
      throw BackendException('sin_conexion', e.toString());
    }
  }

  // El token de acceso dura poco; la sesión de la universidad en el servidor
  // también puede vencer (`reauth_required`).
  static bool _needsAuth(int status, String error) =>
      status == 401 &&
      (error == 'no_autenticado' ||
          error == 'unauthorized' ||
          error == 'reauth_required');

  /// Renueva el token o vuelve a iniciar sesión; si no se puede, lanza
  /// `session_expired` (credenciales rechazadas) o `auth_unavailable`.
  ///
  /// [sentWith] es el token con el que salió la petición: si ya cambió,
  /// otra petición renovó la sesión mientras tanto y basta con repetirla.
  Future<void> _recover(String error, String? sentWith) async {
    if (_access != null && _access != sentWith) return;
    if (error != 'reauth_required') {
      final renewed = await refreshSession();
      scope.check();
      if (renewed == ReauthOutcome.refreshed) return;
      // Sin red o backend caído: un login completo tampoco saldría.
      if (renewed == ReauthOutcome.unavailable) {
        throw const BackendException(
          'auth_unavailable',
          'No se pudo verificar tu sesión en este momento.',
          503,
        );
      }
    }
    final hook = reauthenticate;
    final outcome = hook != null ? await hook() : await _relogin();
    scope.check();
    switch (outcome) {
      case ReauthOutcome.refreshed:
        return;
      case ReauthOutcome.invalidCredentials:
        onSessionInvalid?.call();
        throw const BackendException(
          'session_expired',
          'Tu sesión expiró. Vuelve a iniciar sesión.',
          401,
        );
      case ReauthOutcome.unavailable:
        throw const BackendException(
          'auth_unavailable',
          'No se pudo verificar tu sesión en este momento.',
          503,
        );
    }
  }

  Map<String, dynamic> _decode(http.Response res) {
    try {
      final raw = jsonDecode(utf8.decode(res.bodyBytes));
      return raw is Map ? raw.cast<String, dynamic>() : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<ReauthOutcome> _relogin() async {
    final user = _user;
    final password = _password;
    if (user == null || password == null) {
      return ReauthOutcome.invalidCredentials;
    }
    try {
      await login(usuario: user, clave: password);
      return _access != null
          ? ReauthOutcome.refreshed
          : ReauthOutcome.unavailable;
    } on BackendException catch (e) {
      return e.code == 'invalid_credentials'
          ? ReauthOutcome.invalidCredentials
          : ReauthOutcome.unavailable;
    }
  }

  /// Renueva el token de acceso con el refresh token (`POST /auth/refresh`).
  ///
  /// Single-flight: el refresh token es de un solo uso, así que las
  /// peticiones que reciben 401 a la vez comparten una sola renovación.
  /// [ReauthOutcome.invalidCredentials] = no hay refresh token o el servidor
  /// lo rechazó (hace falta un login); [ReauthOutcome.unavailable] = sin red
  /// o backend caído (se conservan los tokens).
  Future<ReauthOutcome> refreshSession() {
    final pending = _renewal;
    if (pending != null) return pending;
    late final Future<ReauthOutcome> renewal;
    renewal = _renew().whenComplete(() {
      if (identical(_renewal, renewal)) _renewal = null;
    });
    return _renewal = renewal;
  }

  Future<ReauthOutcome> _renew() async {
    final token = _refresh;
    if (token == null || token.isEmpty) return ReauthOutcome.invalidCredentials;
    try {
      final body = await _send(
        'POST',
        '/auth/refresh',
        body: {'refresh_token': token},
        authorize: false,
        module: true,
      );
      final access = body['access_token'] as String?;
      if (access == null || access.isEmpty) return ReauthOutcome.unavailable;
      _access = access;
      _refresh = body['refresh_token'] as String? ?? _refresh;
      await _publishTokens(_access, _refresh);
      return ReauthOutcome.refreshed;
    } on StaleSessionException {
      rethrow;
    } on BackendException catch (e) {
      final status = e.status;
      final rejected =
          status != null && status >= 400 && status < 500 && status != 429;
      if (!rejected) return ReauthOutcome.unavailable;
      if (identical(_refresh, token)) _refresh = null;
      await _publishTokens(null, null);
      return ReauthOutcome.invalidCredentials;
    }
  }

  Future<void> _publishTokens(String? access, String? refresh) async {
    try {
      await onTokensChanged?.call(access, refresh);
    } on StaleSessionException {
      rethrow;
    } catch (_) {
      // Sin almacén seguro los tokens siguen en memoria para esta sesión.
    }
  }

  // --- Documentos legales ---------------------------------------------------

  /// Versión vigente de los documentos legales (`GET /legal`, pública):
  /// `{version, updated_at, summary, documents}`.
  Future<Map<String, dynamic>> legalInfo() =>
      _send('GET', '/legal', authorize: false, module: true);

  /// Deja constancia en el servidor de que el usuario aceptó [version]
  /// (`POST /me/legal/accept`). Requiere sesión.
  Future<void> acceptLegal(int version) async {
    await _send(
      'POST',
      '/me/legal/accept',
      body: {'version': version},
      module: true,
    );
  }

  // --- Push (solo estudiantes) ----------------------------------------------

  /// Registra el token FCM de este dispositivo (`POST /me/devices`) y
  /// devuelve las preferencias de push de la cuenta.
  Future<PushSettings> registerDevice(
    String token, {
    String platform = 'android',
  }) async {
    final body = await _send(
      'POST',
      '/me/devices',
      body: {'token': token, 'platform': platform},
      module: true,
    );
    final prefs = body['notifications'];
    return PushSettings.fromJson(
      prefs is Map ? prefs.cast<String, dynamic>() : const {},
    );
  }

  /// Da de baja el token (`DELETE /me/devices/{token}`). Se llama justo al
  /// cerrar sesión: toma el token de acceso en el momento de la llamada y no
  /// intenta renovarlo.
  Future<void> unregisterDevice(String token) async {
    await _send(
      'DELETE',
      '/me/devices/${Uri.encodeComponent(token)}',
      module: true,
      retried: true,
      bearer: _access,
    );
  }

  /// Preferencias de push de la cuenta (`GET /me/notifications`).
  Future<PushSettings> notificationSettings() async => PushSettings.fromJson(
    await _send('GET', '/me/notifications', module: true),
  );

  /// Activa o desactiva el push de notas (`PUT /me/notifications`).
  Future<PushSettings> setNotificationSettings({required bool grades}) async =>
      PushSettings.fromJson(
        await _send(
          'PUT',
          '/me/notifications',
          body: {'grades': grades},
          module: true,
        ),
      );
}

/// Preferencias de push de la cuenta: si recibe avisos de notas y cuántos
/// dispositivos tiene registrados (`null` cuando la respuesta no lo dice).
class PushSettings {
  const PushSettings({required this.grades, this.devices});
  final bool grades;
  final int? devices;

  factory PushSettings.fromJson(Map<String, dynamic> j) =>
      PushSettings(grades: j['grades'] == true, devices: _int(j['devices']));
}

/// `Retry-After` en segundos (lo que envía la API de Nexo); `null` si no
/// hay o no se entiende.
Duration? retryAfterOf(String? header) {
  final seconds = int.tryParse(header?.trim() ?? '');
  return seconds == null || seconds < 0 ? null : Duration(seconds: seconds);
}

/// Nombre sugerido en `content-disposition` (`filename*=UTF-8''…` primero).
String? filenameFromDisposition(String? disposition) {
  if (disposition == null) return null;
  final star = RegExp(
    r"filename\*=UTF-8''([^;]+)",
    caseSensitive: false,
  ).firstMatch(disposition);
  if (star != null) return Uri.decodeComponent(star.group(1)!.trim());
  final plain = RegExp(
    r'filename="?([^";]+)"?',
    caseSensitive: false,
  ).firstMatch(disposition);
  return plain?.group(1)?.trim();
}

/// Error del backend, identificado por el código que devuelve la API
/// (`sin_acceso_directorio`, `solo_administradores`, `invalid_credentials`,
/// `upstream_unavailable`, `reauth_required`, `not_found`, `sin_conexion`…).
class BackendException implements Exception {
  const BackendException(
    this.code, [
    this.detail,
    this.status,
    this.retryAfter,
  ]);
  final String code;
  final String? detail;

  /// Código HTTP de la respuesta; `null` si no hubo respuesta.
  final int? status;

  /// Espera que pidió el servidor (`Retry-After`), si la indicó.
  final Duration? retryAfter;
  @override
  String toString() => detail ?? code;
}

/// Traduce un error de la API a los errores que entienden [ErrorHandler] y
/// las pantallas: los transitorios (red, servidor) caen al caché y se
/// reintentan; credenciales rechazadas terminan la sesión.
ApiException apiErrorOf(BackendException e) {
  final message = e.detail ?? 'La API de Nexo respondió con un error.';
  final status = e.status;
  return switch (e.code) {
    'sin_conexion' when e.detail?.contains('TimeoutException') ?? false =>
      const TimeoutException('El servidor no respondió a tiempo.'),
    'sin_conexion' => const NetworkException(
      'No hay conexión con el servidor de Nexo. Revisa tu internet e '
      'inténtalo de nuevo.',
    ),
    'session_expired' ||
    'sin_credenciales' => SessionExpiredException(e.detail),
    // Un 401 que sigue después de renovar la sesión no es motivo para
    // sacar al usuario: se conserva la sesión y se usa el caché.
    'auth_unavailable' ||
    'unauthorized' ||
    'no_autenticado' ||
    'reauth_required' => AuthUnavailableException(e.detail),
    'invalid_credentials' => InvalidCredentialsException(e.detail),
    _
        when status == null ||
            status >= 500 ||
            e.code == 'upstream_unavailable' =>
      ServerException(
        message,
        status: status ?? 503,
        code: e.code,
        retryAfter: e.retryAfter,
      ),
    _ => BadRequestException(message, status: status),
  };
}

class DirectoryAccess {
  const DirectoryAccess({
    required this.allowed,
    required this.role,
    required this.code,
  });
  final bool allowed;

  /// `admin` reparte accesos; `autorizado` solo consulta; `null` no entra.
  final String? role;
  final String code;

  bool get isAdmin => role == 'admin';

  factory DirectoryAccess.fromJson(Map<String, dynamic> j) => DirectoryAccess(
    allowed: j['acceso'] == true,
    role: j['rol']?.toString(),
    code: j['codigo']?.toString() ?? '',
  );
}

class DirectoryPage {
  const DirectoryPage({
    required this.students,
    required this.total,
    required this.page,
    required this.pages,
  });
  final List<StudentSummary> students;
  final int total;
  final int page;
  final int pages;

  bool get hasMore => page < pages;

  factory DirectoryPage.fromJson(Map<String, dynamic> j) => DirectoryPage(
    students: (j['estudiantes'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => StudentSummary.fromJson(e.cast<String, dynamic>()))
        .toList(),
    total: _int(j['total']) ?? 0,
    page: _int(j['pagina']) ?? 1,
    pages: _int(j['paginas']) ?? 1,
  );
}

class StudentSummary {
  const StudentSummary({
    required this.code,
    required this.firstName,
    required this.lastName,
    this.school,
    this.cycle,
    this.status,
    this.average,
    this.creditsApproved,
    this.creditsTotal,
  });
  final String code;
  final String firstName;
  final String lastName;
  final String? school;
  final int? cycle;
  final String? status;
  final double? average;
  final int? creditsApproved;
  final int? creditsTotal;

  String get fullName => '$lastName, $firstName';
  bool get atRisk => average != null && average! < 10.5;

  factory StudentSummary.fromJson(Map<String, dynamic> j) => StudentSummary(
    code: j['codigo']?.toString() ?? '',
    firstName: j['nombres']?.toString() ?? '',
    lastName: j['apellidos']?.toString() ?? '',
    school: j['escuela']?.toString(),
    cycle: _int(j['ciclo']),
    status: j['condicion']?.toString(),
    average: _double(j['promedio']),
    creditsApproved: _int(j['creditos_aprobados']),
    creditsTotal: _int(j['creditos_totales']),
  );
}

class StudentRecord extends StudentSummary {
  const StudentRecord({
    required super.code,
    required super.firstName,
    required super.lastName,
    super.school,
    super.cycle,
    super.status,
    super.average,
    super.creditsApproved,
    super.creditsTotal,
    this.dni,
    this.email,
    this.phone,
    this.faculty,
    this.plan,
    this.entryYear,
    this.academic = const {},
    this.modules = const {},
  });
  final String? dni;
  final String? email;
  final String? phone;
  final String? faculty;
  final String? plan;
  final int? entryYear;
  final Map<String, dynamic> academic;
  final Map<String, dynamic> modules;

  Map<String, dynamic>? module(String name) {
    final value = modules[name];
    return value is Map ? value.cast<String, dynamic>() : null;
  }

  factory StudentRecord.fromJson(Map<String, dynamic> j) => StudentRecord(
    code: j['codigo']?.toString() ?? '',
    firstName: j['nombres']?.toString() ?? '',
    lastName: j['apellidos']?.toString() ?? '',
    school: j['escuela']?.toString(),
    cycle: _int(j['ciclo']),
    status: j['condicion']?.toString(),
    average: _double(j['promedio']),
    creditsApproved: _int(j['creditos_aprobados']),
    creditsTotal: _int(j['creditos_totales']),
    dni: j['dni']?.toString(),
    email: j['correo']?.toString(),
    phone: j['telefono']?.toString(),
    faculty: j['facultad']?.toString(),
    plan: j['plan']?.toString(),
    entryYear: _int(j['anio_ingreso']),
    academic: j['academico'] is Map
        ? (j['academico'] as Map).cast<String, dynamic>()
        : const {},
    modules: j['modulos'] is Map
        ? (j['modulos'] as Map).cast<String, dynamic>()
        : const {},
  );
}

class AccessGrants {
  const AccessGrants({required this.grants, required this.admins});
  final List<AccessGrant> grants;

  /// Códigos con potestad para repartir acceso. Vienen del entorno del
  /// servidor, así que la app los muestra pero no los puede cambiar.
  final List<String> admins;

  factory AccessGrants.fromJson(Map<String, dynamic> j) => AccessGrants(
    grants: (j['accesos'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => AccessGrant.fromJson(e.cast<String, dynamic>()))
        .toList(),
    admins: (j['administradores'] as List? ?? const [])
        .map((e) => e.toString())
        .toList(),
  );
}

class AccessGrant {
  const AccessGrant({
    required this.code,
    required this.status,
    this.note,
    this.grantedBy,
    this.grantedAt,
    this.revokedAt,
  });
  final String code;
  final String status;
  final String? note;
  final String? grantedBy;
  final String? grantedAt;
  final String? revokedAt;

  bool get isActive => status == 'activo';

  factory AccessGrant.fromJson(Map<String, dynamic> j) => AccessGrant(
    code: j['codigo']?.toString() ?? '',
    status: j['estado']?.toString() ?? 'revocado',
    note: j['nota']?.toString(),
    grantedBy: j['concedido_por']?.toString(),
    grantedAt: j['concedido_en']?.toString(),
    revokedAt: j['revocado_en']?.toString(),
  );
}

int? _int(Object? v) => v is num ? v.toInt() : null;
double? _double(Object? v) => v is num ? v.toDouble() : null;
