import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/game.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Lists games from the shared online library ([AppState.gameLibrary]) so a
/// group can import ready-made games — including ones with special scoring
/// rules (roles/ranks) that would be tedious to configure by hand.
class GameLibraryBrowser extends StatelessWidget {
  const GameLibraryBrowser({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final games = app.filteredLibrary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          onChanged: app.setLibrarySearch,
          style: bodyFont(size: 15, weight: FontWeight.w700, color: AppColors.ink),
          decoration: InputDecoration(
            hintText: 'Rechercher un jeu…',
            prefixIcon: Icon(Icons.search, size: 20, color: AppColors.mut),
            filled: true,
            fillColor: AppColors.card,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.line, width: 1.5)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.line, width: 1.5)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.accent, width: 1.5)),
          ),
        ),
        const SizedBox(height: 16),
        if (app.libraryLoading)
          Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: CircularProgressIndicator(color: AppColors.accent)))
        else if (games.isEmpty)
          EmptyState(
            emoji: '📭',
            message: app.gameLibrary.isEmpty ? "Aucun jeu dans la bibliothèque pour l'instant." : 'Aucun résultat pour cette recherche.',
          )
        else
          for (final g in games) _LibraryGameTile(game: g, onTap: () => app.importLibraryGame(g)),
      ],
    );
  }
}

class _LibraryGameTile extends StatelessWidget {
  final Game game;
  final VoidCallback onTap;
  const _LibraryGameTile({required this.game, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final special = game.isRanks;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line, width: 1.5), borderRadius: BorderRadius.circular(AppRadius.lg)),
        child: Row(
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
                  Row(
                    children: [
                      Flexible(child: Text(game.name, style: bodyFont(size: 15, weight: FontWeight.w800, color: AppColors.ink), overflow: TextOverflow.ellipsis)),
                      if (special) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(20)),
                          child: Text('RÈGLES SPÉCIALES', style: bodyFont(size: 9, weight: FontWeight.w800, color: AppColors.accent, letterSpacing: 0.3)),
                        ),
                      ],
                    ],
                  ),
                  Text(game.category, style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut)),
                ],
              ),
            ),
            Icon(Icons.add_circle_rounded, color: AppColors.accent, size: 26),
          ],
        ),
      ),
    );
  }
}
