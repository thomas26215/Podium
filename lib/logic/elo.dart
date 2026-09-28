import 'dart:math' as math;

import '../models/match.dart';

/// Rating every player starts a group at.
const kEloStart = 1000.0;

/// How far a single match can move a rating — split across the opponents
/// of a multi-player match, see [computeElo].
const kEloK = 32.0;

/// A group's Elo ratings, replayed from its match history.
class EloResult {
  /// uid -> current rating, for every player who took part in a rated match.
  final Map<String, double> ratings;

  /// uid -> number of rated matches played.
  final Map<String, int> played;

  /// match id -> (uid -> rating change from that match). Only rated matches
  /// appear here — coop and single-side matches are skipped.
  final Map<String, Map<String, double>> deltas;

  const EloResult({required this.ratings, required this.played, required this.deltas});

  static const empty = EloResult(ratings: {}, played: {}, deltas: {});

  double? ratingOf(String uid) => ratings[uid];
}

/// Replays [matches] oldest-first into one rating per player, across every
/// game at once.
///
/// A match is split into sides — each player in free-for-all, each team in
/// team mode (rated at its members' average) — and every pair of sides is
/// scored as a 1v1: 1 for finishing ahead, ½ for a tie, 0 for finishing
/// behind, ordered by points in the match's own direction ([GameMatch.lowWins]).
/// That covers every count type, since points already encode the outcome
/// (1/0 for win/loss, role points for a classement, times for a race).
///
/// A side's change is K/(sides − 1) times the sum of its (score − expected)
/// over its opponents, all from pre-match ratings, so a match is zero-sum
/// and a 6-player game doesn't weigh more than a duel. Every member of a
/// team gets the team's change.
///
/// Coop matches (no opponents) and matches with fewer than two sides (solo
/// runs) aren't rated.
EloResult computeElo(List<GameMatch> matches) {
  final sorted = List.of(matches)
    ..sort((a, b) {
      final c = a.createdAt.compareTo(b.createdAt);
      return c != 0 ? c : a.id.compareTo(b.id);
    });

  final ratings = <String, double>{};
  final played = <String, int>{};
  final deltas = <String, Map<String, double>>{};

  for (final m in sorted) {
    if (m.isCoop) continue;
    final sides = _sides(m);
    if (sides.length < 2) continue;

    double rating(String uid) => ratings[uid] ?? kEloStart;
    final sideRatings = [
      for (final s in sides) s.members.map(rating).reduce((a, b) => a + b) / s.members.length,
    ];

    final k = kEloK / (sides.length - 1);
    final matchDeltas = <String, double>{};
    for (var i = 0; i < sides.length; i++) {
      var sum = 0.0;
      for (var j = 0; j < sides.length; j++) {
        if (i == j) continue;
        final expected = 1 / (1 + math.pow(10, (sideRatings[j] - sideRatings[i]) / 400));
        sum += _score(sides[i].points, sides[j].points, m.lowWins) - expected;
      }
      for (final uid in sides[i].members) {
        matchDeltas[uid] = k * sum;
      }
    }

    matchDeltas.forEach((uid, d) {
      ratings[uid] = rating(uid) + d;
      played[uid] = (played[uid] ?? 0) + 1;
    });
    deltas[m.id] = matchDeltas;
  }

  return EloResult(ratings: ratings, played: played, deltas: deltas);
}

class _Side {
  final List<String> members;
  final int points;
  const _Side(this.members, this.points);
}

List<_Side> _sides(GameMatch m) {
  if (!m.isTeam) return [for (final e in m.entries) _Side([e.playerId], e.points)];
  final members = <String, List<String>>{};
  final totals = <String, int>{};
  for (final e in m.entries) {
    final team = e.teamId ?? 'A';
    (members[team] ??= []).add(e.playerId);
    totals[team] = (totals[team] ?? 0) + e.points;
  }
  return [for (final t in members.keys) _Side(members[t]!, totals[t]!)];
}

double _score(int mine, int theirs, bool lowWins) {
  if (mine == theirs) return 0.5;
  return (lowWins ? mine < theirs : mine > theirs) ? 1 : 0;
}
