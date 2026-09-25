import 'package:flutter_test/flutter_test.dart';
import 'package:podium/models/game.dart';
import 'package:podium/models/match.dart';
import 'package:podium/state/new_game_draft.dart';

void main() {
  test('a game\'s per-player choice survives a Firestore round-trip, and is omitted when off', () {
    const game = Game(
      id: '7w',
      name: '7 Wonders',
      emoji: '🎲',
      category: 'Société',
      rules: [GameRule(id: 'default', name: 'Standard', countType: CountType.highWins)],
      characterChoice: CharacterChoice(label: 'Merveille', feminine: true, options: ['Babylone', 'Rhodes']),
    );
    final restored = Game.fromDoc('7w', game.toMap());
    expect(restored.characterChoice!.label, 'Merveille');
    expect(restored.characterChoice!.feminine, isTrue);
    expect(restored.characterChoice!.options, ['Babylone', 'Rhodes']);
    expect(restored.hasCharacters, isTrue);
    expect(restored.copyWith().characterChoice!.options, ['Babylone', 'Rhodes']);

    final plain = Game.fromDoc('x', const Game(id: 'x', name: 'X', emoji: '🎲', category: 'Autre', rules: [GameRule(id: 'd', name: 'S', countType: CountType.highWins)]).toMap());
    expect(plain.characterChoice, isNull);
    expect(plain.hasCharacters, isFalse);
  });

  test('the choice\'s wording follows its name and gender', () {
    const wonder = CharacterChoice(label: 'Merveille', feminine: true);
    expect(wonder.pickPrompt, 'Choisir une merveille');
    expect(wonder.ofPlayer('Léa'), 'Merveille de Léa');
    expect(wonder.takenBy('Tom'), 'Déjà prise par Tom');
    const hero = CharacterChoice(label: 'Héros');
    expect(hero.pickPrompt, 'Choisir un héros');
    expect(hero.takenBy('Tom'), 'Déjà pris par Tom');
    expect(CharacterChoice.fromMap(const {'label': '  '}).label, CharacterChoice.defaultLabel);
  });

  test('a match entry keeps its character through toMap/fromMap and withCharacter', () {
    const entry = MatchEntry(playerId: 'tom', points: 3, teamId: 'A', role: 'Président');
    final withChar = entry.withCharacter('Pyromancien');
    expect(withChar.points, 3);
    expect(withChar.teamId, 'A');
    expect(withChar.role, 'Président');
    expect(MatchEntry.fromMap(withChar.toMap()).character, 'Pyromancien');
    expect(entry.toMap().containsKey('character'), isFalse);
  });

  test('the draft persists picked characters locally', () {
    final draft = NewGameDraft(playerIds: ['tom', 'lea'], characters: {'tom': 'Barbare'});
    expect(NewGameDraft.fromJson(draft.toJson()).characters, {'tom': 'Barbare'});
  });

  test('the game form only saves a choice while switched on, with at least one option', () {
    final form = GameFormDraft(name: 'Dice Throne', characterLabel: ' ', characters: [' Barbare ', '', 'Moine', 'Barbare']);
    expect(form.cleanCharacterChoice, isNull, reason: 'switch off');
    expect(form.isValid, isTrue);

    form.characterEnabled = true;
    expect(form.cleanCharacterChoice!.options, ['Barbare', 'Moine']);
    expect(form.cleanCharacterChoice!.label, CharacterChoice.defaultLabel, reason: 'blank name falls back');

    form.characters = [' '];
    expect(form.charactersValid, isFalse);
    expect(form.isValid, isFalse);
  });
}
