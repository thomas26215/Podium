import 'package:flutter_test/flutter_test.dart';
import 'package:podium/models/game.dart';
import 'package:podium/models/game_themes.dart';
import 'package:podium/state/new_game_draft.dart';

Game _game({int? min, int? max, List<String> themes = const [], String category = 'Société'}) => Game(
      id: 'g',
      name: 'Dixit',
      emoji: '🎲',
      category: category,
      rules: const [GameRule(id: 'default', name: 'Standard', countType: CountType.highWins)],
      minPlayers: min,
      maxPlayers: max,
      themes: themes,
    );

void main() {
  test('every category with a theme list has unique ids, and Autre has none', () {
    for (final category in Game.categories) {
      final ids = themesForCategory(category).map((t) => t.id).toList();
      expect(ids.toSet().length, ids.length, reason: '$category ids must be unique');
    }
    expect(themesForCategory('Société').map((t) => t.id), containsAll(['duel', 'strategie', 'roles', 'gestion', 'tcg']));
    for (final category in ['Société', 'Cartes', 'Jeu vidéo', 'Sport']) {
      expect(themesForCategory(category).length, greaterThan(45), reason: '$category has a rich theme list');
      expect(themesByGroup(category)[ThemeGroup.format]!.map((t) => t.id), contains('duel'), reason: '$category offers a duel format');
    }
    expect(themesForCategory('Jeu vidéo').map((t) => t.id), contains('combat'));
    expect(themesForCategory('Autre'), isEmpty);
  });

  test('player count and themes survive a Firestore round-trip', () {
    final restored = Game.fromDoc('g', _game(min: 2, max: 4, themes: ['strategie', 'tcg']).toMap());
    expect(restored.minPlayers, 2);
    expect(restored.maxPlayers, 4);
    expect(restored.themes, ['strategie', 'tcg']);
  });

  test('a game saved without them has no player bounds and no themes', () {
    final map = _game().toMap();
    expect(map.containsKey('minPlayers'), isFalse);
    expect(map.containsKey('themes'), isFalse);
    final restored = Game.fromDoc('g', map);
    expect(restored.playersLabel, isNull);
    expect(restored.themeTags, isEmpty);
    expect(restored.acceptsPlayerCount(9), isTrue);
  });

  test('playersLabel and acceptsPlayerCount', () {
    expect(_game(min: 2, max: 4).playersLabel, '2–4 joueurs');
    expect(_game(min: 3, max: 3).playersLabel, '3 joueurs');
    expect(_game(min: 2).playersLabel, '2 joueurs min.');
    expect(_game(max: 4).playersLabel, '4 joueurs max.');
    final g = _game(min: 2, max: 4);
    expect(g.acceptsPlayerCount(2), isTrue);
    expect(g.acceptsPlayerCount(4), isTrue);
    expect(g.acceptsPlayerCount(5), isFalse);
    expect(g.acceptsPlayerCount(1), isFalse);
  });

  test('themeTags ignores ids the category does not offer', () {
    final tags = _game(themes: ['strategie', 'combat', 'nimportequoi'], category: 'Société').themeTags;
    expect(tags.map((t) => t.id), ['strategie', 'combat']);
    expect(_game(themes: ['strategie'], category: 'Autre').themeTags, isEmpty);
  });

  test('the form rejects an invalid player range and drops foreign theme tags', () {
    final form = GameFormDraft(name: 'Dixit');
    expect(form.playersValid, isTrue, reason: 'both bounds are optional');
    form.minPlayers = '5';
    form.maxPlayers = '3';
    expect(form.isValid, isFalse, reason: 'min above max');
    form.minPlayers = '1';
    form.maxPlayers = '';
    expect(form.playersValid, isFalse, reason: 'no solo matches');
    form.minPlayers = '2';
    form.maxPlayers = '4';
    expect(form.isValid, isTrue);

    form.themes = ['escapeGame', 'strategie'];
    form.category = 'Cartes';
    expect(form.cleanThemes, ['strategie'], reason: 'escapeGame is a board-game theme only');
  });
}
