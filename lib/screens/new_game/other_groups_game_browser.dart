import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Lists games found in the user's *other* groups ([AppState.otherGroupsGames])
/// so one can be copied straight into the current group's catalog — spares
/// re-creating a game by hand when it already exists elsewhere.
class OtherGroupsGameBrowser extends StatelessWidget {
  const OtherGroupsGameBrowser({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final games = app.filteredOtherGroupsGames;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          onChanged: app.setOtherGroupsSearch,
          style: bodyFont(size: 15, weight: FontWeight.w700, color: AppColors.ink),
          decoration: appFieldDecoration(
            hintText: 'Rechercher un jeu ou un groupe…',
            prefixIcon: Icon(Icons.search, size: 20, color: AppColors.mut),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        const SizedBox(height: 16),
        if (app.otherGroupsLoading)
          Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: CircularProgressIndicator(color: AppColors.accent)))
        else if (games.isEmpty)
          EmptyState(
            emoji: '📭',
            message: app.otherGroupsGames.isEmpty ? "Aucun jeu dans vos autres groupes." : 'Aucun résultat pour cette recherche.',
          )
        else
          for (final og in games) _OtherGroupGameTile(entry: og, onTap: () => app.importOtherGroupGame(og)),
      ],
    );
  }
}

class _OtherGroupGameTile extends StatelessWidget {
  final OtherGroupGame entry;
  final VoidCallback onTap;
  const _OtherGroupGameTile({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final game = entry.game;
    return GameTileRow(
      emoji: game.emoji,
      onTap: onTap,
      title: Text(game.name, style: bodyFont(size: 15, weight: FontWeight.w800, color: AppColors.ink), overflow: TextOverflow.ellipsis),
      subtitle: Row(
        children: [
          Flexible(child: Text(game.category, style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut), overflow: TextOverflow.ellipsis)),
          Text('  ·  ', style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut)),
          Flexible(
            child: Text(
              entry.groupName,
              style: bodyFont(size: 12, weight: FontWeight.w700, color: AppColors.accent),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
