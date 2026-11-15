import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/data/app_store.dart';
import 'package:nexo/data/local/cache_manager.dart';
import 'package:nexo/core/error_handler.dart';
import 'package:nexo/data/services/connectivity_service.dart';
import 'package:nexo/data/repositories/nexo_repository.dart';
import 'package:nexo/domain/idiomas_models.dart';
import 'package:nexo/domain/unified_models.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:nexo/core/storage.dart';
import 'package:nexo/core/secret_store.dart';

class FakeNexoRepository extends Fake implements NexoRepository {}

class FakeCacheManager extends Fake implements CacheManager {}

class FakeErrorHandler extends Fake implements ErrorHandler {}

class FakeConnectivityService extends Fake implements ConnectivityService {}

void main() {
  group('AppStore Idiomas Integration', () {
    late AppStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await AppStorage.init(secrets: MemorySecretStore());
      store = AppStore(
        FakeNexoRepository(),
        cache: FakeCacheManager(),
        errorHandler: FakeErrorHandler(),
        connectivity: FakeConnectivityService(),
      );
    });

    test('filtra cursos de idiomas vigentes (mes y año actual)', () {
      final now = DateTime.now();
      store.idiomasMatricula = AsyncValue.data([
        // Curso antiguo
        IdiomasCourse(
          estNombres: 'JUAN',
          estPaterno: 'PEREZ',
          estMaterno: 'G',
          asigId: 'ING001',
          asignatura: 'INGLES',
          dias: 'LU-MI',
          horaInicio: '08:00',
          horaFin: '09:30',
          aula: '101',
          aulaNombre: 'AULA',
          detMatriculaId: 1,
          modalidad: 'V',
          idiomaNombre: 'INGLES',
          seccion: 'A',
          anio: now.year - 1, // Año anterior
          mes: now.month,
          tipoEstudio: 'REGULAR',
          turno: 'MAÑANA',
          capacidad: 30,
          cantidad: 20,
          fechRegistro: '2025',
          promedio: 15,
        ),
        // Curso vigente
        IdiomasCourse(
          estNombres: 'JUAN',
          estPaterno: 'PEREZ',
          estMaterno: 'G',
          asigId: 'ING002',
          asignatura: 'INGLES II',
          dias: 'MA-JU',
          horaInicio: '10:00',
          horaFin: '11:30',
          aula: '102',
          aulaNombre: 'AULA',
          detMatriculaId: 2,
          modalidad: 'V',
          idiomaNombre: 'INGLES',
          seccion: 'A',
          anio: now.year,
          mes: now.month, // Mes y año actual
          tipoEstudio: 'REGULAR',
          turno: 'MAÑANA',
          capacidad: 30,
          cantidad: 20,
          fechRegistro: '2026',
          promedio: 16,
        ),
      ]);

      final vigentes = store.idiomasVigentes;
      expect(vigentes, hasLength(1));
      expect(vigentes.first.asigId, 'ING002');
    });

    test('schedule es el de /schedule: no combina /languages', () {
      const idiomas = ScheduleClass(
        id: 'ING_NEW',
        nrc: '',
        subject: 'INGLES NUEVO',
        modality: 'VIRTUAL',
        section: 'A',
        level: '',
        campus: 'VIRTUAL',
        building: '',
        room: '2',
        note: '',
        teacher: 'Centro de Idiomas',
        weekday: 2,
        dayName: 'MA',
        startTime: '10:00',
        endTime: '11:30',
        typeCode: 'I',
      );
      store.setBaseScheduleForTesting(
        const AsyncValue.data([
          ScheduleClass(
            id: 'SIGMA1',
            nrc: '123',
            subject: 'MATEMATICA',
            modality: 'P',
            section: 'A',
            level: '1',
            campus: 'HYO',
            building: 'PAB',
            room: '101',
            note: '',
            teacher: 'PROFE',
            weekday: 1,
            dayName: 'LUNES',
            startTime: '08:00',
            endTime: '09:30',
            typeCode: 'T',
          ),
          idiomas,
        ]),
      );
      final now = DateTime.now();
      store.idiomasMatricula = AsyncValue.data([
        IdiomasCourse(
          estNombres: 'JUAN',
          estPaterno: 'P',
          estMaterno: 'G',
          asigId: 'ING_OTHER',
          asignatura: 'INGLES OTRO',
          dias: 'JU',
          horaInicio: '10:00',
          horaFin: '11:30',
          aula: '2',
          aulaNombre: '2',
          detMatriculaId: 2,
          modalidad: 'V',
          idiomaNombre: 'INGLES',
          seccion: 'A',
          anio: now.year,
          mes: now.month,
          tipoEstudio: 'REGULAR',
          turno: 'MAÑANA',
          capacidad: 30,
          cantidad: 20,
          fechRegistro: '2026',
          promedio: 15,
        ),
      ]);

      final schedule = store.schedule.value!;
      expect(schedule.map((c) => c.id), ['SIGMA1', 'ING_NEW']);
    });
  });
}
