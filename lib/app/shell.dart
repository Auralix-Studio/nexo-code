import 'package:flutter/material.dart';
import 'package:nexo/l10n/app_localizations.dart';

import 'package:nexo/ai/lumen_services.dart';
import 'package:nexo/data/connectivity_service.dart';

import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/design/theme_controller.dart';
import 'package:nexo/core/shortcuts.dart';
import 'package:nexo/data/app_store.dart';
import 'package:nexo/data/ms_auth_service.dart';
import 'package:nexo/data/session.dart';
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

  final List<ScrollController> _scrollControllers = List.generate(
    7,
    (_) => ScrollController(),
  );

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
    final isDesktop = Responsive.isDesktop(context);
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
        )),
      ];
    }

    final safeIndex = _index.clamp(0, pages.length - 1);

    Widget child;
    if (isDesktop) {
      child = Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              _SideRail(
                tabs: tabs,
                index: safeIndex,
                onChange: _goTo,
                onLogout: widget.session.logout,
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: KeyedSubtree(
                    key: ValueKey(safeIndex),
                    child: pages[safeIndex],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      child = Scaffold(
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: KeyedSubtree(
              key: ValueKey(safeIndex),
              child: pages[safeIndex],
            ),
          ),
        ),
        bottomNavigationBar:
            _BottomBar(tabs: tabs, index: safeIndex, onChange: _goTo),
      );
    }

    // Usamos PopScope para interceptar el botón "Atrás" en Android
    // y navegar por el historial de pestañas en lugar de cerrar la app.
    return PopScope(
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
    );
  }

  void _goTo(int i) {
    if (_index == i) return;
    setState(() {
      _history.remove(i);
      _history.add(i);
      _index = i;
    });
  }
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
    return Container(
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
  const _SideRail({
    required this.tabs,
    required this.index,
    required this.onChange,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 232,
      color: NexoTheme.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
            child: Row(
              children: [
                Image.asset(
                  'assets/icon.png',
                  width: 36,
                  height: 36,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 10),
                Text(
                  'Nexo',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: NexoTheme.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < tabs.length; i++) ...[
            _RailItem(
              tab: tabs[i],
              active: i == index,
              onTap: () => onChange(i),
            ),
            const SizedBox(height: 4),
          ],
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: OutlinedButton.icon(
              onPressed: onLogout,
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: Text(AppLocalizations.of(context).actionLogout),
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
  final VoidCallback onTap;
  const _RailItem({
    required this.tab,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Material(
        color: active
            ? NexoTheme.primary.withValues(alpha: 0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  active ? tab.icon : tab.iconOutlined,
                  color: active ? NexoTheme.primary : NexoTheme.textSecondary,
                  size: 22,
                ),
                const SizedBox(width: 14),
                Text(
                  tab.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active ? NexoTheme.primary : NexoTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
