import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexo/core/error_handler.dart';
import 'package:nexo/core/secret_store.dart';
import 'package:nexo/core/storage.dart';
import 'package:nexo/data/api_client.dart';
import 'package:nexo/data/app_store.dart';
import 'package:nexo/data/cache_manager.dart';
import 'package:nexo/data/connectivity_service.dart';
import 'package:nexo/data/sigma_repository.dart';
import 'package:nexo/data/teacher_repository.dart';
import 'package:nexo/domain/models.dart';
import 'package:nexo/domain/unified_models.dart';
import 'package:nexo/features/teacher/teacher_course_detail.dart';
import 'package:nexo/features/teacher/teacher_screen.dart';
import 'package:nexo/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Repository extends Fake implements SigmaRepository {}

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

const notasRow = <String, dynamic>{
  'id': '1365838',
  'nrc': '332142',
  'asignatura': 'BASE DE DATOS I (2026-2)',
  'carrera': 'INGENIERÍA DE SISTEMAS Y COMPUTACIÓN',
  'seccion': 'A1',
  'plan': '2022',
  'ciclo': '04',
  'tipoCalif': 12,
};

const asistenciaRow = <String, dynamic>{
  'id': '419329, 419321',
  'nrc': '332142',
  'asignatura': 'BASE DE DATOS I (2026-2)',
  'modalidad': 'Presencial',
  'carrera': 'INGENIERÍA DE SISTEMAS Y COMPUTACIÓN - PRESENCIAL',
  'seccion': 'A1',
  'aula': 'PABELLON H - H 302 - AFORO: 60',
  'horario': 'Jueves 11:30:00 13:00:00 P, Miércoles 10:45:00 11:30:00 T',
  'plan': '2022',
  'ciclo': '4',
  'tipoCalif': 12,
};

/// SIGMA simulado con las formas reales de las respuestas. Guarda cada POST.
class _FakeSigma {
  final posts = <String, List<Object?>>{};
  final gets = <String, int>{};

  static Map<String, dynamic> _ok(Object? data, [String msg = 'OK']) => {
    'success': true,
    'data': data,
    'mensaje': msg,
  };

  Map<String, dynamic> _student(
    String code,
    String name,
    String mat, {
    double? ev,
    String att = '100',
  }) => {
    'matriculaAsignaturaId': mat,
    'codigo': code,
    'nombreCompleto': name,
    'tipoCalificacion': 12,
    'asistencia': att,
    'notaFinal': ev ?? 0,
    'unidades': [
      {
        'unidadId': 121,
        'nombre': 'UNIDAD 1',
        'porcentaje': 20,
        'promedioUnidad': ev,
        'grupos': [
          if (ev != null)
            {
              'idTipoNota': 11,
              'tipoNotaAbr': 'EV',
              'peso': 100,
              'promedio': ev,
              'notas': [
                {'idNota': 5000 + code.hashCode % 100, 'valor': ev},
              ],
            },
        ],
      },
    ],
  };

  Future<http.Response> handle(http.Request req) async {
    final path = req.url.path.split('/api/').last;
    Object? body;
    if (req.method == 'POST') {
      body = req.body.isEmpty ? null : jsonDecode(req.body);
      posts.putIfAbsent(path, () => []).add(body ?? req.url.queryParameters);
      return http.Response(jsonEncode(_ok(null, 'S - Registro exitoso')), 200);
    }
    gets[path] = (gets[path] ?? 0) + 1;
    final data = switch (path) {
      'Docente/GetAsignaturaDocente' =>
        req.url.queryParameters['modo'] == 'Asistencia'
            ? [asistenciaRow]
            : [notasRow],
      'Login/GetDatosEntidad' => {
        'codigo': '46996068',
        'nombres': 'JOHN',
        'apellidos': ' GUERRA FLORES',
        'isDocente': true,
        'dependencia': {'facultad': 'FACULTAD DE INGENIERÍA'},
      },
      'Docente/getHistorialMarcacion' => const [],
      'Docente/NotasEstudianteResumenV1' => [
        _student('U001', 'ALVAREZ PEREZ ANA LUCIA', 'm1', ev: 14),
        _student('U002', 'BENITO ROJAS BRUNO', 'm2', att: '65'),
        _student('U003', 'CASTRO DIAZ CARLA', 'm3'),
      ],
      'Docente/GetAsistencia' => [
        {
          'codigo': 'U001',
          'nombreCompleto': 'ALVAREZ PEREZ ANA LUCIA',
          'observacion': '---',
          'matricula_asignatura_id': 'm1',
          'cod_cursal': '419329',
          'asistencia': 100,
          'detalle': [
            {
              'asistencia_id': 1,
              'fecha_asistencia': '2026-10-01T10:46:00',
              'estado_asist_id': 1,
              'tipo_unidad_id': 121,
            },
          ],
        },
        {
          'codigo': 'U002',
          'nombreCompleto': 'BENITO ROJAS BRUNO',
          'observacion': '---',
          'matricula_asignatura_id': 'm2',
          'cod_cursal': '419329',
          'asistencia': 50,
          'detalle': [
            {
              'asistencia_id': 2,
              'fecha_asistencia': '2026-10-01T10:46:00',
              'estado_asist_id': 2,
              'tipo_unidad_id': 121,
            },
          ],
        },
        {
          'codigo': 'U003',
          'nombreCompleto': 'CASTRO DIAZ CARLA',
          'observacion': 'Suspensión',
          'matricula_asignatura_id': 'm3',
          'cod_cursal': '419329',
          'asistencia': 0,
          'detalle': [],
        },
      ],
      'Asignatura/getTipoUnidadesV2' => [
        {'tipo_unidad_id': 121, 'descripcion': 'UNIDAD 1', 'habilitado': true},
        {'tipo_unidad_id': 122, 'descripcion': 'UNIDAD 2', 'habilitado': true},
        {'tipo_unidad_id': 123, 'descripcion': 'UNIDAD 3', 'habilitado': false},
      ],
      'Asignatura/getTipoNota' => [
        for (final t in const [
          (11, 'EV', 'EVIDENCIA DE CONOCIMIENTO'),
          (12, 'DE', 'EVIDENCIA DE DESEMPEÑO'),
          (13, 'PR', 'EVIDENCIA DE PRODUCTO'),
        ])
          {
            'tipo_nota_id': t.$1,
            'tipo_nota_abr': t.$2,
            'tipo_nota_desc': t.$3,
            'tipo_nota_escala': '0 - 20    ',
            'tipo_nota_cant_max': 1,
            'minimo_aprob': 10.5,
            'tipo_nota_color': '#8CCD8C',
          },
      ],
      'Docente/GetHora' => '2026-10-07T10:50:00.123-05:00',
      _ => null,
    };
    return http.Response.bytes(
      utf8.encode(jsonEncode(_ok(data))),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }
}

void main() {
  final course = TeacherRepository.mergeAsignaturas(
    [notasRow],
    [asistenciaRow],
  ).single;

  late _FakeSigma sigma;
  late AppStore store;
  late ConnectivityService connection;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppStorage.init(secrets: MemorySecretStore());
    sigma = _FakeSigma();
    final api = ApiClient(transport: MockClient(sigma.handle))..setToken('t');
    connection = ConnectivityService();
    store = AppStore(
      _Repository(),
      cache: _Cache(),
      errorHandler: _Handler(),
      connectivity: connection,
      teacher: TeacherRepository(api),
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

  testWidgets('tomar asistencia en el celular envía el payload de SIGMA', (
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
        sigma.posts['Docente/InsertaRegistroAsistencia']!.single
            as Map<String, dynamic>;
    expect(body['fecha_asistencia'], '2026-10-07 10:50:0');
    expect(body['asistencia'], [
      {
        'matricula_asignatura_id': 'm1',
        'estado_asist_id': 1,
        'cod_cursal': '419329',
        'tipo_unidad_id': 121,
      },
      {
        'matricula_asignatura_id': 'm2',
        'estado_asist_id': 2,
        'cod_cursal': '419329',
        'tipo_unidad_id': 121,
      },
      {
        'matricula_asignatura_id': 'm3',
        'estado_asist_id': 4,
        'cod_cursal': '419329',
        'tipo_unidad_id': 121,
      },
    ]);
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
    final body =
        sigma.posts['Docente/ActualizarRegistroAsistencia']!.single
            as Map<String, dynamic>;
    expect(body, {
      'asistencia': [
        {
          'asistencia_id': 2,
          'matricula_asignatura_id': 'm2',
          'estado_asist_id': 3,
        },
      ],
    });
  });

  testWidgets('registrar una evaluación inserta y actualiza por separado', (
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
    expect(sigma.posts, isEmpty);
    // Esperar a que se oculte el aviso de error, que tapa el botón.
    await tester.pump(const Duration(seconds: 6));
    await settle(tester);
    await tester.enterText(fields.at(3), '9');
    await settle(tester);
    await tester.tap(find.text(l.tchSaveChanges(3)));
    await settle(tester);
    await tester.tap(find.text(l.actionSave).last);
    await settle(tester);

    final ins =
        (sigma.posts['Docente/InsertarNotas']!.single
                as Map<String, dynamic>)['Notas']
            as List;
    expect(ins.map((e) => (e['matricula_asignatura_id'], e['nota'])), [
      ('m2', 12.5),
      ('m3', 9.0),
    ]);
    final upd =
        (sigma.posts['Docente/UpdateNota']!.single
                as Map<String, dynamic>)['Notas']
            as List;
    expect(upd.single['matricula_asignatura_id'], 'm1');
    expect(upd.single['nota'], 16.0);
    expect(upd.single['nota_id'], isNotNull);
    expect(upd.single['tipo_unidad_id'], 121);
    expect(upd.single['tipo_nota_id'], 11);
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
    // Una sola carga de asignaturas por modo: el horario sale de ellas.
    expect(sigma.gets['Docente/GetAsignaturaDocente'], 2);
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
    final ins =
        (sigma.posts['Docente/InsertarNotas']!.single
                as Map<String, dynamic>)['Notas']
            as List;
    expect(ins.map((e) => (e['matricula_asignatura_id'], e['nota'])), [
      ('m2', 13.0),
      ('m3', 8.5),
    ]);
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
}

/// Avanza animaciones y peticiones simuladas sin esperar a que terminen las
/// animaciones infinitas (esqueletos, indicadores).
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}
