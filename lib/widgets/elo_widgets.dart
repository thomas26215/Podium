import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../logic/elo.dart';
import '../theme/app_theme.dart';
import 'common.dart';
import 'match_card.dart' show frenchDayMonth;

/// "+14 Elo" / "−9 Elo" / "±0 Elo" — how much a match (or a set of legs)
/// moved a player's group rating.
class EloDeltaChip extends StatelessWidget {
  final double delta;
  final bool withUnit;
  const EloDeltaChip({super.key, required this.delta, this.withUnit = true});

  @override
  Widget build(BuildContext context) {
    final d = delta.round();
    final color = d > 0 ? AppColors.green : (d < 0 ? Colors.red : AppColors.mut);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(
        '${d > 0 ? '+' : (d < 0 ? '−' : '±')}${d.abs()}${withUnit ? ' Elo' : ''}',
        style: bodyFont(size: 10.5, weight: FontWeight.w800, color: color),
      ),
    );
  }
}

/// A rating band's colored pill — "◆ Or".
class EloTierBadge extends StatelessWidget {
  final EloTier tier;
  final double fontSize;
  const EloTierBadge({super.key, required this.tier, this.fontSize = 10.5});

  @override
  Widget build(BuildContext context) {
    final color = Color(tier.color);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: fontSize * 0.7, vertical: fontSize * 0.2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
      child: Text('◆ ${tier.name}', style: bodyFont(size: fontSize, weight: FontWeight.w800, color: color)),
    );
  }
}

/// A player's rating after each rated match, oldest to newest, with the
/// tier thresholds it crosses drawn as faint lines. Touching a point shows
/// the rating, the change and the date.
class EloHistoryChart extends StatefulWidget {
  final List<EloPoint> points; // oldest first
  const EloHistoryChart({super.key, required this.points});

  @override
  State<EloHistoryChart> createState() => _EloHistoryChartState();
}

class _EloHistoryChartState extends State<EloHistoryChart> {
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _revealed = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    // The start rating comes first, so a single match already draws a line.
    final points = widget.points;
    if (points.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(child: Text('La courbe apparaîtra après la première partie comptée.', textAlign: TextAlign.center, style: bodyFont(size: 12.5, weight: FontWeight.w600, color: AppColors.mut))),
      );
    }
    final values = [kEloStart, ...points.map((p) => p.rating)];
    var minY = values.reduce((a, b) => a < b ? a : b);
    var maxY = values.reduce((a, b) => a > b ? a : b);
    final pad = maxY == minY ? 50.0 : (maxY - minY) * 0.12;
    minY = (minY - pad).clamp(0, double.infinity);
    maxY += pad;
    final mid = (minY + maxY) / 2;
    final spots = [for (final (i, v) in values.indexed) FlSpot(i.toDouble(), _revealed ? v : mid)];
    final accent = AppColors.accent;
    final thresholds = kEloTiers.where((t) => t.min > minY && t.min < maxY).toList();

    return FadeSlideIn(
      offsetY: 8,
      child: SizedBox(
        height: 190,
        child: LineChart(
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
          LineChartData(
            minX: 0,
            maxX: (values.length - 1).toDouble(),
            minY: minY,
            maxY: maxY,
            extraLinesData: ExtraLinesData(horizontalLines: [
              for (final t in thresholds)
                HorizontalLine(
                  y: t.min,
                  color: Color(t.color).withValues(alpha: 0.45),
                  strokeWidth: 1,
                  dashArray: [4, 4],
                  label: HorizontalLineLabel(
                    show: true,
                    alignment: Alignment.topRight,
                    style: bodyFont(size: 9.5, weight: FontWeight.w800, color: Color(t.color)),
                    labelResolver: (_) => t.name,
                  ),
                ),
            ]),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: false,
                color: accent,
                barWidth: 2,
                belowBarData: BarAreaData(show: true, color: accent.withValues(alpha: 0.08)),
                dotData: FlDotData(show: values.length <= 40),
              ),
            ],
            gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: AppColors.line, strokeWidth: 1)),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 38,
                  getTitlesWidget: (v, meta) => (v == meta.min || v == meta.max)
                      ? const SizedBox.shrink()
                      : Text('${v.round()}', style: bodyFont(size: 10, weight: FontWeight.w600, color: AppColors.mut)),
                ),
              ),
            ),
            lineTouchData: LineTouchData(
              enabled: true,
              touchSpotThreshold: 24,
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => AppColors.ink,
                getTooltipItems: (spots) => [
                  for (final s in spots)
                    () {
                      final i = s.x.toInt();
                      if (i == 0) return LineTooltipItem('${kEloStart.round()}\nDépart', bodyFont(size: 12.5, weight: FontWeight.w800, color: Colors.white));
                      final p = points[i - 1];
                      final d = p.delta.round();
                      return LineTooltipItem(
                        '${p.rating.round()}\n',
                        bodyFont(size: 12.5, weight: FontWeight.w800, color: Colors.white),
                        children: [
                          TextSpan(
                            text: '${d >= 0 ? '+' : '−'}${d.abs()} · ${frenchDayMonth(p.date)}',
                            style: bodyFont(size: 11, weight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.75)),
                          ),
                        ],
                      );
                    }(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
