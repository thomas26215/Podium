import '../models/game.dart';
import '../models/game_themes.dart';
import 'text_search.dart';

/// What the game grid is narrowed down to: a number of players the game must
/// accept, and theme tags it must all carry (AND — "Duel + Stratégie" keeps
/// only games that are both). A game with no player bounds is never excluded
/// by the player count; a game without the tags is always excluded by them.
class GameFilter {
  final Set<String> themes;
  final int? players;

  const GameFilter({this.themes = const {}, this.players});

  bool get isActive => themes.isNotEmpty || players != null;

  GameFilter withThemes(Set<String> themes) => GameFilter(themes: themes, players: players);

  /// Passing null clears the player count.
  GameFilter withPlayers(int? players) => GameFilter(themes: themes, players: players);

  bool matches(Game game) {
    if (players != null && !game.acceptsPlayerCount(players!)) return false;
    if (themes.isEmpty) return true;
    final own = game.themeTags.map((t) => t.id).toSet();
    return themes.every(own.contains);
  }

  List<Game> apply(Iterable<Game> games) => games.where(matches).toList();
}

/// Whether [game] matches a free-text search: its name, category or any of
/// its theme labels contains [query] (accent- and case-insensitive). An empty
/// query matches everything.
bool gameMatchesQuery(Game game, String query) {
  final q = foldText(query.trim());
  if (q.isEmpty) return true;
  return foldText(game.name).contains(q) || foldText(game.category).contains(q) || game.themeTags.any((t) => foldText(t.label).contains(q));
}

/// Whether filtering [games] can do anything at all — false for a catalog
/// where no game has a theme or player bounds yet, so the UI can skip the
/// filter bar instead of offering controls that would empty the grid.
bool hasFilterableData(Iterable<Game> games) => games.any((g) => g.themeTags.isNotEmpty || g.minPlayers != null || g.maxPlayers != null);

/// The themes actually carried by [games], grouped for the picker — so a
/// filter only ever offers tags that can return something. Tags shared by
/// several categories are listed once (by id), each group sorted by label.
Map<ThemeGroup, List<GameThemeTag>> themesInUse(Iterable<Game> games) {
  final byId = <String, GameThemeTag>{};
  for (final g in games) {
    for (final t in g.themeTags) {
      byId.putIfAbsent(t.id, () => t);
    }
  }
  return {
    for (final group in ThemeGroup.values)
      if (byId.values.any((t) => t.group == group)) group: (byId.values.where((t) => t.group == group).toList()..sort((a, b) => a.label.compareTo(b.label))),
  };
}
