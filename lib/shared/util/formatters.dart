/// Formateadores de texto compartidos (moneda, fechas, nombres).
abstract final class Fmt {
  static String currency(double v, [String simbolo = 'S/']) {
    final negativo = v < 0;
    final abs = v.abs();
    final entero = abs.truncate();
    final decimales = ((abs - entero) * 100).round();
    final enteroStr = entero.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
    final s = '$simbolo $enteroStr.${decimales.toString().padLeft(2, '0')}';
    return negativo ? '-$s' : s;
  }

  static const _meses = [
    '', 'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
    'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic', //
  ];

  static const _dias = [
    '', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'
  ];

  static String dayLabel(int idDia) =>
      idDia >= 1 && idDia <= 7 ? _dias[idDia] : '';

  static String shortDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} ${_meses[d.month]} ${d.year}';

  static String fullDate(DateTime d) {
    const dias = ['', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    return '${dias[d.weekday]}, ${d.day} ${_meses[d.month]}';
  }

  static String greeting(DateTime now) {
    final h = now.hour;
    if (h < 12) return 'Buenos días';
    if (h < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  static String firstName(String full) {
    final parts =
        full.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.length >= 3) return parts[2]; // SIGMA: APELLIDOS NOMBRES
    if (parts.length == 2) return parts[1];
    return full;
  }

  static String initials(String s) {
    final p =
        s.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (p.isEmpty) return '?';
    if (p.length == 1) return p.first.substring(0, 1).toUpperCase();
    return (p.first.substring(0, 1) + p.last.substring(0, 1)).toUpperCase();
  }
}
