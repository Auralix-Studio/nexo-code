import 'dart:convert';

import 'package:http/http.dart' as http;

/// Respuestas con el sobre de la API de Nexo, para los backends falsos de
/// las pruebas (`{"ok": true, "data": …}` / `{"ok": false, "error": …}`).
http.Response nexoOk(Object? data, {int status = 200}) => http.Response(
  jsonEncode({'ok': true, 'data': data}),
  status,
  headers: const {'content-type': 'application/json; charset=utf-8'},
);

http.Response nexoError(String code, int status, [String? message]) =>
    http.Response(
      jsonEncode({
        'ok': false,
        'error': {'code': code, 'message': message ?? code},
      }),
      status,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );

/// Sesión de `POST /auth/login` para [user]; los códigos que empiezan con
/// `D` son docentes.
Map<String, dynamic> nexoSession(String user, {String? token}) => {
  'access_token': token ?? 'tok-$user',
  'refresh_token': 'ref-$user',
  'expires_in': 900,
  'user': {
    'code': user,
    'role': user.startsWith('D') ? 'teacher' : 'student',
    'name': {'first': 'NOMBRE $user', 'last': 'APELLIDO'},
    'photo_url': null,
  },
};

/// `{user, password}` de una petición a `/auth/login`.
({String user, String password}) loginBody(http.Request req) {
  final body = jsonDecode(req.body) as Map<String, dynamic>;
  return (user: body['user'] as String, password: body['password'] as String);
}
