import 'package:flutter/widgets.dart';

abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 48;
}

abstract final class AppRadii {
  static const double xs = 8;
  static const double sm = 10;
  static const double md = 12;
  static const double lg = 14;
  static const double xl = 16;
  static const double xxl = 20;
  static const double pill = 999;
  static const BorderRadius rXs = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius rSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius rMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius rLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius rXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius rXxl = BorderRadius.all(Radius.circular(xxl));
  static const BorderRadius rPill = BorderRadius.all(Radius.circular(pill));
}

abstract final class AppDurations {
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
}

abstract final class AppIcon {
  static const double xs = 13;
  static const double sm = 16;
  static const double md = 18;
  static const double lg = 20;
  static const double xl = 24;
}

abstract final class AppFont {
  static const double caption = 11;
  static const double small = 12;
  static const double body = 14;
  static const double subtitle = 15;
  static const double title = 16;
  static const double h3 = 18;
  static const double h2 = 22;
  static const double h1 = 28;
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
