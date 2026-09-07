import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A choice of accent color, applied everywhere the app uses `AppColors.accent`
/// (buttons, highlights, charts…). Each preset carries its own light/dark
/// "soft" tint so it reads well against both backgrounds.
enum AccentPreset { orange, blue, green, purple, pink }

class _AccentSwatch {
  final Color accent;
  final Color softLight;
  final Color softDark;
  const _AccentSwatch(this.accent, this.softLight, this.softDark);
}

const _accentSwatches = <AccentPreset, _AccentSwatch>{
  AccentPreset.orange: _AccentSwatch(Color(0xFFFF5B34), Color(0xFFFFE9E1), Color(0xFF402A20)),
  AccentPreset.blue: _AccentSwatch(Color(0xFF3B82F6), Color(0xFFE3EDFF), Color(0xFF1E2C42)),
  AccentPreset.green: _AccentSwatch(Color(0xFF1F9D57), Color(0xFFE4F3EA), Color(0xFF1B3327)),
  AccentPreset.purple: _AccentSwatch(Color(0xFF8B5CF6), Color(0xFFEFE7FF), Color(0xFF2E2646)),
  AccentPreset.pink: _AccentSwatch(Color(0xFFE5537B), Color(0xFFFCE5EB), Color(0xFF3D2029)),
};

/// The accent color for a given preset, independent of the *currently
/// configured* theme — for rendering swatch pickers without touching
/// [AppColors]'s global state.
Color accentPreviewColor(AccentPreset p) => _accentSwatches[p]!.accent;

String accentPresetLabel(AccentPreset p) => switch (p) {
      AccentPreset.orange => 'Orange',
      AccentPreset.blue => 'Bleu',
      AccentPreset.green => 'Vert',
      AccentPreset.purple => 'Violet',
      AccentPreset.pink => 'Rose',
    };

/// The home tab's layout density — [simple] strips the hero/stat-chip/
/// mini-ranking visuals down to plain text and a single latest match,
/// [complete] is the full dashboard with all sections.
enum DashboardStyle { simple, complete }

String dashboardStyleLabel(DashboardStyle s) => switch (s) {
      DashboardStyle.simple => 'Épuré',
      DashboardStyle.complete => 'Complet',
    };

/// Design tokens ported 1:1 from the Podium.dc.html prototype's :root vars —
/// now resolved dynamically against the current light/dark mode and accent
/// choice instead of being fixed constants. Every existing `AppColors.xxx`
/// call site keeps working unchanged; call [AppColors.configure] whenever
/// the resolved theme changes (see AppState) and the next build picks up
/// the new values automatically.
class AppColors {
  AppColors._();

  static bool _dark = false;
  static AccentPreset _accentPreset = AccentPreset.orange;

  static void configure({required bool dark, required AccentPreset accent}) {
    _dark = dark;
    _accentPreset = accent;
  }

  static bool get isDark => _dark;
  static AccentPreset get accentPreset => _accentPreset;

  static Color get bg => _dark ? const Color(0xFF16151A) : const Color(0xFFF4F2EC);
  static Color get frame => _dark ? const Color(0xFF242229) : const Color(0xFFE7E4DB);
  static Color get card => _dark ? const Color(0xFF201F26) : const Color(0xFFFFFFFF);
  static Color get ink => _dark ? const Color(0xFFF4F2EC) : const Color(0xFF18171C);
  static Color get ink2 => _dark ? const Color(0xFFC9C7D1) : const Color(0xFF3A3944);
  static Color get mut => _dark ? const Color(0xFF8D8A97) : const Color(0xFF8C8A93);
  static Color get line => _dark ? const Color(0x1EFFFFFF) : const Color(0x14181713);
  static Color get accent => _accentSwatches[_accentPreset]!.accent;
  static Color get accentSoft => _dark ? _accentSwatches[_accentPreset]!.softDark : _accentSwatches[_accentPreset]!.softLight;
  static Color get green => _dark ? const Color(0xFF34B872) : const Color(0xFF1F9D57);
  static Color get greenSoft => _dark ? const Color(0xFF1C3327) : const Color(0xFFE4F3EA);
  static Color get gold => const Color(0xFFE8A93B);
  static Color get segTrack => _dark ? const Color(0xFF242229) : const Color(0xFFE7E4DB);
}

class AppRadius {
  AppRadius._();
  static const sm = 11.0;
  static const md = 14.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const sheet = 28.0;
}

/// Space Grotesk — used for numerals & display headings ("disp"/"num" in CSS).
TextStyle dispFont({double? size, FontWeight? weight, double? height, Color? color, double? letterSpacing}) {
  return GoogleFonts.spaceGrotesk(
    fontSize: size,
    fontWeight: weight,
    height: height,
    color: color,
    letterSpacing: letterSpacing,
  );
}

/// Manrope — the base body font.
TextStyle bodyFont({double? size, FontWeight? weight, double? height, Color? color, double? letterSpacing}) {
  return GoogleFonts.manrope(
    fontSize: size,
    fontWeight: weight,
    height: height,
    color: color,
    letterSpacing: letterSpacing,
  );
}

/// Every pushed route (Groups screen, QR scanner…) slides down from the top
/// with a fade, instead of the platform-default side slide.
class TopSlidePageTransitionsBuilder extends PageTransitionsBuilder {
  const TopSlidePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, -0.06), end: Offset.zero).animate(curved),
      child: FadeTransition(opacity: curved, child: child),
    );
  }
}

/// Builds the app's [ThemeData] from the current [AppColors] state — call
/// [AppColors.configure] first (AppState does this whenever the theme
/// mode/accent changes) so this reflects the right light/dark + accent.
ThemeData buildAppTheme() {
  final brightness = AppColors.isDark ? Brightness.dark : Brightness.light;
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: brightness,
      primary: AppColors.accent,
      surface: AppColors.bg,
    ),
    textTheme: (AppColors.isDark ? GoogleFonts.manropeTextTheme(ThemeData(brightness: Brightness.dark).textTheme) : GoogleFonts.manropeTextTheme()),
  );
  return base.copyWith(
    textSelectionTheme: TextSelectionThemeData(cursorColor: AppColors.accent),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: TopSlidePageTransitionsBuilder(),
        TargetPlatform.iOS: TopSlidePageTransitionsBuilder(),
        TargetPlatform.macOS: TopSlidePageTransitionsBuilder(),
        TargetPlatform.linux: TopSlidePageTransitionsBuilder(),
        TargetPlatform.windows: TopSlidePageTransitionsBuilder(),
        TargetPlatform.fuchsia: TopSlidePageTransitionsBuilder(),
      },
    ),
  );
}
