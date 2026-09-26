import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:nexo/core/session_scope.dart';
import 'package:nexo/data/cache_manager.dart';
import 'package:nexo/domain/unified_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  late CacheManager cache;
  setUp(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    temp = await Directory(
      p.join(Directory.current.path, '.dart_tool'),
    ).createTemp('nexo-cache-test-');
    await databaseFactory.setDatabasesPath(temp.path);
    cache = CacheManager();
  });
  tearDown(() async {
    // The test database is always inside the unique temporary test directory.
    await databaseFactory.deleteDatabase(p.join(temp.path, 'nexo_cache.db'));
    await temp.delete();
  });

  test(
    'new database has tables and persists only the active account',
    () async {
      await cache.activateAccount('A');
      final tables = await cache.db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'",
      );
      expect(
        tables.map((r) => r['name']),
        containsAll(['schedule', 'cache_owner', 'unified_student']),
      );
      await cache.saveStudent(
        Student.fromSigmaJson({'est_Id': 'A', 'estudiante': 'Alice'}),
      );
      await cache.activateAccount('A');
      expect((await cache.getStudent())?.id, 'A');
      await cache.activateAccount('B');
      expect(await cache.getStudent(), isNull);
      await cache.saveStudent(
        Student.fromSigmaJson({'est_Id': 'B', 'estudiante': 'Bob'}),
      );
      expect((await cache.getStudent())?.id, 'B');
      final database = cache.db;
      await cache.clearAll();
      expect(await database.query('unified_student'), isEmpty);
      expect(await database.query('cache_owner'), isEmpty);
      await expectLater(cache.getStudent(), throwsStateError);
      await database.close();
    },
  );

  for (final populated in [false, true]) {
    test(
      'version 2 migration repairs schema and discards unowned data ($populated)',
      () async {
        final old = await openDatabase(
          p.join(temp.path, 'nexo_cache.db'),
          version: 2,
          onCreate: (db, _) async {
            if (populated) {
              await db.execute(
                'CREATE TABLE unified_student (id TEXT PRIMARY KEY, json_data TEXT, updated_at INTEGER)',
              );
              await db.insert('unified_student', {
                'id': 'old-user',
                'json_data': '{}',
                'updated_at': 0,
              });
            }
          },
        );
        await old.close();
        await cache.activateAccount('B');
        expect(await cache.db.getVersion(), 3);
        expect(await cache.getStudent(), isNull);
        await cache.saveHorario([]);
        expect(await cache.getHorario(), isEmpty);
        await cache.db.close();
      },
    );
  }

  test(
    'cache reads retain the original timestamp and isolate periods',
    () async {
      await cache.activateAccount('A');
      await cache.saveBoleta('2026', '1', []);
      await cache.saveBoleta('2026', '2', []);
      await cache.db.update(
        'boleta_cursos',
        {'updated_at': 123456},
        where: 'year = ? AND periodo = ?',
        whereArgs: ['2026', '1'],
      );
      await cache.getBoleta('2026', '1');
      expect(
        (await cache.updatedAtFor('loadBoleta:2026-1'))!.millisecondsSinceEpoch,
        123456,
      );
      expect(
        (await cache.updatedAtFor('loadBoleta:2026-2'))!.millisecondsSinceEpoch,
        isNot(123456),
      );
      await cache.activateAccount('B');
      expect(await cache.updatedAtFor('loadBoleta:2026-1'), isNull);
      await cache.db.close();
    },
  );

  test('obsolete session cannot read or write the account cache', () async {
    final scope = SessionScope();
    cache = CacheManager(scope: scope);
    await cache.activateAccount('A');
    await scope.run(() async {
      scope.invalidate();
      await expectLater(
        cache.saveHorario([]),
        throwsA(isA<StaleSessionException>()),
      );
      await expectLater(
        cache.getHorario(),
        throwsA(isA<StaleSessionException>()),
      );
    });
    await cache.db.close();
  });
}
