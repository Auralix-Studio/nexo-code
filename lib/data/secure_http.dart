import 'package:http/http.dart' as http;

// Implementación específica por plataforma:
//   - Web: cliente HTTP estándar (el navegador valida TLS).
//   - Móvil/Escritorio: HttpClient con SecurityContext que añade el bundle
//     de root CAs de Mozilla a los del sistema, para sobrevivir a
//     `CERTIFICATE_VERIFY_FAILED` en dispositivos con almacén raíz
//     desactualizado o cuando el servidor omite el intermedio.
import 'secure_http_web.dart'
    if (dart.library.io) 'secure_http_io.dart' as impl;

/// Crea un `http.Client` que valida TLS contra el almacén del sistema
/// **y** un bundle bundleado de root CAs de Mozilla (assets/certs/cacert.pem).
///
/// Usar como `transport` en [ApiClient] y [IntranetClient]. Si la carga del
/// bundle falla, vuelve a un cliente estándar (degradación silenciosa).
Future<http.Client> createSecureClient() => impl.createSecureClientImpl();
