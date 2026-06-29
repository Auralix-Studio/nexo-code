import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/config.dart';
import 'lumen_state.dart';

/// Descarga, verifica y borra el archivo de modelo de Lumen.
///
/// Selecciona automáticamente el artefacto correcto para la plataforma
/// (`.task` en móvil/web, `.litertlm` en escritorio). El archivo se
/// guarda en `getApplicationSupportDirectory()/lumen/<filename>` — esa
/// ruta sobrevive limpieza de caché del SO.
///
/// Reporta progreso y errores en una instancia inyectada de [LumenState].
class LumenModelManager {
  LumenModelManager(this._state, {http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final LumenState _state;
  final http.Client _http;

  /// `true` si estamos corriendo en escritorio (Windows/macOS/Linux).
  /// En Web `kIsWeb` corta antes de intentar leer `Platform`.
  static bool get _isDesktop {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  /// Devuelve el artefacto apropiado para esta plataforma. Lanza
  /// [LumenModelException] si el modelo no tiene variante para escritorio
  /// y estamos en Windows/macOS/Linux.
  LumenModelArtifact _artifact(LumenModelSpec spec) {
    if (_isDesktop && spec.desktop == null) {
      throw LumenModelException(
        'El modelo "${spec.displayName}" todavía no está disponible para '
        'escritorio. Probá la otra variante o usá Nexo en tu teléfono.',
      );
    }
    return spec.artifactFor(isDesktop: _isDesktop);
  }

  Future<Directory> _modelDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'lumen'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Ruta absoluta donde vive (o vivirá) el modelo [model] para la
  /// plataforma actual. Si se omite, usa el modelo activo en [LumenState].
  Future<String> modelPath([LumenModelSpec? model]) async {
    final spec = model ?? _state.activeModel;
    final art = _artifact(spec);
    final dir = await _modelDir();
    return p.join(dir.path, art.filename);
  }

  /// `true` si el archivo correspondiente a la plataforma actual existe
  /// en disco con tamaño no nulo. No valida checksum (eso lo hace [verify]).
  Future<bool> isDownloaded([LumenModelSpec? model]) async {
    try {
      final f = File(await modelPath(model));
      if (!await f.exists()) return false;
      return await f.length() > 0;
    } on LumenModelException {
      // El modelo no tiene variante desktop → no puede estar instalado.
      return false;
    }
  }

  /// Lista los modelos del catálogo que están actualmente descargados.
  /// Útil para limpiar variantes antiguas cuando el user cambia de modelo.
  Future<List<LumenModelSpec>> installedModels() async {
    final installed = <LumenModelSpec>[];
    for (final m in LumenConfig.models) {
      if (await isDownloaded(m)) installed.add(m);
    }
    return installed;
  }

  /// Descarga el modelo activo con progreso streaming. Si ya existe, no
  /// hace nada.
  Future<void> download({CancelToken? cancel}) async {
    final spec = _state.activeModel;
    final art = _artifact(spec); // tira LumenModelException si no hay desktop

    if (!art.isConfigured) {
      throw LumenModelException(
        'El modelo "${spec.displayName}" no está publicado aún para esta '
        'plataforma. Pídele a Alessandro que suba el release.',
      );
    }

    if (await isDownloaded(spec)) {
      _state.setStatus(LumenStatus.ready);
      return;
    }

    final outPath = await modelPath(spec);
    final tmpPath = '$outPath.part';
    final tmp = File(tmpPath);
    if (await tmp.exists()) await tmp.delete();

    _state.setStatus(LumenStatus.downloading);
    _state.setDownloadProgress(received: 0, total: art.sizeBytes);

    final req = http.Request('GET', Uri.parse(art.downloadUrl));
    final resp = await _http.send(req);

    if (resp.statusCode != 200) {
      _state.setStatus(LumenStatus.error,
          error: 'Descarga falló (HTTP ${resp.statusCode}).');
      throw LumenModelException('HTTP ${resp.statusCode}');
    }

    final total = resp.contentLength ?? art.sizeBytes;
    var received = 0;
    final sink = tmp.openWrite();

    try {
      await for (final chunk in resp.stream) {
        if (cancel?.isCancelled ?? false) {
          await sink.close();
          await tmp.delete();
          _state.setStatus(LumenStatus.inactive, error: 'Cancelado.');
          throw const LumenModelException('Descarga cancelada.');
        }
        sink.add(chunk);
        received += chunk.length;
        _state.setDownloadProgress(received: received, total: total);
      }
      await sink.flush();
      await sink.close();
    } catch (e) {
      await sink.close();
      if (await tmp.exists()) await tmp.delete();
      _state.setStatus(LumenStatus.error, error: 'Error de red: $e');
      rethrow;
    }

    _state.setStatus(LumenStatus.verifying);
    final ok = await _verifyChecksum(tmp, art);
    if (!ok) {
      await tmp.delete();
      _state.setStatus(LumenStatus.error,
          error: 'Checksum no coincide — archivo corrupto o manipulado.');
      throw const LumenModelException('SHA-256 mismatch.');
    }

    await tmp.rename(outPath);
    _state.setStatus(LumenStatus.ready);
  }

  /// Verifica el SHA-256 del modelo [model] (o el activo) en disco.
  Future<bool> verify([LumenModelSpec? model]) async {
    final spec = model ?? _state.activeModel;
    try {
      final art = _artifact(spec);
      final f = File(await modelPath(spec));
      if (!await f.exists()) return false;
      return _verifyChecksum(f, art);
    } on LumenModelException {
      return false;
    }
  }

  Future<bool> _verifyChecksum(File f, LumenModelArtifact art) async {
    final expected = art.sha256.toLowerCase();
    final digest = await sha256.bind(f.openRead()).first;
    return digest.toString().toLowerCase() == expected;
  }

  /// Borra el modelo [model] (o el activo) del disco.
  Future<void> delete([LumenModelSpec? model]) async {
    final spec = model ?? _state.activeModel;
    try {
      final f = File(await modelPath(spec));
      if (await f.exists()) await f.delete();
    } on LumenModelException {
      // Modelo no instalable en esta plataforma — nada que borrar.
    }
    if (model == null || model.id == _state.activeModel.id) {
      _state.reset();
    }
  }
}

class LumenModelException implements Exception {
  const LumenModelException(this.message);
  final String message;

  @override
  String toString() => 'LumenModelException: $message';
}

/// Cancelación cooperativa para la descarga.
class CancelToken {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}
