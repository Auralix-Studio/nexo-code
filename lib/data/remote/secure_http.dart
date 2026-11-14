import 'package:http/http.dart' as http;
import 'secure_http_web.dart'
    if (dart.library.io) 'secure_http_io.dart'
    as impl;

Future<http.Client> createSecureClient() => impl.createSecureClientImpl();
