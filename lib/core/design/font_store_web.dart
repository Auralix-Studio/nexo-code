import 'dart:convert';
import 'dart:typed_data';

import 'package:nexo/core/storage.dart';

import 'font_store.dart';

FontFileStore createFontFileStoreImpl() => _PrefsFontFileStore();

/// En web no hay carpeta propia: el archivo va en base64 a las preferencias
/// del navegador, que tienen unos pocos MB para todo el sitio. Por eso el
/// límite es mucho menor que en el resto de plataformas.
class _PrefsFontFileStore implements FontFileStore {
  @override
  int get maxBytes => 1536 * 1024;

  @override
  Future<void> write(String name, Uint8List bytes) =>
      AppStorage.instance.setFontFileBase64(name, base64.encode(bytes));

  @override
  Future<Uint8List?> read(String name) async {
    final raw = AppStorage.instance.fontFileBase64(name);
    return raw == null ? null : base64.decode(raw);
  }

  @override
  Future<void> delete(String name) =>
      AppStorage.instance.setFontFileBase64(name, null);
}
