import 'package:flutter/material.dart';

import '../logic/tournament_bracket.dart';
import '../models/game.dart';
import '../models/match.dart';
import '../models/tournament.dart';
import '../state/app_state.dart';
import 'match_card.dart';
import 'share_card_parts.dart';

/// A picture of a whole tournament, made to be shared as an image (see
/// showTournamentShareDialog): its name, game and format, the champion and
/// finalist once it's over (or how far along it is), each group's standings
/// and the elimination rounds from the final backwards, with every played
/// match's score.
class TournamentShareCard extends StatelessWidget {
  final Tournament tournament;
  final Game? game;
  final AppState appState;
  const TournamentShareCard({super.key, required this.tournament, required this.game, required this.appState});

  /// Match lines shown across the elimination rounds; earlier rounds beyond
  /// this are summed up in one line, to keep a 32-player bracket readable.
  static const _maxBracketLines = 14;

  @override
  Widget build(BuildContext context) {
    final t = tournament;
    final groupsDone = t.matches.any((m) => m.bracket == 'group');
    return ShareCardFrame(
      children: [
        ShareCardHeader(
          emoji: '🏆',
          title: t.name,
          subtitle: [
            if (game != null) '${game!.emoji} ${game!.name}',
            if (_contextName.isNotEmpty) _contextName,
            '${frenchDayMonth(t.createdAt)} ${t.createdAt.year}',
          ].join(' · '),
          pill: '${_formatLabel(t.format)} · ${t.entrants.length} participants',
        ),
        const SizedBox(height: 12),
        _outcome(),
        if (groupsDone)
          for (var g = 0; g < t.groupsCount; g++) ShareSection(title: 'POULE ${g + 1}', child: _groupStandings(g)),
        ..._eliminationSections(),
      ],
    );
  }

  String get _contextName {
    final salonId = tournament.salonId;
    if (salonId != null) return appState.salons.where((s) => s.id == salonId).firstOrNull?.name ?? '';
    return appState.groupById(tournament.groupId)?.name ?? '';
  }

  String _label(String? entrantId) {
    final e = tournament.entrantById(entrantId);
    if (e == null) return 'À déterminer';
    if (e.label != null) return e.label!;
    return e.playerIds.map((id) => appState.playerById(id)?.displayName.split(' ').first ?? '?').join(' & ');
  }

  /// The tournament's very last match: the grand final of a double
  /// elimination, otherwise the last winners-bracket round.
  BracketMatch? get _lastMatch {
    final grand = tournament.matches.where((m) => m.bracket == 'final').firstOrNull;
    if (grand != null) return grand;
    final winners = tournament.matches.where((m) => m.bracket == 'winners').toList();
    if (winners.isEmpty) return null;
    winners.sort((a, b) => b.round.compareTo(a.round));
    return winners.first;
  }

  Widget _outcome() {
    final t = tournament;
    if (t.isCompleted) {
      final last = _lastMatch;
      final finalistId = last == null ? null : (last.winnerId == last.entrantAId ? last.entrantBId : last.entrantAId);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(color: SharePalette.ink, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            const Icon(Icons.emoji_events, color: SharePalette.gold, size: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CHAMPION', style: shareBodyFont(size: 10.5, weight: FontWeight.w800, color: SharePalette.gold, letterSpacing: 0.8)),
                  Text(_label(t.winnerEntrantId),
                      maxLines: 2, overflow: TextOverflow.ellipsis, style: shareDispFont(size: 22, weight: FontWeight.w800, color: Colors.white)),
                  if (finalistId != null)
                    Text('Finaliste : ${_label(finalistId)}',
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: shareBodyFont(size: 12, weight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.65))),
                ],
              ),
            ),
          ],
        ),
      );
    }
    final playable = t.matches.where((m) => !m.bye);
    final done = playable.where((m) => m.isDone).length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: SharePalette.card, border: Border.all(color: SharePalette.line, width: 1.5), borderRadius: BorderRadius.circular(14)),
      child: Text(
        t.isPending ? 'En préparation' : 'En cours · $done/${playable.length} matchs joués',
        style: shareBodyFont(size: 13.5, weight: FontWeight.w800, color: SharePalette.ink),
      ),
    );
  }

  Widget _groupStandings(int groupIndex) {
    final standings = computeGroupStandings(tournament: tournament, groupIndex: groupIndex, playedMatches: appState.matches);
    final qualifiers = tournament.qualifiersPerGroup;
    return Column(
      children: [
        for (final (i, s) in standings.indexed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                SizedBox(width: 18, child: Text('${i + 1}', style: shareBodyFont(size: 12, weight: FontWeight.w700, color: SharePalette.mut))),
                Expanded(
                  child: Text(_label(s.entrantId),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: shareBodyFont(size: 12.5, weight: i < qualifiers ? FontWeight.w800 : FontWeight.w700, color: i < qualifiers ? SharePalette.ink : SharePalette.ink2)),
                ),
                Text('${s.wins} V', style: shareBodyFont(size: 12, weight: FontWeight.w700, color: SharePalette.ink2)),
                const SizedBox(width: 10),
                SizedBox(
                  width: 34,
                  child: Text('${s.diff >= 0 ? '+' : ''}${s.diff}', textAlign: TextAlign.end, style: shareBodyFont(size: 12, weight: FontWeight.w600, color: SharePalette.mut)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Grand final, then the winners bracket from its final backwards, then a
  /// one-line summary of the losers bracket (double elimination).
  List<Widget> _eliminationSections() {
    final t = tournament;
    final grand = t.matches.where((m) => m.bracket == 'final' && !m.isVoid).firstOrNull;
    final winners = t.matches.where((m) => m.bracket == 'winners' && !m.bye && !m.isVoid).toList();
    final losers = t.matches.where((m) => m.bracket == 'losers' && !m.bye && !m.isVoid).toList();
    final rounds = <int, List<BracketMatch>>{};
    for (final m in winners) {
      rounds.putIfAbsent(m.round, () => []).add(m);
    }
    final roundNumbers = rounds.keys.toList()..sort((a, b) => b.compareTo(a));

    final out = <Widget>[];
    if (grand != null) out.add(ShareSection(title: 'GRANDE FINALE', child: _matchLine(grand)));
    var lines = 0;
    var hiddenMatches = 0;
    for (final (i, r) in roundNumbers.indexed) {
      final ms = rounds[r]!..sort((a, b) => a.position.compareTo(b.position));
      if (lines + ms.length > _maxBracketLines && lines > 0) {
        hiddenMatches += ms.length;
        continue;
      }
      lines += ms.length;
      out.add(ShareSection(
        title: _roundName(i, hasGrandFinal: grand != null).toUpperCase(),
        child: Column(children: [for (final m in ms) _matchLine(m)]),
      ));
    }
    if (hiddenMatches > 0) {
      out.add(Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text('+ $hiddenMatches match${hiddenMatches > 1 ? 's' : ''} des tours précédents',
            textAlign: TextAlign.center, style: shareBodyFont(size: 11.5, weight: FontWeight.w700, color: SharePalette.mut)),
      ));
    }
    if (losers.isNotEmpty) {
      final played = losers.where((m) => m.isDone).length;
      out.add(Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text('Tableau des perdants : $played/${losers.length} matchs joués',
            textAlign: TextAlign.center, style: shareBodyFont(size: 11.5, weight: FontWeight.w700, color: SharePalette.mut)),
      ));
    }
    return out;
  }

  /// [fromLast] counts rounds back from the winners bracket's last one.
  String _roundName(int fromLast, {required bool hasGrandFinal}) {
    if (hasGrandFinal && fromLast == 0) return 'Finale des gagnants';
    return switch (fromLast) {
      0 => 'Finale',
      1 => 'Demi-finales',
      2 => 'Quarts de finale',
      3 => 'Huitièmes de finale',
      _ => '${fromLast + 1}e tour avant la finale',
    };
  }

  /// "Léa 12 – 8 Tom", the winner in bold with a trophy; no score for a
  /// win/loss game or a match not played yet.
  Widget _matchLine(BracketMatch m) {
    final gm = m.gameMatchId == null ? null : appState.matches.where((x) => x.id == m.gameMatchId).firstOrNull;
    final rule = game?.resolveRule(tournament.ruleId);
    final showScore = gm != null && !(rule?.isWinLoss ?? false);
    Widget side(String? entrantId, {required bool alignEnd}) {
      final won = m.winnerId != null && m.winnerId == entrantId;
      final lost = m.winnerId != null && !won;
      return Expanded(
        child: Row(
          mainAxisAlignment: alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (won && !alignEnd) ...[const Icon(Icons.emoji_events, color: SharePalette.gold, size: 14), const SizedBox(width: 4)],
            Flexible(
              child: Text(
                _label(entrantId),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: alignEnd ? TextAlign.end : TextAlign.start,
                style: shareBodyFont(size: 12.5, weight: won ? FontWeight.w800 : FontWeight.w700, color: lost ? SharePalette.mut : SharePalette.ink),
              ),
            ),
            if (won && alignEnd) ...[const SizedBox(width: 4), const Icon(Icons.emoji_events, color: SharePalette.gold, size: 14)],
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          side(m.entrantAId, alignEnd: false),
          Container(
            width: 64,
            alignment: Alignment.center,
            child: Text(
              showScore ? '${_score(gm, m.entrantAId)} – ${_score(gm, m.entrantBId)}' : (m.isDone ? 'vs' : '–'),
              style: shareDispFont(size: 13, weight: FontWeight.w700, color: SharePalette.ink2),
            ),
          ),
          side(m.entrantBId, alignEnd: true),
        ],
      ),
    );
  }

  /// An entrant's score in a played match — the sum of its players' points
  /// (a doubles team counts both).
  int _score(GameMatch gm, String? entrantId) {
    final ids = tournament.entrantById(entrantId)?.playerIds.toSet() ?? const <String>{};
    return gm.entries.where((e) => ids.contains(e.playerId)).fold(0, (sum, e) => sum + e.points);
  }
}

String _formatLabel(TournamentFormat f) => switch (f) {
      TournamentFormat.singleElimination => 'Élimination simple',
      TournamentFormat.doubleElimination => 'Élimination double',
      TournamentFormat.groupsThenElimination => 'Poules + élimination',
    };
