import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:nexo/core/config.dart';
import 'package:nexo/core/install_transaction.dart';
import 'package:nexo/core/update_integrity.dart';
import 'package:nexo/core/windows_process.dart';

void main() {
  late Directory workspace;
  late Directory source;
  late Directory root;
  setUp(() async {
    workspace = await Directory(
      p.join(Directory.current.path, '.dart_tool'),
    ).createTemp('installer-test-');
    source = await Directory(p.join(workspace.path, 'source')).create();
    root = await Directory(p.join(workspace.path, 'Nexo')).create();
  });
  tearDown(() async {
    final allowed = p.join(Directory.current.path, '.dart_tool');
    if (!p.isWithin(allowed, workspace.absolute.path))
      throw StateError('Unsafe test cleanup');
    await workspace.delete(recursive: true);
  });
  Future<void> package(Directory directory, String version) async {
    for (final name in [
      'nexo.exe',
      'nexo_setup_helper.exe',
      'flutter_windows.dll',
      'data/icudtl.dat',
    ]) {
      final file = File(p.join(directory.path, name));
      await file.parent.create(recursive: true);
      await file.writeAsString(version);
    }
  }

  Future<void> install() => InstallTransaction.install(
    source: source,
    root: root,
    onProgress: (_) {},
  );

  test('incomplete package never removes the installed version', () async {
    await package(Directory(p.join(root.path, 'bin')), 'old');
    await File(p.join(source.path, 'nexo.exe')).writeAsString('new');
    await expectLater(install(), throwsStateError);
    expect(await File(p.join(root.path, 'bin/nexo.exe')).readAsString(), 'old');
    expect(
      await root
          .list()
          .where((e) => p.basename(e.path).startsWith('bin.new-'))
          .length,
      0,
    );
  });
  test(
    'complete update replaces the version and keeps a recovery copy',
    () async {
      await package(Directory(p.join(root.path, 'bin')), 'old');
      await package(source, 'new');
      await install();
      expect(
        await File(p.join(root.path, 'bin/nexo.exe')).readAsString(),
        'new',
      );
      expect(
        await File(p.join(root.path, 'bin.previous/nexo.exe')).readAsString(),
        'old',
      );
    },
  );
  test(
    'interrupted rename restores the previous version before attempting an update',
    () async {
      await package(Directory(p.join(root.path, 'bin.previous')), 'old');
      await expectLater(install(), throwsStateError);
      expect(
        await File(p.join(root.path, 'bin/nexo.exe')).readAsString(),
        'old',
      );
    },
  );
  test('copy interruption leaves existing application usable', () async {
    await package(Directory(p.join(root.path, 'bin')), 'old');
    await package(source, 'new');
    await expectLater(
      InstallTransaction.install(
        source: source,
        root: root,
        onProgress: (_) => throw const FileSystemException('disk failure'),
      ),
      throwsA(isA<FileSystemException>()),
    );
    expect(await File(p.join(root.path, 'bin/nexo.exe')).readAsString(), 'old');
  });
  test(
    'cannot install over the currently executing package directory',
    () async {
      final installed = Directory(p.join(root.path, 'bin'));
      await package(installed, 'old');
      await expectLater(
        InstallTransaction.install(
          source: installed,
          root: root,
          onProgress: (_) {},
        ),
        throwsStateError,
      );
    },
  );
  test('Windows accepts only the independent Nexo x64 installer', () {
    expect(UpdateConfig.isWindowsAsset('nexo-v1.6.7-setup-x64.exe'), isTrue);
    for (final name in [
      'nexo-v1.6.7-macos.zip',
      'nexo-v1.6.7-windows-x64.zip',
      'tool.exe',
      'nexo.msix',
      'nexo-v1.6.7-setup-arm64.exe',
    ]) {
      expect(UpdateConfig.isWindowsAsset(name), isFalse);
    }
  });
  test('hash rejects equal-size tampering and missing digest', () async {
    final file = File(p.join(source.path, 'setup.exe'));
    final good = [1, 2, 3, 4];
    final hash = sha256.convert(good).toString();
    await file.writeAsBytes(good);
    expect(await UpdateIntegrity.verify(file, hash, 4), isTrue);
    expect(await UpdateIntegrity.verify(file, null, 4), isFalse);
    await file.writeAsBytes([4, 3, 2, 1]);
    expect(await UpdateIntegrity.verify(file, hash, 4), isFalse);
  });
  test('release URL must belong to the expected repository, tag and asset', () {
    const tag = 'v1.6.7', name = 'nexo-v1.6.7-setup-x64.exe';
    const url =
        'https://github.com/auralix-studio/nexo/releases/download/$tag/$name';
    expect(UpdateIntegrity.releaseAsset(url, tag, name), isTrue);
    expect(
      UpdateIntegrity.releaseAsset(
        url.replaceFirst('github.com', 'evil.test'),
        tag,
        name,
      ),
      isFalse,
    );
    expect(UpdateIntegrity.releaseAsset(url, 'v1.6.6', name), isFalse);
    expect(
      UpdateIntegrity.releaseAsset('$url?redirect=evil', tag, name),
      isFalse,
    );
  });
  test('PowerShell paths preserve apostrophes and dollar signs literally', () {
    expect(WindowsProcess.literal(r"C:\O'Brien\$data"), r"'C:\O''Brien\$data'");
  });
}
