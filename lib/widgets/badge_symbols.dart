import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../logic/badges.dart';
import '../theme/app_theme.dart';
import 'badge_symbol_data.dart';
import 'fx_kit.dart';

/// The credit the symbols' licence asks for, naming who drew them.
String badgeSymbolsCredit() {
  final authors = [for (final folder in {for (final s in kBadgeSymbolPaths.keys) s.split('/').first}) kBadgeSymbolAuthors[folder] ?? folder]..sort();
  final last = authors.removeLast();
  return 'Symboles des badges : game-icons.net, par ${authors.isEmpty ? last : '${authors.join(', ')} et $last'} — licence CC BY 3.0.';
}

final _outlines = <String, Path>{};

/// The outline of [symbol] (see BadgeDef.symbol), centred on a 1 × 1 box,
/// its proportions kept. A square one fills the box; a wide or tall one may
/// reach a quarter beyond it on its long side, so it doesn't look smaller.
/// Parsed once.
Path badgeSymbolOutline(String symbol) => _outlines.putIfAbsent(symbol, () {
      final data = kBadgeSymbolPaths[symbol];
      if (data == null) return Path();
      final path = Path();
      for (final outline in data.split('|')) {
        path.addPath(svgPath(outline), Offset.zero);
      }
      final bounds = path.getBounds();
      final scale = math.min(1.25 / math.max(bounds.width, bounds.height), 1 / math.sqrt(bounds.width * bounds.height));
      return path.shift(-bounds.center).transform(Matrix4.diagonal3Values(scale, scale, 1).storage).shift(const Offset(0.5, 0.5));
    });

/// How a tier's symbols are struck: in a metal shading from its lit edge
/// (top left) to its shaded one, a dark line round it — and, on the tiers
/// with a dark face, a glow under it rather than a shadow.
class _Strike {
  final List<Color> metal;
  final Color line;
  final Color? glow;
  const _Strike(this.metal, this.line, {this.glow});
}

_Strike _strikeOf(BadgeTier t) => switch (t) {
      BadgeTier.bronze => const _Strike([Color(0xFFF6CFA4), Color(0xFFCB8650), Color(0xFF8E4B1C), Color(0xFF5E2E0E)], Color(0xFF3F1C07)),
      BadgeTier.silver => const _Strike([Color(0xFFF4F6FA), Color(0xFFA7B0BF), Color(0xFF6A7486), Color(0xFF404857)], Color(0xFF2A303B)),
      BadgeTier.gold => const _Strike([Color(0xFFFFEDB0), Color(0xFFEDB53C), Color(0xFFB07A0E), Color(0xFF7A5206)], Color(0xFF4D3303)),
      BadgeTier.platinum => const _Strike([Color(0xFFDDF1F3), Color(0xFF8DB4BC), Color(0xFF4A7A84), Color(0xFF2A525B)], Color(0xFF1B3A41)),
      BadgeTier.diamond => const _Strike([Color(0xFFBFE6FF), Color(0xFF4C9BF0), Color(0xFF1E57C4), Color(0xFF123783)], Color(0xFF0B2459)),
      BadgeTier.mythic => const _Strike([Color(0xFFFFFFFF), Color(0xFFFFE6A6), Color(0xFFFFA8E2), Color(0xFFC08BFF)], Color(0xFF3A0E6B), glow: Color(0xFFFF7AD9)),
      BadgeTier.exclusive => const _Strike([Color(0xFFFFF4C9), Color(0xFFF0C55A), Color(0xFFB98322), Color(0xFF6E4609)], Color(0xFF2A1A03), glow: Color(0xFFFFC94D)),
    };

/// [badge]'s symbol, [size] wide: struck in relief in the metal of its
/// tier — or, locked, a faint silhouette. It never moves, so it keeps a
/// layer of its own while the medal round it is animated.
class BadgeSymbol extends StatelessWidget {
  final BadgeDef badge;
  final bool earned;
  final double size;
  const BadgeSymbol({super.key, required this.badge, required this.earned, required this.size});

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: CustomPaint(size: Size.square(size), painter: _SymbolPainter(badgeSymbolOutline(badge.symbol), earned ? _strikeOf(badge.tier) : null, AppColors.mut)),
      );
}

class _SymbolPainter extends CustomPainter {
  final Path outline;
  final _Strike? strike;
  final Color locked;
  _SymbolPainter(this.outline, this.strike, this.locked);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final p = outline.transform(Matrix4.diagonal3Values(s, s, 1).storage);
    final st = strike;
    if (st == null) {
      canvas.drawPath(p, fillPaint(locked, 0.4));
      return;
    }
    // Raised off the face: a shadow under it, or a glow on a dark face.
    final d = s * 0.03;
    final glow = st.glow;
    canvas.drawPath(
      glow == null ? p.shift(Offset(0, d * 1.3)) : p,
      Paint()
        ..color = glow?.withValues(alpha: 0.6) ?? const Color(0x59000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, glow == null ? d : s * 0.06),
    );
    canvas.drawPath(p, Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(s, s), st.metal, const [0, 0.35, 0.72, 1]));
    // Its bevel: lit along its inner top-left edges, shaded along the others.
    canvas.save();
    canvas.clipPath(p);
    canvas.drawPath(p.shift(Offset(d, d)), strokePaint(Colors.white, d * 1.6, 0.6));
    canvas.drawPath(p.shift(Offset(-d, -d)), strokePaint(st.line, d * 1.6, 0.35));
    canvas.restore();
    canvas.drawPath(p, strokePaint(st.line, math.max(0.6, s * 0.022), 0.85));
  }

  @override
  bool shouldRepaint(_SymbolPainter old) => old.outline != outline || old.strike != strike || old.locked != locked;
}
