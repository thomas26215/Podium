// Pure bracket-construction logic — no Flutter/Firestore dependency beyond
// the plain data models, so every function here is unit-testable on its own
// (see test/tournament_bracket_test.dart). `AppState` is the only caller;
// it's the seam between this and Firestore persistence.

import '../models/match.dart';
import '../models/tournament.dart';

/// Smallest power of two that can hold [entrantCount] entrants (minimum 2 —
/// a tournament always needs at least one match).
int bracketSizeFor(int entrantCount) {
  var size = 2;
  while (size < entrantCount) {
    size *= 2;
  }
  return size;
}

/// Splits [entrantIds] (in seed order) into first-round pairs for a
/// [bracketSizeFor] bracket: each pair is either two real entrants
/// (`[a, b]`) or one entrant plus a bye (`[a, null]`). Byes are spread one
/// per pair, never two in the same pair — always possible since
/// `byes = size - n` is guaranteed `< size / 2` once `n > size / 2`, true by
/// definition of [bracketSizeFor].
///
/// Deliberately simple rather than "seeded" (top seeds kept apart until the
/// final, seed 1 vs 2 never meeting early, …) — Podium tournaments are
/// casual friend-group brackets, not competition-grade seeding, and letting
/// the organizer choose (or shuffle) the entrant order already avoids the
/// same people always drawing the bye.
List<List<String?>> firstRoundPairs(List<String> entrantIds) {
  final size = bracketSizeFor(entrantIds.length);
  final byes = size - entrantIds.length;
  final numPairs = size ~/ 2;
  final pairs = <List<String?>>[];
  var idx = 0;
  for (var p = 0; p < numPairs; p++) {
    if (p < byes) {
      pairs.add([entrantIds[idx], null]);
      idx += 1;
    } else {
      pairs.add([entrantIds[idx], entrantIds[idx + 1]]);
      idx += 2;
    }
  }
  return pairs;
}

/// Closure pass over a bracket's matches: propagates every known winner (and
/// loser, for a double-elimination match with a `loserNextMatchId`) into the
/// slot it feeds, then — now that may have left some match with exactly one
/// slot filled and the other permanently unreachable (its only possible
/// feeder was a bye, which never produces a loser) — resolves that match as
/// a bye too, repeating until nothing changes.
///
/// Reused both right after generating a fresh bracket (to resolve immediate
/// byes, e.g. round 1 byes cascading into a round-2 bye) and by
/// [advanceResult] after every real match is recorded (the exact same kind
/// of cascade can surface deeper in the bracket once a real result reveals a
/// dead-end slot — see the module doc for why one pass isn't enough there).
List<BracketMatch> propagateBracket(List<BracketMatch> matches) {
  final byId = {for (final m in matches) m.id: m};
  var changed = true;
  while (changed) {
    changed = false;
    for (final m in byId.values.toList()) {
      if (m.winnerId == null) continue;
      if (m.nextMatchId != null) {
        final target = byId[m.nextMatchId]!;
        final filled = m.nextSlot == 'A' ? target.entrantAId : target.entrantBId;
        if (filled == null) {
          byId[target.id] =
              m.nextSlot == 'A' ? target.copyWith(entrantAId: m.winnerId) : target.copyWith(entrantBId: m.winnerId);
          changed = true;
        }
      }
      if (!m.bye && m.loserNextMatchId != null) {
        final loserId = m.entrantAId == m.winnerId ? m.entrantBId : m.entrantAId;
        if (loserId != null) {
          final target = byId[m.loserNextMatchId]!;
          final filled = m.loserNextSlot == 'A' ? target.entrantAId : target.entrantBId;
          if (filled == null) {
            byId[target.id] =
                m.loserNextSlot == 'A' ? target.copyWith(entrantAId: loserId) : target.copyWith(entrantBId: loserId);
            changed = true;
          }
        }
      }
    }
    for (final m in byId.values.toList()) {
      if (m.winnerId != null) continue;
      final aFilled = m.entrantAId != null;
      final bFilled = m.entrantBId != null;
      if (aFilled == bFilled) continue; // both empty (still waiting) or both filled (ready to play)
      final missingSlot = aFilled ? 'B' : 'A';
      final feedable = byId.values.any((other) =>
          other.id != m.id &&
          ((other.nextMatchId == m.id && other.nextSlot == missingSlot) ||
              (other.loserNextMatchId == m.id && other.loserNextSlot == missingSlot && !other.bye)));
      if (!feedable) {
        byId[m.id] = m.copyWith(winnerId: aFilled ? m.entrantAId : m.entrantBId, bye: true);
        changed = true;
      }
    }
  }
  return matches.map((m) => byId[m.id]!).toList();
}

/// Builds a full single-elimination bracket (every node `bracket: 'winners'`)
/// for [entrantIds] — pads to the next power of two with byes (see
/// [firstRoundPairs]) and resolves any bye cascades immediately (see
/// [propagateBracket]), so a bracket that starts with 5 players already
/// shows its round-1 byes advanced into round 2.
List<BracketMatch> buildSingleElimination(List<String> entrantIds, {String idPrefix = 'W'}) {
  assert(entrantIds.length >= 2, 'a tournament needs at least 2 entrants');
  final pairs = firstRoundPairs(entrantIds);
  final roundSizes = <int>[pairs.length];
  while (roundSizes.last > 1) {
    roundSizes.add(roundSizes.last ~/ 2);
  }
  final numRounds = roundSizes.length;

  final matches = <BracketMatch>[];
  for (var p = 0; p < roundSizes[0]; p++) {
    final a = pairs[p][0];
    final b = pairs[p][1];
    final isBye = b == null;
    final hasNext = numRounds > 1;
    matches.add(BracketMatch(
      id: '$idPrefix-R1-M$p',
      bracket: 'winners',
      round: 1,
      position: p,
      entrantAId: a,
      entrantBId: b,
      winnerId: isBye ? a : null,
      bye: isBye,
      nextMatchId: hasNext ? '$idPrefix-R2-M${p ~/ 2}' : null,
      nextSlot: hasNext ? (p.isEven ? 'A' : 'B') : null,
    ));
  }
  for (var r = 2; r <= numRounds; r++) {
    final size = roundSizes[r - 1];
    final hasNext = r < numRounds;
    for (var p = 0; p < size; p++) {
      matches.add(BracketMatch(
        id: '$idPrefix-R$r-M$p',
        bracket: 'winners',
        round: r,
        position: p,
        nextMatchId: hasNext ? '$idPrefix-R${r + 1}-M${p ~/ 2}' : null,
        nextSlot: hasNext ? (p.isEven ? 'A' : 'B') : null,
      ));
    }
  }
  return propagateBracket(matches);
}

/// Builds a double-elimination bracket: a winners bracket identical to
/// [buildSingleElimination] (`bracket: 'winners'`), a losers bracket
/// (`bracket: 'losers'`) that catches every winners-bracket loser exactly
/// once, and a single grand final (`id: 'GF'`, `bracket: 'final'`) between
/// the two bracket champions.
///
/// The losers bracket follows the standard "linear" double-elimination
/// construction (as used by Challonge/Toornament for a power-of-two field):
/// for `k = log2(bracketSize)` winners rounds, there are `2*(k-1)` losers
/// rounds, alternating between a round that consolidates losers-bracket
/// survivors against each other (odd rounds) and one that mixes that
/// round's winners with a fresh drop of winners-bracket losers (even
/// rounds).
///
/// **Deliberate simplification**: the grand final is a single decisive
/// match — if the losers-bracket entrant wins it, the tournament ends right
/// there rather than forcing a "bracket reset" rematch (the traditional
/// double-elimination rule that the winners-bracket entrant must lose
/// *twice* to be eliminated). Chosen to keep the bracket a fixed, fully
/// pre-computed structure instead of one that can grow an extra match
/// mid-tournament — the standard trade-off most casual bracket apps make.
List<BracketMatch> buildDoubleElimination(List<String> entrantIds) {
  assert(entrantIds.length >= 2, 'a tournament needs at least 2 entrants');
  final size = bracketSizeFor(entrantIds.length);
  if (size <= 2) {
    // With only one possible match, there's no meaningful losers bracket —
    // the loser has nobody left to face but the player who just beat them.
    // Falls back to a plain single match, same as single elimination.
    return buildSingleElimination(entrantIds);
  }

  final pairs = firstRoundPairs(entrantIds);
  final k = size.bitLength - 1; // log2(size); size is a power of 2 >= 4

  final wSizes = <int>[size ~/ 2];
  while (wSizes.last > 1) {
    wSizes.add(wSizes.last ~/ 2);
  }
  // Losers rounds j = 1..2*(k-1): L[2i-1] and L[2i] (i = 1..k-1) both have
  // size/2^(i+1) matches.
  final lSizes = <int>[];
  for (var i = 1; i <= k - 1; i++) {
    final s = size ~/ (1 << (i + 1));
    lSizes.add(s);
    lSizes.add(s);
  }

  String wId(int r, int p) => 'W-R$r-M$p';
  String lId(int j, int p) => 'L-R$j-M$p';

  final matches = <BracketMatch>[];

  // Winners bracket round 1 — seeded with byes exactly like single
  // elimination; each match's loser drops into L1, two per L1 match.
  for (var p = 0; p < wSizes[0]; p++) {
    final a = pairs[p][0];
    final b = pairs[p][1];
    final isBye = b == null;
    matches.add(BracketMatch(
      id: wId(1, p),
      bracket: 'winners',
      round: 1,
      position: p,
      entrantAId: a,
      entrantBId: b,
      winnerId: isBye ? a : null,
      bye: isBye,
      nextMatchId: wId(2, p ~/ 2),
      nextSlot: p.isEven ? 'A' : 'B',
      loserNextMatchId: lId(1, p ~/ 2),
      loserNextSlot: p.isEven ? 'A' : 'B',
    ));
  }
  // Winners bracket rounds 2..k — round r's losers drop into L[2*(r-1)]'s
  // slot B (slot A there is fed by the previous losers round's winner).
  for (var r = 2; r <= k; r++) {
    final sz = wSizes[r - 1];
    final hasNext = r < k;
    final lj = 2 * (r - 1);
    for (var p = 0; p < sz; p++) {
      matches.add(BracketMatch(
        id: wId(r, p),
        bracket: 'winners',
        round: r,
        position: p,
        nextMatchId: hasNext ? wId(r + 1, p ~/ 2) : 'GF',
        nextSlot: hasNext ? (p.isEven ? 'A' : 'B') : 'A',
        loserNextMatchId: lId(lj, p),
        loserNextSlot: 'B',
      ));
    }
  }

  // Losers bracket. Odd round j's entrants (for j > 1) arrive from the
  // previous even round's outgoing links; L1's arrive from WR1's
  // loserNextMatchId above. Every odd round's winner advances to the next
  // (even) round's slot A. Even round j's slot B is a fresh drop from the
  // winners bracket (wired above); its winner either feeds the next odd
  // round (paired two-to-one) or, for the very last losers round, the grand
  // final's slot B.
  for (var idx = 0; idx < lSizes.length; idx++) {
    final j = idx + 1;
    final sz = lSizes[idx];
    final isLast = j == lSizes.length;
    for (var p = 0; p < sz; p++) {
      String? nextId;
      String? nextSlot;
      if (j.isOdd) {
        nextId = lId(j + 1, p);
        nextSlot = 'A';
      } else if (isLast) {
        nextId = 'GF';
        nextSlot = 'B';
      } else {
        nextId = lId(j + 1, p ~/ 2);
        nextSlot = p.isEven ? 'A' : 'B';
      }
      matches.add(BracketMatch(id: lId(j, p), bracket: 'losers', round: j, position: p, nextMatchId: nextId, nextSlot: nextSlot));
    }
  }

  matches.add(const BracketMatch(id: 'GF', bracket: 'final', round: 0, position: 0));

  return propagateBracket(matches);
}

/// Standard "circle method" round-robin scheduling: pairs every entrant in
/// [group] with every other entrant exactly once, spread across as few
/// rounds as possible. An odd-sized group gets a silent stand-in that
/// absorbs the "sits out this round" slot — it never produces a match.
List<List<List<String>>> _roundRobinRounds(List<String> group) {
  var current = List<String>.of(group);
  if (current.length.isOdd) current = [...current, ''];
  final n = current.length;
  final rounds = <List<List<String>>>[];
  for (var r = 0; r < n - 1; r++) {
    final pairs = <List<String>>[];
    for (var i = 0; i < n ~/ 2; i++) {
      final a = current[i];
      final b = current[n - 1 - i];
      if (a.isNotEmpty && b.isNotEmpty) pairs.add([a, b]);
    }
    rounds.add(pairs);
    final fixed = current[0];
    final rotating = current.sublist(1);
    rotating.insert(0, rotating.removeLast());
    current = [fixed, ...rotating];
  }
  return rounds;
}

/// Splits [entrantIds] into [groupsCount] pools (as balanced as possible, in
/// seed order) and generates every pool's round-robin pairing (see
/// [_roundRobinRounds]). `bracket: 'group'` matches never carry a
/// `nextMatchId` — they feed a standings table (see
/// [computeGroupStandings]), not a direct bracket advance; the elimination
/// stage is only appended once the group stage is done (see
/// [buildEliminationFromStandings]).
List<BracketMatch> buildGroupStage(List<String> entrantIds, int groupsCount) {
  assert(groupsCount >= 1);
  final groups = List.generate(groupsCount, (_) => <String>[]);
  for (var i = 0; i < entrantIds.length; i++) {
    groups[i % groupsCount].add(entrantIds[i]);
  }
  final matches = <BracketMatch>[];
  for (var g = 0; g < groups.length; g++) {
    final rounds = _roundRobinRounds(groups[g]);
    for (var r = 0; r < rounds.length; r++) {
      for (var p = 0; p < rounds[r].length; p++) {
        final pair = rounds[r][p];
        matches.add(BracketMatch(
          id: 'G$g-R${r + 1}-M$p',
          bracket: 'group',
          round: r + 1,
          position: p,
          groupIndex: g,
          entrantAId: pair[0],
          entrantBId: pair[1],
        ));
      }
    }
  }
  return matches;
}

/// Whether every group-stage match has been played — gates
/// [AppState.generateEliminationStage].
bool groupStageComplete(Tournament t) {
  final groupMatches = t.matches.where((m) => m.bracket == 'group');
  return groupMatches.isNotEmpty && groupMatches.every((m) => m.isDone);
}

/// One entrant's line in a group's standings table.
class GroupStanding {
  final String entrantId;
  final int wins;
  final int pointsFor;
  final int pointsAgainst;
  const GroupStanding({required this.entrantId, required this.wins, required this.pointsFor, required this.pointsAgainst});
  int get diff => pointsFor - pointsAgainst;
}

/// Standings for one group: ranked by wins, then point differential — used
/// both to show a live table before the group is finished and to pick
/// [AppState.generateEliminationStage]'s qualifiers once it is. Needs
/// [playedMatches] (the real recorded [GameMatch]s) to read each group
/// match's actual score via its `gameMatchId` link.
List<GroupStanding> computeGroupStandings({
  required Tournament tournament,
  required int groupIndex,
  required List<GameMatch> playedMatches,
}) {
  final groupMatches = tournament.matches.where((m) => m.bracket == 'group' && m.groupIndex == groupIndex).toList();
  final byId = {for (final gm in playedMatches) gm.id: gm};
  final wins = <String, int>{};
  final pf = <String, int>{};
  final pa = <String, int>{};
  final participants = <String>{};
  for (final bm in groupMatches) {
    if (bm.entrantAId != null) participants.add(bm.entrantAId!);
    if (bm.entrantBId != null) participants.add(bm.entrantBId!);
    if (bm.winnerId == null || bm.gameMatchId == null || bm.entrantAId == null || bm.entrantBId == null) continue;
    final gm = byId[bm.gameMatchId];
    if (gm == null) continue;
    final entrantA = tournament.entrantById(bm.entrantAId);
    final entrantB = tournament.entrantById(bm.entrantBId);
    if (entrantA == null || entrantB == null) continue;
    int scoreFor(List<String> playerIds) {
      final ids = playerIds.toSet();
      return gm.entries.where((e) => ids.contains(e.playerId)).fold(0, (sum, e) => sum + e.points);
    }

    final aScore = scoreFor(entrantA.playerIds);
    final bScore = scoreFor(entrantB.playerIds);
    wins[bm.winnerId!] = (wins[bm.winnerId!] ?? 0) + 1;
    pf[bm.entrantAId!] = (pf[bm.entrantAId!] ?? 0) + aScore;
    pa[bm.entrantAId!] = (pa[bm.entrantAId!] ?? 0) + bScore;
    pf[bm.entrantBId!] = (pf[bm.entrantBId!] ?? 0) + bScore;
    pa[bm.entrantBId!] = (pa[bm.entrantBId!] ?? 0) + aScore;
  }
  final standings = participants
      .map((id) => GroupStanding(entrantId: id, wins: wins[id] ?? 0, pointsFor: pf[id] ?? 0, pointsAgainst: pa[id] ?? 0))
      .toList();
  standings.sort((a, b) => a.wins != b.wins ? b.wins - a.wins : b.diff - a.diff);
  return standings;
}

/// Builds the elimination stage appended once every group is done (see
/// [AppState.generateEliminationStage]): takes each group's qualifiers in
/// rank order but interleaved (every group's 1st place, then every group's
/// 2nd place, …) so the strongest players are spread across the bracket
/// instead of two group winners meeting in round 1.
List<BracketMatch> buildEliminationFromStandings(List<List<String>> qualifiersPerGroup) {
  final interleaved = <String>[];
  var maxLen = 0;
  for (final g in qualifiersPerGroup) {
    if (g.length > maxLen) maxLen = g.length;
  }
  for (var rank = 0; rank < maxLen; rank++) {
    for (final group in qualifiersPerGroup) {
      if (rank < group.length) interleaved.add(group[rank]);
    }
  }
  return buildSingleElimination(interleaved);
}

/// Records a real match's result on the bracket — whether this is the
/// first time it's played, or a correction to one already played (see
/// `AppState.resumeMatch`/`TournamentDetailScreen`, which lets an
/// already-done match be reopened and re-saved): sets the match's own
/// winner, then re-runs [propagateBracket] so it advances (and, in a
/// double-elimination bracket, the loser drops) — the same closure pass
/// [buildSingleElimination]/[buildDoubleElimination] use at generation time,
/// reused here because a real result can surface the exact same kind of bye
/// cascade deeper in the bracket (see [propagateBracket]'s doc).
///
/// A *correction* (the match already had a different winner) additionally
/// overwrites the stale slot(s) it previously fed — the winner's advance and,
/// for double elimination, the loser's drop — as long as whatever match that
/// slot belongs to hasn't been played yet: nothing lost, the whole point of
/// letting a mistake be fixed. If that downstream match *has* already been
/// played (using the old, now-wrong entrant), rewriting it automatically
/// would mean discarding an actual recorded result on a guess — left alone
/// instead, and reported back via `staleMatchIds` so the caller can warn
/// that part of the bracket needs a human look (see
/// `AppState._recordTournamentResult`).
///
/// Flags the tournament `completed` once the bracket's terminal match (the
/// single-elimination final, or the double-elimination grand final) has a
/// winner.
({Tournament tournament, List<String> staleMatchIds}) correctResult(
  Tournament tournament, {
  required String matchId,
  required String winnerEntrantId,
  required String gameMatchId,
}) {
  final byId = {for (final m in tournament.matches) m.id: m};
  final match = byId[matchId];
  if (match == null) return (tournament: tournament, staleMatchIds: const []);

  final oldWinnerId = match.winnerId;
  final oldLoserId = oldWinnerId == null ? null : (match.entrantAId == oldWinnerId ? match.entrantBId : match.entrantAId);
  final newLoserId = match.entrantAId == winnerEntrantId ? match.entrantBId : match.entrantAId;
  byId[matchId] = match.copyWith(winnerId: winnerEntrantId, gameMatchId: gameMatchId);

  final staleMatchIds = <String>[];
  // Overwrites `nextId`'s `nextSlot` with `newValue`, but only if that slot
  // still holds the stale `oldValue` this match previously sent it (a no-op
  // guard, not just an optimization: without it a correction could clobber
  // a slot some OTHER match legitimately fed in the meantime) and that
  // match hasn't been decided yet.
  void refill(String? nextId, String? nextSlot, String? oldValue, String? newValue) {
    if (nextId == null || nextSlot == null || oldValue == newValue) return;
    final next = byId[nextId];
    if (next == null) return;
    final current = nextSlot == 'A' ? next.entrantAId : next.entrantBId;
    if (current != oldValue) return;
    if (next.winnerId != null) {
      staleMatchIds.add(nextId);
      return;
    }
    byId[nextId] = nextSlot == 'A' ? next.copyWith(entrantAId: newValue) : next.copyWith(entrantBId: newValue);
  }

  if (oldWinnerId != null && oldWinnerId != winnerEntrantId) {
    refill(match.nextMatchId, match.nextSlot, oldWinnerId, winnerEntrantId);
    refill(match.loserNextMatchId, match.loserNextSlot, oldLoserId, newLoserId);
  }

  final settled = propagateBracket(byId.values.toList());
  BracketMatch? finalMatch;
  for (final m in settled) {
    if (m.nextMatchId == null && (m.bracket == 'winners' || m.bracket == 'final')) {
      finalMatch = m;
      break;
    }
  }
  final completed = finalMatch != null && finalMatch.isDone;
  final updated = tournament.copyWith(
    matches: settled,
    status: completed ? 'completed' : 'active',
    winnerEntrantId: completed ? finalMatch.winnerId : null,
  );
  return (tournament: updated, staleMatchIds: staleMatchIds);
}

/// The first-time-recording case of [correctResult], for callers that never
/// need to know about a stale downstream match (there can't be one — a
/// match being recorded for the first time never had a different winner to
/// correct).
Tournament advanceResult(
  Tournament tournament, {
  required String matchId,
  required String winnerEntrantId,
  required String gameMatchId,
}) =>
    correctResult(tournament, matchId: matchId, winnerEntrantId: winnerEntrantId, gameMatchId: gameMatchId).tournament;
