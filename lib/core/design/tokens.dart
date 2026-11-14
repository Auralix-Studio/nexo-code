import 'package:flutter/widgets.dart';

abstract final class AppSpacing {
  static const double xxs = 2;
  static const double hair = 3;
  static const double xs = 4;
  static const double tight = 6;
  static const double sm = 8;
  static const double snug = 10;
  static const double md = 12;
  static const double cozy = 14;
  static const double lg = 16;
  static const double roomy = 18;
  static const double xl = 20;
  static const double xxl = 24;
  static const double wide = 28;
  static const double xxxl = 32;
  static const double huge = 48;
}

abstract final class AppRadii {
  static const double tiny = 2;
  static const double xs = 8;
  static const double sm = 10;
  static const double md = 12;
  static const double lg = 14;
  static const double xl = 16;
  static const double xxl = 20;
  static const double xxxl = 24;
  static const double pill = 999;
  static const BorderRadius rTiny = BorderRadius.all(Radius.circular(tiny));
  static const BorderRadius rXs = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius rSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius rMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius rLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius rXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius rXxl = BorderRadius.all(Radius.circular(xxl));
  static const BorderRadius rXxxl = BorderRadius.all(Radius.circular(xxxl));
  static const BorderRadius rPill = BorderRadius.all(Radius.circular(pill));
}

abstract final class AppDurations {
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);

  /// Respuesta al toque (escala al presionar).
  static const Duration press = Duration(milliseconds: 110);

  /// Retraso entre elementos consecutivos de una entrada escalonada.
  static const Duration stagger = Duration(milliseconds: 110);

  /// Entrada de un elemento de lista: más corta que [slow] para no frenar
  /// el desplazamiento.
  static const Duration listStagger = Duration(milliseconds: 45);

  /// Un ciclo de animaciones continuas (brillo de esqueletos, pulso).
  static const Duration loop = Duration(milliseconds: 1100);
}

/// Medidas de componentes que se repiten entre pantallas.
abstract final class AppSizes {
  static const double avatarSm = 38;
  static const double avatarMd = 44;
  static const double avatarLg = 52;

  /// Alto mínimo cómodo para tocar con el pulgar.
  static const double touch = 44;
  static const double button = 50;
  static const double badge = 48;
  static const double iconBadge = 32;
  static const double ring = 76;
  static const double ringStroke = 8;
  static const double bar = 6;
  static const double dot = 8;
  static const double gradeField = 78;
  static const double handleWidth = 40;
  static const double handleHeight = 4;
  static const double stroke = 1.5;
  static const double spinner = 20;
  static const double dialogMaxWidth = 420;
}

/// Opacidades de los tintes de color (fondos suaves, bordes, brillos).
abstract final class AppOpacity {
  static const double faint = 0.06;
  static const double subtle = 0.08;
  static const double soft = 0.10;
  static const double tint = 0.12;
  static const double glow = 0.25;
  static const double outline = 0.35;
  static const double scrim = 0.5;
  static const double onColor = 0.88;
}

abstract final class AppIcon {
  static const double xs = 13;
  static const double sm = 16;
  static const double md = 18;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 28;
}

abstract final class AppFont {
  static const double micro = 10;
  static const double caption = 11;
  static const double small = 12;
  static const double label = 13;
  static const double body = 14;
  static const double subtitle = 15;
  static const double title = 16;
  static const double lead = 17;
  static const double h3 = 18;
  static const double heading = 20;
  static const double h2 = 22;
  static const double h1 = 28;
  static const double metric = 32;
  static const double display = 48;
}

const double kMaxContentWidth = 1240;

class Gap extends StatelessWidget {
  final double size;
  final bool horizontal;
  const Gap(this.size, {super.key}) : horizontal = false;
  const Gap.h(this.size, {super.key}) : horizontal = true;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: horizontal ? size : null,
    height: horizontal ? null : size,
  );
}
