import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Implementación móvil/escritorio del cliente HTTP seguro.
///
/// Construye un [SecurityContext] que combina:
///   - los root CAs **del sistema** (`withTrustedRoots: true`), y
///   - el bundle **de Mozilla** empacado como asset (`cacert.pem`).
///
/// Así cubrimos los dos motivos típicos del error
/// `CERTIFICATE_VERIFY_FAILED: unable to get local issuer certificate`
/// que aparece al iniciar sesión en SIGMA desde algunos dispositivos:
///   1. el almacén raíz del dispositivo está desactualizado, o
///   2. el servidor entrega una cadena incompleta y el root al que sube
///      no está en el sistema.
Future<http.Client> createSecureClientImpl() async {
  final ctx = SecurityContext(withTrustedRoots: true);
  try {
    final data = await rootBundle.load('assets/certs/cacert.pem');
    ctx.setTrustedCertificatesBytes(data.buffer.asUint8List());
  } catch (e) {
    // No es fatal: seguimos con los roots del sistema.
    debugPrint('No se pudo cargar cacert.pem: $e');
  }
  final httpClient = HttpClient(context: ctx);
  return IOClient(httpClient);
}
