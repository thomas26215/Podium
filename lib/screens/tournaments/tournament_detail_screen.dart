import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/tournament_bracket.dart';
import '../../models/match.dart';
import '../../models/tournament.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../new_game/new_game_sheet.dart';

/// The visible bracket: round columns connected with "H" connectors for the
/// winners bracket (and the whole tree, for single elimination), a plainer
/// list for the losers bracket in a double-elimination tournament, and group
/// standings tables for a "poules + élimination" tournament before its
/// playoffs are generated. Looks the tournament up live by id (rather than
/// taking a snapshot) so it stays current as results are recorded — from
/// this screen itself, or by a teammate on another device.
class TournamentDetailScreen extends StatelessWidget {
  final String tournamentId;
  const TournamentDetailScreen({super.key, required this.tournamentId});

  Future<void> _confirmDelete(BuildContext context, AppState app, Tournament t) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
        title: Text('Supprimer ce tournoi ?', style: dispFont(size: 18, weight: FontWeight.w700, color: AppColors.ink)),
        content: Text(
          'Cette action est définitive : le bracket et toutes les parties déjà enregistrées pour ce tournoi seront supprimés, y compris de l\'historique.',
          style: bodyFont(size: 14, weight: FontWeight.w600, color: AppColors.mut),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text('Supprimer', style: TextStyle(color: AppColors.accent))),
        ],
      ),
    );
    if (confirmed == true) {
      final ok = await app.deleteTournament(t);
      if (!context.mounted) return;
      if (ok) {
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(app.flowError ?? "Échec de la suppression — vérifiez votre connexion et réessayez.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final tournament = app.tournaments.where((t) => t.id == tournamentId).firstOrNull;

    if (tournament == null) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(backgroundColor: AppColors.bg, elevation: 0, foregroundColor: AppColors.ink),
        body: Center(child: EmptyState(emoji: '🏆', message: 'Ce tournoi n\'existe plus.')),
      );
    }

    final game = app.gameById(tournament.gameId);
    final winnersMatches = tournament.matches.where((m) => m.bracket == 'winners').toList();
    final losersMatches = tournament.matches.where((m) => m.bracket == 'losers').toList();
    final finalMatch = tournament.matches.where((m) => m.bracket == 'final').firstOrNull;
    final groupMatches = tournament.matches.where((m) => m.bracket == 'group').toList();
    final eliminationGenerated = winnersMatches.isNotEmpty;

    void onTapMatch(BracketMatch m) {
      if (m.isReady) {
        app.startTournamentMatch(tournament, m);
        showNewGameSheet(context, app);
        return;
      }
      // Already played (and not a bye, which never had a real match) —
      // reopen it for correction via the same edit flow as a regular
      // match's "Modifier" (see AppState.resumeMatch, which re-syncs the
      // bracket node on save from the match's own tournamentId tag).
      if (m.isDone && !m.bye && m.gameMatchId != null && game != null) {
        final gm = app.matches.where((gm) => gm.id == m.gameMatchId).firstOrNull;
        if (gm != null) {
          app.resumeMatch(gm, game);
          showNewGameSheet(context, app);
        }
      }
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        foregroundColor: AppColors.ink,
        title: Text(tournament.name, style: bodyFont(size: 17, weight: FontWeight.w800, color: AppColors.ink)),
        actions: [
          if (app.canDeleteTournament(tournament))
            IconButton(icon: const Icon(Icons.delete_outline_rounded), onPressed: () => _confirmDelete(context, app, tournament)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(13)),
                child: Text(game?.emoji ?? '🎲', style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(game?.name ?? 'Jeu', style: bodyFont(size: 15, weight: FontWeight.w800, color: AppColors.ink)),
                    Text(_formatLabel(tournament.format), style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut)),
                  ],
                ),
              ),
              _StatusBadge(completed: tournament.isCompleted),
            ],
          ),
          if (tournament.isCompleted) ...[
            const SizedBox(height: 16),
            _ChampionBanner(label: _entrantLabel(app, tournament.entrantById(tournament.winnerEntrantId))),
          ],
          if (tournament.format == TournamentFormat.groupsThenElimination) ...[
            const SizedBox(height: 22),
            SectionHeader(title: 'Poules'),
            for (var g = 0; g < tournament.groupsCount; g++) ...[
              _GroupSection(app: app, tournament: tournament, groupIndex: g, onTapMatch: onTapMatch),
              const SizedBox(height: 14),
            ],
            if (!eliminationGenerated) ...[
              const SizedBox(height: 8),
              PrimaryButton(
                label: 'Lancer les phases finales',
                onPressed: groupStageComplete(tournament) ? () => app.generateEliminationStage(tournament) : null,
              ),
              if (!groupStageComplete(tournament))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Terminez tous les matchs de poule pour lancer la suite.', style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut)),
                ),
            ],
          ],
          if (eliminationGenerated) ...[
            const SizedBox(height: 22),
            SectionHeader(title: tournament.format == TournamentFormat.groupsThenElimination ? 'Phases finales' : 'Winners'),
            _BracketTree(app: app, tournament: tournament, matches: winnersMatches, onTap: onTapMatch),
          ],
          if (losersMatches.isNotEmpty) ...[
            const SizedBox(height: 22),
            SectionHeader(title: 'Losers'),
            _SimpleBracketColumns(app: app, tournament: tournament, matches: losersMatches, onTap: onTapMatch),
          ],
          if (finalMatch != null) ...[
            const SizedBox(height: 22),
            SectionHeader(title: 'Finale'),
            _MatchCard(app: app, tournament: tournament, match: finalMatch, onTap: () => onTapMatch(finalMatch), wide: true),
          ],
          if (!eliminationGenerated && groupMatches.isEmpty)
            const EmptyState(emoji: '🏆', message: 'Ce tournoi n\'a pas encore de match.'),
        ],
      ),
    );
  }
}

String _formatLabel(TournamentFormat f) => switch (f) {
      TournamentFormat.singleElimination => 'Élimination simple',
      TournamentFormat.doubleElimination => 'Élimination double',
      TournamentFormat.groupsThenElimination => 'Poules + élimination',
    };

String _entrantLabel(AppState app, TournamentEntrant? entrant) {
  if (entrant == null) return '?';
  if (entrant.label != null) return entrant.label!;
  final names = entrant.playerIds.map((id) => app.playerById(id)?.displayName.split(' ').first ?? '?').toList();
  return names.join(' & ');
}

class _StatusBadge extends StatelessWidget {
  final bool completed;
  const _StatusBadge({required this.completed});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: completed ? AppColors.accentSoft : AppColors.card,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        completed ? 'Terminé' : 'En cours',
        style: bodyFont(size: 11.5, weight: FontWeight.w800, color: completed ? AppColors.accent : AppColors.mut),
      ),
    );
  }
}

class _ChampionBanner extends StatelessWidget {
  final String label;
  const _ChampionBanner({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(AppRadius.xl)),
      child: Row(
        children: [
          Icon(Icons.emoji_events, color: AppColors.gold, size: 30),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CHAMPION', style: bodyFont(size: 11, weight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.55), letterSpacing: 1.2)),
                Text(label, style: dispFont(size: 19, weight: FontWeight.w700, color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupSection extends StatelessWidget {
  final AppState app;
  final Tournament tournament;
  final int groupIndex;
  final void Function(BracketMatch) onTapMatch;
  const _GroupSection({required this.app, required this.tournament, required this.groupIndex, required this.onTapMatch});

  @override
  Widget build(BuildContext context) {
    final standings = computeGroupStandings(tournament: tournament, groupIndex: groupIndex, playedMatches: app.matches);
    final groupMatches = tournament.matches.where((m) => m.bracket == 'group' && m.groupIndex == groupIndex).toList()
      ..sort((a, b) => a.round != b.round ? a.round.compareTo(b.round) : a.position.compareTo(b.position));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Poule ${groupIndex + 1}', style: bodyFont(size: 13.5, weight: FontWeight.w800, color: AppColors.ink)),
          const SizedBox(height: 10),
          for (final (i, s) in standings.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  SizedBox(width: 18, child: Text('${i + 1}', style: bodyFont(size: 12.5, weight: FontWeight.w700, color: AppColors.mut))),
                  Expanded(child: Text(_entrantLabel(app, tournament.entrantById(s.entrantId)), style: bodyFont(size: 13, weight: FontWeight.w700, color: AppColors.ink))),
                  Text('${s.wins}V', style: bodyFont(size: 12.5, weight: FontWeight.w700, color: AppColors.ink2)),
                  const SizedBox(width: 8),
                  Text('${s.diff >= 0 ? '+' : ''}${s.diff}', style: bodyFont(size: 12.5, weight: FontWeight.w600, color: AppColors.mut)),
                ],
              ),
            ),
          const SizedBox(height: 10),
          for (final m in groupMatches)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _MatchCard(app: app, tournament: tournament, match: m, onTap: () => onTapMatch(m), compact: true),
            ),
        ],
      ),
    );
  }
}

/// Winners-bracket-shaped tree: every round after the first is exactly two
/// matches converging into one (guaranteed by
/// `buildSingleElimination`/`buildDoubleElimination`), so the connector
/// geometry between columns is always a simple "H" shape.
class _BracketTree extends StatelessWidget {
  final AppState app;
  final Tournament tournament;
  final List<BracketMatch> matches;
  final void Function(BracketMatch) onTap;
  const _BracketTree({required this.app, required this.tournament, required this.matches, required this.onTap});

  static const cardHeight = 62.0;
  static const cardWidth = 164.0;
  static const rowGap = 14.0;
  static const colGap = 26.0;

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) return const SizedBox.shrink();
    final rounds = <int, List<BracketMatch>>{};
    for (final m in matches) {
      rounds.putIfAbsent(m.round, () => []).add(m);
    }
    final roundNumbers = rounds.keys.toList()..sort();
    for (final r in roundNumbers) {
      rounds[r]!.sort((a, b) => a.position.compareTo(b.position));
    }
    const unit = cardHeight + rowGap;
    final centers = <List<double>>[];
    for (var ri = 0; ri < roundNumbers.length; ri++) {
      if (ri == 0) {
        centers.add([for (var i = 0; i < rounds[roundNumbers[0]]!.length; i++) i * unit + cardHeight / 2]);
      } else {
        final prev = centers[ri - 1];
        centers.add([for (var i = 0; i < rounds[roundNumbers[ri]]!.length; i++) (prev[2 * i] + prev[2 * i + 1]) / 2]);
      }
    }
    final totalHeight = centers[0].length * unit - rowGap + cardHeight / 2;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        height: totalHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var ri = 0; ri < roundNumbers.length; ri++) ...[
              if (ri > 0)
                SizedBox(
                  width: colGap,
                  height: totalHeight,
                  child: CustomPaint(painter: _ConnectorPainter(from: centers[ri - 1], to: centers[ri], color: AppColors.line)),
                ),
              SizedBox(
                width: cardWidth,
                height: totalHeight,
                child: Stack(
                  children: [
                    for (var i = 0; i < rounds[roundNumbers[ri]]!.length; i++)
                      Positioned(
                        top: centers[ri][i] - cardHeight / 2,
                        left: 0,
                        right: 0,
                        child: _MatchCard(
                          app: app,
                          tournament: tournament,
                          match: rounds[roundNumbers[ri]]![i],
                          onTap: () => onTap(rounds[roundNumbers[ri]]![i]),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ConnectorPainter extends CustomPainter {
  final List<double> from;
  final List<double> to;
  final Color color;
  const _ConnectorPainter({required this.from, required this.to, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final mid = size.width / 2;
    for (var i = 0; i < to.length; i++) {
      final y1 = from[2 * i];
      final y2 = from[2 * i + 1];
      final ym = to[i];
      canvas.drawLine(Offset(0, y1), Offset(mid, y1), paint);
      canvas.drawLine(Offset(0, y2), Offset(mid, y2), paint);
      canvas.drawLine(Offset(mid, y1), Offset(mid, y2), paint);
      canvas.drawLine(Offset(mid, ym), Offset(size.width, ym), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConnectorPainter oldDelegate) => true;
}

/// The losers bracket doesn't converge 2-to-1 every round (its "drop-in"
/// rounds pair one carried-over survivor with one fresh winners-bracket
/// loser at the same position instead), so it's shown as plain round
/// columns rather than the connector tree — still grouped and ordered, just
/// without the "H" connectors.
class _SimpleBracketColumns extends StatelessWidget {
  final AppState app;
  final Tournament tournament;
  final List<BracketMatch> matches;
  final void Function(BracketMatch) onTap;
  const _SimpleBracketColumns({required this.app, required this.tournament, required this.matches, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final rounds = <int, List<BracketMatch>>{};
    for (final m in matches) {
      rounds.putIfAbsent(m.round, () => []).add(m);
    }
    final roundNumbers = rounds.keys.toList()..sort();
    for (final r in roundNumbers) {
      rounds[r]!.sort((a, b) => a.position.compareTo(b.position));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final r in roundNumbers)
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: SizedBox(
                width: 164,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final m in rounds[r]!)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _MatchCard(app: app, tournament: tournament, match: m, onTap: () => onTap(m)),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  final AppState app;
  final Tournament tournament;
  final BracketMatch match;
  final VoidCallback onTap;
  final bool compact;
  final bool wide;
  const _MatchCard({required this.app, required this.tournament, required this.match, required this.onTap, this.compact = false, this.wide = false});

  @override
  Widget build(BuildContext context) {
    final entrantA = tournament.entrantById(match.entrantAId);
    final entrantB = tournament.entrantById(match.entrantBId);
    GameMatch? gm;
    if (match.gameMatchId != null) {
      gm = app.matches.where((m) => m.id == match.gameMatchId).firstOrNull;
    }
    int? scoreFor(TournamentEntrant? e) {
      final match = gm;
      if (match == null || e == null) return null;
      final ids = e.playerIds.toSet();
      return match.entries.where((entry) => ids.contains(entry.playerId)).fold<int>(0, (sum, entry) => sum + entry.points);
    }

    final scoreA = scoreFor(entrantA);
    final scoreB = scoreFor(entrantB);
    // Playable (both entrants known, unplayed) or already played (and
    // editable — see AppState.resumeMatch) — a bye or a still-TBD match has
    // nothing to tap into.
    final tappable = match.isReady || (match.isDone && !match.bye);

    return Pressable(
      onTap: tappable ? onTap : null,
      child: Container(
        width: wide ? double.infinity : null,
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: compact ? 8 : 10),
        decoration: BoxDecoration(
          color: AppColors.card,
          border: Border.all(color: match.isReady ? AppColors.accent : AppColors.line, width: 1.5),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _EntrantLine(label: _entrantLabel(app, entrantA), score: scoreA, isWinner: match.winnerId != null && match.winnerId == entrantA?.id, bye: match.bye && entrantB == null),
            const SizedBox(height: 4),
            _EntrantLine(label: entrantB != null ? _entrantLabel(app, entrantB) : (match.bye ? '—' : 'À déterminer'), score: scoreB, isWinner: match.winnerId != null && match.winnerId == entrantB?.id, bye: false),
          ],
        ),
      ),
    );
  }
}

class _EntrantLine extends StatelessWidget {
  final String label;
  final int? score;
  final bool isWinner;
  final bool bye;
  const _EntrantLine({required this.label, required this.score, required this.isWinner, required this.bye});

  @override
  Widget build(BuildContext context) {
    final color = bye ? AppColors.mut : (isWinner ? AppColors.ink : AppColors.ink2);
    final weight = isWinner ? FontWeight.w800 : FontWeight.w600;
    return Row(
      children: [
        Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyFont(size: 12.5, weight: weight, color: color))),
        if (score != null) AnimatedCounter(value: score!, style: bodyFont(size: 12.5, weight: weight, color: color)),
      ],
    );
  }
}
