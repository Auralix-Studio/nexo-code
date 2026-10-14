import 'dart:typed_data';

import 'font_store_web.dart' if (dart.library.io) 'font_store_io.dart' as impl;

/// Dónde quedan guardados los archivos de las fuentes importadas.
abstract interface class FontFileStore {
  /// Tamaño máximo aceptado por archivo.
  int get maxBytes;
  Future<void> write(String name, Uint8List bytes);
  Future<Uint8List?> read(String name);
  Future<void> delete(String name);
}

FontFileStore createFontFileStore() => impl.createFontFileStoreImpl();

/// Para pruebas: todo en memoria.
class MemoryFontFileStore implements FontFileStore {
  MemoryFontFileStore({this.maxBytes = 8 * 1024 * 1024});
  @override
  final int maxBytes;
  final Map<String, Uint8List> files = {};
  @override
  Future<void> write(String name, Uint8List bytes) async => files[name] = bytes;
  @override
  Future<Uint8List?> read(String name) async => files[name];
  @override
  Future<void> delete(String name) async => files.remove(name);
}
