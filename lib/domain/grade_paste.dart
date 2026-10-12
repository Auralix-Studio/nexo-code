/// Notas pegadas desde una hoja de cálculo. Muchos docentes llevan sus notas en
/// Excel; en SIGMA hay que tipearlas una por una. Aquí se pega la columna (o
/// código + nota) y la app las reparte en la lista antes de guardar.
library;

/// Valida una nota escrita: número entre 0 y [max] con hasta 2 decimales
/// (SIGMA recorta a 2 decimales); acepta coma decimal. `null` si es inválida.
double? parseGradeValue(String raw, double max) {
  final t = raw.trim().replaceAll(',', '.');
  if (t.isEmpty) return null;
  if (!RegExp(r'^\d{1,2}(\.\d{1,2})?$').hasMatch(t)) return null;
  final v = double.parse(t);
  if (v < 0 || v > max) return null;
  return v;
}

class GradePaste {
  /// Código de alumno → nota.
  final Map<String, double> values;

  /// Se emparejó por código (si no, por el orden de la lista).
  final bool byCode;

  /// Filas con datos que no se pudieron usar.
  final int skipped;

  /// En modo por orden, cantidad de filas copiadas cuando no coincide con la
  /// de alumnos (no se aplica nada). `null` si todo cuadra.
  final int? mismatchRows;

  const GradePaste({
    required this.values,
    required this.byCode,
    required this.skipped,
    this.mismatchRows,
  });

  bool get isEmpty => values.isEmpty;
}

/// Interpreta el portapapeles sin adivinar:
/// - Si alguna fila trae un código de [orderedCodes], se empareja por código y
///   la nota es el único número a la derecha del código.
/// - Si no, cada fila es la nota del alumno en esa posición de la lista (una
///   celda vacía lo deja sin nota). Se ignoran un encabezado sin números y una
///   columna de N.º de orden. Si el número de filas no coincide con el de
///   alumnos no se aplica nada.
///
/// Una fila con varios números candidatos se ignora en vez de elegir uno.
/// Devuelve `null` si no hay nada utilizable.
GradePaste? parseGradePaste(
  String text,
  List<String> orderedCodes, {
  required double max,
}) {
  final known = {for (final c in orderedCodes) c.trim().toUpperCase(): c};
  var lines = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
  // Excel termina la copia con un salto de línea.
  while (lines.isNotEmpty && lines.last.trim().isEmpty) {
    lines = lines.sublist(0, lines.length - 1);
  }
  if (lines.isEmpty) return null;

  // Celdas separadas por tabulador (Excel/Sheets), punto y coma o espacios.
  // La coma no separa: es la coma decimal ("12,5").
  final rows = [
    for (final l in lines)
      l.split(RegExp(r'[\t;\s]+')).where((e) => e.isNotEmpty).toList(),
  ];
  bool isNumber(String c) => RegExp(r'^\d+([.,]\d+)?$').hasMatch(c);
  int codeIndex(List<String> r) =>
      r.indexWhere((c) => known.containsKey(c.toUpperCase()));

  if (rows.any((r) => codeIndex(r) >= 0)) {
    final values = <String, double>{};
    var skipped = 0;
    for (final r in rows) {
      final i = codeIndex(r);
      if (i < 0) {
        if (r.any(isNumber)) skipped++;
        continue;
      }
      final nums = r.skip(i + 1).where(isNumber).toList();
      if (nums.isEmpty) continue;
      final v = nums.length == 1 ? parseGradeValue(nums.single, max) : null;
      if (v == null) {
        skipped++;
      } else {
        values[known[r[i].toUpperCase()]!] = v;
      }
    }
    if (values.isEmpty && skipped == 0) return null;
    return GradePaste(values: values, byCode: true, skipped: skipped);
  }

  var data = rows;
  if (data.first.isNotEmpty && !data.first.any(isNumber)) {
    data = data.sublist(1);
  }
  if (data.isEmpty || !data.any((r) => r.any(isNumber))) return null;
  if (data.length != orderedCodes.length) {
    return GradePaste(
      values: const {},
      byCode: false,
      skipped: 0,
      mismatchRows: data.length,
    );
  }
  final values = <String, double>{};
  var skipped = 0;
  for (var i = 0; i < data.length; i++) {
    final r = data[i];
    if (r.isEmpty) continue;
    var nums = r.where(isNumber).toList();
    // "1  ALVAREZ ANA  14": el primer número es el N.º de orden.
    if (nums.length == 2 && nums.first == '${i + 1}') nums = [nums.last];
    final v = nums.length == 1 ? parseGradeValue(nums.single, max) : null;
    if (v == null) {
      skipped++;
    } else {
      values[orderedCodes[i]] = v;
    }
  }
  return GradePaste(values: values, byCode: false, skipped: skipped);
}
