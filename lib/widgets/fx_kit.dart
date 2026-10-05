import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Shared toolkit for the profile card's procedural animations — banners,
/// avatar frames, name effects and profile effects.
///
/// Two clocks drive them:
///   * `t` (0 → 1, once): an entrance — things fly, fade or trace in;
///   * `ph` (0 → 1, looping, see AmbientLoop): the ambient motion. Anything
///     driven by `ph` must be *periodic* in it — whole sine cycles, wrapped
///     offsets, events placed inside the loop — or the loop shows a seam
///     every time it restarts. The helpers below all are.

const double tau = math.pi * 2;

/// The fractional part of [x], always in 0…1 (also for negatives).
double fract(double x) => x - x.floorToDouble();

/// One sine cycle per loop, times [cycles], shifted by [offset] cycles.
/// In −1…1.
double wave(double ph, [double offset = 0, int cycles = 1]) => math.sin((ph * cycles + offset) * tau);

/// [wave] remapped to 0…1.
double wave01(double ph, [double offset = 0, int cycles = 1]) => 0.5 + 0.5 * wave(ph, offset, cycles);

/// Irregular-looking yet loop-periodic noise, about −1…1: three sines at
/// co-prime integer rates, so it never visibly repeats within a loop but
/// still wraps seamlessly.
double loopNoise(double ph, double seed) => wave(ph, seed, 3) * 0.5 + wave(ph, seed * 1.7 + 0.31, 7) * 0.3 + wave(ph, seed * 2.3 + 0.67, 13) * 0.2;

/// A stable pseudo-random value in 0…1 for an index — per-element
/// randomness that must not change from frame to frame.
double hash01(num n) => fract(math.sin(n * 12.9898 + 78.233) * 43758.5453);

/// 0 → 1 → 0 across u = 0…1 (a sine bump); 0 outside.
double bump(double u) => (u <= 0 || u >= 1) ? 0 : math.sin(u * math.pi);

/// Progress (0…1) through a window of the loop starting at [start] and
/// lasting [length] (both in loop fractions, wrapping past 1) — or null
/// when the loop is outside the window. For events placed in the loop.
double? loopWindow(double ph, double start, double length) {
  final u = fract(ph - start) / length;
  return u < 1 ? u : null;
}

double clamp01(double x) => x < 0 ? 0 : (x > 1 ? 1 : x);

/// Remaps [x] from [a]…[b] to 0…1, clamped.
double span(double x, double a, double b) => clamp01((x - a) / (b - a));

double easeOutCubic(double x) => 1 - math.pow(1 - clamp01(x), 3).toDouble();
double easeInCubic(double x) => math.pow(clamp01(x), 3).toDouble();
double easeInOutSine(double x) => -(math.cos(math.pi * clamp01(x)) - 1) / 2;
double easeOutBack(double x) => Curves.easeOutBack.transform(clamp01(x));
double easeOutElastic(double x) => Curves.elasticOut.transform(clamp01(x));

double lerpD(double a, double b, double t) => a + (b - a) * t;

Paint fillPaint(Color c, [double alpha = 1]) => Paint()..color = c.withValues(alpha: (c.a * alpha).clamp(0.0, 1.0));

Paint strokePaint(Color c, double width, [double alpha = 1]) => Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round
  ..color = c.withValues(alpha: (c.a * alpha).clamp(0.0, 1.0));

/// An additive glow: a radial gradient that brightens what's under it.
void drawGlow(Canvas canvas, Offset c, double radius, Color color, [double alpha = 1]) {
  if (radius <= 0 || alpha <= 0) return;
  canvas.drawCircle(
    c,
    radius,
    Paint()
      ..blendMode = BlendMode.plus
      ..shader = ui.Gradient.radial(c, radius, [color.withValues(alpha: clamp01(alpha)), color.withValues(alpha: 0)]),
  );
}

Color hsv(double hue, double s, double v, [double a = 1]) => HSVColor.fromAHSV(a, fract(hue / 360) * 360, s, v).toColor();

// ============================== particles ==============================

/// Where a particle launched from [p0] at velocity [v0] (px/s) is after
/// [time] seconds, under [gravity] (px/s², downward) and linear [drag]
/// (1/s) — the closed form, so any frame can be drawn without stepping.
Offset ballistic(Offset p0, Offset v0, double time, {double gravity = 900, double drag = 1.4}) {
  final k = drag;
  final e = (1 - math.exp(-k * time)) / k;
  final terminal = gravity / k;
  return Offset(p0.dx + v0.dx * e, p0.dy + terminal * time + (v0.dy - terminal) * e);
}

// ============================== shapes ==============================

/// A four-point twinkle star centred on [p].
void drawSparkle(Canvas canvas, Offset p, double size, Paint paint) {
  if (size <= 0.2) return;
  final s = size, w = size * 0.18;
  final path = Path()
    ..moveTo(p.dx, p.dy - s)
    ..quadraticBezierTo(p.dx + w, p.dy - w, p.dx + s, p.dy)
    ..quadraticBezierTo(p.dx + w, p.dy + w, p.dx, p.dy + s)
    ..quadraticBezierTo(p.dx - w, p.dy + w, p.dx - s, p.dy)
    ..quadraticBezierTo(p.dx - w, p.dy - w, p.dx, p.dy - s)
    ..close();
  canvas.drawPath(path, paint);
}

/// A heart about [size] wide, centred on the origin.
Path heartPath(double size) {
  final s = size / 2;
  return Path()
    ..moveTo(0, s * 0.85)
    ..cubicTo(-s * 1.15, s * 0.05, -s * 0.95, -s * 0.95, 0, -s * 0.35)
    ..cubicTo(s * 0.95, -s * 0.95, s * 1.15, s * 0.05, 0, s * 0.85)
    ..close();
}

/// A five-point star, outer radius [r], centred on the origin.
Path starPath(double r, [double innerRatio = 0.45]) {
  final path = Path();
  for (var i = 0; i < 10; i++) {
    final rr = i.isEven ? r : r * innerRatio;
    final a = -math.pi / 2 + i * math.pi / 5;
    final p = Offset(math.cos(a) * rr, math.sin(a) * rr);
    i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  return path..close();
}

const _pips = {
  1: [Offset(0, 0)],
  2: [Offset(-1, -1), Offset(1, 1)],
  3: [Offset(-1, -1), Offset(0, 0), Offset(1, 1)],
  4: [Offset(-1, -1), Offset(1, -1), Offset(-1, 1), Offset(1, 1)],
  5: [Offset(-1, -1), Offset(1, -1), Offset(0, 0), Offset(-1, 1), Offset(1, 1)],
  6: [Offset(-1, -1), Offset(1, -1), Offset(-1, 0), Offset(1, 0), Offset(-1, 1), Offset(1, 1)],
};

/// A die seen from slightly above: its front side peeking below the top
/// face, the top face shaded, pips on top. [face] 1…6.
void drawDie(
  Canvas canvas,
  Offset c,
  double size,
  int face, {
  double angle = 0,
  double alpha = 1,
  Color body = const Color(0xFFFFFAF2),
  Color side = const Color(0xFFD9CBB8),
  Color pip = const Color(0xFF8B1020),
  double squashX = 1,
  double squashY = 1,
}) {
  if (alpha <= 0.01 || size <= 1) return;
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.rotate(angle);
  canvas.scale(squashX, squashY);
  final r = Radius.circular(size * 0.22);
  final top = Rect.fromCenter(center: Offset.zero, width: size, height: size);
  canvas.drawRRect(RRect.fromRectAndRadius(top.shift(Offset(0, size * 0.14)), r), fillPaint(side, alpha));
  canvas.drawRRect(
    RRect.fromRectAndRadius(top, r),
    Paint()
      ..shader = ui.Gradient.linear(top.topLeft, top.bottomRight, [Color.lerp(body, Colors.white, 0.6)!.withValues(alpha: alpha), body.withValues(alpha: alpha), Color.lerp(body, side, 0.5)!.withValues(alpha: alpha)], [0, 0.55, 1]),
  );
  for (final p in _pips[face.clamp(1, 6)]!) {
    canvas.drawCircle(p * (size * 0.26), size * 0.085, fillPaint(pip, alpha));
  }
  canvas.restore();
}

// ============================== glyphs ==============================

/// Laid-out text glyphs (emoji, card suits, chess pieces…), cached: a
/// `TextPainter.layout` per glyph per frame would sink the frame rate of
/// patterns redrawn sixty times a second. Colour alpha and size are
/// quantised so the cache stays small while things fade and scale.
class GlyphCache {
  GlyphCache._();
  static final _cache = <String, TextPainter>{};
  static bool _listening = false;

  static TextPainter get(String text, double size, Color color, {FontWeight? weight, String? family}) {
    if (!_listening) {
      _listening = true;
      // Newly loaded fonts can change glyph metrics — start over.
      PaintingBindingFonts.onChange(_cache.clear);
    }
    final q = (size * 2).roundToDouble() / 2;
    final c = color.withValues(alpha: (color.a * 24).round() / 24);
    final key = '$text|$q|${c.toARGB32()}|${weight?.value}|$family';
    var tp = _cache[key];
    if (tp == null) {
      if (_cache.length > 900) _cache.clear();
      tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(fontSize: q, color: c, height: 1, fontWeight: weight, fontFamily: family),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      _cache[key] = tp;
    }
    return tp;
  }
}

/// Hooks [GlyphCache] into font-change notifications without importing the
/// painting binding at every call site.
class PaintingBindingFonts {
  static void onChange(VoidCallback listener) {
    try {
      PaintingBinding.instance.systemFonts.addListener(listener);
    } catch (_) {
      // No binding (pure Dart test) — nothing to listen to.
    }
  }
}

/// Paints [text] centred on [center], via [GlyphCache].
void drawGlyph(Canvas canvas, String text, Offset center, double size, Color color, {double angle = 0, double scaleX = 1, double scaleY = 1, FontWeight? weight, String? family}) {
  if (size <= 0.5 || color.a <= 0.02) return;
  final tp = GlyphCache.get(text, size, color, weight: weight, family: family);
  canvas.save();
  canvas.translate(center.dx, center.dy);
  if (angle != 0) canvas.rotate(angle);
  if (scaleX != 1 || scaleY != 1) canvas.scale(scaleX, scaleY);
  tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
  canvas.restore();
}

// ============================== pixel sprites ==============================

final _spritePaths = <List<String>, Map<String, Path>>{};

/// The cells of a pixel-art sprite as one path per colour key (each row a
/// string, '0' = empty), in cell units — built once, then drawn scaled.
Map<String, Path> spritePaths(List<String> rows) => _spritePaths.putIfAbsent(rows, () {
      final out = <String, Path>{};
      for (var r = 0; r < rows.length; r++) {
        for (var c = 0; c < rows[r].length; c++) {
          final k = rows[r][c];
          if (k == '0') continue;
          (out[k] ??= Path()).addRect(Rect.fromLTWH(c.toDouble(), r.toDouble(), 1.02, 1.02));
        }
      }
      return out;
    });

/// Draws a pixel sprite with its top-left at [origin], [cell] px per pixel.
void drawSprite(Canvas canvas, List<String> rows, Offset origin, double cell, Map<String, Color> colors, {double alpha = 1, double glow = 0}) {
  if (alpha <= 0.01) return;
  canvas.save();
  canvas.translate(origin.dx, origin.dy);
  canvas.scale(cell);
  spritePaths(rows).forEach((k, path) {
    final color = colors[k];
    if (color == null) return;
    if (glow > 0) {
      canvas.drawPath(path, Paint()
        ..color = color.withValues(alpha: 0.6 * alpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, glow));
    }
    canvas.drawPath(path, fillPaint(color, alpha));
  });
  canvas.restore();
}
