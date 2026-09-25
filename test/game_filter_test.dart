import 'package:flutter_test/flutter_test.dart';
import 'package:podium/logic/game_filter.dart';
import 'package:podium/models/game.dart';
import 'package:podium/models/game_themes.dart';
import 'package:podium/repositories/games_repository.dart';

Game _game(String id, {String category = 'Société', int? min, int? max, List<String> themes = const []}) => Game(
      id: id,
      name: id,
      emoji: '🎲',
      category: category,
      rules: const [GameRule(id: 'default', name: 'Standard', countType: CountType.highWins)],
      minPlayers: min,
      maxPlayers: max,
      themes: themes,
    );

void main() {
  final wonders = _game('wonders', min: 3, max: 7, themes: ['strategie', 'draft', 'antiquite']);
  final duel = _game('duel', min: 2, max: 2, themes: ['duel', 'strategie', 'draft']);
  final bare = _game('bare');

  test('an empty filter keeps everything and is inactive', () {
    const f = GameFilter();
    expect(f.isActive, isFalse);
    expect(f.apply([wonders, duel, bare]), [wonders, duel, bare]);
  });

  test('the player count keeps games that accept it, and games with no bounds', () {
    final two = const GameFilter().withPlayers(2);
    expect(two.apply([wonders, duel, bare]), [duel, bare]);
    expect(const GameFilter().withPlayers(5).apply([wonders, duel, bare]), [wonders, bare]);
    expect(two.withPlayers(null).isActive, isFalse);
  });

  test('several themes must all be carried (AND)', () {
    expect(const GameFilter().withThemes({'strategie'}).apply([wonders, duel, bare]), [wonders, duel]);
    expect(const GameFilter().withThemes({'strategie', 'duel'}).apply([wonders, duel, bare]), [duel]);
    expect(const GameFilter().withThemes({'strategie'}).withPlayers(4).apply([wonders, duel, bare]), [wonders]);
  });

  test('a theme the category does not offer never matches', () {
    // "escapeGame" is a Société theme — stale on a Cartes game, it is ignored.
    final stale = _game('stale', category: 'Cartes', themes: ['escapeGame']);
    expect(const GameFilter().withThemes({'escapeGame'}).apply([stale]), isEmpty);
  });

  test('themesInUse lists each carried tag once, grouped and sorted', () {
    final groups = themesInUse([wonders, duel, bare]);
    expect(groups.keys, [ThemeGroup.format, ThemeGroup.genre, ThemeGroup.mecanique, ThemeGroup.univers]);
    expect(groups[ThemeGroup.genre]!.map((t) => t.id), ['strategie']);
    expect(groups[ThemeGroup.format]!.map((t) => t.id), ['duel']);
  });

  test('hasFilterableData is false until some game has a theme or player bounds', () {
    expect(hasFilterableData([bare]), isFalse);
    expect(hasFilterableData([bare, _game('x', max: 4)]), isTrue);
    expect(hasFilterableData([bare, _game('y', themes: ['strategie'])]), isTrue);
  });

  test('every default game only carries themes its category offers', () {
    for (final g in kDefaultGames) {
      expect(g.themeTags.length, g.themes.length, reason: '${g.name} has a theme id its category does not offer');
      expect(g.playersLabel, isNotNull, reason: '${g.name} should state its player count');
    }
  });
}
