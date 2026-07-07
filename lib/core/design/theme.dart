import 'package:flutter/material.dart';

class NexoTheme {
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);
  static Color softOf(Color c) => c.withValues(alpha: 0.10);
  static Color primary = NexoColors.light.primary;
  static Color primaryDark = NexoColors.light.primaryDark;
  static Color accent = NexoColors.light.accent;
  static Color bg = NexoColors.light.bg;
  static Color surface = NexoColors.light.surface;
  static Color card = NexoColors.light.card;
  static Color border = NexoColors.light.border;
  static Color divider = NexoColors.light.divider;
  static Color textPrimary = NexoColors.light.textPrimary;
  static Color textSecondary = NexoColors.light.textSecondary;
  static Color textMuted = NexoColors.light.textMuted;
  static bool _isDark = false;
  static bool get isDark => _isDark;
  static void apply(NexoColors p) {
    _isDark = p.isDark;
    primary = p.primary;
    primaryDark = p.primaryDark;
    accent = p.accent;
    bg = p.bg;
    surface = p.surface;
    card = p.card;
    border = p.border;
    divider = p.divider;
    textPrimary = p.textPrimary;
    textSecondary = p.textSecondary;
    textMuted = p.textMuted;
  }

  static ThemeData themeFor(NexoColors p) {
    apply(p);
    final brightness = p.isDark ? Brightness.dark : Brightness.light;
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: p.primary,
        brightness: brightness,
        primary: p.primary,
        secondary: p.accent,
        surface: p.surface,
        error: danger,
      ),
      scaffoldBackgroundColor: p.bg,
      fontFamily: 'Roboto',
      extensions: <ThemeExtension<dynamic>>[p],
    );
    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: p.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
        iconTheme: IconThemeData(color: p.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: p.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          side: BorderSide(color: p.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.primary, width: 1.5),
        ),
        labelStyle: TextStyle(color: p.textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      dividerTheme: DividerThemeData(color: p.divider, thickness: 1, space: 1),
      tabBarTheme: TabBarThemeData(
        labelColor: p.primary,
        unselectedLabelColor: p.textSecondary,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: p.textPrimary,
        displayColor: p.textPrimary,
      ),
      iconTheme: IconThemeData(color: p.textSecondary),
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

  static ThemeData light() => themeFor(NexoColors.light);
  static ThemeData dark() => themeFor(NexoColors.dark);
}

@immutable
class NexoColors extends ThemeExtension<NexoColors> {
  final String id;
  final String label;
  final bool isDark;
  final Color primary, primaryDark, accent;
  final Color bg, surface, card, border, divider;
  final Color textPrimary, textSecondary, textMuted;
  const NexoColors({
    required this.id,
    required this.label,
    required this.isDark,
    required this.primary,
    required this.primaryDark,
    required this.accent,
    required this.bg,
    required this.surface,
    required this.card,
    required this.border,
    required this.divider,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
  });
  @override
  NexoColors copyWith({
    String? id,
    String? label,
    bool? isDark,
    Color? primary,
    Color? primaryDark,
    Color? accent,
    Color? bg,
    Color? surface,
    Color? card,
    Color? border,
    Color? divider,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
  }) => NexoColors(
    id: id ?? this.id,
    label: label ?? this.label,
    isDark: isDark ?? this.isDark,
    primary: primary ?? this.primary,
    primaryDark: primaryDark ?? this.primaryDark,
    accent: accent ?? this.accent,
    bg: bg ?? this.bg,
    surface: surface ?? this.surface,
    card: card ?? this.card,
    border: border ?? this.border,
    divider: divider ?? this.divider,
    textPrimary: textPrimary ?? this.textPrimary,
    textSecondary: textSecondary ?? this.textSecondary,
    textMuted: textMuted ?? this.textMuted,
  );
  @override
  NexoColors lerp(ThemeExtension<NexoColors>? other, double t) {
    if (other is! NexoColors) return this;
    return t < 0.5 ? this : other;
  }

  static const light = NexoColors(
    id: 'light',
    label: 'Claro',
    isDark: false,
    primary: Color(0xFF6366F1),
    primaryDark: Color(0xFF4338CA),
    accent: Color(0xFF22D3EE),
    bg: Color(0xFFF6F7FB),
    surface: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    border: Color(0xFFE4E7EF),
    divider: Color(0xFFEFF1F6),
    textPrimary: Color(0xFF0B1220),
    textSecondary: Color(0xFF5B6678),
    textMuted: Color(0xFF8A93A6),
  );
  static const dark = NexoColors(
    id: 'dark',
    label: 'Oscuro',
    isDark: true,
    primary: Color(0xFF818CF8),
    primaryDark: Color(0xFF6366F1),
    accent: Color(0xFF22D3EE),
    bg: Color(0xFF0A0C10),
    surface: Color(0xFF12151C),
    card: Color(0xFF161A22),
    border: Color(0xFF262B36),
    divider: Color(0xFF1E232C),
    textPrimary: Color(0xFFF2F4F8),
    textSecondary: Color(0xFFA3ADBE),
    textMuted: Color(0xFF6B7385),
  );
  static const midnight = NexoColors(
    id: 'midnight',
    label: 'Medianoche',
    isDark: true,
    primary: Color(0xFF60A5FA),
    primaryDark: Color(0xFF3B82F6),
    accent: Color(0xFF67E8F9),
    bg: Color(0xFF050B1F),
    surface: Color(0xFF0B1430),
    card: Color(0xFF111C40),
    border: Color(0xFF1C2B55),
    divider: Color(0xFF142149),
    textPrimary: Color(0xFFE2E8F5),
    textSecondary: Color(0xFF9CA8C4),
    textMuted: Color(0xFF6A7796),
  );
  static const sunset = NexoColors(
    id: 'sunset',
    label: 'Atardecer',
    isDark: false,
    primary: Color(0xFFEA580C),
    primaryDark: Color(0xFFC2410C),
    accent: Color(0xFFF59E0B),
    bg: Color(0xFFFFF3E6),
    surface: Color(0xFFFFFAF4),
    card: Color(0xFFFFFFFF),
    border: Color(0xFFF1DCC1),
    divider: Color(0xFFF8E7CF),
    textPrimary: Color(0xFF2D1B07),
    textSecondary: Color(0xFF7A5A3B),
    textMuted: Color(0xFFA08672),
  );
  static const forest = NexoColors(
    id: 'forest',
    label: 'Bosque',
    isDark: true,
    primary: Color(0xFF22C55E),
    primaryDark: Color(0xFF16A34A),
    accent: Color(0xFFA3E635),
    bg: Color(0xFF08130E),
    surface: Color(0xFF0D1D15),
    card: Color(0xFF13261C),
    border: Color(0xFF1F3326),
    divider: Color(0xFF182B20),
    textPrimary: Color(0xFFE6F5EC),
    textSecondary: Color(0xFFA6BFB1),
    textMuted: Color(0xFF738B7E),
  );
  static const rose = NexoColors(
    id: 'rose',
    label: 'Rosa',
    isDark: false,
    primary: Color(0xFFE11D48),
    primaryDark: Color(0xFFBE123C),
    accent: Color(0xFFEC4899),
    bg: Color(0xFFFFF1F6),
    surface: Color(0xFFFFFAFC),
    card: Color(0xFFFFFFFF),
    border: Color(0xFFF6D6E1),
    divider: Color(0xFFFCE3EB),
    textPrimary: Color(0xFF2A0913),
    textSecondary: Color(0xFF7A4153),
    textMuted: Color(0xFFA08291),
  );
  static const List<NexoColors> all = [
    light,
    dark,
    midnight,
    sunset,
    forest,
    rose,
  ];
  static NexoColors byId(String id) =>
      all.firstWhere((p) => p.id == id, orElse: () => light);
}

extension NexoColorsContext on BuildContext {
  NexoColors get nx =>
      Theme.of(this).extension<NexoColors>() ?? NexoColors.light;
}
