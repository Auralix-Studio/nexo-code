import 'package:flutter/widgets.dart';

import 'package:nexo/core/design/tokens.dart';

/// Breakpoints estilo Tailwind y helpers de responsividad.
abstract final class Breakpoints {
  static const double sm = 640;
  static const double md = 768;
  static const double lg = 1024;
  static const double xl = 1280;
}

enum ScreenSize { mobile, tablet, desktop }

extension ResponsiveX on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;

  ScreenSize get screenSize {
    final w = screenWidth;
    if (w >= Breakpoints.lg) return ScreenSize.desktop;
    if (w >= Breakpoints.md) return ScreenSize.tablet;
    return ScreenSize.mobile;
  }

  bool get isMobile => screenSize == ScreenSize.mobile;
  bool get isTablet => screenSize == ScreenSize.tablet;
  bool get isDesktop => screenSize == ScreenSize.desktop;
  bool get isWide => !isMobile;

  /// Padding horizontal estándar del contenido según el ancho.
  double get contentPadding {
    final w = screenWidth;
    if (w >= Breakpoints.lg) return AppSpacing.huge - 8; // 40
    if (w >= Breakpoints.md) return AppSpacing.xxxl - 4; // 28
    return AppSpacing.lg + 2; // 18
  }

  /// Devuelve uno de los valores según el tamaño de pantalla.
  T responsive<T>({required T mobile, T? tablet, T? desktop}) =>
      switch (screenSize) {
        ScreenSize.desktop => desktop ?? tablet ?? mobile,
        ScreenSize.tablet => tablet ?? mobile,
        ScreenSize.mobile => mobile,
      };
}
