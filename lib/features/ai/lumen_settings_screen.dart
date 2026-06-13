import 'package:flutter/material.dart';

import 'package:nexo/ai/lumen_services.dart';
import 'package:nexo/ai/lumen_state.dart';
import 'package:nexo/core/config.dart';
import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/design/tokens.dart';

import 'lumen_logo.dart';
import 'lumen_onboarding_dialog.dart';

/// Pantalla de configuración dedicada a Lumen.
///
/// Antes esto vivía como una sección dentro del SettingsScreen global,
/// pero el usuario quiso tenerlo dentro del propio asistente — se accede
/// con el ícono ⚙ del AppBar del chat. La pantalla es completamente
/// self-contained.
class LumenSettingsScreen extends StatefulWidget {
  const LumenSettingsScreen({super.key, required this.services});

  final LumenServices services;

  @override
  State<LumenSettingsScreen> createState() => _LumenSettingsScreenState();
}

class _LumenSettingsScreenState extends State<LumenSettingsScreen> {
  Future<void> _activate() async {
    await LumenOnboardingDialog.show(context, widget.services);
    if (mounted) setState(() {});
  }

  Future<void> _switchModel() async {
    final lumen = widget.services;
    final picked = await showDialog<LumenModelSpec>(
      context: context,
      builder: (ctx) {
        var sel = lumen.state.activeModel;
        return StatefulBuilder(
          builder: (ctx, setStateDialog) => AlertDialog(
            title: const Text('Cambiar modelo de Lumen'),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final m in LumenConfig.models)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      enabled: m.isConfigured,
                      onTap: m.isConfigured
                          ? () => setStateDialog(() => sel = m)
                          : null,
                      leading: Icon(
                        sel.id == m.id
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: sel.id == m.id
                            ? NexoTheme.primary
                            : NexoTheme.textMuted,
                      ),
                      title: Text(m.displayName),
                      subtitle: Text(
                        '${(m.mobile.sizeBytes / (1024 * 1024)).toStringAsFixed(0)} '
                        'MB · ${m.tagline}'
                        '${m.isConfigured ? '' : ' · (no publicado)'}',
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'Cambiar de modelo borra el actual y descarga el nuevo. '
                    'Vas a necesitar internet para la descarga.',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: sel.id == lumen.state.activeModel.id
                    ? null
                    : () => Navigator.of(ctx).pop(sel),
                child: const Text('Cambiar'),
              ),
            ],
          ),
        );
      },
    );
    if (picked == null || !mounted) return;
    final prev = lumen.state.activeModel;
    await lumen.engine.unload();
    await lumen.modelManager.delete(prev);
    await lumen.switchModel(picked);
    if (!mounted) return;
    await LumenOnboardingDialog.show(context, lumen);
    if (mounted) setState(() {});
  }

  Future<void> _delete() async {
    final lumen = widget.services;
    final sizeMb = (lumen.state.activeModel.mobile.sizeBytes / (1024 * 1024))
        .toStringAsFixed(0);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Borrar modelo de Lumen'),
        content: Text(
          'Esto libera $sizeMb MB de tu dispositivo y desactiva Lumen. '
          'Podrás volver a descargar el modelo cuando quieras.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: NexoTheme.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await lumen.engine.unload();
    await lumen.modelManager.delete();
    await lumen.clearSession();
    if (mounted) {
      setState(() {});
      Navigator.of(context).maybePop(); // cerrar settings tras borrar
    }
  }

  Future<void> _clearHistory() async {
    final lumen = widget.services;
    await lumen.clearSession();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Historial de chat limpio.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: const Row(
          children: [
            LumenLogo(size: 28),
            Gap.h(AppSpacing.sm),
            Text('Configuración de Lumen'),
          ],
        ),
      ),
      body: ListenableBuilder(
        listenable: widget.services.state,
        builder: (context, _) {
          final s = widget.services.state;
          final installed = s.status != LumenStatus.inactive &&
              s.status != LumenStatus.error;
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _HeroCard(state: s),
              const Gap(AppSpacing.lg),
              if (!installed)
                _ActionTile(
                  icon: Icons.power_settings_new_rounded,
                  color: NexoTheme.primary,
                  title: 'Activar Lumen',
                  subtitle:
                      'Elegí entre Ligero o Estándar y descargá el modelo.',
                  onTap: _activate,
                )
              else ...[
                _ActionTile(
                  icon: Icons.swap_horiz_rounded,
                  color: NexoTheme.primary,
                  title: 'Cambiar modelo',
                  subtitle: 'Ligero ↔ Estándar. Borra el actual.',
                  enabled: LumenConfig.models.length > 1,
                  onTap: _switchModel,
                ),
                _ActionTile(
                  icon: Icons.history_toggle_off_rounded,
                  color: NexoTheme.warning,
                  title: 'Limpiar historial de chat',
                  subtitle: 'No afecta al modelo descargado.',
                  onTap: _clearHistory,
                ),
                _ActionTile(
                  icon: Icons.delete_outline,
                  color: NexoTheme.danger,
                  title: 'Borrar modelo',
                  subtitle: 'Libera espacio y desactiva Lumen.',
                  onTap: _delete,
                ),
              ],
              const Gap(AppSpacing.xl),
              const _PrivacyNote(),
            ],
          );
        },
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.state});
  final LumenState state;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = state;
    final installed = s.status != LumenStatus.inactive &&
        s.status != LumenStatus.error;

    String headline;
    String sub;
    Color tint;
    if (installed) {
      headline = s.activeModel.displayName;
      sub = '${s.activeModel.tagline} · listo en tu teléfono';
      tint = NexoTheme.success;
    } else if (s.status == LumenStatus.error) {
      headline = 'Hubo un problema';
      sub = s.error ?? 'Revisá tu conexión y volvé a intentar.';
      tint = NexoTheme.danger;
    } else {
      headline = 'Lumen está apagado';
      sub = 'Activalo para empezar a usar el asistente.';
      tint = NexoTheme.textMuted;
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: NexoTheme.card,
        borderRadius: AppRadii.rLg,
        border: Border.all(color: NexoTheme.border),
      ),
      child: Row(
        children: [
          const LumenLogo(size: 56),
          const Gap.h(AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(headline, style: t.titleMedium),
                const Gap(AppSpacing.xxs),
                Text(sub,
                    style: t.bodySmall?.copyWith(color: tint),
                    maxLines: 2),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        enabled: enabled,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: AppRadii.rSm,
          ),
          child: Icon(icon, color: color, size: AppIcon.xl),
        ),
        title: Text(title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: enabled ? null : NexoTheme.textMuted,
            )),
        subtitle: Text(subtitle),
        trailing: enabled
            ? Icon(Icons.chevron_right, color: NexoTheme.textMuted)
            : null,
        onTap: enabled ? onTap : null,
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: NexoTheme.success.withValues(alpha: 0.08),
        borderRadius: AppRadii.rMd,
        border: Border.all(
          color: NexoTheme.success.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined, color: NexoTheme.success),
          const Gap.h(AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Privado por diseño',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Lumen lee tu data UPLA (perfil, horario, cuotas, notas) '
                  'solo para responder en tu teléfono. Nada se envía a '
                  'internet — toda la inferencia es local.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
