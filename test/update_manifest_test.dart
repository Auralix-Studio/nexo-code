import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/data/update_manifest.dart';

const _sha = 'a3f1c2d4e5b6978877665544332211009988776655443322110099887766554a';

Map<String, Object> _asset(String suffix, {String? url, String? name}) {
  final file = name ?? 'nexo-v1.9.1-$suffix';
  return {
    'name': file,
    'url':
        url ??
        'https://github.com/Auralix-Studio/nexo/releases/download/v1.9.1/$file',
    'size': 12000000,
    'sha256': _sha,
  };
}

Map<String, Object> _manifest({
  Map<String, Object>? assets,
  Object? minBuild,
}) => {
  'schema': 1,
  'version': '1.9.1',
  'build': 24,
  'min_build': ?minBuild,
  'assets':
      assets ??
      {
        'android-arm64': _asset('arm64.apk'),
        'android-armv7': _asset('armv7.apk'),
        'android-universal': _asset('universal.apk'),
        'windows-x64': _asset('setup-x64.exe'),
      },
};

void main() {
  test('lee versión, build y archivos', () {
    final m = UpdateManifest.parse(_manifest())!;
    expect(m.version, '1.9.1');
    expect(m.build, 24);
    expect(m.tag, 'v1.9.1');
    expect(m.minBuild, 0);
    expect(m.assets.keys, containsAll(['android-arm64', 'windows-x64']));
    expect(m.assets['android-arm64']!.sha256, _sha);
  });

  test('min_build marca las versiones que ya no funcionan', () {
    expect(UpdateManifest.parse(_manifest(minBuild: 22))!.minBuild, 22);
  });

  test('rechaza un manifiesto de otro esquema o versión mal formada', () {
    expect(UpdateManifest.parse({..._manifest(), 'schema': 2}), isNull);
    expect(UpdateManifest.parse({..._manifest(), 'version': '1.9'}), isNull);
    expect(UpdateManifest.parse('no es un mapa'), isNull);
  });

  test('descarta archivos con origen, nombre o hash que no corresponden', () {
    final m = UpdateManifest.parse(
      _manifest(
        assets: {
          // Otro repositorio.
          'android-arm64': _asset(
            'arm64.apk',
            url:
                'https://github.com/otro/nexo/releases/download/v1.9.1/nexo-v1.9.1-arm64.apk',
          ),
          // Nombre de otra versión.
          'android-armv7': _asset('armv7.apk', name: 'nexo-v1.9.0-armv7.apk'),
          // Sin hash.
          'windows-x64': {..._asset('setup-x64.exe'), 'sha256': 'x'},
          // Clave desconocida.
          'linux-x64': _asset('linux-x64.tar.gz'),
          'android-universal': _asset('universal.apk'),
        },
      ),
    )!;
    expect(m.assets.keys, ['android-universal']);
  });

  test('cada dispositivo recibe el APK de su arquitectura', () {
    final m = UpdateManifest.parse(_manifest())!;
    expect(m.assetFor('android-arm64')!.name, 'nexo-v1.9.1-arm64.apk');
    expect(m.assetFor('android-armv7')!.name, 'nexo-v1.9.1-armv7.apk');
    // Sin APK propio cae al universal, nunca al de otra arquitectura.
    expect(m.assetFor('android-x86_64')!.name, 'nexo-v1.9.1-universal.apk');
    expect(m.assetFor('windows-x64')!.name, 'nexo-v1.9.1-setup-x64.exe');
    expect(m.assetFor(null), isNull);
  });
}
