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
          decoration: InputDecoration(
            hintText: 'Rechercher un jeu ou un groupe…',
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
                  Text(game.name, style: bodyFont(size: 15, weight: FontWeight.w800, color: AppColors.ink), overflow: TextOverflow.ellipsis),
                  Row(
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
