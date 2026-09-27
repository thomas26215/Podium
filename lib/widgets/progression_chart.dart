import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../logic/personal_records.dart';
import '../logic/time_format.dart';
import '../theme/app_theme.dart';
import 'common.dart';
import 'match_card.dart' show frenchDayMonth;

/// One player's results on one game and rule, oldest to newest — a single
/// line (so no legend: the screen's title names it), each attempt a dot,
/// the ones that beat the record at the time drawn larger (see
/// [SoloAttempt.wasRecord]). Touching a dot shows its value and date.
class ProgressionChart extends StatefulWidget {
  final List<SoloAttempt> attempts; // oldest first
  const ProgressionChart({super.key, required this.attempts});

  @override
  State<ProgressionChart> createState() => _ProgressionChartState();
}

class _ProgressionChartState extends State<ProgressionChart> {
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _revealed = true);
    });
  }

  String _label(num v, String unit) => unit == 'time' ? formatDuration(v.round()) : '${v.round()}';

  /// Axis ticks for a time only need the minutes and seconds — "1:52".
  String _axisLabel(num v, String unit) {
    if (unit != 'time') return '${v.round()}';
    final full = formatDuration(v.round());
    return full.substring(0, full.lastIndexOf('.'));
  }

  @override
  Widget build(BuildContext context) {
    final attempts = widget.attempts;
    if (attempts.length < 2) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text('La courbe apparaîtra dès votre deuxième partie.', textAlign: TextAlign.center, style: bodyFont(size: 12.5, weight: FontWeight.w600, color: AppColors.mut)),
        ),
      );
    }
    final unit = attempts.first.unit;
    final values = attempts.map((a) => a.value.toDouble()).toList();
    var minY = values.reduce((a, b) => a < b ? a : b);
    var maxY = values.reduce((a, b) => a > b ? a : b);
    final pad = maxY == minY ? (maxY == 0 ? 1 : maxY * 0.05) : (maxY - minY) * 0.12;
    minY -= pad;
    maxY += pad;
    if (unit != 'time' && minY < 0 && values.every((v) => v >= 0)) minY = 0;
    final mid = (minY + maxY) / 2;
    final spots = [for (final (i, v) in values.indexed) FlSpot(i.toDouble(), _revealed ? v : mid)];
    final accent = AppColors.accent;

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
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: false,
                color: accent,
                barWidth: 2,
                belowBarData: BarAreaData(show: false),
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, _, _, i) {
                    final record = attempts[i].wasRecord;
                    return FlDotCirclePainter(
                      radius: record ? 5.5 : 4,
                      color: record ? accent : AppColors.card,
                      strokeWidth: 2,
                      strokeColor: record ? AppColors.card : accent,
                    );
                  },
                ),
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
                  reservedSize: unit == 'time' ? 44 : 34,
                  getTitlesWidget: (v, meta) => (v == meta.min || v == meta.max)
                      ? const SizedBox.shrink()
                      : Text(_axisLabel(v, unit), style: bodyFont(size: 10, weight: FontWeight.w600, color: AppColors.mut)),
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
                    LineTooltipItem(
                      '${_label(values[s.x.toInt()], unit)}\n',
                      bodyFont(size: 12.5, weight: FontWeight.w800, color: Colors.white),
                      children: [
                        TextSpan(
                          text: '${frenchDayMonth(attempts[s.x.toInt()].match.createdAt)}${attempts[s.x.toInt()].wasRecord ? ' · record' : ''}',
                          style: bodyFont(size: 11, weight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.75)),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
