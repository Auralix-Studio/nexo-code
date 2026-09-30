import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nexo/core/error_handler.dart';
import 'package:nexo/core/secret_store.dart';
import 'package:nexo/core/storage.dart';
import 'package:nexo/data/app_store.dart';
import 'package:nexo/data/cache_manager.dart';
import 'package:nexo/data/connectivity_service.dart';
import 'package:nexo/data/sigma_repository.dart';
import 'package:nexo/features/home/home_screen.dart';
import 'package:nexo/l10n/app_localizations.dart';
import 'package:nexo/shared/widgets/logout_dialog.dart';

class _Repository extends Fake implements SigmaRepository {}

class _Cache extends Fake implements CacheManager {}

class _Handler extends Fake implements ErrorHandler {}

void main() {
  testWidgets(
    'logout and server dialogs stay compact and scroll on short screens',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await AppStorage.init(secrets: MemorySecretStore());
      final connection = ConnectivityService();
      final store = AppStore(
        _Repository(),
        cache: _Cache(),
        errorHandler: _Handler(),
        connectivity: connection,
      );
      addTearDown(store.dispose);
      addTearDown(connection.dispose);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      for (final size in [const Size(1366, 768), const Size(360, 480)]) {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('es'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            home: Scaffold(
              body: HomeScreen(
                store: store,
                connectivity: connection,
                onJump: (_) {},
              ),
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 1));
        final context = tester.element(find.byType(HomeScreen));
        final l = AppLocalizations.of(context);
        final logout = showLogoutConfirm(context);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        final scroll = find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(SingleChildScrollView),
        );
        expect(tester.getSize(scroll).width, lessThanOrEqualTo(380));
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text(l.actionCancel));
        await tester.tap(find.text(l.actionCancel));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(await logout, isFalse);

        await tester.tap(find.byTooltip(l.homeVerifyConnectivity));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.getSize(scroll).width, lessThanOrEqualTo(420));
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text(l.actionClose));
        await tester.tap(find.text(l.actionClose));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(Dialog), findsNothing);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('dashboard keeps saved widgets and order across window sizes', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await AppStorage.init(secrets: MemorySecretStore());
    final connection = ConnectivityService();
    final store = AppStore(
      _Repository(),
      cache: _Cache(),
      errorHandler: _Handler(),
      connectivity: connection,
    );
    addTearDown(store.dispose);
    addTearDown(connection.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    store.dashboardLayout = store.dashboardLayout.reversed.toList();
    final ids = store.dashboardLayout.map((w) => w.id).toList();

    for (final width in [360.0, 768.0, 1024.0, 1366.0]) {
      for (final scale in [1.0, 1.5]) {
        await tester.binding.setSurfaceSize(Size(width, 640));
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('es'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 640),
                textScaler: TextScaler.linear(scale),
              ),
              child: Scaffold(
                body: Padding(
                  // Simulate the expanded desktop rail without starting the app.
                  padding: EdgeInsets.only(left: width >= 1024 ? 233 : 0),
                  child: HomeScreen(
                    store: store,
                    connectivity: connection,
                    onJump: (_) {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 1));
        expect(
          tester.takeException(),
          isNull,
          reason: '$width px / text $scale',
        );
        for (final id in ids) {
          expect(
            find.byKey(ValueKey(id)),
            findsOneWidget,
            reason: '$id at $width',
          );
        }
        final ordered = find.byWidgetPredicate(
          (widget) =>
              widget.key is ValueKey<String> &&
              ids.contains((widget.key as ValueKey<String>).value),
        );
        expect(
          tester
              .widgetList(ordered)
              .map((w) => (w.key as ValueKey<String>).value),
          ids,
        );
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
