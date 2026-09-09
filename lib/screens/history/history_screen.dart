import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../models/game.dart';
import '../../models/match.dart';
import '../../models/tournament.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';
import '../../widgets/common.dart';
import '../../widgets/match_card.dart';
import '../tournaments/tournament_detail_screen.dart';
import 'match_detail_screen.dart';

/// One history row: either a single standalone match, every leg of a
/// "best of N" series (sharing a `seriesId`) collapsed into one grouped
/// [SeriesMatchCard], or every match played as part of a tournament
/// (sharing a `tournamentId`) collapsed into one [_TournamentMatchCard].
class _HistoryItem {
  final List<GameMatch> legs;
  const _HistoryItem(this.legs);

  bool get isSeries => legs.first.seriesId != null;
  bool get isTournament => legs.first.tournamentId != null;
  String get gameId => legs.first.gameId;
  DateTime get sortKey => legs.map((m) => m.createdAt).reduce((a, b) => a.isAfter(b) ? a : b);
}

String _matchGroupingSignature(GameMatch match) {
  final participants = match.entries.map((e) => e.playerId).toList()..sort();
  return [match.gameId, participants.join(',')].join('|');
}

DateTime _dayKey(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

List<_HistoryItem> _groupHistoryItems(List<GameMatch> matches) {
  final seriesGroups = <String, List<GameMatch>>{};
  final tournamentGroups = <String, List<GameMatch>>{};
  final compactGroups = <String, List<GameMatch>>{};
  for (final m in matches) {
    final tid = m.tournamentId;
    final sid = m.seriesId;
    if (tid != null) {
      tournamentGroups.putIfAbsent(tid, () => []).add(m);
    } else if (sid != null) {
      seriesGroups.putIfAbsent(sid, () => []).add(m);
    } else {
      final key = '${_dayKey(m.createdAt).millisecondsSinceEpoch}|${_matchGroupingSignature(m)}';
      compactGroups.putIfAbsent(key, () => []).add(m);
    }
  }

  final items = <_HistoryItem>[];
  for (final legs in compactGroups.values) {
    legs.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    items.add(_HistoryItem(legs));
  }
  for (final legs in seriesGroups.values) {
    legs.sort((a, b) => (a.seriesGame ?? 0).compareTo(b.seriesGame ?? 0));
    items.add(_HistoryItem(legs));
  }
  for (final legs in tournamentGroups.values) {
    legs.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    items.add(_HistoryItem(legs));
  }
  items.sort((a, b) => b.sortKey.compareTo(a.sortKey));
  return items;
}

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final matches = app.viewMatches;
    final stats = app.groupStats;
    final items = _groupHistoryItems(matches);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 116),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenHeading(eyebrow: '${stats['parties']} parties', title: 'Historique'),
          if (items.isEmpty)
            const EmptyState(emoji: '🗂️', message: 'Aucune partie enregistrée pour l\'instant.')
          else
            for (final (i, item) in items.indexed)
              Builder(builder: (context) {
                final g = app.gameById(item.gameId);
                if (g == null) return const SizedBox.shrink();
                void onTapLeg(GameMatch leg) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MatchDetailScreen(game: g, match: leg, appState: app)));
                return FadeSlideIn(
                  delay: Duration(milliseconds: i * 40),
                  child: item.isTournament
                      ? _TournamentMatchCard(
                          tournament: app.tournaments.where((t) => t.id == item.legs.first.tournamentId).firstOrNull,
                          game: g,
                          legs: item.legs,
                          appState: app,
                          onTapLeg: onTapLeg,
                        )
                      : item.isSeries
                          ? SeriesMatchCard(game: g, legs: item.legs, appState: app, onTapLeg: onTapLeg)
                          : item.legs.length > 1
                              ? _GroupedMatchCard(game: g, legs: item.legs, appState: app, onTapLeg: onTapLeg)
                              : MatchCard(
                                  game: g,
                                  match: item.legs.single,
                                  appState: app,
                                  onTap: () => onTapLeg(item.legs.single),
                                ),
                );
              }),
        ],
      ),
    );
  }
}

class _GroupedMatchCard extends StatefulWidget {
  final Game game;
  final List<GameMatch> legs;
  final AppState appState;
  final void Function(GameMatch leg) onTapLeg;

  const _GroupedMatchCard({required this.game, required this.legs, required this.appState, required this.onTapLeg});

  @override
  State<_GroupedMatchCard> createState() => _GroupedMatchCardState();
}

class _GroupedMatchCardState extends State<_GroupedMatchCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final legs = widget.legs;
    final latest = legs.last;
    final resultLine = '${legs.length} parties le même jour';
    final players = legs.expand((m) => m.entries.map((e) => widget.appState.playerById(e.playerId))).whereType<AppUser>().toSet().toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(AppRadius.xl)),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: matchHeader(widget.game, 'Suite de ${legs.length} parties', latest.createdAt)),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.expand_more_rounded, size: 20, color: AppColors.mut),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: Text(resultLine, style: bodyFont(size: 13.5, weight: FontWeight.w700, color: AppColors.ink2))),
                AvatarCluster(avatars: [for (final p in players.take(4)) (initial: p.initial, color: Color(p.color))]),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              alignment: Alignment.topCenter,
              child: !_expanded
                  ? const SizedBox(width: double.infinity)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        Container(height: 1, color: AppColors.line),
                        const SizedBox(height: 10),
                        for (final (index, leg) in legs.indexed)
                          InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => widget.onTapLeg(leg),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  SizedBox(width: 58, child: Text('Partie ${index + 1}', style: bodyFont(size: 12.5, weight: FontWeight.w700, color: AppColors.mut))),
                                  Expanded(child: Text(matchResultLine(widget.game, leg, widget.appState), style: bodyFont(size: 13, weight: FontWeight.w700, color: AppColors.ink))),
                                  Text(hhmm(leg.createdAt), style: bodyFont(size: 11.5, weight: FontWeight.w600, color: AppColors.mut)),
                                  const SizedBox(width: 8),
                                  Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.mut),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Groups every match played as part of one tournament (see
/// [_groupHistoryItems]) under a single card instead of scattering them as
/// unrelated standalone matches — tapping the header opens the tournament's
/// bracket ([TournamentDetailScreen]); a "Voir les parties" toggle expands
/// the flat list of individual legs, same as [SeriesMatchCard]/
/// [_GroupedMatchCard]. Falls back to a generic "Tournoi" label with no
/// bracket link if the tournament itself was since deleted — see
/// `AppState.deleteTournament`'s confirm dialog, which explicitly leaves
/// already-recorded matches in the history.
class _TournamentMatchCard extends StatefulWidget {
  final Tournament? tournament;
  final Game game;
  final List<GameMatch> legs;
  final AppState appState;
  final void Function(GameMatch leg) onTapLeg;

  const _TournamentMatchCard({required this.tournament, required this.game, required this.legs, required this.appState, required this.onTapLeg});

  @override
  State<_TournamentMatchCard> createState() => _TournamentMatchCardState();
}

class _TournamentMatchCardState extends State<_TournamentMatchCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final legs = widget.legs;
    final tournament = widget.tournament;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.accent, width: 1.5), borderRadius: BorderRadius.circular(AppRadius.xl)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            onTap: tournament == null
                ? null
                : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TournamentDetailScreen(tournamentId: tournament.id))),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(13)),
                  child: const Text('🏆', style: TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tournament?.name ?? 'Tournoi', style: bodyFont(size: 15, weight: FontWeight.w800, color: AppColors.ink)),
                      Text(
                        '${widget.game.name} · ${legs.length} partie${legs.length > 1 ? 's' : ''}${tournament == null ? ' · supprimé' : ''}',
                        style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut),
                      ),
                    ],
                  ),
                ),
                if (tournament != null) Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.mut),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Pressable(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_expanded ? 'Masquer les parties' : 'Voir les parties', style: bodyFont(size: 12.5, weight: FontWeight.w700, color: AppColors.accent)),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.expand_more_rounded, size: 16, color: AppColors.accent),
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: !_expanded
                ? const SizedBox(width: double.infinity)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Container(height: 1, color: AppColors.line),
                      const SizedBox(height: 10),
                      for (final leg in legs)
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => widget.onTapLeg(leg),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Expanded(child: Text(matchResultLine(widget.game, leg, widget.appState), style: bodyFont(size: 13, weight: FontWeight.w700, color: AppColors.ink))),
                                Text(hhmm(leg.createdAt), style: bodyFont(size: 11.5, weight: FontWeight.w600, color: AppColors.mut)),
                                const SizedBox(width: 8),
                                Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.mut),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
