import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/personal_records.dart';
import '../../models/game.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../new_game/game_actions_sheet.dart';
import '../new_game/new_game_sheet.dart';
import 'solo_game_screen.dart';

/// "Mes jeux" tab of "Mon espace solo" (in place of the groups'
/// Discussion): the solo catalog as a grid, each game with its record and a
/// "Jouer" button that opens the new-match sheet straight on it.
class SoloGamesScreen extends StatelessWidget {
  const SoloGamesScreen({super.key});

  Future<void> _addGame(BuildContext context, AppState app) async {
    if (app.activeContextClosed) return;
    app.openSheet();
    await showNewGameSheet(context, app);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final records = app.personalRecords;
    // Most recently played first, then never-played games by name.
    final lastPlayed = <String, DateTime>{};
    for (final r in records) {
      final t = lastPlayed[r.game.id];
      if (t == null || r.lastPlayedAt.isAfter(t)) lastPlayed[r.game.id] = r.lastPlayedAt;
    }
    final games = [...app.games]
      ..sort((a, b) {
        final ta = lastPlayed[a.id], tb = lastPlayed[b.id];
        if (ta != null && tb != null) return tb.compareTo(ta);
        if (ta != null) return -1;
        if (tb != null) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 116),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: ScreenHeading(eyebrow: '${games.length} jeu${games.length > 1 ? 'x' : ''}', title: 'Mes jeux')),
              if (!app.activeContextClosed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Pressable(
                    onTap: () => _addGame(context, app),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, size: 18, color: AppColors.accent),
                        const SizedBox(width: 4),
                        Text('Ajouter', style: bodyFont(size: 13.5, weight: FontWeight.w800, color: AppColors.accent)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          if (games.isEmpty)
            const EmptyState(emoji: '🎮', message: 'Aucun jeu solo pour l’instant. Ajoutez-en un depuis la bibliothèque ou créez le vôtre.')
          else
            LayoutBuilder(builder: (context, constraints) {
              final width = (constraints.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final (i, g) in games.indexed)
                    SizedBox(
                      width: width,
                      child: FadeSlideIn(
                        delay: Duration(milliseconds: i * 30),
                        child: _GameTile(game: g, records: records.where((r) => r.game.id == g.id).toList()),
                      ),
                    ),
                ],
              );
            }),
        ],
      ),
    );
  }
}

class _GameTile extends StatelessWidget {
  final Game game;
  final List<PersonalRecord> records; // one per rule played
  const _GameTile({required this.game, required this.records});

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    // The rule played last — what "Jouer" and the record line default to.
    final latest = records.isEmpty ? null : records.reduce((a, b) => a.lastPlayedAt.isAfter(b.lastPlayedAt) ? a : b);
    final line = latest == null
        ? 'Pas encore joué'
        : latest.bestLabel != null
            ? 'Record ${latest.bestLabel}'
            : '${latest.played} partie${latest.played > 1 ? 's' : ''}';
    return Pressable(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SoloGameScreen(gameId: game.id, initialRuleId: latest?.rule.id, initialSetupPick: latest?.setupPick))),
      // Same menu as a long press in the new-match picker: edit, rules
      // reminders, delete…
      onLongPress: () => showGameActionsSheet(context, app, game),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: cardDecoration(radius: AppRadius.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(game.emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 8),
            Text(game.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: bodyFont(size: 14, weight: FontWeight.w800, color: AppColors.ink, height: 1.2)),
            const SizedBox(height: 3),
            Text(line, maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyFont(size: 12, weight: FontWeight.w700, color: latest?.bestLabel != null ? AppColors.ink2 : AppColors.mut)),
            if (latest?.setupPick != null) Text(latest!.setupPick!, maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyFont(size: 11.5, weight: FontWeight.w600, color: AppColors.mut)),
            const SizedBox(height: 12),
            if (!app.activeContextClosed)
              Pressable(
                onTap: () => launchSoloMatch(context, app, game, ruleId: latest?.rule.id),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: AppColors.accentSoft, border: Border.all(color: AppColors.accent, width: 1.5), borderRadius: BorderRadius.circular(AppRadius.md)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_arrow_rounded, size: 18, color: AppColors.accent),
                      const SizedBox(width: 4),
                      Text('Jouer', style: bodyFont(size: 13, weight: FontWeight.w800, color: AppColors.accent)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
