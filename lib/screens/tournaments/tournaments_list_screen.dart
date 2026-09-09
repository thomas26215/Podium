import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/game.dart';
import '../../models/tournament.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../new_game/new_game_sheet.dart';
import 'tournament_detail_screen.dart';

/// Every tournament in the currently-viewed group, active ones first —
/// reached from the "Tout voir" link on the home screen's "Tournois"
/// section. Creating a new one goes through the same "+" wizard as a plain
/// match (see `AppState.startTournamentCreationFlow`), not a screen of its
/// own.
class TournamentsListScreen extends StatelessWidget {
  const TournamentsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final tournaments = List<Tournament>.of(app.viewTournaments)
      ..sort((a, b) {
        if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
        return b.createdAt.compareTo(a.createdAt);
      });

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        foregroundColor: AppColors.ink,
        title: Text('Tournois', style: bodyFont(size: 17, weight: FontWeight.w800, color: AppColors.ink)),
      ),
      floatingActionButton: app.currentGroupClosed
          ? null
          : FloatingActionButton(
              backgroundColor: AppColors.accent,
              onPressed: () {
                app.startTournamentCreationFlow();
                showNewGameSheet(context, app);
              },
              child: const Icon(Icons.add, color: Colors.white),
            ),
      body: tournaments.isEmpty
          ? Center(child: EmptyState(emoji: '🏆', message: "Aucun tournoi pour l'instant. Créez-en un avec le bouton +."))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              itemCount: tournaments.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final t = tournaments[i];
                return FadeSlideIn(
                  delay: Duration(milliseconds: i * 40),
                  child: _TournamentRow(
                    tournament: t,
                    game: app.gameById(t.gameId),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TournamentDetailScreen(tournamentId: t.id))),
                  ),
                );
              },
            ),
    );
  }
}

class _TournamentRow extends StatelessWidget {
  final Tournament tournament;
  final Game? game;
  final VoidCallback onTap;
  const _TournamentRow({required this.tournament, required this.game, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final done = tournament.matches.where((m) => m.gameMatchId != null || m.bye).length;
    final total = tournament.matches.where((m) => m.bracket != 'group').length;
    final format = switch (tournament.format) {
      TournamentFormat.singleElimination => 'Élimination simple',
      TournamentFormat.doubleElimination => 'Élimination double',
      TournamentFormat.groupsThenElimination => 'Poules + élimination',
    };
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line, width: 1.5), borderRadius: BorderRadius.circular(AppRadius.xl)),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(14)),
              child: Text(game?.emoji ?? '🎲', style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tournament.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyFont(size: 15, weight: FontWeight.w800, color: AppColors.ink)),
                  Text(
                    '$format · ${tournament.entrants.length} participants${total > 0 ? ' · $done/$total joués' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: tournament.isCompleted ? AppColors.accentSoft : AppColors.bg,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                tournament.isCompleted ? 'Terminé' : 'En cours',
                style: bodyFont(size: 10.5, weight: FontWeight.w800, color: tournament.isCompleted ? AppColors.accent : AppColors.mut),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
