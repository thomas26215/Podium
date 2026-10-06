import 'dart:math' as math;
import 'dart:ui' as ui show Gradient, PathMetric;
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'appearance.dart';
import 'motion.dart';

Color _hsl(double h, double s, double l, [double a = 1]) => HSLColor.fromAHSL(a.clamp(0, 1), h % 360, s.clamp(0, 1), l.clamp(0, 1)).toColor();

/// [c] with its HSL lightness moved by [dl] (−1…1), alpha kept.
Color shiftLightness(Color c, double dl) {
  final h = HSLColor.fromColor(c);
  return h.withLightness((h.lightness + dl).clamp(0.0, 1.0)).toColor().withValues(alpha: c.a);
}

/// WCAG contrast ratio between two opaque colours (1…21).
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// The accent for a custom hue: vivid, darkened just enough for the white
/// text drawn on accents everywhere to stay readable.
Color accentForHue(double hue) {
  for (var l = 0.56; l > 0.26; l -= 0.02) {
    final c = _hsl(hue, 0.8, l);
    if (contrastRatio(c, Colors.white) >= 3.2) return c;
  }
  return _hsl(hue, 0.8, 0.26);
}

/// The accents that predate custom appearances keep their hand-tuned soft
/// tints (light, dark).
const _legacySoft = <AccentId, (Color, Color)>{
  AccentId.orange: (Color(0xFFFFE9E1), Color(0xFF402A20)),
  AccentId.blue: (Color(0xFFE3EDFF), Color(0xFF1E2C42)),
  AccentId.green: (Color(0xFFE4F3EA), Color(0xFF1B3327)),
  AccentId.purple: (Color(0xFFEFE7FF), Color(0xFF2E2646)),
  AccentId.pink: (Color(0xFFFCE5EB), Color(0xFF3D2029)),
};

/// The neutral tones of a palette in one mode.
class _Tones {
  final Color bg, frame, card, ink, ink2, mut, line, hero, onInk, thumb;
  const _Tones({required this.bg, required this.frame, required this.card, required this.ink, required this.ink2, required this.mut, required this.line, required this.hero, required this.onInk, required this.thumb});

  _Tones copyWith({Color? bg, Color? frame, Color? card, Color? line}) =>
      _Tones(bg: bg ?? this.bg, frame: frame ?? this.frame, card: card ?? this.card, ink: ink, ink2: ink2, mut: mut, line: line ?? this.line, hero: hero, onInk: onInk, thumb: thumb);

  static _Tones of(PaletteId palette, double hue, bool dark) {
    switch (palette) {
      case PaletteId.classic:
        // The original Podium.dc.html tokens, untouched.
        return dark
            ? const _Tones(bg: Color(0xFF16151A), frame: Color(0xFF242229), card: Color(0xFF201F26), ink: Color(0xFFF4F2EC), ink2: Color(0xFFC9C7D1), mut: Color(0xFF8D8A97), line: Color(0x1EFFFFFF), hero: Color(0xFF2E2C36), onInk: Color(0xFF18171C), thumb: Color(0xFF3A3843))
            : const _Tones(bg: Color(0xFFF4F2EC), frame: Color(0xFFE7E4DB), card: Color(0xFFFFFFFF), ink: Color(0xFF18171C), ink2: Color(0xFF3A3944), mut: Color(0xFF8C8A93), line: Color(0x14181713), hero: Color(0xFF18171C), onInk: Colors.white, thumb: Color(0xFFFFFFFF));
      case PaletteId.pure:
        return dark
            ? const _Tones(bg: Color(0xFF000000), frame: Color(0xFF1A1A1D), card: Color(0xFF111113), ink: Color(0xFFF5F5F7), ink2: Color(0xFFC7C7CC), mut: Color(0xFF8A8A90), line: Color(0x22FFFFFF), hero: Color(0xFF1C1C1F), onInk: Color(0xFF111113), thumb: Color(0xFF2C2C30))
            : const _Tones(bg: Color(0xFFFFFFFF), frame: Color(0xFFEDEDF0), card: Color(0xFFF6F6F8), ink: Color(0xFF111113), ink2: Color(0xFF34343A), mut: Color(0xFF86868E), line: Color(0x16000000), hero: Color(0xFF111113), onInk: Colors.white, thumb: Color(0xFFFFFFFF));
      default:
        if (dark) {
          final s = palette.darkTint;
          final frame = _hsl(hue, s * 0.85, 0.155);
          return _Tones(
            bg: _hsl(hue, s, 0.085),
            frame: frame,
            card: _hsl(hue, s * 0.9, 0.13),
            ink: _hsl(hue, 0.22, 0.945),
            ink2: _hsl(hue, 0.1, 0.8),
            mut: _hsl(hue, 0.07, 0.57),
            line: const Color(0x1EFFFFFF),
            hero: _hsl(hue, s * 0.8, 0.19),
            onInk: _hsl(hue, 0.16, 0.1),
            thumb: shiftLightness(frame, 0.09),
          );
        }
        final s = palette.lightTint;
        final ink = _hsl(hue, 0.16, 0.1);
        return _Tones(
          bg: _hsl(hue, s, 0.945),
          frame: _hsl(hue, s * 0.8, 0.885),
          card: _hsl(hue, s, 0.994),
          ink: ink,
          ink2: _hsl(hue, 0.1, 0.25),
          mut: _hsl(hue, 0.06, 0.55),
          line: ink.withValues(alpha: 0.08),
          hero: _hsl(hue, 0.16, 0.11),
          onInk: Colors.white,
          thumb: _hsl(hue, s, 0.994),
        );
    }
  }
}

/// An [Appearance] resolved for one mode: every colour token the app reads
/// through `AppColors`, and the decoration "recipes" of its surface style —
/// so a preview can render any appearance side by side with the live one.
@immutable
class AppTokens {
  final Appearance appearance;
  final bool dark;
  final Color bg, frame, card, ink, ink2, mut, line, accent, accentSoft, green, greenSoft, gold, segTrack, onInk, hero;

  /// What screens paint behind themselves: [bg], or nothing when a backdrop
  /// is drawn underneath (see `AppBackdrop`).
  final Color canvas;

  /// The palette's hue, for tinted shadows and backdrops.
  final double hue;

  /// A segmented control's thumb in the dark flat style.
  final Color thumb;

  /// What soft shadows are tinted with: the palette's darkest tone.
  final Color shadowTint;

  /// The neumorphic shade and highlight.
  final Color neuDark, neuLight;

  const AppTokens._({
    required this.appearance,
    required this.dark,
    required this.bg,
    required this.frame,
    required this.card,
    required this.ink,
    required this.ink2,
    required this.mut,
    required this.line,
    required this.accent,
    required this.accentSoft,
    required this.green,
    required this.greenSoft,
    required this.gold,
    required this.segTrack,
    required this.onInk,
    required this.hero,
    required this.canvas,
    required this.hue,
    required this.thumb,
    required this.shadowTint,
    required this.neuDark,
    required this.neuLight,
  });

  factory AppTokens.resolve(Appearance a, {required bool dark}) {
    final accent = a.accent == AccentId.custom ? accentForHue(a.customHue) : a.accent.color;
    final hue = a.palette == PaletteId.tinted ? HSLColor.fromColor(accent).hue : a.palette.hue;
    var t = _Tones.of(a.palette, hue, dark);
    switch (a.surface) {
      case SurfaceStyle.neumorphic:
        // Soft UI needs a mid-tone ground: light enough for the shadows,
        // dark enough for the highlights — and cards cut from the same.
        final b = HSLColor.fromColor(t.bg);
        final bg = b.withLightness(dark ? 0.17 : 0.9).withSaturation(math.min(b.saturation, dark ? 0.2 : 0.32)).toColor();
        t = t.copyWith(bg: bg, card: bg, frame: shiftLightness(bg, -0.04), line: t.ink.withValues(alpha: 0.07));
      case SurfaceStyle.glass:
        t = t.copyWith(card: Colors.white.withValues(alpha: dark ? 0.07 : 0.55));
      case SurfaceStyle.clay:
        t = t.copyWith(card: Color.alphaBlend(accent.withValues(alpha: dark ? 0.1 : 0.07), t.card));
      case SurfaceStyle.outlined:
        t = t.copyWith(card: t.bg, line: t.ink.withValues(alpha: 0.16));
      case SurfaceStyle.neon:
        t = t.copyWith(card: dark ? shiftLightness(t.card, -0.025) : t.card, line: accent.withValues(alpha: dark ? 0.28 : 0.22));
      case SurfaceStyle.brutalist:
        t = t.copyWith(line: t.ink.withValues(alpha: 0.22));
      case SurfaceStyle.flat || SurfaceStyle.elevated || SurfaceStyle.gradient || SurfaceStyle.satin:
        break;
    }
    final legacy = _legacySoft[a.accent];
    final soft = legacy != null ? (dark ? legacy.$2 : legacy.$1) : Color.alphaBlend(accent.withValues(alpha: dark ? 0.2 : 0.13), dark ? const Color(0xFF1C1B21) : Colors.white);
    final bgHsl = HSLColor.fromColor(t.bg);
    return AppTokens._(
      appearance: a,
      dark: dark,
      bg: t.bg,
      frame: t.frame,
      card: t.card,
      ink: t.ink,
      ink2: t.ink2,
      mut: t.mut,
      line: t.line,
      accent: accent,
      accentSoft: soft,
      green: dark ? const Color(0xFF34B872) : const Color(0xFF1F9D57),
      greenSoft: dark ? const Color(0xFF1C3327) : const Color(0xFFE4F3EA),
      gold: const Color(0xFFE8A93B),
      segTrack: t.frame,
      onInk: t.onInk,
      hero: t.hero,
      canvas: a.backdrop == BackdropStyle.none ? t.bg : Colors.transparent,
      hue: hue,
      thumb: t.thumb,
      shadowTint: dark ? Colors.black : _hsl(hue, 0.3, 0.16),
      neuDark: dark ? Colors.black.withValues(alpha: 0.55) : _hsl(bgHsl.hue, math.min(bgHsl.saturation + 0.12, 0.5), bgHsl.lightness - 0.24, 0.5),
      neuLight: dark ? _hsl(bgHsl.hue, bgHsl.saturation, bgHsl.lightness + 0.075, 0.8) : Colors.white.withValues(alpha: 0.9),
    );
  }

  SurfaceStyle get style => appearance.surface;
  double get radiusFactor => appearance.corners.factor;

  /// How things move in this surface style.
  AppMotion get motion => AppMotion.of(style);

  /// A raised card, tile or chip in the surface style. [fill] and [border]
  /// override the plain card colours (a selected or highlighted state);
  /// [selected] also presses it in where the style can show that.
  /// [depth] scales the shadows: 1 for cards, about half for chips.
  /// [borderRadius] replaces [radius] for uneven corners (a chat bubble).
  Decoration surface({
    double radius = 0,
    BorderRadius? borderRadius,
    Color? fill,
    Color? border,
    double borderWidth = 1,
    bool borderless = false,
    bool selected = false,
    BoxShape shape = BoxShape.rectangle,
    double depth = 1,
  }) {
    final br = shape == BoxShape.circle ? null : (borderRadius ?? BorderRadius.circular(radius));
    if (style == SurfaceStyle.flat) {
      return BoxDecoration(color: fill ?? card, border: borderless ? null : Border.all(color: border ?? line, width: borderWidth), borderRadius: br, shape: shape);
    }
    final d = depth;
    final bw = border == null ? 0.0 : borderWidth;
    if (fill != null && fill.a == 0) {
      // A see-through card is a placeholder ("add a game"): only its outline.
      return SurfaceDecoration(borderRadius: br ?? BorderRadius.zero, shape: shape, borderColor: border ?? ink.withValues(alpha: 0.2), borderWidth: math.max(borderWidth, 1.4), style: style, pressable: true);
    }
    SurfaceDecoration deco({Color? color, Gradient? gradient, List<BoxShadow> shadows = const [], List<BoxShadow> inner = const [], Color? borderColor, Gradient? borderGradient, double width = 0}) {
      return SurfaceDecoration(
        color: color,
        gradient: gradient,
        borderRadius: br ?? BorderRadius.zero,
        shape: shape,
        shadows: shadows,
        innerShadows: inner,
        borderColor: borderColor,
        borderGradient: borderColor == null ? borderGradient : null,
        borderWidth: width,
        style: style,
        pressable: true,
      );
    }

    switch (style) {
      case SurfaceStyle.flat:
        throw StateError('handled above');
      case SurfaceStyle.elevated:
        return deco(color: fill ?? card, shadows: _softShadows(selected ? d * 0.4 : d), borderColor: border, width: bw);
      case SurfaceStyle.neumorphic:
        final base = fill ?? card;
        if (selected) {
          // Pressed into the surface — unless it's a dark fill, which the
          // highlight would only smear.
          return deco(color: base, inner: base.computeLuminance() < 0.25 ? const [] : _neuShadows(d * 0.6), borderColor: border, width: bw);
        }
        return deco(color: base, shadows: _neuShadows(d), borderColor: border, width: bw);
      case SurfaceStyle.glass:
        return deco(
          color: fill == null ? null : _glassTint(fill),
          gradient: fill == null ? _diagonal([Colors.white.withValues(alpha: dark ? 0.12 : 0.74), Colors.white.withValues(alpha: dark ? 0.045 : 0.44)]) : null,
          borderColor: border,
          borderGradient: _diagonal([Colors.white.withValues(alpha: dark ? 0.32 : 0.95), Colors.white.withValues(alpha: dark ? 0.05 : 0.3)]),
          width: math.max(bw, 1.2),
          shadows: [BoxShadow(color: shadowTint.withValues(alpha: dark ? 0.35 : 0.09), blurRadius: 28 * d, offset: Offset(0, 10 * d))],
        );
      case SurfaceStyle.clay:
        final base = fill ?? card;
        return deco(
          gradient: _diagonal([shiftLightness(base, dark ? 0.035 : 0.03), base, shiftLightness(base, dark ? -0.02 : -0.035)], [0, 0.45, 1]),
          borderColor: border,
          borderGradient: _diagonal([Colors.white.withValues(alpha: dark ? 0.16 : 0.95), Colors.white.withValues(alpha: 0)], [0, 0.6]),
          width: border == null ? 2 * math.max(d, 0.75) : math.max(borderWidth, 1.5),
          shadows: _clayShadows(selected ? d * 0.45 : d),
          inner: selected ? [BoxShadow(color: Colors.black.withValues(alpha: dark ? 0.3 : 0.07), offset: Offset(2 * d, 3 * d), blurRadius: 6 * d)] : const [],
        );
      case SurfaceStyle.brutalist:
        final o = 5 * d;
        return deco(
          color: fill ?? card,
          borderColor: border ?? ink,
          width: d < 1 ? 1.6 : 2,
          shadows: selected ? const [] : [BoxShadow(color: dark ? accent : ink, offset: Offset(o, o))],
        );
      case SurfaceStyle.outlined:
        return deco(color: fill ?? card, borderColor: border ?? ink.withValues(alpha: dark ? 0.24 : 0.2), width: math.max(borderWidth, 1.4));
      case SurfaceStyle.neon:
        final glow = selected ? 1.0 : 0.7;
        return deco(
          color: fill == null ? card : _neonTint(fill),
          borderColor: border ?? accent.withValues(alpha: selected ? 1 : (dark ? 0.7 : 0.55)),
          width: math.max(borderWidth, 1.3),
          shadows: [
            BoxShadow(color: accent.withValues(alpha: (dark ? 0.38 : 0.22) * glow), blurRadius: 18 * d),
            BoxShadow(color: accent.withValues(alpha: (dark ? 0.25 : 0.12) * glow), blurRadius: 4 * d),
          ],
          inner: selected ? [BoxShadow(color: accent.withValues(alpha: 0.28), blurRadius: 12 * d)] : const [],
        );
      case SurfaceStyle.gradient:
        final base = fill ?? card;
        return deco(
          gradient: _diagonal([base, Color.alphaBlend(accent.withValues(alpha: dark ? 0.16 : 0.11), base)]),
          borderColor: border ?? accent.withValues(alpha: dark ? 0.22 : 0.16),
          width: borderWidth,
          shadows: selected ? const [] : [BoxShadow(color: (dark ? Colors.black : accent).withValues(alpha: dark ? 0.35 : 0.1), blurRadius: 20 * d, offset: Offset(0, 8 * d))],
        );
      case SurfaceStyle.satin:
        final base = fill ?? card;
        return deco(
          gradient: _vertical([shiftLightness(base, dark ? 0.06 : 0.02), shiftLightness(base, dark ? -0.01 : -0.045)]),
          borderColor: border,
          borderGradient: _vertical([Colors.white.withValues(alpha: dark ? 0.2 : 1), (dark ? Colors.black : ink).withValues(alpha: dark ? 0.4 : 0.12)]),
          width: math.max(bw, 1.2),
          shadows: selected
              ? [BoxShadow(color: shadowTint.withValues(alpha: dark ? 0.3 : 0.06), blurRadius: 2, offset: const Offset(0, 1))]
              : [
                  BoxShadow(color: shadowTint.withValues(alpha: dark ? 0.5 : 0.12), blurRadius: 12 * d, offset: Offset(0, 5 * d)),
                  BoxShadow(color: shadowTint.withValues(alpha: dark ? 0.3 : 0.06), blurRadius: 2, offset: const Offset(0, 1)),
                ],
        );
    }
  }

  /// A recessed area inside a card — the box behind a game's emoji, a
  /// score cell… Cheap enough for every row of a list: no blur.
  Decoration well({double radius = 0, Color? fill, bool bordered = false, BoxShape shape = BoxShape.rectangle}) {
    final br = shape == BoxShape.circle ? null : BorderRadius.circular(radius);
    // Holes, not things to push: they rise with an entrance (an outline
    // traces itself) but never take a press.
    SurfaceDecoration deco({Color? color, Gradient? gradient, Color? borderColor, Gradient? borderGradient, double width = 0}) =>
        SurfaceDecoration(color: color, gradient: gradient, borderRadius: br ?? BorderRadius.zero, shape: shape, borderColor: borderColor, borderGradient: borderGradient, borderWidth: width, style: style);
    switch (style) {
      case SurfaceStyle.flat || SurfaceStyle.elevated || SurfaceStyle.gradient:
        return BoxDecoration(color: fill ?? bg, border: bordered ? Border.all(color: line) : null, borderRadius: br, shape: shape);
      case SurfaceStyle.neumorphic:
        // Concave: shaded where the light can't reach, catching it opposite.
        final base = fill ?? bg;
        return deco(gradient: _diagonal([shiftLightness(base, dark ? -0.045 : -0.05), shiftLightness(base, dark ? 0.02 : 0.025)]));
      case SurfaceStyle.glass:
        return deco(
          color: fill != null ? _glassTint(fill) : (dark ? Colors.black.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.4)),
          borderColor: Colors.white.withValues(alpha: dark ? 0.08 : 0.55),
          width: 1,
        );
      case SurfaceStyle.clay:
        final base = fill ?? shiftLightness(card, dark ? -0.03 : -0.045);
        return deco(gradient: _diagonal([shiftLightness(base, -0.03), shiftLightness(base, 0.015)]), borderGradient: _diagonal([Colors.black.withValues(alpha: 0), Colors.white.withValues(alpha: dark ? 0.08 : 0.7)]), width: 1.5);
      case SurfaceStyle.brutalist:
        return deco(color: fill ?? bg, borderColor: ink, width: 1.5);
      case SurfaceStyle.outlined:
        return deco(color: fill, borderColor: ink.withValues(alpha: 0.14), width: 1.2);
      case SurfaceStyle.neon:
        return deco(color: fill != null ? _neonTint(fill) : (dark ? Colors.black.withValues(alpha: 0.35) : accent.withValues(alpha: 0.05)), borderColor: accent.withValues(alpha: 0.25), width: 1);
      case SurfaceStyle.satin:
        final base = fill ?? bg;
        return deco(gradient: _vertical([shiftLightness(base, dark ? -0.03 : -0.04), shiftLightness(base, dark ? 0.01 : 0.01)]), borderGradient: _vertical([(dark ? Colors.black : ink).withValues(alpha: dark ? 0.35 : 0.1), Colors.white.withValues(alpha: dark ? 0.06 : 0.8)]), width: 1);
    }
  }

  /// The track of a segmented control or a progress bar: a [well], but
  /// truly hollowed out in the neumorphic style.
  Decoration track({double radius = 0}) {
    if (style == SurfaceStyle.flat) return BoxDecoration(color: segTrack, borderRadius: BorderRadius.circular(radius));
    if (style == SurfaceStyle.neumorphic) {
      return SurfaceDecoration(color: bg, borderRadius: BorderRadius.circular(radius), innerShadows: _neuShadows(0.55), style: style);
    }
    if (style == SurfaceStyle.elevated || style == SurfaceStyle.gradient) return BoxDecoration(color: segTrack, borderRadius: BorderRadius.circular(radius));
    return well(radius: radius);
  }

  /// The sliding thumb of a segmented control.
  Decoration segmentThumb({double radius = 0}) {
    final br = BorderRadius.circular(radius);
    switch (style) {
      case SurfaceStyle.flat:
        return BoxDecoration(
          color: dark ? thumb : card,
          borderRadius: br,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 3, offset: const Offset(0, 1))],
        );
      case SurfaceStyle.glass:
        return SurfaceDecoration(
          color: Colors.white.withValues(alpha: dark ? 0.16 : 0.85),
          borderRadius: br,
          borderColor: Colors.white.withValues(alpha: dark ? 0.22 : 1),
          borderWidth: 1,
          shadows: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6, offset: const Offset(0, 2))],
          style: style,
        );
      case SurfaceStyle.outlined:
        return SurfaceDecoration(color: ink.withValues(alpha: 0.06), borderRadius: br, borderColor: ink.withValues(alpha: 0.4), borderWidth: 1.4, style: style);
      case SurfaceStyle.neon:
        return SurfaceDecoration(color: accent.withValues(alpha: 0.16), borderRadius: br, borderColor: accent, borderWidth: 1.2, shadows: [BoxShadow(color: accent.withValues(alpha: 0.35), blurRadius: 10)], style: style);
      case SurfaceStyle.brutalist:
        return SurfaceDecoration(color: card, borderRadius: br, borderColor: ink, borderWidth: 1.6, shadows: [BoxShadow(color: dark ? accent : ink, offset: const Offset(2, 2))], style: style);
      case SurfaceStyle.elevated || SurfaceStyle.neumorphic || SurfaceStyle.clay || SurfaceStyle.gradient || SurfaceStyle.satin:
        return surface(radius: radius, fill: style == SurfaceStyle.elevated && dark ? thumb : null, depth: 0.4);
    }
  }

  /// The always-dark "hero" block (leader card, champion banner…);
  /// [depth] shrinks the shadows for a small one.
  Decoration heroSurface({double radius = 0, double depth = 1}) {
    final d = depth;
    final br = BorderRadius.circular(radius);
    SurfaceDecoration deco({Color? color, Gradient? gradient, List<BoxShadow> shadows = const [], Color? borderColor, Gradient? borderGradient, double width = 0}) => SurfaceDecoration(
          color: color,
          gradient: gradient,
          borderRadius: br,
          shadows: shadows,
          borderColor: borderColor,
          borderGradient: borderGradient,
          borderWidth: width,
          style: style,
          pressable: true,
        );
    switch (style) {
      case SurfaceStyle.flat || SurfaceStyle.outlined:
        return BoxDecoration(color: hero, borderRadius: br);
      case SurfaceStyle.elevated:
        return deco(color: hero, shadows: [BoxShadow(color: shadowTint.withValues(alpha: dark ? 0.5 : 0.22), blurRadius: 26 * d, offset: Offset(0, 10 * d))]);
      case SurfaceStyle.neumorphic:
        return deco(color: hero, shadows: _neuShadows(d));
      case SurfaceStyle.glass:
        return deco(
          gradient: _diagonal([hero.withValues(alpha: 0.94), hero.withValues(alpha: 0.8)]),
          borderGradient: _diagonal([Colors.white.withValues(alpha: 0.35), Colors.white.withValues(alpha: 0.04)]),
          width: 1.2,
          shadows: [BoxShadow(color: shadowTint.withValues(alpha: dark ? 0.4 : 0.18), blurRadius: 28 * d, offset: Offset(0, 10 * d))],
        );
      case SurfaceStyle.clay:
        return deco(
          gradient: _diagonal([shiftLightness(hero, 0.07), hero]),
          borderGradient: _diagonal([Colors.white.withValues(alpha: 0.22), Colors.white.withValues(alpha: 0)], [0, 0.6]),
          width: 2,
          shadows: _clayShadows(d),
        );
      case SurfaceStyle.brutalist:
        return deco(color: hero, borderColor: ink, width: 2, shadows: [BoxShadow(color: accent, offset: Offset(5 * d, 5 * d))]);
      case SurfaceStyle.neon:
        return deco(
          color: hero,
          borderColor: accent.withValues(alpha: 0.8),
          width: 1.4,
          shadows: [BoxShadow(color: accent.withValues(alpha: 0.4), blurRadius: 22 * d), BoxShadow(color: accent.withValues(alpha: 0.25), blurRadius: 5 * d)],
        );
      case SurfaceStyle.gradient:
        return deco(gradient: _diagonal([hero, Color.lerp(hero, accent, 0.45)!]), shadows: [BoxShadow(color: accent.withValues(alpha: dark ? 0.2 : 0.25), blurRadius: 24 * d, offset: Offset(0, 10 * d))]);
      case SurfaceStyle.satin:
        return deco(
          gradient: _vertical([shiftLightness(hero, 0.09), hero]),
          borderGradient: _vertical([Colors.white.withValues(alpha: 0.3), Colors.white.withValues(alpha: 0)]),
          width: 1.2,
          shadows: [BoxShadow(color: shadowTint.withValues(alpha: dark ? 0.5 : 0.2), blurRadius: 14 * d, offset: Offset(0, 6 * d))],
        );
    }
  }

  /// An accent-filled call to action (the main button, the "+").
  /// [strong] for the bigger glow of the floating "+"; no [glow] for a
  /// small one inside a card, plain in the original style.
  Decoration accentButton({double radius = 0, bool enabled = true, bool strong = false, bool glow = true, BoxShape shape = BoxShape.rectangle}) {
    final br = shape == BoxShape.circle ? null : BorderRadius.circular(radius);
    final fill = enabled ? accent : accent.withValues(alpha: 0.35);
    final glowA = enabled ? (strong ? 0.4 : 0.28) : 0.0;
    final glowBlur = strong ? 22.0 : 18.0;
    final glowY = strong ? 10.0 : 8.0;
    final halo = BoxShadow(color: accent.withValues(alpha: glowA), blurRadius: glowBlur, offset: Offset(0, glowY));
    SurfaceDecoration deco({Color? color, Gradient? gradient, List<BoxShadow> shadows = const [], Color? borderColor, Gradient? borderGradient, double width = 0}) => SurfaceDecoration(
          color: color,
          gradient: gradient,
          borderRadius: br ?? BorderRadius.zero,
          shape: shape,
          shadows: shadows,
          borderColor: borderColor,
          borderGradient: borderGradient,
          borderWidth: width,
          style: style,
          pressable: true,
        );
    switch (style) {
      case SurfaceStyle.flat:
        return BoxDecoration(color: fill, borderRadius: br, shape: shape, boxShadow: glow ? [halo] : null);
      case SurfaceStyle.elevated:
        // A surface of its own, so that its glow settles under a press.
        return deco(color: fill, shadows: glow ? [halo] : _softShadows(0.5));
      case SurfaceStyle.outlined:
        return BoxDecoration(color: fill, borderRadius: br, shape: shape);
      case SurfaceStyle.neumorphic:
        return deco(color: fill, shadows: enabled ? _neuShadows(strong ? 0.9 : 0.7) : const []);
      case SurfaceStyle.glass:
        return deco(gradient: _diagonal([shiftLightness(fill, 0.07), fill]), borderColor: Colors.white.withValues(alpha: enabled ? 0.45 : 0.15), width: 1, shadows: [halo]);
      case SurfaceStyle.clay:
        return deco(
          gradient: _diagonal([shiftLightness(fill, 0.08), fill, shiftLightness(fill, -0.05)], [0, 0.5, 1]),
          borderGradient: _diagonal([Colors.white.withValues(alpha: enabled ? 0.55 : 0.2), Colors.white.withValues(alpha: 0)], [0, 0.6]),
          width: 2,
          shadows: [BoxShadow(color: accent.withValues(alpha: glowA * 1.1), blurRadius: glowBlur + 4, offset: Offset(0, glowY + 2))],
        );
      case SurfaceStyle.brutalist:
        return deco(color: fill, borderColor: ink, width: 2, shadows: enabled ? [BoxShadow(color: ink, offset: Offset(strong ? 4 : 3, strong ? 4 : 3))] : const []);
      case SurfaceStyle.neon:
        return deco(color: fill, shadows: enabled ? [BoxShadow(color: accent.withValues(alpha: 0.6), blurRadius: 24), BoxShadow(color: accent.withValues(alpha: 0.4), blurRadius: 6)] : const []);
      case SurfaceStyle.gradient:
        final second = accentForHue(HSLColor.fromColor(accent).hue + 32);
        return deco(gradient: _diagonal([fill, enabled ? second : second.withValues(alpha: 0.35)]), shadows: [halo]);
      case SurfaceStyle.satin:
        return deco(
          gradient: _vertical([shiftLightness(fill, 0.1), shiftLightness(fill, -0.04)]),
          borderGradient: _vertical([Colors.white.withValues(alpha: enabled ? 0.6 : 0.2), Colors.black.withValues(alpha: 0.15)]),
          width: 1.2,
          shadows: [BoxShadow(color: accent.withValues(alpha: glowA * 0.8), blurRadius: glowBlur, offset: Offset(0, glowY)), BoxShadow(color: Colors.black.withValues(alpha: enabled ? 0.12 : 0), blurRadius: 3, offset: const Offset(0, 1.5))],
        );
    }
  }

  /// What shows a row pressed when it has no surface of its own (a ranking
  /// row inside a card…): drawn behind it, coming in with the press — a
  /// hollow in neumorphism, a lifted card in relief, a lit frame in neon.
  Decoration pressHighlight({double radius = 0}) {
    final br = BorderRadius.circular(radius);
    return switch (style) {
      SurfaceStyle.flat => BoxDecoration(color: ink.withValues(alpha: 0.05), borderRadius: br),
      SurfaceStyle.elevated => SurfaceDecoration(color: card, borderRadius: br, shadows: _softShadows(0.6)),
      SurfaceStyle.neumorphic => SurfaceDecoration(color: bg, borderRadius: br, innerShadows: _neuShadows(0.45)),
      SurfaceStyle.glass => SurfaceDecoration(color: Colors.white.withValues(alpha: dark ? 0.1 : 0.42), borderRadius: br, borderColor: Colors.white.withValues(alpha: dark ? 0.22 : 0.85), borderWidth: 1),
      SurfaceStyle.clay => SurfaceDecoration(
          color: shiftLightness(card, dark ? -0.03 : -0.04),
          borderRadius: br,
          innerShadows: [BoxShadow(color: Colors.black.withValues(alpha: dark ? 0.3 : 0.08), offset: const Offset(2, 3), blurRadius: 7)],
        ),
      SurfaceStyle.brutalist => SurfaceDecoration(color: accentSoft, borderRadius: br, borderColor: ink, borderWidth: 1.6),
      SurfaceStyle.outlined => SurfaceDecoration(borderRadius: br, borderColor: ink.withValues(alpha: 0.35), borderWidth: 1.4),
      SurfaceStyle.neon => SurfaceDecoration(
          color: accent.withValues(alpha: 0.1),
          borderRadius: br,
          borderColor: accent.withValues(alpha: 0.8),
          borderWidth: 1.2,
          shadows: [BoxShadow(color: accent.withValues(alpha: 0.35), blurRadius: 14)],
        ),
      SurfaceStyle.gradient => SurfaceDecoration(gradient: _diagonal([accent.withValues(alpha: 0.04), accent.withValues(alpha: 0.16)]), borderRadius: br),
      SurfaceStyle.satin => SurfaceDecoration(
          gradient: _vertical([Colors.white.withValues(alpha: dark ? 0.08 : 0.55), (dark ? Colors.black : ink).withValues(alpha: 0.05)]),
          borderRadius: br,
          borderGradient: _vertical([Colors.white.withValues(alpha: dark ? 0.16 : 0.95), Colors.white.withValues(alpha: 0)]),
          borderWidth: 1,
        ),
    };
  }

  /// The pill behind the navigation bar's current tab — hollowed into the
  /// bar in neumorphism, a glowing tube in neon…
  Decoration navIndicator({double radius = 0}) {
    final br = BorderRadius.circular(radius);
    SurfaceDecoration deco({Color? color, Gradient? gradient, List<BoxShadow> shadows = const [], List<BoxShadow> inner = const [], Color? borderColor, double width = 0}) => SurfaceDecoration(
          color: color,
          gradient: gradient,
          borderRadius: br,
          shadows: shadows,
          innerShadows: inner,
          borderColor: borderColor,
          borderWidth: width,
          style: style,
          pressable: true,
        );
    return switch (style) {
      SurfaceStyle.flat => BoxDecoration(color: accentSoft, borderRadius: br),
      SurfaceStyle.elevated || SurfaceStyle.clay || SurfaceStyle.satin => surface(radius: radius, fill: accentSoft, depth: 0.35),
      SurfaceStyle.neumorphic => deco(color: bg, inner: _neuShadows(0.4)),
      SurfaceStyle.glass => deco(color: Colors.white.withValues(alpha: dark ? 0.14 : 0.6), borderColor: Colors.white.withValues(alpha: dark ? 0.25 : 0.9), width: 1),
      SurfaceStyle.brutalist => deco(color: accentSoft, borderColor: ink, width: 1.6, shadows: [BoxShadow(color: dark ? accent : ink, offset: const Offset(2, 2))]),
      SurfaceStyle.outlined => deco(borderColor: ink.withValues(alpha: 0.45), width: 1.4),
      SurfaceStyle.neon => deco(color: accent.withValues(alpha: 0.14), borderColor: accent, width: 1.2, shadows: [BoxShadow(color: accent.withValues(alpha: 0.45), blurRadius: 12)]),
      SurfaceStyle.gradient => deco(gradient: _diagonal([accentSoft, Color.alphaBlend(accent.withValues(alpha: 0.2), accentSoft)])),
    };
  }

  /// How Material's own tap feedback (text and icon buttons, menu items,
  /// list tiles) looks in this style: a ripple, or for the styles that
  /// press rather than splash, only a shade over what's held.
  ({InteractiveInkFeatureFactory? factory, Color? splash, Color? highlight}) get tapInk => switch (style) {
        SurfaceStyle.flat => (factory: null, splash: null, highlight: null),
        SurfaceStyle.elevated => (factory: InkRipple.splashFactory, splash: ink.withValues(alpha: 0.08), highlight: ink.withValues(alpha: 0.04)),
        SurfaceStyle.neumorphic => (factory: NoSplash.splashFactory, splash: Colors.transparent, highlight: neuDark.withValues(alpha: dark ? 0.35 : 0.22)),
        SurfaceStyle.glass => (factory: InkRipple.splashFactory, splash: Colors.white.withValues(alpha: dark ? 0.18 : 0.4), highlight: Colors.white.withValues(alpha: dark ? 0.06 : 0.14)),
        SurfaceStyle.clay => (factory: InkRipple.splashFactory, splash: accent.withValues(alpha: 0.14), highlight: accent.withValues(alpha: 0.05)),
        SurfaceStyle.brutalist => (factory: NoSplash.splashFactory, splash: Colors.transparent, highlight: ink.withValues(alpha: 0.14)),
        SurfaceStyle.outlined => (factory: InkRipple.splashFactory, splash: ink.withValues(alpha: 0.07), highlight: Colors.transparent),
        SurfaceStyle.neon => (factory: InkRipple.splashFactory, splash: accent.withValues(alpha: 0.35), highlight: accent.withValues(alpha: 0.12)),
        SurfaceStyle.gradient => (factory: InkRipple.splashFactory, splash: accent.withValues(alpha: 0.16), highlight: accent.withValues(alpha: 0.06)),
        SurfaceStyle.satin => (factory: InkRipple.splashFactory, splash: Colors.white.withValues(alpha: dark ? 0.16 : 0.35), highlight: Colors.white.withValues(alpha: dark ? 0.05 : 0.12)),
      };

  /// The floating navigation bar: a [surface], which in the flat style
  /// needs a shadow of its own to float at all.
  Decoration floatingBar({double radius = 0}) {
    if (style == SurfaceStyle.flat || style == SurfaceStyle.outlined) {
      return BoxDecoration(
        color: style == SurfaceStyle.outlined ? bg : card,
        border: Border.all(color: style == SurfaceStyle.outlined ? ink.withValues(alpha: 0.2) : line, width: style == SurfaceStyle.outlined ? 1.4 : 1),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [BoxShadow(color: shadowTint.withValues(alpha: dark ? 0.45 : 0.1), blurRadius: 24, offset: const Offset(0, 8))],
      );
    }
    return surface(radius: radius, depth: 0.8);
  }

  /// A text field's fill and borders: (fill, border colour, border width,
  /// focused border width).
  ({Color fill, Color border, double width}) get field => switch (style) {
        SurfaceStyle.flat || SurfaceStyle.elevated || SurfaceStyle.gradient || SurfaceStyle.satin => (fill: card, border: line, width: 1.5),
        SurfaceStyle.neumorphic => (fill: shiftLightness(bg, dark ? -0.03 : -0.035), border: Colors.transparent, width: 1.5),
        SurfaceStyle.glass => (fill: Colors.white.withValues(alpha: dark ? 0.06 : 0.5), border: Colors.white.withValues(alpha: dark ? 0.14 : 0.75), width: 1.5),
        SurfaceStyle.clay => (fill: shiftLightness(card, dark ? -0.03 : -0.035), border: Colors.transparent, width: 1.5),
        SurfaceStyle.brutalist => (fill: card, border: ink, width: 2),
        SurfaceStyle.outlined => (fill: Colors.transparent, border: ink.withValues(alpha: 0.22), width: 1.5),
        SurfaceStyle.neon => (fill: card, border: accent.withValues(alpha: 0.35), width: 1.5),
      };

  // ---- recipes ----

  List<BoxShadow> _softShadows(double d) => [
        BoxShadow(color: shadowTint.withValues(alpha: dark ? 0.4 : 0.07), blurRadius: 22 * d, offset: Offset(0, 8 * d)),
        BoxShadow(color: shadowTint.withValues(alpha: dark ? 0.25 : 0.05), blurRadius: 4 * d, offset: Offset(0, 1.5 * d)),
      ];

  /// The neumorphic pair: shade down-right, light up-left (as inner
  /// shadows, the same pair hollows a shape out instead).
  List<BoxShadow> _neuShadows(double d) => [
        BoxShadow(color: neuDark, offset: Offset(6 * d, 6 * d), blurRadius: 14 * d),
        BoxShadow(color: neuLight, offset: Offset(-6 * d, -6 * d), blurRadius: 14 * d),
      ];

  List<BoxShadow> _clayShadows(double d) {
    final tint = HSLColor.fromColor(accent).withSaturation(0.55).withLightness(0.55).toColor();
    return dark
        ? [BoxShadow(color: Colors.black.withValues(alpha: 0.55), blurRadius: 26 * d, offset: Offset(0, 12 * d)), BoxShadow(color: accent.withValues(alpha: 0.12), blurRadius: 16 * d, offset: Offset(0, 4 * d))]
        : [BoxShadow(color: tint.withValues(alpha: 0.26), blurRadius: 26 * d, offset: Offset(0, 12 * d)), BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6 * d, offset: Offset(0, 3 * d))];
  }

  /// An opaque highlight fill made see-through, for glass.
  Color _glassTint(Color fill) => (fill == accentSoft || fill == greenSoft) ? fill.withValues(alpha: dark ? 0.6 : 0.7) : fill;

  Color _neonTint(Color fill) => fill == accentSoft ? Color.alphaBlend(accent.withValues(alpha: 0.16), card) : fill;

  static LinearGradient _diagonal(List<Color> colors, [List<double>? stops]) => LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors, stops: stops);
  static LinearGradient _vertical(List<Color> colors) => LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors);

  @override
  bool operator ==(Object other) => other is AppTokens && other.appearance == appearance && other.dark == dark;

  @override
  int get hashCode => Object.hash(appearance, dark);
}

/// A box decoration with what [BoxDecoration] can't do: inner shadows (a
/// shape pressed into the surface), a gradient border (a lit edge) and
/// both a colour and a gradient at once. Lerps with itself and with plain
/// [BoxDecoration]s, so animated containers glide between styles.
///
/// Drawn in a surface [style], it also moves like one: pressed under a
/// `Pressable` and rising in under an entrance (see [SurfaceMotion]), it
/// sinks into the background, lands on its shadow, flares up… at paint
/// time, without its widget rebuilding.
@immutable
class SurfaceDecoration extends Decoration {
  final Color? color;

  /// Painted over [color] when both are set.
  final Gradient? gradient;
  final BorderRadius borderRadius;
  final BoxShape shape;
  final List<BoxShadow> shadows;

  /// Cast inside the shape, like CSS `inset` shadows: an offset down-right
  /// shades the top-left inner edge.
  final List<BoxShadow> innerShadows;
  final Color? borderColor;
  final Gradient? borderGradient;
  final double borderWidth;

  /// The surface style whose motion this follows — null for one that
  /// never moves.
  final SurfaceStyle? style;

  /// Whether a press above it pushes it in — false for wells and tracks,
  /// holes rather than things to push.
  final bool pressable;

  const SurfaceDecoration({
    this.color,
    this.gradient,
    this.borderRadius = BorderRadius.zero,
    this.shape = BoxShape.rectangle,
    this.shadows = const [],
    this.innerShadows = const [],
    this.borderColor,
    this.borderGradient,
    this.borderWidth = 0,
    this.style,
    this.pressable = false,
  });

  factory SurfaceDecoration.fromBox(BoxDecoration b) {
    final border = b.border;
    final side = border is Border && border.isUniform ? border.top : null;
    return SurfaceDecoration(
      color: b.color,
      gradient: b.gradient,
      borderRadius: b.borderRadius?.resolve(TextDirection.ltr) ?? BorderRadius.zero,
      shape: b.shape,
      shadows: b.boxShadow ?? const [],
      borderColor: side?.color,
      borderWidth: side?.width ?? 0,
    );
  }

  bool get _hasBorder => borderWidth > 0 && (borderColor != null || borderGradient != null);

  @override
  EdgeInsetsGeometry get padding => _hasBorder ? EdgeInsets.all(borderWidth) : EdgeInsets.zero;

  @override
  bool get isComplex => shadows.isNotEmpty || innerShadows.isNotEmpty;

  RRect _rrect(Rect rect) {
    if (shape == BoxShape.circle) {
      final c = Rect.fromCircle(center: rect.center, radius: rect.shortestSide / 2);
      return RRect.fromRectAndRadius(c, Radius.circular(c.width / 2));
    }
    return borderRadius.toRRect(rect);
  }

  @override
  Path getClipPath(Rect rect, TextDirection textDirection) => Path()..addRRect(_rrect(rect));

  @override
  bool hitTest(Size size, Offset position, {TextDirection? textDirection}) => _rrect(Offset.zero & size).contains(position);

  static SurfaceDecoration? lerp(SurfaceDecoration? a, SurfaceDecoration? b, double t) {
    if (identical(a, b)) return a;
    if (a == null) return b!._scaled(t);
    if (b == null) return a._scaled(1 - t);
    return SurfaceDecoration(
      color: Color.lerp(a.color, b.color, t),
      gradient: Gradient.lerp(a.gradient, b.gradient, t),
      borderRadius: BorderRadius.lerp(a.borderRadius, b.borderRadius, t)!,
      shape: t < 0.5 ? a.shape : b.shape,
      shadows: BoxShadow.lerpList(a.shadows, b.shadows, t) ?? const [],
      innerShadows: BoxShadow.lerpList(a.innerShadows, b.innerShadows, t) ?? const [],
      borderColor: Color.lerp(a.borderColor, b.borderColor, t),
      borderGradient: Gradient.lerp(a.borderGradient, b.borderGradient, t),
      borderWidth: lerpDouble(a.borderWidth, b.borderWidth, t)!,
      style: t < 0.5 ? a.style ?? b.style : b.style ?? a.style,
      pressable: t < 0.5 ? a.pressable : b.pressable,
    );
  }

  SurfaceDecoration _scaled(double t) => SurfaceDecoration(
        color: color == null ? null : Color.lerp(null, color, t),
        gradient: gradient?.scale(t),
        borderRadius: borderRadius,
        shape: shape,
        shadows: [for (final s in shadows) s.scale(t)],
        innerShadows: [for (final s in innerShadows) s.scale(t)],
        borderColor: borderColor == null ? null : Color.lerp(null, borderColor, t),
        borderGradient: borderGradient?.scale(t),
        borderWidth: borderWidth,
        style: style,
        pressable: pressable,
      );

  static SurfaceDecoration? _from(Decoration? d) => switch (d) {
        SurfaceDecoration() => d,
        BoxDecoration() => SurfaceDecoration.fromBox(d),
        _ => null,
      };

  @override
  Decoration? lerpFrom(Decoration? a, double t) {
    if (a == null) return _scaled(t);
    final from = _from(a);
    return from == null ? super.lerpFrom(a, t) : SurfaceDecoration.lerp(from, this, t);
  }

  @override
  Decoration? lerpTo(Decoration? b, double t) {
    if (b == null) return _scaled(1 - t);
    final to = _from(b);
    return to == null ? super.lerpTo(b, t) : SurfaceDecoration.lerp(this, to, t);
  }

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _SurfacePainter(this, onChanged);

  @override
  bool operator ==(Object other) =>
      other is SurfaceDecoration &&
      other.color == color &&
      other.gradient == gradient &&
      other.borderRadius == borderRadius &&
      other.shape == shape &&
      listEquals(other.shadows, shadows) &&
      listEquals(other.innerShadows, innerShadows) &&
      other.borderColor == borderColor &&
      other.borderGradient == borderGradient &&
      other.borderWidth == borderWidth &&
      other.style == style &&
      other.pressable == pressable;

  @override
  int get hashCode => Object.hash(color, gradient, borderRadius, shape, Object.hashAll(shadows), Object.hashAll(innerShadows), borderColor, borderGradient, borderWidth, style, pressable);

  // ---- motion ----

  /// How far its flat shadow lies — where a neo-brutal press lands it.
  Offset get _flatShadow => style == SurfaceStyle.brutalist && shadows.isNotEmpty ? shadows.first.offset : Offset.zero;

  /// This surface [press]ed in (0…1) and [rise]n onto the page (0…1, a
  /// little more while a shadow snaps out) in its [style]: what the
  /// painter draws instead. The extras of a style — a glint, a gloss, an
  /// outline tracing itself — are drawn by the painter on top.
  SurfaceDecoration _moved(SurfaceStyle style, {required double press, required double rise}) {
    var shadows = this.shadows, inner = innerShadows, gradient = this.gradient, borderGradient = this.borderGradient;
    var color = this.color, borderColor = this.borderColor, borderWidth = this.borderWidth;
    if (press > 0) {
      switch (style) {
        case SurfaceStyle.flat:
          break;
        case SurfaceStyle.elevated:
          // Set down on the page: its shadow tucks in under it.
          shadows = _scaledShadows(shadows, 1 - 0.65 * press);
        case SurfaceStyle.neumorphic:
          if (shadows.isEmpty) {
            // Already pressed in (picked): it sinks a little deeper.
            inner = _scaledShadows(inner, 1 + 0.45 * press);
          } else {
            // Raised → flush with the surface → hollowed out: the shadows
            // fold in under it, then the same pair lights it from inside.
            // A dark fill only takes the shade: the highlight would smear.
            final dent = (press * 2 - 1).clamp(0.0, 1.0);
            final dark = color != null && color.computeLuminance() < 0.3;
            inner = [...inner, for (final s in dark ? shadows.take(1) : shadows) _scaledShadow(s, 0.55 * dent)];
            shadows = _scaledShadows(shadows, (1 - press * 2).clamp(0.0, 1.0));
          }
        case SurfaceStyle.glass:
          shadows = _scaledShadows(shadows, 1 - 0.5 * press);
        case SurfaceStyle.clay:
          // Squashed down: less lift, and a dent where the finger went.
          shadows = _scaledShadows(shadows, 1 - 0.55 * press);
          inner = [...inner, BoxShadow(color: Colors.black.withValues(alpha: 0.12 * press), offset: Offset(2, 3) * press, blurRadius: 7 * press)];
        case SurfaceStyle.brutalist:
          // The surface travels onto its shadow (`Pressable` moves it) while
          // the shadow stays where it was — gone under it once pressed home.
          shadows = [for (final s in shadows) BoxShadow(color: s.color, offset: s.offset * (1 - press), blurRadius: s.blurRadius, spreadRadius: s.spreadRadius)];
        case SurfaceStyle.outlined:
          borderWidth += 1.1 * press;
          final tint = borderColor;
          if (color != null && tint != null) color = Color.alphaBlend(tint.withValues(alpha: 0.07 * press), color);
        case SurfaceStyle.neon:
          // The tube flares: brighter, wider glow, and lit from within.
          shadows = [
            for (final s in shadows) BoxShadow(color: s.color.withValues(alpha: (s.color.a * (1 + 1.2 * press)).clamp(0.0, 1.0)), offset: s.offset, blurRadius: s.blurRadius * (1 + 0.5 * press), spreadRadius: s.spreadRadius),
          ];
          final tube = borderColor;
          if (tube != null) {
            borderColor = tube.withValues(alpha: lerpDouble(tube.a, 1, press));
            inner = [...inner, BoxShadow(color: tube.withValues(alpha: 0.32 * press), blurRadius: 12 * press)];
          }
        case SurfaceStyle.gradient:
          // Its colours swing round and run deeper.
          shadows = _scaledShadows(shadows, 1 - 0.7 * press);
          gradient = _turned(gradient, 0.7 * press, deepen: press);
        case SurfaceStyle.satin:
          shadows = _scaledShadows(shadows, 1 - 0.6 * press);
      }
    }
    if (rise != 1) {
      switch (style) {
        case SurfaceStyle.brutalist:
          // A flat shadow slides out from under it, as solid as ever.
          shadows = [for (final s in shadows) BoxShadow(color: s.color, offset: s.offset * rise, blurRadius: s.blurRadius, spreadRadius: s.spreadRadius)];
        case SurfaceStyle.neon:
          // The glow and the tube light up together.
          shadows = [for (final s in shadows) BoxShadow(color: s.color.withValues(alpha: s.color.a * rise.clamp(0.0, 1.0)), offset: s.offset, blurRadius: s.blurRadius, spreadRadius: s.spreadRadius)];
          final tube = borderColor;
          if (tube != null) borderColor = tube.withValues(alpha: tube.a * rise.clamp(0.0, 1.0));
        case SurfaceStyle.gradient:
          shadows = _scaledShadows(shadows, rise);
          gradient = _turned(gradient, -0.9 * (1 - rise));
        case SurfaceStyle.glass:
          shadows = _scaledShadows(shadows, rise);
          borderGradient = borderGradient?.scale(rise.clamp(0.0, 1.0));
        case SurfaceStyle.flat || SurfaceStyle.elevated || SurfaceStyle.neumorphic || SurfaceStyle.clay || SurfaceStyle.outlined || SurfaceStyle.satin:
          shadows = _scaledShadows(shadows, rise);
          inner = _scaledShadows(inner, rise);
      }
    }
    return SurfaceDecoration(
      color: color,
      gradient: gradient,
      borderRadius: borderRadius,
      shape: shape,
      shadows: shadows,
      innerShadows: inner,
      borderColor: borderColor,
      borderGradient: borderGradient,
      borderWidth: borderWidth,
      style: style,
      pressable: pressable,
    );
  }

  /// [s] grown or shrunk by [f] — its spread, blur and reach, and how dark
  /// it is: at 0 it's gone.
  static BoxShadow _scaledShadow(BoxShadow s, double f) =>
      BoxShadow(color: s.color.withValues(alpha: (s.color.a * f).clamp(0.0, 1.0)), offset: s.offset * f, blurRadius: s.blurRadius * f, spreadRadius: s.spreadRadius * f);

  static List<BoxShadow> _scaledShadows(List<BoxShadow> list, double f) => f == 1 ? list : [for (final s in list) _scaledShadow(s, f)];

  /// A linear [gradient] turned by [angle] radians — a gradient card's
  /// colours sweeping round — and [deepen]ed (0…1) toward its last colour.
  static Gradient? _turned(Gradient? gradient, double angle, {double deepen = 0}) {
    if (gradient is! LinearGradient || angle == 0) return gradient;
    final last = gradient.colors.last;
    final colors = deepen == 0 ? gradient.colors : [for (final c in gradient.colors) Color.lerp(c, last, 0.6 * deepen)!];
    return LinearGradient(begin: gradient.begin, end: gradient.end, colors: colors, stops: gradient.stops, tileMode: gradient.tileMode, transform: GradientRotation(angle));
  }
}

class _SurfacePainter extends BoxPainter {
  final SurfaceDecoration d;
  _SurfacePainter(this.d, super.onChanged);

  static Paint _shadowPaint(BoxShadow s) {
    final p = Paint()..color = s.color;
    if (s.blurRadius > 0) p.maskFilter = MaskFilter.blur(BlurStyle.normal, s.blurSigma);
    return p;
  }

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null || size.isEmpty) return;
    final rect = offset & size;

    // What it's going through right now — see SurfaceMotion.
    var d = this.d;
    final style = d.style;
    PressSlot? slot;
    var rise = 1.0;
    if (style != null) {
      rise = SurfaceMotion.rise;
      if (d.pressable) slot = SurfaceMotion.claim(size)?..travel = d._flatShadow;
    }
    final press = slot == null ? 0.0 : slot.value.clamp(0.0, 1.0);
    if (press > 0 || rise != 1) d = d._moved(style!, press: press, rise: rise);
    final rrect = d._rrect(rect);

    for (final s in d.shadows) {
      if (s.color.a == 0) continue;
      canvas.drawRRect(rrect.shift(s.offset).inflate(s.spreadRadius), _shadowPaint(s));
    }
    if (d.color != null && d.color!.a > 0) canvas.drawRRect(rrect, Paint()..color = d.color!);
    if (d.gradient != null) canvas.drawRRect(rrect, Paint()..shader = d.gradient!.createShader(rect, textDirection: configuration.textDirection));

    if (style == SurfaceStyle.glass && press > 0) {
      // Light caught where the finger is: a bright core, tinted by the
      // accent as it spreads through the pane.
      final at = rect.topLeft + Offset(slot!.touch.dx * rect.width, slot.touch.dy * rect.height);
      final r = rect.longestSide * 0.9;
      final light = ui.Gradient.radial(at, r, [Colors.white.withValues(alpha: 0.55 * press), slot.tint.withValues(alpha: 0.2 * press), slot.tint.withValues(alpha: 0)], [0, 0.3, 1]);
      _clipped(canvas, rrect, () => canvas.drawCircle(at, r, Paint()..shader = light));
    }
    if (style == SurfaceStyle.satin) {
      // A gloss sweeping across, once on the way in and with each press.
      final sweep = press > 0 ? press : (rise < 1 ? rise : 0.0);
      if (sweep > 0) _sheen(canvas, rect, rrect, sweep);
    }

    if (d.innerShadows.isNotEmpty) {
      canvas.save();
      canvas.clipRRect(rrect);
      for (final s in d.innerShadows) {
        if (s.color.a == 0) continue;
        // A frame around the shape with a hole where the shape would be if
        // shifted by the offset: blurred, it falls inside along the edges.
        final hole = rrect.shift(s.offset).deflate(s.spreadRadius);
        if (hole.width <= 0 || hole.height <= 0) continue;
        final outer = RRect.fromRectAndRadius(rect.inflate(s.blurRadius * 2 + s.offset.distance + s.spreadRadius.abs() + 4), Radius.zero);
        canvas.drawDRRect(outer, hole, _shadowPaint(s));
      }
      canvas.restore();
    }

    if (d._hasBorder) {
      final w = d.borderWidth;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w;
      final ring = rrect.deflate(w / 2);
      if (d.borderColor != null) {
        paint.color = d.borderColor!;
      } else {
        paint.shader = d.borderGradient!.createShader(rect, textDirection: configuration.textDirection);
      }
      if (style == SurfaceStyle.outlined && rise < 1) {
        _traced(canvas, ring, rise, paint..strokeCap = StrokeCap.round);
      } else {
        canvas.drawRRect(ring, paint);
      }
    }
  }

  static void _clipped(Canvas canvas, RRect rrect, VoidCallback paint) {
    canvas.save();
    canvas.clipRRect(rrect);
    paint();
    canvas.restore();
  }

  /// A diagonal band of light at [u] (0 → 1) of its way across — a shaded
  /// fold ahead of a bright one, so it reads on a pale surface too.
  static void _sheen(Canvas canvas, Rect rect, RRect rrect, double u) {
    final dir = (rect.bottomRight - rect.topLeft) / (rect.bottomRight - rect.topLeft).distance;
    final centre = Offset.lerp(rect.topLeft - dir * rect.shortestSide, rect.bottomRight + dir * rect.shortestSide, u)!;
    final half = dir * rect.shortestSide * 0.8;
    final shader = ui.Gradient.linear(
      centre - half,
      centre + half,
      [Colors.black.withValues(alpha: 0), Colors.black.withValues(alpha: 0.07), Colors.white.withValues(alpha: 0.6), Colors.white.withValues(alpha: 0)],
      [0, 0.38, 0.55, 1],
    );
    _clipped(canvas, rrect, () => canvas.drawRect(rect, Paint()..shader = shader));
  }

  /// The [ring] drawn [t] (0 → 1) of the way round, both ways from its
  /// start — an outline tracing itself.
  static void _traced(Canvas canvas, RRect ring, double t, Paint paint) {
    final ui.PathMetric? metric = (Path()..addRRect(ring)).computeMetrics().firstOrNull;
    if (t <= 0 || metric == null) return;
    final half = metric.length * t / 2;
    canvas.drawPath(metric.extractPath(0, half), paint);
    canvas.drawPath(metric.extractPath(metric.length - half, metric.length), paint);
  }
}
