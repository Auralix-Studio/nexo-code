import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:ui';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:nexo/l10n/app_localizations.dart';
import 'package:nexo/l10n/quechua_fallback.dart';
import 'package:nexo/core/win_setup_service.dart';
import 'package:nexo/features/settings/setup_view.dart';
import 'package:nexo/features/settings/install_dialog.dart';
import 'package:nexo/widgets/custom_title_bar.dart';

import 'package:nexo/app/shell.dart';
import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/design/theme_controller.dart';
import 'package:nexo/core/error_handler.dart';
import 'package:nexo/core/storage.dart';
import 'package:nexo/data/api_client.dart';
import 'package:nexo/data/app_store.dart';
import 'package:nexo/data/cache_manager.dart';
import 'package:nexo/data/connectivity_service.dart';
import 'package:nexo/data/home_widget_service.dart';
import 'package:nexo/data/notification_service.dart';
import 'package:nexo/data/session.dart';
import 'package:nexo/data/sigma_repository.dart';
import 'package:nexo/core/shortcuts.dart';
import 'package:nexo/data/docente_repository.dart';
import 'package:nexo/data/intranet_client.dart';
import 'package:nexo/data/intranet_repository.dart';
import 'package:nexo/data/graph_client.dart';
import 'package:nexo/data/ms_auth_service.dart';
import 'package:nexo/data/secure_http.dart';
import 'package:nexo/data/teams_repository.dart';
import 'package:nexo/features/auth/login_screen.dart';
import 'package:nexo/features/legal/terms_screen.dart';
import 'package:nexo/features/onboarding/onboarding_screen.dart';
import 'package:nexo/ai/lumen_services.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await AppStorage.init();

  bool isSetup = false;
  bool isUninstall = false;
  if (!kIsWeb && Platform.isWindows) {
    await windowManager.ensureInitialized();
    isUninstall = args.contains('--uninstall');
    final isInstalled = WinSetupService.isInstalledInstance;
    final isPortable = AppStorage.instance.runPortable;
    isSetup = isUninstall || (!isInstalled && !isPortable);

    final themeMode = AppStorage.instance.themeMode ?? 'system';
    bool isDark = false;
    if (themeMode == 'system') {
      isDark = PlatformDispatcher.instance.platformBrightness == Brightness.dark;
    } else {
      isDark = NexoColors.byId(themeMode).isDark;
    }
    final initialBg = isDark ? NexoColors.dark.bg : NexoColors.light.bg;

    if (isSetup) {
      final windowOptions = WindowOptions(
        size: const Size(480, 380),
        minimumSize: const Size(480, 340),
        maximumSize: const Size(480, 700),
        titleBarStyle: TitleBarStyle.hidden,
        center: true,
        backgroundColor: initialBg,
      );
      windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
      });
    } else {
      final windowOptions = WindowOptions(
        size: const Size(1280, 800),
        minimumSize: const Size(800, 600),
        titleBarStyle: TitleBarStyle.hidden,
        center: true,
        backgroundColor: initialBg,
      );
      windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
      });
    }
  }

  // Atajo de desinstalación: saltar todo el bootstrapping (red, sqlite,
  // notificaciones, etc.). La vista de uninstall no necesita nada de eso y
  // cualquier cuelgue en bootstrap dejaba la ventana en blanco.
  if (isUninstall) {
    final mode = AppStorage.instance.themeMode ?? 'system';
    final NexoColors palette;
    if (mode == 'system') {
      final isDark = !kIsWeb &&
          PlatformDispatcher.instance.platformBrightness == Brightness.dark;
      palette = isDark ? NexoColors.dark : NexoColors.light;
    } else {
      palette = NexoColors.byId(mode);
    }
    runApp(_UninstallApp(palette: palette));
    return;
  }

  // Transporte HTTP con root CAs de Mozilla + del sistema.
  // Arregla CERTIFICATE_VERIFY_FAILED en dispositivos con almacén raíz
  // desactualizado. En Web es un cliente estándar (el navegador valida).
  final secureHttp = await createSecureClient();

  final api = ApiClient(transport: secureHttp);
  final repo = SigmaRepository(api);
  final session = SessionService(apiClient: api, repo: repo);

  // Reutilizamos el transporte con root CAs de Mozilla — sin esto, el
  // healthcheck de Intranet/SIGMA falla en dispositivos con almacén de
  // certificados desactualizado y el banner sale rojo aunque la app
  // funcione bien para todo lo demás.
  final connectivity = ConnectivityService(httpClient: secureHttp);
  final cache = CacheManager();
  await cache.init();
  await connectivity.start();

  final errorHandler = ErrorHandler(connectivity: connectivity, session: session);

  final intranet = IntranetRepository(IntranetClient(transport: secureHttp));
  final graph = GraphClient(transport: secureHttp);
  final msAuth = MsAuthService(graph);
  final teams = TeamsRepository(graph);
  final docente = DocenteRepository(api);
  final store = AppStore(
    repo,
    cache: cache,
    errorHandler: errorHandler,
    intranet: intranet,
    teams: teams,
    docente: docente,
  );
  final theme = ThemeController()..load();
  final widgets = HomeWidgetService();
  await widgets.init();
  ShortcutService.instance.init();
  await NotificationService.instance.init();

  // Detección de notas nuevas → notificación inmediata.
  store.onGradeChange = (curso, nota) =>
      NotificationService.instance.showGradeChanged(curso, nota);

  // Si el token expira, limpiamos el store junto con la sesión.
  session.addListener(() {
    if (!session.isAuthenticated) store.clear();
  });

  // Mantener los widgets y las notificaciones sincronizados.
  store.addListener(() {
    if (!store.profile.loading && !store.horario.loading) {
      widgets.sync(store);
      if (NotificationService.instance.prefs.enabled &&
          !store.cuotasPendientes.loading) {
        NotificationService.instance.reschedule(
          clases: store.horario.value,
          cuotas: store.cuotasPendientes.value,
        );
      }
    }
  });

  await session.bootstrap();
  await msAuth.bootstrap();
  if (session.isAuthenticated) store.hydrateFromCache();

  // Lumen: instanciado siempre, pero arranca en `inactive`. La descarga del
  // modelo es opt-in (ver LumenHomeCard → LumenOnboardingDialog).
  final lumen = LumenServices();

  runApp(NexoApp(
    session: session,
    store: store,
    theme: theme,
    msAuth: msAuth,
    connectivity: connectivity,
    lumen: lumen,
    isSetup: isSetup,
    isUninstall: isUninstall,
  ));
}

class NexoApp extends StatelessWidget {
  const NexoApp({
    super.key,
    required this.session,
    required this.store,
    required this.theme,
    required this.msAuth,
    required this.connectivity,
    required this.lumen,
    required this.isSetup,
    required this.isUninstall,
  });

  final SessionService session;
  final AppStore store;
  final ThemeController theme;
  final MsAuthService msAuth;
  final ConnectivityService connectivity;
  final LumenServices lumen;
  final bool isSetup;
  final bool isUninstall;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: theme,
      builder: (context, _) {
        return MaterialApp(
          title: 'Nexo · UPLA',
          debugShowCheckedModeBanner: false,
          // Internacionalización via flutter_localizations + ARB.
          locale: theme.locale.flutterLocale,
          // Lista personalizada: delegates oficiales + puentes que sirven
          // español a los widgets nativos cuando el locale es quechua
          // (flutter_localizations no trae traducciones de Material/Cupertino
          // para `qu`, lo que rompía diálogos y date pickers).
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
            final isTest = Platform.environment.containsKey('FLUTTER_TEST');
            if (!kIsWeb && Platform.isWindows && !isTest) {
              windowManager.setBackgroundColor(palette.bg);
            }
            return Theme(data: NexoTheme.themeFor(palette), child: child!);
          },
          theme: NexoTheme.light(),
          home: _Gate(
            session: session,
            store: store,
            theme: theme,
            msAuth: msAuth,
            connectivity: connectivity,
            lumen: lumen,
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
    required this.msAuth,
    required this.connectivity,
    required this.lumen,
    required this.isSetup,
    required this.isUninstall,
  });
  final SessionService session;
  final AppStore store;
  final ThemeController theme;
  final MsAuthService msAuth;
  final ConnectivityService connectivity;
  final LumenServices lumen;
  final bool isSetup;
  final bool isUninstall;

  @override
  State<_Gate> createState() => _GateState();
}

class _GateState extends State<_Gate> {
  bool _accepted = AppStorage.instance.acceptedTerms;
  bool _seenOnboarding = AppStorage.instance.seenOnboarding;
  late bool _isSetup = widget.isSetup;
  bool _showInstallView = false;
  InstallOptions? _installOptions;

  @override
  Widget build(BuildContext context) {
    if (widget.isUninstall) {
      return const UninstallView();
    }

    if (_isSetup) {
      if (_showInstallView && _installOptions != null) {
        return Scaffold(
          backgroundColor: NexoTheme.bg,
          body: InstallView(options: _installOptions!),
        );
      }
      return Scaffold(
        backgroundColor: NexoTheme.bg,
        body: SetupWizard(
          theme: widget.theme,
          onInstall: (options) async {
            // Persistir antes de instalar para que el exe instalado
            // salte directo al login
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
            if (!kIsWeb && Platform.isWindows) {
              await windowManager.setMinimumSize(const Size(800, 600));
              await windowManager.setMaximumSize(const Size(9999, 9999));
              await windowManager.setResizable(true);
              await windowManager.setSize(const Size(1280, 800));
              await windowManager.center();
            }
            setState(() {
              _isSetup = false;
              _accepted = true;
              _seenOnboarding = true;
            });
          },
        ),
      );
    }

    Widget gated;
    String key;

    if (!_accepted) {
      key = 'terms';
      gated = TermsScreen(
        onAccept: () async {
          await AppStorage.instance.setAcceptedTerms(true);
          if (mounted) setState(() => _accepted = true);
        },
      );
    } else {
      gated = ListenableBuilder(
        listenable: widget.session,
        builder: (context, _) {
          final showOnboarding =
              !_seenOnboarding &&
              widget.session.status == SessionStatus.unauthenticated;
          final Widget child;
          final String k;
          if (showOnboarding) {
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
                msAuth: widget.msAuth,
                connectivity: widget.connectivity,
                lumen: widget.lumen,
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
            // Fade + slide sutil — evita que el paso de Onboarding a Login
            // se sienta "seco". El widget entrante baja 8% de la altura
            // hasta su posición real mientras hace fade-in.
            transitionBuilder: (c, anim) {
              final slide = Tween<Offset>(
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

        final isTest = Platform.environment.containsKey('FLUTTER_TEST');
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
    final bgTween = ColorTween(begin: startBg, end: endBg).animate(
      CurvedAnimation(parent: _c, curve: const Interval(0.0, 0.7)),
    );
    final width = MediaQuery.sizeOf(context).width;
    final fontSize = (width * 0.14).clamp(38.0, 66.0);

    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: bgTween.value ?? endBg,
          body: Center(
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
        );
      },
    );
  }
}

/// App mínima para la ruta de desinstalación. Evita inicializar red, sqlite,
/// notificaciones, etc. — cualquier cuelgue en esos servicios dejaba la
/// ventana en blanco al desinstalar.
class _UninstallApp extends StatelessWidget {
  const _UninstallApp({required this.palette});
  final NexoColors palette;

  @override
  Widget build(BuildContext context) {
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
      home: const UninstallView(),
    );
  }
}
