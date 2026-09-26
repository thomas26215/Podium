import 'package:flutter_test/flutter_test.dart';
import 'package:podium/models/match.dart';

GameMatch _match({required String mode, required bool lowWins, required List<MatchEntry> entries}) => GameMatch(
      id: 'm',
      gameId: 'g',
      groupId: 'grp',
      mode: mode,
      unit: 'points',
      lowWins: lowWins,
      entries: entries,
      timeline: const [],
      createdAt: DateTime(2026),
    );

void main() {
  const teams = [
    MatchEntry(playerId: 'a1', points: 10, teamId: 'A'),
    MatchEntry(playerId: 'a2', points: 15, teamId: 'A'),
    MatchEntry(playerId: 'b1', points: 30, teamId: 'B'),
    MatchEntry(playerId: 'b2', points: 5, teamId: 'B'),
  ];

  test('team match: the highest total wins in a regular game', () {
    expect(_match(mode: 'team', lowWins: false, entries: teams).winnerIds(), ['b1', 'b2']);
  });

  test('team match: the lowest total wins in a lowWins game (Skyjo, golf…)', () {
    expect(_match(mode: 'team', lowWins: true, entries: teams).winnerIds(), ['a1', 'a2']);
  });

  test('free-for-all: lowWins picks the lowest score, ties share the win', () {
    const entries = [
      MatchEntry(playerId: 'x', points: 12),
      MatchEntry(playerId: 'y', points: 7),
      MatchEntry(playerId: 'z', points: 7),
    ];
    expect(_match(mode: 'ffa', lowWins: true, entries: entries).winnerIds(), ['y', 'z']);
    expect(_match(mode: 'ffa', lowWins: false, entries: entries).winnerIds(), ['x']);
  });
}
