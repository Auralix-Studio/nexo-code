/// Respuestas del backend para las integraciones: compartir el horario con
/// un calendario y "Conectar con Nexo" para apps externas.
library;

/// Lo que el estudiante comparte hoy y con quién.
class IntegrationStatus {
  const IntegrationStatus({
    required this.sharing,
    required this.calendarEnabled,
    required this.connections,
    this.updatedAt,
  });

  /// Si hay perfil y horario compartidos en el backend.
  final bool sharing;
  final bool calendarEnabled;
  final List<ConnectedApp> connections;
  final DateTime? updatedAt;

  static const empty = IntegrationStatus(
    sharing: false,
    calendarEnabled: false,
    connections: [],
  );

  factory IntegrationStatus.fromJson(Map<String, dynamic> json) {
    final shared = json['shared'];
    return IntegrationStatus(
      sharing: shared is Map,
      calendarEnabled: json['calendar_enabled'] == true,
      connections: (json['connections'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => ConnectedApp.fromJson(e.cast<String, dynamic>()))
          .toList(),
      updatedAt: shared is Map
          ? DateTime.tryParse(shared['updated_at']?.toString() ?? '')
          : null,
    );
  }
}

/// Una app externa con acceso a datos del estudiante.
class ConnectedApp {
  const ConnectedApp({
    required this.id,
    required this.name,
    required this.scopes,
    this.website,
    this.connectedAt,
    this.lastUsedAt,
  });

  final String id;
  final String name;
  final List<String> scopes;
  final String? website;
  final DateTime? connectedAt;
  final DateTime? lastUsedAt;

  factory ConnectedApp.fromJson(Map<String, dynamic> json) => ConnectedApp(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    scopes: _scopes(json['scopes']),
    website: json['website']?.toString(),
    connectedAt: DateTime.tryParse(json['connected_at']?.toString() ?? ''),
    lastUsedAt: DateTime.tryParse(json['last_used_at']?.toString() ?? ''),
  );
}

/// El enlace privado del calendario, en sus tres formas.
class CalendarLinks {
  const CalendarLinks({
    required this.url,
    required this.webcalUrl,
    required this.googleUrl,
  });

  /// `https://…/calendar/<clave>.ics`, para copiar en cualquier calendario.
  final String url;

  /// `webcal://…`, que abre la app de calendario del sistema.
  final String webcalUrl;

  /// Suscripción directa en Google Calendar.
  final String googleUrl;

  factory CalendarLinks.fromJson(Map<String, dynamic> json) => CalendarLinks(
    url: json['url']?.toString() ?? '',
    webcalUrl: json['webcal_url']?.toString() ?? '',
    googleUrl: json['google_url']?.toString() ?? '',
  );
}

/// Una app que pide acceso, para la pantalla de consentimiento.
class ConnectionRequest {
  const ConnectionRequest({
    required this.code,
    required this.appName,
    required this.scopes,
    this.website,
  });

  final String code;
  final String appName;
  final List<String> scopes;
  final String? website;

  factory ConnectionRequest.fromJson(Map<String, dynamic> json) {
    final client = json['client'] is Map
        ? (json['client'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    return ConnectionRequest(
      code: json['user_code']?.toString() ?? '',
      appName: client['name']?.toString() ?? '',
      website: client['website']?.toString(),
      scopes: _scopes(json['scopes']),
    );
  }
}

List<String> _scopes(Object? raw) =>
    raw is List ? raw.map((e) => e.toString()).toList() : const [];
