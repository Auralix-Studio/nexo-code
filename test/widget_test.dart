import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/domain/models.dart';
import 'package:nexo/features/legal/support_screen.dart';
import 'package:nexo/l10n/app_localizations.dart';
import 'package:nexo/shared/util/formatters.dart';

void main() {
  test('Cuota.daysUntilDue calcula días correctamente', () {
    final c = Cuota.fromJson({
      'descripcion': 'CUOTA 02',
      'fechaVencimiento': '20-05-2026',
      'tipoMoneda': 'S/.',
      'importe': 522.5,
      'mora': 0,
      'subtotal': 522.5,
      'observacion': '',
    });
    final now = DateTime(2026, 5, 14);
    expect(c.daysUntilDue(now), 6);
  });

  test('ClaseHorario decodifica campos clave', () {
    final c = ClaseHorario.fromJson({
      'id': '331131',
      'asignatura': 'ANTROPOLOGÍA',
      'idDia': 4,
      'horaInicio': '13:45',
      'horaFin': '15:15',
      'aula': 'I 304',
      'docente': 'MEZA VARGAS ZENAIDA',
      'idTipo': 'T',
    });
    expect(c.asignatura, 'ANTROPOLOGÍA');
    expect(c.tipoLargo, 'Teoría');
    expect(c.idDia, 4);
  });

  test('NotaAsignatura parsea ambos parciales con su capitalización real', () {
    // Caso real de SIGMA: campos en minúscula para el primer parcial
    // y prefijo "_2" + Nta capitalizado para el segundo.
    final n = NotaAsignatura.fromJson({
      'codigo': '331126',
      'asignatura': 'INVESTIGACIÓN FORMATIVA',
      'seccion': 'A1',
      'ciclo': '02',
      'credito': '3.000',
      'asistencia': '100',
      'mtr_Anio': '2025',
      'mtr_Periodo': '2',
      'pF1': '09',
      'pF2': '13',
      'pf': '11',
      'pfp': '11',
      'puesto': '43/62',
      'tipoAsignatura': 'TN',
      'complementario': '--',
      'cc': 'True',
      // Primer parcial — campos lowercase "nta"
      'p1': '15   ',
      'p2': '12   ',
      'p3': '15   ',
      'p4': '     ',
      'ntaP1': '14.00',
      'ntaTI1': '15   ',
      'ntaPY1': '     ',
      'ntaPromTiPy': '14.50',
      'ntaParcial1': '3    ',
      // Segundo parcial — prefijo "_2" + Nta capital
      '_2P1': '13   ',
      '_2P2': '14   ',
      '_2P3': '     ',
      '_2P4': '     ',
      '_2NtaP1': '13.50',
      '_2NtaTI1': '12   ',
      '_2NtaPY1': '     ',
      '_2NtaPromTiPy': '12.75',
      '_2NtaParcial1': '13   ',
    });
    expect(n.notaActualNum, 11);
    expect(n.notaActualText, '11');
    expect(n.aprobado, true);
    expect(n.asistenciaPct, 100);
    expect(n.pF1, '09');
    expect(n.pF2, '13');

    expect(n.primer.practicas, ['15', '12', '15', '']);
    expect(n.primer.promPracticas, '14.00');
    expect(n.primer.trabajoInv, '15');
    expect(n.primer.promTiPy, '14.50');
    expect(n.primer.examen, '3');

    expect(n.segundo.practicas, ['13', '14', '', '']);
    expect(n.segundo.promPracticas, '13.50');
    expect(n.segundo.examen, '13');
    expect(n.segundo.vacio, false);
  });

  test('notaFmt y RecordCurso manejan decimales', () {
    expect(notaFmt('14.00'), '14');
    expect(notaFmt('14.50'), '14.50');
    expect(notaFmt('15'), '15');
    expect(notaFmt('  '), '—');
    expect(notaFmt('--'), '—');
    expect(notaToDouble('14,5'), 14.5);

    final c = RecordCurso.fromRow([
      'INGENIERÍA', 'INGENIERÍA DE SISTEMAS Y COMPUTACIÓN', '2022',
      'concluido', 'TN', '1', '33111A', 'METODOLOGÍA', '2', '0',
      '33111A', ' ', '14.00', ' ', '1', 'Jul 13 2025', 'ALESSANDRO',
    ]);
    expect(c.nombre, 'METODOLOGÍA');
    expect(c.nota, 14.0);
    expect(c.notaText, '14');
    expect(c.aprobado, true);
    expect(c.concluido, true);
  });

  test('BoletaCurso parsea la fila real (modelo nuevo 2026-1)', () {
    final b = BoletaCurso.fromRow([
      '72AF4D09-553C-4E2D-BF80-203D0F381292', '2022', '02', '2',
      '332123', 'ALGEBRA LINEAL', 'A1', '100', '2.8000', '3', 'Dsp.',
    ]);
    expect(b.matriculaAsignaturaId, '72AF4D09-553C-4E2D-BF80-203D0F381292');
    expect(b.codigo, '332123');
    expect(b.nombre, 'ALGEBRA LINEAL');
    expect(b.seccion, 'A1');
    expect(b.asistencia, 100);
    expect(b.promedio, 2.8);
    expect(b.promedioText, '2.80');
    expect(b.enProceso, true);
  });

  test('CursoDetalleNotas agrupa unidades/evidencias/promedios', () {
    const id = 'F7AADDA4-A1B3-4D53-8131-3A70A2C42057';
    final det = CursoDetalleNotas.fromRows([
      ['210131', id, '12', '121', 'UNIDAD 1', '20.00', '11',
        'EVIDENCIA DE CONOCIMIENTO', '100.00', '15.00', ' ', 'tbl1'],
      ['210168', id, '12', '121', 'UNIDAD 1', '20.00', '12',
        'EVIDENCIA DE DESEMPEÑO', '100.00', '14.00', ' ', 'tbl1'],
      ['210205', id, '12', '121', 'UNIDAD 1', '20.00', '13',
        'EVIDENCIA DE PRODUCTO', '100.00', '14.00', ' ', 'tbl1'],
      [' ', id, '12', '121', 'UNIDAD 1', '20.00', '11',
        'EVIDENCIA DE CONOCIMIENTO', '100.00', '15.00', ' ', 'tbl2'],
      [' ', id, '12', '121', 'UNIDAD 1', '20.00', ' ', ' ', ' ',
        '14.33', ' ', 'tbl3'],
      [' ', id, ' ', ' ', ' ', ' ', ' ', ' ', ' ', '14.00', ' ', 'tbl4'],
      [' ', id, ' ', ' ', 'SUSTITUTORIO', ' ', ' ', ' ', ' ', ' ', ' ',
        'tbl5'],
      [' ', id, ' ', ' ', ' ', ' ', ' ', ' ', ' ', '3.00', 'Dsp.', 'tbl6'],
    ]);
    expect(det.unidades.length, 1);
    final u = det.unidades.first;
    expect(u.nombre, 'UNIDAD 1');
    expect(u.peso, 20.0);
    expect(u.evidencias.length, 3);
    expect(u.evidencias.first.tipo, 'EVIDENCIA DE CONOCIMIENTO');
    expect(u.evidencias.first.notaText, '15');
    expect(u.promedioText, '14.33');
    expect(det.promedioFinalText, '3');
    expect(det.estado, 'Dsp.');
    expect(det.tieneSustitutorio, false);
  });

  test('Fmt.parseAula y Fmt.formatAula procesan correctamente "I 302" y otros formatos', () {
    final parsed = Fmt.parseAula('I 302');
    expect(parsed['pabellon'], 'I');
    expect(parsed['aula'], '302');

    final parsedSingle = Fmt.parseAula('Virtual');
    expect(parsedSingle['pabellon'], null);
    expect(parsedSingle['aula'], 'Virtual');

    final parsedEmpty = Fmt.parseAula('   ');
    expect(parsedEmpty['pabellon'], null);
    expect(parsedEmpty['aula'], null);

    final parsedLab = Fmt.parseAula('LABORATORIO DE COMPUTO 4');
    expect(parsedLab['pabellon'], null);
    expect(parsedLab['aula'], 'LABORATORIO DE COMPUTO 4');

    expect(Fmt.formatAula('I 302'), 'Pab. I - Aula 302');
    expect(Fmt.formatAula('LABORATORIO DE COMPUTO 4'), 'LABORATORIO DE COMPUTO 4');
    expect(Fmt.formatAula('Virtual'), 'Virtual');
    expect(Fmt.formatAula(''), '—');
  });

  testWidgets('SupportScreen renders and handles tapping contact options safely', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('es'),
        home: SupportScreen(),
      ),
    );

    expect(find.text('Soporte Técnico'), findsOneWidget);
    expect(find.text('¿Tienes algún problema?'), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.text('Correo Electrónico'), findsOneWidget);

    // Tap WhatsApp option
    await tester.tap(find.text('WhatsApp'));
    await tester.pumpAndSettle();

    // Tap Email option
    await tester.tap(find.text('Correo Electrónico'));
    await tester.pumpAndSettle();

    // Since we're in a widget test and url_launcher is not mocked,
    // they should fail gracefully via the try-catch block and copy the text
    // to the clipboard, rather than throwing uncaught PlatformExceptions.
  });
}
