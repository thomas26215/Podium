import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podium/models/game.dart';
import 'package:podium/models/match.dart';
import 'package:podium/state/new_game_draft.dart';

void main() {
  const plainRules = [GameRule(id: 'default', name: 'Standard', countType: CountType.highWins)];

  test('a game\'s expansions survive a Firestore round-trip and copyWith, and are omitted when empty', () {
    const game = Game(id: 'dom', name: 'Dominion', emoji: '🃏', category: 'Société', rules: plainRules, expansions: ['Intrigue', 'Rivages']);
    final restored = Game.fromDoc('dom', game.toMap());
    expect(restored.expansions, ['Intrigue', 'Rivages']);
    expect(restored.hasExpansions, isTrue);
    expect(restored.copyWith().expansions, ['Intrigue', 'Rivages']);

    const plain = Game(id: 'x', name: 'X', emoji: '🎲', category: 'Autre', rules: plainRules);
    expect(plain.toMap().containsKey('expansions'), isFalse);
    expect(Game.fromDoc('x', plain.toMap()).hasExpansions, isFalse);
  });

  test('a match keeps its expansions through toMap/fromDoc and copies', () {
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
      expansions: const ['Intrigue'],
    );
    final map = match.toMap();
    expect(map['createdAt'], isA<Timestamp>());
    expect(GameMatch.fromDoc('m', map).expansions, ['Intrigue']);
    expect(match.copyWithId('n').expansions, ['Intrigue']);
    expect(match.copyWith(seriesEndedEarly: true).expansions, ['Intrigue']);

    final none = GameMatch.fromDoc('m', {...map}..remove('expansions'));
    expect(none.expansions, isEmpty);
  });

  test('the draft persists ticked expansions locally', () {
    final draft = NewGameDraft(expansions: ['Intrigue']);
    expect(NewGameDraft.fromJson(draft.toJson()).expansions, ['Intrigue']);
    expect(NewGameDraft.fromJson(const {}).expansions, isEmpty);
  });

  test('the game form trims and dedupes expansions', () {
    final form = GameFormDraft(name: 'Dominion', expansions: [' Intrigue ', '', 'Rivages', 'Intrigue']);
    expect(form.cleanExpansions, ['Intrigue', 'Rivages']);
  });
}
