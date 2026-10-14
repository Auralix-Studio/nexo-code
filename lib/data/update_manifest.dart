import 'package:nexo/core/update_integrity.dart';

import 'update_target_web.dart'
    if (dart.library.ffi) 'update_target_io.dart'
    as target;

/// Archivo de una plataforma dentro de `version.json`.
class UpdateAsset {
  const UpdateAsset({
    required this.name,
    required this.url,
    required this.size,
    required this.sha256,
  });
  final String name;
  final String url;
  final int size;
  final String sha256;
}

/// `version.json`: lo publica el pipeline de release en el sitio y como
/// archivo del release. Esquema en `scripts/release_assets.py manifest`.
class UpdateManifest {
  const UpdateManifest({
    required this.version,
    required this.build,
    required this.tag,
    required this.minBuild,
    required this.assets,
  });

  final String version;
  final int build;
  final String tag;

  /// Las versiones con build menor ya no funcionan (p. ej. cambió el sistema
  /// académico): hay que actualizar sí o sí.
  final int minBuild;

  /// Por clave de plataforma: `android-arm64`, `windows-x64`…
  final Map<String, UpdateAsset> assets;

  static final _version = RegExp(r'^\d+\.\d+\.\d+$');

  /// Sufijo del nombre de archivo de cada clave, tal como lo sube el release.
  static const suffixes = {
    'android-arm64': 'arm64.apk',
    'android-armv7': 'armv7.apk',
    'android-x86_64': 'x86_64.apk',
    'android-universal': 'universal.apk',
    'windows-x64': 'setup-x64.exe',
  };

  /// `null` si el JSON no es un manifiesto válido. Los archivos que no
  /// cumplen el formato (nombre, origen, hash) se descartan uno por uno: un
  /// error en el de Windows no deja sin actualización a Android.
  static UpdateManifest? parse(Object? json) {
    if (json is! Map || json['schema'] != 1) return null;
    final version = json['version'];
    final build = json['build'];
    if (version is! String || !_version.hasMatch(version) || build is! int) {
      return null;
    }
    final tag = 'v$version';
    final assets = <String, UpdateAsset>{};
    final raw = json['assets'];
    if (raw is Map) {
      for (final MapEntry(:key, :value) in raw.entries) {
        final suffix = suffixes[key];
        if (suffix == null || value is! Map) continue;
        final name = value['name'];
        final url = value['url'];
        final size = value['size'];
        final sha = UpdateIntegrity.digest(value['sha256'] as String?);
        if (name != 'nexo-$tag-$suffix' ||
            url is! String ||
            size is! int ||
            size <= 0 ||
            sha == null ||
            !UpdateIntegrity.releaseAsset(url, tag, name as String)) {
          continue;
        }
        assets[key as String] = UpdateAsset(
          name: name,
          url: url,
          size: size,
          sha256: sha,
        );
      }
    }
    final minBuild = json['min_build'];
    return UpdateManifest(
      version: version,
      build: build,
      tag: tag,
      minBuild: minBuild is int ? minBuild : 0,
      assets: assets,
    );
  }

  /// El archivo para este dispositivo. En Android, el de su arquitectura
  /// (unos 12 MB) y no el universal; este solo si no hay uno específico.
  UpdateAsset? assetForThisDevice() => assetFor(target.currentTargetKey());

  UpdateAsset? assetFor(String? key) {
    if (key == null) return null;
    return assets[key] ??
        (key.startsWith('android-') ? assets['android-universal'] : null);
  }
}
