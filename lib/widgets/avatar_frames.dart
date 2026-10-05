import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'ambient_loop.dart';
import 'fx_kit.dart';

/// Avatar decorations, Discord-style (see AppUser.avatarFrame).
const kAvatarFrames = <({String id, String label})>[
  (id: 'gold', label: 'Or'),
  (id: 'neon', label: 'Néon'),
  (id: 'rainbow', label: 'Arc-en-ciel'),
  (id: 'pixel', label: 'Pixel'),
  (id: 'royal', label: 'Royal'),
  (id: 'fire', label: 'Feu'),
  (id: 'laurel', label: 'Lauriers'),
  (id: 'ice', label: 'Glace'),
  (id: 'stars', label: 'Étoiles'),
  (id: 'dice', label: 'Dés'),
];

/// Wraps an avatar of diameter [size] in its decoration — or a plain white
/// rim when [frameId] is null. The decoration traces itself in, then
/// lives on its ambient loop; [phase] freezes it at one point of the loop
/// instead (thumbnails, visual checks).
class FramedAvatar extends StatelessWidget {
  final String? frameId;
  final double size;
  final Widget child;
  final double? phase;
  const FramedAvatar({super.key, required this.frameId, required this.size, required this.child, this.phase});

  @override
  Widget build(BuildContext context) {
    final id = frameId;
    if (id == null) {
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 3),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 14, offset: const Offset(0, 6))],
        ),
        child: child,
      );
    }
    final outer = size * 1.22;
    Widget framed(double t, double ph) => SizedBox(
          width: outer,
          height: outer,
          child: CustomPaint(
            painter: _FramePainter(id, t, ph, behind: true),
            foregroundPainter: _FramePainter(id, t, ph, behind: false),
            child: Center(child: child),
          ),
        );
    if (phase != null) return framed(1, phase!);
    return RepaintBoundary(
      child: TweenAnimationBuilder<double>(
        key: ValueKey(id),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1000),
        curve: Curves.easeOutCubic,
        builder: (context, t, _) => AmbientLoop(period: const Duration(seconds: 6), builder: (context, ph) => framed(t, ph)),
      ),
    );
  }
}

/// Paints one frame in two passes: [behind] the avatar (glows, flames
/// that lick up behind it) and in front of it (the ring, gems, the crown).
class _FramePainter extends CustomPainter {
  final String id;
  final double t;
  final double ph;
  final bool behind;
  _FramePainter(this.id, this.t, this.ph, {required this.behind});

  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero);
    final r = s.width / 2 - s.width * 0.05;
    final stroke = s.width * 0.065;
    final arc = Rect.fromCircle(center: c, radius: r);
    final sweep = tau * t;
    Paint ring(List<Color> colors, {double spin = 0, double width = 1}) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke * width
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(colors: colors, transform: GradientRotation(-math.pi / 2 + spin)).createShader(arc);
    void traced(Paint p) => canvas.drawArc(arc, -math.pi / 2, sweep, false, p);

    switch (id) {
      case 'gold':
        if (behind) {
          drawGlow(canvas, c, r * 1.3, const Color(0xFFFFC94D), 0.35 * t);
          return;
        }
        traced(ring(const [Color(0xFFFFF1B8), Color(0xFFC98A12), Color(0xFFFFE08A), Color(0xFF8A5A06), Color(0xFFFFF1B8)], spin: ph * tau));
        // Inner and outer bevel lines for a cast-metal look.
        canvas.drawArc(arc.deflate(stroke * 0.5), -math.pi / 2, sweep, false, strokePaint(const Color(0xFF7A4E05), 1, 0.7 * t));
        canvas.drawArc(arc.inflate(stroke * 0.5), -math.pi / 2, sweep, false, strokePaint(const Color(0xFFFFF6D5), 1, 0.7 * t));
        // A glint racing round the ring twice a loop.
        final g = -math.pi / 2 + ph * tau * 2;
        canvas.drawArc(arc, g, 0.5, false, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke * 0.7
          ..strokeCap = StrokeCap.round
          ..blendMode = BlendMode.plus
          ..shader = SweepGradient(colors: const [Color(0x00FFFFFF), Color(0xCCFFFFFF), Color(0x00FFFFFF)], stops: const [0, 0.04, 0.08], transform: GradientRotation(g)).createShader(arc));
        // Sparkles drifting half a turn per loop: each ends where the one
        // opposite started, so opposite ones twinkle in step.
        for (var i = 0; i < 6; i++) {
          final a = -math.pi / 2 + i * tau / 6 + ph * tau * 0.5 + 0.3;
          final tw = wave01(ph, i / 3, 4);
          drawSparkle(canvas, c + Offset(math.cos(a), math.sin(a)) * (r + stroke * 0.9), stroke * (0.25 + 0.55 * tw) * t, fillPaint(const Color(0xFFFFF4C2), t));
        }

      case 'neon':
        final hue = ph * 360;
        final a = hsv(hue, 0.85, 1), b = hsv(hue + 120, 0.85, 1), cc = hsv(hue + 240, 0.85, 1);
        // A hum, and now and then the stutter of a tired tube.
        final stutter = (ph * 6 % 1) > 0.92 ? 0.3 + 0.7 * ((ph * 600).floor() % 2) : 1.0;
        final hum = (0.75 + 0.25 * wave01(ph, 0, 9)) * stutter;
        if (behind) {
          canvas.drawArc(arc, -math.pi / 2, sweep, false, ring([a, b, cc, a], spin: -ph * tau, width: 2.2)..maskFilter = MaskFilter.blur(BlurStyle.normal, stroke * 1.4));
          drawGlow(canvas, c, r * 1.35, a, 0.3 * hum * t);
          return;
        }
        traced(ring([a, b, cc, a], spin: -ph * tau, width: 0.9)
          ..color = Colors.white.withValues(alpha: hum)
          ..maskFilter = MaskFilter.blur(BlurStyle.solid, stroke * 0.6 * hum));
        traced(strokePaint(Colors.white, stroke * 0.28, 0.85 * hum * t));

      case 'rainbow':
        final colors = [for (var k = 0; k <= 6; k++) hsv(k * 60.0, 0.75, 1)];
        if (behind) {
          canvas.drawArc(arc, -math.pi / 2, sweep, false, ring(colors, spin: ph * tau, width: 1.8)..maskFilter = MaskFilter.blur(BlurStyle.normal, stroke));
          return;
        }
        traced(ring(colors, spin: ph * tau));
        canvas.drawArc(arc.deflate(stroke * 0.25), -math.pi / 2, sweep, false, strokePaint(Colors.white, stroke * 0.18, 0.55 * t));

      case 'pixel':
        if (behind) return;
        const n = 24;
        const palette = [Color(0xFF22D3EE), Color(0xFFA3E635), Color(0xFFF472B6)];
        final chase = (ph * n * 2 + 0.5).floor(); // steps clear of the loop's wrap
        for (var i = 0; i < n; i++) {
          if (i / n > t) break;
          final a = -math.pi / 2 + i * tau / n;
          final p = c + Offset(math.cos(a), math.sin(a)) * r;
          final lit = (i + chase) % 3;
          final px = stroke * 1.15;
          canvas.drawRect(Rect.fromCenter(center: p, width: px, height: px), fillPaint(palette[lit], lit == 0 ? 1 : 0.55));
          if (lit == 0) drawGlow(canvas, p, px * 1.8, palette[0], 0.5 * t);
        }
        // Pixels popping off the ring.
        for (var k = 0; k < 4; k++) {
          final u = loopWindow(ph, k / 4 + 0.05, 0.18);
          if (u == null) continue;
          final a = hash01(k + 3) * tau;
          final p = c + Offset(math.cos(a), math.sin(a)) * (r + stroke + u * stroke * 4);
          canvas.drawRect(Rect.fromCenter(center: p, width: stroke * 0.8, height: stroke * 0.8), fillPaint(palette[k % 3], (1 - u) * t));
        }

      case 'royal':
        if (behind) {
          drawGlow(canvas, c, r * 1.3, const Color(0xFF9D4EDD), 0.35 * t);
          return;
        }
        traced(ring(const [Color(0xFF7C3AED), Color(0xFFE8A93B), Color(0xFF5B21B6), Color(0xFFFFD873), Color(0xFF7C3AED)], spin: ph * tau));
        // Gems orbiting the ring.
        for (var i = 0; i < 4; i++) {
          final a = -math.pi / 4 + i * tau / 4 + ph * tau;
          final p = c + Offset(math.cos(a), math.sin(a)) * r;
          final g = stroke * 0.9 * t;
          final gem = Path()
            ..moveTo(p.dx, p.dy - g)
            ..lineTo(p.dx + g * 0.75, p.dy)
            ..lineTo(p.dx, p.dy + g)
            ..lineTo(p.dx - g * 0.75, p.dy)
            ..close();
          final color = const [Color(0xFFE63946), Color(0xFF3A86FF), Color(0xFF2EC4B6), Color(0xFFFFBE0B)][i];
          canvas.drawPath(gem, Paint()..shader = ui.Gradient.linear(p - Offset(g, g), p + Offset(g, g), [Color.lerp(color, Colors.white, 0.6)!, color, Color.lerp(color, Colors.black, 0.35)!], const [0, 0.5, 1]));
          canvas.drawPath(gem, strokePaint(const Color(0xFFFFE8A3), 1, t));
        }
        // The crown, floating and catching the light.
        final bob = wave(ph, 0, 2) * s.width * 0.025;
        final cw = s.width * 0.42, ch = s.width * 0.22;
        final base = Offset(c.dx, c.dy - r - stroke * 0.2 + bob);
        canvas.save();
        canvas.translate(base.dx, base.dy);
        canvas.rotate(-0.1 + wave(ph, 0.25, 2) * 0.05);
        canvas.scale(t);
        final crown = Path()
          ..moveTo(-cw / 2, 0)
          ..lineTo(-cw / 2, -ch * 0.75)
          ..lineTo(-cw * 0.25, -ch * 0.35)
          ..lineTo(0, -ch)
          ..lineTo(cw * 0.25, -ch * 0.35)
          ..lineTo(cw / 2, -ch * 0.75)
          ..lineTo(cw / 2, 0)
          ..close();
        canvas.drawPath(crown, Paint()..shader = ui.Gradient.linear(Offset(-cw / 2, -ch), Offset(cw / 2, 0), const [Color(0xFFFFF1B8), Color(0xFFE8A93B), Color(0xFFB7791F)], const [0, 0.5, 1]));
        canvas.drawPath(crown, strokePaint(const Color(0xFF7A4E05), 1.1));
        for (final x in [-cw / 2, 0.0, cw / 2]) {
          canvas.drawCircle(Offset(x, x == 0 ? -ch : -ch * 0.75), ch * 0.12, fillPaint(const Color(0xFFFFF6D5)));
        }
        canvas.drawCircle(Offset(0, -ch * 0.3), ch * 0.13, fillPaint(const Color(0xFFE63946)));
        final shine = loopWindow(ph, 0.1, 0.2);
        if (shine != null) {
          canvas.save();
          canvas.clipPath(crown);
          final x = lerpD(-cw, cw, shine);
          canvas.drawRect(Rect.fromLTWH(x - cw * 0.12, -ch, cw * 0.24, ch), Paint()
            ..blendMode = BlendMode.plus
            ..color = Colors.white.withValues(alpha: 0.6 * bump(shine)));
          canvas.restore();
        }
        canvas.restore();

      case 'fire':
        // Flame tongues licking up around the ring (behind the avatar),
        // a molten ring and embers in front.
        if (behind) {
          drawGlow(canvas, c, r * 1.45, const Color(0xFFFF6B1A), (0.4 + 0.15 * wave(ph, 0, 11)) * t);
          const tongues = 22;
          for (final (layer, color, scale) in const [(0, Color(0xFFD62828), 1.0), (1, Color(0xFFFF7B00), 0.78), (2, Color(0xFFFFD166), 0.5)]) {
            final paint = Paint()
              ..blendMode = BlendMode.plus
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, stroke * 0.25)
              ..color = color.withValues(alpha: 0.85 * t);
            for (var i = 0; i < tongues; i++) {
              final a = -math.pi / 2 + i * tau / tongues + layer * 0.07;
              final dir = Offset(math.cos(a), math.sin(a));
              // Tongues on top reach higher; all flicker on their own.
              final up = 0.55 + 0.45 * math.max(0.0, -dir.dy);
              final len = stroke * 2.4 * scale * up * (0.7 + 0.4 * wave01(ph, hash01(i * 3 + layer), 13 + (i % 5) * 4)) * t;
              final base = c + dir * r;
              final tip = base + dir * len + Offset(wave(ph, hash01(i + layer * 50), 17) * stroke * 0.4, -len * 0.45);
              final side = Offset(-dir.dy, dir.dx) * stroke * 0.55 * scale;
              canvas.drawPath(Path()
                ..moveTo(base.dx + side.dx, base.dy + side.dy)
                ..quadraticBezierTo(base.dx + dir.dx * len * 0.5 + side.dx, base.dy + dir.dy * len * 0.5 + side.dy - len * 0.1, tip.dx, tip.dy)
                ..quadraticBezierTo(base.dx + dir.dx * len * 0.5 - side.dx, base.dy + dir.dy * len * 0.5 - side.dy - len * 0.1, base.dx - side.dx, base.dy - side.dy)
                ..close(), paint);
            }
          }
          return;
        }
        traced(ring(const [Color(0xFFFFE066), Color(0xFFFF7B00), Color(0xFFD62828), Color(0xFFFF7B00), Color(0xFFFFE066)], spin: -ph * tau * 2)
          ..maskFilter = MaskFilter.blur(BlurStyle.solid, stroke * (0.35 + 0.2 * wave01(ph, 0, 13))));
        for (var i = 0; i < 12; i++) {
          final life = fract(ph * (3 + i % 3) + hash01(i));
          final a = -math.pi / 2 + (hash01(i + 9) - 0.5) * 2.2;
          final p = c + Offset(math.cos(a), math.sin(a)) * r + Offset(wave(ph, hash01(i + 2), 5) * stroke, -life * s.height * 0.45);
          canvas.drawCircle(p, stroke * 0.18 * (1 - life) + 0.4, fillPaint(Color.lerp(const Color(0xFFFFF3B0), const Color(0xFFFF7B00), life)!, (1 - life) * span(life, 0, 0.12) * t));
        }

      case 'laurel':
        if (behind) return;
        const pairs = 8;
        for (var side = -1; side <= 1; side += 2) {
          // The stem.
          canvas.drawArc(arc, math.pi / 2 + (side < 0 ? 0.3 : -0.3), side * 2.6 * t, false, strokePaint(const Color(0xFF6B4F1D), stroke * 0.25, t));
          for (var i = 0; i < pairs; i++) {
            if (i / pairs > t) break;
            final a = math.pi / 2 + side * (0.4 + i * 0.32);
            final p = c + Offset(math.cos(a), math.sin(a)) * r;
            // A golden glint climbing each branch, from below the first
            // leaf to past the last, twice a loop.
            final at = -1 / 6 + fract(ph * 2) * ((pairs - 1) / pairs + 2 / 6);
            final glint = math.max(0.0, 1 - (i / pairs - at).abs() * 6);
            for (final out in [1, -1]) {
              canvas.save();
              canvas.translate(p.dx, p.dy);
              canvas.rotate(a + side * math.pi / 2 + out * 0.55 + wave(ph, i / pairs, 2) * 0.1);
              final lw = stroke * 1.9, lh = stroke * 0.8;
              final leaf = Path()
                ..moveTo(0, 0)
                ..quadraticBezierTo(lw * 0.5, -lh, lw, 0)
                ..quadraticBezierTo(lw * 0.5, lh, 0, 0)
                ..close();
              final color = Color.lerp(Color.lerp(const Color(0xFF2D6A4F), const Color(0xFFE8A93B), i / pairs)!, Colors.white, glint * 0.6)!;
              canvas.drawPath(leaf, Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(lw, 0), [color, Color.lerp(color, Colors.black, 0.25)!]));
              canvas.drawLine(Offset.zero, Offset(lw * 0.8, 0), strokePaint(Colors.black, 0.6, 0.25));
              canvas.restore();
            }
          }
        }
        canvas.drawCircle(c + Offset(0, r + stroke * 0.2), stroke * 0.35 * t, fillPaint(const Color(0xFFC1121F)));

      case 'ice':
        if (behind) {
          drawGlow(canvas, c, r * 1.35, const Color(0xFF7DD3FC), 0.3 * t);
          return;
        }
        traced(ring(const [Color(0xFFF0FBFF), Color(0xFF7DD3FC), Color(0xFFBAE6FD), Color(0xFF38BDF8), Color(0xFFF0FBFF)], spin: ph * tau));
        for (var i = 0; i < 8; i++) {
          if (i / 8 > t) break;
          final a = -math.pi / 2 + i * tau / 8 + 0.2;
          final dir = Offset(math.cos(a), math.sin(a));
          final shimmer = 0.6 + 0.4 * wave01(ph, i / 8, 3);
          final len = stroke * (1.2 + 0.8 * hash01(i + 5));
          final base = c + dir * (r + stroke * 0.3);
          final side = Offset(-dir.dy, dir.dx) * stroke * 0.35;
          canvas.drawPath(Path()..addPolygon([base + side, base + dir * len, base - side], true), Paint()..shader = ui.Gradient.linear(base, base + dir * len, [Colors.white.withValues(alpha: shimmer), const Color(0xFF7DD3FC).withValues(alpha: 0.6 * shimmer)]));
        }
        // Snowflakes orbiting slowly.
        for (var i = 0; i < 5; i++) {
          final a = i / 5 * tau + ph * tau * (i.isEven ? 1 : -1);
          final p = c + Offset(math.cos(a), math.sin(a)) * (r + stroke * (1.3 + 0.4 * wave(ph, i / 5, 2)));
          final fs = stroke * 0.55;
          final paint = strokePaint(Colors.white, 1, 0.9 * t);
          for (var k = 0; k < 3; k++) {
            final b = k * math.pi / 3 + ph * tau;
            canvas.drawLine(p - Offset(math.cos(b), math.sin(b)) * fs, p + Offset(math.cos(b), math.sin(b)) * fs, paint);
          }
        }

      case 'stars':
        if (behind) {
          drawGlow(canvas, c, r * 1.3, const Color(0xFFFFE08A), 0.25 * t);
          return;
        }
        canvas.drawArc(arc, -math.pi / 2, sweep, false, strokePaint(const Color(0xFFFFE08A), stroke * 0.3, 0.7 * t));
        for (var i = 0; i < 10; i++) {
          final a = -math.pi / 2 + i * tau / 10 + ph * tau;
          final p = c + Offset(math.cos(a), math.sin(a)) * r;
          final glint = 0.4 + 0.6 * wave01(ph, -i / 10, 3);
          final size = stroke * (i.isEven ? 0.95 : 0.65) * glint * t;
          canvas.save();
          canvas.translate(p.dx, p.dy);
          canvas.rotate(ph * tau * 2);
          canvas.drawPath(starPath(size), fillPaint(Color.lerp(const Color(0xFFFFE08A), Colors.white, glint)!));
          canvas.restore();
          if (glint > 0.8) drawGlow(canvas, p, size * 2.5, const Color(0xFFFFF4C2), 0.5 * (glint - 0.8) * 5 * t);
        }

      case 'dice':
        if (behind) return;
        traced(ring(const [Color(0xFF1F1F1F), Color(0xFF5A5A5A), Color(0xFF1F1F1F)], spin: ph * tau));
        for (var i = 0; i < 4; i++) {
          final a = -math.pi / 4 + i * tau / 4 + ph * tau;
          // Each die tumbles as it orbits: at the start of every beat it
          // hops off the ring and flips over — its new face turning up while
          // it's edge-on — landing a quarter turn on. Beats are staggered
          // per die, and none falls on the loop's wrap.
          final beat = ph * 8 + i * 0.25 + 0.125;
          final k = beat.floor();
          final roll = span(fract(beat), 0, 0.4);
          final flip = math.cos(roll * math.pi);
          final face = 1 + (hash01(i * 13 + ((flip > 0 ? k - 1 : k) % 8)) * 6).floor();
          final p = c + Offset(math.cos(a), math.sin(a)) * (r + bump(roll) * stroke * 0.8);
          drawDie(canvas, p, stroke * 2.1 * t * (1 + 0.15 * bump(roll)), face, angle: a + (k + easeOutBack(roll)) * math.pi / 2, squashX: math.max(0.06, flip.abs()), alpha: 1);
        }
    }
  }

  @override
  bool shouldRepaint(_FramePainter old) => old.t != t || old.ph != ph || old.id != id;
}
