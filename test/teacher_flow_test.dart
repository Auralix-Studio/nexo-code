import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexo/core/error_handler.dart';
import 'package:nexo/core/secret_store.dart';
import 'package:nexo/core/storage.dart';
import 'package:nexo/data/app_store.dart';
import 'package:nexo/data/local/cache_manager.dart';
import 'package:nexo/data/remote/backend_client.dart';
import 'package:nexo/data/repositories/nexo_repository.dart';
import 'package:nexo/data/repositories/nexo_teacher_repository.dart';
import 'package:nexo/data/services/connectivity_service.dart';
import 'package:nexo/data/services/directory_service.dart';
import 'package:nexo/domain/models.dart';
import 'package:nexo/domain/unified_models.dart';
import 'package:nexo/features/teacher/courses/teacher_course_detail.dart';
import 'package:nexo/features/teacher/teacher_screen.dart';
import 'package:nexo/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_nexo_api.dart';

class _Cache extends Fake implements CacheManager {
  @override
  Future<void> saveDocenteAlumnos(String id, List<TeacherStudent> a) async {}
  @override
  Future<List<TeacherStudent>?> getDocenteAlumnos(String id) async => null;
  @override
  Future<void> saveDocenteCursos(List<TeacherSubject> c) async {}
  @override
  Future<List<TeacherSubject>?> getDocenteCursos() async => null;
  @override
  Future<void> saveDocenteInfo(TeacherInfo info) async {}
  @override
  Future<TeacherInfo?> getDocenteInfo() async => null;
  @override
  Future<void> saveDocenteHorario(List<ScheduleClass> c) async {}
  @override
  Future<List<ScheduleClass>?> getDocenteHorario() async => null;
}

class _Handler extends Fake implements ErrorHandler {
  @override
  Future<T> withFallback<T>({
    required Future<T> Function() remote,
    required Future<T?> Function() cached,
    required String operationName,
  }) => remote();
}

/// Una sección de `GET /teaching/sections`.
const sectionJson = <String, dynamic>{
  'id': 'sec_1',
  'term': '2026-2',
  'nrc': '332142',
  'course': {'code': '332142', 'name': 'BASE DE DATOS I (2026-2)'},
  'section': 'A1',
  'career': 'INGENIERÍA DE SISTEMAS Y COMPUTACIÓN',
  'modality': 'in_person',
  'cycle': 4,
  'elective': false,
  'enrolled': 3,
  'campus': 'HUANCAYO',
  'room': {'building': 'PABELLON H', 'name': 'H 302', 'capacity': 60},
  'schedule': [
    {'weekday': 4, 'start': '11:30', 'end': '13:00', 'kind': 'practice'},
    {'weekday': 3, 'start': '10:45', 'end': '11:30', 'kind': 'theory'},
  ],
};

/// API de Nexo simulada (`/teaching/*`) con las formas del contrato.
/// Guarda cada escritura por `MÉTODO ruta`.
class _FakeNexo {
  final writes = <String, List<Map<String, dynamic>>>{};
  final gets = <String, int>{};

  Map<String, dynamic> _student(
    String code,
    String name, {
    double? ev,
    int att = 100,
  }) => {
    'code': code,
    'name': name,
    'attendance_percent': att,
    'final_grade': ev,
    'suspended': false,
    'units': [
      {
        'unit_id': 121,
        'name': 'UNIDAD 1',
        'weight_percent': 20,
        'average': ev,
        'evaluations': [
          if (ev != null)
            {
              'type_id': 11,
              'abbr': 'EV',
              'weight_percent': 100,
              'grades': [ev],
            },
        ],
      },
    ],
  };

  Future<http.Response> handle(http.Request req) async {
    final path = req.url.path;
    if (req.method != 'GET') {
      writes
          .putIfAbsent('${req.method} $path', () => [])
          .add(
            req.body.isEmpty
                ? const {}
                : (jsonDecode(req.body) as Map).cast<String, dynamic>(),
          );
      return nexoOk({'saved': 1, 'failed': []});
    }
    gets[path] = (gets[path] ?? 0) + 1;
    final data = switch (path) {
      '/teaching/sections' => [sectionJson],
      '/teaching/me' => {
        'code': '46996068',
        'first_name': 'JOHN',
        'last_name': 'GUERRA FLORES',
        'full_name': 'JOHN GUERRA FLORES',
        'faculty': 'FACULTAD DE INGENIERÍA',
        'specialty': null,
        'photo_url': null,
      },
      '/teaching/punches' || '/teaching/compliance' => const [],
      '/teaching/virtual-classes' => const [],
      '/teaching/sections/sec_1/students' => {
        'students': [
          _student('U001', 'ALVAREZ PEREZ ANA LUCIA', ev: 14),
          _student('U002', 'BENITO ROJAS BRUNO', att: 65),
          _student('U003', 'CASTRO DIAZ CARLA'),
        ],
      },
      '/teaching/sections/sec_1/attendance' => {
        'units': [
          {'unit_id': 121, 'name': 'UNIDAD 1', 'open': true},
          {'unit_id': 122, 'name': 'UNIDAD 2', 'open': true},
        ],
        'sessions': [
          {'id': '2026-10-01T10:46:00', 'unit_id': 121},
        ],
        'students': [
          {
            'code': 'U001',
            'name': 'ALVAREZ PEREZ ANA LUCIA',
            'suspended': false,
            'percent': 100,
            'marks': [
              {'session': '2026-10-01T10:46:00', 'state': 'present'},
            ],
          },
          {
            'code': 'U002',
            'name': 'BENITO ROJAS BRUNO',
            'suspended': false,
            'percent': 50,
            'marks': [
              {'session': '2026-10-01T10:46:00', 'state': 'absent'},
            ],
          },
          {
            'code': 'U003',
            'name': 'CASTRO DIAZ CARLA',
            'suspended': true,
            'percent': 0,
            'marks': [],
          },
        ],
      },
      '/teaching/sections/sec_1/grade-units' => [
        for (final u in const [
          (121, 'UNIDAD 1', true),
          (122, 'UNIDAD 2', true),
          (123, 'UNIDAD 3', false),
        ])
          {
            'unit_id': u.$1,
            'name': u.$2,
            'open': u.$3,
            'types': [
              for (final t in const [
                (11, 'EV', 'EVIDENCIA DE CONOCIMIENTO'),
                (12, 'DE', 'EVIDENCIA DE DESEMPEÑO'),
                (13, 'PR', 'EVIDENCIA DE PRODUCTO'),
              ])
                {
                  'type_id': t.$1,
                  'abbr': t.$2,
                  'name': t.$3,
                  'max': 20,
                  'passing': 10.5,
                  'max_columns': 1,
                  'color': '#8CCD8C',
                },
            ],
          },
      ],
      '/teaching/server-time' => {'now': '2026-10-07T10:50:00-05:00'},
      _ => null,
    };
    if (data == null) return nexoError('not_found', 404);
    return nexoOk(data);
  }
}

void main() {
  final course = teacherSubjectFromNexo(sectionJson);

  late _FakeNexo nexo;
  late AppStore store;
  late ConnectivityService connection;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppStorage.init(secrets: MemorySecretStore());
    await AppStorage.instance.setCredentials('46996068', 'clave');
    nexo = _FakeNexo();
    final api = BackendClient(transport: MockClient(nexo.handle))
      ..setToken('t');
    connection = ConnectivityService();
    store = AppStore(
      NexoRepository(DirectoryService(client: api)),
      cache: _Cache(),
      errorHandler: _Handler(),
      connectivity: connection,
      scope: api.scope,
    );
  });

  tearDown(() {
    store.dispose();
    connection.dispose();
  });

  Future<void> pumpPhone(WidgetTester tester, {Widget? home}) async {
    await tester.binding.setSurfaceSize(const Size(360, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: home ?? TeacherCourseDetailScreen(store: store, course: course),
      ),
    );
    await settle(tester);
  }

  testWidgets('tomar asistencia en el celular envía las marcas a la API', (
    tester,
  ) async {
    await pumpPhone(tester);
    final l = AppLocalizations.of(
      tester.element(find.byType(TeacherCourseDetailScreen)),
    );
    expect(tester.takeException(), isNull);
    // Historial de la pestaña Asistencia (más abajo en un celular con letra
    // grande).
    await tester.dragUntilVisible(
      find.text(l.tchSessionsTitle(1)),
      find.byType(ListView).first,
      const Offset(0, -150),
    );
    expect(find.text(l.tchSessionsTitle(1)), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, 2000));
    await settle(tester);

    await tester.tap(find.text(l.tchAttTake).first);
    await settle(tester);
    expect(tester.takeException(), isNull);
    // La suspendida no se marca; quedan 2 activos.
    expect(find.text(l.tchAttProgress(0, 2)), findsOneWidget);

    await tester.tap(find.text(l.tchAttAllPresent));
    await settle(tester);
    await tester.tap(find.byTooltip(l.tchStateAbsent).at(1));
    await settle(tester);
    expect(find.text(l.tchAttProgress(2, 2)), findsOneWidget);

    // Pase de lista uno por uno también cabe en pantalla.
    await tester.tap(find.byTooltip(l.tchAttModeOneByOne));
    await settle(tester);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip(l.tchAttModeList));
    await settle(tester);

    await tester.tap(find.text(l.docenteSaveAttendance));
    await settle(tester);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text(l.tchAttRegister));
    await settle(tester);

    final body =
        nexo.writes['POST /teaching/sections/sec_1/attendance']!.single;
    // La hora la pone el reloj de la universidad en el backend.
    expect(body.containsKey('date'), isFalse);
    expect(body['unit_id'], 121);
    final marks = {
      for (final m in body['marks'] as List) m['student']: m['state'],
    };
    expect(marks['U001'], 'present');
    expect(marks['U002'], 'absent');
    // La suspendida va como presente: el backend la registra suspendida.
    expect(marks['U003'], anyOf(isNull, 'present'));
  });

  testWidgets('corregir una sesión pasada solo permite falta/justificado', (
    tester,
  ) async {
    await pumpPhone(tester);
    final l = AppLocalizations.of(
      tester.element(find.byType(TeacherCourseDetailScreen)),
    );
    // Sin `.first`: el finder se evalúa mientras la fila aún no existe.
    await tester.dragUntilVisible(
      find.byIcon(Icons.chevron_right_rounded),
      find.byType(ListView).first,
      const Offset(0, -200),
    );
    await settle(tester);
    await tester.tap(find.byIcon(Icons.chevron_right_rounded).first);
    await settle(tester);
    expect(tester.takeException(), isNull);
    // Sesión pasada: no se ofrece "Asistió".
    expect(find.byTooltip(l.tchStatePresent), findsNothing);
    await tester.tap(find.byTooltip(l.tchStateJustified).at(1));
    await settle(tester);
    await tester.tap(find.text(l.tchSaveChanges(1)));
    await settle(tester);
    await tester.tap(find.text(l.actionSave).last);
    await settle(tester);
    final body = nexo
        .writes['PATCH /teaching/sections/sec_1/attendance/2026-10-01T10:46:00']!
        .single;
    expect(body, {
      'marks': [
        {'student': 'U002', 'state': 'justified'},
      ],
    });
  });

  testWidgets('registrar una evaluación: nuevas y corregidas en un envío', (
    tester,
  ) async {
    await pumpPhone(tester);
    final l = AppLocalizations.of(
      tester.element(find.byType(TeacherCourseDetailScreen)),
    );
    await tester.tap(find.text(l.docenteTabNotas));
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('EVIDENCIA DE CONOCIMIENTO'), findsOneWidget);

    await tester.tap(find.text('EVIDENCIA DE CONOCIMIENTO'));
    await settle(tester);
    expect(tester.takeException(), isNull);
    final fields = find.byType(TextField);
    // [0] buscador, luego un campo por alumno en orden alfabético.
    await tester.enterText(fields.at(1), '16');
    await tester.enterText(fields.at(2), '12,5');
    await tester.enterText(fields.at(3), '25');
    await settle(tester);
    await tester.tap(find.text(l.tchSaveChanges(2)));
    await settle(tester);
    // La nota fuera de rango bloquea el guardado.
    expect(nexo.writes, isEmpty);
    // Esperar a que se oculte el aviso de error, que tapa el botón.
    await tester.pump(const Duration(seconds: 6));
    await settle(tester);
    await tester.enterText(fields.at(3), '9');
    await settle(tester);
    await tester.tap(find.text(l.tchSaveChanges(3)));
    await settle(tester);
    await tester.tap(find.text(l.actionSave).last);
    await settle(tester);

    final body = nexo.writes['PUT /teaching/sections/sec_1/grades']!.single;
    expect((body['unit_id'], body['type_id']), (121, 11));
    final grades = {
      for (final g in body['grades'] as List)
        g['student']: (g['value'], g['column']),
    };
    // U001 ya tenía nota en la columna 0: se corrige esa columna.
    expect(grades, {
      'U001': (16.0, 0),
      'U002': (12.5, null),
      'U003': (9.0, null),
    });
  });

  testWidgets('reporte de asistencia y notas sin desbordes', (tester) async {
    await pumpPhone(tester);
    final l = AppLocalizations.of(
      tester.element(find.byType(TeacherCourseDetailScreen)),
    );
    await tester.tap(find.text(l.docenteTabReporte));
    await settle(tester);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text(l.docenteTabNotas).last);
    await settle(tester);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text(l.docenteTabAlumnos));
    await settle(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tablero: agenda, pendientes y conteo sin desbordes', (
    tester,
  ) async {
    // Miércoles 14 de octubre, 11:05: BD I (10:45–11:30) en curso.
    await pumpPhone(
      tester,
      home: Scaffold(
        body: TeacherScreen(
          store: store,
          clock: () => DateTime(2026, 10, 14, 11, 5),
        ),
      ),
    );
    await settle(tester);
    final l = AppLocalizations.of(tester.element(find.byType(TeacherScreen)));
    expect(tester.takeException(), isNull);
    // Una sola carga de secciones: el horario sale de ellas.
    expect(nexo.gets['/teaching/sections'], 1);
    expect(find.text('John'), findsOneWidget);
    expect(find.text(l.tchAgendaTitle), findsOneWidget);
    expect(find.text(l.tchPhaseOngoing), findsOneWidget);
    // Alumnos distintos contados de los rosters.
    expect(find.text('3'), findsWidgets);

    await tester.dragUntilVisible(
      find.text(l.tchAlertsRow(1)),
      find.byType(CustomScrollView),
      const Offset(0, -200),
    );
    await settle(tester);
    // El miércoles 7 quedó sin asistencia; el jueves 8 fue feriado.
    expect(find.text(l.tchMissingCount(1)), findsOneWidget);
    expect(find.text(l.tchAlertsCriticalCount(1)), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text(l.tchAlertsRow(1)));
    await settle(tester);
    expect(find.text('BENITO ROJAS BRUNO'), findsOneWidget);
    expect(find.text(l.tchAlertAttCritical(65)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lo marcado en la lista se recupera al volver a entrar', (
    tester,
  ) async {
    await pumpPhone(tester);
    final l = AppLocalizations.of(
      tester.element(find.byType(TeacherCourseDetailScreen)),
    );
    await tester.tap(find.text(l.tchAttTake).first);
    await settle(tester);
    await tester.tap(find.byTooltip(l.tchStateAbsent).at(1));
    await settle(tester);
    expect(find.text(l.tchAttProgress(1, 2)), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await settle(tester);

    await tester.tap(find.text(l.tchAttTake).first);
    await settle(tester);
    expect(find.text(l.tchDraftRestored), findsOneWidget);
    expect(find.text(l.tchAttProgress(1, 2)), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text(l.tchDraftDiscard));
    await settle(tester);
    expect(find.text(l.tchAttProgress(0, 2)), findsOneWidget);
  });

  testWidgets('pegar notas desde Excel llena la lista y se guarda', (
    tester,
  ) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => call.method == 'Clipboard.getData'
          ? {'text': 'CODIGO\tNOTA\nU003\t8,5\nU002\t13\n'}
          : null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pumpPhone(tester);
    final l = AppLocalizations.of(
      tester.element(find.byType(TeacherCourseDetailScreen)),
    );
    await tester.tap(find.text(l.docenteTabNotas));
    await settle(tester);
    await tester.tap(find.text('EVIDENCIA DE CONOCIMIENTO'));
    await settle(tester);
    await tester.tap(find.byTooltip(l.tchPasteAction));
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text(l.tchPasteByCode(2)), findsOneWidget);
    await tester.tap(find.text(l.tchPasteApply));
    await settle(tester);
    await tester.pump(const Duration(seconds: 6));
    await settle(tester);
    await tester.tap(find.text(l.tchSaveChanges(2)));
    await settle(tester);
    await tester.tap(find.text(l.actionSave).last);
    await settle(tester);
    final body = nexo.writes['PUT /teaching/sections/sec_1/grades']!.single;
    expect(
      {for (final g in body['grades'] as List) g['student']: g['value']},
      {'U002': 13.0, 'U003': 8.5},
    );
  });

  testWidgets('tabla de notas de la sección sin desbordes', (tester) async {
    await pumpPhone(tester);
    final l = AppLocalizations.of(
      tester.element(find.byType(TeacherCourseDetailScreen)),
    );
    await tester.tap(find.text(l.docenteTabNotas));
    await settle(tester);
    await tester.tap(find.text(l.tchViewGrid));
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text(l.tchGridFinal), findsOneWidget);
    expect(find.text('U1'), findsOneWidget);
    expect(find.text('EV'), findsOneWidget);
  });

  testWidgets(
    'borrador de notas se guarda al escribir, se muestra y descarta',
    (tester) async {
      await pumpPhone(tester);
      final l = AppLocalizations.of(
        tester.element(find.byType(TeacherCourseDetailScreen)),
      );
      await tester.tap(find.text(l.docenteTabNotas));
      await settle(tester);
      await tester.tap(find.text('EVIDENCIA DE CONOCIMIENTO'));
      await settle(tester);

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(1), '18');
      await tester.enterText(fields.at(2), '15');
      await settle(tester);
      expect(find.text(l.tchSaveChanges(2)), findsOneWidget);
      expect(find.text(l.tchGradeSaveDraft), findsOneWidget);

      await tester.tap(find.text(l.tchGradeSaveDraft));
      await settle(tester);
      expect(nexo.writes, isEmpty);
      // La tarjeta de la evaluación muestra el aviso de borrador pendiente.
      expect(find.text(l.tchGradeDraftBadge(2)), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 6));
      await settle(tester);

      await tester.tap(find.text('EVIDENCIA DE CONOCIMIENTO'));
      await settle(tester);
      expect(find.text(l.tchDraftRestored), findsOneWidget);
      expect(find.text(l.tchSaveChanges(2)), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text(l.tchDraftDiscard));
      await settle(tester);
      expect(find.text(l.tchDraftRestored), findsNothing);
      expect(find.text(l.tchSaveChanges(2)), findsNothing);

      await tester.tap(find.byType(BackButton));
      await settle(tester);
      expect(find.text(l.tchGradeDraftBadge(2)), findsNothing);

      // Unidad cerrada en la universidad (UNIDAD 3): permite guardar borrador.
      await tester.ensureVisible(find.text('UNIDAD 3'));
      await tester.tap(find.text('UNIDAD 3'));
      await settle(tester);
      await tester.tap(find.text('EVIDENCIA DE CONOCIMIENTO'));
      await settle(tester);
      expect(find.text(l.tchGradeLockedDraftHint), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(1), '17');
      await settle(tester);
      await tester.tap(find.text(l.tchGradeSaveDraft));
      await settle(tester);
      expect(find.text(l.tchGradeDraftBadge(1)), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

/// Avanza animaciones y peticiones simuladas sin esperar a que terminen las
/// animaciones infinitas (esqueletos, indicadores).
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}
