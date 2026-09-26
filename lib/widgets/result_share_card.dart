import 'package:flutter/material.dart';

import '../models/game.dart';
import '../models/match.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'avatar.dart';
import 'match_card.dart';

/// Logical side of [ResultShareCard]; rendered at 3× for a 1080×1080 image.
const kShareCardSize = 360.0;

/// Fixed light palette — the shared image looks the same whatever theme the
/// sharer uses (see [AppColors] for the in-app, theme-dependent tokens).
class _Palette {
  static const bg = Color(0xFFF4F2EC);
  static const card = Color(0xFFFFFFFF);
  static const ink = Color(0xFF18171C);
  static const mut = Color(0xFF8C8A93);
  static const line = Color(0x14181713);
  static const bronze = Color(0xFFB8B3A6);
  static const gold = Color(0xFFE8A93B);
}

/// One player's line in the result, already placed (ties share a place).
class _Ranked {
  final String name;
  final String initial;
  final Color color;
  final String score;
  final int place;
  const _Ranked(this.name, this.initial, this.color, this.score, this.place);
}

/// A square, self-contained picture of one match's result — the game, where
/// and when it was played, the podium (or teams / the coop outcome) and a
/// "Podium" footer — made to be shared as an image (see
/// ResultSharePreviewDialog). Pass the whole series' [legs] for a "best of
/// N" series to show its score.
class ResultShareCard extends StatelessWidget {
  final Game game;
  final GameMatch match;
  final AppState appState;
  final List<GameMatch>? legs;

  const ResultShareCard({super.key, required this.game, required this.match, required this.appState, this.legs});

  Color get _accent => accentPreviewColor(AppColors.accentPreset);

  static String _pts(int n) => n.abs() <= 1 ? '$n pt' : '$n pts';

  @override
  Widget build(BuildContext context) {
    // Its own Material, so text never picks up the "no Material ancestor"
    // debug style wherever the card is rendered from.
    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: kShareCardSize,
        height: kShareCardSize,
        color: _Palette.bg,
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(),
            const SizedBox(height: 12),
            Expanded(child: match.isCoop ? _coop() : (match.isTeam ? _teams() : _ffa())),
            const SizedBox(height: 10),
            _footer(),
          ],
        ),
      ),
    );
  }

  String get _contextName {
    final salonId = match.salonId;
    if (salonId != null) return appState.salons.where((s) => s.id == salonId).firstOrNull?.name ?? '';
    return appState.groupById(match.groupId)?.name ?? '';
  }

  String get _dateLabel => '${frenchDayMonth(match.createdAt)} ${match.createdAt.year}';

  Widget _header() {
    final context = _contextName;
    final series = legs;
    final seriesLabel = series != null && series.length > 1 ? seriesResultLine(series, appState) : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(game.emoji, style: const TextStyle(fontSize: 30)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(game.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: dispFont(size: 22, weight: FontWeight.w800, color: _Palette.ink, letterSpacing: -0.3)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          [if (context.isNotEmpty) context, _dateLabel].join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: bodyFont(size: 12.5, weight: FontWeight.w700, color: _Palette.mut),
        ),
        if (seriesLabel != null && seriesLabel.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(color: _accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: Text('Best of ${series!.first.seriesLength ?? series.length} · $seriesLabel',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyFont(size: 11.5, weight: FontWeight.w800, color: _accent)),
          ),
        ],
      ],
    );
  }

  Widget _footer() {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(7)),
          child: const Icon(Icons.emoji_events_rounded, size: 14, color: Colors.white),
        ),
        const SizedBox(width: 7),
        Text('Podium', style: dispFont(size: 15, weight: FontWeight.w800, color: _Palette.ink)),
        const SizedBox(width: 12),
        Expanded(
          child: Text('Disponible sur Google Play',
              textAlign: TextAlign.end, maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyFont(size: 10.5, weight: FontWeight.w700, color: _Palette.mut)),
        ),
      ],
    );
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
      final p = appState.playerById(e.playerId);
      final score = rule.isWinLoss ? (winners.contains(e.playerId) ? 'Victoire' : '') : (e.role ?? _pts(e.points));
      out.add(_Ranked(p?.displayName ?? 'Joueur', p?.initial ?? '?', p != null ? Color(p.color) : _Palette.mut, score, place));
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
        Expanded(
          // Shrinks rather than overflows when the header takes more room
          // (a series badge) or the system font is larger.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.bottomCenter,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < columns.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  _podiumColumn(columns[i], slot: columns[i] == top.first ? 1 : (columns[i] == top[1] ? 2 : 3)),
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
    final barColor = {1: _accent, 2: _Palette.ink, 3: _Palette.bronze}[slot]!;
    return SizedBox(
      width: 96,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (r.place == 1) const Icon(Icons.emoji_events, color: _Palette.gold, size: 20),
          const SizedBox(height: 2),
          Avatar(initial: r.initial, color: r.color, size: slot == 1 ? 50 : 42, fontSize: slot == 1 ? 20 : 17),
          const SizedBox(height: 5),
          Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyFont(size: 12.5, weight: FontWeight.w800, color: _Palette.ink)),
          Text(r.score.isEmpty ? ' ' : r.score,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyFont(size: 11.5, weight: FontWeight.w700, color: _Palette.mut)),
          const SizedBox(height: 5),
          Container(
            height: heights[slot],
            alignment: Alignment.topCenter,
            padding: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(color: barColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
            child: Text('${r.place}', style: dispFont(size: 20, weight: FontWeight.w700, color: Colors.white)),
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
      style: bodyFont(size: 11.5, weight: FontWeight.w700, color: _Palette.mut),
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
      members.putIfAbsent(t, () => []).add(appState.playerById(e.playerId)?.displayName ?? 'Joueur');
    }
    bool won(String t) => match.entries.any((e) => (e.teamId ?? 'A') == t && winners.contains(e.playerId));
    final teams = totals.keys.toList()
      ..sort((a, b) {
        if (won(a) != won(b)) return won(a) ? -1 : 1;
        return match.lowWins ? totals[a]!.compareTo(totals[b]!) : totals[b]!.compareTo(totals[a]!);
      });
    final showScores = !game.resolveRule(match.ruleId).isWinLoss;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final t in teams.take(4))
          Container(
            margin: const EdgeInsets.only(bottom: 7),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: teams.length > 2 ? 7 : 11),
            decoration: BoxDecoration(
              color: _Palette.card,
              border: Border.all(color: won(t) ? _accent : _Palette.line, width: won(t) ? 2 : 1.5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                if (won(t)) ...[const Icon(Icons.emoji_events, color: _Palette.gold, size: 18), const SizedBox(width: 6)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Équipe $t', style: bodyFont(size: 13.5, weight: FontWeight.w800, color: _Palette.ink)),
                      Text(members[t]!.join(', '),
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyFont(size: 11.5, weight: FontWeight.w700, color: _Palette.mut)),
                    ],
                  ),
                ),
                if (showScores) Text(_pts(totals[t]!), style: dispFont(size: 17, weight: FontWeight.w800, color: won(t) ? _accent : _Palette.ink)),
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
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(won ? '🎉' : '😔', style: const TextStyle(fontSize: 40)),
        const SizedBox(height: 6),
        Text(won ? 'Victoire collective' : 'Défaite collective', style: dispFont(size: 24, weight: FontWeight.w800, color: won ? _accent : _Palette.ink)),
        if (showScore) Text('Score du groupe : ${_pts(score)}', style: bodyFont(size: 13, weight: FontWeight.w700, color: _Palette.mut)),
        const SizedBox(height: 14),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final e in match.entries.take(10))
              Builder(builder: (_) {
                final p = appState.playerById(e.playerId);
                return Avatar(initial: p?.initial ?? '?', color: p != null ? Color(p.color) : _Palette.mut, size: 34, fontSize: 14);
              }),
          ],
        ),
        if (match.entries.length > 10) Text('+${match.entries.length - 10}', style: bodyFont(size: 11.5, weight: FontWeight.w700, color: _Palette.mut)),
      ],
    );
  }
}
