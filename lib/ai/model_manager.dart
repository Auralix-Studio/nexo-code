import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/config.dart';
import 'lumen_state.dart';

/// Descarga, verifica y borra el archivo `.task` del modelo Lumen.
///
/// El archivo se guarda en `getApplicationSupportDirectory()/lumen/<filename>`
/// — esta ruta sobrevive a limpieza de caché (a diferencia de temp/cache).
///
/// Reporta progreso y errores en una instancia inyectada de [LumenState].
class LumenModelManager {
  LumenModelManager(this._state, {http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final LumenState _state;
  final http.Client _http;

  Future<Directory> _modelDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'lumen'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Ruta absoluta donde vive (o vivirá) el modelo [model]. Si se omite,
  /// usa el modelo activo en [LumenState].
  Future<String> modelPath([LumenModelSpec? model]) async {
    final spec = model ?? _state.activeModel;
    final dir = await _modelDir();
    return p.join(dir.path, spec.filename);
  }

  /// `true` si el modelo [model] (o el activo) existe en disco con tamaño
  /// no nulo. No valida checksum (eso lo hace [verify]).
  Future<bool> isDownloaded([LumenModelSpec? model]) async {
    final f = File(await modelPath(model));
    if (!await f.exists()) return false;
    final size = await f.length();
    return size > 0;
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
  ///
  /// Lanza [LumenModelException] si la descarga falla o el modelo no está
  /// configurado (checksum en TODO).
  Future<void> download({CancelToken? cancel}) async {
    final spec = _state.activeModel;
    if (!spec.isConfigured) {
      throw LumenModelException(
        'El modelo "${spec.displayName}" no está publicado aún. '
        'Pídele a Alessandro que suba el release a GitHub.',
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
    _state.setDownloadProgress(received: 0, total: spec.sizeBytes);

    final req = http.Request('GET', Uri.parse(spec.downloadUrl));
    final resp = await _http.send(req);

    if (resp.statusCode != 200) {
      _state.setStatus(LumenStatus.error,
          error: 'Descarga falló (HTTP ${resp.statusCode}).');
      throw LumenModelException('HTTP ${resp.statusCode}');
    }

    final total = resp.contentLength ?? spec.sizeBytes;
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
    final ok = await _verifyChecksum(tmp, spec);
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
    final f = File(await modelPath(spec));
    if (!await f.exists()) return false;
    return _verifyChecksum(f, spec);
  }

  Future<bool> _verifyChecksum(File f, LumenModelSpec spec) async {
    final expected = spec.sha256.toLowerCase();
    final digest = await sha256.bind(f.openRead()).first;
    return digest.toString().toLowerCase() == expected;
  }

  /// Borra el modelo [model] (o el activo) del disco.
  Future<void> delete([LumenModelSpec? model]) async {
    final spec = model ?? _state.activeModel;
    final f = File(await modelPath(spec));
    if (await f.exists()) await f.delete();
    // Solo resetear el state si el modelo borrado es el activo.
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
