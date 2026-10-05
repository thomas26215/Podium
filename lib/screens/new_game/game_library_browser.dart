import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/game_filter.dart';
import '../../models/game.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/game_filter_bar.dart';
import '../../widgets/option_chip.dart';
import 'library_game_preview_screen.dart';

/// Lists games from the shared online library ([AppState.gameLibrary]) so a
/// group can import ready-made games — including ones with special scoring
/// rules (roles/ranks) that would be tedious to configure by hand. Tapping
/// one opens its full preview ([LibraryGamePreviewScreen]), where it's
/// actually imported; games the catalog already follows are ticked.
///
/// A row of category chips narrows the list to one `Game.category`; the
/// filter bar then only offers that category's themes. The library holds
/// over a thousand games, so results are shown [_pageSize] at a time behind
/// an "Afficher plus" button, and only the first page animates in.
class GameLibraryBrowser extends StatefulWidget {
  const GameLibraryBrowser({super.key});

  @override
  State<GameLibraryBrowser> createState() => _GameLibraryBrowserState();
}

class _GameLibraryBrowserState extends State<GameLibraryBrowser> {
  static const _pageSize = 40;
  int _shown = _pageSize;
  String? _lastSearch;
  GameFilter? _lastFilter;
  String? _lastCategory;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final games = app.filteredLibrary;
    final inCategory = app.libraryInCategory;
    // A new category, search or filter starts back at the first page.
    if (app.librarySearch != _lastSearch || !identical(app.libraryFilter, _lastFilter) || app.libraryCategory != _lastCategory) {
      _lastSearch = app.librarySearch;
      _lastFilter = app.libraryFilter;
      _lastCategory = app.libraryCategory;
      _shown = _pageSize;
    }
    final visible = games.take(_shown).toList();
    void preview(Game g) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LibraryGamePreviewScreen(game: g)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (app.gameLibrary.isNotEmpty) ...[
          _CategoryChips(library: app.contextLibrary, selected: app.libraryCategory, onChanged: app.setLibraryCategory),
          const SizedBox(height: 12),
        ],
        TextField(
          onChanged: app.setLibrarySearch,
          style: bodyFont(size: 15, weight: FontWeight.w700, color: AppColors.ink),
          decoration: appFieldDecoration(
            hintText: 'Rechercher un jeu…',
            prefixIcon: Icon(Icons.search, size: 20, color: AppColors.mut),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        if (hasFilterableData(inCategory)) ...[
          const SizedBox(height: 12),
          GameFilterBar(games: inCategory, filter: app.libraryFilter, shownCount: games.length, onChanged: app.setLibraryFilter),
        ],
        const SizedBox(height: 16),
        if (app.libraryLoading)
          const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: PodiumLoader()))
        else if (games.isEmpty)
          EmptyState(
            emoji: '📭',
            message: app.gameLibrary.isEmpty
                ? "Aucun jeu dans la bibliothèque pour l'instant."
                : (app.libraryFilter.isActive ? 'Aucun jeu ne correspond à ces filtres.' : 'Aucun résultat pour cette recherche.'),
          )
        else ...[
          for (final (i, g) in visible.indexed)
            i < _pageSize
                ? FadeSlideIn(delay: Duration(milliseconds: i * 30), child: _LibraryGameTile(game: g, imported: app.libraryCopyOf(g) != null, onTap: () => preview(g)))
                : _LibraryGameTile(game: g, imported: app.libraryCopyOf(g) != null, onTap: () => preview(g)),
          if (games.length > visible.length)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: TextButton(
                  onPressed: () => setState(() => _shown += _pageSize),
                  child: Text('Afficher plus (${games.length - visible.length} restants)', style: bodyFont(size: 14, weight: FontWeight.w800, color: AppColors.accent)),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

/// "Tous · 1071", "Jeux de société · 445"… — one chip per category present
/// in the library, in [Game.categories] order, scrolling sideways on narrow
/// screens.
class _CategoryChips extends StatelessWidget {
  final List<Game> library;
  final String? selected;
  final ValueChanged<String?> onChanged;
  const _CategoryChips({required this.library, required this.selected, required this.onChanged});

  static const _labels = {
    'Société': 'Jeux de société',
    'Cartes': 'Jeux de cartes',
    'Jeu vidéo': 'Jeux vidéo',
    'Sport': 'Sports',
    'Autre': 'Autres',
  };

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final g in library) {
      counts[g.category] = (counts[g.category] ?? 0) + 1;
    }
    final categories = [...Game.categories.where(counts.containsKey), ...counts.keys.where((c) => !Game.categories.contains(c))];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          OptionChip(label: 'Tous · ${library.length}', selected: selected == null, onTap: () => onChanged(null)),
          for (final c in categories) ...[
            const SizedBox(width: 8),
            OptionChip(label: '${_labels[c] ?? c} · ${counts[c]}', selected: selected == c, onTap: () => onChanged(c)),
          ],
        ],
      ),
    );
  }
}

class _LibraryGameTile extends StatelessWidget {
  final Game game;
  final bool imported;
  final VoidCallback onTap;
  const _LibraryGameTile({required this.game, required this.imported, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final special = game.defaultRule.isRanks;
    return GameTileRow(
      emoji: game.emoji,
      onTap: onTap,
      trailing: imported
          ? Icon(Icons.check_circle_rounded, color: AppColors.accent, size: 26)
          : Icon(Icons.chevron_right_rounded, color: AppColors.mut, size: 26),
      title: Row(
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
      subtitle: Text([game.category, ?game.summaryLine()].join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut)),
    );
  }
}
