import 'package:flutter/foundation.dart';

import '../core/config.dart';

/// Estados del ciclo de vida del modelo Lumen.
enum LumenStatus {
  /// Lumen no está activado (no hay modelo en disco, no se intenta descargar).
  inactive,

  /// Activado pero el modelo aún no está descargado.
  awaitingDownload,

  /// Descarga en curso.
  downloading,

  /// Verificando checksum SHA-256.
  verifying,

  /// Modelo descargado y verificado, listo para cargar.
  ready,

  /// Modelo cargándose en memoria (RAM).
  loading,

  /// Modelo cargado y listo para inferencia.
  loaded,

  /// Falló alguna fase. [LumenState.error] tiene el detalle.
  error,
}

/// Estado global de Lumen. Patrón [ChangeNotifier] (consistente con `AppStore`).
///
/// Sin singleton global — se inyecta en `main.dart` y se provee con
/// `ChangeNotifierProvider` o equivalente. Toda la lógica pesada
/// (descarga, inferencia) vive en otras clases que se llaman desde aquí
/// y reportan vía los setters internos.
class LumenState extends ChangeNotifier {
  LumenState({LumenModelSpec? initialModel})
      : _activeModel = initialModel ?? LumenConfig.defaultModel;

  LumenStatus _status = LumenStatus.inactive;
  double _downloadProgress = 0;
  int _downloadedBytes = 0;
  int _totalBytes = 0;
  String? _error;
  LumenModelSpec _activeModel;

  LumenStatus get status => _status;
  double get downloadProgress => _downloadProgress;
  int get downloadedBytes => _downloadedBytes;
  int get totalBytes => _totalBytes;
  String? get error => _error;

  /// Modelo seleccionado por el usuario (o el default si nunca eligió).
  /// Cambiar este valor NO descarga ni borra nada — solo dice "cuando se
  /// invoque al manager, opera sobre este". El llamador debe coordinar.
  LumenModelSpec get activeModel => _activeModel;

  bool get isReady => _status == LumenStatus.ready ||
      _status == LumenStatus.loaded;

  void setActiveModel(LumenModelSpec model) {
    if (_activeModel.id == model.id) return;
    _activeModel = model;
    notifyListeners();
  }

  void setStatus(LumenStatus next, {String? error}) {
    if (_status == next && error == _error) return;
    _status = next;
    _error = error;
    notifyListeners();
  }

  void setDownloadProgress({required int received, required int total}) {
    _downloadedBytes = received;
    _totalBytes = total;
    _downloadProgress = total > 0 ? received / total : 0;
    notifyListeners();
  }

  void reset() {
    _status = LumenStatus.inactive;
    _downloadProgress = 0;
    _downloadedBytes = 0;
    _totalBytes = 0;
    _error = null;
    notifyListeners();
  }
}
