import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../models/game.dart';
import '../models/match.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'avatar.dart';

const frMonths = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];

/// "3 août" style absolute date — the only French date-formatting helper in
/// the app, reused wherever a day needs spelling out (see
/// e.g. GroupFormDialog's auto-generated temporary-group name).
String frenchDayMonth(DateTime dt) => '${dt.day} ${frMonths[dt.month - 1]}';

String relativeDateLabel(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(dt.year, dt.month, dt.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return "Aujourd'hui";
  if (diff == 1) return 'Hier';
  if (diff < 7 && diff > 0) return 'Il y a $diff j';
  return frenchDayMonth(dt);
}

String hhmm(DateTime dt) => '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

/// Short "who won, with what score" line used by both the condensed
/// [MatchCard] and [HomeMatchTile].
String matchResultLine(Game game, GameMatch match, AppState appState) {
  final winners = match.winnerIds();
  if (match.isTeam) {
    final teamIds = <String>[];
    for (final e in match.entries) {
      if (!teamIds.contains(e.teamId)) teamIds.add(e.teamId ?? 'A');
    }
    final winningTeam = match.entries.where((e) => winners.contains(e.playerId)).firstOrNull?.teamId;
    return winningTeam != null ? 'Équipe $winningTeam gagne' : '';
  }
  final winnerNames = winners.map((id) => appState.playerById(id)?.displayName).whereType<String>().toList();
  if (winnerNames.isEmpty) return '';
  final names = winnerNames.join(', ');
  // No score to show for a win/loss game — and with several winners at
  // once (routine for this count type, unlike a tie elsewhere), "Gagné
  // par" reads oddly for more than one name.
  if (game.isWinLoss) return winnerNames.length > 1 ? '$names gagnent' : '$names gagne';
  final entry = winners.length == 1 ? match.entries.where((e) => e.playerId == winners.first).firstOrNull : null;
  final scoreLabel = entry?.role ?? (entry != null ? '${entry.points} pts' : '');
  return 'Gagné par $names${scoreLabel.isNotEmpty ? ' · $scoreLabel' : ''}';
}

/// "Who's ahead in the series" line for a group of legs sharing a
/// `seriesId` — e.g. "Gagné par Alice · 2/3 parties" (or, mid-series,
/// however many legs have actually been played so far).
String seriesResultLine(List<GameMatch> legs, AppState appState) {
  if (legs.isEmpty) return '';
  final t = seriesTally(legs);
  final total = legs.first.seriesLength ?? legs.length;
  if (t.leaders.isEmpty) return '0/$total parties jouées';
  final names = t.isTeam ? t.leaders.map((id) => 'Équipe $id').join(' & ') : t.leaders.map((id) => appState.playerById(id)?.displayName ?? '?').join(' & ');
  final verb = t.leaders.length > 1 ? 'Égalité entre' : 'Gagné par';
  return '$verb $names · ${t.leaderWins}/$total parties';
}

/// Grouped card for a finished (or in-progress) "best of N" series: header +
/// running result, expandable to each individual leg (tap a leg for its
/// full [MatchCard]-style breakdown via [onTapLeg]).
class SeriesMatchCard extends StatefulWidget {
  final Game game;
  final List<GameMatch> legs; // sorted ascending by seriesGame
  final AppState appState;
  final void Function(GameMatch leg) onTapLeg;
  const SeriesMatchCard({super.key, required this.game, required this.legs, required this.appState, required this.onTapLeg});

  @override
  State<SeriesMatchCard> createState() => _SeriesMatchCardState();
}

class _SeriesMatchCardState extends State<SeriesMatchCard> {
  bool _expanded = false;

  Future<void> _confirmDeleteSeries(BuildContext context, int total) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
        title: Text('Supprimer cette série (Best of $total) ?', style: dispFont(size: 18, weight: FontWeight.w700, color: AppColors.ink)),
        content: Text(
          "Cette action est définitive : les ${widget.legs.length} partie${widget.legs.length > 1 ? 's' : ''} de la série seront supprimées et le classement recalculé.",
          style: bodyFont(size: 14, weight: FontWeight.w600, color: AppColors.mut),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Supprimer', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) await widget.appState.deleteMatchSeries(widget.legs);
  }

  @override
  Widget build(BuildContext context) {
    final legs = widget.legs;
    final last = legs.last;
    final total = last.seriesLength ?? legs.length;
    final inProgress = legs.length < total && !legs.any((l) => l.seriesEndedEarly);
    final resultLine = seriesResultLine(legs, widget.appState);
    final players = legs.expand((m) => m.entries.map((e) => widget.appState.playerById(e.playerId))).whereType<AppUser>().toSet().toList();
    final canDelete = widget.appState.canDeleteMatch(legs.first);

    return _CardShell(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: matchHeader(widget.game, inProgress ? 'Best of $total · En cours' : 'Best of $total', last.createdAt)),
              if (canDelete)
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: Icon(Icons.more_horiz, size: 20, color: AppColors.mut),
                  onSelected: (_) => _confirmDeleteSeries(context, total),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'delete', child: Text('Supprimer la série', style: TextStyle(color: Colors.red))),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: Text(resultLine, style: bodyFont(size: 13.5, weight: FontWeight.w700, color: AppColors.ink2))),
              AvatarCluster(avatars: [for (final p in players.take(4)) (initial: p.initial, color: Color(p.color))]),
              const SizedBox(width: 4),
              AnimatedRotation(
                turns: _expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(Icons.expand_more_rounded, size: 20, color: AppColors.mut),
              ),
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
                      for (final leg in legs)
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => widget.onTapLeg(leg),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                SizedBox(width: 58, child: Text('Partie ${leg.seriesGame ?? '?'}', style: bodyFont(size: 12.5, weight: FontWeight.w700, color: AppColors.mut))),
                                Expanded(child: Text(matchResultLine(widget.game, leg, widget.appState), style: bodyFont(size: 13, weight: FontWeight.w700, color: AppColors.ink))),
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

class _CardShell extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _CardShell({required this.child, this.onTap});
  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(AppRadius.xl)),
      child: child,
    );
    if (onTap == null) return card;
    return InkWell(borderRadius: BorderRadius.circular(AppRadius.xl), onTap: onTap, child: card);
  }
}

Widget matchHeader(Game game, String subtitle, DateTime createdAt) {
  return Row(
    children: [
      Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(13)),
        child: Text(game.emoji, style: const TextStyle(fontSize: 22)),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(game.name, style: bodyFont(size: 16, weight: FontWeight.w800, color: AppColors.ink, letterSpacing: -0.1)),
            Text(subtitle, style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut)),
          ],
        ),
      ),
      Text(relativeDateLabel(createdAt), style: bodyFont(size: 11.5, weight: FontWeight.w700, color: AppColors.mut)),
    ],
  );
}

/// Compact one-liner used in the home "dernières parties" list.
class HomeMatchTile extends StatelessWidget {
  final Game game;
  final GameMatch match;
  final AppUser? winner;
  const HomeMatchTile({super.key, required this.game, required this.match, required this.winner});

  @override
  Widget build(BuildContext context) {
    final line = match.isTeam ? 'Victoire en équipe' : (winner != null ? 'Gagné par ${winner!.displayName}' : '');
    return _CardShell(child: matchHeader(game, line, match.createdAt));
  }
}

/// Condensed match summary for the history list: header + who won, with a
/// small avatar cluster of the players involved. Tap for the full
/// breakdown, chart and round-by-round detail (see MatchDetailScreen).
class MatchCard extends StatelessWidget {
  final Game game;
  final GameMatch match;
  final AppState appState;
  final VoidCallback? onTap;
  const MatchCard({super.key, required this.game, required this.match, required this.appState, this.onTap});

  @override
  Widget build(BuildContext context) {
    final unitLabel = match.unit == 'wins' ? ' · Manches' : '';
    final modeLabel = match.isTeam ? ' · Équipes$unitLabel' : unitLabel;
    final resultLine = matchResultLine(game, match, appState);
    final players = match.entries.map((e) => appState.playerById(e.playerId)).whereType<AppUser>().toList();

    return _CardShell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          matchHeader(game, '${game.category}$modeLabel', match.createdAt),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(resultLine, style: bodyFont(size: 13.5, weight: FontWeight.w700, color: AppColors.ink2)),
              ),
              AvatarCluster(avatars: [for (final p in players.take(4)) (initial: p.initial, color: Color(p.color))]),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.mut),
            ],
          ),
          if (match.hasScoreBreakdown || match.tournamentId != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (match.tournamentId != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(999)),
                    child: Text('🏆 Tournoi', style: bodyFont(size: 11.5, weight: FontWeight.w800, color: AppColors.ink2)),
                  ),
                if (match.hasScoreBreakdown)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(999)),
                    child: Text('Par catégories', style: bodyFont(size: 11.5, weight: FontWeight.w800, color: AppColors.accent)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
