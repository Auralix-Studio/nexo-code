import 'dart:math' as math;
import 'package:flutter/material.dart';

class EscarapelaWidget extends StatefulWidget {
  const EscarapelaWidget({super.key});

  @override
  State<EscarapelaWidget> createState() => _EscarapelaWidgetState();
}

class _EscarapelaWidgetState extends State<EscarapelaWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  late final Animation<double> _fade = Tween<double>(begin: 0.0, end: 1.0)
      .animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.5, curve: Curves.easeIn)));
  late final Animation<double> _scale = Tween<double>(begin: 0.5, end: 1.0)
      .animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      return CustomPaint(
        size: const Size(20, 24),
        painter: _EscarapelaPainter(),
      );
    }
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Opacity(
          opacity: _fade.value,
          child: Transform.scale(
            scale: _scale.value,
            child: child,
          ),
        );
      },
      child: CustomPaint(
        size: const Size(20, 24),
        painter: _EscarapelaPainter(),
      ),
    );
  }
}

class _EscarapelaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    
    // Escalar la caja original del SVG (500x600) al size proporcionado por el parent
    final scaleX = size.width / 500.0;
    final scaleY = size.height / 600.0;
    final scale = scaleX < scaleY ? scaleX : scaleY; 
    
    // Centrar el dibujo en el canvas disponible
    canvas.translate((size.width - 500.0 * scale) / 2, (size.height - 600.0 * scale) / 2);
    canvas.scale(scale);

    final paintRed = Paint()..color = const Color(0xFFC8102E)..style = PaintingStyle.fill;
    final paintWhite = Paint()..color = const Color(0xFFFFFFFF)..style = PaintingStyle.fill;

    void drawPoly(List<double> points, Paint paint) {
      final path = Path();
      if (points.isEmpty) return;
      path.moveTo(points[0], points[1]);
      for (int i = 2; i < points.length; i += 2) {
        path.lineTo(points[i], points[i + 1]);
      }
      path.close();
      canvas.drawPath(path, paint);
    }

    // === Cola izquierda ===
    canvas.save();
    canvas.translate(250, 200);
    canvas.rotate(20 * math.pi / 180);
    canvas.translate(-250, -200);
    drawPoly([165, 200, 195, 200, 195, 500, 165, 520], paintRed);
    drawPoly([195, 200, 225, 200, 225, 500, 210, 490, 195, 500], paintWhite);
    drawPoly([225, 200, 255, 200, 255, 520, 225, 500], paintRed);
    canvas.restore();

    // === Cola derecha ===
    canvas.save();
    canvas.translate(250, 200);
    canvas.rotate(-20 * math.pi / 180);
    canvas.translate(-250, -200);
    drawPoly([245, 200, 275, 200, 275, 500, 245, 520], paintRed);
    drawPoly([275, 200, 305, 200, 305, 500, 290, 490, 275, 500], paintWhite);
    drawPoly([305, 200, 335, 200, 335, 520, 305, 500], paintRed);
    canvas.restore();

    // === Roseta circular (Coronas) ===
    // 1. Corona exterior
    for (int i = 0; i < 12; i++) {
      canvas.save();
      canvas.translate(250, 200);
      canvas.rotate((i * 30) * math.pi / 180);
      canvas.translate(-250, -200);
      canvas.drawCircle(const Offset(250, 80), 60, paintRed);
      canvas.restore();
    }

    // 2. Corona intermedia
    for (int i = 0; i < 12; i++) {
      canvas.save();
      canvas.translate(250, 200);
      canvas.rotate((i * 30) * math.pi / 180);
      canvas.translate(-250, -200);
      canvas.drawCircle(const Offset(250, 120), 45, paintWhite);
      canvas.restore();
    }

    // 3. Corona interior
    for (int i = 0; i < 12; i++) {
      canvas.save();
      canvas.translate(250, 200);
      canvas.rotate((i * 30) * math.pi / 180);
      canvas.translate(-250, -200);
      canvas.drawCircle(const Offset(250, 170), 35, paintRed);
      canvas.restore();
    }
    
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
