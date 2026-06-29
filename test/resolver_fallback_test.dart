import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/core/data/resolver.dart';
import 'package:nexo/core/errors.dart';

/// Verifica el contrato que distingue "vacío legítimo" de "backend caído".
/// De esto depende que una caída de SIGMA/Intranet caiga a la copia local en
/// vez de pisar el estado con `[]` (bug de "pantallas vacías").
void main() {
  Resolver<List<String>> resolver(List<DataSource<List<String>>> sources) =>
      Resolver<List<String>>(
        sources: sources,
        merge: MergeStrategies.firstWins,
        isEmpty: (l) => l.isEmpty,
      );

  test('todas las fuentes vacías → NoDataAvailable SIN causa (vacío real)',
      () async {
    final r = resolver([
      DataSource(id: 'a', fetch: () async => const <String>[]),
      DataSource(id: 'b', fetch: () async => const <String>[]),
    ]);
    try {
      await r.load();
      fail('debió lanzar NoDataAvailableException');
    } on NoDataAvailableException catch (e) {
      expect(e.cause, isNull); // sin causa → la app lo trata como []
    }
  });

  test('una fuente falla → NoDataAvailable CON causa (backend caído)',
      () async {
    final r = resolver([
      DataSource(
        id: 'a',
        fetch: () async => throw const NetworkException('SIGMA caído'),
      ),
      DataSource(id: 'b', fetch: () async => const <String>[]),
    ]);
    try {
      await r.load();
      fail('debió lanzar NoDataAvailableException');
    } on NoDataAvailableException catch (e) {
      expect(e.cause, isA<NetworkException>()); // con causa → cae a cache
    }
  });

  test('fuente no disponible (sin creds) no cuenta como caída', () async {
    final r = resolver([
      DataSource(
        id: 'intranet',
        available: () async => false, // sin credenciales
        fetch: () async => const <String>[],
      ),
    ]);
    try {
      await r.load();
      fail('debió lanzar NoDataAvailableException');
    } on NoDataAvailableException catch (e) {
      expect(e.cause, isNull); // no configurada ≠ caída
    }
  });

  test('primera fuente con datos gana aunque la segunda falle', () async {
    final r = resolver([
      DataSource(id: 'a', fetch: () async => ['ok']),
      DataSource(id: 'b', fetch: () async => throw Exception('irrelevante')),
    ]);
    expect(await r.load(), ['ok']);
  });
}
