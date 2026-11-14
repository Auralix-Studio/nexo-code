import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:ui';
import 'package:http/http.dart' as http;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:nexo/l10n/app_localizations.dart';
import 'package:nexo/l10n/quechua_fallback.dart';
import 'package:nexo/core/festivity/festivity.dart';
import 'package:nexo/features/festivity/widgets/fiestas_patrias_effects.dart';
import 'package:nexo/core/win_setup_service.dart';
import 'package:nexo/core/windows_startup.dart';
import 'package:nexo/features/settings/setup_view.dart';
import 'package:nexo/features/settings/install_dialog.dart';
import 'package:nexo/shared/widgets/custom_title_bar.dart';
import 'package:nexo/app/shell.dart';
import 'package:nexo/core/config.dart';
import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/design/theme_controller.dart';
import 'package:nexo/core/error_handler.dart';
import 'package:nexo/core/storage.dart';
import 'package:nexo/data/app_store.dart';
import 'package:nexo/data/services/directory_service.dart';
import 'package:nexo/data/local/cache_manager.dart';
import 'package:nexo/data/services/connectivity_service.dart';
import 'package:nexo/data/services/home_widget_service.dart';
import 'package:nexo/data/services/notification_service.dart';
import 'package:nexo/data/services/session.dart';
import 'package:nexo/core/shortcuts.dart';
import 'package:nexo/data/repositories/nexo_repository.dart';
import 'package:nexo/data/remote/backend_client.dart';
import 'package:nexo/core/session_scope.dart';
import 'package:nexo/data/remote/secure_http.dart';
import 'package:nexo/data/services/update_service.dart';
import 'package:nexo/features/auth/account_switcher.dart';
import 'package:nexo/features/auth/login_screen.dart';
import 'package:nexo/features/legal/legal_updates.dart';
import 'package:nexo/features/legal/terms_screen.dart';
import 'package:nexo/features/onboarding/onboarding_screen.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Si una pantalla falla al construirse, Flutter la sustituye por un recuadro
  // gris sin texto en release: es la «pantalla negra» que no dice nada. Se
  // cambia por algo legible y reportable, con el error a la vista.
  ErrorWidget.builder = (details) {
    debugPrint('Pantalla rota: ${details.exception}');
    return _BrokenScreen(details: details);
  };
  _startupStepSync('sqlite', () {
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  });

  // Único paso del que no se puede prescindir: sin preferencias no hay sesión
  // ni tema. Si ni eso funciona, mejor decirlo que dejar la ventana vacía.
  if (!kIsWeb && Platform.isWindows) {
    await _startupStep('sqlite-path', WinSetupService.prepareDatabaseDirectory);
  }
  if (!await _startupStep('storage', AppStorage.init)) {
    if (!kIsWeb && Platform.isWindows) {
      await WindowsStartup.prepare(backgroundColor: NexoColors.light.bg);
    }
    runApp(const _StartupErrorApp());
    _showWindowsAfterFirstFrame();
    return;
  }

  bool isSetup = false;
  bool isUninstall = false;
  if (!kIsWeb && Platform.isWindows) {
    // En la build de Store, la instalación la gestiona Windows: no hay
    // asistente propio ni desinstalador embebido.
    isUninstall = !StoreBuild.isStore && args.contains('--uninstall');
    final isInstalled = WinSetupService.isInstalledInstance;
    final isPortable = AppStorage.instance.runPortable;
    isSetup =
        !StoreBuild.isStore &&
        (isUninstall ||
            args.contains('--setup') ||
            (!isInstalled && !isPortable));
    final themeMode = AppStorage.instance.themeMode ?? 'system';
    bool isDark = false;
    if (themeMode == 'system') {
      isDark =
          PlatformDispatcher.instance.platformBrightness == Brightness.dark;
    } else {
      isDark = NexoColors.byId(themeMode).isDark;
    }
    final initialBg = isDark ? NexoColors.dark.bg : NexoColors.light.bg;
    await WindowsStartup.prepare(
      isSetup: isSetup,
      isUninstall: isUninstall,
      backgroundColor: initialBg,
    );
  }
  if (isUninstall) {
    final mode = AppStorage.instance.themeMode ?? 'system';
    final NexoColors palette;
    if (mode == 'system') {
      final isDark =
          !kIsWeb &&
          PlatformDispatcher.instance.platformBrightness == Brightness.dark;
      palette = isDark ? NexoColors.dark : NexoColors.light;
    } else {
      palette = NexoColors.byId(mode);
    }
    runApp(_UninstallApp(palette: palette));
    _showWindowsAfterFirstFrame();
    return;
  }
  // Si falla la carga del bundle de certificados nos quedamos con las raíces
  // del sistema: es peor arrancar sin app que arrancar sin ese extra.
  final secureHttp =
      await _startupValue('http', createSecureClient) ?? http.Client();
  // La app solo habla con la API de Nexo: un cliente, una sesión.
  final scope = SessionScope();
  final backend = BackendClient(transport: secureHttp, scope: scope);
  final session = SessionService(client: backend);
  final connectivity = ConnectivityService(httpClient: secureHttp);
  final cache = CacheManager(scope: scope);
  final errorHandler = ErrorHandler(
    connectivity: connectivity,
    session: session,
  );
  final directory = DirectoryService(client: backend);
  // Versión vigente de los documentos legales, publicada por el backend.
  final legal = LegalUpdates.backend(backend);
  final store = AppStore(
    NexoRepository(directory),
    cache: cache,
    errorHandler: errorHandler,
    connectivity: connectivity,
    scope: scope,
  );
  final theme = ThemeController()..load();
  // Sin esperar: el splash usa su propia fuente y, cuando esta termina de
  // registrarse, el motor vuelve a componer el texto con ella.
  unawaited(theme.fonts.ensureLoaded(theme.fontId));
  final widgets = HomeWidgetService();
  final updater = UpdateService(httpClient: secureHttp);
  store.onGradeChange = (course, grade) =>
      NotificationService.instance.showGradeChanged(course, grade);
  session.onSessionEnded = () async {
    final cleared = store.clear(invalidateSession: false);
    directory.reset();
    await Future.wait<void>([
      cleared,
      widgets.sync(store),
      NotificationService.instance.clearAccount(),
    ]);
  };
  session.onAccountReady = cache.activateAccount;
  store.addListener(() {
    if (!session.isAuthenticated) return;
    if (!store.profile.loading && !store.schedule.loading) {
      widgets.sync(store);
    }
    NotificationService.instance.reschedule(
      clases: store.schedule.value,
      installments: store.pendingInstallments.value,
      finishedSubjects: store.finishedSubjectsThisTerm,
    );
  });
  // Pintar ANTES de tocar red o disco. La certificación de la Microsoft Store
  // rechazó la 1.6.3.0 (10.1.2.10 Functionality) con «the product does not
  // display any content at launch»: antes de este `runApp` se hacía una docena
  // de `await` —entre ellos un ping a SIGMA y otro a la Intranet, 6 s cada
  // uno— y en una máquina que no alcanza los servidores de la UPLA la ventana
  // se quedaba vacía. Ahora la primera pantalla aparece de inmediato y todo lo
  // demás ocurre por detrás, tolerando fallos.
  runApp(
    NexoApp(
      session: session,
      store: store,
      theme: theme,
      connectivity: connectivity,
      directory: directory,
      legal: legal,
      isSetup: isSetup,
      isUninstall: isUninstall,
    ),
  );

  _showWindowsAfterFirstFrame();
  _startPortable = () => _bootstrap(
    cache: cache,
    connectivity: connectivity,
    session: session,
    store: store,
    widgets: widgets,
    updater: updater,
  );
  if (!isSetup) unawaited(_startPortable!());
}

void _showWindowsAfterFirstFrame() {
  if (!kIsWeb && Platform.isWindows) {
    unawaited(
      WindowsStartup.showAfterFrame(
        WidgetsBinding.instance.waitUntilFirstFrameRasterized,
      ),
    );
  }
}

Future<void> Function()? _startPortable;

/// Arranque en segundo plano.
///
/// Cada paso va aislado: que falle el caché, las notificaciones o la red no
/// puede impedir que la app se use. Lo que decide la primera pantalla
/// —`session.bootstrap`— va primero; el resto en paralelo, porque no dependen
/// entre sí.
Future<void> _bootstrap({
  required CacheManager cache,
  required ConnectivityService connectivity,
  required SessionService session,
  required AppStore store,
  required HomeWidgetService widgets,
  required UpdateService updater,
}) async {
  // El caché va primero porque la sesión depende de él: al resolverse avisa a
  // sus oyentes y, si resulta que no hay sesión, el store limpia el caché. Es
  // disco local y no red, así que no es lo que dejaba la ventana en blanco.
  final cacheReady = await _startupStep('cache', cache.init);

  await _startupStep('session', session.bootstrap);
  // Si no se pudo decidir, a login: nunca dejar el splash colgado.
  session.resolveUnknownAsUnauthenticated();

  if (cacheReady && session.isAuthenticated) {
    await _startupStep('hydrate', store.hydrateFromCache);
  }

  // Lo que sí puede tardar o fallar, en paralelo y sin bloquear la pantalla.
  await Future.wait([
    _startupStep('connectivity', connectivity.start),
    _startupStep('widgets', widgets.init),
    _startupStep('notifications', NotificationService.instance.init),
  ]);
  if (session.isAuthenticated) {
    await NotificationService.instance.reschedule(
      clases: store.schedule.value,
      installments: store.pendingInstallments.value,
      finishedSubjects: store.finishedSubjectsThisTerm,
    );
  }

  _startupStepSync('shortcuts', ShortcutService.instance.init);

  // La Store se encarga de las actualizaciones: no arrancamos el updater propio.
  if (!StoreBuild.isStore) {
    NotificationService.instance.onInstallUpdateTap = updater.installDownloaded;
    unawaited(_startupStep('updater', updater.bootstrap));
  }
}

/// Ejecuta un paso de arranque sin dejar que tumbe la app ni la bloquee.
/// Devuelve `false` si falló, para que quien dependa del paso se lo salte.
Future<bool> _startupStep(String name, Future<void> Function() step) async {
  return await _startupValue(name, () async {
        await step();
        return true;
      }) ??
      false;
}

/// Igual, pero para pasos que producen algo que la app necesita.
Future<T?> _startupValue<T>(String name, Future<T> Function() step) async {
  try {
    return await step().timeout(const Duration(seconds: 20));
  } catch (e) {
    debugPrint('Arranque: «$name» falló y se omite ($e)');
    return null;
  }
}

void _startupStepSync(String name, void Function() step) {
  try {
    step();
  } catch (e) {
    debugPrint('Arranque: «$name» falló y se omite ($e)');
  }
}

class NexoApp extends StatelessWidget {
  const NexoApp({
    super.key,
    required this.session,
    required this.store,
    required this.theme,
    required this.connectivity,
    required this.directory,
    required this.isSetup,
    required this.isUninstall,
    this.legal,
  });
  final SessionService session;
  final AppStore store;
  final ThemeController theme;
  final ConnectivityService connectivity;
  final DirectoryService directory;
  final bool isSetup;
  final bool isUninstall;
  final LegalUpdates? legal;
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: theme,
      builder: (context, _) {
        return MaterialApp(
          title: 'Nexo · UPLA',
          debugShowCheckedModeBanner: false,
          locale: theme.locale.flutterLocale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            QuechuaMaterialDelegate(),
            QuechuaCupertinoDelegate(),
            QuechuaWidgetsDelegate(),
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (ctx, child) {
            final palette = theme.resolvedPalette(ctx);
            final isTest =
                !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
            if (!kIsWeb && Platform.isWindows && !isTest) {
              windowManager.setBackgroundColor(palette.bg);
            }
            return Theme(
              data: NexoTheme.themeFor(palette, fontFamily: theme.fontFamily),
              child: child!,
            );
          },
          theme: NexoTheme.light(fontFamily: theme.fontFamily),
          home: _Gate(
            legal: legal,
            session: session,
            store: store,
            theme: theme,
            directory: directory,
            connectivity: connectivity,
            isSetup: isSetup,
            isUninstall: isUninstall,
          ),
        );
      },
    );
  }
}

class _Gate extends StatefulWidget {
  const _Gate({
    required this.session,
    required this.store,
    required this.theme,
    required this.connectivity,
    required this.directory,
    required this.isSetup,
    required this.isUninstall,
    this.legal,
  });
  final SessionService session;
  final AppStore store;
  final ThemeController theme;
  final ConnectivityService connectivity;
  final DirectoryService directory;
  final bool isSetup;
  final bool isUninstall;
  final LegalUpdates? legal;
  @override
  State<_Gate> createState() => _GateState();
}

class _GateState extends State<_Gate> with WidgetsBindingObserver {
  bool _accepted = AppStorage.instance.acceptedTerms;
  bool _seenOnboarding = AppStorage.instance.seenOnboarding;
  late bool _isSetup = widget.isSetup;
  bool _showInstallView = false;
  InstallOptions? _installOptions;
  bool _minSplashDone = false;

  SessionStatus? _lastStatus;

  @override
  void initState() {
    super.initState();
    _watchLegal();
    final active = FestivityService.active(DateTime.now());
    final isFiestasPatrias =
        AppStorage.instance.festivityDecor &&
        active?.festivity.id == 'fiestas_patrias';

    if (isFiestasPatrias) {
      Future.delayed(const Duration(milliseconds: 3500), () {
        if (mounted) setState(() => _minSplashDone = true);
      });
    } else {
      _minSplashDone = true;
    }
  }

  // Documentos legales: la versión vigente la publica el backend, así que
  // un cambio llega sin actualizar la app. Se consulta al abrir y al volver
  // (LegalUpdates limita a una vez por hora); si hay una versión nueva se
  // vuelve a pedir la aceptación. La constancia en el servidor se envía en
  // cuanto hay sesión.
  void _watchLegal() {
    final legal = widget.legal;
    if (legal == null || widget.isUninstall) return;
    WidgetsBinding.instance.addObserver(this);
    legal.addListener(_onLegalChanged);
    widget.session.addListener(_onSessionChanged);
    unawaited(legal.check());
  }

  @override
  void dispose() {
    if (widget.legal != null && !widget.isUninstall) {
      WidgetsBinding.instance.removeObserver(this);
      widget.legal!.removeListener(_onLegalChanged);
      widget.session.removeListener(_onSessionChanged);
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(widget.legal?.check());
  }

  void _onLegalChanged() {
    final accepted = AppStorage.instance.acceptedTerms;
    if (mounted && accepted != _accepted) {
      setState(() => _accepted = accepted);
    }
  }

  void _onSessionChanged() {
    final status = widget.session.status;
    if (status == _lastStatus) return;
    _lastStatus = status;
    final legal = widget.legal!;
    if (status == SessionStatus.authenticated) {
      unawaited(legal.syncAcceptance());
    } else if (status == SessionStatus.unauthenticated) {
      unawaited(legal.signedOut());
    }
  }

  Future<void> _acceptTerms() async {
    final legal = widget.legal;
    if (legal != null) {
      await legal.accept();
    } else {
      await AppStorage.instance.setAcceptedTerms(true);
    }
    if (mounted) setState(() => _accepted = true);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isUninstall) {
      return const UninstallView();
    }
    if (_isSetup) {
      if (_showInstallView && _installOptions != null) {
        return Scaffold(
          backgroundColor: NexoTheme.bg,
          body: Column(
            children: [
              const CustomTitleBar(),
              Expanded(child: InstallView(options: _installOptions!)),
            ],
          ),
        );
      }
      return Scaffold(
        backgroundColor: NexoTheme.bg,
        body: Column(
          children: [
            const CustomTitleBar(),
            Expanded(
              child: SetupWizard(
                theme: widget.theme,
                onInstall: (options) async {
                  await AppStorage.instance.setAcceptedTerms(true);
                  await AppStorage.instance.setSeenOnboarding(true);
                  setState(() {
                    _installOptions = options;
                    _showInstallView = true;
                  });
                },
                onRunPortable: () async {
                  await AppStorage.instance.setRunPortable(true);
                  await AppStorage.instance.setAcceptedTerms(true);
                  await AppStorage.instance.setSeenOnboarding(true);
                  unawaited(_startPortable?.call() ?? Future<void>.value());
                  if (!kIsWeb && Platform.isWindows) {
                    await windowManager.setMinimumSize(const Size(480, 500));
                    await windowManager.setMaximumSize(const Size(9999, 9999));
                    await windowManager.setResizable(true);
                    await windowManager.setSize(const Size(1100, 680));
                    await windowManager.center();
                  }
                  setState(() {
                    _isSetup = false;
                    _accepted = true;
                    _seenOnboarding = true;
                  });
                },
              ),
            ),
          ],
        ),
      );
    }
    Widget gated;
    String key;
    if (!_accepted) {
      key = 'terms';
      final legal = widget.legal;
      gated = TermsScreen(
        // Quien ya había aceptado una versión anterior no está "empezando":
        // está viendo unos términos que cambiaron.
        isUpdate: AppStorage.instance.acceptedTermsVersion > 0,
        version: AppStorage.instance.requiredTermsVersion,
        changes: legal?.changes ?? const [],
        onlineDocuments: legal?.onlineDocuments ?? const [],
        onAccept: _acceptTerms,
      );
    } else {
      gated = ListenableBuilder(
        listenable: widget.session,
        builder: (context, _) {
          final isWaiting =
              widget.session.status == SessionStatus.unknown || !_minSplashDone;
          final showOnboarding =
              !_seenOnboarding &&
              widget.session.status == SessionStatus.unauthenticated;
          final Widget child;
          final String k;
          final switching = widget.session.switchingTo;
          if (isWaiting) {
            k = 'splash_delay';
            child = const _SplashScreen();
          } else if (switching != null) {
            k = 'switching';
            child = AccountSwitchingScreen(account: switching);
          } else if (showOnboarding) {
            k = 'onboarding';
            child = OnboardingScreen(
              onDone: () async {
                await AppStorage.instance.setSeenOnboarding(true);
                if (mounted) setState(() => _seenOnboarding = true);
              },
            );
          } else {
            k = widget.session.status.name;
            child = switch (widget.session.status) {
              SessionStatus.unknown => const _SplashScreen(),
              SessionStatus.authenticated => AppShell(
                store: widget.store,
                session: widget.session,
                theme: widget.theme,
                connectivity: widget.connectivity,
                directory: widget.directory,
              ),
              SessionStatus.unauthenticated => LoginScreen(
                session: widget.session,
              ),
            };
          }
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 480),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (c, anim) {
              final slide =
                  Tween<Offset>(
                    begin: const Offset(0, 0.08),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
                  );
              return FadeTransition(
                opacity: anim,
                child: SlideTransition(position: slide, child: c),
              );
            },
            child: KeyedSubtree(key: ValueKey(k), child: child),
          );
        },
      );
      key = 'app';
    }
    return ListenableBuilder(
      listenable: widget.theme,
      builder: (context, _) {
        NexoTheme.apply(widget.theme.resolvedPalette(context));
        Widget child = AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (c, anim) =>
              FadeTransition(opacity: anim, child: c),
          child: KeyedSubtree(key: ValueKey(key), child: gated),
        );
        final isTest =
            !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
        if (!kIsWeb && Platform.isWindows && !isTest) {
          child = Scaffold(
            backgroundColor: NexoTheme.bg,
            body: Column(
              children: [
                const CustomTitleBar(),
                Expanded(child: child),
              ],
            ),
          );
        }
        return child;
      },
    );
  }
}

/// Reemplaza el recuadro vacío de Flutter cuando una pantalla no se puede
/// construir. No usa `Scaffold` ni localizaciones a propósito: se inserta
/// justo donde falló el árbol, así que puede quedar fuera de cualquier
/// contexto de Material.
class _BrokenScreen extends StatelessWidget {
  const _BrokenScreen({required this.details});
  final FlutterErrorDetails details;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: NexoTheme.bg,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.report_gmailerrorred_outlined,
                  size: 44,
                  color: NexoTheme.warning,
                ),
                const SizedBox(height: 12),
                Text(
                  'No se pudo mostrar esta sección',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: NexoTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Vuelve atrás e inténtalo de nuevo. Si se repite, envíanos '
                  'esta captura desde Soporte:',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: NexoTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${details.exception}',
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: NexoTheme.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pantalla de último recurso: si ni las preferencias locales arrancan, la
/// app dice qué pasa en vez de mostrar una ventana en blanco. No usa
/// localizaciones ni tema porque justamente puede que no haya nada cargado.
class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Nexo no pudo iniciarse',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'No se pudo acceder al almacenamiento local del dispositivo. '
                  'Cierra la aplicación y vuelve a abrirla; si el problema '
                  'sigue, reinstálala.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => exit(0),
                  child: const Text('Cerrar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SplashScreen extends StatefulWidget {
  const _SplashScreen();
  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..forward();
  late final Animation<double> _logoScale = Tween(
    begin: 0.9,
    end: 1.0,
  ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutBack));
  late final Animation<double> _textOpacity = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.2, 0.9, curve: Curves.easeOut),
  );
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.nx;
    final startBg = palette.isDark
        ? const Color(0xFF0A0C10)
        : const Color(0xFFFFFFFF);
    final endBg = palette.bg;
    final bgTween = ColorTween(
      begin: startBg,
      end: endBg,
    ).animate(CurvedAnimation(parent: _c, curve: const Interval(0.0, 0.7)));
    final active = FestivityService.active(DateTime.now());
    final isFiestasPatrias =
        AppStorage.instance.festivityDecor &&
        active?.festivity.id == 'fiestas_patrias';
    final width = MediaQuery.sizeOf(context).width;
    final fontSize = (width * 0.22).clamp(60.0, 120.0);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: bgTween.value ?? endBg,
          body: Stack(
            children: [
              // Logo de NEXO estrictamente centrado en la pantalla (como siempre ha estado)
              Center(
                child: FadeTransition(
                  opacity: _textOpacity,
                  child: ScaleTransition(
                    scale: _logoScale,
                    child: Text(
                      'NEXO',
                      style: TextStyle(
                        fontFamily: 'SuperMindset',
                        fontSize: fontSize,
                        height: 0.9,
                        letterSpacing: 1.6,
                        color: palette.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
              // Decoración festiva colgada debajo
              if (isFiestasPatrias)
                Center(
                  child: FadeTransition(
                    opacity: _textOpacity,
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: Transform.translate(
                        offset: Offset(
                          0,
                          fontSize + 120,
                        ), // Desplaza los elementos hacia abajo libremente
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '¡Felices Fiestas Patrias!',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFE2432A), // Rojo patrio
                              ),
                            ),
                            SizedBox(height: 12),
                            SizedBox(
                              width: 160,
                              height: 80,
                              child: MarcaPeruEffect(
                                color: Color(0xFFE2432A),
                              ), // Rojo patrio
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _UninstallApp extends StatelessWidget {
  const _UninstallApp({required this.palette});
  final NexoColors palette;
  @override
  Widget build(BuildContext context) {
    NexoTheme.apply(palette);
    return MaterialApp(
      title: 'Desinstalar Nexo',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: NexoTheme.themeFor(palette),
      home: Scaffold(
        backgroundColor: palette.bg,
        body: const Column(
          children: [
            CustomTitleBar(),
            Expanded(child: UninstallView()),
          ],
        ),
      ),
    );
  }
}
