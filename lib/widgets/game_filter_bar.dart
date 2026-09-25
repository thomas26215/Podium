import 'package:flutter/material.dart';

import '../logic/game_filter.dart';
import '../models/game.dart';
import '../theme/app_theme.dart';
import 'common.dart';
import 'option_chip.dart';
import 'theme_picker.dart';

/// Narrows a list of games by number of players and by theme (see
/// [GameFilter]): two compact chips (themes picker, players menu), plus a
/// "N jeux · Réinitialiser" line while something is active. Stateless — the
/// owner keeps the [filter] and applies it ([GameFilter.apply]) to whatever
/// list it shows. [games] is the full, unfiltered list, so the theme picker
/// only offers tags that can return something.
class GameFilterBar extends StatelessWidget {
  final List<Game> games;
  final GameFilter filter;
  final int shownCount;
  final ValueChanged<GameFilter> onChanged;
  const GameFilterBar({super.key, required this.games, required this.filter, required this.shownCount, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final themeGroups = themesInUse(games);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // No game carries a theme (e.g. the "Autre" category): nothing to pick.
            if (themeGroups.isNotEmpty) ...[
              OptionChip(
                icon: Icons.sell_outlined,
                label: filter.themes.isEmpty ? 'Thèmes' : 'Thèmes · ${filter.themes.length}',
                selected: filter.themes.isNotEmpty,
                onTap: () async {
                  final picked = await showThemePicker(
                    context,
                    groups: themeGroups,
                    selected: filter.themes.toList(),
                    title: 'Filtrer par thème',
                  );
                  if (picked != null) onChanged(filter.withThemes(picked.toSet()));
                },
              ),
              const SizedBox(width: 8),
            ],
            // One chip opening a small menu, instead of a chip per player count.
            PopupMenuButton<int>(
              tooltip: 'Nombre de joueurs',
              padding: EdgeInsets.zero,
              color: AppColors.card,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
              onSelected: (n) => onChanged(filter.withPlayers(n == 0 ? null : n)),
              itemBuilder: (_) => [
                if (filter.players != null) PopupMenuItem(value: 0, child: Text('Tous', style: bodyFont(size: 14, weight: FontWeight.w700, color: AppColors.mut))),
                for (var n = 2; n <= 8; n++)
                  PopupMenuItem(
                    value: n,
                    child: Text('$n joueurs', style: bodyFont(size: 14, weight: filter.players == n ? FontWeight.w800 : FontWeight.w600, color: filter.players == n ? AppColors.accent : AppColors.ink)),
                  ),
              ],
              child: OptionChip(icon: Icons.group_outlined, label: filter.players == null ? 'Joueurs' : '${filter.players} joueurs', selected: filter.players != null),
            ),
          ],
        ),
        if (filter.isActive)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                Text('$shownCount jeu${shownCount > 1 ? 'x' : ''}', style: bodyFont(size: 12.5, weight: FontWeight.w700, color: AppColors.mut)),
                const SizedBox(width: 10),
                Pressable(
                  onTap: () => onChanged(const GameFilter()),
                  child: Text('Réinitialiser', style: bodyFont(size: 12.5, weight: FontWeight.w700, color: AppColors.accent)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
