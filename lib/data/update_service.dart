import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:nexo/core/update_integrity.dart';
import 'package:nexo/data/update_manifest.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:nexo/core/config.dart';
import 'package:nexo/core/storage.dart';
import 'package:nexo/data/notification_service.dart';

enum UpdateState { unsupported, unknown, upToDate, available, ready }

class UpdateStatus {
  const UpdateStatus({
    required this.state,
    this.latestVersion,
    this.apkPath,
    this.required = false,
  });
  final UpdateState state;
  final String? latestVersion;
  final String? apkPath;

  /// Esta versión ya no funciona: no se puede seguir sin actualizar.
  final bool required;
}

/// Qué pasó al pedir instalar.
enum InstallOutcome {
  /// Se abrió el instalador del sistema.
  started,

  /// Android aún no deja a Nexo instalar apps: se abrió ese ajuste y hay que
  /// volver a tocar «Instalar» al regresar.
  needsPermission,
  failed,
}

class UpdateService extends ChangeNotifier {
  UpdateService({http.Client? httpClient, NotificationService? notifications})
    : _http = httpClient ?? http.Client(),
      _notifications = notifications ?? NotificationService.instance {
    instance = this;
  }
  static UpdateService? instance;
  final http.Client _http;
  final NotificationService _notifications;
  Future<void>? _downloadInFlight;
  bool _busy = false;
  bool get isBusy => _busy;
  void _setBusy(bool v) {
    if (_busy == v) return;
    _busy = v;
    notifyListeners();
  }

  bool get isSupported => _isSupported;

  /// En la distribución propia: el instalador de Windows y el APK de
  /// Android que se bajan de GitHub.
  ///
  /// Nunca en tiendas (`StoreBuild.isStore`): Google Play prohíbe que una app
  /// descargue e instale APKs y la Microsoft Store actualiza por su cuenta.
  /// El build de Play tampoco lleva el permiso de instalar (ver
  /// android/app/src/direct/AndroidManifest.xml).
  bool get _isSupported =>
      !kIsWeb &&
      !StoreBuild.isStore &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.android);

  static const _installer = MethodChannel('nexo/updater');
  Future<void> bootstrap() async {
    if (!_isSupported) return;
    await _cleanupIfAlreadyInstalled();
    unawaited(_runCheckAndDownload(force: false));
  }

  Future<UpdateStatus> checkNow() async {
    if (!_isSupported) {
      return const UpdateStatus(state: UpdateState.unsupported);
    }
    _setBusy(true);
    try {
      await _notifications.requestPermission();
      await _runCheckAndDownload(force: true);
      return currentStatus();
    } finally {
      _setBusy(false);
    }
  }

  UpdateStatus currentStatus() {
    if (!_isSupported) {
      return const UpdateStatus(state: UpdateState.unsupported);
    }
    final s = AppStorage.instance;
    final latest = s.updLatestVer;
    if (latest == null) return const UpdateStatus(state: UpdateState.unknown);
    if (!_isNewer(latest, AppConfig.appVersion)) {
      return const UpdateStatus(state: UpdateState.upToDate);
    }
    final required = AppConfig.appBuild < s.updMinBuild;
    final downloaded = s.updDownloadedVer;
    final path = s.updApkPath;
    if (downloaded == latest &&
        path != null &&
        s.updSha256 != null &&
        File(path).existsSync()) {
      return UpdateStatus(
        state: UpdateState.ready,
        latestVersion: latest,
        apkPath: path,
        required: required,
      );
    }
    return UpdateStatus(
      state: UpdateState.available,
      latestVersion: latest,
      required: required,
    );
  }

  Future<InstallOutcome> installDownloaded() async {
    if (!_isSupported) return InstallOutcome.failed;
    _setBusy(true);
    try {
      var status = currentStatus();
      if (status.state == UpdateState.available) {
        await _downloadOnce();
        status = currentStatus();
        notifyListeners();
      }
      if (status.state != UpdateState.ready || status.apkPath == null) {
        return InstallOutcome.failed;
      }
      try {
        final storage = AppStorage.instance;
        final directory = await _apkDir();
        final file = File(status.apkPath!);
        if (!p.isWithin(directory.path, file.absolute.path) ||
            !await UpdateIntegrity.verify(
              file,
              storage.updSha256,
              storage.updApkSize,
            )) {
          await storage.clearUpdDownloaded();
          throw const FileSystemException(
            'El instalador no superó la verificación SHA-256.',
          );
        }
        if (defaultTargetPlatform == TargetPlatform.android) {
          return await _installApk(file);
        }
        await Process.start(file.path, [], mode: ProcessStartMode.detached);
        return InstallOutcome.started;
      } catch (e) {
        debugPrint('[UpdateService] install failed: $e');
        return InstallOutcome.failed;
      }
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _runCheckAndDownload({required bool force}) async {
    try {
      final s = AppStorage.instance;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (!force) {
        final last = s.updLastCheckMs ?? 0;
        if (now - last < UpdateConfig.checkInterval.inMilliseconds) {
          if (currentStatus().state == UpdateState.available) {
            unawaited(_downloadOnce());
          }
          return;
        }
      }
      await s.setUpdLastCheckMs(now);
      final manifest = await _fetchManifest();
      if (manifest == null) return;
      final version = manifest.version;
      final asset = manifest.assetForThisDevice();
      if (asset == null) return;
      await s.setUpdLatest(
        version: version,
        url: asset.url,
        size: asset.size,
        sha256: asset.sha256,
      );
      await s.setUpdMinBuild(manifest.minBuild);
      if (!_isNewer(version, AppConfig.appVersion)) return;
      // En Android no se descarga sola: el APK se baja muchas veces por datos
      // móviles, y que lo decida el usuario al tocar el aviso. Salvo que esta
      // versión ya no funcione.
      if (defaultTargetPlatform != TargetPlatform.android ||
          currentStatus().required) {
        await _downloadOnce();
      }
      final fresh = currentStatus();
      if (fresh.state == UpdateState.ready) {
        await _notifications.showUpdateReady(version);
      } else if (fresh.state == UpdateState.available) {
        await _notifications.showUpdateAvailable(version);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[UpdateService] check failed: $e');
    }
  }

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
    if (version == null ||
        url == null ||
        UpdateIntegrity.digest(s.updSha256) == null) {
      return;
    }
    final name = Uri.parse(url).pathSegments.lastOrNull ?? '';
    if (!RegExp(r'^\d+\.\d+\.\d+$').hasMatch(version) ||
        !_isAssetForThisPlatform(name, version) ||
        !UpdateIntegrity.releaseAsset(url, 'v$version', name)) {
      return;
    }
    final existingPath = s.updApkPath;
    if (s.updDownloadedVer == version && existingPath != null) {
      final f = File(existingPath);
      if (await f.exists()) {
        final len = await f.length();
        if ((size == null || len == size) &&
            await UpdateIntegrity.verify(f, s.updSha256, size)) {
          return;
        }
        await _safeDelete(f);
        await s.clearUpdDownloaded();
      }
    }
    final dir = await _apkDir();
    final ext = _extensionFromUrl(url) ?? '.apk';
    final dest = File(p.join(dir.path, 'nexo-$version$ext'));
    final part = File('${dest.path}.part');
    final req = http.Request('GET', Uri.parse(url));
    final res = await _http.send(req).timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) {
      throw HttpException(
        'GET $url devolvió ${res.statusCode}',
        uri: Uri.parse(url),
      );
    }
    if (await part.exists()) await _safeDelete(part);
    final sink = part.openWrite();
    try {
      await res.stream.timeout(const Duration(seconds: 30)).pipe(sink);
    } finally {
      await sink.close();
    }
    if (size != null) {
      final len = await part.length();
      if (len != size) {
        await _safeDelete(part);
        throw const FileSystemException(
          'Descarga incompleta — tamaño no coincide con el release.',
        );
      }
    }
    if (!await UpdateIntegrity.verify(part, s.updSha256, size)) {
      await _safeDelete(part);
      throw const FileSystemException(
        'La descarga no coincide con SHA-256 del release.',
      );
    }
    if (await dest.exists()) await _safeDelete(dest);
    await part.rename(dest.path);
    await s.setUpdDownloaded(version, dest.path);
    await _purgeStaleApks(dir, keep: dest.path);
  }

  Future<void> _cleanupIfAlreadyInstalled() async {
    final s = AppStorage.instance;
    final downloaded = s.updDownloadedVer;
    if (downloaded == null) return;
    if (!_isNewer(downloaded, AppConfig.appVersion) &&
        downloaded != AppConfig.appVersion) {}
    if (_isNewer(AppConfig.appVersion, downloaded) ||
        AppConfig.appVersion == downloaded) {
      final path = s.updApkPath;
      if (path != null) await _safeDelete(File(path));
      await s.clearUpdDownloaded();
      final latest = s.updLatestVer;
      if (latest != null && !_isNewer(latest, AppConfig.appVersion)) {
        await s.clearUpdLatest();
      }
    }
  }

  Future<void> _purgeStaleApks(Directory dir, {required String keep}) async {
    try {
      await for (final f in dir.list()) {
        final isArtifact =
            f.path.endsWith('.apk') ||
            f.path.endsWith('.zip') ||
            f.path.endsWith('.exe') ||
            f.path.endsWith('.msix');
        if (f is File && f.path != keep && isArtifact) {
          await _safeDelete(f);
        }
      }
    } catch (_) {}
  }

  static String? _extensionFromUrl(String url) {
    final segs = Uri.parse(url).pathSegments;
    final name = segs.isNotEmpty ? segs.last : '';
    final dot = name.lastIndexOf('.');
    if (dot <= 0) return null;
    return name.substring(dot);
  }

  Future<void> _safeDelete(FileSystemEntity f) async {
    try {
      await f.delete();
    } catch (_) {}
  }

  /// En Android, `files/updates`: la única carpeta que el FileProvider le
  /// deja ver al instalador (res/xml/nexo_update_paths.xml).
  Future<Directory> _apkDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'updates'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// `version.json` del sitio (CDN de GitHub Pages) y, si falla, la copia
  /// del último release. Ninguno pasa por la API de GitHub, que permite 60
  /// consultas por hora por IP y se agotaba con muchos alumnos en la misma
  /// red de la universidad.
  Future<UpdateManifest?> _fetchManifest() async {
    for (final url in const [
      UpdateConfig.manifestUrl,
      UpdateConfig.manifestFallbackUrl,
    ]) {
      try {
        final res = await _http
            .get(Uri.parse(url), headers: const {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 15));
        if (res.statusCode != 200) {
          debugPrint('[UpdateService] $url respondió ${res.statusCode}');
          continue;
        }
        final manifest = UpdateManifest.parse(jsonDecode(res.body));
        if (manifest != null) return manifest;
      } catch (e) {
        debugPrint('[UpdateService] $url: $e');
      }
    }
    return null;
  }

  static bool _isAssetForThisPlatform(String name, String version) {
    final prefix = 'nexo-v$version-';
    if (!name.startsWith(prefix)) return false;
    final suffix = name.substring(prefix.length);
    final keys = UpdateManifest.suffixes.entries
        .where((e) => e.value == suffix)
        .map((e) => e.key);
    final platform = defaultTargetPlatform == TargetPlatform.android
        ? 'android-'
        : 'windows-';
    return keys.any((k) => k.startsWith(platform));
  }

  /// La parte nativa (ApkInstaller.kt) vuelve a comprobar que el APK sea
  /// esta misma app, más nueva y con la misma firma, antes de abrir el
  /// instalador del sistema.
  Future<InstallOutcome> _installApk(File file) async {
    final result = await _installer.invokeMethod<String>('install', {
      'path': file.path,
    });
    switch (result) {
      case 'started':
        return InstallOutcome.started;
      case 'needs_permission':
        await _installer.invokeMethod<void>('openInstallSettings');
        return InstallOutcome.needsPermission;
      case 'wrong_package' || 'wrong_signature' || 'invalid_file':
        // No es nuestro APK: se borra para no volver a ofrecerlo.
        debugPrint('[UpdateService] APK rechazado: $result');
        await _safeDelete(file);
        await AppStorage.instance.clearUpdDownloaded();
        return InstallOutcome.failed;
      default:
        debugPrint('[UpdateService] instalación: $result');
        return InstallOutcome.failed;
    }
  }

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
