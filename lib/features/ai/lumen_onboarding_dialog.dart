import 'package:flutter/material.dart';

import 'package:nexo/ai/lumen_services.dart';
import 'package:nexo/ai/lumen_state.dart';
import 'package:nexo/ai/model_manager.dart';
import 'package:nexo/core/config.dart';
import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/design/tokens.dart';

/// Diálogo de bienvenida para Lumen — explica qué es, pide aceptación y
/// dispara la descarga del modelo.
///
/// Devuelve `true` si el usuario completó la descarga y el modelo quedó
/// listo, `false` si canceló o falló.
class LumenOnboardingDialog extends StatefulWidget {
  const LumenOnboardingDialog({super.key, required this.services});

  final LumenServices services;

  static Future<bool?> show(BuildContext context, LumenServices services) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => LumenOnboardingDialog(services: services),
    );
  }

  @override
  State<LumenOnboardingDialog> createState() => _LumenOnboardingDialogState();
}

class _LumenOnboardingDialogState extends State<LumenOnboardingDialog> {
  bool _accepted = false;
  CancelToken? _cancel;

  Future<void> _startDownload() async {
    setState(() => _accepted = true);
    _cancel = CancelToken();
    try {
      await widget.services.modelManager.download(cancel: _cancel);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      // El error ya quedó reflejado en LumenState.error.
      if (!mounted) return;
      setState(() {});
    }
  }

  void _cancelDownload() {
    _cancel?.cancel();
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.services.state,
      builder: (context, _) {
        final s = widget.services.state;
        final isDownloading = s.status == LumenStatus.downloading ||
            s.status == LumenStatus.verifying;
        return AlertDialog(
          title: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: const RadialGradient(
                    colors: [Color(0xFFFFB84D), Color(0xFFE89E2B)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.auto_awesome,
                    color: Colors.white, size: 20),
              ),
              const Gap.h(AppSpacing.md),
              const Text('Lumen'),
            ],
          ),
          content: SingleChildScrollView(
            child: _accepted
                ? _DownloadProgress(state: s)
                : const _Explainer(),
          ),
          actions: [
            if (!_accepted) ...[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton.icon(
                onPressed: LumenConfig.isConfigured ? _startDownload : null,
                icon: const Icon(Icons.download_rounded),
                label: Text(LumenConfig.isConfigured
                    ? 'Aceptar y descargar'
                    : 'No disponible aún'),
              ),
            ] else if (isDownloading)
              TextButton(
                onPressed: _cancelDownload,
                child: const Text('Cancelar descarga'),
              )
            else if (s.status == LumenStatus.error)
              FilledButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cerrar'),
              ),
          ],
        );
      },
    );
  }
}

class _Explainer extends StatelessWidget {
  const _Explainer();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Asistente IA personal, 100% en tu teléfono.',
          style: t.titleSmall,
        ),
        const Gap(AppSpacing.sm),
        Text(
          'Lumen responde tus dudas sobre UPLA y tu propia data (horario, '
          'cuotas, notas) sin enviar nada a internet. Toda la inferencia '
          'corre localmente.',
          style: t.bodyMedium,
        ),
        const Gap(AppSpacing.lg),
        _Bullet(
          icon: Icons.cloud_download_rounded,
          color: NexoTheme.primary,
          title: 'Descarga única (~529 MB)',
          subtitle: 'El modelo Gemma 1B se descarga una sola vez. '
              'Después funciona sin internet.',
        ),
        _Bullet(
          icon: Icons.lock_outline_rounded,
          color: NexoTheme.success,
          title: 'Privado por diseño',
          subtitle: 'Cero llamadas a APIs externas. Auditable en el código.',
        ),
        _Bullet(
          icon: Icons.warning_amber_rounded,
          color: NexoTheme.warning,
          title: 'Puede equivocarse',
          subtitle: 'Modelo más chico que ChatGPT. Confirma información '
              'crítica en fuentes oficiales.',
        ),
        if (!LumenConfig.isConfigured) ...[
          const Gap(AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: NexoTheme.warning.withValues(alpha: 0.12),
              borderRadius: AppRadii.rSm,
            ),
            child: Text(
              'El modelo todavía no está publicado por el equipo de Nexo. '
              'Volvé a intentar más tarde.',
              style: t.bodySmall?.copyWith(color: NexoTheme.warning),
            ),
          ),
        ],
      ],
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: AppIcon.lg),
          const Gap.h(AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600)),
                Text(subtitle, style: t.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DownloadProgress extends StatelessWidget {
  const _DownloadProgress({required this.state});

  final LumenState state;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final mb = (state.downloadedBytes / (1024 * 1024)).toStringAsFixed(1);
    final totalMb = (state.totalBytes / (1024 * 1024)).toStringAsFixed(0);
    final pct = (state.downloadProgress * 100).toStringAsFixed(1);

    String label;
    switch (state.status) {
      case LumenStatus.downloading:
        label = 'Descargando modelo… $mb / $totalMb MB ($pct%)';
        break;
      case LumenStatus.verifying:
        label = 'Verificando integridad del archivo…';
        break;
      case LumenStatus.error:
        label = state.error ?? 'Error desconocido.';
        break;
      case LumenStatus.ready:
        label = 'Modelo listo.';
        break;
      default:
        label = 'Preparando…';
    }

    final isError = state.status == LumenStatus.error;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (state.status == LumenStatus.downloading)
          LinearProgressIndicator(value: state.downloadProgress)
        else if (state.status == LumenStatus.verifying)
          const LinearProgressIndicator()
        else if (state.status == LumenStatus.error)
          Icon(Icons.error_outline, color: NexoTheme.danger, size: AppIcon.xl),
        const Gap(AppSpacing.md),
        Text(label,
            style: t.bodyMedium?.copyWith(
              color: isError ? NexoTheme.danger : null,
            )),
      ],
    );
  }
}
