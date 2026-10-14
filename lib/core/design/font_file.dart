import 'dart:convert';
import 'dart:typed_data';

/// Por qué un archivo no sirve como fuente de la app.
enum FontFileProblem {
  /// No empieza como TrueType ni OpenType.
  notAFont,

  /// WOFF/WOFF2: formato comprimido para navegadores.
  webFont,

  /// TTC/OTC: varias fuentes en un solo archivo.
  collection,

  /// La cabecera promete tablas que no están o se salen del archivo.
  damaged,
}

class FontFileException implements Exception {
  const FontFileException(this.problem);
  final FontFileProblem problem;
  @override
  String toString() => 'FontFileException(${problem.name})';
}

/// Lo que dice de sí mismo un archivo TTF u OTF, leído de sus tablas `name`,
/// `OS/2` y `head` sin pasar por el motor de texto.
class FontFileInfo {
  const FontFileInfo({
    required this.family,
    required this.style,
    required this.weight,
    required this.italic,
    required this.variable,
    required this.isCff,
  });

  /// Familia tipográfica ("Inter"), no el nombre del estilo ("Inter Light").
  final String family;
  final String style;

  /// Peso declarado en OS/2 (100–900).
  final int weight;
  final bool italic;

  /// Tiene ejes de variación (`fvar`): un solo archivo con todos los pesos.
  final bool variable;

  /// Contornos CFF (`.otf`) en lugar de TrueType (`.ttf`).
  final bool isCff;

  String get extension => isCff ? 'otf' : 'ttf';

  static FontFileInfo parse(Uint8List bytes) {
    final font = _Sfnt.read(bytes);
    final names = font.names();
    final family = (names[16] ?? names[1] ?? '').trim();
    final style = (names[17] ?? names[2] ?? '').trim();
    final os2 = font.table('OS/2');
    final head = font.table('head');
    var weight = 400;
    var italic = false;
    if (os2 != null && os2.length >= 64) {
      weight = font.u16(os2.offset + 4);
      // Algunas fuentes antiguas guardan el peso como 1–9.
      if (weight >= 1 && weight <= 9) weight *= 100;
      italic = font.u16(os2.offset + 62) & 0x0001 != 0;
    } else if (head != null && head.length >= 46) {
      final macStyle = font.u16(head.offset + 44);
      weight = macStyle & 0x1 != 0 ? 700 : 400;
      italic = macStyle & 0x2 != 0;
    }
    return FontFileInfo(
      family: family.isEmpty ? 'Sin nombre' : family,
      style: style.isEmpty ? 'Regular' : style,
      weight: weight.clamp(100, 900),
      italic: italic,
      variable: font.table('fvar') != null,
      isCff: font.tag == _otto,
    );
  }

  /// Copia de [bytes] que declara [weight] como su peso.
  ///
  /// Los contornos no cambian: sirve para registrar el mismo archivo bajo
  /// varios pesos. Flutter engorda a mano (negrita sintética) cualquier texto
  /// que pida 200 o más de peso que la fuente que encuentra; con una copia
  /// que ya declara ese peso, no hay nada que engordar y la letra se ve como
  /// la dibujó su autor.
  ///
  /// En una fuente variable el motor no lee el peso de OS/2 sino del valor
  /// por defecto del eje `wght`, así que también se mueve ese valor. La letra
  /// se sigue dibujando en su instancia por defecto: el motor solo recorre el
  /// eje si el texto pide `fontVariations`, y la app no lo hace.
  ///
  /// Devuelve `null` si el archivo no tiene tabla OS/2 donde escribirlo.
  static Uint8List? withWeight(Uint8List bytes, int weight) {
    final font = _Sfnt.read(Uint8List.fromList(bytes));
    final os2 = font.table('OS/2');
    if (os2 == null || os2.length < 64) return null;
    font.setU16(os2.offset + 4, weight);
    final changed = [os2];
    final fvar = font.table('fvar');
    if (fvar != null && font.setWeightAxisDefault(fvar, weight)) {
      changed.add(fvar);
    }
    font.refreshChecksums(changed);
    return font.bytes;
  }
}

const _trueType = 0x00010000;
const _appleTrue = 0x74727565; // 'true'
const _otto = 0x4F54544F; // 'OTTO'
const _woff = 0x774F4646; // 'wOFF'
const _woff2 = 0x774F4632; // 'wOF2'
const _ttcf = 0x74746366; // 'ttcf'

class _Table {
  const _Table(this.record, this.offset, this.length);

  /// Posición de la entrada en el directorio de tablas.
  final int record;
  final int offset;
  final int length;
}

/// Lectura mínima del contenedor sfnt que comparten TTF y OTF.
class _Sfnt {
  _Sfnt._(this.bytes, this.tag, this._tables)
    : _data = ByteData.sublistView(bytes);

  final Uint8List bytes;
  final ByteData _data;
  final int tag;
  final Map<String, _Table> _tables;

  static _Sfnt read(Uint8List bytes) {
    if (bytes.length < 12) {
      throw const FontFileException(FontFileProblem.notAFont);
    }
    final data = ByteData.sublistView(bytes);
    final tag = data.getUint32(0);
    switch (tag) {
      case _woff || _woff2:
        throw const FontFileException(FontFileProblem.webFont);
      case _ttcf:
        throw const FontFileException(FontFileProblem.collection);
      case _trueType || _appleTrue || _otto:
        break;
      default:
        throw const FontFileException(FontFileProblem.notAFont);
    }
    final count = data.getUint16(4);
    if (count == 0 || 12 + 16 * count > bytes.length) {
      throw const FontFileException(FontFileProblem.damaged);
    }
    final tables = <String, _Table>{};
    for (var i = 0; i < count; i++) {
      final record = 12 + 16 * i;
      final name = latin1.decode(bytes.sublist(record, record + 4));
      final offset = data.getUint32(record + 8);
      final length = data.getUint32(record + 12);
      if (offset + length > bytes.length) {
        throw const FontFileException(FontFileProblem.damaged);
      }
      tables[name] = _Table(record, offset, length);
    }
    for (final required in const ['cmap', 'head', 'name']) {
      if (!tables.containsKey(required)) {
        throw const FontFileException(FontFileProblem.damaged);
      }
    }
    if (tables['head']!.length < 54) {
      throw const FontFileException(FontFileProblem.damaged);
    }
    return _Sfnt._(bytes, tag, tables);
  }

  _Table? table(String name) => _tables[name];
  int u16(int at) => _data.getUint16(at);
  void setU16(int at, int value) => _data.setUint16(at, value);

  /// Nombres por `nameID`, quedándose con la mejor versión de cada uno:
  /// Windows en inglés de EE. UU. antes que cualquier otro idioma, y Unicode
  /// antes que Mac Roman.
  Map<int, String> names() {
    final t = _tables['name']!;
    if (t.length < 6) return const {};
    final count = u16(t.offset + 2);
    final strings = t.offset + u16(t.offset + 4);
    final best = <int, (int, String)>{};
    for (var i = 0; i < count; i++) {
      final r = t.offset + 6 + 12 * i;
      if (r + 12 > t.offset + t.length) break;
      final platform = u16(r);
      final encoding = u16(r + 2);
      final language = u16(r + 4);
      final id = u16(r + 6);
      final length = u16(r + 8);
      final start = strings + u16(r + 10);
      if (start + length > bytes.length) continue;
      final int rank;
      final String value;
      if (platform == 3 && (encoding == 1 || encoding == 10 || encoding == 0)) {
        rank = language == 0x0409 ? 4 : 3;
        value = _utf16(start, length);
      } else if (platform == 0) {
        rank = 2;
        value = _utf16(start, length);
      } else if (platform == 1 && encoding == 0) {
        rank = 1;
        value = latin1.decode(bytes.sublist(start, start + length));
      } else {
        continue;
      }
      if (value.trim().isEmpty) continue;
      final current = best[id];
      if (current == null || rank > current.$1) best[id] = (rank, value);
    }
    return {for (final e in best.entries) e.key: e.value.$2};
  }

  String _utf16(int start, int length) {
    final units = <int>[
      for (var i = start; i + 1 < start + length; i += 2) _data.getUint16(i),
    ];
    return String.fromCharCodes(units);
  }

  /// Pone en [weight] el valor por defecto del eje `wght`, ampliando su
  /// rango si hace falta. Como la letra se dibuja en el valor por defecto
  /// (coordenada normalizada 0), los contornos no cambian. `false` si no hay
  /// tal eje.
  bool setWeightAxisDefault(_Table fvar, int weight) {
    if (fvar.length < 16) return false;
    final axes = fvar.offset + u16(fvar.offset + 4);
    final count = u16(fvar.offset + 8);
    final size = u16(fvar.offset + 10);
    if (size < 20) return false;
    for (var i = 0; i < count; i++) {
      final axis = axes + i * size;
      if (axis + 20 > fvar.offset + fvar.length) return false;
      if (_data.getUint32(axis) != 0x77676874) continue; // 'wght'
      final value = weight << 16;
      if (_data.getInt32(axis + 4) > value) _data.setInt32(axis + 4, value);
      if (_data.getInt32(axis + 12) < value) _data.setInt32(axis + 12, value);
      _data.setInt32(axis + 8, value);
      return true;
    }
    return false;
  }

  /// Rehace la suma de verificación de [changed] y el ajuste global de
  /// `head`, para que ningún lector estricto rechace la copia.
  void refreshChecksums(List<_Table> changed) {
    for (final t in changed) {
      _data.setUint32(t.record + 4, _sum(t.offset, t.length));
    }
    final head = _tables['head']!;
    _data.setUint32(head.offset + 8, 0);
    var total = _sum(0, 12 + 16 * _tables.length);
    for (final t in _tables.values) {
      total = (total + _data.getUint32(t.record + 4)) & 0xFFFFFFFF;
    }
    _data.setUint32(head.offset + 8, (0xB1B0AFBA - total) & 0xFFFFFFFF);
  }

  int _sum(int offset, int length) {
    var sum = 0;
    final end = offset + length;
    for (var i = offset; i < end; i += 4) {
      var word = 0;
      for (var b = 0; b < 4; b++) {
        word = (word << 8) | (i + b < end ? bytes[i + b] : 0);
      }
      sum = (sum + word) & 0xFFFFFFFF;
    }
    return sum;
  }
}
