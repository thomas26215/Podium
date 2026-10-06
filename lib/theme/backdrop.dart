import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../widgets/fx_kit.dart';
import 'app_theme.dart';

/// Paints the player's backdrop (see [BackdropStyle]) behind [child]. With
/// no backdrop it paints nothing but keeps the same tree, so picking one
/// never rebuilds the screen underneath from scratch.
class AppBackdrop extends StatelessWidget {
  final Widget child;
  const AppBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final t = AppColors.tokens;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: t.appearance.backdrop == BackdropStyle.none ? const SizedBox.shrink() : RepaintBoundary(child: BackdropView(tokens: t)),
        ),
        child,
      ],
    );
  }
}

/// One backdrop, still or drifting (when the player animates it and the
/// device allows motion). Every animated view reads the same clock, so a
/// route fading in over another shows the very same frame.
class BackdropView extends StatefulWidget {
  final AppTokens tokens;

  /// Defaults to the tokens' own backdrop — set for a preview thumbnail.
  final BackdropStyle? style;

  /// Forces a still frame (thumbnails).
  final bool still;
  const BackdropView({super.key, required this.tokens, this.style, this.still = false});

  @override
  State<BackdropView> createState() => _BackdropViewState();
}

class _BackdropViewState extends State<BackdropView> with SingleTickerProviderStateMixin {
  static final _clock = Stopwatch()..start();
  late final Ticker _ticker = createTicker(_tick);
  final _phase = ValueNotifier<double>(0);

  BackdropStyle get _style => widget.style ?? widget.tokens.appearance.backdrop;

  bool get _animated {
    final a = widget.tokens.appearance;
    return !widget.still && _style.animatable && a.animatedBackdrop && !a.reduceMotion && !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);
  }

  void _sync() {
    if (_animated) {
      if (!_ticker.isActive) _ticker.start();
    } else {
      if (_ticker.isActive) _ticker.stop();
      _phase.value = 0;
    }
  }

  void _tick(Duration _) {
    final ms = _periodOf(_style).inMilliseconds;
    _phase.value = (_clock.elapsedMilliseconds % ms) / ms;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(BackdropView old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _phase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(painter: BackdropPainter(widget.tokens, style: _style, phase: _phase));
}

Duration _periodOf(BackdropStyle s) => switch (s) {
      BackdropStyle.aurora => const Duration(seconds: 24),
      BackdropStyle.mesh => const Duration(seconds: 30),
      BackdropStyle.waves => const Duration(seconds: 12),
      BackdropStyle.bubbles => const Duration(seconds: 40),
      BackdropStyle.stars => const Duration(seconds: 10),
      _ => const Duration(seconds: 20),
    };

/// Draws a [BackdropStyle] over the tokens' background colour. Absolute
/// sizes (a 22 px dot grid…), so a thumbnail shows a true-scale crop.
/// Everything that moves is periodic in the phase — no seam on the loop.
class BackdropPainter extends CustomPainter {
  final AppTokens t;
  final BackdropStyle style;
  final ValueListenable<double>? phase;
  BackdropPainter(this.t, {required this.style, this.phase}) : super(repaint: phase);

  bool get _dark => t.dark;

  /// The accent with its hue turned by [dh] degrees.
  Color _shift(double dh) {
    final h = HSLColor.fromColor(t.accent);
    return h.withHue((h.hue + dh) % 360).toColor();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = t.bg);
    final ph = phase?.value ?? 0;
    switch (style) {
      case BackdropStyle.none:
        break;
      case BackdropStyle.gradient:
        _gradient(canvas, rect);
      case BackdropStyle.aurora:
        _aurora(canvas, size, ph);
      case BackdropStyle.mesh:
        _mesh(canvas, size, ph);
      case BackdropStyle.dots:
        _dots(canvas, size);
      case BackdropStyle.grid:
        _grid(canvas, size);
      case BackdropStyle.stripes:
        _stripes(canvas, size);
      case BackdropStyle.notebook:
        _notebook(canvas, size);
      case BackdropStyle.waves:
        _waves(canvas, size, ph);
      case BackdropStyle.bubbles:
        _bubbles(canvas, size, ph);
      case BackdropStyle.stars:
        _stars(canvas, size, ph);
      case BackdropStyle.confetti:
        _confetti(canvas, size);
      case BackdropStyle.suits:
        _suits(canvas, size);
    }
  }

  void _gradient(Canvas canvas, Rect rect) {
    final a = Color.alphaBlend(t.accent.withValues(alpha: _dark ? 0.24 : 0.17), t.bg);
    final b = Color.alphaBlend(_shift(48).withValues(alpha: _dark ? 0.16 : 0.12), t.bg);
    canvas.drawRect(rect, Paint()..shader = ui.Gradient.linear(rect.topLeft, rect.bottomRight, [a, t.bg, b], [0, 0.5, 1]));
  }

  void _blob(Canvas canvas, Offset c, double r, Color color, double alpha) {
    canvas.drawCircle(
      c,
      r,
      Paint()..shader = ui.Gradient.radial(c, r, [color.withValues(alpha: alpha), color.withValues(alpha: alpha * 0.45), color.withValues(alpha: 0)], [0, 0.45, 1]),
    );
  }

  void _aurora(Canvas canvas, Size size, double ph) {
    final w = size.width, h = size.height;
    final reach = math.max(w, h * 0.55);
    final k = _dark ? 0.85 : 1.0;
    final blobs = [
      (c: t.accent, x: 0.1, y: 0.08, r: 0.85, a: 0.36),
      (c: _shift(60), x: 0.95, y: 0.34, r: 0.75, a: 0.3),
      (c: _shift(-50), x: 0.2, y: 0.78, r: 0.85, a: 0.28),
      (c: _shift(150), x: 0.92, y: 1.02, r: 0.6, a: 0.2),
    ];
    for (final (i, b) in blobs.indexed) {
      final dx = wave(ph, i * 0.25) * 0.09, dy = wave(ph, i * 0.25 + 0.3) * 0.06;
      _blob(canvas, Offset((b.x + dx) * w, (b.y + dy) * h), b.r * reach, b.c, b.a * k);
    }
  }

  void _mesh(Canvas canvas, Size size, double ph) {
    final w = size.width, h = size.height;
    final reach = math.sqrt(w * w + h * h) * 0.62;
    final a = _dark ? 0.24 : 0.28;
    final corners = [(x: 0.0, y: 0.0, c: t.accent), (x: 1.0, y: 0.0, c: _shift(90)), (x: 0.0, y: 1.0, c: _shift(200)), (x: 1.0, y: 1.0, c: _shift(290))];
    for (final (i, p) in corners.indexed) {
      final dx = wave(ph, i * 0.25) * 0.12, dy = wave(ph, i * 0.25 + 0.5) * 0.08;
      _blob(canvas, Offset((p.x + dx) * w, (p.y + dy) * h), reach, p.c, a);
    }
  }

  void _dots(Canvas canvas, Size size) {
    const gap = 22.0;
    final ox = (size.width % gap) / 2 + gap / 2, oy = gap / 2;
    final points = <Offset>[
      for (var y = oy; y < size.height; y += gap)
        for (var x = ox; x < size.width; x += gap) Offset(x, y),
    ];
    canvas.drawPoints(
      ui.PointMode.points,
      points,
      Paint()
        ..color = t.ink.withValues(alpha: _dark ? 0.13 : 0.11)
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round,
    );
  }

  void _grid(Canvas canvas, Size size) {
    const gap = 24.0;
    final minor = Paint()
      ..color = t.ink.withValues(alpha: _dark ? 0.07 : 0.055)
      ..strokeWidth = 1;
    final major = Paint()
      ..color = t.accent.withValues(alpha: _dark ? 0.2 : 0.12)
      ..strokeWidth = 1;
    var i = 0;
    for (var x = 0.5; x < size.width; x += gap, i++) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), i % 4 == 0 ? major : minor);
    }
    i = 0;
    for (var y = 0.5; y < size.height; y += gap, i++) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), i % 4 == 0 ? major : minor);
    }
  }

  void _stripes(Canvas canvas, Size size) {
    const gap = 26.0;
    final p = Paint()
      ..color = t.ink.withValues(alpha: _dark ? 0.05 : 0.04)
      ..strokeWidth = 9;
    final h = size.height;
    for (var x = -h; x < size.width + h; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x + h, h), p);
    }
  }

  void _notebook(Canvas canvas, Size size) {
    final rule = Paint()
      ..color = (_dark ? const Color(0xFF7FA6D9) : const Color(0xFF4F86D1)).withValues(alpha: _dark ? 0.16 : 0.22)
      ..strokeWidth = 1;
    for (var y = 58.0; y < size.height; y += 30) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), rule);
    }
    final margin = Paint()
      ..color = const Color(0xFFE0505B).withValues(alpha: _dark ? 0.24 : 0.32)
      ..strokeWidth = 1.2;
    canvas.drawLine(const Offset(12, 0), Offset(12, size.height), margin);
  }

  void _waves(Canvas canvas, Size size, double ph) {
    const gap = 34.0, amp = 7.0, len = 150.0;
    final shift = ph * len;
    final accentLine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..color = t.accent.withValues(alpha: _dark ? 0.18 : 0.14);
    final inkLine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = t.ink.withValues(alpha: _dark ? 0.07 : 0.05);
    var i = 0;
    for (var y = gap / 2; y < size.height + gap; y += gap, i++) {
      final path = Path();
      for (var x = -6.0; x <= size.width + 6; x += 6) {
        final yy = y + math.sin((x + shift + i * 23) / len * tau) * amp;
        x == -6 ? path.moveTo(x, yy) : path.lineTo(x, yy);
      }
      canvas.drawPath(path, i.isEven ? accentLine : inkLine);
    }
  }

  void _bubbles(Canvas canvas, Size size, double ph) {
    final colors = [t.accent, _shift(28), _shift(-28), _shift(56)];
    for (var i = 0; i < 18; i++) {
      final r = 16 + hash01(i * 3.1) * 70;
      final x = hash01(i * 7.7) * size.width;
      // Each bubble rises once or twice per loop — whole laps, no seam.
      final y = fract(hash01(i * 5.3) - ph * (1 + i % 2)) * (size.height + 2 * r) - r;
      final c = Offset(x, y);
      final color = colors[i % colors.length];
      canvas.drawCircle(c, r, Paint()..shader = ui.Gradient.radial(c + Offset(-r * 0.3, -r * 0.3), r * 1.2, [color.withValues(alpha: _dark ? 0.07 : 0.05), color.withValues(alpha: _dark ? 0.17 : 0.13)]));
      canvas.drawCircle(c, r, strokePaint(color, 1, _dark ? 0.18 : 0.16));
    }
  }

  void _stars(Canvas canvas, Size size, double ph) {
    final base = _dark ? Colors.white : t.ink;
    for (var i = 0; i < 160; i++) {
      final p = Offset(hash01(i * 1.3) * size.width, hash01(i * 2.9) * size.height);
      final r = 0.5 + math.pow(hash01(i * 4.1), 3).toDouble() * 1.6;
      final alpha = _dark ? 0.25 + 0.6 * hash01(i * 6.7) : 0.08 + 0.2 * hash01(i * 6.7);
      final twinkle = 0.55 + 0.45 * wave(ph, hash01(i * 9.1), 1 + i % 3);
      canvas.drawCircle(p, r, fillPaint(base, alpha * twinkle));
      if (i % 20 == 0) drawSparkle(canvas, p, 4 + hash01(i * 3.3) * 4, fillPaint(t.accent, (_dark ? 0.7 : 0.4) * twinkle));
    }
  }

  void _confetti(Canvas canvas, Size size) {
    final colors = [t.accent, _shift(70), _shift(160), _shift(250), t.gold];
    final alpha = _dark ? 0.34 : 0.26;
    for (var i = 0; i < 70; i++) {
      final p = Offset(hash01(i * 1.7) * size.width, hash01(i * 3.7) * size.height);
      final s = 4 + hash01(i * 5.9) * 5;
      final paint = fillPaint(colors[i % colors.length], alpha);
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(hash01(i * 8.3) * math.pi);
      switch (i % 3) {
        case 0:
          canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: s * 1.6, height: s * 0.6), const Radius.circular(1)), paint);
        case 1:
          canvas.drawCircle(Offset.zero, s * 0.4, paint);
        default:
          canvas.drawPath(
            Path()
              ..moveTo(0, -s * 0.6)
              ..lineTo(s * 0.55, s * 0.4)
              ..lineTo(-s * 0.55, s * 0.4)
              ..close(),
            paint,
          );
      }
      canvas.restore();
    }
  }

  void _suits(Canvas canvas, Size size) {
    const gap = 54.0, glyphs = ['♠', '♥', '♦', '♣'];
    var row = 0;
    for (var y = 22.0; y < size.height + gap; y += gap, row++) {
      var col = 0;
      for (var x = (row.isOdd ? gap / 2 : 0.0) + 14; x < size.width + gap; x += gap, col++) {
        final g = glyphs[(row + col) % 4];
        final red = g == '♥' || g == '♦';
        final color = red ? t.accent.withValues(alpha: _dark ? 0.14 : 0.1) : t.ink.withValues(alpha: _dark ? 0.09 : 0.07);
        drawGlyph(canvas, g, Offset(x, y), 18, color, angle: (hash01(row * 31 + col) - 0.5) * 0.5);
      }
    }
  }

  @override
  bool shouldRepaint(BackdropPainter old) => old.t != t || old.style != style || old.phase != phase;
}
