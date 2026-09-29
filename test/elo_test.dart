import 'package:flutter_test/flutter_test.dart';
import 'package:podium/logic/elo.dart';
import 'package:podium/models/match.dart';

GameMatch _match(String id, List<MatchEntry> entries, {String mode = 'ffa', bool lowWins = false, DateTime? at, String game = 'g'}) => GameMatch(
      id: id,
      gameId: game,
      groupId: 'grp',
      mode: mode,
      unit: 'points',
      lowWins: lowWins,
      entries: entries,
      timeline: const [],
      createdAt: at ?? DateTime(2026),
    );

MatchEntry _e(String id, int points, [String? team]) => MatchEntry(playerId: id, points: points, teamId: team);

void main() {
  test('a newcomer is shown at the start rating', () {
    expect(displayRating(25, 25 / 3), closeTo(kEloStart, 1e-9));
  });

  test('a duel: the winner climbs, the loser drops, never below 0', () {
    final r = computeElo([_match('m', [_e('a', 10), _e('b', 5)])]);
    expect(r.ratings['a']!, greaterThan(kEloStart));
    expect(r.ratings['b']!, lessThan(kEloStart));
    expect(r.ratings['b']!, greaterThanOrEqualTo(0));
    expect(r.played, {'a': 1, 'b': 1});
    expect(r.deltas['m']!['a'], closeTo(r.ratings['a']! - kEloStart, 1e-9));
  });

  test('a tie between newcomers moves both the same way', () {
    final r = computeElo([_match('m', [_e('a', 7), _e('b', 7)])]);
    expect(r.ratings['a'], closeTo(r.ratings['b']!, 1e-9));
  });

  test('lowWins: the lowest score wins', () {
    final r = computeElo([_match('m', [_e('a', 10), _e('b', 5)], lowWins: true)]);
    expect(r.ratings['b']! > r.ratings['a']!, isTrue);
  });

  test('free-for-all: the better the finishing place, the bigger the gain', () {
    final r = computeElo([_match('m', [_e('a', 40), _e('b', 30), _e('c', 20), _e('d', 10)])]);
    final d = r.deltas['m']!;
    expect(d['a']! > d['b']! && d['b']! > d['c']! && d['c']! > d['d']!, isTrue);
  });

  test('team members of equal standing all get the same change', () {
    final r = computeElo([
      _match('m', [_e('a1', 10, 'A'), _e('a2', 15, 'A'), _e('b1', 30, 'B'), _e('b2', 5, 'B')], mode: 'team'),
    ]);
    final d = r.deltas['m']!;
    expect(d['b1']!, greaterThan(0));
    expect(d['b2'], closeTo(d['b1']!, 1e-9));
    expect(d['a1']!, lessThan(d['b1']!));
    expect(d['a2'], closeTo(d['a1']!, 1e-9));
  });

  test('coop and solo matches are not rated', () {
    final r = computeElo([
      _match('coop', [_e('a', 1), _e('b', 1)], mode: 'coop'),
      _match('solo', [_e('a', 120)]),
      _match('oneTeam', [_e('a', 1, 'A'), _e('b', 2, 'A')], mode: 'team'),
    ]);
    expect(r.ratings, isEmpty);
    expect(r.deltas, isEmpty);
  });

  test('matches are replayed oldest-first whatever the input order', () {
    final first = _match('m1', [_e('a', 10), _e('b', 0)], at: DateTime(2026, 1, 1));
    final second = _match('m2', [_e('b', 10), _e('c', 0)], at: DateTime(2026, 1, 2));
    expect(computeElo([second, first]).ratings, computeElo([first, second]).ratings);
  });

  test('beating a stronger player earns more', () {
    final r = computeElo([
      for (var i = 0; i < 5; i++) _match('s$i', [_e('strong', 10), _e('x', 0)], at: DateTime(2026, 1, 1, i)),
      _match('upset', [_e('u1', 10), _e('strong', 0)], at: DateTime(2026, 1, 2)),
      _match('easy', [_e('u2', 10), _e('x', 0)], at: DateTime(2026, 1, 3)),
    ]);
    expect(r.deltas['upset']!['u1']! > r.deltas['easy']!['u2']!, isTrue);
  });

  test('evenly matched regulars both climb as their level becomes known', () {
    final r = computeElo([
      for (var i = 0; i < 60; i++) _match('m$i', [_e('a', i.isEven ? 10 : 0), _e('b', i.isEven ? 0 : 10)], at: DateTime(2026, 1, 1, 0, i)),
    ]);
    expect(r.ratings['a']!, greaterThan(1000));
    expect(r.ratings['b']!, greaterThan(1000));
  });

  group('history and records', () {
    final r = computeElo([
      _match('m1', [_e('a', 10), _e('b', 0)], at: DateTime(2026, 1, 1)),
      _match('m2', [_e('a', 10), _e('b', 0)], at: DateTime(2026, 1, 2)),
      _match('m3', [_e('b', 10), _e('a', 0)], at: DateTime(2026, 1, 3)),
    ]);

    test('each rated match adds a point to its players\' history', () {
      expect(r.history['a']!.map((p) => p.matchId), ['m1', 'm2', 'm3']);
      expect(r.history['a']!.last.rating, closeTo(r.ratings['a']!, 1e-9));
      expect(r.history['a']![1].delta, closeTo(r.deltas['m2']!['a']!, 1e-9));
    });

    test('records: peak, best gain, streaks and upsets', () {
      final a = eloRecordsOf(r, 'a');
      expect(a.longestStreak, 2);
      expect(a.currentStreak, 0);
      expect(a.peak!.matchId, 'm2');
      expect(a.upset, isNull, reason: 'a was never the lower-rated side when finishing ahead');
      final b = eloRecordsOf(r, 'b');
      expect(b.upset!.matchId, 'm3');
      expect(b.upset!.opponentIds, ['a']);
      expect(b.upset!.gap, greaterThan(0));
    });
  });

  test('tiers follow the rating bands', () {
    expect(eloTier(0).name, 'Bronze');
    expect(eloTier(kEloStart).name, 'Bronze');
    expect(eloTier(1000).name, 'Or');
    expect(eloTier(2500).name, 'Diamant');
    expect(nextEloTier(1200)!.name, 'Platine');
    expect(nextEloTier(2500), isNull);
  });

  test('win chances favour the stronger side and add up to 1', () {
    final r = computeElo([for (var i = 0; i < 5; i++) _match('m$i', [_e('strong', 10), _e('weak', 0)], at: DateTime(2026, 1, 1, i))]);
    final chances = eloWinChances(r, [['strong'], ['weak'], ['new']]);
    expect(chances.reduce((a, b) => a + b), closeTo(1, 1e-9));
    expect(chances[0], greaterThan(chances[2]));
    expect(chances[2], greaterThan(chances[1]));
  });

  test('balanced teams split the strongest players apart', () {
    final r = computeElo([
      for (var i = 0; i < 6; i++) _match('m$i', [_e('s1', 30), _e('s2', 20), _e('w1', 10), _e('w2', 0)], at: DateTime(2026, 1, 1, i)),
    ]);
    final teams = balanceEloTeams(r, ['s1', 's2', 'w1', 'w2'], 2);
    expect(teams.values.where((t) => t == 'A').length, 2);
    expect(teams['s1'], isNot(teams['s2']));
    expect(teams['s1'], teams['w2'], reason: 'the best player gets the weakest partner');
    expect(balanceEloTeams(r, ['s1', 's2', 'w1'], 2).values.toSet(), {'A', 'B'});
  });

  group('per-game ratings', () {
    // a has beaten b five times at "g" — clearly the stronger one there.
    final history = [for (var i = 0; i < 5; i++) _match('p$i', [_e('a', 10), _e('b', 0)], at: DateTime(2026, 1, 1, i))];
    double gain(String winner, String loser, String game) {
      final r = computeElo([...history, _match('last', [_e(winner, 10), _e(loser, 0)], at: DateTime(2026, 1, 2), game: game)]);
      return r.deltas['last']![winner]!;
    }

    test('each game keeps its own rating', () {
      final r = computeElo([
        _match('m1', [_e('a', 10), _e('b', 0)], game: 'chess'),
        _match('m2', [_e('b', 10), _e('a', 0)], at: DateTime(2026, 1, 2), game: 'darts'),
      ]);
      expect(r.gameRatings['chess']!['a']!, greaterThan(r.gameRatings['chess']!['b']!));
      expect(r.gameRatings['darts']!['b']!, greaterThan(r.gameRatings['darts']!['a']!));
      expect(r.gamePlayed['chess'], {'a': 1, 'b': 1});
    });

    test('an expected result on the game moves the global rating less', () {
      expect(gain('a', 'b', 'g'), lessThan(gain('a', 'b', 'fresh')));
    });

    test('an upset on the game moves the global rating more', () {
      expect(gain('b', 'a', 'g'), greaterThan(gain('b', 'a', 'fresh')));
    });
  });

  group('game-aware skills', () {
    // b dominates globally (darts), but a has always beaten b at chess.
    final r = computeElo([
      for (var i = 0; i < 20; i++) _match('d$i', [_e('b', 10), _e('a', 0)], at: DateTime(2026, 1, 1, 0, i), game: 'darts'),
      for (var i = 0; i < 10; i++) _match('c$i', [_e('a', 10), _e('b', 0)], at: DateTime(2026, 1, 2, 0, i), game: 'chess'),
    ]);

    test('predictions lean on the picked game', () {
      final global = eloWinChances(r, [['a'], ['b']]);
      final chess = eloWinChances(r, [['a'], ['b']], gameId: 'chess');
      expect(chess[0], greaterThan(global[0]));
      expect(chess[0], greaterThan(0.5), reason: 'a is the chess favourite');
    });

    test('a game nobody played falls back to the global skill', () {
      expect(eloWinChances(r, [['a'], ['b']], gameId: 'go'), eloWinChances(r, [['a'], ['b']]));
    });

    test('each game keeps its own curve and records', () {
      expect(r.gameHistory['chess']!['a']!.length, 10);
      expect(r.gameHistory['chess']!['a']!.last.rating, closeTo(r.gameRatings['chess']!['a']!, 1e-9));
      final chessRecords = eloRecordsOf(r, 'a', gameId: 'chess');
      expect(chessRecords.longestStreak, 10);
      expect(chessRecords.upset, isNull, reason: 'upsets are global only');
    });
  });
}
