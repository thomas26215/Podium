import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_tokens.dart';
import 'appearance.dart';
import 'backdrop.dart';
import 'motion.dart';

export 'app_tokens.dart' show AppTokens, SurfaceDecoration, accentForHue, contrastRatio, shiftLightness;
export 'appearance.dart';
export 'motion.dart';

/// The home tab's layout density — [simple] strips the hero/stat-chip/
/// mini-ranking visuals down to plain text and a single latest match,
/// [complete] is the full dashboard with all sections.
enum DashboardStyle { simple, complete }

String dashboardStyleLabel(DashboardStyle s) => switch (s) {
      DashboardStyle.simple => 'Épuré',
      DashboardStyle.complete => 'Complet',
    };

/// Design tokens ported 1:1 from the Podium.dc.html prototype's :root vars —
/// now resolved from the player's [Appearance] (palette, accent, surface
/// style…) for the current light/dark mode, see [AppTokens]. Every
/// `AppColors.xxx` call site reads the live values; call [configure]
/// whenever the mode or appearance changes (AppState does) and the next
/// build picks them up.
class AppColors {
  AppColors._();

  static AppTokens _tokens = AppTokens.resolve(const Appearance(), dark: false);

  static void configure({required bool dark, required Appearance appearance}) {
    if (_tokens.dark == dark && _tokens.appearance == appearance) return;
    _tokens = AppTokens.resolve(appearance, dark: dark);
  }

  /// Everything resolved at once — colours plus the surface recipes.
  static AppTokens get tokens => _tokens;

  /// How things move in the player's surface style.
  static AppMotion get motion => _tokens.motion;

  static bool get isDark => _tokens.dark;

  static Color get bg => _tokens.bg;
  static Color get frame => _tokens.frame;
  static Color get card => _tokens.card;
  static Color get ink => _tokens.ink;
  static Color get ink2 => _tokens.ink2;
  static Color get mut => _tokens.mut;
  static Color get line => _tokens.line;
  static Color get accent => _tokens.accent;
  static Color get accentSoft => _tokens.accentSoft;
  static Color get green => _tokens.green;
  static Color get greenSoft => _tokens.greenSoft;
  static Color get gold => _tokens.gold;
  static Color get segTrack => _tokens.segTrack;

  /// What a screen's Scaffold and AppBar paint: [bg], or nothing at all
  /// when the player picked a backdrop, which every route draws underneath
  /// (see [AppPageTransitionsBuilder]).
  static Color get canvas => _tokens.canvas;

  /// Text/icons drawn on an [ink] fill (a selected pill, a score badge) —
  /// [ink] flips to near-white in dark mode, so what sits on it has to flip
  /// too instead of staying white.
  static Color get onInk => _tokens.onInk;

  /// The always-dark "hero" surface (leader card, champion banner, toast…)
  /// that carries white text in both themes — unlike [ink], which turns
  /// light in dark mode. Lifted a little off [bg] there so it still reads
  /// as a raised block.
  static Color get hero => _tokens.hero;
}

/// Corner radii, scaled by the player's corner style (see [CornerStyle]).
class AppRadius {
  AppRadius._();
  static double get _f => AppColors.tokens.radiusFactor;
  static double get sm => 11.0 * _f;
  static double get md => 14.0 * _f;
  static double get lg => 16.0 * _f;
  static double get xl => 20.0 * _f;
  static double get xxl => 24.0 * _f;
  static double get sheet => 28.0 * _f;

  /// A one-off radius from the original design, scaled like the tokens.
  static double scaled(double r) => r * _f;
}

/// A card, panel or tile in the player's surface style — the one way the
/// app draws them, so an effect picked in the settings reaches every
/// screen. [fill] and [border] override the plain card colours for a
/// highlighted state; [selected] also presses it in where the style allows.
Decoration cardDecoration({
  double radius = 0,
  BorderRadius? borderRadius,
  Color? fill,
  Color? border,
  double borderWidth = 1,
  bool borderless = false,
  bool selected = false,
  BoxShape shape = BoxShape.rectangle,
}) =>
    AppColors.tokens.surface(radius: radius, borderRadius: borderRadius, fill: fill, border: border, borderWidth: borderWidth, borderless: borderless, selected: selected, shape: shape);

/// A chip, pill or small control: a [cardDecoration] with shallower shadows.
Decoration chipDecoration({
  double radius = 0,
  BorderRadius? borderRadius,
  Color? fill,
  Color? border,
  double borderWidth = 1,
  bool borderless = false,
  bool selected = false,
  BoxShape shape = BoxShape.rectangle,
}) =>
    AppColors.tokens.surface(radius: radius, borderRadius: borderRadius, fill: fill, border: border, borderWidth: borderWidth, borderless: borderless, selected: selected, shape: shape, depth: 0.55);

/// A recessed box inside a card (an emoji tile, a score cell…).
Decoration wellDecoration({double radius = 0, Color? fill, bool bordered = false, BoxShape shape = BoxShape.rectangle}) =>
    AppColors.tokens.well(radius: radius, fill: fill, bordered: bordered, shape: shape);

/// The dark "hero" block (see [AppColors.hero]) in the surface style —
/// [depth] below 1 for a small one (an icon tile).
Decoration heroDecoration({double radius = 0, double depth = 1}) => AppColors.tokens.heroSurface(radius: radius, depth: depth);

/// An accent call to action in the surface style — without its [glow]
/// for a small one inside a card.
Decoration accentDecoration({double radius = 0, bool enabled = true, bool strong = false, bool glow = true}) => AppColors.tokens.accentButton(radius: radius, enabled: enabled, strong: strong, glow: glow);

/// The display font of [pair] — numerals & headings ("disp"/"num" in CSS).
TextStyle pairDisplayFont(FontPair pair, {double? size, FontWeight? weight, double? height, Color? color, double? letterSpacing}) {
  return _pairFont(pair.displayFamily, pair.displayScale, pair.tight, size: size, weight: weight, height: height, color: color, letterSpacing: letterSpacing);
}

/// The body font of [pair].
TextStyle pairBodyFont(FontPair pair, {double? size, FontWeight? weight, double? height, Color? color, double? letterSpacing}) {
  return _pairFont(pair.bodyFamily, pair.bodyScale, true, size: size, weight: weight, height: height, color: color, letterSpacing: letterSpacing);
}

TextStyle _pairFont(String? family, double scale, bool tight, {double? size, FontWeight? weight, double? height, Color? color, double? letterSpacing}) {
  final s = size == null ? null : size * scale;
  // Monospaced and pixel faces read cramped with negative tracking.
  final ls = !tight && letterSpacing != null && letterSpacing < 0 ? 0.0 : letterSpacing;
  if (family == null) return TextStyle(fontSize: s, fontWeight: weight, height: height, color: color, letterSpacing: ls);
  return GoogleFonts.getFont(family, fontSize: s, fontWeight: weight, height: height, color: color, letterSpacing: ls);
}

/// The display font (Space Grotesk by default) — used for numerals &
/// display headings ("disp"/"num" in CSS).
TextStyle dispFont({double? size, FontWeight? weight, double? height, Color? color, double? letterSpacing}) {
  final pair = AppColors.tokens.appearance.font;
  if (pair == FontPair.podium) {
    return GoogleFonts.spaceGrotesk(fontSize: size, fontWeight: weight, height: height, color: color, letterSpacing: letterSpacing);
  }
  return pairDisplayFont(pair, size: size, weight: weight, height: height, color: color, letterSpacing: letterSpacing);
}

/// The body font (Manrope by default).
TextStyle bodyFont({double? size, FontWeight? weight, double? height, Color? color, double? letterSpacing}) {
  final pair = AppColors.tokens.appearance.font;
  if (pair == FontPair.podium) {
    return GoogleFonts.manrope(fontSize: size, fontWeight: weight, height: height, color: color, letterSpacing: letterSpacing);
  }
  return pairBodyFont(pair, size: size, weight: weight, height: height, color: color, letterSpacing: letterSpacing);
}

/// How every pushed route (Groups screen, QR scanner…) comes in, in the
/// player's surface style: slid down from the top with a fade in the
/// original one, risen out of the surface in neumorphism, brought into
/// focus behind frosted glass, dropped in hard in neo-brutalism, drawn
/// down like a pen stroke in the outlined style… — always along the
/// vertical, never sideways. Over the player's backdrop, which each route
/// paints for itself so that it stays opaque while it comes in. With
/// reduced motion, screens only fade.
class AppPageTransitionsBuilder extends PageTransitionsBuilder {
  final SurfaceStyle style;
  const AppPageTransitionsBuilder(this.style);

  AppMotion get _motion => AppMotion.of(style);

  @override
  Duration get transitionDuration => _motion.page;

  @override
  Duration get reverseTransitionDuration => _motion.pageReverse;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      return FadeTransition(opacity: animation, child: AppBackdrop(child: child));
    }
    Animation<double> curved(Animation<double> a, Curve curve) => a.drive(CurveTween(curve: curve));
    Animation<double> scale(Animation<double> a, double begin, double end, Curve curve) => a.drive(Tween<double>(begin: begin, end: end).chain(CurveTween(curve: curve)));
    Animation<Offset> slide(Animation<double> a, Offset begin, Offset end, Curve curve) => a.drive(Tween<Offset>(begin: begin, end: end).chain(CurveTween(curve: curve)));
    // The way back speeds up as it goes, the way in settles.
    final leaving = animation.status == AnimationStatus.reverse;

    switch (style) {
      case SurfaceStyle.flat:
        final curve = leaving ? Curves.easeInCubic : Curves.easeOutCubic;
        return FadeTransition(
          opacity: curved(animation, curve),
          child: AppBackdrop(child: SlideTransition(position: slide(animation, const Offset(0, -0.06), Offset.zero, curve), child: child)),
        );
      case SurfaceStyle.elevated:
        // Lifted toward you out of the page behind, which drifts closer.
        return FadeTransition(
          opacity: curved(animation, const Interval(0, 0.7, curve: Curves.easeOut)),
          child: AppBackdrop(
            child: ScaleTransition(
              scale: scale(animation, 0.92, 1, Curves.easeOutCubic),
              child: ScaleTransition(scale: scale(secondaryAnimation, 1, 1.04, Curves.easeOutCubic), child: child),
            ),
          ),
        );
      case SurfaceStyle.neumorphic:
        // Rises out of the surface while the page behind sinks back in.
        return FadeTransition(
          opacity: curved(animation, const Interval(0, 0.55, curve: Curves.easeOut)),
          child: AppBackdrop(
            child: ScaleTransition(
              scale: scale(animation, 0.94, 1, Curves.easeOutQuint),
              child: ScaleTransition(scale: scale(secondaryAnimation, 1, 0.96, Curves.easeInOutCubic), child: child),
            ),
          ),
        );
      case SurfaceStyle.glass:
        // Comes into focus from a frost, the page behind frosting over.
        return FadeTransition(
          opacity: curved(animation, const Interval(0, 0.75, curve: Curves.easeOut)),
          child: AppBackdrop(
            child: _Frosted(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              child: ScaleTransition(scale: scale(animation, 1.06, 1, Curves.easeOutCubic), child: child),
            ),
          ),
        );
      case SurfaceStyle.clay:
        // Bounces up into place; the page behind shrinks away.
        return FadeTransition(
          opacity: curved(animation, const Interval(0, 0.4, curve: Curves.easeOut)),
          child: AppBackdrop(
            child: SlideTransition(
              position: slide(animation, const Offset(0, 0.08), Offset.zero, Curves.easeOutBack),
              child: ScaleTransition(
                scale: scale(animation, 0.94, 1, Curves.easeOutBack),
                child: ScaleTransition(scale: scale(secondaryAnimation, 1, 0.95, Curves.easeOutCubic), child: child),
              ),
            ),
          ),
        );
      case SurfaceStyle.brutalist:
        // Dropped down from the top with a hard stop and a hard edge,
        // shoving the page behind down.
        return SlideTransition(
          position: slide(animation, const Offset(0, -1), Offset.zero, Curves.easeOutExpo),
          child: SlideTransition(
            position: slide(secondaryAnimation, Offset.zero, const Offset(0, 0.25), Curves.easeOutExpo),
            child: _HardEdge(animation: animation, child: AppBackdrop(child: child)),
          ),
        );
      case SurfaceStyle.outlined:
        // Drawn down the screen behind a pen line.
        return _Wipe(animation: animation, child: AppBackdrop(child: child));
      case SurfaceStyle.neon:
        // Strikes on with a stutter; the page behind dims.
        return FadeTransition(
          opacity: curved(animation, leaving ? Curves.easeIn : flickerSoft),
          child: AppBackdrop(
            child: ScaleTransition(
              scale: scale(animation, 1.02, 1, Curves.easeOutCubic),
              child: _Dimmed(animation: secondaryAnimation, child: child),
            ),
          ),
        );
      case SurfaceStyle.gradient:
        // Flows down from the top as the page behind drifts away below.
        return FadeTransition(
          opacity: curved(animation, const Interval(0, 0.7, curve: Curves.easeOut)),
          child: AppBackdrop(
            child: SlideTransition(
              position: slide(animation, const Offset(0, -0.12), Offset.zero, Curves.easeOutQuart),
              child: SlideTransition(position: slide(secondaryAnimation, Offset.zero, const Offset(0, 0.05), Curves.easeOutQuart), child: child),
            ),
          ),
        );
      case SurfaceStyle.satin:
        // Rises gently under a passing gloss.
        return FadeTransition(
          opacity: curved(animation, const Interval(0, 0.65, curve: Curves.easeOut)),
          child: AppBackdrop(
            child: SlideTransition(
              position: slide(animation, const Offset(0, 0.05), Offset.zero, Curves.easeOutQuart),
              child: ScaleTransition(
                scale: scale(secondaryAnimation, 1, 0.98, Curves.easeOutCubic),
                child: _Gloss(animation: animation, child: child),
              ),
            ),
          ),
        );
    }
  }

  @override
  bool operator ==(Object other) => other is AppPageTransitionsBuilder && other.style == style;

  @override
  int get hashCode => style.hashCode;
}

/// Blurs a page coming in out of focus, and the page it covers into it.
class _Frosted extends StatelessWidget {
  final Animation<double> animation, secondaryAnimation;
  final Widget child;
  const _Frosted({required this.animation, required this.secondaryAnimation, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([animation, secondaryAnimation]),
      child: child,
      builder: (context, child) {
        final sigma = 14 * (1 - Curves.easeOutCubic.transform(animation.value)) + 7 * Curves.easeOutCubic.transform(secondaryAnimation.value);
        return ImageFiltered(
          enabled: sigma > 0.05,
          imageFilter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.decal),
          child: child,
        );
      },
    );
  }
}

/// A page's leading edge while it drops in: a hard ink rule along its
/// bottom with a flat shadow under it, gone once it's in place.
class _HardEdge extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;
  const _HardEdge({required this.animation, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final moving = animation.status.isAnimating;
        final ink = AppColors.ink;
        // The shadow behind the opaque page shows only past its edge.
        return DecoratedBox(
          decoration: BoxDecoration(boxShadow: moving ? [BoxShadow(color: ink, offset: const Offset(0, 7))] : null),
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(border: moving ? Border(bottom: BorderSide(color: ink, width: 2.5)) : null),
            child: child,
          ),
        );
      },
    );
  }
}

/// Reveals a page from the top down, a fine line drawing it in.
class _Wipe extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;
  const _Wipe({required this.animation, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final e = Curves.easeInOutCubic.transform(animation.value);
        final drawing = e > 0 && e < 1;
        return ClipRect(
          clipper: _WipeClipper(e),
          clipBehavior: e >= 1 ? Clip.none : Clip.hardEdge,
          child: CustomPaint(foregroundPainter: drawing ? _WipeLine(e, AppColors.ink.withValues(alpha: 0.55)) : null, child: child),
        );
      },
    );
  }
}

class _WipeClipper extends CustomClipper<Rect> {
  final double progress;
  const _WipeClipper(this.progress);

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, size.width, size.height * progress);

  @override
  bool shouldReclip(_WipeClipper old) => old.progress != progress;
}

class _WipeLine extends CustomPainter {
  final double progress;
  final Color color;
  const _WipeLine(this.progress, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * progress - 0.8;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), Paint()
      ..color = color
      ..strokeWidth = 1.6);
  }

  @override
  bool shouldRepaint(_WipeLine old) => old.progress != progress || old.color != color;
}

/// Dims a page as another one covers it.
class _Dimmed extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;
  const _Dimmed({required this.animation, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) => DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5 * animation.value)),
        child: child,
      ),
    );
  }
}

/// A band of gloss passing over a page as it comes in.
class _Gloss extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;
  const _Gloss({required this.animation, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final t = animation.value;
        final sweeping = animation.status == AnimationStatus.forward && t > 0 && t < 1;
        return CustomPaint(foregroundPainter: sweeping ? _GlossPainter(Curves.easeInOutSine.transform(t)) : null, child: child);
      },
    );
  }
}

class _GlossPainter extends CustomPainter {
  final double progress;
  const _GlossPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final dir = Offset(size.width, size.height) / Offset(size.width, size.height).distance;
    final centre = Offset.lerp(-dir * size.shortestSide * 0.6, rect.bottomRight + dir * size.shortestSide * 0.6, progress)!;
    final half = dir * size.shortestSide * 0.45;
    canvas.drawRect(
      rect,
      Paint()..shader = ui.Gradient.linear(centre - half, centre + half, [Colors.white.withValues(alpha: 0), Colors.white.withValues(alpha: 0.13), Colors.white.withValues(alpha: 0)], [0, 0.5, 1]),
    );
  }

  @override
  bool shouldRepaint(_GlossPainter old) => old.progress != progress;
}

/// Builds the app's [ThemeData] from the current [AppColors] state — call
/// [AppColors.configure] first (AppState does this whenever the theme
/// mode/appearance changes) so this reflects the right light/dark + accent.
ThemeData buildAppTheme() {
  final brightness = AppColors.isDark ? Brightness.dark : Brightness.light;
  final family = AppColors.tokens.appearance.font.bodyFamily;
  final baseText = ThemeData(brightness: brightness).textTheme;
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: AppColors.canvas,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: brightness,
      primary: AppColors.accent,
      surface: AppColors.bg,
    ),
    textTheme: family == null ? baseText : GoogleFonts.getTextTheme(family, baseText),
  );
  final tokens = AppColors.tokens;
  final ink = tokens.tapInk;
  return base.copyWith(
    textSelectionTheme: TextSelectionThemeData(cursorColor: AppColors.accent),
    // Material's own buttons and menus answer a tap in the surface style
    // too: rippling, or only shading what's held where things press.
    splashFactory: ink.factory,
    splashColor: ink.splash,
    highlightColor: ink.highlight,
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {for (final platform in TargetPlatform.values) platform: AppPageTransitionsBuilder(tokens.style)},
    ),
  );
}
