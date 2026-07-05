import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:nexo/core/design/breakpoints.dart';
import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/festivity/festivity.dart';
import 'package:nexo/core/storage.dart';
import 'package:nexo/features/festivity/widgets/fiestas_patrias_effects.dart';

bool _decorEnabled(BuildContext context) =>
    AppStorage.instance.festivityDecor &&
    !MediaQuery.of(context).disableAnimations;

class FestivityOverlay extends StatelessWidget {
  const FestivityOverlay({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(color: NexoTheme.bg),
        const Positioned.fill(child: _BackgroundLayer()),
        child,
        const Positioned.fill(child: _ForegroundLayer()),
      ],
    );
  }
}

class _BackgroundLayer extends StatefulWidget {
  const _BackgroundLayer();
  @override
  State<_BackgroundLayer> createState() => _BackgroundLayerState();
}

class _BackgroundLayerState extends State<_BackgroundLayer> {
  late final Timer _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = FestivityService.active(DateTime.now());
    if (active == null || !_decorEnabled(context)) {
      return const SizedBox.shrink();
    }
    if (active.festivity.id == 'fiestas_patrias') {
      return const IgnorePointer(
        child: Opacity(
          opacity: 0.1, // 10% de opacidad para que sea marca de agua
          child: Center(
            child: MarcaPeruEffect(),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _ForegroundLayer extends StatefulWidget {
  const _ForegroundLayer();
  @override
  State<_ForegroundLayer> createState() => _ForegroundLayerState();
}

class _ForegroundLayerState extends State<_ForegroundLayer> {
  late final Timer _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = FestivityService.active(DateTime.now());
    if (active == null || !_decorEnabled(context)) {
      return const SizedBox.shrink();
    }
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(child: _Particles(activeFestivity: active)),
        ),
        if (active.number != null && context.isDesktop)
          Positioned(
            top: 0,
            right: 24,
            child: SafeArea(
              child: IgnorePointer(
                child: _HangingNumber(number: '${active.number}'),
              ),
            ),
          ),
      ],
    );
  }
}

class _HangingNumber extends StatefulWidget {
  const _HangingNumber({required this.number});
  final String number;
  @override
  State<_HangingNumber> createState() => _HangingNumberState();
}

class _HangingNumberState extends State<_HangingNumber>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFFFC107);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, childW) {
        final angle = 0.16 * math.sin(_c.value * 2 * math.pi);
        return Transform.rotate(
          angle: angle,
          alignment: Alignment.topCenter,
          child: childW,
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: Color(0xFF8A94A6),
              shape: BoxShape.circle,
            ),
          ),
          Container(
            width: 1.5,
            height: 34,
            color: NexoTheme.textMuted.withValues(alpha: 0.6),
          ),
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [gold, Color(0xFFFFA000)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.75),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: gold.withValues(alpha: 0.45),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Text(
              widget.number,
              style: const TextStyle(
                fontFamily: 'SuperMindset',
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FestivityWordmark extends StatefulWidget {
  const FestivityWordmark({super.key, this.style});
  final TextStyle? style;
  @override
  State<FestivityWordmark> createState() => _FestivityWordmarkState();
}

class _FestivityWordmarkState extends State<FestivityWordmark> {
  late final Timer _timer;
  int _i = 0;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) setState(() => _i++);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base =
        widget.style ??
        TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w900,
          color: NexoTheme.textPrimary,
          letterSpacing: -0.5,
        );
    final enabled =
        AppStorage.instance.festivityDecor &&
        !MediaQuery.of(context).disableAnimations;
    final active = enabled ? FestivityService.active(DateTime.now()) : null;
    final words = active?.wordmark ?? const ['Nexo'];
    if (words.length <= 1) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Nexo',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: base,
        ),
      );
    }
    final idx = _i % words.length;
    final word = words[idx];
    final festive = idx != 0;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.centerLeft,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.25),
            end: Offset.zero,
          ).animate(anim),
          child: child,
        ),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          word,
          key: ValueKey(word),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: festive ? base.copyWith(color: NexoTheme.primary) : base,
        ),
      ),
    );
  }
}

List<Color> _palette(FestivityDecor d) => switch (d) {
  FestivityDecor.snow => const [Colors.white, Color(0xFFE3F2FD)],
  FestivityDecor.flagsPeru => const [Color(0xFFD91023), Colors.white],
  FestivityDecor.petals => const [Color(0xFFF48FB1), Color(0xFFF8BBD0)],
  FestivityDecor.confetti => const [
    Color(0xFFEF5350),
    Color(0xFF42A5F5),
    Color(0xFF66BB6A),
    Color(0xFFFFCA28),
    Color(0xFFAB47BC),
  ],
  FestivityDecor.graduation => const [
    Color(0xFFFFC107),
    Color(0xFF1E88E5),
    Color(0xFFE53935),
    Colors.white,
  ],
};

class _Particle {
  _Particle(math.Random r, List<Color> palette)
    : x0 = r.nextDouble(),
      size = 4 + r.nextDouble() * 6,
      speed = 0.03 + r.nextDouble() * 0.06,
      seed = r.nextDouble(),
      driftAmp = 0.01 + r.nextDouble() * 0.03,
      driftFreq = 0.5 + r.nextDouble() * 1.0,
      spin = (r.nextBool() ? 1 : -1) * (0.5 + r.nextDouble()),
      color = palette[r.nextInt(palette.length)];
  final double x0, size, speed, seed, driftAmp, driftFreq, spin;
  final Color color;
}

class _Particles extends StatefulWidget {
  const _Particles({required this.activeFestivity});
  final ActiveFestivity activeFestivity;
  @override
  State<_Particles> createState() => _ParticlesState();
}

class _ParticlesState extends State<_Particles>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<double> _t = ValueNotifier(0);
  late List<_Particle> _particles;
  @override
  void initState() {
    super.initState();
    _build();
    _ticker = createTicker((e) => _t.value = e.inMicroseconds / 1e6)..start();
  }

  void _build() {
    final decor = widget.activeFestivity.decor;
    final r = math.Random(decor.index + 7);
    final palette = widget.activeFestivity.festivity.decorColors ?? _palette(decor);
    _particles = List.generate(34, (_) => _Particle(r, palette));
  }

  @override
  void didUpdateWidget(covariant _Particles old) {
    super.didUpdateWidget(old);
    if (old.activeFestivity.festivity.id != widget.activeFestivity.festivity.id) _build();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _ParticlePainter(
          t: _t,
          particles: _particles,
          isSnow: widget.activeFestivity.decor == FestivityDecor.snow,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter({
    required this.t,
    required this.particles,
    required this.isSnow,
  }) : super(repaint: t);
  final ValueNotifier<double> t;
  final List<_Particle> particles;
  final bool isSnow;
  double _frac(double v) => v - v.floorToDouble();
  @override
  void paint(Canvas canvas, Size size) {
    final time = t.value;
    final paint = Paint();
    for (final p in particles) {
      final y = _frac(time * p.speed + p.seed) * (size.height + 40) - 20;
      final drift = math.sin((time * p.driftFreq) + p.seed * 6.28) * p.driftAmp;
      final x = ((p.x0 + drift) % 1.0) * size.width;
      paint.color = p.color.withValues(alpha: isSnow ? 0.55 : 0.45);
      if (isSnow) {
        canvas.drawCircle(Offset(x, y), p.size * 0.5, paint);
      } else {
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(time * p.spin + p.seed * 6.28);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: p.size,
              height: p.size * 0.6,
            ),
            Radius.circular(p.size * 0.2),
          ),
          paint,
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) => false;
}
