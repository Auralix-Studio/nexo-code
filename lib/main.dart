import 'package:flutter/material.dart';

import 'package:nexo/app/shell.dart';
import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/design/theme_controller.dart';
import 'package:nexo/core/storage.dart';
import 'package:nexo/data/api_client.dart';
import 'package:nexo/data/app_store.dart';
import 'package:nexo/data/home_widget_service.dart';
import 'package:nexo/data/notification_service.dart';
import 'package:nexo/data/session.dart';
import 'package:nexo/data/sigma_repository.dart';
import 'package:nexo/core/shortcuts.dart';
import 'package:nexo/data/intranet_client.dart';
import 'package:nexo/data/intranet_repository.dart';
import 'package:nexo/features/auth/login_screen.dart';
import 'package:nexo/features/legal/terms_screen.dart';
import 'package:nexo/features/onboarding/onboarding_screen.dart';
import 'package:nexo/shared/widgets/app_logo.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppStorage.init();

  final api = ApiClient();
  final repo = SigmaRepository(api);
  final session = SessionService(apiClient: api, repo: repo);
  final intranet = IntranetRepository(IntranetClient());
  final store = AppStore(repo, intranet: intranet);
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
  if (session.isAuthenticated) store.hydrateFromCache();
  runApp(NexoApp(session: session, store: store, theme: theme));
}

class NexoApp extends StatelessWidget {
  const NexoApp({
    super.key,
    required this.session,
    required this.store,
    required this.theme,
  });

  final SessionService session;
  final AppStore store;
  final ThemeController theme;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: theme,
      builder: (context, _) {
        return MaterialApp(
          title: 'Nexo · UPLA',
          debugShowCheckedModeBanner: false,
          // Tema único resuelto desde el controlador (claro/oscuro/sistema).
          // Builder asegura que `theme` se calcule con el brightness real.
          builder: (ctx, child) {
            final dark = theme.resolvedDark(ctx);
            return Theme(
              data: NexoTheme.themeFor(dark),
              child: child!,
            );
          },
          theme: NexoTheme.light(),
          home: _Gate(session: session, store: store, theme: theme),
        );
      },
    );
  }
}

/// Compuerta: muestra Términos en el primer arranque, luego el flujo normal.
class _Gate extends StatefulWidget {
  const _Gate({
    required this.session,
    required this.store,
    required this.theme,
  });
  final SessionService session;
  final AppStore store;
  final ThemeController theme;

  @override
  State<_Gate> createState() => _GateState();
}

class _GateState extends State<_Gate> {
  bool _accepted = AppStorage.instance.acceptedTerms;
  bool _seenOnboarding = AppStorage.instance.seenOnboarding;

  @override
  Widget build(BuildContext context) {
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
          final showOnboarding = !_seenOnboarding &&
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
                ),
              SessionStatus.unauthenticated =>
                LoginScreen(session: widget.session),
            };
          }
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            switchInCurve: Curves.easeOutCubic,
            transitionBuilder: (c, anim) =>
                FadeTransition(opacity: anim, child: c),
            child: KeyedSubtree(key: ValueKey(k), child: child),
          );
        },
      );
      key = 'app';
    }

    return ListenableBuilder(
      listenable: widget.theme,
      builder: (context, _) {
        // Aseguramos que las variables estáticas se actualicen ANTES de construir la UI
        NexoTheme.apply(widget.theme.resolvedDark(context));

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (c, anim) => FadeTransition(opacity: anim, child: c),
          child: KeyedSubtree(key: ValueKey(key), child: gated),
        );
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
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: Tween(begin: 0.92, end: 1.04).animate(
                CurvedAnimation(parent: _c, curve: Curves.easeInOut),
              ),
              child: const AppLogo(size: 72),
            ),
            const SizedBox(height: 20),
            const Text(
              'Nexo',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
