import 'dart:async';

import 'package:flutter/material.dart';

import 'package:nexo/ai/lumen_services.dart';

import 'lumen_fab.dart';

/// Envoltorio que escucha el scroll del [child] y muestra/oculta el
/// [LumenFab] consecuentemente (estilo WhatsApp Meta AI).
///
/// Reglas:
/// - Scroll down (delta > umbral) → ocultar.
/// - Scroll up o detenido por ~400 ms → mostrar de nuevo.
/// - Si el contenido no scrollea (página corta) → siempre visible.
class LumenFabOverlay extends StatefulWidget {
  const LumenFabOverlay({
    super.key,
    required this.services,
    required this.child,
    this.bottomInset = 16,
    this.rightInset = 16,
  });

  final LumenServices services;
  final Widget child;
  final double bottomInset;
  final double rightInset;

  @override
  State<LumenFabOverlay> createState() => _LumenFabOverlayState();
}

class _LumenFabOverlayState extends State<LumenFabOverlay> {
  bool _visible = true;
  Timer? _settleTimer;

  bool _onScroll(ScrollNotification n) {
    // Ignorar scrolls que no son verticales o que vienen de listas
    // pequeñas (NestedScrollView puede emitir cosas raras).
    if (n.metrics.axis != Axis.vertical) return false;

    if (n is ScrollUpdateNotification) {
      final delta = n.scrollDelta ?? 0;
      if (delta > 6 && _visible) {
        setState(() => _visible = false);
      } else if (delta < -6 && !_visible) {
        setState(() => _visible = true);
      }
      // Si el user para de mover el dedo (sin event end), re-emerge.
      _settleTimer?.cancel();
      _settleTimer = Timer(const Duration(milliseconds: 450), () {
        if (mounted && !_visible) setState(() => _visible = true);
      });
    } else if (n is ScrollEndNotification) {
      _settleTimer?.cancel();
      if (!_visible) setState(() => _visible = true);
    }
    return false;
  }

  @override
  void dispose() {
    _settleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: widget.child,
        ),
        Positioned(
          right: widget.rightInset,
          bottom: widget.bottomInset,
          child: LumenFab(
            services: widget.services,
            visible: _visible,
          ),
        ),
      ],
    );
  }
}
