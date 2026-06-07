import 'package:flutter/material.dart';

import 'package:nexo/ai/lumen_services.dart';
import 'package:nexo/ai/lumen_state.dart';
import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/design/tokens.dart';

import 'lumen_chat_screen.dart';
import 'lumen_logo.dart';
import 'lumen_onboarding_dialog.dart';

/// Tarjeta en el Home que sirve de entrada a Lumen.
///
/// Cambia su CTA según el estado del modelo:
/// - `inactive` → "Activar Lumen" abre el onboarding.
/// - `downloading` / `verifying` → muestra progreso (no clickeable).
/// - `ready` / `loaded` → "Abrir chat" navega a [LumenChatScreen].
class LumenHomeCard extends StatefulWidget {
  const LumenHomeCard({super.key, required this.services});

  final LumenServices services;

  @override
  State<LumenHomeCard> createState() => _LumenHomeCardState();
}

class _LumenHomeCardState extends State<LumenHomeCard> {
  @override
  void initState() {
    super.initState();
    _detectExistingModel();
  }

  Future<void> _detectExistingModel() async {
    if (widget.services.state.status != LumenStatus.inactive) return;
    final has = await widget.services.modelManager.isDownloaded();
    if (has && mounted) {
      widget.services.state.setStatus(LumenStatus.ready);
    }
  }

  Future<void> _openOnboarding() async {
    final ok = await LumenOnboardingDialog.show(context, widget.services);
    if (ok == true && mounted) {
      _openChat();
    }
  }

  void _openChat() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LumenChatScreen(services: widget.services),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.services.state,
      builder: (context, _) {
        final s = widget.services.state;
        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _onTap(s.status),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  const LumenLogo(size: 48),
                  const Gap.h(AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Lumen',
                            style: Theme.of(context).textTheme.titleMedium),
                        const Gap(AppSpacing.xxs),
                        Text(
                          _subtitle(s),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: NexoTheme.textSecondary,
                          ),
                        ),
                        if (s.status == LumenStatus.downloading) ...[
                          const Gap(AppSpacing.sm),
                          LinearProgressIndicator(value: s.downloadProgress),
                        ],
                      ],
                    ),
                  ),
                  if (_onTap(s.status) != null)
                    const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  VoidCallback? _onTap(LumenStatus status) {
    switch (status) {
      case LumenStatus.inactive:
        return _openOnboarding;
      case LumenStatus.ready:
      case LumenStatus.loading:
      case LumenStatus.loaded:
        return _openChat;
      case LumenStatus.error:
        return _openOnboarding;
      case LumenStatus.downloading:
      case LumenStatus.verifying:
      case LumenStatus.awaitingDownload:
        return null;
    }
  }

  String _subtitle(LumenState s) {
    switch (s.status) {
      case LumenStatus.inactive:
        return 'Asistente IA personal · 100% en tu teléfono';
      case LumenStatus.awaitingDownload:
        return 'Listo para descargar';
      case LumenStatus.downloading:
        final pct = (s.downloadProgress * 100).toStringAsFixed(0);
        return 'Descargando modelo… $pct%';
      case LumenStatus.verifying:
        return 'Verificando archivo…';
      case LumenStatus.ready:
        return 'Listo · toca para preguntarme';
      case LumenStatus.loading:
        return 'Cargando modelo en memoria…';
      case LumenStatus.loaded:
        return 'Listo · toca para preguntarme';
      case LumenStatus.error:
        return s.error ?? 'Error — toca para reintentar';
    }
  }
}
