import 'package:flutter_test/flutter_test.dart';
import 'package:podium/models/game.dart';
import 'package:podium/models/match.dart';
import 'package:podium/state/new_game_draft.dart';

void main() {
  const plainRules = [GameRule(id: 'default', name: 'Standard', countType: CountType.highWins)];

  test('a game\'s setup choice survives a Firestore round-trip and copyWith, and is omitted when unset', () {
    const game = Game(
      id: 'dom',
      name: 'Dominion',
      emoji: '🃏',
      category: 'Société',
      rules: plainRules,
      setupChoice: SetupChoice(label: 'Cartes Royaume', options: ['Chapelle', 'Village'], count: 10),
    );
    final restored = Game.fromDoc('dom', game.toMap());
    expect(restored.setupChoice!.label, 'Cartes Royaume');
    expect(restored.setupChoice!.options, ['Chapelle', 'Village']);
    expect(restored.setupChoice!.count, 10);
    expect(restored.hasSetupChoice, isTrue);
    expect(restored.copyWith().setupChoice!.options, ['Chapelle', 'Village']);

    const plain = Game(id: 'x', name: 'X', emoji: '🎲', category: 'Autre', rules: plainRules);
    expect(plain.toMap().containsKey('setupChoice'), isFalse);
    expect(Game.fromDoc('x', plain.toMap()).hasSetupChoice, isFalse);
    expect(SetupChoice.fromMap(const {'label': ' ', 'options': ['A']}).label, SetupChoice.defaultLabel);
    expect(SetupChoice.fromMap(const {'options': ['A']}).count, isNull);
  });

  test('a match keeps its setup picks through toMap/fromDoc and copies', () {
    final match = GameMatch(
      id: 'm',
      gameId: 'dom',
      groupId: 'g',
      mode: 'ffa',
      unit: 'points',
      lowWins: false,
      entries: const [],
      timeline: const [],
      createdAt: DateTime(2026, 9, 27),
      setupPicks: const ['Chapelle'],
    );
    final map = match.toMap();
    expect(GameMatch.fromDoc('m', map).setupPicks, ['Chapelle']);
    expect(match.copyWithId('n').setupPicks, ['Chapelle']);
    expect(match.copyWith(seriesEndedEarly: true).setupPicks, ['Chapelle']);
    expect(GameMatch.fromDoc('m', {...map}..remove('setupPicks')).setupPicks, isEmpty);
  });

  test('the draft persists ticked setup picks locally', () {
    final draft = NewGameDraft(setupPicks: ['Chapelle']);
    expect(NewGameDraft.fromJson(draft.toJson()).setupPicks, ['Chapelle']);
    expect(NewGameDraft.fromJson(const {}).setupPicks, isEmpty);
  });

  test('the game form trims options, needs at least one to save a choice, and checks the count', () {
    final form = GameFormDraft(name: 'Dominion', setupLabel: ' ', setupOptions: [' Chapelle ', '', 'Village', 'Chapelle']);
    expect(form.cleanSetupChoice!.options, ['Chapelle', 'Village']);
    expect(form.cleanSetupChoice!.label, SetupChoice.defaultLabel, reason: 'blank name falls back');
    expect(form.cleanSetupChoice!.count, isNull);

    form.setupCount = '10';
    expect(form.cleanSetupChoice!.count, 10);
    form.setupCount = '0';
    expect(form.setupCountValid, isFalse);
    expect(form.isValid, isFalse);

    form.setupOptions = [' '];
    expect(form.cleanSetupChoice, isNull);
  });
}
