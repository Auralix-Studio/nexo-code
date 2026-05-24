import 'package:flutter/material.dart';

/// Sistema de diseño con soporte claro / oscuro.
///
/// Los colores neutros son campos `static` **mutables**: al cambiar de modo
/// se reasignan y se reconstruye toda la app desde la raíz. Los colores de
/// marca/semánticos son `const` (funcionan en ambos modos).
class NexoTheme {
  // ===== Marca / semánticos (constantes) =====
  static const Color primary = Color(0xFF6366F1);
  static const Color primaryDark = Color(0xFF4338CA);
  static const Color accent = Color(0xFF22D3EE);

  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  static Color softOf(Color c) => c.withValues(alpha: 0.10);

  // ===== Neutros (mutables según el modo) =====
  static Color bg = _Light.bg;
  static Color surface = _Light.surface;
  static Color card = _Light.card;
  static Color border = _Light.border;
  static Color divider = _Light.divider;
  static Color textPrimary = _Light.textPrimary;
  static Color textSecondary = _Light.textSecondary;
  static Color textMuted = _Light.textMuted;

  static bool _isDark = false;
  static bool get isDark => _isDark;

  /// Reasigna la paleta neutra. Llamar antes de construir el ThemeData.
  static void apply(bool dark) {
    _isDark = dark;
    final p = dark ? _Dark.values : _Light.values;
    bg = p[0];
    surface = p[1];
    card = p[2];
    border = p[3];
    divider = p[4];
    textPrimary = p[5];
    textSecondary = p[6];
    textMuted = p[7];
  }

  static ThemeData themeFor(bool dark) {
    apply(dark);
    final brightness = dark ? Brightness.dark : Brightness.light;
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: brightness,
        primary: primary,
        secondary: accent,
        surface: surface,
        error: danger,
      ),
      scaffoldBackgroundColor: bg,
      fontFamily: 'Roboto',
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          side: BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        labelStyle: TextStyle(color: textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: divider,
        thickness: 1,
        space: 1,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor: textSecondary,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle:
            const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      iconTheme: IconThemeData(color: textSecondary),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      splashFactory: InkSparkle.splashFactory,
    );
  }

  static ThemeData light() => themeFor(false);
  static ThemeData dark() => themeFor(true);
}

class _Light {
  static const bg = Color(0xFFF6F7FB);
  static const surface = Color(0xFFFFFFFF);
  static const card = Color(0xFFFFFFFF);
  static const border = Color(0xFFE4E7EF);
  static const divider = Color(0xFFEFF1F6);
  static const textPrimary = Color(0xFF0B1220);
  static const textSecondary = Color(0xFF5B6678);
  static const textMuted = Color(0xFF8A93A6);
  static const values = [
    bg,
    surface,
    card,
    border,
    divider,
    textPrimary,
    textSecondary,
    textMuted,
  ];
}

class _Dark {
  static const bg = Color(0xFF0A0C10);
  static const surface = Color(0xFF12151C);
  static const card = Color(0xFF161A22);
  static const border = Color(0xFF262B36);
  static const divider = Color(0xFF1E232C);
  static const textPrimary = Color(0xFFF2F4F8);
  static const textSecondary = Color(0xFFA3ADBE);
  static const textMuted = Color(0xFF6B7385);
  static const values = [
    bg,
    surface,
    card,
    border,
    divider,
    textPrimary,
    textSecondary,
    textMuted,
  ];
}

/// Breakpoints estilo Tailwind.
class Responsive {
  static const double sm = 640;
  static const double md = 768;
  static const double lg = 1024;
  static const double xl = 1280;

  static bool isMobile(BuildContext c) => MediaQuery.sizeOf(c).width < md;
  static bool isTablet(BuildContext c) {
    final w = MediaQuery.sizeOf(c).width;
    return w >= md && w < lg;
  }

  static bool isDesktop(BuildContext c) => MediaQuery.sizeOf(c).width >= lg;

  static double hPad(BuildContext c) {
    final w = MediaQuery.sizeOf(c).width;
    if (w >= lg) return 40;
    if (w >= md) return 28;
    return 18;
  }
}
