import 'package:flutter/material.dart';

import 'package:nexo/ai/chat_session.dart';
import 'package:nexo/ai/lumen_services.dart';
import 'package:nexo/ai/lumen_state.dart';
import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/design/tokens.dart';
import 'package:nexo/features/ai/lumen_logo.dart';
import 'package:nexo/features/ai/lumen_settings_screen.dart';

/// Pantalla principal de conversación con Lumen.
///
/// Asume que el modelo ya está descargado. Carga el engine la primera vez
/// que se monta (puede tardar 1-3s en hardware moderno).
class LumenChatScreen extends StatefulWidget {
  const LumenChatScreen({super.key, required this.services});

  final LumenServices services;

  @override
  State<LumenChatScreen> createState() => _LumenChatScreenState();
}

class _LumenChatScreenState extends State<LumenChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    // Carga lazy del modelo en RAM cuando se abre el chat.
    if (!widget.services.engine.isLoaded) {
      widget.services.engine.load();
    }
    widget.services.session.addListener(_scrollToBottom);
  }

  @override
  void dispose() {
    widget.services.session.removeListener(_scrollToBottom);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: AppDurations.fast,
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _input.text;
    if (text.trim().isEmpty || widget.services.session.isBusy) return;
    _input.clear();
    try {
      await widget.services.session.send(text);
    } catch (_) {
      // El error ya se vuelca como burbuja en LumenChatSession.
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = widget.services;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            const LumenLogo(size: 32),
            const Gap.h(AppSpacing.sm),
            ListenableBuilder(
              listenable: services.state,
              builder: (_, child) {
                final s = services.state.status;
                final label = switch (s) {
                  LumenStatus.loading => 'Lumen · cargando…',
                  LumenStatus.loaded => 'Lumen · listo',
                  LumenStatus.error => 'Lumen · error',
                  _ => 'Lumen',
                };
                return Text(label);
              },
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Limpiar conversación',
            onPressed: () => services.clearSession(),
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: 'Configuración de Lumen',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => LumenSettingsScreen(services: services),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListenableBuilder(
              listenable: services.session,
              builder: (context, _) {
                final messages = services.session.messages;
                if (messages.isEmpty) {
                  return const _EmptyState();
                }
                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: messages.length,
                  itemBuilder: (_, i) => _Bubble(message: messages[i]),
                );
              },
            ),
          ),
          _InputBar(
            controller: _input,
            services: services,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const LumenLogo(size: 80),
          const Gap(AppSpacing.md),
          Text(
            'Hola. Soy Lumen.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Gap(AppSpacing.xs),
          Text(
            'Pregúntame sobre tus clases, cuotas, notas o UPLA en general.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: NexoTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;
    final bg = isUser ? NexoTheme.primary : NexoTheme.card;
    final fg = isUser ? Colors.white : NexoTheme.textPrimary;
    final align = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(AppRadii.lg),
      topRight: const Radius.circular(AppRadii.lg),
      bottomLeft: Radius.circular(isUser ? AppRadii.lg : AppRadii.xs),
      bottomRight: Radius.circular(isUser ? AppRadii.xs : AppRadii.lg),
    );

    return Align(
      alignment: align,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: radius,
          border: isUser ? null : Border.all(color: NexoTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SelectableText(
              message.text.isEmpty && message.isStreaming
                  ? '…'
                  : message.text,
              style: TextStyle(color: fg, fontSize: AppFont.body, height: 1.4),
            ),
            if (message.isStreaming && message.text.isNotEmpty) ...[
              const Gap(AppSpacing.xs),
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  valueColor: AlwaysStoppedAnimation(
                    isUser ? Colors.white : NexoTheme.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.services,
    required this.onSend,
  });

  final TextEditingController controller;
  final LumenServices services;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: NexoTheme.surface,
          border: Border(top: BorderSide(color: NexoTheme.divider)),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: const InputDecoration(
                  hintText: 'Pregúntale a Lumen…',
                  border: OutlineInputBorder(borderRadius: AppRadii.rLg),
                  isDense: true,
                ),
              ),
            ),
            const Gap.h(AppSpacing.sm),
            ListenableBuilder(
              listenable: Listenable.merge([services.state, services.session]),
              builder: (_, child) {
                final loaded = services.state.status == LumenStatus.loaded;
                final busy = services.session.isBusy;
                final enabled = loaded && !busy;
                return IconButton.filled(
                  onPressed: enabled ? onSend : null,
                  icon: Icon(busy
                      ? Icons.hourglass_top_rounded
                      : Icons.send_rounded),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
