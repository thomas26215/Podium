import '../models/game_themes.dart';
import '../state/player_row.dart';

/// How a player fares across the games carrying one theme tag — aggregated
/// from their per-game stats (see `AppState.profileGameBreakdown`). A game
/// with several tags counts once under each of them.
class ThemeStat {
  final GameThemeTag tag;
  final int played;
  final int wins;
  const ThemeStat({required this.tag, required this.played, required this.wins});

  double get ratio => played > 0 ? wins / played : 0;
}

/// [stats] regrouped by theme tag, most-played first (ties: best winrate,
/// then label). Only tags with at least one game played appear.
List<ThemeStat> themeStats(Iterable<ProfileGameStat> stats) {
  final played = <String, int>{};
  final wins = <String, int>{};
  final tags = <String, GameThemeTag>{};
  for (final s in stats) {
    for (final t in s.game.themeTags) {
      tags.putIfAbsent(t.id, () => t);
      played[t.id] = (played[t.id] ?? 0) + s.played;
      wins[t.id] = (wins[t.id] ?? 0) + s.wins;
    }
  }
  final out = [for (final id in tags.keys) ThemeStat(tag: tags[id]!, played: played[id]!, wins: wins[id]!)];
  out.sort((a, b) {
    if (a.played != b.played) return b.played.compareTo(a.played);
    if (a.ratio != b.ratio) return b.ratio.compareTo(a.ratio);
    return a.tag.label.compareTo(b.tag.label);
  });
  return out;
}
