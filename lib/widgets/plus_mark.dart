import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/plus_membership.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// Podium+'s own colours — the same in every theme, like a brand: amber,
/// pink and violet, the mythic badges' end of the spectrum.
const kPlusGradient = [Color(0xFFFFB547), Color(0xFFFF5C8A), Color(0xFF8B5CF6)];

/// The night behind the Podium+ page — the app icon's own navy.
const kPlusNight = Color(0xFF080E2A);

/// The mark of a membership: a white plus on Podium's gradient — two, on
/// a wider pill, for Podium++. Pinned on what a membership unlocks, and
/// next to a member's name on their card.
class PlusMark extends StatelessWidget {
  /// Its height — a Podium++ one is wider.
  final double size;

  /// A white rim, to stand out on any picture (a banner, a frame…).
  final bool rim;
  final PlusTier tier;
  const PlusMark({super.key, this.size = 18, this.rim = true, this.tier = PlusTier.plus});

  @override
  Widget build(BuildContext context) {
    final pluses = tier == PlusTier.plusPlus ? 2 : 1;
    return Semantics(
      label: tier.label,
      child: Container(
        width: pluses == 2 ? size * 1.62 : size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size / 2),
          boxShadow: [BoxShadow(color: kPlusGradient[1].withValues(alpha: 0.45), blurRadius: size * 0.45, offset: Offset(0, size * 0.1))],
        ),
        child: CustomPaint(painter: _MarkPainter(rim, pluses)),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  final bool rim;
  final int pluses;
  _MarkPainter(this.rim, this.pluses);

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final r = h / 2;
    final pill = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(r));
    canvas.drawRRect(pill, Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(size.width, h), kPlusGradient, const [0, 0.5, 1]));
    // A soft light on the upper half, like a glazed bead.
    canvas.drawRRect(pill, Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(0, r), const [Color(0x40FFFFFF), Color(0x00FFFFFF)]));
    if (rim) {
      final w = math.max(1.2, h * 0.09);
      canvas.drawRRect(pill.deflate(w / 2), Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..color = Colors.white);
    }
    final arm = h * (pluses == 2 ? (rim ? 0.17 : 0.19) : (rim ? 0.2 : 0.24));
    final glyph = Paint()
      ..color = Colors.white
      ..strokeWidth = h * (rim ? 0.13 : 0.15)
      ..strokeCap = StrokeCap.round;
    final mid = size.center(Offset.zero);
    for (final c in pluses == 2 ? [mid - Offset(h * 0.29, 0), mid + Offset(h * 0.29, 0)] : [mid]) {
      canvas.drawLine(c - Offset(arm, 0), c + Offset(arm, 0), glyph);
      canvas.drawLine(c - Offset(0, arm), c + Offset(0, arm), glyph);
    }
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.rim != rim || old.pluses != pluses;
}

/// A line in the app's own style telling a player about the + on some
/// options, with a way to unlock them ([onTap], called [action]).
class PlusHint extends StatelessWidget {
  final String text;
  final String action;
  final VoidCallback onTap;

  /// The membership the marked options come with.
  final PlusTier tier;
  const PlusHint({super.key, required this.text, this.action = 'Découvrir', required this.onTap, this.tier = PlusTier.plus});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
        decoration: cardDecoration(radius: AppRadius.md, fill: AppColors.accentSoft, border: AppColors.accent.withValues(alpha: 0.35)),
        child: Row(
          children: [
            PlusMark(size: 20, tier: tier),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: bodyFont(size: 13, weight: FontWeight.w700, color: AppColors.ink2, height: 1.3))),
            const SizedBox(width: 8),
            Text(action, style: bodyFont(size: 13, weight: FontWeight.w800, color: AppColors.accent)),
          ],
        ),
      ),
    );
  }
}

/// "Podium" and the mark, as one name — "Podium+" or "Podium++" — always in
/// Podium's own display font, whatever font the player picked for the app.
class PlusWordmark extends StatelessWidget {
  final double size;
  final Color color;
  final PlusTier tier;
  const PlusWordmark({super.key, this.size = 30, this.color = Colors.white, this.tier = PlusTier.plus});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: tier.label,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Podium', style: GoogleFonts.spaceGrotesk(fontSize: size, fontWeight: FontWeight.w700, color: color, letterSpacing: -size * 0.03, height: 1)),
          SizedBox(width: size * 0.16),
          PlusMark(size: size * 0.86, rim: false, tier: tier),
        ],
      ),
    );
  }
}
