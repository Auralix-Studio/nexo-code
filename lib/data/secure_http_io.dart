import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

Future<http.Client> createSecureClientImpl() async {
  final ctx = SecurityContext(withTrustedRoots: true);
  try {
    final data = await rootBundle.load('assets/certs/cacert.pem');
    ctx.setTrustedCertificatesBytes(data.buffer.asUint8List());
  } catch (e) {
    debugPrint('No se pudo cargar cacert.pem: $e');
  }
  final httpClient = HttpClient(context: ctx);
  return IOClient(httpClient);
}
