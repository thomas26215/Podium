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
/// The "Jeux" tab of `MainShell`.
class GamesCatalogScreen extends StatelessWidget {
  const GamesCatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final games = app.games;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 116),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenHeading(eyebrow: '${games.length} jeux', title: 'Jeux'),
          if (games.isEmpty)
            EmptyState(emoji: '🎲', message: "Aucun jeu dans ce groupe pour l'instant.")
          else
            for (final (i, g) in games.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: FadeSlideIn(
                  delay: Duration(milliseconds: i * 40),
                  child: _GameRow(
                    game: g,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => GameDetailScreen(game: g))),
                    onLongPress: () => showGameActionsSheet(context, app, g),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _GameRow extends StatelessWidget {
  final Game game;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  const _GameRow({required this.game, required this.onTap, required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final reminderCount = game.ruleSections.length;
    final bits = <String>[
      game.category,
      if (game.defaultRule.pointLimit != null) '${game.defaultRule.pointLimit} pts max',
      if (game.hasMultipleRules) '${game.rules.length} règles',
      if (reminderCount > 0) '$reminderCount catégorie${reminderCount > 1 ? 's' : ''} d\'aide-mémoire',
    ];
    return Pressable(
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
