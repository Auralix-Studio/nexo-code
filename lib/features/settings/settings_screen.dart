import 'package:flutter/material.dart';

import 'package:nexo/core/app_locale.dart';
import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/design/theme_controller.dart';
import 'package:nexo/data/app_store.dart';
import 'package:nexo/features/notifications/notifications_screen.dart';
import 'package:nexo/l10n/app_localizations.dart';
import 'package:nexo/shared/widgets/section_card.dart';

/// Pantalla de Configuración común a estudiante y docente.
/// Centraliza Apariencia, Idioma, Formato de hora y Notificaciones.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.store,
    required this.theme,
  });
  final AppStore store;
  final ThemeController theme;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _AppearanceCard(theme: theme),
                const SizedBox(height: 14),
                _PreferencesCard(theme: theme),
                const SizedBox(height: 14),
                _NotificationsCard(store: store),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ===== Apariencia (paletas) =====

class _AppearanceCard extends StatelessWidget {
  final ThemeController theme;
  const _AppearanceCard({required this.theme});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: theme,
      builder: (context, _) {
        final selection = theme.selection;
        final l = AppLocalizations.of(context);
        return SectionCard(
          title: l.settingsAppearance,
          icon: Icons.palette_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SystemOption(
                title: l.settingsSystem,
                subtitle: l.settingsSystemDesc,
                selected: selection == 'system',
                onTap: () => theme.setSelection('system'),
              ),
              const SizedBox(height: 12),
              Text(
                l.settingsPalette.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: NexoTheme.textMuted,
                ),
              ),
              const SizedBox(height: 10),
              LayoutBuilder(builder: (ctx, c) {
                final cols = c.maxWidth >= 480 ? 3 : 2;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: NexoColors.all.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    mainAxisExtent: 96,
                  ),
                  itemBuilder: (_, i) {
                    final palette = NexoColors.all[i];
                    return _PaletteTile(
                      palette: palette,
                      selected: selection == palette.id,
                      activeLabel: l.settingsActive,
                      onTap: () => theme.setSelection(palette.id),
                    );
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class _SystemOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  const _SystemOption({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? NexoTheme.primary.withValues(alpha: 0.10)
              : NexoTheme.bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? NexoTheme.primary : NexoTheme.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.brightness_auto_rounded,
              color: selected ? NexoTheme.primary : NexoTheme.textSecondary,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color:
                          selected ? NexoTheme.primary : NexoTheme.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: NexoTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded,
                  size: 20, color: NexoTheme.primary),
          ],
        ),
      ),
    );
  }
}

class _PaletteTile extends StatelessWidget {
  final NexoColors palette;
  final bool selected;
  final String activeLabel;
  final VoidCallback onTap;
  const _PaletteTile({
    required this.palette,
    required this.selected,
    required this.activeLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: NexoTheme.bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? NexoTheme.primary : NexoTheme.border,
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Row(
          children: [
            _PalettePreview(palette: palette),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    palette.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? NexoTheme.primary
                          : NexoTheme.textPrimary,
                    ),
                  ),
                  if (selected)
                    Text(
                      activeLabel,
                      style: TextStyle(
                        fontSize: 10,
                        color: NexoTheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PalettePreview extends StatelessWidget {
  final NexoColors palette;
  const _PalettePreview({required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: palette.border),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 6, top: 22, right: 6,
            child: Container(
              height: 14,
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: palette.border),
              ),
            ),
          ),
          Positioned(
            left: 6, top: 6,
            child: Container(
              width: 12, height: 12,
              decoration: BoxDecoration(
                color: palette.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: 22, top: 6,
            child: Container(
              width: 12, height: 12,
              decoration: BoxDecoration(
                color: palette.accent,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===== Idioma + Formato de hora =====

class _PreferencesCard extends StatelessWidget {
  final ThemeController theme;
  const _PreferencesCard({required this.theme});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: theme,
      builder: (context, _) {
        final l = AppLocalizations.of(context);
        return SectionCard(
          title: '${l.language} / ${l.timeFormat}',
          icon: Icons.tune_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.language.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: NexoTheme.textMuted,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (final loc in AppLocale.values) ...[
                    Expanded(
                      child: _PrefChip(
                        label: loc.label,
                        selected: theme.locale == loc,
                        onTap: () => theme.setLocale(loc),
                      ),
                    ),
                    if (loc != AppLocale.values.last)
                      const SizedBox(width: 8),
                  ],
                ],
              ),
              const SizedBox(height: 18),
              Text(
                l.timeFormat.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: NexoTheme.textMuted,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _PrefChip(
                      label: l.hours24,
                      selected: theme.use24h,
                      onTap: () => theme.setUse24h(true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _PrefChip(
                      label: l.hours12,
                      selected: !theme.use24h,
                      onTap: () => theme.setUse24h(false),
                    ),
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

class _PrefChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _PrefChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? NexoTheme.primary.withValues(alpha: 0.12)
              : NexoTheme.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? NexoTheme.primary : NexoTheme.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? NexoTheme.primary : NexoTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

// ===== Notificaciones (link) =====

class _NotificationsCard extends StatelessWidget {
  final AppStore store;
  const _NotificationsCard({required this.store});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Card(
      child: ListTile(
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: NexoTheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.notifications_active_outlined,
              color: NexoTheme.primary, size: 20),
        ),
        title: Text(l.titleNotifications,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          l.settingsNotificationsSubtitle,
          style: TextStyle(color: NexoTheme.textSecondary),
        ),
        trailing: Icon(Icons.chevron_right, color: NexoTheme.textMuted),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => NotificationsScreen(store: store),
          ),
        ),
      ),
    );
  }
}

