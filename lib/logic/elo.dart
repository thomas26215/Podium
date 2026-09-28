import 'dart:math' as math;

import '../models/match.dart';

// OpenSkill (Weng-Lin, Plackett-Luce model) defaults — a player's skill is
// a mean [_mu] and an uncertainty [_sigma] that shrinks as they play.
const _mu = 25.0;
const _sigma = _mu / 3;
const _beta = _sigma / 2;
const _kappa = 0.0001;
const _tau = _mu / 300; // keeps the uncertainty from collapsing to zero

/// Displayed rating of a newcomer — see [displayRating].
const kEloStart = 100.0;

/// Displayed points per unit of conservative skill (mu − 3σ).
const _scale = 75.0;

/// The rating shown for a skill estimate: the conservative one (mu − 3σ,
/// "at least this good" with ~99% confidence), rescaled so a newcomer sits
/// at [kEloStart]. It climbs both as the player wins (mu up) and as their
/// level becomes known (σ down), so the whole group progresses towards
/// ~1500–2000 instead of trading points around a fixed average. Never
/// below 0.
double displayRating(double mu, double sigma) => math.max(0, kEloStart + _scale * ((mu - 3 * sigma) - (_mu - 3 * _sigma)));

/// A group's ratings, replayed from its match history.
class EloResult {
  /// uid -> current displayed rating, for every player in a rated match.
  final Map<String, double> ratings;

  /// uid -> number of rated matches played.
  final Map<String, int> played;

  /// match id -> (uid -> displayed rating change from that match). Only
  /// rated matches appear here — coop and single-side matches are skipped.
  final Map<String, Map<String, double>> deltas;

  const EloResult({required this.ratings, required this.played, required this.deltas});

  static const empty = EloResult(ratings: {}, played: {}, deltas: {});

  double? ratingOf(String uid) => ratings[uid];
}

class _Skill {
  double mu = _mu;
  double sigma = _sigma;
  double get display => displayRating(mu, sigma);
}

class _Side {
  final List<String> members;
  final int points;
  int rank = 0; // 0 = best; tied sides share a rank
  double mu = 0;
  double sigmaSq = 0;
  _Side(this.members, this.points);
}

/// Replays [matches] oldest-first into one rating per player, across every
/// game at once, with OpenSkill's Plackett-Luce model.
///
/// A match is split into sides — each player in free-for-all, each team in
/// team mode (a team's skill is the sum of its members') — ranked by points
/// in the match's own direction ([GameMatch.lowWins]), ties sharing a rank.
/// That covers every count type, since points already encode the outcome
/// (1/0 for win/loss, role points for a classement, times for a race).
/// Plackett-Luce reads the ranking as successive picks — the winner was the
/// best of everyone, the runner-up the best of the rest, and so on — so
/// finishing ahead of strong players pays more, and a player whose level is
/// still uncertain moves more than a regular.
///
/// Coop matches (no opponents) and matches with fewer than two sides (solo
/// runs) aren't rated.
EloResult computeElo(List<GameMatch> matches) {
  final sorted = List.of(matches)
    ..sort((a, b) {
      final c = a.createdAt.compareTo(b.createdAt);
      return c != 0 ? c : a.id.compareTo(b.id);
    });

  final skills = <String, _Skill>{};
  final played = <String, int>{};
  final deltas = <String, Map<String, double>>{};

  for (final m in sorted) {
    if (m.isCoop) continue;
    final sides = _sides(m);
    if (sides.length < 2) continue;

    final before = <String, double>{};
    for (final s in sides) {
      for (final uid in s.members) {
        final k = skills.putIfAbsent(uid, _Skill.new);
        before[uid] = k.display;
        k.sigma = math.sqrt(k.sigma * k.sigma + _tau * _tau);
      }
    }
    for (final s in sides) {
      s.rank = sides.where((o) => m.lowWins ? o.points < s.points : o.points > s.points).length;
      s.mu = s.members.fold(0.0, (sum, uid) => sum + skills[uid]!.mu);
      s.sigmaSq = s.members.fold(0.0, (sum, uid) => sum + math.pow(skills[uid]!.sigma, 2));
    }

    final c = math.sqrt(sides.fold(0.0, (sum, s) => sum + s.sigmaSq + _beta * _beta));
    final sumQ = [for (final q in sides) sides.where((i) => i.rank >= q.rank).fold(0.0, (sum, i) => sum + math.exp(i.mu / c))];
    final ties = [for (final q in sides) sides.where((i) => i.rank == q.rank).length];

    final updates = <(double, double)>[];
    for (var i = 0; i < sides.length; i++) {
      final si = sides[i];
      var omega = 0.0, delta = 0.0;
      for (var q = 0; q < sides.length; q++) {
        if (sides[q].rank > si.rank) continue;
        final quotient = math.exp(si.mu / c) / sumQ[q];
        omega += (i == q ? 1 - quotient : -quotient) / ties[q];
        delta += quotient * (1 - quotient) / ties[q];
      }
      final gamma = math.sqrt(si.sigmaSq) / c;
      updates.add((omega * si.sigmaSq / c, delta * gamma * si.sigmaSq / (c * c)));
    }

    final matchDeltas = <String, double>{};
    for (var i = 0; i < sides.length; i++) {
      final (omega, delta) = updates[i];
      for (final uid in sides[i].members) {
        final k = skills[uid]!;
        final share = k.sigma * k.sigma / sides[i].sigmaSq;
        k.mu += share * omega;
        k.sigma *= math.sqrt(math.max(1 - share * delta, _kappa));
        matchDeltas[uid] = k.display - before[uid]!;
        played[uid] = (played[uid] ?? 0) + 1;
      }
    }
    deltas[m.id] = matchDeltas;
  }

  return EloResult(ratings: skills.map((uid, k) => MapEntry(uid, k.display)), played: played, deltas: deltas);
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
