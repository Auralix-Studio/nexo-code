import 'package:flutter/material.dart';

import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/design/theme_controller.dart';
import 'package:nexo/data/app_store.dart';
import 'package:nexo/data/session.dart';
import 'package:nexo/domain/models.dart';
import 'package:nexo/features/legal/terms_screen.dart';
import 'package:nexo/features/notifications/notifications_screen.dart';
import 'package:nexo/shared/widgets/page_scaffold.dart';
import 'package:nexo/shared/widgets/section_card.dart';
import 'package:nexo/shared/widgets/student_avatar.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.store,
    required this.session,
    required this.theme,
  });

  final AppStore store;
  final SessionService session;
  final ThemeController theme;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final p = store.profile.value;
        return RefreshIndicator(
          onRefresh: () => store.loadProfile().then((_) {}),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics()),
            slivers: [
              const SliverToBoxAdapter(child: PageHeader(title: 'Perfil')),
              SliverToBoxAdapter(
                child: PageBody(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _HeroCard(
                        profile: p,
                        promedio: store.promedioAcumulado,
                        creditosAprob: store.creditosAprobados,
                        creditosTotal: store.creditosTotales,
                      ),
                      const SizedBox(height: 14),
                      _AcademicCard(profile: p),
                      const SizedBox(height: 14),
                      _AppearanceCard(theme: theme),
                      const SizedBox(height: 14),
                      _ActionsCard(onLogout: session.logout, store: store),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        );
      },
    );
  }
}

class _HeroCard extends StatelessWidget {
  final StudentProfile? profile;
  final double? promedio;
  final int? creditosAprob;
  final int? creditosTotal;
  const _HeroCard({
    required this.profile,
    required this.promedio,
    required this.creditosAprob,
    required this.creditosTotal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [NexoTheme.primary, NexoTheme.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: NexoTheme.primary.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StudentAvatar(
                codigo: profile?.estId,
                nombre: profile?.estudiante ?? '',
                size: 72,
                radius: 22,
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.25),
                    Colors.white.withValues(alpha: 0.12),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderColor: Colors.white.withValues(alpha: 0.3),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile == null ? '...' : profile!.estudiante,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile?.estId ?? '',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _heroStat(
                'PROMEDIO',
                promedio == null ? '—' : promedio!.toStringAsFixed(2),
              ),
              _heroDivider(),
              _heroStat(
                'CRÉDITOS',
                creditosAprob == null
                    ? '—'
                    : creditosTotal != null && creditosTotal! > 0
                        ? '$creditosAprob/$creditosTotal'
                        : '$creditosAprob',
              ),
              _heroDivider(),
              _heroStat('NIVEL', profile?.nivel ?? '—'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroStat(String label, String value) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      );

  Widget _heroDivider() => Container(
        width: 1,
        height: 36,
        color: Colors.white.withValues(alpha: 0.18),
        margin: const EdgeInsets.symmetric(horizontal: 12),
      );
}

class _AcademicCard extends StatelessWidget {
  final StudentProfile? profile;
  const _AcademicCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final items = <_InfoItem>[
      _InfoItem(
        icon: Icons.menu_book_outlined,
        label: 'Carrera',
        value: p?.carrera ?? '—',
        wide: true,
        color: NexoTheme.primary,
      ),
      _InfoItem(
        icon: Icons.account_balance_outlined,
        label: 'Facultad',
        value: p?.facultad ?? '—',
        wide: true,
      ),
      _InfoItem(
        icon: Icons.location_city_outlined,
        label: 'Sede',
        value: p?.sede ?? '—',
      ),
      _InfoItem(
        icon: Icons.video_camera_back_outlined,
        label: 'Modalidad',
        value: p?.modalidad ?? '—',
      ),
      _InfoItem(
        icon: Icons.bookmark_outline,
        label: 'Plan de estudios',
        value: p?.pesId ?? '—',
      ),
      _InfoItem(
        icon: Icons.layers_outlined,
        label: 'Nivel',
        value: p?.nivel ?? '—',
      ),
      _InfoItem(
        icon: Icons.event_available_outlined,
        label: 'Última matrícula',
        value: p?.ultimaMatricula ?? '—',
      ),
      _InfoItem(
        icon: p?.matriculado == true
            ? Icons.check_circle_outline
            : Icons.cancel_outlined,
        label: 'Estado',
        value: p?.matriculado == true ? 'Matriculado' : 'No matriculado',
        color:
            p?.matriculado == true ? NexoTheme.success : NexoTheme.danger,
      ),
    ];

    return SectionCard(
      title: 'Información académica',
      icon: Icons.school_outlined,
      child: LayoutBuilder(builder: (ctx, c) {
        final twoCols = c.maxWidth >= 540;
        final tiles = <Widget>[];
        for (var i = 0; i < items.length; i++) {
          final item = items[i];
          tiles.add(_InfoTile(item: item));
        }
        if (!twoCols) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                tiles[i],
                if (i < tiles.length - 1) const SizedBox(height: 8),
              ],
            ],
          );
        }
        // Dos columnas: los items con wide:true ocupan toda la fila.
        final rows = <Widget>[];
        var i = 0;
        while (i < items.length) {
          final current = items[i];
          if (current.wide) {
            rows.add(_InfoTile(item: current));
            i++;
          } else if (i + 1 < items.length && !items[i + 1].wide) {
            rows.add(IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _InfoTile(item: items[i])),
                  const SizedBox(width: 8),
                  Expanded(child: _InfoTile(item: items[i + 1])),
                ],
              ),
            ));
            i += 2;
          } else {
            rows.add(_InfoTile(item: items[i]));
            i++;
          }
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var k = 0; k < rows.length; k++) ...[
              rows[k],
              if (k < rows.length - 1) const SizedBox(height: 8),
            ],
          ],
        );
      }),
    );
  }
}

class _InfoItem {
  final IconData icon;
  final String label;
  final String value;
  final bool wide;
  final Color? color;
  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
    this.wide = false,
    this.color,
  });
}

class _InfoTile extends StatelessWidget {
  final _InfoItem item;
  const _InfoTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final color = item.color ?? NexoTheme.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NexoTheme.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NexoTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(item.icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: NexoTheme.textMuted,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: item.color ?? NexoTheme.textPrimary,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AppearanceCard extends StatelessWidget {
  final ThemeController theme;
  const _AppearanceCard({required this.theme});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: theme,
      builder: (context, _) {
        final mode = theme.mode;
        return SectionCard(
          title: 'Apariencia',
          icon: Icons.palette_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _ModeOption(
                    label: 'Claro',
                    icon: Icons.light_mode_rounded,
                    selected: mode == ThemeMode.light,
                    onTap: () => theme.set(ThemeMode.light),
                  ),
                  const SizedBox(width: 8),
                  _ModeOption(
                    label: 'Oscuro',
                    icon: Icons.dark_mode_rounded,
                    selected: mode == ThemeMode.dark,
                    onTap: () => theme.set(ThemeMode.dark),
                  ),
                  const SizedBox(width: 8),
                  _ModeOption(
                    label: 'Sistema',
                    icon: Icons.brightness_auto_rounded,
                    selected: mode == ThemeMode.system,
                    onTap: () => theme.set(ThemeMode.system),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ModeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _ModeOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: selected
                ? NexoTheme.primary.withValues(alpha: 0.12)
                : NexoTheme.bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? NexoTheme.primary : NexoTheme.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 22,
                color:
                    selected ? NexoTheme.primary : NexoTheme.textSecondary,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color:
                      selected ? NexoTheme.primary : NexoTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionsCard extends StatelessWidget {
  final Future<void> Function() onLogout;
  final AppStore store;
  const _ActionsCard({required this.onLogout, required this.store});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: NexoTheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.notifications_active_outlined,
                  color: NexoTheme.primary, size: 20),
            ),
            title: const Text(
              'Notificaciones',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text('Clases, pagos y notas',
                style: TextStyle(color: NexoTheme.textSecondary)),
            trailing:
                Icon(Icons.chevron_right, color: NexoTheme.textMuted),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => NotificationsScreen(store: store),
              ),
            ),
          ),
          const Divider(height: 1, indent: 70),
          ListTile(
            leading: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: NexoTheme.info.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child:
                  const Icon(Icons.info_outline, color: NexoTheme.info, size: 20),
            ),
            title: const Text(
              'Acerca de Nexo',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text('Versión 0.1.0',
                style: TextStyle(color: NexoTheme.textSecondary)),
            trailing: Icon(Icons.chevron_right,
                color: NexoTheme.textMuted),
            onTap: () => showAboutDialog(
              context: context,
              applicationName: 'Nexo · UPLA',
              applicationVersion: '0.1.0',
              applicationLegalese:
                  'Cliente no oficial creado por y para estudiantes UPLA.',
            ),
          ),
          const Divider(height: 1, indent: 70),
          ListTile(
            leading: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: NexoTheme.info.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.privacy_tip_outlined,
                  color: NexoTheme.info, size: 20),
            ),
            title: const Text(
              'Términos y privacidad',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            trailing:
                Icon(Icons.chevron_right, color: NexoTheme.textMuted),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const TermsScreen(),
              ),
            ),
          ),
          const Divider(height: 1, indent: 70),
          ListTile(
            leading: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: NexoTheme.danger.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.logout_rounded,
                  color: NexoTheme.danger, size: 20),
            ),
            title: const Text(
              'Cerrar sesión',
              style: TextStyle(
                color: NexoTheme.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Cerrar sesión'),
                  content: const Text('¿Quieres salir de tu cuenta?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancelar'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: TextButton.styleFrom(
                          foregroundColor: NexoTheme.danger),
                      child: const Text('Cerrar sesión'),
                    ),
                  ],
                ),
              );
              if (ok == true) await onLogout();
            },
          ),
        ],
      ),
    );
  }
}
