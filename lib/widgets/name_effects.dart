import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import 'ambient_loop.dart';
import 'fx_kit.dart';

/// Fonts a player can pick for their name on the profile card (see
/// AppUser.nameFont). `null` is the app's own display font.
const kNameFonts = <({String? id, String label})>[
  (id: null, label: 'Classique'),
  (id: 'arcade', label: 'Arcade'),
  (id: 'retro', label: 'Rétro'),
  (id: 'comic', label: 'BD'),
  (id: 'medieval', label: 'Médiéval'),
  (id: 'script', label: 'Manuscrit'),
  (id: 'future', label: 'Futuriste'),
  (id: 'marker', label: 'Feutre'),
  (id: 'horror', label: 'Horreur'),
];

/// The name's text style at roughly [size] — each font is scaled so they
/// all read about as big as the default.
TextStyle nameFontStyle(String? fontId, double size) => switch (fontId) {
      'arcade' => GoogleFonts.pressStart2p(fontSize: size * 0.6, height: 1.5),
      'retro' => GoogleFonts.vt323(fontSize: size * 1.35, height: 1),
      'comic' => GoogleFonts.bangers(fontSize: size * 1.12, letterSpacing: 1.2),
      'medieval' => GoogleFonts.cinzel(fontSize: size * 0.92, fontWeight: FontWeight.w800),
      'script' => GoogleFonts.pacifico(fontSize: size * 0.9, height: 1.3),
      'future' => GoogleFonts.orbitron(fontSize: size * 0.86, fontWeight: FontWeight.w800),
      'marker' => GoogleFonts.permanentMarker(fontSize: size * 0.98),
      'horror' => GoogleFonts.creepster(fontSize: size * 1.12, letterSpacing: 1.2),
      _ => dispFont(size: size, weight: FontWeight.w800, letterSpacing: -0.4),
    };

/// Animated treatments for the name (see AppUser.nameEffect).
const kNameEffects = <({String? id, String label})>[
  (id: null, label: 'Aucun'),
  (id: 'gradient', label: 'Dégradé'),
  (id: 'neon', label: 'Néon'),
  (id: 'gold', label: 'Or'),
  (id: 'rainbow', label: 'Arc-en-ciel'),
  (id: 'fire', label: 'Feu'),
  (id: 'glitch', label: 'Glitch'),
  (id: 'wave', label: 'Vague'),
  (id: 'shine', label: 'Brillance'),
  (id: 'holo', label: 'Holo'),
];

Duration _periodOf(String effect) => switch (effect) {
      'wave' => const Duration(milliseconds: 2400),
      'neon' || 'shine' => const Duration(seconds: 3),
      'gold' => const Duration(milliseconds: 3500),
      'holo' => const Duration(seconds: 5),
      _ => const Duration(seconds: 4),
    };

/// A player's name in their chosen font and effect, white-based so it sits
/// on any banner; [accent] (their avatar colour) tints the gradient, neon
/// and wave effects. Effects keep moving on an ambient loop; [phase]
/// freezes one instead (thumbnails, visual checks).
class StyledName extends StatelessWidget {
  final String text;
  final String? fontId;
  final String? effectId;
  final double size;
  final Color accent;
  final double? phase;
  const StyledName({super.key, required this.text, this.fontId, this.effectId, this.size = 25, required this.accent, this.phase});

  @override
  Widget build(BuildContext context) {
    final raw = nameFontStyle(fontId, size);
    final base = raw.copyWith(color: Colors.white);
    final effect = effectId;
    if (effect == null || !kNameEffects.any((e) => e.id == effect)) {
      return Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, softWrap: false, style: base.copyWith(shadows: const [Shadow(color: Color(0x66000000), blurRadius: 8)]));
    }
    if (phase != null) return _NameFx(text: text, raw: raw, effect: effect, accent: accent, size: size, ph: phase!);
    return RepaintBoundary(
      child: AmbientLoop(period: _periodOf(effect), builder: (context, ph) => _NameFx(text: text, raw: raw, effect: effect, accent: accent, size: size, ph: ph)),
    );
  }
}

class _NameFx extends StatelessWidget {
  final String text;

  /// The font's style with no colour — [base] adds white; the stroked and
  /// tinted variants add a `foreground` paint instead (a style can't have
  /// both).
  final TextStyle raw;
  final String effect;
  final Color accent;
  final double size;
  final double ph;
  const _NameFx({required this.text, required this.raw, required this.effect, required this.accent, required this.size, required this.ph});

  TextStyle get base => raw.copyWith(color: Colors.white);

  TextStyle _painted(Paint paint) => raw.copyWith(foreground: paint, shadows: const []);

  Widget _text(TextStyle style) => Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, softWrap: false, style: style);

  /// The name filled with a gradient, slid by [shift] lengths of the
  /// gradient along its own axis — so a whole number of them brings a tiled
  /// gradient back exactly where it started.
  Widget _filled(List<Color> colors, {List<double>? stops, Alignment begin = Alignment.centerLeft, Alignment end = Alignment.centerRight, double shift = 0, TileMode tile = TileMode.mirror}) =>
      _shaded((box) => LinearGradient(begin: begin, end: end, colors: colors, stops: stops, tileMode: tile, transform: _Slide.along(begin, end, box.size, shift)).createShader(box));

  /// The name painted with [shader], laid over its text box.
  Widget _shaded(ShaderCallback shader) => _BleedingShaderMask(bleed: size * 0.6, shaderCallback: shader, child: _text(base.copyWith(shadows: const [])));

  /// A blurred, tinted copy of the name — the glow under the effects.
  Widget _glow(Color color, double sigma, double alpha) => ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.decal),
        child: _text(base.copyWith(color: color.withValues(alpha: clamp01(alpha)), shadows: const [])),
      );

  /// A bright band sweeping across the letters while [u] goes 0 → 1.
  Widget _sweep(double u, {double width = 0.22, double alpha = 0.95, bool soft = false}) => _shaded((box) {
        // Tilted ~27° like a glint on metal, whatever the text's shape; a
        // flat bright core unless [soft]. It enters and leaves clear of
        // the letters.
        final tilt = box.width * 0.25 / math.max(1.0, box.height / 2);
        final edge = width / 2, core = soft ? 0.0 : width / 6;
        final white = Colors.white.withValues(alpha: alpha);
        return LinearGradient(
          begin: Alignment(-1, -tilt),
          end: Alignment(1, tilt),
          colors: [const Color(0x00FFFFFF), white, white, const Color(0x00FFFFFF)],
          stops: [0.5 - edge, 0.5 - core, 0.5 + core, 0.5 + edge],
          transform: _Slide(lerpD(-1.3, 1.3, u) * box.width, 0),
        ).createShader(box);
      });

  Widget _shadow() => _text(base.copyWith(color: Colors.transparent, shadows: const [Shadow(color: Color(0x80000000), blurRadius: 8, offset: Offset(0, 2))]));

  Widget _over(CustomPainter painter) => Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: painter)));

  @override
  Widget build(BuildContext context) {
    final light = Color.lerp(accent, Colors.white, 0.45)!;
    final layers = switch (effect) {
      'gradient' => [
          _shadow(),
          _glow(accent, 6, 0.55),
          _filled([Color.lerp(accent, Colors.white, 0.1)!, Colors.white, light, Color.lerp(accent, Colors.white, 0.1)!], shift: ph * 2),
        ],
      'neon' => () {
          // Two quick stutters a loop, like a tired tube.
          final stutter = (loopWindow(ph, 0.36, 0.06) != null || loopWindow(ph, 0.81, 0.04) != null) ? ((ph * 500).floor().isEven ? 0.25 : 0.9) : 1.0;
          final hum = (0.8 + 0.2 * wave01(ph, 0, 6)) * stutter;
          return [
            _glow(accent, 10 * hum, 0.9 * hum),
            _glow(light, 3, 0.8 * hum),
            _text(_painted(Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = size * 0.07
              ..strokeJoin = StrokeJoin.round
              ..color = light.withValues(alpha: hum))),
            _text(_painted(Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = size * 0.022
              ..color = Colors.white.withValues(alpha: 0.95 * stutter))),
          ];
        }(),
      'gold' => () {
          // Cast gold catching the light: a soft sheen and a crisp glint
          // racing across, the glow swelling as they pass.
          final u = loopWindow(ph, 0.05, 0.32);
          final bloom = u == null ? 0.0 : bump(u);
          return [
            _shadow(),
            _glow(const Color(0xFFFFB703), 5 + 4 * bloom, 0.5 + 0.35 * bloom),
            _filled(const [Color(0xFFFFEDB0), Color(0xFFF0C04A), Color(0xFFB37A0C), Color(0xFFF5D272), Color(0xFF8A5A06)], stops: const [0, 0.32, 0.55, 0.72, 1], begin: Alignment.topCenter, end: Alignment.bottomCenter, tile: TileMode.clamp),
            if (u != null) ...[_sweep(u, width: 0.75, alpha: 0.45, soft: true), _sweep(u, width: 0.24)],
            _over(_SparklePainter(ph, const Color(0xFFFFF4C2), count: 6)),
          ];
        }(),
      'rainbow' => [
          _shadow(),
          _glow(Colors.white, 5, 0.35),
          _filled([for (var k = 0; k <= 6; k++) hsv(k * 60.0, 0.7, 1)], shift: ph, tile: TileMode.repeated),
        ],
      'fire' => [
          _over(_FlamePainter(ph, behind: true)),
          _glow(const Color(0xFFFF7B00), 7 + 2 * wave01(ph, 0, 23), 0.85),
          _filled(const [Color(0xFFFFF3B0), Color(0xFFFFB703), Color(0xFFFB5607), Color(0xFFC1121F)], begin: Alignment.bottomCenter, end: Alignment.topCenter, shift: -0.08 * wave(ph, 0, 19), tile: TileMode.clamp),
          _over(_FlamePainter(ph, behind: false)),
        ],
      'glitch' => _glitch(),
      'wave' => [_wave(light)],
      'shine' => () {
          final u = loopWindow(ph, 0.1, 0.45);
          final bloom = u == null ? 0.0 : bump(u);
          return [
            _shadow(),
            _glow(Colors.white, 7 + 6 * bloom, 0.2 + 0.65 * bloom),
            // Polished silver, deep enough for the white sweep to flare.
            _filled(const [Color(0xFFEDF0F7), Color(0xFFAEB5C7), Color(0xFF7E879E)], stops: const [0, 0.55, 1], begin: Alignment.topCenter, end: Alignment.bottomCenter, tile: TileMode.clamp),
            if (u != null) ...[_sweep(u, width: 0.8, alpha: 0.5, soft: true), _sweep(u, width: 0.28)],
            if (u != null) _over(_SparklePainter(ph, Colors.white, count: 2)),
          ];
        }(),
      'holo' => [
          _shadow(),
          _glow(const Color(0xFFB49AFF), 5, 0.5),
          _filled(const [Color(0xFFFF9AE2), Color(0xFF9AE7FF), Color(0xFFFFF59A), Color(0xFFB49AFF), Color(0xFF9AFFC8), Color(0xFFFF9AE2)], begin: Alignment.topLeft, end: Alignment.bottomRight, shift: ph, tile: TileMode.repeated),
          // Foil stripes sliding the other way at another pace.
          _shaded((box) => LinearGradient(
                begin: Alignment.topLeft,
                end: const Alignment(-0.6, -0.2),
                colors: const [Color(0x00FFFFFF), Color(0x66FFFFFF), Color(0x00FFFFFF)],
                tileMode: TileMode.repeated,
                transform: _Slide.along(Alignment.topLeft, const Alignment(-0.6, -0.2), box.size, -9 * ph),
              ).createShader(box)),
          _over(_SparklePainter(ph, Colors.white, count: 4)),
        ],
      _ => [_text(base)],
    };
    // One name for screen readers, not one per layer.
    return Semantics(label: text, excludeSemantics: true, child: Stack(clipBehavior: Clip.none, children: layers));
  }

  List<Widget> _glitch() {
    // Mostly a faint colour split; three bursts a loop of jumpy offsets and
    // sliced, displaced letters.
    final burst = [loopWindow(ph, 0.1, 0.05), loopWindow(ph, 0.46, 0.03), loopWindow(ph, 0.73, 0.06)].whereType<double>().firstOrNull;
    final step = (ph * 60).floor();
    double jitter(int k) => (hash01(step * 7 + k) - 0.5) * 2;
    final split = burst != null ? size * 0.12 : size * 0.035;
    final dx = burst != null ? jitter(1) * size * 0.1 : 0.0;
    Widget copy(Color color, Offset offset) => Transform.translate(
          offset: offset,
          child: _text(_painted(Paint()
            ..color = color
            ..blendMode = BlendMode.plus)),
        );
    return [
      _shadow(),
      copy(const Color(0xCCFF2BD6), Offset(-split + dx, burst != null ? jitter(2) * size * 0.05 : 0)),
      copy(const Color(0xCC00E5FF), Offset(split + dx, burst != null ? jitter(3) * size * 0.05 : 0)),
      if (burst == null)
        _text(base.copyWith(shadows: const []))
      else
        for (var i = 0; i < 4; i++)
          ClipRect(
            clipper: _Slice(i / 4, (i + 1) / 4),
            child: Transform.translate(offset: Offset(jitter(10 + i) * size * 0.18, 0), child: _text(base.copyWith(shadows: const []))),
          ),
    ];
  }

  Widget _wave(Color light) {
    final chars = text.characters.toList();
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, ch) in chars.indexed)
            Transform.translate(
              offset: Offset(0, math.sin((ph - i * 0.08) * tau) * size * 0.14),
              child: Text(
                ch,
                style: base.copyWith(
                  color: Color.lerp(Colors.white, light, wave01(ph, -i * 0.08)),
                  shadows: [Shadow(color: accent.withValues(alpha: 0.8), blurRadius: 10), const Shadow(color: Color(0x80000000), blurRadius: 6, offset: Offset(0, 2))],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A [ShaderMask] (srcIn) whose mask reaches [bleed] past its child's box:
/// glyphs can spill out of their text box (accents, swashes, descenders),
/// and past a plain ShaderMask's edge they'd keep their own white.
class _BleedingShaderMask extends SingleChildRenderObjectWidget {
  final ShaderCallback shaderCallback;
  final double bleed;
  const _BleedingShaderMask({required this.shaderCallback, required this.bleed, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderBleedingShaderMask(shaderCallback, bleed);

  @override
  void updateRenderObject(BuildContext context, _RenderBleedingShaderMask renderObject) {
    renderObject
      ..shaderCallback = shaderCallback
      ..bleed = bleed;
  }
}

class _RenderBleedingShaderMask extends RenderProxyBox {
  _RenderBleedingShaderMask(this._shaderCallback, this._bleed);

  ShaderCallback _shaderCallback;
  set shaderCallback(ShaderCallback value) {
    _shaderCallback = value;
    markNeedsPaint();
  }

  double _bleed;
  set bleed(double value) {
    if (value == _bleed) return;
    _bleed = value;
    markNeedsPaint();
  }

  @override
  ShaderMaskLayer? get layer => super.layer as ShaderMaskLayer?;

  @override
  bool get alwaysNeedsCompositing => child != null;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) {
      layer = null;
      return;
    }
    // The layer draws the shader from its mask's top-left corner, so the
    // child's box sits [_bleed] in from there.
    layer ??= ShaderMaskLayer();
    layer!
      ..shader = _shaderCallback(Offset(_bleed, _bleed) & size)
      ..maskRect = (offset & size).inflate(_bleed)
      ..blendMode = BlendMode.srcIn;
    context.pushLayer(layer!, super.paint, offset);
  }
}

class _Slide extends GradientTransform {
  final double dx, dy;
  const _Slide(this.dx, this.dy);

  /// [lengths] times the gradient's own begin → end vector.
  factory _Slide.along(Alignment begin, Alignment end, Size size, double lengths) {
    final axis = end.alongSize(size) - begin.alongSize(size);
    return _Slide(axis.dx * lengths, axis.dy * lengths);
  }
  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) => Matrix4.translationValues(dx, dy, 0);
}

class _Slice extends CustomClipper<Rect> {
  final double from, to;
  const _Slice(this.from, this.to);
  @override
  Rect getClip(Size size) => Rect.fromLTRB(-size.width, size.height * from, size.width * 2, size.height * to);
  @override
  bool shouldReclip(_Slice old) => old.from != from || old.to != to;
}

/// Twinkles popping up around the letters.
class _SparklePainter extends CustomPainter {
  final double ph;
  final Color color;
  final int count;
  _SparklePainter(this.ph, this.color, {required this.count});

  @override
  void paint(Canvas canvas, Size s) {
    for (var i = 0; i < count; i++) {
      final u = loopWindow(ph, i / count + hash01(i) * 0.1, 0.35);
      if (u == null) continue;
      final p = Offset(s.width * (0.05 + 0.9 * hash01(i + 11)), s.height * (0.1 + 0.8 * hash01(i + 23)));
      final k = bump(u);
      drawSparkle(canvas, p, s.height * 0.16 * k, fillPaint(color, k));
      drawGlow(canvas, p, s.height * 0.3 * k, color, 0.5 * k);
    }
  }

  @override
  bool shouldRepaint(_SparklePainter old) => old.ph != ph;
}

/// Flames licking up from the tops of the letters (behind them) and embers
/// rising (in front).
class _FlamePainter extends CustomPainter {
  final double ph;
  final bool behind;
  _FlamePainter(this.ph, {required this.behind});

  @override
  void paint(Canvas canvas, Size s) {
    if (s.isEmpty) return;
    if (behind) {
      final n = math.max(4, (s.width / (s.height * 0.32)).round());
      for (final (scale, color) in const [(1.0, Color(0xFFD62828)), (0.7, Color(0xFFFF7B00)), (0.42, Color(0xFFFFD166))]) {
        final paint = Paint()
          ..blendMode = BlendMode.plus
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s.height * 0.04)
          ..color = color.withValues(alpha: 0.8);
        for (var i = 0; i < n; i++) {
          final x = s.width * (i + 0.5) / n;
          final baseY = s.height * 0.42;
          final hgt = s.height * 0.62 * scale * (0.55 + 0.45 * wave01(ph, hash01(i * 5 + scale), 23 + (i % 4) * 6));
          final wid = s.width / n * 0.55 * scale;
          final sway = wave(ph, hash01(i + 31), 17) * wid * 0.5;
          canvas.drawPath(Path()
            ..moveTo(x - wid, baseY)
            ..quadraticBezierTo(x - wid * 0.6, baseY - hgt * 0.6, x + sway, baseY - hgt)
            ..quadraticBezierTo(x + wid * 0.6, baseY - hgt * 0.6, x + wid, baseY)
            ..close(), paint);
        }
      }
      return;
    }
    for (var i = 0; i < 10; i++) {
      final life = fract(ph * (2 + i % 3) + hash01(i));
      final p = Offset(s.width * hash01(i + 40) + wave(ph, hash01(i + 3), 4) * 6, s.height * 0.3 - life * s.height * 1.1);
      canvas.drawCircle(p, s.height * 0.035 * (1 - life) + 0.5, fillPaint(Color.lerp(const Color(0xFFFFF3B0), const Color(0xFFFF7B00), life)!, (1 - life) * span(life, 0, 0.12)));
    }
  }

  @override
  bool shouldRepaint(_FlamePainter old) => old.ph != ph;
}
