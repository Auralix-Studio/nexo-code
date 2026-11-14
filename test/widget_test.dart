import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/domain/models.dart';
import 'package:nexo/domain/unified_models.dart';
import 'package:nexo/features/legal/support_screen.dart';
import 'package:nexo/l10n/app_localizations.dart';
import 'package:nexo/shared/util/formatters.dart';

void main() {
  test('Payment.daysUntilDue calcula días correctamente', () {
    const p = Payment(
      description: 'Cuota 02',
      currency: 'S/.',
      amount: 522.5,
      lateFee: 0,
      total: 522.5,
      note: '',
      dueDateRaw: '20-05-2026',
    );
    final now = DateTime(2026, 5, 14);
    expect(p.daysUntilDue(now), 6);
  });

  test('ScheduleClass decodifica campos clave', () {
    final c = ScheduleClass.fromSigmaJson({
      'id': '331131',
      'asignatura': 'ANTROPOLOGÍA',
      'idDia': 4,
      'horaInicio': '13:45',
      'horaFin': '15:15',
      'aula': 'I 304',
      'teacher': 'MEZA VARGAS ZENAIDA',
      'idTipo': 'T',
    });
    expect(c.subject, 'ANTROPOLOGÍA');
    expect(c.typeName, 'Teoría');
    expect(c.weekday, 4);
  });

  test('CourseGrade parsea ambos parciales con su capitalización real', () {
    // Caso real de SIGMA: campos en minúscula para el firstTerm parcial
    // y prefijo "_2" + Nta capitalizado para el secondTerm.
    final n = CourseGrade.fromJson({
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
    expect(n.currentGradeNum, 11);
    expect(n.currentGradeText, '11.00');
    expect(n.isApproved, true);
    expect(n.asistenciaPct, 100);
    expect(n.pF1, '09');
    expect(n.pF2, '13');

    expect(n.firstTerm.practices, ['15', '12', '15', '']);
    expect(n.firstTerm.practicesAverage, '14.00');
    expect(n.firstTerm.researchWork, '15');
    expect(n.firstTerm.researchProjectAverage, '14.50');
    expect(n.firstTerm.exam, '3');

    expect(n.secondTerm.practices, ['13', '14', '', '']);
    expect(n.secondTerm.practicesAverage, '13.50');
    expect(n.secondTerm.exam, '13');
    expect(n.secondTerm.isEmpty, false);
  });

  test('formatGrade maneja decimales', () {
    expect(formatGrade('14.00'), '14.00');
    expect(formatGrade('14.50'), '14.50');
    expect(formatGrade('15'), '15.00');
    expect(formatGrade('  '), '—');
    expect(formatGrade('--'), '—');
    expect(parseGrade('14,5'), 14.5);
  });

  test(
    'Fmt.parseAula y Fmt.formatAula procesan correctamente "I 302" y otros formatos',
    () {
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

      expect(Fmt.formatAula('I 302'), 'Pabellón I - Aula 302');
      expect(
        Fmt.formatAula('LABORATORIO DE COMPUTO 4'),
        'Laboratorio - DE COMPUTO 4',
      );
      expect(Fmt.formatAula('Virtual'), 'Virtual');
      expect(Fmt.formatAula(''), '—');
    },
  );

  testWidgets(
    'SupportScreen renders and handles tapping contact options safely',
    (tester) async {
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
    },
  );
}
