import 'package:flutter_test/flutter_test.dart';
import 'package:podium/logic/elo.dart';
import 'package:podium/models/match.dart';

GameMatch _match(String id, List<MatchEntry> entries, {String mode = 'ffa', bool lowWins = false, DateTime? at}) => GameMatch(
      id: id,
      gameId: 'g',
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
  test('a duel between equal ratings moves both by K/2', () {
    final r = computeElo([_match('m', [_e('a', 10), _e('b', 5)])]);
    expect(r.ratings['a'], closeTo(kEloStart + kEloK / 2, 1e-9));
    expect(r.ratings['b'], closeTo(kEloStart - kEloK / 2, 1e-9));
    expect(r.played, {'a': 1, 'b': 1});
  });

  test('a tie between equal ratings changes nothing', () {
    final r = computeElo([_match('m', [_e('a', 7), _e('b', 7)])]);
    expect(r.ratings['a'], closeTo(kEloStart, 1e-9));
    expect(r.ratings['b'], closeTo(kEloStart, 1e-9));
  });

  test('lowWins: the lowest score wins', () {
    final r = computeElo([_match('m', [_e('a', 10), _e('b', 5)], lowWins: true)]);
    expect(r.ratings['b']! > r.ratings['a']!, isTrue);
  });

  test('free-for-all is zero-sum and ordered by finishing place', () {
    final r = computeElo([_match('m', [_e('a', 40), _e('b', 30), _e('c', 20), _e('d', 10)])]);
    final d = r.deltas['m']!;
    expect(d.values.reduce((x, y) => x + y), closeTo(0, 1e-9));
    expect(d['a']! > d['b']! && d['b']! > d['c']! && d['c']! > d['d']!, isTrue);
    // Winning a 4-player game weighs the same as winning a duel.
    expect(d['a'], closeTo(kEloK / 2, 1e-9));
  });

  test('team members all get their team\'s change', () {
    final r = computeElo([
      _match('m', [_e('a1', 10, 'A'), _e('a2', 15, 'A'), _e('b1', 30, 'B'), _e('b2', 5, 'B')], mode: 'team'),
    ]);
    final d = r.deltas['m']!;
    expect(d['b1'], closeTo(kEloK / 2, 1e-9));
    expect(d['b2'], d['b1']);
    expect(d['a1'], closeTo(-kEloK / 2, 1e-9));
    expect(d['a2'], d['a1']);
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
    final inOrder = computeElo([first, second]);
    final shuffled = computeElo([second, first]);
    expect(shuffled.ratings, inOrder.ratings);
    // b had already lost to a when facing c, so c (still at the start rating) was favoured.
    expect(inOrder.deltas['m2']!['b']! > kEloK / 2, isTrue);
  });

  test('beating a higher-rated player earns more', () {
    final r = computeElo([
      _match('m1', [_e('strong', 10), _e('x', 0)], at: DateTime(2026, 1, 1)),
      _match('m2', [_e('upset', 10), _e('strong', 0)], at: DateTime(2026, 1, 2)),
      _match('m3', [_e('easy', 10), _e('x', 0)], at: DateTime(2026, 1, 3)),
    ]);
    expect(r.deltas['m2']!['upset']! > r.deltas['m3']!['easy']!, isTrue);
  });
}
