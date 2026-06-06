import 'package:http/http.dart' as http;

/// En Web la validación TLS la hace el navegador con su propio almacén raíz,
/// así que el cliente HTTP estándar es suficiente.
Future<http.Client> createSecureClientImpl() async => http.Client();
