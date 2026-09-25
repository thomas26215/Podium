import 'package:flutter_test/flutter_test.dart';
import 'package:podium/logic/game_sort.dart';
import 'package:podium/models/game.dart';
import 'package:podium/models/match.dart';

Game _game(String id, String name) => Game(
      id: id,
      name: name,
      emoji: '🎲',
      category: 'Société',
      rules: const [GameRule(id: 'default', name: 'Standard', countType: CountType.highWins)],
    );

GameMatch _match(String gameId, DateTime at) => GameMatch(
      id: '$gameId-${at.millisecondsSinceEpoch}',
      gameId: gameId,
      groupId: 'g',
      mode: 'ffa',
      unit: 'points',
      lowWins: false,
      entries: const [],
      timeline: const [],
      createdAt: at,
    );

void main() {
  final catan = _game('catan', 'Catan');
  final uno = _game('uno', 'Uno');
  final skyjo = _game('skyjo', 'Skyjo');
  final ecole = _game('ecole', 'École des sorciers');
  final never = _game('never', 'Azul');
  final games = [catan, uno, skyjo, ecole, never];

  // Uno: 3 games, last one 2 days ago. Catan: 1 game, yesterday. Skyjo: 3
  // games, last one 5 days ago. École: 1 game, 10 days ago. Azul: never played.
  final now = DateTime(2026, 9, 24);
  final usage = gameUsage([
    _match('uno', now.subtract(const Duration(days: 9))),
    _match('uno', now.subtract(const Duration(days: 4))),
    _match('uno', now.subtract(const Duration(days: 2))),
    _match('catan', now.subtract(const Duration(days: 1))),
    _match('skyjo', now.subtract(const Duration(days: 20))),
    _match('skyjo', now.subtract(const Duration(days: 8))),
    _match('skyjo', now.subtract(const Duration(days: 5))),
    _match('ecole', now.subtract(const Duration(days: 10))),
  ]);

  test('gameUsage counts matches and keeps the most recent date', () {
    expect(usage['uno']!.playCount, 3);
    expect(usage['uno']!.lastPlayed, now.subtract(const Duration(days: 2)));
    expect(usage.containsKey('never'), isFalse);
  });

  test('last played: most recent first, never-played games last', () {
    expect(sortGames(games, GameSort.lastPlayed, usage).map((g) => g.id), ['catan', 'uno', 'skyjo', 'ecole', 'never']);
  });

  test('play count: most played first, ties broken by recency, never-played last', () {
    // Uno and Skyjo both have 3 (Uno is more recent); Catan and École both have 1 (Catan is more recent).
    expect(sortGames(games, GameSort.playCount, usage).map((g) => g.id), ['uno', 'skyjo', 'catan', 'ecole', 'never']);
  });

  test('name: alphabetical, ignoring accents and case', () {
    expect(sortGames(games, GameSort.name, usage).map((g) => g.id), ['never', 'catan', 'ecole', 'skyjo', 'uno']);
  });

  test('games never played fall back to name order under the usage sorts', () {
    final a = _game('a', 'Bravo');
    final b = _game('b', 'Alpha');
    expect(sortGames([a, b], GameSort.lastPlayed, const {}).map((g) => g.id), ['b', 'a']);
    expect(sortGames([a, b], GameSort.playCount, const {}).map((g) => g.id), ['b', 'a']);
  });
}
