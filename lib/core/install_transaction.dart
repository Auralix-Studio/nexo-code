import 'dart:io';
import 'package:path/path.dart' as p;

class InstallTransaction {
  static Future<void> install({
    required Directory source,
    required Directory root,
    required void Function(double) onProgress,
  }) async {
    final rootPath = p.normalize(p.absolute(root.path));
    final sourcePath = p.normalize(p.absolute(source.path));
    final target = Directory(p.join(rootPath, 'bin'));
    if (p.equals(sourcePath, rootPath) ||
        p.equals(sourcePath, target.path) ||
        p.isWithin(target.path, sourcePath) ||
        p.isWithin(sourcePath, rootPath)) {
      throw StateError(
        'Ejecuta el instalador desde una carpeta independiente.',
      );
    }
    for (var path = rootPath; ; path = p.dirname(path)) {
      if (await FileSystemEntity.type(path, followLinks: false) ==
          FileSystemEntityType.link) {
        throw StateError('La ruta de instalación contiene un enlace.');
      }
      if (p.dirname(path) == path) break;
    }
    await root.create(recursive: true);
    final lock = await File(
      p.join(rootPath, '.install.lock'),
    ).open(mode: FileMode.append);
    Directory? staged;
    final backup = Directory(p.join(rootPath, 'bin.previous'));
    var moved = false;
    try {
      await lock.lock(FileLock.exclusive);
      for (final dir in [target, backup]) {
        if (await FileSystemEntity.type(dir.path, followLinks: false) ==
            FileSystemEntityType.link) {
          throw StateError('La instalación contiene un enlace.');
        }
      }
      if (!await target.exists() && await backup.exists()) {
        await backup.rename(target.path);
      }
      staged = await Directory(rootPath).createTemp('bin.new-');
      final entries = await source
          .list(recursive: true, followLinks: false)
          .toList();
      var copied = 0;
      for (final entity in entries) {
        if (entity is Link) {
          throw StateError('El paquete contiene enlaces no admitidos.');
        }
        final destination = p.join(
          staged.path,
          p.relative(entity.path, from: sourcePath),
        );
        if (!p.isWithin(staged.path, destination)) {
          throw StateError('Ruta de paquete inválida.');
        }
        if (entity is Directory) {
          await Directory(destination).create(recursive: true);
        }
        if (entity is File) {
          await Directory(p.dirname(destination)).create(recursive: true);
          await entity.copy(destination);
          if (await File(destination).length() != await entity.length()) {
            throw StateError('Copia incompleta.');
          }
        }
        onProgress(++copied / entries.length);
      }
      for (final name in [
        'nexo.exe',
        'nexo_setup_helper.exe',
        'flutter_windows.dll',
        'data/icudtl.dat',
      ]) {
        if (!await File(p.join(staged.path, name)).exists()) {
          throw StateError('Paquete incompleto: falta $name.');
        }
      }
      if (await backup.exists()) await backup.delete(recursive: true);
      if (await target.exists()) {
        await target.rename(backup.path);
        moved = true;
      }
      try {
        await staged.rename(target.path);
        staged = null;
      } catch (_) {
        if (moved) await backup.rename(target.path);
        rethrow;
      }
    } finally {
      if (staged != null && await staged.exists()) {
        await staged.delete(recursive: true);
      }
      await lock.close();
    }
  }
}
