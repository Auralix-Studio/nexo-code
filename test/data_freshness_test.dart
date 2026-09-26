import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nexo/core/data/resolver.dart';
import 'package:nexo/core/error_handler.dart';
import 'package:nexo/core/secret_store.dart';
import 'package:nexo/core/storage.dart';
import 'package:nexo/data/app_store.dart';
import 'package:nexo/data/cache_manager.dart';
import 'package:nexo/data/connectivity_service.dart';
import 'package:nexo/data/sigma_repository.dart';
import 'package:nexo/domain/unified_models.dart';
import 'package:nexo/l10n/app_localizations.dart';
import 'package:nexo/shared/widgets/data_status.dart';

class Repository extends Fake implements SigmaRepository {
  int calls = 0;
  Completer<List<TermAverage>>? pending;
  @override
  Future<List<TermAverage>> promediosResumen() async {
    calls++;
    return pending == null ? [] : await pending!.future;
  }
}

class Cache extends Fake implements CacheManager {
  int writes = 0;
  DateTime? stamp;
  @override
  Future<DateTime?> updatedAtFor(String operation) async => stamp;
  @override
  Future<List<TermAverage>?> getPromedios() async => [];
  @override
  Future<void> savePromedios(List<TermAverage> data) async {
    writes++;
  }

  @override
  Future<void> clearAll() async {}
}

class Connection extends Fake implements ConnectivityService {
  @override
  bool get firstCheckCompleted => true;
  @override
  bool get hasInternet => true;
}

class Handler extends Fake implements ErrorHandler {
  bool local = false;
  bool fail = false;
  @override
  Future<T> withFallback<T>({
    required Future<T> Function() remote,
    required Future<T?> Function() cached,
    required String operationName,
  }) async {
    if (fail) throw StateError('unavailable');
    return local ? (await cached())! : await remote();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Repository repo;
  late Cache cache;
  late Handler handler;
  late AppStore store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppStorage.init(secrets: MemorySecretStore());
    repo = Repository();
    cache = Cache();
    handler = Handler();
    store = AppStore(
      repo,
      cache: cache,
      errorHandler: handler,
      connectivity: Connection(),
    );
  });
  tearDown(() => store.dispose());

  test(
    'concurrent loads share the response; manual refresh still fetches',
    () async {
      repo.pending = Completer<List<TermAverage>>();
      final a = store.loadPromedios();
      final b = store.loadPromedios();
      expect(repo.calls, 1);
      repo.pending!.complete([]);
      await Future.wait([a, b]);
      expect(cache.writes, 1);
      expect(store.freshnessOf('loadPromedios')!.fromCache, isFalse);
      repo.pending = null;
      await store.loadPromedios();
      expect(repo.calls, 2);
    },
  );

  test(
    'fallback preserves the original date and never rewrites cached data',
    () async {
      await store.loadPromedios();
      final original = store.freshnessOf('loadPromedios')!.updatedAt!;
      handler.local = true;
      await store.loadPromedios();
      final status = store.freshnessOf('loadPromedios')!;
      expect(status.fromCache, isTrue);
      expect(
        status.updatedAt!.millisecondsSinceEpoch,
        original.millisecondsSinceEpoch,
      );
      expect(cache.writes, 1);
      expect(repo.calls, 1);
    },
  );

  test(
    'legacy cache has unknown age and failed refresh retains date',
    () async {
      handler.local = true;
      await store.loadPromedios();
      expect(store.freshnessOf('loadPromedios')!.updatedAt, isNull);
      handler.local = false;
      await store.loadPromedios();
      final date = store.freshnessOf('loadPromedios')!.updatedAt;
      handler.fail = true;
      await store.loadPromedios();
      expect(store.freshnessOf('loadPromedios')!.failed, isTrue);
      expect(store.freshnessOf('loadPromedios')!.updatedAt, date);
      expect(store.promedios.hasValue, isTrue);
    },
  );

  test(
    'hydration restores SQLite data and date without a network call',
    () async {
      cache.stamp = DateTime(2026, 1, 15, 9);
      await store.hydrateFromCache();
      expect(store.promedios.hasValue, isTrue);
      expect(store.freshnessOf('loadPromedios')!.updatedAt, cache.stamp);
      expect(store.freshnessOf('loadPromedios')!.fromCache, isTrue);
      expect(repo.calls, 0);
      expect(cache.writes, 0);
    },
  );

  test(
    'hydration cannot replace data already received from the server',
    () async {
      await store.loadPromedios();
      final before = store.freshnessOf('loadPromedios');
      await store.hydrateFromCache();
      expect(store.freshnessOf('loadPromedios'), same(before));
      expect(before!.fromCache, isFalse);
    },
  );

  test('logout discards late results and provenance', () async {
    repo.pending = Completer<List<TermAverage>>();
    final pending = store.loadPromedios();
    await store.clear();
    repo.pending!.complete([]);
    await pending;
    expect(store.promedios.hasValue, isFalse);
    expect(store.freshnessOf('loadPromedios'), isNull);
    expect(cache.writes, 0);
  });

  test('first valid source avoids unnecessary fallback requests', () async {
    var fallbackCalls = 0;
    final resolver = Resolver<int>(
      sources: [
        DataSource(id: 'primary', fetch: () async => 1),
        DataSource(
          id: 'fallback',
          fetch: () async {
            fallbackCalls++;
            return 2;
          },
        ),
      ],
      merge: MergeStrategies.firstWins,
      stopAfterFirst: true,
    );
    expect(await resolver.load(), 1);
    expect(fallbackCalls, 0);
  });

  test('empty or failed primary still tries the fallback', () async {
    for (final throwsError in [false, true]) {
      final resolver = Resolver<List<int>>(
        sources: [
          DataSource(
            id: 'primary',
            fetch: () async {
              if (throwsError) throw StateError('offline');
              return [];
            },
          ),
          DataSource(id: 'fallback', fetch: () async => [2]),
        ],
        merge: MergeStrategies.firstWins,
        stopAfterFirst: true,
        isEmpty: (v) => v.isEmpty,
      );
      expect(await resolver.load(), [2]);
    }
  });

  testWidgets('saved data is labelled without inventing an update date', (
    tester,
  ) async {
    handler.local = true;
    await store.loadPromedios();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: DataStatus(
            store: store,
            operations: const {'loadPromedios': 'Notas'},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Datos guardados'), findsOneWidget);
    expect(
      find.textContaining('Fecha de actualización desconocida'),
      findsOneWidget,
    );
  });
}
