import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexo/core/secret_store.dart';
import 'package:nexo/core/storage.dart';
import 'package:nexo/data/app_store.dart';
import 'package:nexo/data/connectivity_service.dart';
import 'package:nexo/data/home_widget_service.dart';
import 'package:nexo/domain/unified_models.dart';
import 'package:nexo/shared/util/formatters.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Network extends Fake implements Connectivity {
  final changes = StreamController<List<ConnectivityResult>>(sync: true);

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => changes.stream;

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => [
    ConnectivityResult.wifi,
  ];
}

class _EmptyStore extends Fake implements AppStore {
  @override
  AsyncValue<List<ScheduleClass>> get schedule => const AsyncValue.data([]);
  @override
  AsyncValue<List<Payment>> get pendingInstallments =>
      const AsyncValue.data([]);
  @override
  double? get promedioAcumulado => null;
  @override
  int? get approvedCredits => null;
  @override
  int? get totalCredits => null;
}

class _TrackedClient extends MockClient {
  _TrackedClient(super.handler);
  bool closed = false;
  @override
  void close() {
    closed = true;
    super.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('currency carries rounded cents into the integer part', () {
    expect(Fmt.currency(1.999), 'S/ 2.00');
    expect(Fmt.currency(999.999), 'S/ 1,000.00');
    expect(Fmt.currency(-1.999), '-S/ 2.00');
    expect(Fmt.currency(12.5), 'S/ 12.50');
  });

  test('all Android widgets use the actual Kotlin package', () async {
    SharedPreferences.setMockInitialValues({});
    await AppStorage.init(secrets: MemorySecretStore());
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    const channel = MethodChannel('home_widget');
    final calls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return true;
    });
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      messenger.setMockMethodCallHandler(channel, null);
    });

    await HomeWidgetService().sync(_EmptyStore());

    final providers = calls
        .where((call) => call.method == 'updateWidget')
        .map((call) => (call.arguments as Map)['qualifiedAndroidName']);
    expect(
      providers,
      unorderedEquals([
        'pro.aurx.nexo.NextClassWidgetProvider',
        'pro.aurx.nexo.TodayWidgetProvider',
        'pro.aurx.nexo.PaymentWidgetProvider',
        'pro.aurx.nexo.AcademicWidgetProvider',
      ]),
    );
  });

  test('a late health check cannot undo a network disconnect', () async {
    final network = _Network();
    final response = Completer<http.Response>();
    final connection = ConnectivityService(
      connectivity: network,
      httpClient: MockClient((_) => response.future),
    );
    addTearDown(connection.dispose);
    addTearDown(network.changes.close);

    final start = connection.start();
    await connection.networkReady;
    network.changes.add([ConnectivityResult.none]);
    expect(connection.hasInternet, isFalse);
    response.complete(http.Response('', 200));
    await start;

    expect(connection.hasInternet, isFalse);
    expect(connection.sigmaStatus, ServerStatus.offline);
  });

  test('disposing during a check preserves the shared HTTP client', () async {
    final network = _Network();
    final response = Completer<http.Response>();
    final client = _TrackedClient((_) => response.future);
    final connection = ConnectivityService(
      connectivity: network,
      httpClient: client,
    );
    addTearDown(network.changes.close);
    addTearDown(client.close);
    final start = connection.start();
    await connection.networkReady;
    connection.dispose();
    response.complete(http.Response('', 200));

    await expectLater(start, completes);
    expect(client.closed, isFalse);
  });
}
