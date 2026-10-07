import 'dart:math' as math;

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

/// [n] duels a/b, a winning [aWins] of each 10, a match an hour apart.
List<GameMatch> _duels(String a, String b, int n, {int aWins = 5, String game = 'g', DateTime? from, String prefix = 'd'}) => [
      for (var i = 0; i < n; i++)
        _match('$prefix$i', [_e(a, i % 10 < aWins ? 1 : 0), _e(b, i % 10 < aWins ? 0 : 1)], at: (from ?? DateTime(2026)).add(Duration(hours: i)), game: game),
    ];

void main() {
  test('a duel: the winner climbs, the loser drops a little', () {
    final r = computeElo([_match('m', [_e('a', 10), _e('b', 5)])]);
    expect(r.ratings['a']!, greaterThan(kEloStart + 50));
    expect(r.ratings['b']!, lessThan(kEloStart));
    expect(r.ratings['b']!, greaterThan(kEloStart - 20), reason: 'a first loss no longer sends anyone to 0');
    expect(r.played, {'a': 1, 'b': 1});
    expect(r.deltas['m']!['a'], closeTo(r.ratings['a']! - kEloStart, 1e-9));
  });

  test('a draw between newcomers moves both alike, by half a win\'s progression', () {
    final r = computeElo([_match('m', [_e('a', 7), _e('b', 7)])]);
    final win = computeElo([_match('m', [_e('a', 8), _e('b', 7)])]).deltas['m']!['a']!;
    expect(r.ratings['a'], closeTo(r.ratings['b']!, 1e-9));
    expect(r.deltas['m']!['a']!, greaterThan(0));
    expect(r.deltas['m']!['a']!, lessThan(win / 2));
    expect(r.played, {'a': 1, 'b': 1});
  });

  test('lowWins: the lowest score wins', () {
    final r = computeElo([_match('m', [_e('a', 10), _e('b', 5)], lowWins: true)]);
    expect(r.ratings['b']! > r.ratings['a']!, isTrue);
  });

  test('free-for-all: the better the finishing place, the better the change', () {
    final r = computeElo([_match('m', [_e('a', 40), _e('b', 30), _e('c', 20), _e('d', 10)])]);
    final d = r.deltas['m']!;
    expect(d['a']! > d['b']! && d['b']! > d['c']! && d['c']! > d['d']!, isTrue);
    expect(d['a']!, greaterThan(0));
    expect(d['d']!, lessThan(0));
  });

  test('team members of equal standing all get the same change', () {
    final r = computeElo([
      _match('m', [_e('a1', 10, 'A'), _e('a2', 15, 'A'), _e('b1', 30, 'B'), _e('b2', 5, 'B')], mode: 'team'),
    ]);
    final d = r.deltas['m']!;
    expect(d['b1']!, greaterThan(0));
    expect(d['b2'], closeTo(d['b1']!, 1e-9));
    expect(d['a1']!, lessThan(0));
    expect(d['a2'], closeTo(d['a1']!, 1e-9));
  });

  test('co-winners of a free-for-all (a 2v2 entered as one) all gain, co-losers all lose', () {
    // c has dominated d: tied last with d, a weak player used to lose
    // points less, and could even gain — now they both just lost.
    final r = computeElo([
      ..._duels('c', 'd', 10, aWins: 10),
      _match('kems', [_e('a', 1), _e('b', 1), _e('c', 0), _e('d', 0)], at: DateTime(2026, 2)),
    ]);
    final d = r.deltas['kems']!;
    expect(d['a']!, greaterThan(0));
    expect(d['b']!, greaterThan(0));
    expect(d['c']!, lessThan(0));
    expect(d['d']!, lessThan(0));
  });

  test('coop, solo and all-tied matches are not rated', () {
    final r = computeElo([
      _match('coop', [_e('a', 1), _e('b', 1)], mode: 'coop'),
      _match('solo', [_e('a', 120)]),
      _match('oneTeam', [_e('a', 1, 'A'), _e('b', 2, 'A')], mode: 'team'),
      _match('allTied', [_e('a', 3), _e('b', 3), _e('c', 3)]),
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

  test('a win never costs and a loss never earns, globally or on the game', () {
    final rnd = math.Random(7);
    final players = [for (var i = 0; i < 7; i++) 'p$i'];
    final matches = <GameMatch>[];
    for (var i = 0; i < 400; i++) {
      final picked = (List.of(players)..shuffle(rnd)).take(2 + rnd.nextInt(4)).toList();
      final team = picked.length == 4 && rnd.nextBool();
      matches.add(_match(
        'm$i',
        [for (final (j, p) in picked.indexed) _e(p, rnd.nextInt(4), team ? (j < 2 ? 'A' : 'B') : null)],
        mode: team ? 'team' : 'ffa',
        lowWins: rnd.nextInt(5) == 0,
        at: DateTime(2026).add(Duration(hours: i * 7)),
        game: 'g${rnd.nextInt(3)}',
      ));
    }
    final r = computeElo(matches);
    var checked = 0;
    for (final m in matches) {
      final d = r.deltas[m.id];
      if (d == null) continue;
      final totals = <String, int>{};
      for (final e in m.entries) {
        final side = m.isTeam ? e.teamId! : e.playerId;
        totals[side] = (totals[side] ?? 0) + e.points;
      }
      final best = m.lowWins ? totals.values.reduce(math.min) : totals.values.reduce(math.max);
      final worst = m.lowWins ? totals.values.reduce(math.max) : totals.values.reduce(math.min);
      if (best == worst) continue;
      for (final e in m.entries) {
        final mine = totals[m.isTeam ? e.teamId! : e.playerId]!;
        final onGame = r.gameHistory[m.gameId]![e.playerId]!.firstWhere((p) => p.matchId == m.id).delta;
        if (mine == best) {
          expect(d[e.playerId]!, greaterThanOrEqualTo(0), reason: '${m.id}: ${e.playerId} finished first');
          expect(onGame, greaterThanOrEqualTo(0));
          checked++;
        }
        if (mine == worst) {
          expect(d[e.playerId]!, lessThanOrEqualTo(0), reason: '${m.id}: ${e.playerId} finished last');
          expect(onGame, lessThanOrEqualTo(0));
          checked++;
        }
      }
    }
    expect(checked, greaterThan(500));
  });

  group('progression', () {
    test('a newcomer losing again and again stays well clear of 0', () {
      final r = computeElo([for (var i = 0; i < 6; i++) _match('l$i', [_e('a', 1), _e('b', 0)], at: DateTime(2026, 1, 1, i))]);
      expect(r.ratings['b']!, greaterThan(kEloStart / 2));
    });

    test('evenly matched regulars climb, then settle around an average level', () {
      final r60 = computeElo(_duels('a', 'b', 60));
      expect(r60.ratings['a']!, greaterThan(1000));
      expect(r60.ratings['b']!, greaterThan(1000));
      final r300 = computeElo(_duels('a', 'b', 300));
      for (final uid in ['a', 'b']) {
        expect(r300.ratings[uid]!, closeTo(kLevelStart, 200));
      }
    });

    test('a stronger regular settles higher', () {
      final r = computeElo(_duels('a', 'b', 300, aWins: 7));
      expect(r.ratings['a']!, greaterThan(r.ratings['b']! + 200));
      expect(r.skillOf('a').mu, greaterThan(r.skillOf('b').mu));
    });

    test('below the level, gains outweigh losses; once there, they even out', () {
      final early = computeElo(_duels('a', 'b', 4, aWins: 5));
      expect(early.deltas['d0']!['a']!, greaterThan(-early.deltas['d0']!['b']! * 4), reason: 'the first win earns several times what the loss costs');
      final settled = computeElo(_duels('a', 'b', 400));
      final win = settled.deltas['d390']!['a']!, loss = settled.deltas['d390']!['b']!;
      expect(win / -loss, closeTo(1, 0.5));
    });
  });

  group('history and records', () {
    final r = computeElo([
      for (var i = 1; i <= 4; i++) _match('m$i', [_e('a', 10), _e('b', 0)], at: DateTime(2026, 1, i)),
      _match('m5', [_e('b', 10), _e('a', 0)], at: DateTime(2026, 1, 5)),
    ]);

    test('each rated match adds a point to its players\' history', () {
      expect(r.history['a']!.map((p) => p.matchId), ['m1', 'm2', 'm3', 'm4', 'm5']);
      expect(r.history['a']!.last.rating, closeTo(r.ratings['a']!, 1e-9));
      expect(r.history['a']![1].delta, closeTo(r.deltas['m2']!['a']!, 1e-9));
    });

    test('records: peak, best gain, streaks and upsets', () {
      final a = eloRecordsOf(r, 'a');
      expect(a.longestStreak, 4);
      expect(a.currentStreak, 0);
      expect(a.peak!.matchId, 'm4');
      expect(a.upset, isNull, reason: 'a was the favourite in each win');
      final b = eloRecordsOf(r, 'b');
      expect(b.upset!.matchId, 'm5');
      expect(b.upset!.opponentIds, ['a']);
      expect(b.upset!.chance, lessThan(kEloUpsetChance));
    });

    test('a narrow underdog\'s win is no exploit', () {
      final close = computeElo([
        _match('m1', [_e('a', 10), _e('b', 0)], at: DateTime(2026, 1, 1)),
        _match('m2', [_e('b', 10), _e('a', 0)], at: DateTime(2026, 1, 2)),
      ]);
      expect(close.bestUpsets, isEmpty);
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
    test('each game keeps its own rating, from its own results', () {
      final r = computeElo([
        _match('m1', [_e('a', 10), _e('b', 0)], game: 'chess'),
        _match('m2', [_e('b', 10), _e('a', 0)], at: DateTime(2026, 1, 2), game: 'darts'),
      ]);
      expect(r.gameRatings['chess']!['a']!, greaterThan(r.gameRatings['chess']!['b']!));
      expect(r.gameRatings['darts']!['b']!, greaterThan(r.gameRatings['darts']!['a']!));
      expect(r.gamePlayed['chess'], {'a': 1, 'b': 1});
    });

    test('a strong player isn\'t held back on a game where results are even', () {
      // a dominates b at chess; at cards they win in turn.
      final r = computeElo([
        ..._duels('a', 'b', 30, aWins: 9, game: 'chess'),
        for (var i = 0; i < 20; i++) _match('c$i', [_e('a', i.isEven ? 1 : 0), _e('b', i.isEven ? 0 : 1)], at: DateTime(2026, 2).add(Duration(hours: i)), game: 'cards'),
      ]);
      expect(r.gameRatings['cards']!['a']!, closeTo(r.gameRatings['cards']!['b']!, 60));
    });

    test('the same record in another order lands close', () {
      // Five wins each way, twice over: whoever won last is only a little ahead.
      final r = computeElo(_duels('a', 'b', 20));
      expect(r.gameRatings['g']!['a']!, closeTo(r.gameRatings['g']!['b']!, 100));
      expect(r.ratings['a']!, closeTo(r.ratings['b']!, 100));
    });

    test('an expected result on the game moves the global rating less than an upset there', () {
      final history = _duels('a', 'b', 10, aWins: 9);
      double gain(String winner, String loser) {
        final r = computeElo([...history, _match('last', [_e(winner, 10), _e(loser, 0)], at: DateTime(2026, 2))]);
        return r.deltas['last']![winner]!.abs();
      }
      expect(gain('a', 'b'), lessThan(gain('b', 'a')));
    });
  });

  group('game-aware levels', () {
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

    test('a game nobody played falls back on the general level, less surely', () {
      final global = eloWinChances(r, [['a'], ['b']]);
      final go = eloWinChances(r, [['a'], ['b']], gameId: 'go');
      expect((go[0] - 0.5).sign, (global[0] - 0.5).sign);
      expect((go[0] - 0.5).abs(), lessThanOrEqualTo((global[0] - 0.5).abs()));
    });

    test('each game keeps its own curve and records', () {
      expect(r.gameHistory['chess']!['a']!.length, 10);
      expect(r.gameHistory['chess']!['a']!.last.rating, closeTo(r.gameRatings['chess']!['a']!, 1e-9));
      final chessRecords = eloRecordsOf(r, 'a', gameId: 'chess');
      expect(chessRecords.longestStreak, 10);
      expect(chessRecords.upset, isNull, reason: 'upsets are global only');
    });
  });

  test('a game full of upsets is learnt as luckier, and its matches count less', () {
    // a always beats b at chess; at dice, results ignore who's better.
    final r = computeElo([
      ..._duels('a', 'b', 40, aWins: 10, game: 'chess'),
      for (var i = 0; i < 40; i++)
        _match('x$i', [_e('a', (i * 7) % 3 == 0 ? 1 : 0), _e('b', (i * 7) % 3 == 0 ? 0 : 1)], at: DateTime(2026, 3).add(Duration(hours: i)), game: 'dice'),
    ]);
    expect(r.luckOf('dice'), greaterThan(1.3));
    expect(r.luckOf('chess'), lessThan(r.luckOf('dice')));
    expect(r.luckOf('unknown'), 1);
  });
}
