import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../logic/time_format.dart';
import '../models/app_user.dart';
import '../models/game.dart';
import '../models/match.dart';
import '../state/app_state.dart';
import 'avatar.dart';
import 'match_card.dart';
import 'share_card_parts.dart';

export 'share_card_parts.dart' show kShareCardWidth, kShareImageWidth;

/// One player's line in the result, already placed (ties share a place).
class _Ranked {
  final String playerId;
  final String name;
  final String initial;
  final Color color;
  final String score;
  final int place;
  const _Ranked(this.playerId, this.name, this.initial, this.color, this.score, this.place);
}

/// A self-contained picture of one match's result, made to be shared as an
/// image (see showResultShareDialog): the game, where and when it was
/// played, the podium (or teams / the coop outcome), then — when the match
/// has them — the points per scoring category, the score-evolution chart
/// and the round-by-round table. Pass the whole series' [legs] for a "best
/// of N" series to show its score.
class ResultShareCard extends StatelessWidget {
  final Game game;
  final GameMatch match;
  final AppState appState;
  final List<GameMatch>? legs;

  const ResultShareCard({super.key, required this.game, required this.match, required this.appState, this.legs});

  /// Beyond this, the round table would be too long/wide for the image —
  /// the chart alone tells the story.
  static const _maxTableRounds = 12;
  static const _maxTablePlayers = 6;

  @override
  Widget build(BuildContext context) {
    final rounds = _rounds();
    final showChart = _timelineByPlayer().values.any((pts) => pts.length >= 2);
    final showRounds = match.resolvedInputMode == 'rounds' &&
        rounds.length >= 2 &&
        rounds.length <= _maxTableRounds &&
        match.entries.length <= _maxTablePlayers &&
        !match.isCoop;
    return ShareCardFrame(
      children: [
        _header(),
        const SizedBox(height: 12),
        if (match.isCoop) _coop() else if (match.isTeam) _teams() else _ffa(),
        if (match.hasScoreBreakdown && !match.isCoop) ShareSection(title: 'DÉTAIL DES POINTS', child: _categories()),
        if (showChart) ShareSection(title: 'ÉVOLUTION DES SCORES', child: _chart()),
        if (showRounds) ShareSection(title: 'MANCHES', child: _roundsTable(rounds)),
      ],
    );
  }

  String get _contextName {
    final salonId = match.salonId;
    if (salonId != null) return appState.salons.where((s) => s.id == salonId).firstOrNull?.name ?? '';
    return appState.groupById(match.groupId)?.name ?? '';
  }

  Widget _header() {
    final context = _contextName;
    final series = legs;
    final seriesLabel = series != null && series.length > 1 ? seriesResultLine(series, appState) : null;
    final rule = game.resolveRule(match.ruleId);
    return ShareCardHeader(
      emoji: game.emoji,
      title: game.name,
      subtitle: [
        if (context.isNotEmpty) context,
        '${frenchDayMonth(match.createdAt)} ${match.createdAt.year}',
        if (game.rules.length > 1) rule.name,
      ].join(' · '),
      pill: seriesLabel == null || seriesLabel.isEmpty ? null : 'Best of ${series!.first.seriesLength ?? series.length} · $seriesLabel',
    );
  }

  AppUser? _player(String id) => appState.playerById(id);
  String _name(String id) => _player(id)?.displayName ?? 'Joueur';
  Color _color(String id) {
    final p = _player(id);
    return p != null ? Color(p.color) : SharePalette.mut;
  }

  // ---------------------------------------------------------------- FFA

  /// Players in finishing order; tied scores share a place. A win/loss game
  /// has no score — winners first, then everyone else. A ranks game (e.g.
  /// Président) shows each player's role instead of points.
  List<_Ranked> _ranked() {
    final rule = game.resolveRule(match.ruleId);
    final winners = match.winnerIds().toSet();
    final entries = [...match.entries];
    int key(MatchEntry e) => rule.isWinLoss ? (winners.contains(e.playerId) ? 0 : 1) : (match.lowWins ? e.points : -e.points);
    entries.sort((a, b) => key(a).compareTo(key(b)));
    final out = <_Ranked>[];
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      final place = i > 0 && key(entries[i - 1]) == key(e) ? out[i - 1].place : i + 1;
      final score = rule.isWinLoss ? (winners.contains(e.playerId) ? 'Victoire' : '') : (e.role ?? (match.unit == 'time' ? formatDuration(e.points) : sharePts(e.points)));
      out.add(_Ranked(e.playerId, _name(e.playerId), _player(e.playerId)?.initial ?? '?', _color(e.playerId), score, place));
    }
    return out;
  }

  Widget _ffa() {
    final ranked = _ranked();
    final top = ranked.take(3).toList();
    final rest = ranked.skip(3).toList();
    // Display order 2nd, 1st, 3rd, like the in-app podium.
    final columns = [if (top.length > 1) top[1], top.first, if (top.length > 2) top[2]];
    return Column(
      children: [
        SizedBox(
          height: 206,
          // Shrinks rather than overflows with a larger system font.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.bottomCenter,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < columns.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  _podiumColumn(columns[i], slot: identical(columns[i], top.first) ? 1 : (identical(columns[i], top[1]) ? 2 : 3)),
                ],
              ],
            ),
          ),
        ),
        if (rest.isNotEmpty) ...[
          const SizedBox(height: 8),
          _restLine(rest),
        ],
      ],
    );
  }

  /// [slot] is the podium step (1 = center/tallest); the printed place can
  /// differ from it on a tie.
  Widget _podiumColumn(_Ranked r, {required int slot}) {
    const heights = {1: 74.0, 2: 54.0, 3: 38.0};
    final barColor = {1: SharePalette.accent, 2: SharePalette.ink, 3: SharePalette.bronze}[slot]!;
    return SizedBox(
      width: 96,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (r.place == 1) const Icon(Icons.emoji_events, color: SharePalette.gold, size: 20),
          const SizedBox(height: 2),
          Avatar(initial: r.initial, color: r.color, size: slot == 1 ? 50 : 42, fontSize: slot == 1 ? 20 : 17),
          const SizedBox(height: 5),
          Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: shareBodyFont(size: 12.5, weight: FontWeight.w800, color: SharePalette.ink)),
          Text(r.score.isEmpty ? ' ' : r.score,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: shareBodyFont(size: 11.5, weight: FontWeight.w700, color: SharePalette.mut)),
          const SizedBox(height: 5),
          Container(
            width: 96,
            height: heights[slot],
            alignment: Alignment.topCenter,
            padding: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(color: barColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
            child: Text('${r.place}', style: shareDispFont(size: 20, weight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _restLine(List<_Ranked> rest) {
    const shown = 3;
    final parts = [for (final r in rest.take(shown)) '${r.place}. ${r.name}${r.score.isNotEmpty ? ' · ${r.score}' : ''}'];
    if (rest.length > shown) parts.add('+${rest.length - shown}');
    return Text(
      parts.join('   '),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: shareBodyFont(size: 11.5, weight: FontWeight.w700, color: SharePalette.mut),
    );
  }

  // ---------------------------------------------------------------- teams

  Widget _teams() {
    final winners = match.winnerIds().toSet();
    final totals = <String, int>{};
    final members = <String, List<String>>{};
    for (final e in match.entries) {
      final t = e.teamId ?? 'A';
      totals[t] = (totals[t] ?? 0) + e.points;
      members.putIfAbsent(t, () => []).add(_name(e.playerId));
    }
    bool won(String t) => match.entries.any((e) => (e.teamId ?? 'A') == t && winners.contains(e.playerId));
    final teams = totals.keys.toList()
      ..sort((a, b) {
        if (won(a) != won(b)) return won(a) ? -1 : 1;
        return match.lowWins ? totals[a]!.compareTo(totals[b]!) : totals[b]!.compareTo(totals[a]!);
      });
    final showScores = !game.resolveRule(match.ruleId).isWinLoss;
    return Column(
      children: [
        for (final t in teams)
          Container(
            margin: const EdgeInsets.only(bottom: 7),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: SharePalette.card,
              border: Border.all(color: won(t) ? SharePalette.accent : SharePalette.line, width: won(t) ? 2 : 1.5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                if (won(t)) ...[const Icon(Icons.emoji_events, color: SharePalette.gold, size: 18), const SizedBox(width: 6)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Équipe $t', style: shareBodyFont(size: 13.5, weight: FontWeight.w800, color: SharePalette.ink)),
                      Text(members[t]!.join(', '),
                          maxLines: 2, overflow: TextOverflow.ellipsis, style: shareBodyFont(size: 11.5, weight: FontWeight.w700, color: SharePalette.mut)),
                    ],
                  ),
                ),
                if (showScores)
                  Text(sharePts(totals[t]!), style: shareDispFont(size: 17, weight: FontWeight.w800, color: won(t) ? SharePalette.accent : SharePalette.ink)),
              ],
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------- coop

  Widget _coop() {
    final won = match.winnerIds().isNotEmpty;
    final rule = game.resolveRule(match.ruleId);
    final score = match.entries.firstOrNull?.points;
    final showScore = !rule.isWinLoss && match.unit != 'wins' && score != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        children: [
          Text(won ? '🎉' : '😔', style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 6),
          Text(won ? 'Victoire collective' : 'Défaite collective',
              style: shareDispFont(size: 24, weight: FontWeight.w800, color: won ? SharePalette.accent : SharePalette.ink)),
          if (showScore) Text('Score du groupe : ${sharePts(score)}', style: shareBodyFont(size: 13, weight: FontWeight.w700, color: SharePalette.mut)),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final e in match.entries.take(12))
                Avatar(initial: _player(e.playerId)?.initial ?? '?', color: _color(e.playerId), size: 34, fontSize: 14),
            ],
          ),
          if (match.entries.length > 12) Text('+${match.entries.length - 12}', style: shareBodyFont(size: 11.5, weight: FontWeight.w700, color: SharePalette.mut)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- categories

  /// Points per scoring category (e.g. 7 Wonders' military, science…), one
  /// column per player in finishing order.
  Widget _categories() {
    final ranked = _ranked().take(_maxTablePlayers).toList();
    final byPlayer = {for (final e in match.entries) e.playerId: e};
    final fields = match.scoreFields ?? const [];
    final rows = <({String label, Color? color, String id})>[
      if (fields.isNotEmpty)
        for (final f in fields) (label: f.label, color: Color(f.color), id: f.id)
      else
        for (final key in {for (final e in match.entries) ...?e.scoreBreakdown?.keys}) (label: key, color: null, id: key),
    ];
    Widget cell(String s, {bool bold = false}) => SizedBox(
          width: 40,
          child: Text(s,
              textAlign: TextAlign.center,
              maxLines: 1,
              style: shareBodyFont(size: 11.5, weight: bold ? FontWeight.w800 : FontWeight.w700, color: bold ? SharePalette.ink : SharePalette.ink2)),
        );
    return Column(
      children: [
        Row(
          children: [
            const Expanded(child: SizedBox()),
            for (final r in ranked) SizedBox(width: 40, child: Center(child: Avatar(initial: r.initial, color: r.color, size: 22, fontSize: 10))),
          ],
        ),
        const SizedBox(height: 6),
        for (final (i, row) in rows.indexed)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(color: i.isEven ? SharePalette.bg : null, borderRadius: BorderRadius.circular(6)),
            child: Row(
              children: [
                const SizedBox(width: 4),
                if (row.color != null) ...[
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: row.color, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(row.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: shareBodyFont(size: 11.5, weight: FontWeight.w700, color: SharePalette.ink2)),
                ),
                for (final r in ranked) cell('${byPlayer[r.playerId]?.scoreBreakdown?[row.id] ?? 0}'),
              ],
            ),
          ),
        const Divider(height: 12, color: SharePalette.line),
        Row(
          children: [
            const SizedBox(width: 4),
            Expanded(child: Text('Total', style: shareBodyFont(size: 12, weight: FontWeight.w800, color: SharePalette.ink))),
            for (final r in ranked) cell('${byPlayer[r.playerId]?.points ?? 0}', bold: true),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- chart

  Map<String, List<TimelinePoint>> _timelineByPlayer() {
    final byPlayer = <String, List<TimelinePoint>>{};
    for (final t in match.timeline) {
      byPlayer.putIfAbsent(t.playerId, () => []).add(t);
    }
    return byPlayer;
  }

  /// Each player's line in their own avatar color, unless another player
  /// already took it.
  Map<String, Color> _lineColors(Iterable<String> playerIds) {
    const spare = [Color(0xFF5B4BE8), Color(0xFF1F9D57), Color(0xFFE8A93B), Color(0xFFE5537B), Color(0xFF2AA8B0), Color(0xFF18171C)];
    final used = <int>{};
    final out = <String, Color>{};
    var s = 0;
    for (final id in playerIds) {
      var c = _color(id);
      if (!used.add(c.toARGB32())) {
        while (s < spare.length - 1 && used.contains(spare[s].toARGB32())) {
          s++;
        }
        c = spare[s];
        used.add(c.toARGB32());
      }
      out[id] = c;
    }
    return out;
  }

  /// Cumulative score per player across the match — a static version of the
  /// in-app ScoreEvolutionChart (no animation, fixed light palette).
  Widget _chart() {
    final byPlayer = _timelineByPlayer();
    final colors = _lineColors(byPlayer.keys);
    var maxY = 0.0, minY = 0.0, maxX = 0.0;
    final allSpots = <String, List<FlSpot>>{};
    for (final entry in byPlayer.entries) {
      final spots = [const FlSpot(0, 0), for (final (i, p) in entry.value.indexed) FlSpot((i + 1).toDouble(), p.val.toDouble())];
      for (final s in spots) {
        if (s.y > maxY) maxY = s.y;
        if (s.y < minY) minY = s.y;
        if (s.x > maxX) maxX = s.x;
      }
      allSpots[entry.key] = spots;
    }
    final bars = [
      for (final entry in allSpots.entries)
        LineChartBarData(
          spots: entry.value,
          color: colors[entry.key],
          barWidth: 2.5,
          dotData: FlDotData(show: maxX <= 15),
          belowBarData: BarAreaData(show: false),
        ),
    ];
    final xInterval = maxX <= 12 ? 1.0 : (maxX / 6).ceilToDouble();
    TextStyle axis() => shareBodyFont(size: 9.5, weight: FontWeight.w600, color: SharePalette.mut);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 150,
          child: LineChart(
            duration: Duration.zero,
            LineChartData(
              minY: minY,
              maxY: maxY == minY ? maxY + 1 : maxY,
              minX: 0,
              maxX: maxX,
              lineBarsData: bars,
              gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => const FlLine(color: SharePalette.line, strokeWidth: 1)),
              borderData: FlBorderData(show: false),
              lineTouchData: const LineTouchData(enabled: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, getTitlesWidget: (v, _) => Text('${v.toInt()}', style: axis()))),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: xInterval,
                    getTitlesWidget: (v, _) => v == 0 ? const SizedBox.shrink() : Text('${v.toInt()}', style: axis()),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            for (final id in byPlayer.keys)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 10, height: 3, color: colors[id]),
                  const SizedBox(width: 5),
                  Text(_name(id), style: shareBodyFont(size: 11, weight: FontWeight.w700, color: SharePalette.ink2)),
                ],
              ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- rounds

  /// The timeline cut into rounds — one point per player per round, same
  /// as the match detail screen's round table.
  List<List<TimelinePoint>> _rounds() {
    final n = match.entries.length;
    if (n == 0) return const [];
    return [for (var i = 0; i < match.timeline.length; i += n) match.timeline.sublist(i, (i + n).clamp(0, match.timeline.length))];
  }

  Widget _roundsTable(List<List<TimelinePoint>> rounds) {
    final playerIds = rounds.first.map((t) => t.playerId).toList();
    Widget cell(String s, {bool bold = false}) => Expanded(
          child: Text(s,
              textAlign: TextAlign.center,
              style: shareBodyFont(size: 11.5, weight: bold ? FontWeight.w800 : FontWeight.w700, color: bold ? SharePalette.ink : SharePalette.ink2)),
        );
    return Column(
      children: [
        Row(
          children: [
            const SizedBox(width: 36),
            for (final id in playerIds)
              Expanded(child: Center(child: Avatar(initial: _player(id)?.initial ?? '?', color: _color(id), size: 22, fontSize: 10))),
          ],
        ),
        const SizedBox(height: 6),
        for (final (i, round) in rounds.indexed)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 3),
            decoration: BoxDecoration(color: i.isEven ? SharePalette.bg : null, borderRadius: BorderRadius.circular(6)),
            child: Row(
              children: [
                SizedBox(width: 36, child: Text('M${i + 1}', style: shareBodyFont(size: 11, weight: FontWeight.w700, color: SharePalette.mut))),
                for (final id in playerIds)
                  Builder(builder: (_) {
                    final t = round.where((e) => e.playerId == id);
                    final d = t.isEmpty ? 0 : t.first.delta;
                    return cell('${d >= 0 ? '+' : ''}$d');
                  }),
              ],
            ),
          ),
        const Divider(height: 12, color: SharePalette.line),
        Row(
          children: [
            SizedBox(width: 36, child: Text('Total', style: shareBodyFont(size: 11, weight: FontWeight.w800, color: SharePalette.ink))),
            for (final id in playerIds) cell('${match.entries.where((e) => e.playerId == id).firstOrNull?.points ?? 0}', bold: true),
          ],
        ),
      ],
    );
  }
}
