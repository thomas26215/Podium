import 'package:flutter_test/flutter_test.dart';
import 'package:podium/logic/game_filter.dart';
import 'package:podium/logic/theme_stats.dart';
import 'package:podium/models/game.dart';
import 'package:podium/state/player_row.dart';

Game _game(String id, {String category = 'Société', List<String> themes = const []}) => Game(
      id: id,
      name: id,
      emoji: '🎲',
      category: category,
      rules: const [GameRule(id: 'default', name: 'Standard', countType: CountType.highWins)],
      themes: themes,
    );

void main() {
  test('themeStats regroups per-game stats under each theme, most played first', () {
    final stats = [
      ProfileGameStat(game: _game('catan', themes: ['strategie', 'gestion']), played: 4, wins: 3, avg: 0),
      ProfileGameStat(game: _game('wonders', themes: ['strategie', 'draft']), played: 2, wins: 0, avg: 0),
      ProfileGameStat(game: _game('uno', category: 'Cartes', themes: ['familial']), played: 6, wins: 1, avg: 0),
      ProfileGameStat(game: _game('bare'), played: 9, wins: 9, avg: 0),
    ];
    final out = themeStats(stats);
    // strategie and familial tie on 6 games played; strategie has the better winrate.
    expect(out.map((t) => t.tag.id), ['strategie', 'familial', 'gestion', 'draft']);
    final strat = out.firstWhere((t) => t.tag.id == 'strategie');
    expect(strat.played, 6, reason: 'a theme sums every game carrying it');
    expect(strat.wins, 3);
    expect(strat.ratio, 0.5);
    expect(out.any((t) => t.played == 9), isFalse, reason: 'a game without themes contributes nothing');
  });

  test('themeStats is empty when no game has a theme', () {
    expect(themeStats([ProfileGameStat(game: _game('bare'), played: 3, wins: 1, avg: 0)]), isEmpty);
  });

  test('gameMatchesQuery searches name, category and theme labels, ignoring accents and case', () {
    final g = _game('Antiquité', themes: ['antiquite', 'draft']);
    expect(gameMatchesQuery(g, ''), isTrue);
    expect(gameMatchesQuery(g, 'antiq'), isTrue);
    expect(gameMatchesQuery(g, 'SOCIETE'), isTrue, reason: 'category, accent-insensitive');
    expect(gameMatchesQuery(g, 'draf'), isTrue, reason: 'theme label');
    expect(gameMatchesQuery(g, 'zzz'), isFalse);
  });
}
