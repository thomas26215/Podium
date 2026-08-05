import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/game.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../new_game/game_actions_sheet.dart';
import 'game_detail_screen.dart';

/// The group's whole game catalog in one place — anyone can browse it,
/// including its rules reminders, without going through the new-game flow.
class GamesCatalogScreen extends StatelessWidget {
  const GamesCatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final games = app.topLevelGames;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        foregroundColor: AppColors.ink,
        title: Text('Jeux du groupe', style: bodyFont(size: 17, weight: FontWeight.w800, color: AppColors.ink)),
      ),
      body: games.isEmpty
          ? Center(child: EmptyState(emoji: '🎲', message: "Aucun jeu dans ce groupe pour l'instant."))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              itemCount: games.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final g = games[i];
                return _GameRow(
                  game: g,
                  variantCount: app.variantsOf(g.id).length,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => GameDetailScreen(game: g))),
                  onLongPress: () => showGameActionsSheet(context, app, g),
                );
              },
            ),
    );
  }
}

class _GameRow extends StatelessWidget {
  final Game game;
  final int variantCount;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  const _GameRow({required this.game, required this.variantCount, required this.onTap, required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final ruleCount = game.ruleSections.length;
    final bits = <String>[
      game.category,
      if (game.pointLimit != null) '${game.pointLimit} pts max',
      if (variantCount > 0) '$variantCount variante${variantCount > 1 ? 's' : ''}',
      if (ruleCount > 0) '$ruleCount catégorie${ruleCount > 1 ? 's' : ''} de règles',
    ];
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
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
              child: Text(game.emoji, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(game.name, style: bodyFont(size: 15, weight: FontWeight.w800, color: AppColors.ink)),
                  Text(bits.join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.mut),
          ],
        ),
      ),
    );
  }
}
