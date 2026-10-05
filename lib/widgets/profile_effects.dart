import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'ambient_loop.dart';
import 'fx_kit.dart';

/// Effects played over the profile card (see AppUser.profileEffect): a
/// burst when the profile opens, then a lighter ambient version that keeps
/// going — Discord's "profile effects".
const kProfileEffects = <({String id, String label, String emoji})>[
  (id: 'confetti', label: 'Confettis', emoji: '🎉'),
  (id: 'sparkles', label: 'Étincelles', emoji: '✨'),
  (id: 'snow', label: 'Neige', emoji: '❄️'),
  (id: 'fireworks', label: 'Feu d\'artifice', emoji: '🎆'),
  (id: 'dice', label: 'Pluie de dés', emoji: '🎲'),
  (id: 'hearts', label: 'Cœurs', emoji: '💖'),
  (id: 'pixels', label: 'Pixels', emoji: '👾'),
  (id: 'coins', label: 'Pièces d\'or', emoji: '🪙'),
  (id: 'petals', label: 'Pétales', emoji: '🌸'),
  (id: 'bubbles', label: 'Bulles', emoji: '🫧'),
  (id: 'lightning', label: 'Éclairs', emoji: '⚡'),
  (id: 'shooting', label: 'Étoiles filantes', emoji: '🌠'),
];

const _introSeconds = 3.4;

/// Plays [effectId] over its parent (wrap in Positioned.fill): the intro
/// burst — again whenever [effectId] or [replayToken] changes — then the
/// ambient loop. Ignores touches.
class ProfileEffectOverlay extends StatefulWidget {
  final String? effectId;
  final Object? replayToken;
  const ProfileEffectOverlay({super.key, required this.effectId, this.replayToken});

  @override
  State<ProfileEffectOverlay> createState() => _ProfileEffectOverlayState();
}

class _ProfileEffectOverlayState extends State<ProfileEffectOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _intro;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 3400));
    if (widget.effectId != null) _intro.forward();
  }

  @override
  void didUpdateWidget(ProfileEffectOverlay old) {
    super.didUpdateWidget(old);
    if (widget.effectId != old.effectId || widget.replayToken != old.replayToken) {
      if (widget.effectId == null) {
        _intro.value = 1;
      } else {
        _intro.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.effectId;
    if (id == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: RepaintBoundary(
        child: AmbientLoop(
          period: const Duration(seconds: 8),
          builder: (context, ph) => AnimatedBuilder(
            animation: _intro,
            builder: (context, _) {
              final intro = _intro.isCompleted ? null : _intro.value;
              // The ambient version fades in under the end of the burst.
              final ambient = intro == null ? 1.0 : span(intro, 0.55, 1);
              return CustomPaint(painter: ProfileEffectPainter(id, intro: intro, ph: ph, ambient: ambient), size: Size.infinite);
            },
          ),
        ),
      ),
    );
  }
}

/// One frame of a profile effect: the intro burst at [intro] (0…1, or
/// null once it's over) plus the ambient loop at phase [ph], weighted by
/// [ambient]. Public so tests can render any instant of an effect.
class ProfileEffectPainter extends CustomPainter {
  final String id;
  final double? intro;
  final double ph;
  final double ambient;
  ProfileEffectPainter(this.id, {required this.intro, required this.ph, required this.ambient});

  static const _palette = [Color(0xFFFF5B34), Color(0xFFFFC94D), Color(0xFF4DC3FF), Color(0xFF6BFF95), Color(0xFFC77DFF), Color(0xFFFF6BB5)];
  static const _avatar = Offset(64, 64); // the avatar's centre on the card

  @override
  void paint(Canvas canvas, Size s) {
    if (s.isEmpty) return;
    final i = intro;
    if (ambient > 0) _ambient(canvas, s, ambient);
    if (i != null) _intro(canvas, s, i, i * _introSeconds, fadeOut: 1 - span(i, 0.78, 1));
  }

  // ---------------------------------------------------------------- intros

  void _intro(Canvas canvas, Size s, double u, double sec, {required double fadeOut}) {
    final w = s.width, h = s.height;
    switch (id) {
      case 'confetti':
        // Two cannons in the bottom corners, three volleys each.
        for (var k = 0; k < 96; k++) {
          final left = k.isEven;
          final delay = (k % 3) * 0.18;
          final tt = sec - delay;
          if (tt <= 0) continue;
          // Scaled to the card: they peak at 55–80 % of its height, then
          // float down on heavy drag like real paper.
          // Each piece with its own spread and drag, so the volleys fan out
          // across the card instead of flying as two clumps.
          final drag = 2.3 + 1.4 * hash01(k + 600);
          final v = Offset((left ? 1 : -1) * (0.9 + 2.6 * hash01(k)) * h, -(2.2 + 1.5 * hash01(k + 300)) * h);
          var p = ballistic(Offset(left ? -8 : w + 8, h * 0.98), v, tt, gravity: 0.5 * drag * h, drag: drag);
          p += Offset(math.sin(tt * 5 + k) * 14 * (1 - math.exp(-tt)), 0);
          _confettiPiece(canvas, p, k, spin: tt * (3 + 5 * hash01(k + 8)), flip: math.cos(tt * (7 + 6 * hash01(k + 9)) + k), wiggle: tt * 8, alpha: fadeOut);
        }
      case 'sparkles':
        for (var k = 0; k < 36; k++) {
          final life = 0.6 + hash01(k + 50);
          if (sec > life) continue;
          final a = hash01(k) * tau;
          final p = ballistic(_avatar, Offset(math.cos(a), math.sin(a)) * (160 + 300 * hash01(k + 9)), sec, gravity: 40, drag: 3);
          final k01 = bump(sec / life);
          drawSparkle(canvas, p, (3 + 5 * hash01(k + 3)) * k01, fillPaint(Color.lerp(Colors.white, const Color(0xFFFFE08A), hash01(k + 7))!, k01));
          drawGlow(canvas, p, 10 * k01, const Color(0xFFFFF4C2), 0.5 * k01);
        }
        for (var k = 0; k < 26; k++) {
          final start = 0.15 + hash01(k + 200) * 2.6;
          final local = (sec - start) / 0.55;
          if (local <= 0 || local >= 1) continue;
          final p = Offset(hash01(k + 400) * w, hash01(k + 600) * h);
          final k01 = bump(local);
          drawSparkle(canvas, p, (4 + 7 * hash01(k + 800)) * k01, fillPaint(Colors.white, k01 * fadeOut));
        }
      case 'snow':
        for (var k = 0; k < 70; k++) {
          final depth = 1 + k % 3;
          final delay = hash01(k + 5) * 1.2;
          final tt = sec - delay;
          if (tt <= 0) continue;
          final p = Offset(hash01(k) * w + math.sin(tt * 1.4 + k) * 10 * depth, -10 + tt * (40 + 35 * depth));
          _flake(canvas, p, depth, (0.5 + 0.17 * depth) * fadeOut, tt * 0.6);
        }
      case 'fireworks':
        const rockets = [(0.0, 0.58, 0.28), (0.35, 0.82, 0.18), (0.7, 0.7, 0.36), (1.15, 0.93, 0.24)];
        for (final (r, (launch, fx, fy)) in rockets.indexed) {
          final color = _palette[(r * 2 + 1) % _palette.length];
          final apex = Offset(w * fx, h * fy);
          final rise = (sec - launch) / 0.55;
          if (rise > 0 && rise < 1) _rocket(canvas, apex, h, rise, 1);
          final tt = sec - launch - 0.55;
          if (tt > 0 && tt < 1.5) _burst(canvas, apex, color, tt, 56, r, scale: h / 200, fade: fadeOut);
        }
      case 'dice':
        for (var k = 0; k < 9; k++) {
          final size = 16 + 10 * hash01(k + 4);
          final x = w * (0.35 + 0.6 * hash01(k));
          final delay = hash01(k + 20) * 0.9;
          final tt = sec - delay;
          if (tt <= 0) continue;
          final (y, spin, settled) = _bouncing(-20, h - size * 0.7, tt, k);
          final face = settled ? 1 + (hash01(k + 77) * 6).floor() : 1 + (hash01(k * 9 + (tt * 10).floor()) * 6).floor();
          drawDie(canvas, Offset(x, y), size, face, angle: spin, alpha: fadeOut);
        }
      case 'hearts':
        for (var k = 0; k < 30; k++) {
          final delay = hash01(k + 2) * 1.6;
          final tt = sec - delay;
          if (tt <= 0) continue;
          final y = h + 20 - tt * (90 + 90 * hash01(k + 6));
          if (y < -30) continue;
          final p = Offset(w * (0.2 + 0.78 * hash01(k)) + math.sin(tt * 3 + k) * 14, y);
          final size = (12 + 12 * hash01(k + 9)) * easeOutBack(tt / 0.4);
          _heart(canvas, p, size, k, clamp01(y / (h * 0.25)) * fadeOut, math.sin(tt * 2 + k) * 0.25);
        }
        // A pop of little hearts out of the avatar.
        for (var k = 0; k < 10; k++) {
          if (sec > 1.2) break;
          final a = k / 10 * tau;
          final p = ballistic(_avatar, Offset(math.cos(a), math.sin(a)) * 220, sec, gravity: 60, drag: 3.5);
          _heart(canvas, p, 10 * bump(sec / 1.2), k, 1, 0);
        }
      case 'pixels':
        final ring = sec / 0.8;
        if (ring < 1) {
          final r = 10 + ring * 90;
          final step = 6.0;
          for (var a = 0.0; a < tau; a += 0.16) {
            final p = _avatar + Offset(math.cos(a), math.sin(a)) * r;
            canvas.drawRect(Rect.fromLTWH((p.dx / step).floorToDouble() * step, (p.dy / step).floorToDouble() * step, step - 1, step - 1), fillPaint(const Color(0xFF22D3EE), 1 - ring));
          }
        }
        for (var k = 0; k < 80; k++) {
          final a = hash01(k) * tau;
          final p = ballistic(_avatar, Offset(math.cos(a), math.sin(a) - 0.5) * (200 + 320 * hash01(k + 3)), sec, gravity: 700, drag: 1);
          final size = 3.0 + (hash01(k + 6) * 3).floor() * 1.5;
          canvas.drawRect(Rect.fromCenter(center: p, width: size, height: size), fillPaint(_palette[k % _palette.length], fadeOut * (1 - span(sec, 1.8, 3.2))));
        }
      case 'coins':
        for (var k = 0; k < 34; k++) {
          final delay = hash01(k + 1) * 0.7;
          final tt = sec - delay;
          if (tt <= 0) continue;
          final v = Offset((hash01(k) - 0.5) * 1.4 * h, -(2.6 + 0.6 * hash01(k + 2)) * h);
          final p = ballistic(Offset(w * 0.74, h + 12), v, tt, gravity: 6 * h, drag: 0.4);
          if (p.dy > h + 30) continue;
          _coin(canvas, p, 8 + 4 * hash01(k + 5), tt * (10 + 6 * hash01(k + 8)) + k, fadeOut);
        }
      case 'petals':
        for (var k = 0; k < 46; k++) {
          final delay = hash01(k + 3) * 1.4;
          final tt = sec - delay;
          if (tt <= 0) continue;
          final p = ballistic(Offset(-20, h * (0.05 + 0.6 * hash01(k))), Offset(140 + 120 * hash01(k + 9), 30 + 40 * hash01(k + 11)), tt, gravity: 35, drag: 0.25) + Offset(0, math.sin(tt * 2.4 + k) * 12);
          _petal(canvas, p, 7 + 5 * hash01(k + 13), tt * 3 + k, math.sin(tt * 4 + k), fadeOut);
        }
      case 'bubbles':
        for (var k = 0; k < 30; k++) {
          final delay = hash01(k + 4) * 1.5;
          final tt = sec - delay;
          if (tt <= 0) continue;
          final popAt = h * (0.1 + 0.5 * hash01(k + 8));
          final y = h + 14 - tt * (70 + 80 * hash01(k + 2));
          final p = Offset(w * (0.3 + 0.68 * hash01(k)) + math.sin(tt * 3 + k) * 8, y);
          final r = (5 + 9 * hash01(k + 6)) * (0.6 + 0.4 * clamp01(tt));
          if (y > popAt) {
            _bubble(canvas, p, r, fadeOut);
          } else {
            final pop = (popAt - y) / 30;
            if (pop < 1) canvas.drawCircle(Offset(p.dx, popAt), r * (1 + pop), strokePaint(Colors.white, 1.2, (1 - pop) * fadeOut));
          }
        }
      case 'lightning':
        for (final (k, at) in const [0.15, 1.0].indexed) {
          final local = (sec - at) / 0.45;
          if (local < 0 || local > 1) continue;
          // A stuttering flash: on, dimmer, on again, gone.
          final flash = local < 0.1 ? 1.0 : (local < 0.2 ? 0.25 : (local < 0.32 ? 0.85 : 1 - span(local, 0.32, 1)));
          canvas.drawRect(Offset.zero & s, Paint()
            ..blendMode = BlendMode.plus
            ..color = const Color(0xFFC7D2FE).withValues(alpha: 0.35 * flash));
          _bolt(canvas, Offset(w * (0.55 + 0.35 * hash01(k + 2)), -5), Offset(w * (0.45 + 0.4 * hash01(k + 5)), h * 0.95), k * 17 + 3, flash);
        }
      case 'shooting':
        for (var k = 0; k < 7; k++) {
          final start = hash01(k + 9) * 2.2;
          final local = (sec - start) / 0.7;
          if (local <= 0 || local >= 1) continue;
          _shootingStar(canvas, s, k, local, 1);
        }
    }
  }

  // --------------------------------------------------------------- ambient

  void _ambient(Canvas canvas, Size s, double k) {
    final w = s.width, h = s.height;
    switch (id) {
      case 'confetti':
        for (var i = 0; i < 16; i++) {
          final c = 1 + i % 2;
          final y = fract(hash01(i + 3) + ph * c) * (h + 40) - 20;
          final p = Offset(w * hash01(i) + math.sin((ph * c * 3 + hash01(i)) * tau) * 14, y);
          // Whole turns and tumbles per loop, so each piece wraps cleanly.
          final turns = (4 + (6 * hash01(i + 8)).floor()) * c;
          final tumbles = (9 + (7 * hash01(i + 9)).floor()) * c;
          _confettiPiece(canvas, p, i, spin: ph * tau * turns, flip: math.cos(ph * tau * tumbles + i), wiggle: ph * tau * 10 * c, alpha: k * 0.85);
        }
      case 'sparkles':
        for (var i = 0; i < 12; i++) {
          final u = loopWindow(ph, i / 12 + hash01(i) * 0.05, 0.1);
          if (u == null) continue;
          final p = Offset(hash01(i + 30) * w, hash01(i + 60) * h);
          final b = bump(u);
          drawSparkle(canvas, p, (4 + 6 * hash01(i + 90)) * b, fillPaint(Colors.white, b * k));
          drawGlow(canvas, p, 12 * b, const Color(0xFFFFF4C2), 0.4 * b * k);
        }
      case 'snow':
        for (var i = 0; i < 46; i++) {
          final depth = 1 + i % 3;
          final y = fract(hash01(i + 7) + ph * depth) * (h + 20) - 10;
          final p = Offset(hash01(i) * w + math.sin((ph * 2 + hash01(i + 2)) * tau) * 10 * depth, y);
          _flake(canvas, p, depth, (0.45 + 0.17 * depth) * k, ph * tau);
        }
      case 'fireworks':
        for (final (r, (start, fx, fy)) in const [(0.12, 0.72, 0.3), (0.58, 0.9, 0.22)].indexed) {
          final apex = Offset(w * fx, h * fy);
          // Each shell is seen climbing (≈ 0.55 s) before it bursts.
          if (loopWindow(ph, start - 0.07, 0.07) case final rise?) _rocket(canvas, apex, h, rise, k);
          final u = loopWindow(ph, start, 0.22);
          if (u == null) continue;
          _burst(canvas, apex, _palette[(r * 3 + 2) % _palette.length], u * 1.75, 36, r + 10, scale: 0.75 * h / 200, fade: k);
        }
      case 'dice':
        for (var i = 0; i < 2; i++) {
          final u = loopWindow(ph, i * 0.5 + 0.1, 0.3);
          if (u == null) continue;
          final size = 15.0;
          final (y, spin, settled) = _bouncing(-20, h - size * 0.7, u * 2.4, i + 40);
          drawDie(canvas, Offset(w * (0.6 + 0.3 * i), y), size, settled ? 6 - i : 1 + (hash01(i * 7 + (u * 20).floor()) * 6).floor(), angle: spin, alpha: k * (1 - span(u, 0.8, 1)));
        }
      case 'hearts':
        for (var i = 0; i < 11; i++) {
          final c = 1 + i % 2;
          final y = h + 20 - fract(hash01(i + 5) + ph * c) * (h + 50);
          final p = Offset(w * (0.25 + 0.72 * hash01(i)) + math.sin((ph * c * 2 + hash01(i)) * tau) * 12, y);
          _heart(canvas, p, 10 + 8 * hash01(i + 9), i, clamp01(y / (h * 0.3)) * k * 0.85, math.sin((ph * 2 + i * 0.1) * tau) * 0.2);
        }
      case 'pixels':
        for (var i = 0; i < 16; i++) {
          final life = fract(hash01(i + 2) + ph * (1 + i % 3));
          final p = Offset(w * (0.2 + 0.8 * hash01(i)) + wave(ph, hash01(i + 4), 2) * 6, h - life * h * 0.9);
          final size = 3.0 + (i % 3) * 1.5;
          // Each pixel hops colour on its own beat (never on the loop's
          // wrap) and fades in.
          final hop = (ph * 12 + 0.05 + 0.9 * hash01(i + 8)).floor();
          canvas.drawRect(Rect.fromCenter(center: p, width: size, height: size), fillPaint(_palette[(i + hop) % _palette.length], (1 - life) * span(life, 0, 0.08) * k));
        }
      case 'coins':
        for (var i = 0; i < 6; i++) {
          final y = fract(hash01(i + 4) + ph * (1 + i % 2)) * (h + 40) - 20;
          _coin(canvas, Offset(w * (0.35 + 0.6 * hash01(i)), y), 7 + 3 * hash01(i + 1), ph * tau * 4 + i, k * 0.9);
        }
      case 'petals':
        for (var i = 0; i < 16; i++) {
          final c = 1 + i % 2;
          final f = fract(hash01(i + 6) + ph * c);
          final p = Offset(-20 + f * (w + 40), h * (0.05 + 0.75 * hash01(i)) + f * h * 0.25 + math.sin((f * 2 + hash01(i)) * tau) * 10);
          _petal(canvas, p, 7 + 4 * hash01(i + 2), (ph * c * 3 + hash01(i)) * tau, math.sin((ph * c * 4 + hash01(i + 1)) * tau), k);
        }
      case 'bubbles':
        for (var i = 0; i < 12; i++) {
          final y = h + 12 - fract(hash01(i + 9) + ph * (1 + i % 2)) * (h + 30);
          _bubble(canvas, Offset(w * (0.3 + 0.68 * hash01(i)) + wave(ph, hash01(i + 1), 3) * 7, y), 4 + 7 * hash01(i + 3), k * 0.9);
        }
      case 'lightning':
        final u = loopWindow(ph, 0.5, 0.06);
        if (u != null) {
          final flash = u < 0.15 ? 1.0 : (u < 0.3 ? 0.3 : 1 - span(u, 0.3, 1));
          canvas.drawRect(Offset.zero & s, Paint()
            ..blendMode = BlendMode.plus
            ..color = const Color(0xFFC7D2FE).withValues(alpha: 0.22 * flash * k));
          _bolt(canvas, Offset(w * 0.8, -5), Offset(w * 0.68, h * 0.8), 91, flash * k);
        }
      case 'shooting':
        for (var i = 0; i < 3; i++) {
          final u = loopWindow(ph, i / 3 + hash01(i) * 0.1, 0.09);
          if (u == null) continue;
          _shootingStar(canvas, s, i + 20, u, k);
        }
    }
  }

  // ---------------------------------------------------------------- pieces

  /// Confetti piece [k], turned by [spin], tumbling in 3D by [flip] (−1…1);
  /// [wiggle] ripples the streamers.
  void _confettiPiece(Canvas canvas, Offset p, int k, {required double spin, required double flip, required double wiggle, required double alpha}) {
    if (alpha <= 0.01) return;
    final color = _palette[k % _palette.length];
    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.rotate(hash01(k + 7) * tau + spin * (k.isEven ? 1 : -1));
    if (k % 3 == 0) {
      // A curly streamer.
      final path = Path()..moveTo(-7, 0);
      for (var x = -7.0; x <= 7; x += 1.5) {
        path.lineTo(x, math.sin(x * 0.9 + wiggle) * 2.4 * flip);
      }
      canvas.drawPath(path, strokePaint(color, 2.2, alpha));
    } else {
      canvas.scale(1, flip.abs().clamp(0.15, 1.0));
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: 6, height: 10), fillPaint(flip > 0 ? color : Color.lerp(color, Colors.black, 0.25)!, alpha));
    }
    canvas.restore();
  }

  void _flake(Canvas canvas, Offset p, int depth, double alpha, double angle) {
    if (depth < 3) {
      canvas.drawCircle(p, 0.8 + depth * 0.7, fillPaint(Colors.white, alpha));
      return;
    }
    final paint = strokePaint(Colors.white, 1.1, alpha);
    for (var k = 0; k < 3; k++) {
      final a = k * math.pi / 3 + angle;
      final d = Offset(math.cos(a), math.sin(a)) * 4.2;
      canvas.drawLine(p - d, p + d, paint);
    }
  }

  /// A shell climbing to [apex] (rise 0 → 1), trailing sparks.
  void _rocket(Canvas canvas, Offset apex, double h, double rise, double alpha) {
    final from = Offset(apex.dx - 10, h + 10);
    for (var k = 0; k < 6; k++) {
      final q = Offset.lerp(from, apex, easeOutCubic(math.max(0, rise - k * 0.04)))!;
      canvas.drawCircle(q, 2 - k * 0.25, fillPaint(const Color(0xFFFFE8A3), (1 - k / 6) * alpha));
    }
    drawGlow(canvas, Offset.lerp(from, apex, easeOutCubic(rise))!, 8, const Color(0xFFFFE8A3), 0.8 * alpha);
  }

  void _burst(Canvas canvas, Offset c, Color color, double tt, int n, int seed, {required double scale, required double fade}) {
    // The bang: a white flash, then the colour blooming while sparks fly.
    if (tt < 0.15) drawGlow(canvas, c, 70 * scale * (1 - tt / 0.15 * 0.4), Colors.white, 0.9 * (1 - tt / 0.15) * fade);
    drawGlow(canvas, c, 90 * scale * (0.6 + 0.4 * span(tt, 0, 0.4)), color, 0.35 * (1 - span(tt, 0.1, 1.1)) * fade);
    final spark = Paint()..blendMode = BlendMode.plus;
    for (var k = 0; k < n; k++) {
      final a = k / n * tau + hash01(seed * 31 + k) * 0.2;
      // Two shells: a wide outer ring and a tighter inner one.
      final speed = (k.isEven ? 140 + 110 * hash01(seed * 17 + k) : 80 + 50 * hash01(seed * 19 + k)) * scale;
      final p = ballistic(c, Offset(math.cos(a), math.sin(a)) * speed, tt, gravity: 120 * scale, drag: 2.2);
      final life = 1 - span(tt, 0.45, 1.5);
      // Some sparks crackle (flicker) as they fade.
      final crackle = k % 3 == 0 ? ((tt * 30 + k).floor().isEven ? 1.0 : 0.25) : 1.0;
      final trail = ballistic(c, Offset(math.cos(a), math.sin(a)) * speed, math.max(0, tt - 0.09), gravity: 120 * scale, drag: 2.2);
      canvas.drawLine(trail, p, strokePaint(color, 2, 0.7 * life * fade)..blendMode = BlendMode.plus);
      canvas.drawCircle(p, 2.2, spark..color = Color.lerp(color, Colors.white, 0.55)!.withValues(alpha: clamp01(life * crackle * fade)));
    }
  }

  /// A dropped object bouncing to rest on [floor]: (y, spin, settled).
  (double, double, bool) _bouncing(double y0, double floor, double tt, int seed) {
    const g = 1400.0, e = 0.42;
    var fall = floor - y0;
    var t1 = math.sqrt(2 * fall / g);
    if (tt < t1) return (y0 + 0.5 * g * tt * tt, tt * 9 + seed, false);
    var rest = tt - t1;
    var v = e * g * t1;
    for (var b = 0; b < 3; b++) {
      final air = 2 * v / g;
      if (rest < air) return (floor - (v * rest - 0.5 * g * rest * rest), t1 * 9 + seed + rest * 6 * (1 - b * 0.3), false);
      rest -= air;
      v *= e;
    }
    return (floor, t1 * 9 + seed, true);
  }

  void _heart(Canvas canvas, Offset p, double size, int k, double alpha, double angle) {
    if (alpha <= 0.01 || size <= 0.5) return;
    const colors = [Color(0xFFFF4D8D), Color(0xFFFF6B6B), Color(0xFFFF9EC7), Color(0xFFE5537B)];
    final color = colors[k % colors.length];
    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.rotate(angle);
    final path = heartPath(size);
    canvas.drawPath(path, Paint()..shader = ui.Gradient.linear(Offset(-size / 2, -size / 2), Offset(size / 2, size / 2), [Color.lerp(color, Colors.white, 0.45)!.withValues(alpha: alpha), color.withValues(alpha: alpha)]));
    canvas.drawCircle(Offset(-size * 0.18, -size * 0.12), size * 0.09, fillPaint(Colors.white, 0.6 * alpha));
    canvas.restore();
  }

  void _coin(Canvas canvas, Offset p, double r, double spin, double alpha) {
    if (alpha <= 0.01) return;
    final sx = math.cos(spin);
    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.scale(sx.abs().clamp(0.12, 1.0), 1);
    canvas.drawCircle(Offset.zero, r, Paint()..shader = ui.Gradient.linear(Offset(-r, -r), Offset(r, r), [const Color(0xFFFFF1B8).withValues(alpha: alpha), const Color(0xFFE8A93B).withValues(alpha: alpha), const Color(0xFFB7791F).withValues(alpha: alpha)], const [0, 0.5, 1]));
    canvas.drawCircle(Offset.zero, r * 0.7, strokePaint(const Color(0xFFFFF6D5), 1.2, 0.8 * alpha));
    canvas.restore();
    if (sx.abs() > 0.97) drawSparkle(canvas, p + Offset(r * 0.4, -r * 0.4), r * 0.6, fillPaint(Colors.white, alpha));
  }

  void _petal(Canvas canvas, Offset p, double size, double angle, double flutter, double alpha) {
    if (alpha <= 0.01) return;
    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.rotate(angle);
    canvas.scale(flutter.abs().clamp(0.25, 1.0), 1);
    final path = Path()
      ..moveTo(0, -size * 0.6)
      ..quadraticBezierTo(size * 0.55, -size * 0.2, 0, size * 0.6)
      ..quadraticBezierTo(-size * 0.55, -size * 0.2, 0, -size * 0.6)
      ..close();
    canvas.drawPath(path, Paint()..shader = ui.Gradient.linear(Offset(0, -size * 0.6), Offset(0, size * 0.6), [const Color(0xFFFFE4EF).withValues(alpha: alpha), const Color(0xFFFF9EC7).withValues(alpha: alpha)]));
    canvas.restore();
  }

  void _bubble(Canvas canvas, Offset p, double r, double alpha) {
    if (alpha <= 0.01) return;
    canvas.drawCircle(p, r, Paint()..shader = ui.Gradient.radial(p, r, [const Color(0x00FFFFFF), const Color(0x33A5F3FC).withValues(alpha: 0.2 * alpha), Colors.white.withValues(alpha: 0.5 * alpha)], const [0, 0.75, 1]));
    canvas.drawCircle(p, r, strokePaint(Colors.white, 0.9, 0.55 * alpha));
    canvas.drawArc(Rect.fromCircle(center: p, radius: r * 0.65), -2.6, 0.9, false, strokePaint(Colors.white, 1.4, 0.8 * alpha));
  }

  void _bolt(Canvas canvas, Offset a, Offset b, int seed, double alpha) {
    if (alpha <= 0.01) return;
    List<Offset> jag(Offset from, Offset to, int s, double spread) {
      var pts = [from, to];
      for (var level = 0; level < 5; level++) {
        final next = <Offset>[];
        for (var i = 0; i < pts.length - 1; i++) {
          final m = Offset.lerp(pts[i], pts[i + 1], 0.5)!;
          final d = pts[i + 1] - pts[i];
          final n = Offset(-d.dy, d.dx) / (d.distance == 0 ? 1 : d.distance);
          next
            ..add(pts[i])
            ..add(m + n * (hash01(s * 131 + level * 17 + i) - 0.5) * spread * math.pow(0.55, level).toDouble());
        }
        next.add(pts.last);
        pts = next;
      }
      return pts;
    }

    final main = jag(a, b, seed, (b - a).distance * 0.45);
    final branches = [
      for (var k = 0; k < 3; k++)
        () {
          final from = main[(main.length * (0.25 + 0.2 * k)).floor()];
          final dir = (b - a) / (b - a).distance;
          final to = from + Offset(dir.dx + (k.isEven ? 0.6 : -0.6), dir.dy) * (b - a).distance * 0.3;
          return jag(from, to, seed + k + 1, (to - from).distance * 0.5);
        }(),
    ];
    for (final (path, width) in [(main, 1.0), ...branches.map((p) => (p, 0.55))]) {
      final line = Path()..addPolygon(path, false);
      canvas.drawPath(line, strokePaint(const Color(0xFFA5B4FC), 7 * width, 0.5 * alpha)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
      canvas.drawPath(line, strokePaint(Colors.white, 2.2 * width, alpha));
    }
  }

  void _shootingStar(Canvas canvas, Size s, int k, double u, double alpha) {
    final w = s.width, h = s.height;
    final start = Offset(w * (0.55 + 0.45 * hash01(k + 1)), h * (0.02 + 0.35 * hash01(k + 2)));
    const dir = Offset(-0.88, 0.47);
    final head = start + dir * (easeOutCubic(u) * w * 0.6);
    final len = w * 0.34 * bump(u);
    final tail = head - dir * len;
    final a = bump(u) * alpha;
    canvas.drawLine(tail, head, Paint()
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..shader = ui.Gradient.linear(tail, head, [const Color(0x00FFFFFF), Colors.white.withValues(alpha: a)]));
    drawGlow(canvas, head, 10, const Color(0xFFE0F2FE), a);
    for (var j = 0; j < 4; j++) {
      final q = Offset.lerp(head, tail, 0.25 + j * 0.2)! + Offset(0, math.sin(j * 2.1 + u * 20) * 3);
      drawSparkle(canvas, q, 2.5 * (1 - j / 4) * a, fillPaint(Colors.white, a));
    }
  }

  @override
  bool shouldRepaint(ProfileEffectPainter old) => old.intro != intro || old.ph != ph || old.ambient != ambient || old.id != id;
}
