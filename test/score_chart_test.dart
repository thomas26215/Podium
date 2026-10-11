import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podium/theme/app_theme.dart';
import 'package:podium/widgets/score_evolution_chart.dart';

void main() {
  test('the score chart never draws two lines in look-alike colours, whatever the accent', () {
    for (final a in AccentId.values.where((a) => a != AccentId.custom)) {
      for (final dark in [false, true]) {
        final t = AppTokens.resolve(Appearance(accent: a), dark: dark);
        final colors = scoreLineColors(t.accent, green: t.green, gold: t.gold);
        final where = '${a.name} / ${dark ? 'dark' : 'light'}';
        expect(colors.first, t.accent, reason: where);
        expect(colors.length, greaterThanOrEqualTo(5), reason: where);
        final accentHue = HSLColor.fromColor(t.accent).hue;
        for (final c in colors.skip(1)) {
          final d = (HSLColor.fromColor(c).hue - accentHue).abs();
          expect(d > 180 ? 360 - d : d, greaterThan(20), reason: '$where: $c');
        }
      }
    }
  });

  test('with the orange accent, the chart keeps its original colours', () {
    final t = AppTokens.resolve(const Appearance(accent: AccentId.orange), dark: false);
    expect(scoreLineColors(t.accent, green: t.green, gold: t.gold).take(5), [t.accent, t.green, t.gold, const Color(0xFF5B4BE8), const Color(0xFFE5537B)]);
  });
}
