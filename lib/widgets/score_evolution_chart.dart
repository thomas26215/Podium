import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/match.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

/// Line chart of each player's cumulative score across rounds, built
/// straight from a match's (or in-progress draft's) `timeline` — works for
/// both "rounds" and "live" input modes, since both append one
/// `TimelinePoint` per score change with a running cumulative `val`.
class ScoreEvolutionChart extends StatelessWidget {
  final List<TimelinePoint> timeline;
  final AppState appState;
  const ScoreEvolutionChart({super.key, required this.timeline, required this.appState});

  @override
  Widget build(BuildContext context) {
    final byPlayer = <String, List<TimelinePoint>>{};
    for (final t in timeline) {
      byPlayer.putIfAbsent(t.playerId, () => []).add(t);
    }
    if (byPlayer.values.every((pts) => pts.length < 2)) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(child: Text('Au moins 2 manches sont nécessaires pour afficher le graphique.', textAlign: TextAlign.center, style: bodyFont(size: 12.5, weight: FontWeight.w600, color: AppColors.mut))),
      );
    }

    final colors = [AppColors.accent, AppColors.green, AppColors.gold, const Color(0xFF5B4BE8), const Color(0xFFE5537B)];
    var maxY = 0.0, minY = 0.0, maxX = 0.0;
    final bars = <LineChartBarData>[];
    var ci = 0;
    for (final entry in byPlayer.entries) {
      final pts = entry.value;
      final spots = [
        const FlSpot(0, 0),
        for (final (i, p) in pts.indexed) FlSpot((i + 1).toDouble(), p.val.toDouble()),
      ];
      for (final s in spots) {
        if (s.y > maxY) maxY = s.y;
        if (s.y < minY) minY = s.y;
        if (s.x > maxX) maxX = s.x;
      }
      final color = colors[ci % colors.length];
      ci++;
      bars.add(LineChartBarData(
        spots: spots,
        isCurved: false,
        color: color,
        barWidth: 2.5,
        dotData: const FlDotData(show: true),
        belowBarData: BarAreaData(show: false),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 180,
          child: LineChart(
            LineChartData(
              minY: minY,
              maxY: maxY == minY ? maxY + 1 : maxY,
              minX: 0,
              maxX: maxX,
              lineBarsData: bars,
              gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: AppColors.line, strokeWidth: 1)),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32, getTitlesWidget: (v, _) => Text('${v.toInt()}', style: bodyFont(size: 10, weight: FontWeight.w600, color: AppColors.mut)))),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    getTitlesWidget: (v, _) => v == 0 ? const SizedBox.shrink() : Text('${v.toInt()}', style: bodyFont(size: 10, weight: FontWeight.w600, color: AppColors.mut)),
                  ),
                ),
              ),
              lineTouchData: const LineTouchData(enabled: true),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            for (final (i, uid) in byPlayer.keys.indexed)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: colors[i % colors.length], shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(appState.playerById(uid)?.displayName ?? '?', style: bodyFont(size: 12, weight: FontWeight.w700, color: AppColors.ink2)),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
