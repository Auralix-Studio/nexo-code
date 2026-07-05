import 'package:flutter/material.dart';

class MarcaPeruEffect extends StatelessWidget {
  const MarcaPeruEffect({super.key, this.color});
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _MarcaPeruPainter(color: color),
    );
  }
}

class _MarcaPeruPainter extends CustomPainter {
  final Color? color;
  _MarcaPeruPainter({this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    path.moveTo(647, 224.6);
    path.relativeCubicTo(8.1, -4.5, 30.4, -16.6, 37.4, -25.7);
    path.relativeCubicTo(5.8, -7.5, -20.6, -13.1, -26.3, -8.6);
    path.relativeCubicTo(-8.8, 7.3, -18, 16, -23, 21);
    path.cubicTo(624.6, 222.3, 639.1, 228.9, 647, 224.6);
    path.moveTo(734.6, 291.7);
    path.relativeCubicTo(-23.6, -4.3, -33.3, -16.1, -35, -26.2);
    path.relativeCubicTo(-4.1, -23.5, 4.5, -34.7, -2.9, -34.6);
    path.relativeCubicTo(-7.4, 0.1, -19.7, 4.9, -20.5, 11.9);
    path.relativeCubicTo(-3.9, 32.9, -18.1, 52.3, -38.8, 52.2);
    path.relativeCubicTo(-22.6, -0.1, -26.5, -29.9, -22, -49);
    path.relativeCubicTo(3.2, -13.6, -8.9, -10.5, -19, -6.2);
    path.relativeCubicTo(-3.7, 1.6, -6.4, 3.8, -7.8, 9.4);
    path.relativeCubicTo(-2.7, 11.5, -6.3, 29.2, -22.3, 39.1);
    path.relativeCubicTo(-15.4, 9.5, -34.2, 6.9, -34.7, -30.4);
    path.relativeCubicTo(-0.7, -42.5, -43.3, -23.3, -57.1, -18.9);
    path.relativeCubicTo(-13.8, 4.4, -20.9, 2.3, -20.6, 15.7);
    path.relativeCubicTo(0.9, 33.7, -24.3, 44.2, -44.1, 45.2);
    path.relativeCubicTo(-27.9, 1.5, -41.6, -18.8, -41.6, -26.7);
    path.relativeCubicTo(25, 0.7, 40.3, -1.6, 51.1, -11.5);
    path.relativeCubicTo(14.3, -13.1, 9.5, -41.8, -24.7, -44.5);
    path.relativeCubicTo(-34.1, -2.7, -52.7, 22.1, -54.4, 36.6);
    path.relativeCubicTo(-11.8, -0.3, -14.4, -0.3, -26.9, -0.7);
    path.relativeCubicTo(-3, -50.4, -17.1, -104.7, -43.6, -137.9);
    path.relativeCubicTo(-26.6, -32, -87.3, -43.3, -149.9, -43.7);
    path.relativeCubicTo(-37.8, 0, -82.7, 4.2, -114.7, 13);
    path.relativeCubicTo(-31.9, 9, -57.4, 21.7, -75.4, 49.1);
    path.relativeCubicTo(-30.9, 47, -29.9, 103.1, -25.5, 174.7);
    path.relativeCubicTo(5.4, 89, 26.4, 177.6, 52.5, 258.9);
    path.relativeCubicTo(2.7, 8.2, 11.7, 2.7, 18.4, -1.8);
    path.relativeCubicTo(6.7, -4.5, 11.3, -6.9, 9, -13.1);
    path.relativeCubicTo(-29.8, -76.5, -53.6, -187.8, -57.2, -244.2);
    path.relativeCubicTo(-3.5, -53.9, -3.1, -132.9, 24.2, -165.9);
    path.relativeCubicTo(38.1, -45.8, 130.2, -50.6, 166.7, -50.6);
    path.relativeCubicTo(60.4, -0.4, 106.4, 10.8, 130, 34.3);
    path.relativeCubicTo(25.6, 25.6, 39.8, 78.9, 42.9, 126.3);
    path.relativeCubicTo(-5.3, -0.2, -14.4, -0.3, -19.8, -0.5);
    path.relativeCubicTo(-1.2, -13.6, -5.3, -34.4, -12.5, -49);
    path.relativeCubicTo(-12.2, -24.3, -29.5, -40.5, -56.5, -50.4);
    path.relativeCubicTo(-25.5, -9.4, -60.1, -13.3, -98.8, -13.3);
    path.relativeCubicTo(-45, 0.1, -93.6, 13.4, -120.2, 47.5);
    path.relativeCubicTo(-17, 22.3, -23.5, 48.5, -23.7, 84.7);
    path.relativeCubicTo(0, 34.1, 4.7, 73.6, 17.9, 104);
    path.relativeCubicTo(13.2, 30.3, 33.8, 61.1, 60.7, 73.3);
    path.relativeCubicTo(15.8, 7.2, 38.7, 10.5, 56.1, 9.6);
    path.relativeCubicTo(56.2, -2.8, 164.6, -31, 193.8, -74.1);
    path.relativeCubicTo(31.2, -46.1, 26.3, -111.6, 26.3, -112.5);
    path.relativeCubicTo(12.3, 0.3, 19.2, 0.1, 26.7, 0.1);
    path.relativeCubicTo(1.2, 16.8, 17.5, 47.8, 62.9, 47.8);
    path.relativeCubicTo(45.3, 0, 59.8, -38.1, 62.1, -48.5);
    path.relativeCubicTo(2, -9.1, 12.8, -14.6, 27.1, -16.3);
    path.relativeCubicTo(17.9, -2.1, 3.2, 16.4, 26.9, 44.4);
    path.relativeCubicTo(21.6, 25.5, 47.8, 6.7, 52.7, 2.8);
    path.relativeCubicTo(10, -8, 19.9, -26.2, 21.6, -34.5);
    path.relativeCubicTo(0.4, 26.3, 12.9, 42.3, 40, 45.1);
    path.relativeCubicTo(27.4, 2.7, 46.3, -18.3, 52.1, -28.6);
    path.relativeCubicTo(16.1, 26.5, 36.5, 32.9, 42, 30.7);
    path.cubicTo(733.6, 312.7, 744.9, 293.5, 734.6, 291.7);
    path.moveTo(143.6, 366.3);
    path.relativeCubicTo(-14.9, 0.7, -39.8, 1.5, -56.6, -6);
    path.relativeCubicTo(-26.1, -11.7, -36.5, -43.7, -36.5, -73.2);
    path.relativeCubicTo(0.1, -33.1, 20.1, -74.7, 78.2, -74.8);
    path.relativeCubicTo(53.7, -0.1, 67.9, 31.1, 70.4, 37);
    path.relativeCubicTo(-8, -0.9, -47.2, -4.7, -67.7, -3);
    path.relativeCubicTo(-15.6, 1.3, -41.7, 7.3, -41.7, 39.1);
    path.relativeCubicTo(0, 31.8, 29.1, 63.7, 89.8, 50.3);
    path.relativeCubicTo(14.7, -3.3, 45.9, -13.9, 44.9, -67.5);
    path.relativeCubicTo(11.2, 0.6, 17.2, 0.6, 29.6, 1.1);
    path.cubicTo(261.5, 339.1, 207.4, 363, 143.6, 366.3);
    path.moveTo(202.7, 268);
    path.relativeCubicTo(3.6, 21.6, -9.4, 51.3, -50.8, 46.3);
    path.relativeCubicTo(-44.6, -5.5, -34.2, -45, -6.7, -46.7);
    path.cubicTo(168.9, 266.1, 194.9, 267.6, 202.7, 268);
    path.moveTo(250.5, 388.1);
    path.relativeCubicTo(-25.8, 18, -74.7, 34.3, -122.5, 42.6);
    path.relativeCubicTo(-30.1, 5.2, -64.6, 4.3, -86.6, -10.1);
    path.cubicTo(-9, 387.6, -15, 301.2, -15, 269.3);
    path.cubicTo(-15.1, 235.5, -7.7, 168, 95, 162);
    path.relativeCubicTo(109.5, -6.4, 146.7, 33.3, 156.6, 90.8);
    path.relativeLineTo(-31.1, -1.8);
    path.relativeCubicTo(-3.3, -10.1, -10.5, -21.4, -17, -29.2);
    path.relativeCubicTo(-14.6, -16.8, -39.3, -28, -72, -28.1);
    path.relativeCubicTo(-95.6, -0.4, -105.7, 66.3, -103.6, 99);
    path.relativeCubicTo(2.2, 34, 12.9, 77.2, 48.1, 91.3);
    path.relativeCubicTo(14.4, 5.8, 38.8, 7.5, 55.1, 7.1);
    path.relativeCubicTo(52.7, -1.8, 99.5, -19.3, 125.8, -50.4);
    path.relativeCubicTo(10.8, -12.7, 16.8, -40.7, 16.8, -60.1);
    path.relativeCubicTo(0, -4.6, 0.4, -6.2, 0, -11);
    path.relativeCubicTo(4.7, 0.2, 17.1, 0.6, 17.1, 0.6);
    path.cubicTo(290.9, 310.8, 286.5, 362.9, 250.5, 388.1);
    path.moveTo(389.7, 231.1);
    path.relativeCubicTo(21.5, -4.9, 30.3, 20.5, 0.2, 22.7);
    path.relativeCubicTo(-12.7, 0.9, -22.5, 0.4, -22.5, 0.4);
    path.cubicTo(370.5, 242.5, 378.6, 233.7, 389.7, 231.1);

    canvas.save();

    final bounds = path.getBounds();
    final targetWidth = size.width * 0.75 > 450 ? 450.0 : size.width * 0.75;
    final scale = targetWidth / bounds.width;

    final scaledWidth = bounds.width * scale;
    final scaledHeight = bounds.height * scale;

    final dx = (size.width - scaledWidth) / 2;
    final dy = (size.height - scaledHeight) / 2;

    canvas.translate(dx, dy);
    canvas.scale(scale);
    canvas.translate(-bounds.left, -bounds.top);

    final paint = Paint()
      ..color = color ?? const Color(0xFFE2432A)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MarcaPeruPainter oldDelegate) =>
      oldDelegate.color != color;
}
