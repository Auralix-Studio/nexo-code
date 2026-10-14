import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:nexo/core/design/font_file.dart';
import 'package:nexo/core/design/font_store.dart';
import 'package:nexo/core/storage.dart';

/// De dónde sale una fuente elegible.
enum FontKind {
  /// La de siempre de Nexo.
  standard,

  /// La que trae el sistema operativo.
  system,

  /// Empaquetada con la app.
  bundled,

  /// Importada por el usuario desde un archivo.
  imported,
}

/// Un archivo de una fuente importada: un peso y estilo concretos.
@immutable
class FontFace {
  const FontFace({
    required this.file,
    required this.weight,
    required this.italic,
    required this.style,
  });
  final String file;
  final int weight;
  final bool italic;
  final String style;

  Map<String, Object> toJson() => {
    'file': file,
    'weight': weight,
    'italic': italic,
    'style': style,
  };

  static FontFace? fromJson(Object? json) {
    if (json is! Map) return null;
    final file = json['file'];
    final weight = json['weight'];
    if (file is! String || weight is! int) return null;
    return FontFace(
      file: file,
      weight: weight,
      italic: json['italic'] == true,
      style: json['style'] is String ? json['style'] as String : 'Regular',
    );
  }
}

/// Una tipografía que se puede aplicar a toda la app.
@immutable
class FontChoice {
  const FontChoice._({
    required this.id,
    required this.name,
    required this.kind,
    this.family,
    this.asset,
    this.faces = const [],
    this.variable = false,
  });

  final String id;

  /// Nombre para mostrar.
  final String name;
  final FontKind kind;

  /// Familia que recibe `TextStyle.fontFamily`; `null` es la del sistema.
  final String? family;

  /// Archivo dentro del bundle, para las empaquetadas.
  final String? asset;

  /// Archivos guardados, para las importadas.
  final List<FontFace> faces;

  /// Alguno de sus archivos es una fuente variable.
  final bool variable;

  /// Hay que registrarla en el motor antes de usarla.
  bool get needsLoading => asset != null || faces.isNotEmpty;

  static FontChoice _imported(
    String id,
    String name,
    List<FontFace> faces,
    bool variable,
  ) {
    final sorted = [...faces]
      ..sort((a, b) {
        final byWeight = a.weight.compareTo(b.weight);
        if (byWeight != 0) return byWeight;
        return (a.italic ? 1 : 0).compareTo(b.italic ? 1 : 0);
      });
    // El motor no deja quitar una familia ya registrada. Si cambian sus
    // archivos, se registra con otro nombre para no mezclar los de antes.
    final revision = sha1
        .convert(utf8.encode(sorted.map((f) => f.file).join('|')))
        .toString()
        .substring(0, 8);
    return FontChoice._(
      id: id,
      name: name,
      kind: FontKind.imported,
      family: 'Nexo $name $revision',
      faces: List.unmodifiable(sorted),
      variable: variable,
    );
  }

  Map<String, Object> _toJson() => {
    'id': id,
    'name': name,
    'variable': variable,
    'faces': [for (final f in faces) f.toJson()],
  };

  static FontChoice? _fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final name = json['name'];
    final faces = json['faces'];
    if (id is! String || name is! String || faces is! List) return null;
    final parsed = faces.map(FontFace.fromJson).nonNulls.toList();
    if (parsed.isEmpty) return null;
    return _imported(id, name, parsed, json['variable'] == true);
  }
}

/// Por qué no entró un archivo al importar.
enum FontImportProblem {
  notAFont,
  webFont,
  collection,
  damaged,
  tooLarge,
  notSaved,
}

@immutable
class FontRejection {
  const FontRejection(this.file, this.problem);
  final String file;
  final FontImportProblem problem;
}

/// Resultado de una importación: familias nuevas o ampliadas, y archivos que
/// no se pudieron usar.
@immutable
class FontImport {
  const FontImport({required this.fonts, required this.rejected});
  final List<FontChoice> fonts;
  final List<FontRejection> rejected;
}

/// Archivo elegido por el usuario, aún sin validar.
typedef PickedFontFile = ({String name, Uint8List bytes});

/// Catálogo de tipografías: las que trae Nexo y las que importa el usuario.
///
/// Se encarga también de registrarlas en el motor de texto, porque una fuente
/// importada no existe para Flutter hasta que se le pasan sus bytes.
class FontLibrary {
  FontLibrary({FontFileStore? store, AssetBundle? bundle})
    : _store = store ?? createFontFileStore(),
      _bundle = bundle ?? rootBundle;

  final FontFileStore _store;
  final AssetBundle _bundle;

  static const defaultId = 'roboto';

  static const List<FontChoice> presets = [
    FontChoice._(
      id: defaultId,
      name: 'Roboto',
      kind: FontKind.standard,
      family: 'Roboto',
    ),
    FontChoice._(id: 'system', name: 'Sistema', kind: FontKind.system),
    FontChoice._(
      id: 'hypero',
      name: 'Hypero',
      kind: FontKind.bundled,
      family: 'Nexo Hypero',
      asset: 'assets/fonts/Hypero.ttf',
    ),
    FontChoice._(
      id: 'supermindset',
      name: 'Super Mindset',
      kind: FontKind.bundled,
      family: 'Nexo Super Mindset',
      asset: 'assets/fonts/Super Mindset.ttf',
    ),
  ];

  final List<FontChoice> _imported = [];
  final Map<String, Future<bool>> _registered = {};

  /// Tamaño máximo por archivo en esta plataforma.
  int get maxBytes => _store.maxBytes;

  List<FontChoice> get imported => List.unmodifiable(_imported);
  List<FontChoice> get all => [...presets, ..._imported];

  FontChoice? byId(String id) {
    for (final f in presets) {
      if (f.id == id) return f;
    }
    for (final f in _imported) {
      if (f.id == id) return f;
    }
    return null;
  }

  /// Lee la lista de importadas guardada. No toca los archivos: se cargan al
  /// elegir cada fuente.
  void load() {
    _imported.clear();
    final raw = AppStorage.instance.importedFontsJson;
    if (raw == null) return;
    try {
      final list = jsonDecode(raw);
      if (list is! List) return;
      _imported.addAll(list.map(FontChoice._fromJson).nonNulls);
    } catch (_) {
      // Una lista ilegible no debe impedir arrancar: se empieza sin importadas.
      _imported.clear();
    }
  }

  /// Registra la fuente en el motor de texto si aún no lo está. Devuelve
  /// `false` si no se pudo (archivo borrado o ilegible); el texto sigue
  /// saliendo con la fuente del sistema.
  Future<bool> ensureLoaded(String id) {
    final font = byId(id);
    if (font == null) return Future.value(false);
    if (!font.needsLoading) return Future.value(true);
    return _registered[font.family!] ??= _register(font).catchError((Object e) {
      debugPrint('Fuente «${font.name}» no se pudo cargar: $e');
      _registered.remove(font.family);
      return false;
    });
  }

  Future<bool> _register(FontChoice font) async {
    final faces = <FontBytes>[];
    if (font.asset != null) {
      final data = await _bundle.load(font.asset!);
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      final info = FontFileInfo.parse(bytes);
      faces.add((weight: info.weight, italic: info.italic, bytes: bytes));
    } else {
      for (final face in font.faces) {
        final bytes = await _store.read(face.file);
        if (bytes == null) continue;
        faces.add((weight: face.weight, italic: face.italic, bytes: bytes));
      }
    }
    if (faces.isEmpty) return false;
    final loader = FontLoader(font.family!);
    for (final bytes in coverBoldWeights(faces)) {
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
    return true;
  }

  /// Peso que declara la copia: el máximo. Al pedir negrita (600 o más),
  /// el motor elige la cara más liviana entre las que pesan al menos lo
  /// pedido; con una de 900 siempre hay una, y nunca queda 200 por debajo,
  /// que es cuando engorda la letra a mano.
  static const coverWeight = 900;

  /// Los archivos de [faces] más, por estilo (recto y cursiva), una copia
  /// de la cara más gruesa que declara [coverWeight].
  ///
  /// Sin esto, una fuente que solo trae Regular sale con negrita sintética en
  /// cada título y etiqueta (la app usa w600–w900 en casi todas partes), y se
  /// ve pastosa y mucho más pesada de lo que es. La copia conserva los
  /// contornos: los títulos se ven con el grosor real del archivo. Si la
  /// familia ya trae una cara de 800 o más, no hace falta.
  static List<Uint8List> coverBoldWeights(List<FontBytes> faces) {
    final out = [for (final f in faces) f.bytes];
    for (final italic in {for (final f in faces) f.italic}) {
      final heaviest = faces
          .where((f) => f.italic == italic)
          .reduce((a, b) => b.weight > a.weight ? b : a);
      if (coverWeight - heaviest.weight < 200) continue;
      final copy = FontFileInfo.withWeight(heaviest.bytes, coverWeight);
      if (copy != null) out.add(copy);
    }
    return out;
  }

  /// Valida, guarda y agrupa por familia los archivos elegidos. Los de una
  /// familia ya importada se suman a ella; un mismo peso y estilo se
  /// reemplaza.
  Future<FontImport> import(List<PickedFontFile> files) async {
    final rejected = <FontRejection>[];
    final parsed = <String, List<(PickedFontFile, FontFileInfo)>>{};
    for (final file in files) {
      if (file.bytes.length > _store.maxBytes) {
        rejected.add(FontRejection(file.name, FontImportProblem.tooLarge));
        continue;
      }
      try {
        final info = FontFileInfo.parse(file.bytes);
        parsed.putIfAbsent(info.family.toLowerCase(), () => []).add((
          file,
          info,
        ));
      } on FontFileException catch (e) {
        rejected.add(
          FontRejection(file.name, switch (e.problem) {
            FontFileProblem.notAFont => FontImportProblem.notAFont,
            FontFileProblem.webFont => FontImportProblem.webFont,
            FontFileProblem.collection => FontImportProblem.collection,
            FontFileProblem.damaged => FontImportProblem.damaged,
          }),
        );
      }
    }

    final changed = <FontChoice>[];
    final orphaned = <String>{};
    for (final entry in parsed.entries) {
      final existing = _imported
          .where((f) => f.name.toLowerCase() == entry.key)
          .firstOrNull;
      final faces = [...?existing?.faces];
      var variable = existing?.variable ?? false;
      var saved = 0;
      for (final (file, info) in entry.value) {
        final name =
            '${sha256.convert(file.bytes).toString().substring(0, 20)}'
            '.${info.extension}';
        try {
          await _store.write(name, file.bytes);
        } catch (e) {
          debugPrint('No se pudo guardar la fuente: $e');
          rejected.add(FontRejection(file.name, FontImportProblem.notSaved));
          continue;
        }
        saved++;
        variable = variable || info.variable;
        faces.removeWhere((f) {
          final same =
              f.file == name ||
              (f.weight == info.weight && f.italic == info.italic);
          if (same && f.file != name) orphaned.add(f.file);
          return same;
        });
        faces.add(
          FontFace(
            file: name,
            weight: info.weight,
            italic: info.italic,
            style: info.style,
          ),
        );
      }
      if (saved == 0) continue;
      final font = FontChoice._imported(
        existing?.id ??
            'user:${sha1.convert(utf8.encode(entry.key)).toString().substring(0, 12)}',
        existing?.name ?? entry.value.first.$2.family,
        faces,
        variable,
      );
      if (existing != null) {
        _imported[_imported.indexOf(existing)] = font;
      } else {
        _imported.add(font);
      }
      changed.add(font);
    }

    if (changed.isNotEmpty) await _persist();
    await _deleteUnused(orphaned);
    return FontImport(fonts: changed, rejected: rejected);
  }

  Future<void> remove(String id) async {
    final font = _imported.where((f) => f.id == id).firstOrNull;
    if (font == null) return;
    _imported.remove(font);
    await _persist();
    await _deleteUnused({for (final f in font.faces) f.file});
  }

  Future<void> _persist() => AppStorage.instance.setImportedFontsJson(
    jsonEncode([for (final f in _imported) f._toJson()]),
  );

  /// Borra los de [files] que ya no usa ninguna familia.
  Future<void> _deleteUnused(Set<String> files) async {
    final inUse = {
      for (final f in _imported) ...f.faces.map((face) => face.file),
    };
    for (final file in files.difference(inUse)) {
      try {
        await _store.delete(file);
      } catch (_) {}
    }
  }
}

/// Bytes de un archivo de fuente con el peso y estilo que declara.
typedef FontBytes = ({int weight, bool italic, Uint8List bytes});
