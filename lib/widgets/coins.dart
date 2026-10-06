import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../logic/plus.dart';
import '../theme/app_theme.dart';

/// A jeton, Podium's coin: gold, notched like a game chip, with the
/// podium's three steps struck in the middle.
class CoinIcon extends StatelessWidget {
  final double size;
  const CoinIcon({super.key, this.size = 16});

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: const _CoinPainter());
}

class _CoinPainter extends CustomPainter {
  const _CoinPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final c = size.center(Offset.zero);
    canvas.drawCircle(c + Offset(0, r * 0.08), r, Paint()..color = const Color(0x33000000));
    canvas.drawCircle(c, r, Paint()..shader = ui.Gradient.linear(c - Offset(r, r), c + Offset(r, r), const [Color(0xFFFFE28A), Color(0xFFF2B33D), Color(0xFFC07E14)], const [0, 0.5, 1]));
    // The chip's notches round the rim.
    final notch = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.2
      ..color = const Color(0xFFFFF1C2);
    for (var i = 0; i < 8; i++) {
      canvas.drawArc(Rect.fromCircle(center: c, radius: r * 0.84), i * math.pi / 4 - math.pi / 20, math.pi / 10, false, notch);
    }
    canvas.drawCircle(c, r * 0.64, Paint()..color = const Color(0xFFDB9A22));
    canvas.drawCircle(c, r * 0.64, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.6, r * 0.07)
      ..color = const Color(0x8CFFF6DA));
    // The podium: 2nd, 1st, 3rd.
    final bar = Paint()..color = const Color(0xFFFFF8E1);
    final w = r * 0.2, gap = r * 0.05, base = c.dy + r * 0.3;
    for (final (i, h) in const [0.38, 0.56, 0.28].indexed) {
      final left = c.dx - w * 1.5 - gap + i * (w + gap);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(left, base - r * h, left + w, base), Radius.circular(w * 0.25)), bar);
    }
  }

  @override
  bool shouldRepaint(_CoinPainter old) => false;
}

/// A number of jetons — the coin, then "1 200".
class CoinAmount extends StatelessWidget {
  final int amount;
  final double size;
  final Color? color;
  final FontWeight weight;
  const CoinAmount(this.amount, {super.key, this.size = 14, this.color, this.weight = FontWeight.w800});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: coinsLabel(amount),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CoinIcon(size: size * 1.15),
          SizedBox(width: size * 0.32),
          Text(groupDigits(amount), style: dispFont(size: size, weight: weight, color: color ?? AppColors.ink)),
        ],
      ),
    );
  }
}
