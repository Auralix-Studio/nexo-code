import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'font_store.dart';

FontFileStore createFontFileStoreImpl() => _DiskFontFileStore();

/// Archivos en `<soporte de la app>/fonts`, fuera de cualquier caché que el
/// sistema pueda vaciar.
class _DiskFontFileStore implements FontFileStore {
  Future<Directory>? _dir;

  @override
  int get maxBytes => 8 * 1024 * 1024;

  Future<Directory> _folder() => _dir ??= () async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'fonts'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }();

  Future<File> _file(String name) async =>
      File(p.join((await _folder()).path, p.basename(name)));

  @override
  Future<void> write(String name, Uint8List bytes) async {
    await (await _file(name)).writeAsBytes(bytes, flush: true);
  }

  @override
  Future<Uint8List?> read(String name) async {
    final f = await _file(name);
    return await f.exists() ? f.readAsBytes() : null;
  }

  @override
  Future<void> delete(String name) async {
    final f = await _file(name);
    if (await f.exists()) await f.delete();
  }
}
