import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:podium/models/game.dart';
import 'package:podium/models/game_themes.dart';

/// Guards tool/game_library.json, the seed for the shared `gameLibrary`
/// collection: every game must load through [Game.fromDoc] exactly as the
/// app will read it, with every field filled in.
void main() {
  final raw = jsonDecode(File('tool/game_library.json').readAsStringSync()) as Map<String, dynamic>;
  final games = [for (final e in raw.entries) Game.fromDoc(e.key, Map<String, dynamic>.from(e.value as Map))];

  test('the library is not empty and names are unique', () {
    expect(games, isNotEmpty);
    final names = games.map((g) => g.name.toLowerCase()).toList();
    expect(names.toSet().length, names.length);
  });

  test('an imported copy keeps its library link until it is edited', () {
    final copy = Game.fromDoc('abc', {...games.first.toMap(), 'libraryId': games.first.id});
    expect(copy.followsLibrary, isTrue);
    expect(Game.fromDoc(copy.id, copy.toMap()).libraryId, games.first.id);
    expect(copy.copyWith(ruleSections: const []).libraryId, games.first.id);
    final edited = copy.copyWith(ruleSections: const [], detachFromLibrary: true);
    expect(edited.followsLibrary, isFalse);
    expect(edited.toMap().containsKey('libraryId'), isFalse);
  });

  for (final game in games) {
    group(game.name, () {
      test('basics', () {
        expect(game.id, matches(RegExp(r'^[a-z0-9_]+$')));
        expect(Game.categories, contains(game.category));
        expect(game.emoji, isNotEmpty);
        expect(game.minPlayers, isNotNull);
        expect(game.maxPlayers, isNotNull);
        expect(game.minPlayers!, greaterThanOrEqualTo(1));
        expect(game.maxPlayers!, greaterThanOrEqualTo(game.minPlayers!));
      });

      test('themes all belong to the category', () {
        final offered = themesForCategory(game.category).map((t) => t.id).toSet();
        if (offered.isNotEmpty) expect(game.themes, isNotEmpty);
        for (final t in game.themes) {
          expect(offered, contains(t), reason: 'theme "$t" is not offered for ${game.category}');
        }
        expect(game.themes.toSet().length, game.themes.length);
      });

      test('rules are consistent', () {
        expect(game.rules, isNotEmpty);
        expect(game.rules.map((r) => r.id).toSet().length, game.rules.length);
        for (final r in game.rules) {
          expect(r.name, isNotEmpty);
          if (r.pointLimit != null) {
            expect([CountType.highWins, CountType.lowWins], contains(r.countType), reason: '${r.id}: pointLimit needs a points count');
          }
          if (r.coop) expect(r.countType, isNot(CountType.ranks));
          if (!r.isRanks) {
            expect(r.topRoles, isNull);
            expect(r.bottomRoles, isNull);
          }
          expect(r.topPoints?.length, r.topRoles?.length);
          expect(r.bottomPoints?.length, r.bottomRoles?.length);
          if (r.hasScoreFields) {
            final ids = r.scoreFields!.map((f) => f.id).toList();
            expect(ids.toSet().length, ids.length);
            expect(r.countType, isNot(CountType.winLoss));
          }
        }
      });

      test('rules reminders are filled in', () {
        expect(game.ruleSections, isNotEmpty);
        for (final s in game.ruleSections) {
          expect(s.title, isNotEmpty);
          expect(s.rules, isNotEmpty);
          for (final rule in s.rules) {
            expect(rule.trim(), isNotEmpty);
          }
        }
      });

      test('character choice, when set, has options', () {
        final c = game.characterChoice;
        if (c == null) return;
        expect(c.options, isNotEmpty);
        expect(c.options.toSet().length, c.options.length);
      });

      test('survives a Firestore round-trip', () {
        final again = Game.fromDoc(game.id, game.toMap());
        expect(again.toMap(), game.toMap());
      });
    });
  }
}
