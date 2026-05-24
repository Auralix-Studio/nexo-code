import 'package:flutter/material.dart';

import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/design/theme_controller.dart';
import 'package:nexo/core/shortcuts.dart';
import 'package:nexo/data/app_store.dart';
import 'package:nexo/data/session.dart';
import 'package:nexo/features/grades/grades_screen.dart';
import 'package:nexo/features/home/home_screen.dart';
import 'package:nexo/features/payments/payments_screen.dart';
import 'package:nexo/features/profile/profile_screen.dart';
import 'package:nexo/features/schedule/schedule_screen.dart';

class _Tab {
  final String label;
  final IconData icon;
  final IconData iconOutlined;
  const _Tab(this.label, this.icon, this.iconOutlined);
}

const _tabs = [
  _Tab('Inicio', Icons.home_rounded, Icons.home_outlined),
  _Tab('Horario', Icons.calendar_today_rounded, Icons.calendar_today_outlined),
  _Tab('Notas', Icons.school_rounded, Icons.school_outlined),
  _Tab('Pagos', Icons.account_balance_wallet_rounded,
      Icons.account_balance_wallet_outlined),
  _Tab('Perfil', Icons.person_rounded, Icons.person_outline_rounded),
];

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.store,
    required this.session,
    required this.theme,
  });

  final AppStore store;
  final SessionService session;
  final ThemeController theme;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  final List<int> _history = [0];

  final List<ScrollController> _scrollControllers = List.generate(5, (_) => ScrollController());

  @override
  void initState() {
    super.initState();
    // Carga datos esenciales al entrar.
    widget.store.loadHomeEssentials();

    // Escucha acciones directas (shortcuts).
    ShortcutService.instance.addListener(_handleShortcut);
    _handleShortcut(); // Procesa si ya hay una pendiente.
  }

  @override
  void dispose() {
    ShortcutService.instance.removeListener(_handleShortcut);
    for (final c in _scrollControllers) {
      c.dispose();
    }
    super.dispose();
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
    final pages = [
      PrimaryScrollController(
        controller: _scrollControllers[0],
        child: HomeScreen(store: widget.store, onJump: _goTo),
      ),
      PrimaryScrollController(
        controller: _scrollControllers[1],
        child: ScheduleScreen(store: widget.store),
      ),
      PrimaryScrollController(
        controller: _scrollControllers[2],
        child: GradesScreen(store: widget.store),
      ),
      PrimaryScrollController(
        controller: _scrollControllers[3],
        child: PaymentsScreen(store: widget.store),
      ),
      PrimaryScrollController(
        controller: _scrollControllers[4],
        child: ProfileScreen(
          store: widget.store,
          session: widget.session,
          theme: widget.theme,
        ),
      ),
    ];

    Widget child;
    if (isDesktop) {
      child = Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              _SideRail(
                index: _index,
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
                    key: ValueKey(_index),
                    child: pages[_index],
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
              key: ValueKey(_index),
              child: pages[_index],
            ),
          ),
        ),
        bottomNavigationBar: _BottomBar(index: _index, onChange: _goTo),
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
  final int index;
  final ValueChanged<int> onChange;
  const _BottomBar({required this.index, required this.onChange});

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
              for (var i = 0; i < _tabs.length; i++)
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
                              i == index ? _tabs[i].icon : _tabs[i].iconOutlined,
                              key: ValueKey(i == index),
                              color: i == index
                                  ? NexoTheme.primary
                                  : NexoTheme.textMuted,
                              size: 24,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _tabs[i].label,
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
  final int index;
  final ValueChanged<int> onChange;
  final Future<void> Function() onLogout;
  const _SideRail({
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
          for (var i = 0; i < _tabs.length; i++) ...[
            _RailItem(
              tab: _tabs[i],
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
              label: const Text('Cerrar sesión'),
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
  const _RailItem({required this.tab, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Material(
        color: active ? NexoTheme.primary.withValues(alpha: 0.10) : Colors.transparent,
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
