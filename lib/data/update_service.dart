import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:nexo/core/config.dart';
import 'package:nexo/core/storage.dart';
import 'package:nexo/data/notification_service.dart';

/// Estado de actualización tras un chequeo o consulta.
enum UpdateState {
  /// Plataforma sin autoupdater (todo lo que no es Android).
  unsupported,

  /// Aún no se sabe (no se chequeó nunca, o el último chequeo falló).
  unknown,

  /// La app está al día.
  upToDate,

  /// Hay una versión nueva publicada — el APK aún no se ha descargado.
  available,

  /// Hay una versión nueva y el APK ya está descargado, listo para instalar.
  ready,
}

class UpdateStatus {
  const UpdateStatus({
    required this.state,
    this.latestVersion,
    this.apkPath,
  });

  final UpdateState state;
  final String? latestVersion;
  final String? apkPath;
}

/// Autoupdater de Nexo (Android-only).
///
/// Flujo de raíz:
///   1. En cada arranque, [bootstrap] hace housekeeping (borra el APK ya
///      consumido si el sistema instaló la versión nueva) y, si pasaron
///      24h desde el último chequeo, consulta GitHub Releases.
///   2. Si hay versión nueva, la metadata se persiste y se dispara la
///      descarga **idempotente** (`downloadedVersion` evita repetirla) en
///      segundo plano. Al terminar, notifica al usuario.
///   3. [installDownloaded] lanza el instalador del sistema (open_filex
///      → ACTION_VIEW + FileProvider). Tras instalar, el siguiente boot
///      borra el APK consumido.
///
/// Nunca lanza al caller — todos los errores quedan en debugPrint para
/// que el autoupdate no rompa el arranque de la app.
class UpdateService {
  UpdateService({http.Client? httpClient, NotificationService? notifications})
      : _http = httpClient ?? http.Client(),
        _notifications = notifications ?? NotificationService.instance;

  final http.Client _http;
  final NotificationService _notifications;
  Future<void>? _downloadInFlight;

  bool get _isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Llamar una vez en el arranque, **después** de `NotificationService.init()`
  /// para que el handler de tap esté listo si llega a disparar una notif.
  ///
  /// No bloquea: hace housekeeping síncrono (rápido) y delega el resto a
  /// un microtask. Si no hay red o GitHub está caído, no pasa nada visible.
  Future<void> bootstrap() async {
    if (!_isSupported) return;
    await _cleanupIfAlreadyInstalled();
    unawaited(_runCheckAndDownload(force: false));
  }

  /// Chequeo manual (botón "Buscar actualizaciones"). Ignora el throttle.
  Future<UpdateStatus> checkNow() async {
    if (!_isSupported) return const UpdateStatus(state: UpdateState.unsupported);
    await _runCheckAndDownload(force: true);
    return currentStatus();
  }

  /// Estado actual derivado de la metadata persistida — útil para pintar
  /// un banner sin volver a pegarle a la red.
  UpdateStatus currentStatus() {
    if (!_isSupported) return const UpdateStatus(state: UpdateState.unsupported);
    final s = AppStorage.instance;
    final latest = s.updLatestVer;
    if (latest == null) return const UpdateStatus(state: UpdateState.unknown);
    if (!_isNewer(latest, AppConfig.appVersion)) {
      return const UpdateStatus(state: UpdateState.upToDate);
    }
    final downloaded = s.updDownloadedVer;
    final path = s.updApkPath;
    if (downloaded == latest && path != null && File(path).existsSync()) {
      return UpdateStatus(
        state: UpdateState.ready,
        latestVersion: latest,
        apkPath: path,
      );
    }
    return UpdateStatus(state: UpdateState.available, latestVersion: latest);
  }

  /// Lanza el instalador del sistema con el APK ya descargado. Si el APK
  /// aún no está en disco, lo descarga primero. Devuelve `true` si el
  /// intent se abrió (no implica que el usuario haya completado la
  /// instalación — eso solo se sabe al próximo arranque).
  Future<bool> installDownloaded() async {
    if (!_isSupported) return false;
    var status = currentStatus();
    if (status.state == UpdateState.available) {
      await _downloadOnce();
      status = currentStatus();
    }
    if (status.state != UpdateState.ready || status.apkPath == null) {
      return false;
    }
    try {
      final res = await OpenFilex.open(status.apkPath!);
      // ResultType.done = el sistema lanzó el visor/instalador.
      return res.type == ResultType.done;
    } catch (e) {
      debugPrint('[UpdateService] install failed: $e');
      return false;
    }
  }

  // ─── Internos ───

  Future<void> _runCheckAndDownload({required bool force}) async {
    try {
      final s = AppStorage.instance;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (!force) {
        final last = s.updLastCheckMs ?? 0;
        if (now - last < UpdateConfig.checkInterval.inMilliseconds) {
          // Throttle: dentro de la ventana. Si ya hay descarga pendiente,
          // asegurarla por si quedó a medias del boot anterior.
          if (currentStatus().state == UpdateState.available) {
            unawaited(_downloadOnce());
          }
          return;
        }
      }
      await s.setUpdLastCheckMs(now);

      final release = await _fetchLatestRelease();
      if (release == null) return;
      final version = release.version;
      final asset = release.apkAsset;
      if (asset == null) return; // release sin APK (puede ser de modelos)

      await s.setUpdLatest(
        version: version,
        url: asset.url,
        size: asset.size,
      );

      if (!_isNewer(version, AppConfig.appVersion)) return;

      // Descarga si no la tenemos ya (idempotente).
      await _downloadOnce();
      final fresh = currentStatus();
      if (fresh.state == UpdateState.ready) {
        await _notifications.showUpdateReady(version);
      } else if (fresh.state == UpdateState.available) {
        // Descarga falló — al menos avisamos que hay actualización.
        await _notifications.showUpdateAvailable(version);
      }
    } catch (e) {
      debugPrint('[UpdateService] check failed: $e');
    }
  }

  /// Garantiza una sola descarga concurrente — si varios callers la piden
  /// (boot + tap manual), comparten el mismo future.
  Future<void> _downloadOnce() {
    return _downloadInFlight ??= () async {
      try {
        await _doDownload();
      } finally {
        _downloadInFlight = null;
      }
    }();
  }

  Future<void> _doDownload() async {
    final s = AppStorage.instance;
    final version = s.updLatestVer;
    final url = s.updApkUrl;
    final size = s.updApkSize;
    if (version == null || url == null) return;

    // Idempotencia: si el archivo ya existe con el tamaño esperado y la
    // metadata coincide, no re-descargamos.
    final existingPath = s.updApkPath;
    if (s.updDownloadedVer == version && existingPath != null) {
      final f = File(existingPath);
      if (await f.exists()) {
        final len = await f.length();
        if (size == null || len == size) return;
        // Tamaño no coincide → archivo corrupto, lo borramos y reintentamos.
        await _safeDelete(f);
        await s.clearUpdDownloaded();
      }
    }

    final dir = await _apkDir();
    final dest = File(p.join(dir.path, 'nexo-$version.apk'));
    final part = File('${dest.path}.part');

    // Descarga streaming a .part — rename atómico al final para no dejar
    // archivos corruptos visibles como "instalables".
    final req = http.Request('GET', Uri.parse(url));
    final res = await _http.send(req);
    if (res.statusCode != 200) {
      throw HttpException(
        'GET $url devolvió ${res.statusCode}',
        uri: Uri.parse(url),
      );
    }
    if (await part.exists()) await _safeDelete(part);
    final sink = part.openWrite();
    try {
      await res.stream.pipe(sink);
    } finally {
      await sink.close();
    }

    if (size != null) {
      final len = await part.length();
      if (len != size) {
        await _safeDelete(part);
        throw const FileSystemException(
            'Descarga incompleta — tamaño no coincide con el release.');
      }
    }
    if (await dest.exists()) await _safeDelete(dest);
    await part.rename(dest.path);
    await s.setUpdDownloaded(version, dest.path);

    // Limpieza preventiva: borrar APKs de versiones obsoletas que hayan
    // quedado en el dir (por ejemplo si el sistema instaló pero algo
    // interrumpió el cleanup de la app antes).
    await _purgeStaleApks(dir, keep: dest.path);
  }

  /// Tras instalar la app, en el siguiente arranque [AppConfig.appVersion]
  /// ya coincide con la descargada → borramos el APK consumido y limpiamos
  /// la metadata.
  Future<void> _cleanupIfAlreadyInstalled() async {
    final s = AppStorage.instance;
    final downloaded = s.updDownloadedVer;
    if (downloaded == null) return;
    if (!_isNewer(downloaded, AppConfig.appVersion) &&
        downloaded != AppConfig.appVersion) {
      // downloaded < current: ya superada, descartar metadata vieja.
    }
    if (_isNewer(AppConfig.appVersion, downloaded) ||
        AppConfig.appVersion == downloaded) {
      final path = s.updApkPath;
      if (path != null) await _safeDelete(File(path));
      await s.clearUpdDownloaded();
      // Si la versión instalada >= la "latest" que conocíamos, también
      // descartamos esa metadata para que el próximo check decida de cero.
      final latest = s.updLatestVer;
      if (latest != null && !_isNewer(latest, AppConfig.appVersion)) {
        await s.clearUpdLatest();
      }
    }
  }

  Future<void> _purgeStaleApks(Directory dir, {required String keep}) async {
    try {
      await for (final f in dir.list()) {
        if (f is File && f.path != keep && f.path.endsWith('.apk')) {
          await _safeDelete(f);
        }
      }
    } catch (_) {}
  }

  Future<void> _safeDelete(FileSystemEntity f) async {
    try {
      await f.delete();
    } catch (_) {}
  }

  Future<Directory> _apkDir() async {
    // External cache dir — visible para el sistema cuando se lanza el
    // instalador, y se limpia automáticamente si el SO necesita espacio.
    final base = await getExternalStorageDirectory() ??
        await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'updates'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<_GhRelease?> _fetchLatestRelease() async {
    final res = await _http.get(
      Uri.parse(UpdateConfig.latestReleaseApi),
      headers: const {
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      },
    ).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      debugPrint('[UpdateService] GitHub API ${res.statusCode}: ${res.body}');
      return null;
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final tag = (json['tag_name'] as String?)?.trim();
    if (tag == null || tag.isEmpty) return null;
    final version = _stripVPrefix(tag);
    final assets = (json['assets'] as List?) ?? const [];
    _GhAsset? apk;
    for (final a in assets.whereType<Map<String, dynamic>>()) {
      final name = a['name'] as String? ?? '';
      if (!UpdateConfig.isApkAsset(name)) continue;
      final url = a['browser_download_url'] as String?;
      final size = (a['size'] as num?)?.toInt();
      if (url == null || size == null) continue;
      apk = _GhAsset(url: url, size: size);
      break;
    }
    return _GhRelease(version: version, apkAsset: apk);
  }

  /// Quita el `v` líder (`v1.0.1` → `1.0.1`) y trim. No valida formato:
  /// la comparación se hace en [_isNewer].
  static String _stripVPrefix(String s) {
    final t = s.trim();
    if (t.isNotEmpty && (t[0] == 'v' || t[0] == 'V')) return t.substring(1);
    return t;
  }

  /// Comparación semver simple — `1.2.3` o `1.2.3+4`. Suficiente para
  /// `AppConfig.appVersion`. Si los formatos son inválidos, cae a string
  /// compare (conservador: prefiere "no es mayor" sobre falsos positivos).
  static bool _isNewer(String a, String b) {
    final pa = _parseVersion(a);
    final pb = _parseVersion(b);
    if (pa == null || pb == null) return a.compareTo(b) > 0;
    for (var i = 0; i < 3; i++) {
      if (pa[i] != pb[i]) return pa[i] > pb[i];
    }
    return false;
  }

  static List<int>? _parseVersion(String s) {
    final core = s.split('+').first.split('-').first;
    final parts = core.split('.');
    if (parts.length < 2) return null;
    final out = <int>[];
    for (var i = 0; i < 3; i++) {
      final raw = i < parts.length ? parts[i] : '0';
      final n = int.tryParse(raw);
      if (n == null) return null;
      out.add(n);
    }
    return out;
  }
}

class _GhRelease {
  _GhRelease({required this.version, required this.apkAsset});
  final String version;
  final _GhAsset? apkAsset;
}

class _GhAsset {
  _GhAsset({required this.url, required this.size});
  final String url;
  final int size;
}
