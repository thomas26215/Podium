import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:podium/logic/elo.dart';
import 'package:podium/widgets/elo_widgets.dart';

/// How many times [ys] turns from rising to falling or back.
int _turns(List<double> ys) {
  var turns = 0, last = 0.0;
  for (var i = 1; i < ys.length; i++) {
    final d = ys[i] - ys[i - 1];
    if (d.abs() < 1e-9) continue;
    if (last != 0 && d.sign != last.sign) turns++;
    last = d;
  }
  return turns;
}

void main() {
  // 80 matches won and lost by turns: +40, −15, +40, −15…
  final climb = [kEloStart, for (var i = 1; i <= 80; i++) kEloStart + 25.0 * (i ~/ 2) + (i.isOdd ? 40 : 0)];

  test('the curve starts at the start rating and ends on the current one', () {
    final curve = smoothCurve(climb);
    expect(curve.first.x, 0);
    expect(curve.first.y, kEloStart);
    expect(curve.last.x, 80);
    expect(curve.last.y, climb.last);
  });

  test('a long history is drawn as its trend, not match by match', () {
    expect(_turns(climb), 79);
    final curve = smoothCurve(climb).map((s) => s.y).toList();
    expect(_turns(curve), lessThanOrEqualTo(2), reason: 'at most a hook at either end');
    final low = climb.reduce((a, b) => a < b ? a : b), high = climb.reduce((a, b) => a > b ? a : b);
    expect(curve.every((y) => y >= low && y <= high), isTrue);
  });

  test('a short history keeps every rating, joined without bulging past them', () {
    const short = [kEloStart, 160.0, 158.0, 156.0, 230.0];
    final curve = smoothCurve(short);
    for (final (i, v) in short.indexed) {
      expect(curve.firstWhere((s) => s.x == i).y, closeTo(v, 1e-9));
    }
    expect(curve.where((s) => s.x >= 1).every((s) => s.y >= 156 - 1e-9), isTrue, reason: 'no dip before the jump');
    expect(curve.where((s) => s.x >= 1 && s.x <= 3).every((s) => s.y <= 160 + 1e-9), isTrue, reason: 'no bump above the first win');
    expect(curve.length, greaterThan(100), reason: 'finely sampled, so it looks round');
  });

  test('a single match draws a straight line', () {
    expect(smoothCurve([kEloStart, 160]).map((s) => (s.x, s.y)), [(0.0, kEloStart), (1.0, 160.0)]);
  });

  testWidgets('the profile chart draws one smooth line, with no dot per match', (tester) async {
    final points = [
      for (var i = 1; i < climb.length; i++) EloPoint(matchId: 'm$i', date: DateTime(2026, 1, 1).add(Duration(hours: i)), rating: climb[i], delta: climb[i] - climb[i - 1]),
    ];
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: EloHistoryChart(points: points))));
    await tester.pumpAndSettle();
    final bar = tester.widget<LineChart>(find.byType(LineChart)).data.lineBarsData.single;
    expect(bar.isCurved, isTrue);
    expect(bar.dotData.show, isFalse);
    expect(bar.spots.first.y, kEloStart);
    expect(bar.spots.last.y, climb.last);
  });
}
