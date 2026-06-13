import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexo/l10n/app_localizations.dart';

import 'package:nexo/ai/lumen_services.dart';
import 'package:nexo/data/connectivity_service.dart';
import 'package:nexo/features/ai/lumen_fab_overlay.dart';

import 'package:nexo/core/design/breakpoints.dart';
import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/design/theme_controller.dart';
import 'package:nexo/core/shortcuts.dart';
import 'package:nexo/data/app_store.dart';
import 'package:nexo/data/ms_auth_service.dart';
import 'package:nexo/data/session.dart';
import 'package:nexo/features/festivity/festivity_overlay.dart';
import 'package:nexo/features/docente/docente_cursos_screen.dart';
import 'package:nexo/features/docente/docente_horario_screen.dart';
import 'package:nexo/features/docente/docente_profile_screen.dart';
import 'package:nexo/features/docente/docente_screen.dart';
import 'package:nexo/features/grades/grades_screen.dart';
import 'package:nexo/features/home/home_screen.dart';
import 'package:nexo/features/payments/payments_screen.dart';
import 'package:nexo/features/profile/profile_screen.dart';
import 'package:nexo/features/schedule/schedule_screen.dart';
import 'package:nexo/features/teams/teams_screen.dart';
import 'package:nexo/shared/widgets/update_banner.dart';
import 'package:nexo/shared/widgets/whatsapp_invite_dialog.dart';

class _Tab {
  final String label;
  final IconData icon;
  final IconData iconOutlined;
  const _Tab(this.label, this.icon, this.iconOutlined);
}

/// Tabs del alumno (experiencia normal del estudiante).
List<_Tab> _studentTabs(AppLocalizations l) => [
      _Tab(l.tabHome, Icons.home_rounded, Icons.home_outlined),
      _Tab(l.tabSchedule, Icons.calendar_today_rounded,
          Icons.calendar_today_outlined),
      _Tab(l.tabGrades, Icons.school_rounded, Icons.school_outlined),
      _Tab(l.tabPayments, Icons.account_balance_wallet_rounded,
          Icons.account_balance_wallet_outlined),
    _Tab(l.tabTeams, Icons.groups_rounded, Icons.groups_outlined),
      _Tab(l.tabProfile, Icons.person_rounded, Icons.person_outline_rounded),
    ];

/// Tabs del docente (experiencia completamente distinta — sin pagos, notas
/// del alumno, ni Teams del estudiante). Cada pestaña es una pantalla
/// separada con su propio scope, igual que la separación del alumno.
List<_Tab> _teacherTabs(AppLocalizations l) => [
      _Tab(l.tabHome, Icons.dashboard_rounded, Icons.dashboard_outlined),
      _Tab(l.tabCourses, Icons.menu_book_rounded, Icons.menu_book_outlined),
      _Tab(l.tabSchedule, Icons.calendar_today_rounded,
          Icons.calendar_today_outlined),
      _Tab(l.tabProfile, Icons.person_rounded, Icons.person_outline_rounded),
    ];

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.store,
    required this.session,
    required this.theme,
    required this.msAuth,
    required this.connectivity,
    required this.lumen,
  });

  final AppStore store;
  final SessionService session;
  final ThemeController theme;
  final MsAuthService msAuth;
  final ConnectivityService connectivity;
  final LumenServices lumen;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _index = 0;
  final List<int> _history = [0];
  DateTime? _lastBoletaCheck;

  /// Sidebar colapsado a solo iconos (escritorio).
  bool _railCollapsed = false;

  /// Un Navigator anidado por pestaña: el detalle se abre DENTRO del área de
  /// contenido (el sidebar nunca se tapa) y cada pestaña conserva su pila.
  final List<GlobalKey<NavigatorState>> _tabNavKeys =
      List.generate(7, (_) => GlobalKey<NavigatorState>());

  /// Breadcrumb por pestaña: título del detalle abierto (null = en la raíz).
  final List<String?> _breadcrumbs = List.filled(7, null);

  /// Pestañas ya visitadas — para montar su contenido de forma lazy en el
  /// IndexedStack (no cargar datos de pestañas que el usuario no abrió).
  final Set<int> _visitedTabs = {0};

  final List<ScrollController> _scrollControllers = List.generate(
    7,
    (_) => ScrollController(),
  );

  void _setBreadcrumb(int tab, String? title) {
    if (_breadcrumbs[tab] == title) return;
    // Diferimos el setState: el observer del Navigator dispara durante la
    // navegación (potencialmente en fase de build).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _breadcrumbs[tab] != title) {
        setState(() => _breadcrumbs[tab] = title);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    // En modo docente NO cargamos data del alumno (SIGMA/Intranet rechazaría
    // el token y nos echaría a login).
    final isDocente = widget.session.user?.isDocente ?? false;
    if (!isDocente) {
      widget.store.loadHomeEssentials();
    }
    _lastBoletaCheck = DateTime.now();

    WidgetsBinding.instance.addObserver(this);

    ShortcutService.instance.addListener(_handleShortcut);
    _handleShortcut();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) maybeShowWhatsappInvite(context);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ShortcutService.instance.removeListener(_handleShortcut);
    for (final c in _scrollControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // No chequeamos boleta del alumno en modo docente.
    if (widget.session.user?.isDocente ?? false) return;
    final now = DateTime.now();
    if (_lastBoletaCheck != null &&
        now.difference(_lastBoletaCheck!) < const Duration(seconds: 60)) {
      return;
    }
    _lastBoletaCheck = now;
    widget.store.checkActiveBoleta();
  }

  void _handleShortcut() {
    final action = ShortcutService.instance.pendingAction;
    if (action != null) {
      final index = switch (action) {
        AppShortcutType.schedule => 1,
        AppShortcutType.grades => 2,
        AppShortcutType.payments => 3,
      };
      _goTo(index);
      ShortcutService.instance.consume();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = context.isDesktop;
    final isDocente = widget.session.user?.isDocente ?? false;
    final l = AppLocalizations.of(context);

    var idx = 0;
    Widget wrap(Widget page) => PrimaryScrollController(
        controller: _scrollControllers[idx++], child: page);

    final List<_Tab> tabs;
    final List<Widget> pages;

    if (isDocente) {
      tabs = _teacherTabs(l);
      pages = <Widget>[
        wrap(DocenteScreen(store: widget.store)),
        wrap(DocenteCursosScreen(store: widget.store)),
        wrap(DocenteHorarioScreen(store: widget.store)),
        wrap(DocenteProfileScreen(
          store: widget.store,
          session: widget.session,
          theme: widget.theme,
          lumen: widget.lumen,
        )),
      ];
    } else {
      tabs = _studentTabs(l);
      pages = <Widget>[
        wrap(HomeScreen(
          store: widget.store,
          connectivity: widget.connectivity,
          lumen: widget.lumen,
          onJump: _goTo,
        )),
        wrap(ScheduleScreen(store: widget.store)),
        wrap(GradesScreen(store: widget.store)),
        wrap(PaymentsScreen(store: widget.store)),
        wrap(TeamsScreen(store: widget.store, msAuth: widget.msAuth)),
        wrap(ProfileScreen(
          store: widget.store,
          session: widget.session,
          theme: widget.theme,
          lumen: widget.lumen,
        )),
      ];
    }

    final safeIndex = _index.clamp(0, pages.length - 1);

    Widget child;
    if (isDesktop) {
      // Cada pestaña vive en su propio Navigator anidado: el detalle se apila
      // DENTRO de este IndexedStack (área de contenido), nunca sobre el rail.
      final content = IndexedStack(
        index: safeIndex,
        children: [
          for (var i = 0; i < pages.length; i++)
            if (_visitedTabs.contains(i))
              _TabContent(
                navigatorKey: _tabNavKeys[i],
                root: pages[i],
                onBreadcrumb: (title) => _setBreadcrumb(i, title),
              )
            else
              const SizedBox.shrink(),
        ],
      );

      child = CallbackShortcuts(
        bindings: _tabShortcuts(tabs.length),
        child: Focus(
          autofocus: true,
          child: Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  const UpdateBanner(),
                  Expanded(
                    child: Row(
                      children: [
                        _SideRail(
                          tabs: tabs,
                          index: safeIndex,
                          onChange: _goTo,
                          onLogout: widget.session.logout,
                          collapsed: _railCollapsed,
                          onToggleCollapse: () =>
                              setState(() => _railCollapsed = !_railCollapsed),
                          breadcrumb: _breadcrumbs[safeIndex],
                        ),
                        const VerticalDivider(width: 1),
                        Expanded(
                          child: LumenFabOverlay(
                            services: widget.lumen,
                            bottomInset: 24,
                            rightInset: 24,
                            child: content,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } else {
      child = Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              const UpdateBanner(),
              Expanded(
                child: LumenFabOverlay(
                  services: widget.lumen,
                  // bottomInset un poco mayor para que el FAB no quede pegado
                  // a la nav inferior.
                  bottomInset: 12,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: KeyedSubtree(
                      key: ValueKey(safeIndex),
                      child: pages[safeIndex],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar:
            _BottomBar(tabs: tabs, index: safeIndex, onChange: _goTo),
      );
    }

    // Usamos PopScope para interceptar el botón "Atrás" en Android
    // y navegar por el historial de pestañas en lugar de cerrar la app.
    // FestivityOverlay superpone los adornos de la festividad activa (si hay).
    return FestivityOverlay(
      child: PopScope(
        canPop: _history.length <= 1,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (_history.length > 1) {
            setState(() {
              _history.removeLast();
              _index = _history.last;
            });
          }
        },
        child: child,
      ),
    );
  }

  /// Atajos de escritorio: `Ctrl/⌘ + número` salta directo a la pestaña N.
  Map<ShortcutActivator, VoidCallback> _tabShortcuts(int count) {
    const digits = <LogicalKeyboardKey>[
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit6,
      LogicalKeyboardKey.digit7,
      LogicalKeyboardKey.digit8,
      LogicalKeyboardKey.digit9,
    ];
    final n = count.clamp(0, digits.length);
    return {
      for (var i = 0; i < n; i++) ...{
        SingleActivator(digits[i], control: true): () => _goTo(i),
        SingleActivator(digits[i], meta: true): () => _goTo(i),
      },
    };
  }

  void _goTo(int i) {
    if (_index == i) {
      // Re-tocar la pestaña activa: si hay un detalle abierto en su Navigator
      // anidado, volver a la raíz (cerrar el detalle). En móvil el key no está
      // montado → no-op seguro.
      _tabNavKeys[i].currentState?.popUntil((r) => r.isFirst);
      return;
    }
    setState(() {
      _visitedTabs.add(i);
      _history.remove(i);
      _history.add(i);
      _index = i;
    });
  }
}

/// Aloja una pestaña en su propio [Navigator] anidado: el detalle se apila en
/// el área de contenido (sin tapar el rail) y reporta el breadcrumb.
class _TabContent extends StatefulWidget {
  const _TabContent({
    required this.navigatorKey,
    required this.root,
    required this.onBreadcrumb,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget root;
  final ValueChanged<String?> onBreadcrumb;

  @override
  State<_TabContent> createState() => _TabContentState();
}

class _TabContentState extends State<_TabContent> {
  late final _BreadcrumbObserver _observer =
      _BreadcrumbObserver((title) => widget.onBreadcrumb(title));

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: widget.navigatorKey,
      observers: [_observer],
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        builder: (_) => widget.root,
        settings: settings,
      ),
    );
  }
}

/// Reporta el título (`RouteSettings.name`) de la ruta superior del Navigator;
/// `null` cuando solo queda la raíz. Alimenta el breadcrumb del sidebar.
class _BreadcrumbObserver extends NavigatorObserver {
  _BreadcrumbObserver(this.onChange);
  final ValueChanged<String?> onChange;

  String? _titleOf(Route<dynamic>? route) {
    final name = route?.settings.name;
    if (name == null || name.isEmpty || name == '/') return null;
    return name;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      onChange(_titleOf(route));
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      onChange(_titleOf(previousRoute));
  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      onChange(_titleOf(previousRoute));
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      onChange(_titleOf(newRoute));
}

class _BottomBar extends StatelessWidget {
  final List<_Tab> tabs;
  final int index;
  final ValueChanged<int> onChange;
  const _BottomBar({
    required this.tabs,
    required this.index,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: NexoTheme.surface,
        border: Border(top: BorderSide(color: NexoTheme.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (var i = 0; i < tabs.length; i++)
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => onChange(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              i == index
                                  ? tabs[i].icon
                                  : tabs[i].iconOutlined,
                              key: ValueKey(i == index),
                              color: i == index
                                  ? NexoTheme.primary
                                  : NexoTheme.textMuted,
                              size: 24,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tabs[i].label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: i == index
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: i == index
                                  ? NexoTheme.primary
                                  : NexoTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SideRail extends StatelessWidget {
  final List<_Tab> tabs;
  final int index;
  final ValueChanged<int> onChange;
  final Future<void> Function() onLogout;
  final bool collapsed;
  final VoidCallback onToggleCollapse;
  final String? breadcrumb;
  const _SideRail({
    required this.tabs,
    required this.index,
    required this.onChange,
    required this.onLogout,
    required this.collapsed,
    required this.onToggleCollapse,
    this.breadcrumb,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      width: collapsed ? 68 : 232,
      color: NexoTheme.surface,
      child: Column(
        children: [
          // Encabezado: logo + wordmark (si expandido) + botón de colapso.
          Padding(
            padding: EdgeInsets.fromLTRB(collapsed ? 0 : 20, 18, collapsed ? 0 : 10, 18),
            child: Row(
              mainAxisAlignment:
                  collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                if (!collapsed) ...[
                  Image.asset('assets/icon.png',
                      width: 32,
                      height: 32,
                      cacheWidth: 96,
                      cacheHeight: 96,
                      fit: BoxFit.contain),
                  const SizedBox(width: 10),
                  const Expanded(child: FestivityWordmark()),
                ],
                IconButton(
                  tooltip: collapsed ? 'Expandir' : 'Colapsar',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    collapsed
                        ? Icons.chevron_right_rounded
                        : Icons.chevron_left_rounded,
                    size: 20,
                    color: NexoTheme.textMuted,
                  ),
                  onPressed: onToggleCollapse,
                ),
              ],
            ),
          ),
          for (var i = 0; i < tabs.length; i++) ...[
            _RailItem(
              tab: tabs[i],
              active: i == index,
              collapsed: collapsed,
              breadcrumb: i == index ? breadcrumb : null,
              onTap: () => onChange(i),
            ),
            const SizedBox(height: 4),
          ],
          const Spacer(),
          Padding(
            padding: EdgeInsets.fromLTRB(
                collapsed ? 8 : 16, 0, collapsed ? 8 : 16, 16),
            child: collapsed
                ? IconButton(
                    tooltip: l.actionLogout,
                    icon: const Icon(Icons.logout_rounded, size: 20),
                    color: NexoTheme.textSecondary,
                    onPressed: onLogout,
                  )
                : OutlinedButton.icon(
                    onPressed: onLogout,
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: Text(l.actionLogout),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: NexoTheme.textSecondary,
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: NexoTheme.border),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  final _Tab tab;
  final bool active;
  final bool collapsed;
  final String? breadcrumb;
  final VoidCallback onTap;
  const _RailItem({
    required this.tab,
    required this.active,
    required this.onTap,
    this.collapsed = false,
    this.breadcrumb,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? NexoTheme.primary : NexoTheme.textSecondary;
    final icon = Icon(active ? tab.icon : tab.iconOutlined, color: color, size: 22);

    // Etiqueta: "Horario" o, si hay detalle abierto, "Horario › Física".
    final Widget label = breadcrumb == null
        ? Text(
            tab.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
          )
        : Text.rich(
            TextSpan(children: [
              TextSpan(
                text: tab.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              TextSpan(
                text: '  ›  $breadcrumb',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: NexoTheme.textMuted,
                ),
              ),
            ]),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          );

    final content = collapsed
        ? Tooltip(
            message: breadcrumb == null ? tab.label : '${tab.label} › $breadcrumb',
            child: Center(child: icon),
          )
        : Row(
            children: [
              icon,
              const SizedBox(width: 14),
              Expanded(child: label),
            ],
          );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: collapsed ? 10 : 12),
      child: Material(
        color: active
            ? NexoTheme.primary.withValues(alpha: 0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: collapsed ? 0 : 14, vertical: 12),
            child: content,
          ),
        ),
      ),
    );
  }
}
