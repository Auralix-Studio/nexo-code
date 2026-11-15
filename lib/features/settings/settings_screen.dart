import 'package:flutter/material.dart';
import 'package:nexo/core/app_locale.dart';
import 'package:nexo/core/config.dart';
import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/design/theme_controller.dart';
import 'package:nexo/core/storage.dart';
import 'package:nexo/data/app_store.dart';
import 'package:nexo/data/services/push_service.dart';
import 'package:nexo/data/services/update_service.dart';
import 'package:nexo/features/notifications/notifications_screen.dart';
import 'package:nexo/features/settings/typography_card.dart';
import 'package:nexo/l10n/app_localizations.dart';
import 'package:nexo/shared/widgets/section_card.dart';
import 'package:nexo/core/design/tokens.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.store, required this.theme});
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
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                _AppearanceCard(theme: theme),
                const SizedBox(height: AppSpacing.cozy),
                TypographyCard(theme: theme),
                const SizedBox(height: AppSpacing.cozy),
                _PreferencesCard(theme: theme),
                const SizedBox(height: AppSpacing.cozy),
                _NotificationsCard(store: store),
                const _GradePushCard(),
                const SizedBox(height: AppSpacing.cozy),
                const UpdateCard(),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
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
              const SizedBox(height: AppSpacing.md),
              Text(
                l.settingsPalette.toUpperCase(),
                style: TextStyle(
                  fontSize: AppFont.caption,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: NexoTheme.textMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.snug),
              LayoutBuilder(
                builder: (ctx, c) {
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
                },
              ),
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
      borderRadius: AppRadii.rLg,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.cozy,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: selected
              ? NexoTheme.primary.withValues(alpha: AppOpacity.soft)
              : NexoTheme.bg,
          borderRadius: AppRadii.rLg,
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
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: AppFont.body,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? NexoTheme.primary
                          : NexoTheme.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: AppFont.small,
                      color: NexoTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(
                Icons.check_circle_rounded,
                size: AppIcon.lg,
                color: NexoTheme.primary,
              ),
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
      borderRadius: AppRadii.rLg,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: NexoTheme.bg,
          borderRadius: AppRadii.rLg,
          border: Border.all(
            color: selected ? NexoTheme.primary : NexoTheme.border,
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Row(
          children: [
            _PalettePreview(palette: palette),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    palette.label,
                    style: TextStyle(
                      fontSize: AppFont.small,
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
                        fontSize: AppFont.micro,
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
            left: 6,
            top: 22,
            right: 6,
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
            left: 6,
            top: 6,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: palette.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: 22,
            top: 6,
            child: Container(
              width: 12,
              height: 12,
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
                  fontSize: AppFont.caption,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: NexoTheme.textMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.snug),
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
                      const SizedBox(width: AppSpacing.sm),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.roomy),
              Text(
                l.timeFormat.toUpperCase(),
                style: TextStyle(
                  fontSize: AppFont.caption,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: NexoTheme.textMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.snug),
              Row(
                children: [
                  Expanded(
                    child: _PrefChip(
                      label: l.hours24,
                      selected: theme.use24h,
                      onTap: () => theme.setUse24h(true),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _PrefChip(
                      label: l.hours12,
                      selected: !theme.use24h,
                      onTap: () => theme.setUse24h(false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.roomy),
              const _FestivityToggle(),
            ],
          ),
        );
      },
    );
  }
}

class _FestivityToggle extends StatefulWidget {
  const _FestivityToggle();
  @override
  State<_FestivityToggle> createState() => _FestivityToggleState();
}

class _FestivityToggleState extends State<_FestivityToggle> {
  Future<void> _set(bool v) async {
    await AppStorage.instance.setFestivityDecor(v);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final on = AppStorage.instance.festivityDecor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'ADORNOS DE FESTIVIDADES',
          style: TextStyle(
            fontSize: AppFont.caption,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: NexoTheme.textMuted,
          ),
        ),
        const SizedBox(height: AppSpacing.snug),
        Row(
          children: [
            Expanded(
              child: _PrefChip(
                label: 'Activado',
                selected: on,
                onTap: () => _set(true),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _PrefChip(
                label: 'Desactivado',
                selected: !on,
                onTap: () => _set(false),
              ),
            ),
          ],
        ),
      ],
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
      borderRadius: AppRadii.rMd,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: selected
              ? NexoTheme.primary.withValues(alpha: AppOpacity.tint)
              : NexoTheme.bg,
          borderRadius: AppRadii.rMd,
          border: Border.all(
            color: selected ? NexoTheme.primary : NexoTheme.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: AppFont.label,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? NexoTheme.primary : NexoTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

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
            color: NexoTheme.primary.withValues(alpha: AppOpacity.tint),
            borderRadius: AppRadii.rSm,
          ),
          child: Icon(
            Icons.notifications_active_outlined,
            color: NexoTheme.primary,
            size: AppIcon.lg,
          ),
        ),
        title: Text(
          l.titleNotifications,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
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

/// Push de notas: solo aparece si el push funciona en este dispositivo y hay
/// un estudiante con sesión. El estado vive en el servidor
/// (`/me/notifications`).
class _GradePushCard extends StatelessWidget {
  const _GradePushCard();
  @override
  Widget build(BuildContext context) {
    final push = PushService.instance;
    if (push == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: push,
      builder: (context, _) => push.canManage
          ? Padding(
              padding: const EdgeInsets.only(top: AppSpacing.cozy),
              child: _GradePushSwitch(push: push),
            )
          : const SizedBox.shrink(),
    );
  }
}

class _GradePushSwitch extends StatefulWidget {
  const _GradePushSwitch({required this.push});
  final PushService push;
  @override
  State<_GradePushSwitch> createState() => _GradePushSwitchState();
}

class _GradePushSwitchState extends State<_GradePushSwitch> {
  bool? _enabled;
  bool _busy = false;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _loadFailed = false;
    });
    try {
      final enabled = await widget.push.gradesEnabled();
      if (mounted) setState(() => _enabled = enabled);
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _set(bool value) async {
    final previous = _enabled;
    setState(() {
      _enabled = value;
      _busy = true;
    });
    try {
      final saved = await widget.push.setGradesEnabled(value);
      if (mounted) setState(() => _enabled = saved);
    } catch (_) {
      if (!mounted) return;
      setState(() => _enabled = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).settingsPushGradesError),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final enabled = _enabled;
    return Card(
      child: SwitchListTile(
        secondary: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: NexoTheme.primary.withValues(alpha: AppOpacity.tint),
            borderRadius: AppRadii.rSm,
          ),
          child: Icon(
            Icons.school_outlined,
            color: NexoTheme.primary,
            size: AppIcon.lg,
          ),
        ),
        title: Text(
          l.settingsPushGrades,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          _loadFailed
              ? l.settingsPushGradesLoadError
              : l.settingsPushGradesSubtitle,
          style: TextStyle(color: NexoTheme.textSecondary),
        ),
        value: enabled ?? false,
        onChanged: _busy
            ? null
            : enabled == null
            ? (_) => _load()
            : _set,
      ),
    );
  }
}

class UpdateCard extends StatelessWidget {
  const UpdateCard({super.key});
  @override
  Widget build(BuildContext context) {
    // En la Store, Windows gestiona las actualizaciones: sin tarjeta propia.
    if (StoreBuild.isStore) return const SizedBox.shrink();
    final updater = UpdateService.instance;
    if (updater == null || !updater.isSupported) {
      return const SizedBox.shrink();
    }
    return ListenableBuilder(
      listenable: updater,
      builder: (context, _) {
        final l = AppLocalizations.of(context);
        final status = updater.currentStatus();
        final busy = updater.isBusy;
        return SectionCard(
          title: l.updTitle,
          icon: Icons.system_update_alt_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.updInstalledVersion,
                          style: TextStyle(
                            fontSize: AppFont.caption,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                            color: NexoTheme.textMuted,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          'Nexo ${AppConfig.appVersion}',
                          style: TextStyle(
                            fontSize: AppFont.subtitle,
                            fontWeight: FontWeight.w700,
                            color: NexoTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _StatusPill(status: status, busy: busy),
                ],
              ),
              const SizedBox(height: AppSpacing.cozy),
              _UpdateAction(updater: updater, status: status, busy: busy),
            ],
          ),
        );
      },
    );
  }
}

class _StatusPill extends StatelessWidget {
  final UpdateStatus status;
  final bool busy;
  const _StatusPill({required this.status, required this.busy});
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    late final String label;
    late final Color color;
    late final IconData icon;
    if (busy) {
      label = l.updStatusChecking;
      color = NexoTheme.textSecondary;
      icon = Icons.sync_rounded;
    } else {
      switch (status.state) {
        case UpdateState.ready:
        case UpdateState.available:
          label = l.updStatusAvailable;
          color = NexoTheme.primary;
          icon = Icons.new_releases_rounded;
        case UpdateState.upToDate:
          label = l.updStatusUpToDate;
          color = NexoTheme.success;
          icon = Icons.verified_rounded;
        case UpdateState.unknown:
        case UpdateState.unsupported:
          label = l.updStatusUnknown;
          color = NexoTheme.textMuted;
          icon = Icons.help_outline_rounded;
      }
    }
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.snug,
        vertical: AppSpacing.tight,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppOpacity.tint),
        borderRadius: AppRadii.rXxl,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: AppFont.caption,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _UpdateAction extends StatelessWidget {
  final UpdateService updater;
  final UpdateStatus status;
  final bool busy;
  const _UpdateAction({
    required this.updater,
    required this.status,
    required this.busy,
  });
  Future<void> _check(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final s = await updater.checkNow();
    if (!context.mounted) return;
    final msg = switch (s.state) {
      UpdateState.upToDate => l.updSnackUpToDate,
      UpdateState.available ||
      UpdateState.ready => l.updSnackAvailable(s.latestVersion ?? ''),
      _ => l.updSnackCheckFailed,
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _install(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final outcome = await updater.installDownloaded();
    if (!context.mounted) return;
    final msg = switch (outcome) {
      InstallOutcome.started => null,
      InstallOutcome.needsPermission => l.updSnackNeedsPermission,
      InstallOutcome.failed => l.updSnackInstallFailed,
    };
    if (msg == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final hasUpdate =
        status.state == UpdateState.available ||
        status.state == UpdateState.ready;
    if (hasUpdate) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.updAvailableLine(status.latestVersion ?? ''),
            style: TextStyle(
              fontSize: AppFont.label,
              color: NexoTheme.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.snug),
          FilledButton.icon(
            onPressed: busy ? null : () => _install(context),
            icon: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_rounded, size: AppIcon.md),
            label: Text(
              status.state == UpdateState.ready
                  ? l.updInstallNow
                  : l.updDownloadInstall,
            ),
          ),
        ],
      );
    }
    return OutlinedButton.icon(
      onPressed: busy ? null : () => _check(context),
      icon: busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.refresh_rounded, size: AppIcon.md),
      label: Text(l.updCheck),
    );
  }
}
