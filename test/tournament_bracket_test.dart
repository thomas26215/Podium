// Unit tests for the pure bracket-construction logic in
// lib/logic/tournament_bracket.dart — no Firebase/widget dependency, so
// these run fast and pin down the bracket algorithms independently of the
// UI built on top of them.

import 'package:flutter_test/flutter_test.dart';
import 'package:podium/logic/tournament_bracket.dart';
import 'package:podium/models/match.dart';
import 'package:podium/models/tournament.dart';

BracketMatch _byId(List<BracketMatch> matches, String id) => matches.firstWhere((m) => m.id == id);

Tournament _wrap(List<BracketMatch> matches, {TournamentFormat format = TournamentFormat.singleElimination, int groupsCount = 0, int qualifiersPerGroup = 0}) {
  return Tournament(
    id: 't1',
    groupId: 'g1',
    gameId: 'catan',
    name: 'Test',
    format: format,
    entrants: [for (var i = 0; i < 8; i++) TournamentEntrant(id: 'p$i', playerIds: ['p$i'])],
    matches: matches,
    groupsCount: groupsCount,
    qualifiersPerGroup: qualifiersPerGroup,
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('bracketSizeFor', () {
    test('rounds up to the next power of two, minimum 2', () {
      expect(bracketSizeFor(2), 2);
      expect(bracketSizeFor(3), 4);
      expect(bracketSizeFor(4), 4);
      expect(bracketSizeFor(5), 8);
      expect(bracketSizeFor(8), 8);
      expect(bracketSizeFor(9), 16);
    });
  });

  group('buildSingleElimination', () {
    test('4 entrants: 2 round-1 matches + 1 final, no byes', () {
      final matches = buildSingleElimination(['p0', 'p1', 'p2', 'p3']);
      expect(matches.length, 3);
      final m0 = _byId(matches, 'W-R1-M0');
      final m1 = _byId(matches, 'W-R1-M1');
      final finalMatch = _byId(matches, 'W-R2-M0');
      expect(m0.entrantAId, 'p0');
      expect(m0.entrantBId, 'p1');
      expect(m0.bye, false);
      expect(m0.nextMatchId, 'W-R2-M0');
      expect(m0.nextSlot, 'A');
      expect(m1.nextSlot, 'B');
      expect(finalMatch.entrantAId, null);
      expect(finalMatch.entrantBId, null);
      expect(finalMatch.nextMatchId, null);
    });

    test('5 entrants: byes resolve immediately and cascade into round 2', () {
      final matches = buildSingleElimination(['p0', 'p1', 'p2', 'p3', 'p4']);
      expect(matches.length, 7); // 4 + 2 + 1

      final r1m0 = _byId(matches, 'W-R1-M0');
      final r1m1 = _byId(matches, 'W-R1-M1');
      final r1m2 = _byId(matches, 'W-R1-M2');
      final r1m3 = _byId(matches, 'W-R1-M3');
      expect(r1m0.bye, true);
      expect(r1m0.winnerId, 'p0');
      expect(r1m1.bye, true);
      expect(r1m1.winnerId, 'p1');
      expect(r1m2.bye, true);
      expect(r1m2.winnerId, 'p2');
      // The 5th entrant is the only one with an opponent — no bye.
      expect(r1m3.bye, false);
      expect(r1m3.entrantAId, 'p3');
      expect(r1m3.entrantBId, 'p4');
      expect(r1m3.winnerId, null);

      // Two byes feeding the same round-2 match resolve it into a real,
      // still-unplayed match between the two bye winners.
      final r2m0 = _byId(matches, 'W-R2-M0');
      expect(r2m0.entrantAId, 'p0');
      expect(r2m0.entrantBId, 'p1');
      expect(r2m0.winnerId, null);
      expect(r2m0.bye, false);

      // One bye + one still-unplayed real match: only the bye side is known.
      final r2m1 = _byId(matches, 'W-R2-M1');
      expect(r2m1.entrantAId, 'p2');
      expect(r2m1.entrantBId, null);

      final finalMatch = _byId(matches, 'W-R3-M0');
      expect(finalMatch.entrantAId, null);
      expect(finalMatch.entrantBId, null);
    });

    test('advanceResult propagates a real result and completes the tournament', () {
      var t = _wrap(buildSingleElimination(['p0', 'p1', 'p2', 'p3', 'p4']));
      // Round 1's only real match: p3 beats p4.
      t = advanceResult(t, matchId: 'W-R1-M3', winnerEntrantId: 'p3', gameMatchId: 'gm1');
      expect(_byId(t.matches, 'W-R2-M1').entrantBId, 'p3');
      expect(t.status, 'active');

      // Round 2.
      t = advanceResult(t, matchId: 'W-R2-M0', winnerEntrantId: 'p0', gameMatchId: 'gm2');
      t = advanceResult(t, matchId: 'W-R2-M1', winnerEntrantId: 'p3', gameMatchId: 'gm3');
      final finalMatch = _byId(t.matches, 'W-R3-M0');
      expect(finalMatch.entrantAId, 'p0');
      expect(finalMatch.entrantBId, 'p3');
      expect(t.status, 'active');

      // Final.
      t = advanceResult(t, matchId: 'W-R3-M0', winnerEntrantId: 'p0', gameMatchId: 'gm4');
      expect(t.status, 'completed');
      expect(t.winnerEntrantId, 'p0');
    });
  });

  group('correctResult', () {
    test('flipping a winner before the next round is played fixes it cleanly, no stale matches', () {
      var t = _wrap(buildSingleElimination(['p0', 'p1', 'p2', 'p3']));
      t = advanceResult(t, matchId: 'W-R1-M0', winnerEntrantId: 'p0', gameMatchId: 'gm1');
      expect(_byId(t.matches, 'W-R2-M0').entrantAId, 'p0');

      // Correction: it was actually p1 who won that match — the next round
      // hasn't been played yet, so the fix should propagate for free.
      final result = correctResult(t, matchId: 'W-R1-M0', winnerEntrantId: 'p1', gameMatchId: 'gm1-fixed');
      expect(result.staleMatchIds, isEmpty);
      expect(_byId(result.tournament.matches, 'W-R1-M0').winnerId, 'p1');
      expect(_byId(result.tournament.matches, 'W-R2-M0').entrantAId, 'p1');
    });

    test('flipping a winner after the next round was already played reports it stale instead of overwriting it', () {
      var t = _wrap(buildSingleElimination(['p0', 'p1', 'p2', 'p3']));
      t = advanceResult(t, matchId: 'W-R1-M0', winnerEntrantId: 'p0', gameMatchId: 'gm1');
      t = advanceResult(t, matchId: 'W-R1-M1', winnerEntrantId: 'p2', gameMatchId: 'gm2');
      // The final was already played with p0 (now about to be proven wrong).
      t = advanceResult(t, matchId: 'W-R2-M0', winnerEntrantId: 'p0', gameMatchId: 'gm3');
      expect(t.status, 'completed');
      expect(t.winnerEntrantId, 'p0');

      final result = correctResult(t, matchId: 'W-R1-M0', winnerEntrantId: 'p1', gameMatchId: 'gm1-fixed');
      expect(result.staleMatchIds, ['W-R2-M0']);
      // The corrected match itself is fixed...
      expect(_byId(result.tournament.matches, 'W-R1-M0').winnerId, 'p1');
      // ...but the final, already decided against the old (wrong) entrant,
      // is deliberately left untouched rather than silently rewritten.
      final finalMatch = _byId(result.tournament.matches, 'W-R2-M0');
      expect(finalMatch.entrantAId, 'p0');
      expect(finalMatch.winnerId, 'p0');
      expect(result.tournament.status, 'completed');
      expect(result.tournament.winnerEntrantId, 'p0');
    });
  });

  group('buildDoubleElimination', () {
    test('4 entrants: winners + losers + grand final, correctly linked', () {
      final matches = buildDoubleElimination(['p0', 'p1', 'p2', 'p3']);
      // W: 2 + 1, L: 1 + 1, GF: 1
      expect(matches.length, 6);

      final w1m0 = _byId(matches, 'W-R1-M0');
      final w1m1 = _byId(matches, 'W-R1-M1');
      expect(w1m0.loserNextMatchId, 'L-R1-M0');
      expect(w1m0.loserNextSlot, 'A');
      expect(w1m1.loserNextMatchId, 'L-R1-M0');
      expect(w1m1.loserNextSlot, 'B');

      final wFinal = _byId(matches, 'W-R2-M0');
      expect(wFinal.nextMatchId, 'GF');
      expect(wFinal.nextSlot, 'A');
      expect(wFinal.loserNextMatchId, 'L-R2-M0');
      expect(wFinal.loserNextSlot, 'B');

      final l1 = _byId(matches, 'L-R1-M0');
      expect(l1.nextMatchId, 'L-R2-M0');
      expect(l1.nextSlot, 'A');

      final l2 = _byId(matches, 'L-R2-M0');
      expect(l2.nextMatchId, 'GF');
      expect(l2.nextSlot, 'B');

      final gf = _byId(matches, 'GF');
      expect(gf.bracket, 'final');
    });

    test('a losers-bracket run can still win the single decisive grand final', () {
      var t = _wrap(buildDoubleElimination(['p0', 'p1', 'p2', 'p3']), format: TournamentFormat.doubleElimination);
      // Winners bracket: p0 beats p1, p2 beats p3.
      t = advanceResult(t, matchId: 'W-R1-M0', winnerEntrantId: 'p0', gameMatchId: 'g1');
      t = advanceResult(t, matchId: 'W-R1-M1', winnerEntrantId: 'p2', gameMatchId: 'g2');
      expect(_byId(t.matches, 'L-R1-M0').entrantAId, 'p1');
      expect(_byId(t.matches, 'L-R1-M0').entrantBId, 'p3');

      // Losers round 1: p1 beats p3, survives.
      t = advanceResult(t, matchId: 'L-R1-M0', winnerEntrantId: 'p1', gameMatchId: 'g3');

      // Winners final: p0 beats p2 — p2 drops to losers bracket final.
      t = advanceResult(t, matchId: 'W-R2-M0', winnerEntrantId: 'p0', gameMatchId: 'g4');
      final l2 = _byId(t.matches, 'L-R2-M0');
      expect(l2.entrantAId, 'p1');
      expect(l2.entrantBId, 'p2');
      expect(_byId(t.matches, 'GF').entrantAId, 'p0');

      // Losers bracket final: p1 beats p2, reaching the grand final.
      t = advanceResult(t, matchId: 'L-R2-M0', winnerEntrantId: 'p1', gameMatchId: 'g5');
      final gf = _byId(t.matches, 'GF');
      expect(gf.entrantAId, 'p0');
      expect(gf.entrantBId, 'p1');
      expect(t.status, 'active');

      // Grand final: the losers-bracket entrant wins outright (no reset —
      // see buildDoubleElimination's documented simplification).
      t = advanceResult(t, matchId: 'GF', winnerEntrantId: 'p1', gameMatchId: 'g6');
      expect(t.status, 'completed');
      expect(t.winnerEntrantId, 'p1');
    });
  });

  group('group stage', () {
    test('buildGroupStage splits into balanced pools with a full round robin', () {
      final matches = buildGroupStage(['p0', 'p1', 'p2', 'p3', 'p4', 'p5'], 2);
      final group0 = matches.where((m) => m.groupIndex == 0).toList();
      final group1 = matches.where((m) => m.groupIndex == 1).toList();
      // p0,p2,p4 in group 0 / p1,p3,p5 in group 1 (i % groupsCount) — 3
      // players means exactly 3 pairings (C(3,2)) each.
      expect(group0.length, 3);
      expect(group1.length, 3);
      for (final m in matches) {
        expect(m.bracket, 'group');
        expect(m.nextMatchId, null);
      }
    });

    test('groupStageComplete and computeGroupStandings rank by wins then point differential', () {
      var t = _wrap(buildGroupStage(['p0', 'p1', 'p2'], 1), format: TournamentFormat.groupsThenElimination, groupsCount: 1, qualifiersPerGroup: 2);
      expect(groupStageComplete(t), false);

      GameMatch gm(String id, String a, String b, int aPts, int bPts) => GameMatch(
            id: id,
            gameId: 'catan',
            groupId: 'g1',
            mode: 'ffa',
            unit: 'points',
            lowWins: false,
            entries: [MatchEntry(playerId: a, points: aPts), MatchEntry(playerId: b, points: bPts)],
            timeline: const [],
            createdAt: DateTime(2026, 1, 1),
          );

      final playedMatches = <GameMatch>[];
      for (final m in t.matches) {
        final winner = m.entrantAId == 'p0' || m.entrantBId == 'p0' ? 'p0' : m.entrantAId!;
        final loser = winner == m.entrantAId ? m.entrantBId! : m.entrantAId!;
        final played = gm('gm-${m.id}', winner, loser, 10, 5);
        playedMatches.add(played);
        t = advanceResult(t, matchId: m.id, winnerEntrantId: winner, gameMatchId: played.id);
      }
      expect(groupStageComplete(t), true);

      final standings = computeGroupStandings(tournament: t, groupIndex: 0, playedMatches: playedMatches);
      expect(standings.first.entrantId, 'p0');
      expect(standings.first.wins, 2);
    });
  });
}
