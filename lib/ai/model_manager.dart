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

  /// Ruta absoluta donde vive (o vivirá) el modelo.
  Future<String> modelPath() async {
    final dir = await _modelDir();
    return p.join(dir.path, LumenConfig.modelFilename);
  }

  /// `true` si el archivo existe en disco con tamaño no nulo.
  /// No valida checksum (eso lo hace [verify]).
  Future<bool> isDownloaded() async {
    final f = File(await modelPath());
    if (!await f.exists()) return false;
    final size = await f.length();
    return size > 0;
  }

  /// Descarga el modelo con progreso streaming. Si ya existe, no hace nada.
  ///
  /// Lanza [LumenModelException] si la descarga falla o el config no está
  /// listo (checksum/URL en TODO).
  Future<void> download({CancelToken? cancel}) async {
    if (!LumenConfig.isConfigured) {
      throw const LumenModelException(
        'El modelo no está publicado aún. Pídele a Alessandro que suba el '
        'release a GitHub.',
      );
    }

    if (await isDownloaded()) {
      _state.setStatus(LumenStatus.ready);
      return;
    }

    final outPath = await modelPath();
    final tmpPath = '$outPath.part';
    final tmp = File(tmpPath);
    if (await tmp.exists()) await tmp.delete();

    _state.setStatus(LumenStatus.downloading);
    _state.setDownloadProgress(received: 0, total: LumenConfig.modelSizeBytes);

    final req = http.Request('GET', Uri.parse(LumenConfig.modelDownloadUrl));
    final resp = await _http.send(req);

    if (resp.statusCode != 200) {
      _state.setStatus(LumenStatus.error,
          error: 'Descarga falló (HTTP ${resp.statusCode}).');
      throw LumenModelException('HTTP ${resp.statusCode}');
    }

    final total = resp.contentLength ?? LumenConfig.modelSizeBytes;
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
    final ok = await _verifyChecksum(tmp);
    if (!ok) {
      await tmp.delete();
      _state.setStatus(LumenStatus.error,
          error: 'Checksum no coincide — archivo corrupto o manipulado.');
      throw const LumenModelException('SHA-256 mismatch.');
    }

    await tmp.rename(outPath);
    _state.setStatus(LumenStatus.ready);
  }

  /// Verifica el SHA-256 del archivo descargado contra [LumenConfig.modelSha256].
  Future<bool> verify() async {
    final f = File(await modelPath());
    if (!await f.exists()) return false;
    return _verifyChecksum(f);
  }

  Future<bool> _verifyChecksum(File f) async {
    final expected = LumenConfig.modelSha256.toLowerCase();
    final digest = await sha256.bind(f.openRead()).first;
    return digest.toString().toLowerCase() == expected;
  }

  /// Borra el modelo del disco. Libera ~529 MB.
  Future<void> delete() async {
    final f = File(await modelPath());
    if (await f.exists()) await f.delete();
    _state.reset();
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
