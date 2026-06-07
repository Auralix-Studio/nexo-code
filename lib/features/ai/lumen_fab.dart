import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:nexo/ai/lumen_services.dart';
import 'package:nexo/ai/lumen_state.dart';

import 'lumen_chat_screen.dart';
import 'lumen_logo.dart';
import 'lumen_onboarding_dialog.dart';

/// FAB de Lumen — el "punto de entrada" flotante estilo WhatsApp AI.
///
/// Vive sobre la nav del shell. Cuando aparece por primera vez (o vuelve
/// a aparecer tras un scroll) hace una animación de "ola": sube desde
/// abajo con un overshoot suave + un anillo de ripple que se expande.
///
/// Tap behavior:
/// - Lumen `inactive` → abre el onboarding (selector de modelo + descarga).
/// - Lumen `ready/loaded` → navega al chat.
/// - Lumen `downloading/verifying` → no-op (visualiza el progreso).
class LumenFab extends StatefulWidget {
  const LumenFab({
    super.key,
    required this.services,
    this.visible = true,
  });

  final LumenServices services;
  final bool visible;

  @override
  State<LumenFab> createState() => _LumenFabState();
}

class _LumenFabState extends State<LumenFab>
    with TickerProviderStateMixin {
  late final AnimationController _rise; // entrada: sube + escala
  late final AnimationController _ripple; // ola que se expande detrás

  @override
  void initState() {
    super.initState();
    _rise = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _ripple = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _checkExistingModel();
    if (widget.visible) {
      _rise.forward();
      _ripple.forward();
    }
  }

  @override
  void didUpdateWidget(covariant LumenFab old) {
    super.didUpdateWidget(old);
    if (widget.visible && !old.visible) {
      // Volver a entrar tras un hide por scroll: ola corta.
      _rise.forward(from: 0);
      _ripple.forward(from: 0);
    } else if (!widget.visible && old.visible) {
      _rise.reverse();
    }
  }

  @override
  void dispose() {
    _rise.dispose();
    _ripple.dispose();
    super.dispose();
  }

  Future<void> _checkExistingModel() async {
    final s = widget.services;
    if (s.state.status != LumenStatus.inactive) return;
    final has = await s.modelManager.isDownloaded();
    if (has && mounted) s.state.setStatus(LumenStatus.ready);
  }

  Future<void> _onTap() async {
    final s = widget.services;
    switch (s.state.status) {
      case LumenStatus.inactive:
      case LumenStatus.error:
        final ok = await LumenOnboardingDialog.show(context, s);
        if (ok == true && mounted) _openChat();
        break;
      case LumenStatus.ready:
      case LumenStatus.loading:
      case LumenStatus.loaded:
        _openChat();
        break;
      case LumenStatus.downloading:
      case LumenStatus.verifying:
      case LumenStatus.awaitingDownload:
        // Mostrar el dialogo de progreso (vuelve a abrir el onboarding
        // que detecta el estado actual y renderea la barra).
        await LumenOnboardingDialog.show(context, s);
        break;
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
    return AnimatedBuilder(
      animation: Listenable.merge([_rise, _ripple, widget.services.state]),
      builder: (context, _) {
        final t = Curves.easeOutBack.transform(_rise.value.clamp(0.0, 1.0));
        final translateY = (1 - t) * 80; // sube 80px
        final scale = 0.6 + 0.4 * t;
        final status = widget.services.state.status;
        final isBusy = status == LumenStatus.downloading ||
            status == LumenStatus.verifying ||
            status == LumenStatus.loading;

        return Transform.translate(
          offset: Offset(0, translateY),
          child: Transform.scale(
            scale: scale,
            child: SizedBox(
              width: 88,
              height: 88,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Ripple "ola"
                  if (_ripple.isAnimating || _ripple.value > 0)
                    _Ripple(progress: _ripple.value),
                  // Botón
                  Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    elevation: 8,
                    shadowColor: const Color(0x66AA7BFF),
                    child: InkWell(
                      onTap: _onTap,
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFAA7BFF).withValues(alpha: 0.35),
                            width: 1.2,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x33AA7BFF),
                              blurRadius: 16,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: isBusy
                            ? const SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                ),
                              )
                            : const LumenLogo(size: 38),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Anillo expansivo que sale del centro del FAB cuando aparece.
class _Ripple extends StatelessWidget {
  const _Ripple({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(88, 88),
      painter: _RipplePainter(progress: progress),
    );
  }
}

class _RipplePainter extends CustomPainter {
  _RipplePainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;
    final t = Curves.easeOut.transform(progress);
    // Dos olas desfasadas.
    for (final phase in const [0.0, 0.45]) {
      final p = ((t - phase) / (1 - phase)).clamp(0.0, 1.0);
      if (p <= 0) continue;
      final radius = 24 + p * (maxRadius - 24);
      final alpha = (1 - p) * 0.45;
      final paint = Paint()
        ..color = const Color(0xFFAA7BFF).withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * (1 - p) + 0.5;
      canvas.drawCircle(center, radius, paint);
    }
    // Pequeño "shine" arriba para sensación de ola levantándose.
    final shinePaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: -math.pi / 2 - 0.4,
        endAngle: -math.pi / 2 + 0.4,
        colors: [
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: 0.18 * (1 - t)),
          Colors.white.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius));
    canvas.drawCircle(center, maxRadius - 6, shinePaint);
  }

  @override
  bool shouldRepaint(_RipplePainter old) => old.progress != progress;
}
