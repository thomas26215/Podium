import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/game_filter.dart';
import '../../logic/game_sort.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/game_filter_bar.dart';
import '../../widgets/option_chip.dart';
import 'game_actions_sheet.dart';

class Step1Game extends StatelessWidget {
  const Step1Game({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    // Skipped for a catalog where no game has a theme or player bounds yet —
    // every filter would just empty the grid.
    final filterable = hasFilterableData(app.games);
    // Search and sort only earn their space once there's something to search.
    final searchable = app.games.length > 1;
    final shown = app.filteredGames;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (searchable) ...[
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  // Rebuilt with the stored query when stepping back to this
                  // step, so the box and the filtered grid never disagree.
                  initialValue: app.gameSearch,
                  onChanged: app.setGameSearch,
                  style: bodyFont(size: 15, weight: FontWeight.w700, color: AppColors.ink),
                  decoration: appFieldDecoration(
                    hintText: 'Rechercher un jeu…',
                    prefixIcon: Icon(Icons.search, size: 20, color: AppColors.mut),
                    contentPadding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<GameSort>(
                tooltip: 'Trier',
                padding: EdgeInsets.zero,
                color: AppColors.card,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                onSelected: app.setGameSort,
                itemBuilder: (_) => [
                  for (final sort in GameSort.values)
                    PopupMenuItem(
                      value: sort,
                      child: Text(
                        sort.label,
                        style: bodyFont(size: 14, weight: app.gameSort == sort ? FontWeight.w800 : FontWeight.w600, color: app.gameSort == sort ? AppColors.accent : AppColors.ink),
                      ),
                    ),
                ],
                child: OptionChip(icon: Icons.swap_vert_rounded, label: app.gameSort.shortLabel, selected: false),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        if (filterable) ...[
          GameFilterBar(games: app.games, filter: app.gameGridFilter, shownCount: shown.length, onChanged: app.setGameGridFilter),
          const SizedBox(height: 14),
        ],
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          // Taller cards leave room for the players/themes line.
          childAspectRatio: filterable ? 1.1 : 1.35,
          children: [
            // Cascading in — and a game a search brings back comes in too.
            for (final (i, g) in shown.indexed)
              Builder(builder: (_) {
                final baseSub = g.defaultRule.pointLimit != null ? '${g.category} · ${g.defaultRule.pointLimit} pts max' : g.category;
                final selected = app.draft.gameId == g.id;
                return FadeSlideIn(
                  key: ValueKey(g.id),
                  delay: staggerDelay(i, stepMs: 30, maxMs: 300),
                  child: _GameCard(
                    emoji: g.emoji,
                    name: g.name,
                    sub: g.hasMultipleRules ? '$baseSub · ${g.rules.length} règles' : baseSub,
                    detail: g.summaryLine(),
                    selected: selected,
                    // The wizard advances to a dedicated "Quelle règle ?" step
                    // right after this one whenever the game has more than one
                    // rule (see AppState.stepSequence) — nothing extra to do
                    // here either way.
                    onTap: () => app.pickGame(g.id),
                    onLongPress: () => showGameActionsSheet(context, app, g),
                  ),
                );
              }),
            FadeSlideIn(
              key: const ValueKey('new-game'),
              delay: staggerDelay(shown.length, stepMs: 30, maxMs: 300),
              child: _GameCard(emoji: '＋', name: 'Nouveau jeu', sub: 'Créer', selected: false, dashed: true, onTap: () => _showNewGameChooser(context, app)),
            ),
          ],
        ),
        if ((app.gameGridFilter.isActive || app.gameSearch.trim().isNotEmpty) && shown.isEmpty) ...[
          const SizedBox(height: 10),
          Text('Aucun jeu ne correspond à votre recherche.', style: bodyFont(size: 12.5, weight: FontWeight.w700, color: AppColors.ink2)),
        ],
        if (app.games.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('Appui long sur un jeu pour le modifier ou le supprimer.', style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut)),
        ],
      ],
    );
  }
}

Future<void> _showNewGameChooser(BuildContext context, AppState app) async {
  // Cross-group catalog browsing doesn't have a Salon equivalent — hidden
  // entirely while a Salon is the active context (see AppState.
  // startBrowsingOtherGroups, which is a Group-only feature).
  // Solo games and group games never cross over — "Mon espace solo" doesn't
  // import from the groups (and is never offered to them).
  final hasOtherGroups = app.activeContext == ActiveContextKind.group && !app.isPersonalContext && app.groups.any((g) => g.id != app.currentRootId);
  await showModalBottomSheet(
    context: context,
    sheetAnimationStyle: appSheetAnimation,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ajouter un jeu', style: dispFont(size: 18, weight: FontWeight.w700, color: AppColors.ink)),
          const SizedBox(height: 16),
          ChooserOption(
            icon: Icons.cloud_download_rounded,
            title: 'Importer depuis la bibliothèque',
            subtitle: 'Jeux prêts à l\'emploi, y compris ceux avec des règles spéciales (Président…).',
            onTap: () {
              Navigator.of(sheetContext).pop();
              app.startBrowsingLibrary();
            },
          ),
          if (hasOtherGroups) ...[
            const SizedBox(height: 10),
            ChooserOption(
              icon: Icons.groups_rounded,
              title: 'Depuis un autre de vos groupes',
              subtitle: 'Réutilisez un jeu déjà créé dans un autre groupe.',
              onTap: () {
                Navigator.of(sheetContext).pop();
                app.startBrowsingOtherGroups();
              },
            ),
          ],
          const SizedBox(height: 10),
          ChooserOption(
            icon: Icons.edit_rounded,
            title: 'Créer un jeu personnalisé',
            subtitle: 'Points ou manches gagnées, avec une limite optionnelle.',
            onTap: () {
              Navigator.of(sheetContext).pop();
              app.startNewGame();
            },
          ),
        ],
      ),
    ),
  );
}


class _GameCard extends StatelessWidget {
  final String emoji;
  final String name;
  final String sub;
  final String? detail;
  final bool selected;
  final bool dashed;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  const _GameCard({required this.emoji, required this.name, required this.sub, this.detail, required this.selected, required this.onTap, this.dashed = false, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: AppColors.motion.change,
        curve: AppColors.motion.changeCurve,
        padding: const EdgeInsets.all(16),
        decoration: cardDecoration(
          radius: AppRadius.xl,
          fill: selected ? AppColors.accentSoft : (dashed ? Colors.transparent : null),
          border: selected ? AppColors.accent : null,
          borderWidth: 1.5,
          selected: selected,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: TextStyle(fontSize: 30, color: dashed ? AppColors.accent : null, fontWeight: dashed ? FontWeight.w700 : null)),
            const SizedBox(height: 8),
            Text(name, style: bodyFont(size: 15, weight: FontWeight.w800, color: AppColors.ink)),
            Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyFont(size: 11.5, weight: FontWeight.w600, color: AppColors.mut)),
            if (detail != null) Text(detail!, maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyFont(size: 11.5, weight: FontWeight.w600, color: AppColors.mut)),
          ],
        ),
      ),
    );
  }
}
