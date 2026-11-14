import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:nexo/core/config.dart';
import 'package:nexo/core/storage.dart';
import 'package:nexo/data/remote/backend_client.dart';

/// Un documento publicado por el backend, para leerlo en la web cuando es
/// más nuevo que el que trae la app.
typedef OnlineLegalDoc = ({String id, String title, String url});

/// Mantiene la app al día con la versión de los documentos legales que
/// publica el backend (`GET /legal`), sin esperar a una actualización.
///
/// - Consulta al arrancar y al volver a la app, como mucho una vez por
///   [interval]. Sin red no pasa nada: vale la versión que trae la app.
/// - Si el backend publica una versión mayor que la aceptada, avisa a sus
///   oyentes para que se muestre otra vez el flujo de aceptación con el
///   resumen de cambios.
/// - Al aceptar, se guarda en el dispositivo y, si hay sesión, se deja
///   constancia en el servidor (`POST /me/legal/accept`). Si no hay sesión o
///   falla, se reintenta en [syncAcceptance] (p. ej. al iniciar sesión).
class LegalUpdates extends ChangeNotifier {
  LegalUpdates({
    required Future<Map<String, dynamic>> Function() fetch,
    required Future<void> Function(int version) upload,
    bool Function()? signedIn,
    AppStorage? storage,
    DateTime Function()? clock,
    this.interval = const Duration(hours: 1),
  }) : _fetch = fetch,
       _upload = upload,
       _signedIn = signedIn ?? _always,
       _storage = storage,
       _clock = clock ?? DateTime.now;

  factory LegalUpdates.backend(BackendClient client) => LegalUpdates(
    fetch: client.legalInfo,
    upload: client.acceptLegal,
    // Sin token no se intenta: un 401 dispararía la re-autenticación.
    signedIn: () => client.isConnected,
  );

  static bool _always() => true;

  final Future<Map<String, dynamic>> Function() _fetch;
  final Future<void> Function(int version) _upload;
  final bool Function() _signedIn;
  final AppStorage? _storage;
  final DateTime Function() _clock;
  final Duration interval;
  Future<bool>? _checking;
  bool _syncing = false;

  AppStorage get _store => _storage ?? AppStorage.instance;

  /// Falta aceptar la versión vigente.
  bool get needsAcceptance => !_store.acceptedTerms;

  /// Ya se había aceptado una versión anterior: es un cambio, no la primera
  /// vez.
  bool get isUpdate => _store.acceptedTermsVersion > 0;

  int get requiredVersion => _store.requiredTermsVersion;

  /// Qué cambió, según el backend. Vacío si nunca se pudo consultar.
  List<String> get changes => _store.legalSummary;

  /// Documentos en la web: solo cuando la versión vigente es más nueva que
  /// los textos que trae la app.
  List<OnlineLegalDoc> get onlineDocuments {
    if (requiredVersion <= LegalTerms.version) return const [];
    final raw = _store.legalDocumentsJson;
    if (raw == null) return const [];
    try {
      return _parseDocuments(jsonDecode(raw));
    } catch (_) {
      return const [];
    }
  }

  /// Consulta el backend si pasó [interval] desde la última vez (o siempre
  /// con [force]). Devuelve `true` si ahora hay que aceptar una versión
  /// nueva. Nunca lanza.
  Future<bool> check({bool force = false}) {
    final now = _clock().millisecondsSinceEpoch;
    if (!force && now - _store.legalCheckedAtMs < interval.inMilliseconds) {
      return Future.value(false);
    }
    return _checking ??= _check(now).whenComplete(() => _checking = null);
  }

  Future<bool> _check(int now) async {
    final before = needsAcceptance;
    try {
      final info = await _fetch();
      final version = info['version'];
      if (version is! int || version < 1) return false;
      final summary = [
        for (final s in (info['summary'] as List?) ?? const []) s.toString(),
      ];
      await _store.setLegalServerInfo(version, summary);
      await _store.setLegalDocumentsJson(
        jsonEncode(info['documents'] ?? const []),
      );
      await _store.setLegalCheckedAtMs(now);
    } catch (_) {
      // Sin red, backend caído o respuesta rara: se queda la versión
      // conocida y se reintenta en la próxima ocasión.
      return false;
    }
    final changed = needsAcceptance && !before;
    if (changed) notifyListeners();
    return changed;
  }

  /// El usuario aceptó la versión vigente.
  Future<void> accept() async {
    await _store.setAcceptedTerms(true);
    notifyListeners();
    unawaited(syncAcceptance());
  }

  /// Terminó la sesión: la próxima cuenta que entre también debe quedar
  /// registrada.
  Future<void> signedOut() => _store.setLegalSyncedVersion(0);

  /// Registra en el servidor la aceptación pendiente. Sin sesión o sin red
  /// falla en silencio y queda para la próxima vez.
  Future<void> syncAcceptance() async {
    final version = _store.acceptedTermsVersion;
    if (_syncing ||
        !_signedIn() ||
        version < 1 ||
        version <= _store.legalSyncedVersion) {
      return;
    }
    _syncing = true;
    try {
      await _upload(version);
      await _store.setLegalSyncedVersion(version);
    } catch (_) {
      // Se reintenta al iniciar sesión o al volver a la app.
    } finally {
      _syncing = false;
    }
  }

  static List<OnlineLegalDoc> _parseDocuments(Object? raw) => [
    if (raw is List)
      for (final d in raw.whereType<Map>())
        if (d['url'] is String && d['title'] is String)
          (
            id: d['id']?.toString() ?? '',
            title: d['title'] as String,
            url: d['url'] as String,
          ),
  ];
}
