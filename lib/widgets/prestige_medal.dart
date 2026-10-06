import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../logic/badges.dart';
import '../theme/app_theme.dart';
import 'ambient_loop.dart';
import 'badge_symbols.dart';
import 'fx_kit.dart';

/// Tiers above gold aren't round medals: each gets a shape of its own and,
/// once earned, keeps a small animation going — see [PrestigeMedal].
bool isPrestigeTier(BadgeTier t) => t.index > BadgeTier.gold.index;

/// A badge of a tier above gold, [size] wide:
///   * platinum — a bevelled hexagonal crest hung on two ribbons: the light
///     drifts over its bevels, a shine crosses it, the ribbons sway;
///   * diamond — a brilliant-cut gem: its facets catch a light turning
///     round it, with flashes of fire and glints;
///   * mythic — a starry core in an opal rim, on a slowly turning star of
///     gold and violet in a breathing halo, a shooting star now and then;
///   * exclusive — black and gold, like no other: a crowned obsidian
///     medallion in a laurel wreath. A light climbs the laurels up to the
///     crown's pearls, another turns round the bezel, a prism sweeps the
///     black face and gold dust rises in a breathing aura.
///
/// Locked, it's the same shape greyed out, its progress traced along the
/// outline. Earned, it runs its own loop — or draws [phase], for a parent
/// that runs the loop itself — and holds still under reduced motion.
class PrestigeMedal extends StatelessWidget {
  final BadgeDef badge;
  final bool earned;
  final double size;
  final double? progress;
  final double? phase;
  const PrestigeMedal({super.key, required this.badge, required this.earned, this.size = 56, this.progress, this.phase});

  @override
  Widget build(BuildContext context) {
    final look = _lookOf(badge.tier);
    if (!earned) {
      final p = progress;
      return SizedBox.square(
        dimension: size,
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _LockedPainter(look, AppColors.segTrack, AppColors.card))),
            _symbol(look, earned: false),
            if (p != null && p > 0)
              Positioned.fill(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: p),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => CustomPaint(painter: _TrackPainter(look, v, AppColors.accent)),
                ),
              ),
            Positioned(right: 0, bottom: 0, child: BadgeLockPip(size: size)),
          ],
        ),
      );
    }
    final symbol = _symbol(look, earned: true);
    Widget frame(double ph) => CustomPaint(painter: _LookPainter(look, ph), foregroundPainter: _LookPainter(look, ph, front: true), child: symbol);
    if (phase != null) return frame(phase!);
    // Each badge on its own period, so a row of them never moves in unison.
    final period = Duration(milliseconds: 4600 + (hash01(badge.id.length * 7 + badge.id.codeUnitAt(0)) * 1800).round());
    return RepaintBoundary(child: AmbientLoop(period: period, builder: (context, ph) => frame(ph)));
  }

  Widget _symbol(_Look look, {required bool earned}) => SizedBox.square(
        dimension: size,
        child: Transform.translate(
          offset: Offset(0, size * look.faceDy),
          child: Center(child: BadgeSymbol(badge: badge, earned: earned, size: size * look.symbolScale)),
        ),
      );
}

/// The padlock in the corner of a locked badge [size] wide.
class BadgeLockPip extends StatelessWidget {
  final double size;
  const BadgeLockPip({super.key, required this.size});

  @override
  Widget build(BuildContext context) => Container(
        width: size * 0.32,
        height: size * 0.32,
        decoration: BoxDecoration(color: AppColors.bg, shape: BoxShape.circle, border: Border.all(color: AppColors.line)),
        child: Icon(Icons.lock_rounded, size: size * 0.18, color: AppColors.mut),
      );
}

/// The shape of a prestige [tier], filling a [size]-wide square — for
/// small legends.
Path prestigeGlyph(BadgeTier tier, double size) => _lookOf(tier).glyph(size);

// ============================== painters ==============================

class _LookPainter extends CustomPainter {
  final _Look look;
  final double ph;
  final bool front;
  _LookPainter(this.look, this.ph, {this.front = false});

  @override
  void paint(Canvas canvas, Size s) => front ? look.paintFront(canvas, s.width, ph) : look.paintBack(canvas, s.width, ph);

  @override
  bool shouldRepaint(_LookPainter old) => old.ph != ph || old.look != look;
}

class _LockedPainter extends CustomPainter {
  final _Look look;
  final Color track;
  final Color face;
  _LockedPainter(this.look, this.track, this.face);

  @override
  void paint(Canvas canvas, Size s) => look.paintLocked(canvas, s.width, track, face);

  @override
  bool shouldRepaint(_LockedPainter old) => old.look != look || old.track != track || old.face != face;
}

/// A locked badge's progress: [t] of the way along its [_Look.track].
class _TrackPainter extends CustomPainter {
  final _Look look;
  final double t;
  final Color color;
  _TrackPainter(this.look, this.t, this.color);

  @override
  void paint(Canvas canvas, Size s) {
    if (t <= 0) return;
    final traced = Path();
    for (final m in look.track(s.width).computeMetrics()) {
      traced.addPath(m.extractPath(0, m.length * clamp01(t)), Offset.zero);
    }
    canvas.drawPath(traced, strokePaint(color, s.width * 0.08));
  }

  @override
  bool shouldRepaint(_TrackPainter old) => old.t != t || old.color != color || old.look != look;
}

// ============================== the looks ==============================

/// How one prestige tier is drawn, `S` wide. Anything driven by the loop
/// phase `ph` is periodic in it (see fx_kit), so the loop never shows a seam.
abstract class _Look {
  const _Look();

  /// Where the symbol sits: how far below the centre (× S)…
  double get faceDy => 0;

  /// …and how big it is (× S).
  double get symbolScale => 0.38;

  /// Behind the symbol: the badge itself.
  void paintBack(Canvas canvas, double S, double ph);

  /// Over the symbol: glints and shines.
  void paintFront(Canvas canvas, double S, double ph);

  /// The locked silhouette, in [track] with a [face] where the symbol goes.
  void paintLocked(Canvas canvas, double S, Color track, Color face);

  /// The line a locked badge's progress is traced along: from the top,
  /// clockwise.
  Path track(double S);

  /// The bare shape, filling the square.
  Path glyph(double S);
}

_Look _lookOf(BadgeTier t) => switch (t) {
      BadgeTier.platinum => const _Platinum(),
      BadgeTier.diamond => const _Diamond(),
      BadgeTier.mythic => const _Mythic(),
      BadgeTier.exclusive => const _Exclusive(),
      _ => throw ArgumentError.value(t, 'tier', 'not above gold'),
    };

Offset _dir(double a) => Offset(math.cos(a), math.sin(a));

/// The colour [x] (0…1) of the way along [stops], set [at] those points.
Color _ramp(List<Color> stops, List<double> at, double x) {
  x = clamp01(x);
  for (var i = 1; i < stops.length; i++) {
    if (x <= at[i]) return Color.lerp(stops[i - 1], stops[i], (x - at[i - 1]) / (at[i] - at[i - 1]))!;
  }
  return stops.last;
}

/// [n] points evenly round a circle of radius [r] about [c], the first at
/// angle [start] — clockwise on screen.
List<Offset> _ring(Offset c, double r, int n, double start) => [for (var i = 0; i < n; i++) c + _dir(start + i * tau / n) * r];

Path _poly(List<Offset> points) => Path()..addPolygon(points, true);

/// Platinum: a bevelled hexagonal crest hung on two ribbons.
class _Platinum extends _Look {
  const _Platinum();

  static const _dark = Color(0xFF5C8592);
  static const _light = Color(0xFFF7FFFF);
  static const _edge = Color(0xFF3A6770);
  static const _ribbon = [Color(0xFF1C5560), Color(0xFF3B93A1), Color(0xFF1C5560)];

  // The crest sits a little high, so the ribbons show below it.
  static const _cy = 0.465, _outer = 0.455, _inner = 0.345;

  @override
  double get faceDy => _cy - 0.5;

  Offset _c(double S) => Offset(S / 2, S * _cy);

  List<Offset> _hex(double S, double r) => _ring(_c(S), S * r, 6, -math.pi / 2);

  /// The two ribbon tails behind the crest, swung out either side and
  /// swaying together — the right one a beat behind, as in a breeze.
  void _tails(Canvas canvas, double S, double ph, {Color? flat}) {
    final c = _c(S);
    final w = S * 0.17, len = S * 0.55, notch = S * 0.09;
    final tail = Path()
      ..moveTo(-w / 2, 0)
      ..lineTo(w / 2, 0)
      ..lineTo(w / 2, len)
      ..lineTo(0, len - notch)
      ..lineTo(-w / 2, len)
      ..close();
    for (final side in const [1.0, -1.0]) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(side * 0.45 + 0.05 * wave(ph, side > 0 ? 0 : -0.08));
      if (flat != null) {
        canvas.drawPath(tail, fillPaint(flat));
      } else {
        canvas.drawPath(tail, Paint()..shader = ui.Gradient.linear(Offset(-w / 2, 0), Offset(w / 2, 0), _ribbon, const [0, 0.5, 1]));
        canvas.drawRect(Rect.fromLTRB(-w * 0.13, 0, w * 0.13, len - notch), fillPaint(const Color(0xFFE6F8FA), 0.9));
      }
      canvas.restore();
    }
  }

  @override
  void paintBack(Canvas canvas, double S, double ph) {
    final c = _c(S);
    _tails(canvas, S, ph);
    final outer = _hex(S, _outer), inner = _hex(S, _inner);
    final crest = _poly(outer);
    canvas.drawPath(
      crest.shift(Offset(0, S * 0.035)),
      Paint()
        ..color = const Color(0x5014363D)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, S * 0.035),
    );
    // The six bevels, lit by a light drifting to and fro over the top left.
    final light = -2.4 + 0.8 * wave(ph);
    for (var i = 0; i < 6; i++) {
      final j = (i + 1) % 6;
      final facing = -math.pi / 2 + (i + 0.5) * tau / 6;
      final k = 0.5 + 0.5 * math.cos(facing - light);
      canvas.drawPath(_poly([outer[i], outer[j], inner[j], inner[i]]), fillPaint(Color.lerp(_dark, _light, k)!));
    }
    canvas.drawPath(crest, strokePaint(_edge, S * 0.014));
    final face = _poly(inner);
    canvas.drawPath(face, Paint()..shader = ui.Gradient.radial(c + Offset(-S * 0.09, -S * 0.11), S * 0.42, const [Colors.white, Color(0xFFD3EBEE)]));
    canvas.drawPath(face, strokePaint(Colors.white, S * 0.012, 0.9));
    // A fine engraved line round the face.
    canvas.drawPath(_poly(_hex(S, _inner * 0.86)), strokePaint(_edge, S * 0.008, 0.3));
  }

  @override
  void paintFront(Canvas canvas, double S, double ph) {
    drawSheen(canvas, _poly(_hex(S, _outer)), _c(S), S * 0.5, loopWindow(ph, 0.08, 0.3) ?? 0);
    // Glints on two of the crest's corners, once the shine has passed.
    final corners = _hex(S, _outer * 0.9);
    for (final (i, start) in const [(0, 0.4), (2, 0.6)]) {
      final k = loopWindow(ph, start, 0.16);
      if (k != null) drawSparkle(canvas, corners[i], S * 0.14 * bump(k), fillPaint(Colors.white, bump(k)));
    }
  }

  @override
  void paintLocked(Canvas canvas, double S, Color track, Color face) {
    _tails(canvas, S, 0, flat: Color.lerp(track, face, 0.35));
    canvas.drawPath(_poly(_hex(S, _outer)), fillPaint(track));
    canvas.drawPath(_poly(_hex(S, _inner)), fillPaint(face));
  }

  @override
  Path track(double S) => _poly(_hex(S, (_outer + _inner) / 2));

  @override
  Path glyph(double S) => _poly(_ring(Offset(S / 2, S / 2), S / 2, 6, -math.pi / 2));
}

typedef _Facet = ({List<Offset> pts, double facing, int kind});

/// Diamond: a brilliant-cut gem seen from above — the symbol on its table,
/// a ring of facets round it.
class _Diamond extends _Look {
  const _Diamond();

  static const _start = -math.pi / 2 - math.pi / 8; // a flat top
  static const _girdle = 0.49, _table = 0.3, _tips = 0.4;
  static const _ink = Color(0xFF15398F);

  /// The stone's colour, from deep blue (0) to white (1).
  static Color _ice(double b) => _ramp(const [Color(0xFF173E9E), Color(0xFF3F8FEA), Color(0xFFAEE6FF), Color(0xFFFFFFFF)], const [0.0, 0.45, 0.82, 1.0], b);

  /// The crown's 40 facets round the table, each with the direction it
  /// faces and its kind: 0 star, 1 bezel, 2 upper girdle — from the
  /// flattest to the steepest.
  List<_Facet> _facets(double S) {
    final c = Offset(S / 2, S / 2);
    final o = _ring(c, S * _girdle, 8, _start);
    final t = _ring(c, S * _table, 8, _start);
    final p = _ring(c, S * _tips, 8, _start + tau / 16);
    final facets = <_Facet>[];
    for (var i = 0; i < 8; i++) {
      final j = (i + 1) % 8;
      final a = _start + i * tau / 8;
      final m = Offset.lerp(o[i], o[j], 0.5)!;
      facets.addAll([
        (pts: [t[i], t[j], p[i]], facing: a + tau / 16, kind: 0),
        (pts: [t[i], p[i], o[i]], facing: a, kind: 1),
        (pts: [t[j], o[j], p[i]], facing: a + tau / 8, kind: 1),
        (pts: [o[i], m, p[i]], facing: a + tau / 32, kind: 2),
        (pts: [m, o[j], p[i]], facing: a + 3 * tau / 32, kind: 2),
      ]);
    }
    return facets;
  }

  /// How bright facet [f] is under a light from [light]: lit on the side
  /// facing it, plus a faster ripple so that neighbours never match — that
  /// contrast is what makes it read as a cut stone.
  static double _brightness(_Facet f, double light) {
    const base = [0.62, 0.5, 0.4], reach = [0.25, 0.38, 0.46];
    return base[f.kind] + reach[f.kind] * math.cos(f.facing - light) + 0.18 * math.cos(3 * f.facing - 2 * light + f.kind * 2.1);
  }

  @override
  void paintBack(Canvas canvas, double S, double ph) {
    final c = Offset(S / 2, S / 2);
    final gem = _poly(_ring(c, S * _girdle, 8, _start));
    // A cold glow, breathing, and the stone's shadow.
    canvas.drawPath(
      gem,
      Paint()
        ..color = const Color(0xFF7FDBFF).withValues(alpha: 0.3 + 0.25 * wave01(ph, 0, 2))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, S * 0.06),
    );
    canvas.drawPath(
      gem.shift(Offset(0, S * 0.03)),
      Paint()
        ..color = const Color(0x55163B8C)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, S * 0.035),
    );
    // The facets, under a light turning once round the stone per loop.
    final light = -math.pi * 0.75 + ph * tau;
    final facets = _facets(S);
    for (final f in facets) {
      canvas.drawPath(_poly(f.pts), fillPaint(_ice(_brightness(f, light))));
    }
    // Fire: now and then a facet flashes a colour of the rainbow.
    for (var e = 0; e < 5; e++) {
      final k = loopWindow(ph, (e + 0.3 * hash01(e + 1)) / 5, 0.1);
      if (k == null) continue;
      final f = facets[(hash01(e * 7 + 3) * facets.length).floor()];
      canvas.drawPath(
        _poly(f.pts),
        Paint()
          ..blendMode = BlendMode.plus
          ..color = hsv(hash01(e * 5 + 2) * 360, 0.75, 1, 0.8 * bump(k)),
      );
    }
    final edges = strokePaint(Colors.white, S * 0.007, 0.35);
    for (final f in facets) {
      canvas.drawPath(_poly(f.pts), edges);
    }
    // The table: flat, a soft reflection gliding over it with the light.
    final table = _poly(_ring(c, S * _table, 8, _start));
    canvas.drawPath(table, Paint()..shader = ui.Gradient.linear(c + Offset(-S * 0.2, -S * 0.25), c + Offset(S * 0.2, S * 0.25), const [Colors.white, Color(0xFFCDEEFF)]));
    canvas.save();
    canvas.clipPath(table);
    drawGlow(canvas, c + _dir(light) * S * 0.14, S * 0.16, Colors.white, 0.45);
    canvas.restore();
    canvas.drawPath(table, strokePaint(Colors.white, S * 0.012, 0.9));
    canvas.drawPath(gem, strokePaint(_ink, S * 0.016, 0.85));
  }

  @override
  void paintFront(Canvas canvas, double S, double ph) {
    // Glints flaring on the facets, one after another.
    final tips = _ring(Offset(S / 2, S / 2), S * _tips, 8, _start + tau / 16);
    for (final (i, start) in const [(1, 0.12), (5, 0.45), (3, 0.78)]) {
      final k = loopWindow(ph, start, 0.18);
      if (k == null) continue;
      final g = bump(k);
      drawGlow(canvas, tips[i], S * 0.12 * g, const Color(0xFFBFF1FF), 0.8 * g);
      drawSparkle(canvas, tips[i], S * 0.2 * g, fillPaint(Colors.white, g));
    }
  }

  @override
  void paintLocked(Canvas canvas, double S, Color track, Color face) {
    final c = Offset(S / 2, S / 2);
    canvas.drawPath(_poly(_ring(c, S * _girdle, 8, _start)), fillPaint(track));
    final edges = strokePaint(face, S * 0.01, 0.6);
    for (final f in _facets(S)) {
      canvas.drawPath(_poly(f.pts), edges);
    }
    canvas.drawPath(_poly(_ring(c, S * _table, 8, _start)), fillPaint(face));
  }

  @override
  Path track(double S) {
    final o = _ring(Offset(S / 2, S / 2), S * 0.445, 8, _start);
    final top = Offset.lerp(o[0], o[1], 0.5)!;
    final path = Path()..moveTo(top.dx, top.dy);
    for (var i = 1; i <= 8; i++) {
      path.lineTo(o[i % 8].dx, o[i % 8].dy);
    }
    return path..close();
  }

  @override
  Path glyph(double S) => _poly(_ring(Offset(S / 2, S / 2), S / 2, 8, _start));
}

/// Mythic: a starry core in an opal rim, set on a slowly turning star of
/// gold and violet spikes, in a breathing halo.
class _Mythic extends _Look {
  const _Mythic();

  static const _core = 0.35, _rim = 0.055;
  static const _opal = [Color(0xFFFF7AD9), Color(0xFFFFD36B), Color(0xFF7CF5FF), Color(0xFFB07CFF), Color(0xFFFF7AD9)];
  static const _ink = Color(0xFF3A0E6B);

  /// The star: 8 long gold spikes and 8 short violet ones, each split into
  /// a lit and a shaded half so it reads as a ridge, turned by [turn]. The
  /// spikes facing [glint] light up; [reach] stretches them.
  void _star(Canvas canvas, double S, double turn, {double? glint, double reach = 0, Color? flat}) {
    final c = Offset(S / 2, S / 2);
    for (var i = 0; i < 16; i++) {
      final a = -math.pi / 2 + turn + i * tau / 16;
      final long = i.isEven;
      final tip = c + _dir(a) * S * (long ? 0.47 + reach : 0.43 + reach * 0.6);
      final l = c + _dir(a - tau / 32) * S * 0.345;
      final r = c + _dir(a + tau / 32) * S * 0.345;
      final shine = glint == null ? 0.0 : math.pow(math.max(0.0, math.cos(a - glint)), 6).toDouble();
      final lit = flat ?? Color.lerp(long ? const Color(0xFFFFE08A) : const Color(0xFFC9A2FF), Colors.white, 0.75 * shine)!;
      final shade = flat ?? Color.lerp(long ? const Color(0xFFD6961C) : const Color(0xFF7440D8), Colors.white, 0.35 * shine)!;
      canvas.drawPath(_poly([c, l, tip]), fillPaint(lit));
      canvas.drawPath(_poly([c, tip, r]), fillPaint(shade));
    }
  }

  @override
  void paintBack(Canvas canvas, double S, double ph) {
    final c = Offset(S / 2, S / 2);
    final breathe = wave01(ph, 0, 2);
    canvas.drawCircle(c, S * 0.5, Paint()..shader = ui.Gradient.radial(c, S * 0.5, [const Color(0xFFFF7AD9).withValues(alpha: 0.45 + 0.25 * breathe), const Color(0x00B07CFF)]));
    // Turning an eighth of a turn per loop (it looks the same every
    // eighth), reaching out as it breathes, a glint running the other way.
    _star(canvas, S, ph * tau / 8, glint: -math.pi / 2 - ph * tau, reach: 0.03 * breathe);
    canvas.drawCircle(
      c + Offset(0, S * 0.025),
      S * _core,
      Paint()
        ..color = const Color(0x66250845)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, S * 0.03),
    );
    // The opal rim, its colours turning.
    canvas.drawCircle(
      c,
      S * (_core - _rim / 2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = S * _rim
        ..shader = SweepGradient(colors: _opal, transform: GradientRotation(ph * tau)).createShader(Rect.fromCircle(center: c, radius: S * _core)),
    );
    canvas.drawCircle(c, S * _core, strokePaint(_ink, S * 0.012, 0.8));
    // The night sky inside: a nebula, and stars twinkling.
    final fr = S * (_core - _rim);
    canvas.drawCircle(c, fr, Paint()..shader = ui.Gradient.radial(c + Offset(-S * 0.06, -S * 0.08), fr * 1.4, const [Color(0xFF5E2CA5), Color(0xFF26104F), Color(0xFF12062A)], const [0, 0.55, 1]));
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: fr)));
    drawGlow(canvas, c + Offset(S * 0.1, S * 0.1), S * 0.17, const Color(0xFFFF5BC8), 0.35);
    for (var i = 0; i < 11; i++) {
      final p = c + _dir(hash01(i * 3 + 1) * tau) * fr * 0.92 * math.sqrt(hash01(i * 5 + 2));
      canvas.drawCircle(p, S * (0.007 + 0.009 * hash01(i + 9)), fillPaint(Colors.white, 0.2 + 0.8 * wave01(ph, hash01(i * 11 + 4), 2 + i % 2)));
    }
    canvas.restore();
    canvas.drawCircle(c, fr, strokePaint(Colors.white, S * 0.008, 0.5));
  }

  @override
  void paintFront(Canvas canvas, double S, double ph) {
    final c = Offset(S / 2, S / 2);
    final fr = S * (_core - _rim);
    // A shooting star across the sky.
    final k = loopWindow(ph, 0.55, 0.13);
    if (k != null && k > 0.02) {
      final from = c + Offset(-fr * 1.1, -fr * 0.75), to = c + Offset(fr * 1.1, fr * 0.2);
      final head = Offset.lerp(from, to, k)!, tail = Offset.lerp(from, to, math.max(0, k - 0.3))!;
      canvas.save();
      canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: fr)));
      canvas.drawLine(
        tail,
        head,
        Paint()
          ..strokeWidth = S * 0.014
          ..strokeCap = StrokeCap.round
          ..shader = ui.Gradient.linear(tail, head, const [Color(0x00FFFFFF), Colors.white]),
      );
      canvas.restore();
    }
    // Sparkles at the tips of the long spikes, one after another.
    for (final (m, start) in const [(0, 0.2), (3, 0.42), (5, 0.8)]) {
      final k = loopWindow(ph, start, 0.16);
      if (k == null) continue;
      final tip = c + _dir(-math.pi / 2 + ph * tau / 8 + m * tau / 8) * S * 0.45;
      drawSparkle(canvas, tip, S * 0.16 * bump(k), fillPaint(Colors.white, bump(k)));
    }
  }

  @override
  void paintLocked(Canvas canvas, double S, Color track, Color face) {
    final c = Offset(S / 2, S / 2);
    _star(canvas, S, 0, flat: Color.lerp(track, face, 0.35));
    canvas.drawCircle(c, S * _core, fillPaint(track));
    canvas.drawCircle(c, S * (_core - _rim), fillPaint(face));
  }

  @override
  Path track(double S) {
    final rect = Rect.fromCircle(center: Offset(S / 2, S / 2), radius: S * (_core - _rim / 2));
    return Path()
      ..addArc(rect, -math.pi / 2, math.pi)
      ..arcTo(rect, math.pi / 2, math.pi, false);
  }

  @override
  Path glyph(double S) {
    final c = Offset(S / 2, S / 2);
    return _poly([for (var i = 0; i < 16; i++) c + _dir(-math.pi / 2 + i * tau / 16) * S * (i.isEven ? 0.5 : 0.3)]);
  }
}

typedef _Leaf = ({Offset base, double angle, double len, double up});

/// Exclusive: a crowned obsidian medallion in a milled gold bezel, in a
/// laurel wreath tied with a red ribbon, light rays fanning out behind.
class _Exclusive extends _Look {
  const _Exclusive();

  // The medallion sits a little low, under its crown; the wreath round it
  // a little higher, so its ribbon stays in the square.
  static const _cy = 0.56, _outer = 0.335, _inner = 0.28;
  static const _wy = 0.53, _wreath = 0.385;
  static const _ink = Color(0xFF3A2405);

  /// Where the laurel branches end, either side of the crown.
  static const _branchTop = -math.pi / 2 + 0.78;

  /// The pearls on the crown's three points (× S).
  static const _pearls = [Offset(0.355, 0.088), Offset(0.5, 0.05), Offset(0.645, 0.088)];

  @override
  double get faceDy => _cy - 0.5;

  @override
  double get symbolScale => 0.36;

  /// Gold, from its shade (0) to its highlight (1).
  static Color _gold(double k) => _ramp(const [Color(0xFF6E4609), Color(0xFFB98322), Color(0xFFF0C55A), Color(0xFFFFF4C9)], const [0.0, 0.42, 0.78, 1.0], k);

  /// The laurel's leaves, from the bottom up — the right branch, then its
  /// mirror: where each grows, the way it points, how long it is and how
  /// far up its branch (0…1). A pair per node, one leaf at the tip.
  static List<_Leaf> _leaves(double S) {
    const nodes = 7, from = math.pi / 2 - 0.14;
    final c = Offset(S / 2, S * _wy);
    final right = <_Leaf>[];
    for (var i = 0; i <= nodes; i++) {
      final up = i / nodes;
      final a = lerpD(from, _branchTop, up);
      final base = c + _dir(a) * S * _wreath;
      final along = a - math.pi / 2; // up the branch
      final len = S * 0.155 * (1 - 0.3 * up);
      if (i == nodes) {
        right.add((base: base, angle: along, len: len, up: up));
      } else {
        right.addAll([(base: base, angle: along - 0.55, len: len, up: up), (base: base, angle: along + 0.55, len: len, up: up)]);
      }
    }
    return [...right, for (final l in right) (base: Offset(S - l.base.dx, l.base.dy), angle: math.pi - l.angle, len: l.len, up: l.up)];
  }

  /// A leaf [len] long, pointing along +x from its base at the origin.
  static Path _leaf(double len) {
    final w = len * 0.46;
    return Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(len * 0.4, -w, len, 0)
      ..quadraticBezierTo(len * 0.4, w, 0, 0)
      ..close();
  }

  /// The wreath behind the medallion, tied at the bottom. Lit from the top
  /// left, a light climbing its branches once per loop — or, [flat], a
  /// silhouette in one colour.
  void _laurels(Canvas canvas, double S, double ph, {Color? flat}) {
    final c = Offset(S / 2, S * _wy);
    final rect = Rect.fromCircle(center: c, radius: S * _wreath);
    final stem = strokePaint(flat ?? _gold(0.2), S * 0.018);
    canvas.drawArc(rect, _branchTop, math.pi / 2 - _branchTop, false, stem);
    canvas.drawArc(rect, math.pi / 2, math.pi / 2 - _branchTop, false, stem);
    final edge = strokePaint(_ink, S * 0.007, 0.55);
    for (final l in _leaves(S)) {
      final leaf = _leaf(l.len);
      canvas.save();
      canvas.translate(l.base.dx, l.base.dy);
      canvas.rotate(l.angle);
      if (flat != null) {
        canvas.drawPath(leaf, fillPaint(flat));
      } else {
        final lit = 0.38 + 0.26 * math.cos(l.angle + 3 * math.pi / 4);
        final k = loopWindow(ph, 0.06 + 0.32 * l.up, 0.16);
        canvas.drawPath(leaf, fillPaint(_gold(lit + 0.4 * (k == null ? 0 : bump(k)))));
        canvas.drawPath(leaf, edge);
      }
      canvas.restore();
    }
    // The ribbon tying the branches: two notched tails, then the knot.
    final knot = c + Offset(0, S * _wreath);
    final len = S * 0.085, w = S * 0.05;
    final tail = _poly([Offset(0, -w / 2), Offset(len, -w / 2), Offset(len - w * 0.45, 0), Offset(len, w / 2), Offset(0, w / 2)]);
    for (final side in const [1.0, -1.0]) {
      canvas.save();
      canvas.translate(knot.dx, knot.dy);
      canvas.rotate(math.pi / 2 - side * 0.55);
      canvas.drawPath(tail, fillPaint(flat ?? const Color(0xFFA30F35)));
      if (flat == null) canvas.drawPath(tail, strokePaint(const Color(0xFF5C0619), S * 0.006, 0.6));
      canvas.restore();
    }
    canvas.drawCircle(knot, S * 0.034, fillPaint(flat ?? const Color(0xFFD02A52)));
    if (flat == null) canvas.drawCircle(knot, S * 0.034, strokePaint(const Color(0xFF5C0619), S * 0.007, 0.7));
  }

  static Path _crownPath(double S) => _poly([
        Offset(S * 0.37, S * 0.25),
        _pearls[0] * S,
        Offset(S * 0.43, S * 0.165),
        _pearls[1] * S,
        Offset(S * 0.57, S * 0.165),
        _pearls[2] * S,
        Offset(S * 0.63, S * 0.25),
      ]);

  /// The crown on the medallion: gold, a pearl on each point and a ruby on
  /// its band — or, [flat], a silhouette.
  void _crown(Canvas canvas, double S, {Color? flat}) {
    final crown = _crownPath(S);
    if (flat != null) {
      canvas.drawPath(crown, fillPaint(flat));
      for (final p in _pearls) {
        canvas.drawCircle(p * S, S * 0.026, fillPaint(flat));
      }
      return;
    }
    canvas.drawPath(crown, Paint()..shader = ui.Gradient.linear(Offset(0, S * 0.05), Offset(0, S * 0.25), [_gold(0.9), _gold(0.55), _gold(0.22)], const [0, 0.55, 1]));
    canvas.drawLine(Offset(S * 0.366, S * 0.2), Offset(S * 0.634, S * 0.2), strokePaint(_ink, S * 0.009, 0.45));
    canvas.drawPath(crown, strokePaint(_ink, S * 0.011, 0.85));
    for (final p in _pearls) {
      final at = p * S;
      canvas.drawCircle(at, S * 0.026, Paint()..shader = ui.Gradient.radial(at - Offset(S * 0.008, S * 0.008), S * 0.034, const [Colors.white, Color(0xFFE9D9B5)]));
      canvas.drawCircle(at, S * 0.026, strokePaint(_ink, S * 0.007, 0.55));
    }
    final ruby = Offset(S * 0.5, S * 0.225);
    canvas.drawCircle(ruby, S * 0.021, Paint()..shader = ui.Gradient.radial(ruby - Offset(S * 0.007, S * 0.007), S * 0.029, const [Color(0xFFFF8FA8), Color(0xFFC8143F), Color(0xFF6E0620)], const [0, 0.55, 1]));
  }

  /// [n] spokes round [c], from [r0] out to [r1] — as one path.
  static Path _spokes(Offset c, int n, double r0, double r1) {
    final path = Path();
    for (var i = 0; i < n; i++) {
      final d = _dir(i * tau / n);
      final a = c + d * r0, b = c + d * r1;
      path
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy);
    }
    return path;
  }

  @override
  void paintBack(Canvas canvas, double S, double ph) {
    final c = Offset(S / 2, S * _cy);
    final mid = Offset(S / 2, S / 2);
    // A warm aura, and rays of light fanning out round the crown — long and
    // short, turning a twelfth of a turn per loop (they look the same every
    // twelfth), both breathing.
    final breathe = wave01(ph, 0, 2);
    canvas.drawCircle(mid, S * 0.5, Paint()..shader = ui.Gradient.radial(mid, S * 0.5, [const Color(0xFFFFC94D).withValues(alpha: 0.32 + 0.2 * breathe), const Color(0x00FFC94D)]));
    final rays = Path();
    for (var i = 0; i < 24; i++) {
      final a = -math.pi / 2 + ph * tau / 12 + i * tau / 24;
      final long = i.isEven;
      final half = long ? 0.075 : 0.045;
      final tip = mid + _dir(a) * S * (long ? 0.5 : 0.43);
      final l = mid + _dir(a - half) * S * 0.2, r = mid + _dir(a + half) * S * 0.2;
      rays.addPolygon([l, tip, r], true);
    }
    canvas.drawPath(rays, Paint()..shader = ui.Gradient.radial(mid, S * 0.5, [const Color(0xFFFFD36B).withValues(alpha: 0.7 + 0.3 * breathe), const Color(0x00FFD36B)], const [0.4, 1]));
    _laurels(canvas, S, ph);
    canvas.drawCircle(
      c + Offset(0, S * 0.03),
      S * _outer,
      Paint()
        ..color = const Color(0x70000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, S * 0.035),
    );
    // The bezel, a light turning round it once per loop, milled like the
    // edge of a coin.
    canvas.drawCircle(
      c,
      S * (_outer + _inner) / 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = S * (_outer - _inner)
        ..shader = SweepGradient(colors: [_gold(0.85), _gold(0.25), _gold(0.62), _gold(0.2), _gold(0.85)], transform: GradientRotation(ph * tau)).createShader(Rect.fromCircle(center: c, radius: S * _outer)),
    );
    canvas.drawPath(_spokes(c, 40, S * (_inner + 0.01), S * (_outer - 0.01)), strokePaint(_ink, S * 0.006, 0.3));
    canvas.drawCircle(c, S * _outer, strokePaint(_ink, S * 0.013, 0.85));
    // The obsidian face, a sunray dial engraved in it.
    final fr = S * _inner;
    canvas.drawCircle(c, fr, Paint()..shader = ui.Gradient.radial(c + Offset(-S * 0.07, -S * 0.09), fr * 1.4, const [Color(0xFF3D3225), Color(0xFF15100A), Color(0xFF040302)], const [0, 0.5, 1]));
    canvas.drawPath(_spokes(c, 36, S * 0.06, fr - S * 0.02), strokePaint(_gold(0.6), S * 0.005, 0.12));
    canvas.drawCircle(c, fr * 0.9, strokePaint(_gold(0.6), S * 0.006, 0.35));
    canvas.drawCircle(c, fr, strokePaint(_gold(0.92), S * 0.011, 0.8));
    _crown(canvas, S);
  }

  /// A band of rainbow light across the disc of radius [r] round [c], like
  /// on a hologram — [u] from 0 (off to the left) to 1 (off to the right).
  static void _prism(Canvas canvas, Offset c, double r, double u) {
    if (u <= 0 || u >= 1) return;
    final w = r * 1.1;
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)));
    canvas.translate(c.dx + lerpD(-r * 2.1, r * 2.1, u), c.dy);
    canvas.rotate(-0.6);
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: w, height: r * 3),
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.linear(Offset(-w / 2, 0), Offset(w / 2, 0), const [Color(0x0019E3FF), Color(0x5C19E3FF), Color(0x6BFF4FD8), Color(0x6BFFD25C), Color(0x00FFD25C)], const [0, 0.28, 0.52, 0.76, 1]),
    );
    canvas.restore();
  }

  @override
  void paintFront(Canvas canvas, double S, double ph) {
    _prism(canvas, Offset(S / 2, S * _cy), S * _inner, loopWindow(ph, 0.6, 0.3) ?? 0);
    // The light that climbed the laurels ends on the crown's pearls.
    for (final (i, start) in const [(0, 0.42), (1, 0.48), (2, 0.54)]) {
      final k = loopWindow(ph, start, 0.14);
      if (k != null) drawSparkle(canvas, _pearls[i] * S, S * 0.12 * bump(k), fillPaint(Colors.white, bump(k)));
    }
    // Gold dust rising either side.
    for (var i = 0; i < 6; i++) {
      final u = fract(ph * (1 + (i ~/ 2) % 2) + hash01(i + 3));
      final side = i.isEven ? 1.0 : -1.0;
      final p = Offset(S / 2 + side * S * (0.36 + 0.09 * hash01(i + 11)) + S * 0.02 * wave(ph, hash01(i + 7), 2), S * lerpD(0.86, 0.1, u));
      final a = bump(u);
      drawGlow(canvas, p, S * 0.05 * a, const Color(0xFFFFC94D), 0.7 * a);
      canvas.drawCircle(p, S * (0.008 + 0.006 * hash01(i + 5)), fillPaint(const Color(0xFFFFF3CC), a));
    }
  }

  @override
  void paintLocked(Canvas canvas, double S, Color track, Color face) {
    final c = Offset(S / 2, S * _cy);
    _laurels(canvas, S, 0, flat: Color.lerp(track, face, 0.35));
    canvas.drawCircle(c, S * _outer, fillPaint(track));
    canvas.drawCircle(c, S * _inner, fillPaint(face));
    _crown(canvas, S, flat: track);
  }

  @override
  Path track(double S) {
    final rect = Rect.fromCircle(center: Offset(S / 2, S * _cy), radius: S * (_outer + _inner) / 2);
    return Path()
      ..addArc(rect, -math.pi / 2, math.pi)
      ..arcTo(rect, math.pi / 2, math.pi, false);
  }

  /// A crown.
  @override
  Path glyph(double S) => _poly([
        Offset(S * 0.1, S * 0.9),
        Offset(S * 0.04, S * 0.2),
        Offset(S * 0.32, S * 0.48),
        Offset(S * 0.5, S * 0.08),
        Offset(S * 0.68, S * 0.48),
        Offset(S * 0.96, S * 0.2),
        Offset(S * 0.9, S * 0.9),
      ]);
}
