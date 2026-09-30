import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nexo/core/error_handler.dart';
import 'package:nexo/core/secret_store.dart';
import 'package:nexo/core/storage.dart';
import 'package:nexo/data/app_store.dart';
import 'package:nexo/data/cache_manager.dart';
import 'package:nexo/data/connectivity_service.dart';
import 'package:nexo/data/sigma_repository.dart';
import 'package:nexo/domain/models.dart';
import 'package:nexo/domain/unified_models.dart';

class _Network extends Fake implements Connectivity {
  _Network({this.fail = false});
  final bool fail;
  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      const Stream.empty();
  @override
  Future<List<ConnectivityResult>> checkConnectivity() async {
    if (fail) throw StateError('plugin unavailable');
    return [ConnectivityResult.wifi];
  }
}

class _Repo extends Fake implements SigmaRepository {}

class _Cache extends Fake implements CacheManager {}

class _Handler extends Fake implements ErrorHandler {}

class _Store extends AppStore {
  _Store(ConnectivityService connection)
    : super(
        _Repo(),
        cache: _Cache(),
        errorHandler: _Handler(),
        connectivity: connection,
      );
  final periodsReady = Completer<List<Term>?>();
  final paymentsReady = Completer<List<Payment>?>();
  final idiomasReady = Completer<void>();
  final summaryStarted = Completer<void>();
  final boletaStarted = Completer<void>();
  int periodCalls = 0;
  bool profileStarted = false;
  @override
  Future<List<Term>?> loadPeriodos() {
    periodCalls++;
    return periodsReady.future;
  }

  @override
  Future<Student?> loadProfile() async {
    profileStarted = true;
    const student = Student(
      id: 'test',
      fullName: '',
      career: '',
      faculty: '',
      campus: '',
      level: '1',
      studyPlan: 'plan',
      modality: '',
      isEnrolled: true,
    );
    profile = const AsyncValue.data(student);
    return student;
  }

  @override
  Future<List<ScheduleClass>?> loadHorarioActual() async => [];
  @override
  Future<List<Payment>?> loadCuotasPendientes() => paymentsReady.future;
  @override
  Future<List<TermAverage>?> loadPromedios() async => [];
  @override
  Future<void> loadIdiomasMatricula() => idiomasReady.future;
  @override
  Future<GradesSummary?> loadResumen(String plan, String level) async {
    summaryStarted.complete();
    return null;
  }

  @override
  Future<void> checkActiveBoleta() async {
    boletaStarted.complete();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('network readiness does not wait for slow server diagnostics', () async {
    final response = Completer<http.Response>();
    final connection = ConnectivityService(
      connectivity: _Network(),
      httpClient: MockClient((_) => response.future),
    );
    addTearDown(connection.dispose);
    final start = connection.start();
    await connection.networkReady.timeout(const Duration(seconds: 1));
    expect(connection.hasInternet, isTrue);
    expect(connection.firstCheckCompleted, isFalse);
    response.complete(http.Response('', 200));
    await start;
    expect(connection.firstCheckCompleted, isTrue);
  });

  test('plugin failure releases startup waiters', () async {
    final connection = ConnectivityService(connectivity: _Network(fail: true));
    addTearDown(connection.dispose);
    await expectLater(connection.start(), throwsStateError);
    await connection.networkReady.timeout(const Duration(seconds: 1));
    await connection.firstCheckDone.timeout(const Duration(seconds: 1));
  });

  test('academic data waits for period, not payments or languages', () async {
    SharedPreferences.setMockInitialValues({});
    await AppStorage.init(secrets: MemorySecretStore());
    final connection = ConnectivityService();
    final store = _Store(connection);
    addTearDown(connection.dispose);
    addTearDown(store.dispose);
    final first = store.loadHomeEssentials();
    final duplicate = store.loadHomeEssentials();
    expect(store.periodCalls, 1);
    expect(store.profileStarted, isFalse);
    expect(store.boletaStarted.isCompleted, isFalse);
    store.periodsReady.complete([]);
    await store.summaryStarted.future.timeout(const Duration(seconds: 1));
    await store.boletaStarted.future.timeout(const Duration(seconds: 1));
    expect(store.paymentsReady.isCompleted, isFalse);
    expect(store.idiomasReady.isCompleted, isFalse);
    store.paymentsReady.complete([]);
    store.idiomasReady.complete();
    await Future.wait([first, duplicate]);
  });
}
