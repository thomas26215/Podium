import '../models/game.dart';
import '../models/match.dart';
import 'text_search.dart';

/// How the "Quel jeu ?" grid is ordered.
enum GameSort {
  lastPlayed('Dernière partie', 'Récent'),
  playCount('Nombre de parties', 'Plus joués'),
  name('Nom (A → Z)', 'A → Z');

  const GameSort(this.label, this.shortLabel);

  /// Full wording, used in the sort menu.
  final String label;

  /// Compact wording for the chip showing the current choice.
  final String shortLabel;
}

/// How much a game has been played in the current view.
class GameUsage {
  final int playCount;
  final DateTime? lastPlayed;
  const GameUsage({required this.playCount, required this.lastPlayed});
}

/// Match count and most recent match date per game id — a game with no match
/// has no entry.
Map<String, GameUsage> gameUsage(Iterable<GameMatch> matches) {
  final count = <String, int>{};
  final last = <String, DateTime>{};
  for (final m in matches) {
    count[m.gameId] = (count[m.gameId] ?? 0) + 1;
    final prev = last[m.gameId];
    if (prev == null || m.createdAt.isAfter(prev)) last[m.gameId] = m.createdAt;
  }
  return {for (final id in count.keys) id: GameUsage(playCount: count[id]!, lastPlayed: last[id])};
}

/// [games] ordered by [sort]. Games never played always come after played
/// ones for the two usage-based sorts, then alphabetically; ties fall back
/// to the other usage measure and finally the name, so the order is stable.
List<Game> sortGames(Iterable<Game> games, GameSort sort, Map<String, GameUsage> usage) {
  int byName(Game a, Game b) => foldText(a.name).compareTo(foldText(b.name));
  int byLast(Game a, Game b) {
    final la = usage[a.id]?.lastPlayed, lb = usage[b.id]?.lastPlayed;
    if (la == null && lb == null) return 0;
    if (la == null) return 1;
    if (lb == null) return -1;
    return lb.compareTo(la);
  }

  int byCount(Game a, Game b) => (usage[b.id]?.playCount ?? 0).compareTo(usage[a.id]?.playCount ?? 0);

  final out = games.toList();
  out.sort(switch (sort) {
    GameSort.lastPlayed => (a, b) => byLast(a, b) != 0 ? byLast(a, b) : (byCount(a, b) != 0 ? byCount(a, b) : byName(a, b)),
    GameSort.playCount => (a, b) => byCount(a, b) != 0 ? byCount(a, b) : (byLast(a, b) != 0 ? byLast(a, b) : byName(a, b)),
    GameSort.name => byName,
  });
  return out;
}
