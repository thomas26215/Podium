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

/// One step of a player's rating history — their rating right after
/// [matchId], and how much that match moved it.
class EloPoint {
  final String matchId;
  final DateTime date;
  final double rating;
  final double delta;
  const EloPoint({required this.matchId, required this.date, required this.rating, required this.delta});
}

/// A player finishing ahead of a better-rated side — the bigger [gap] (the
/// opponents' displayed rating minus the player's, both before the match),
/// the bigger the exploit.
class EloUpset {
  final String matchId;
  final DateTime date;
  final List<String> opponentIds;
  final double gap;
  const EloUpset({required this.matchId, required this.date, required this.opponentIds, required this.gap});
}

/// A player's current OpenSkill estimate — what [eloWinChances] and
/// [balanceEloTeams] work on, rather than the displayed rating.
class EloSkill {
  final double mu;
  final double sigma;
  const EloSkill(this.mu, this.sigma);
  static const newcomer = EloSkill(_mu, _sigma);
}

/// A group's ratings, replayed from its match history.
class EloResult {
  /// uid -> current displayed rating, for every player in a rated match.
  final Map<String, double> ratings;

  /// uid -> number of rated matches played.
  final Map<String, int> played;

  /// match id -> (uid -> displayed rating change from that match). Only
  /// rated matches appear here — coop and single-side matches are skipped.
  final Map<String, Map<String, double>> deltas;

  /// uid -> rating after each of their rated matches, oldest first.
  final Map<String, List<EloPoint>> history;

  /// uid -> current skill estimate.
  final Map<String, EloSkill> skills;

  /// uid -> their biggest upset so far, if they ever finished ahead of a
  /// better-rated side.
  final Map<String, EloUpset> bestUpsets;

  const EloResult({
    required this.ratings,
    required this.played,
    required this.deltas,
    this.history = const {},
    this.skills = const {},
    this.bestUpsets = const {},
  });

  static const empty = EloResult(ratings: {}, played: {}, deltas: {});

  double? ratingOf(String uid) => ratings[uid];

  EloSkill skillOf(String uid) => skills[uid] ?? EloSkill.newcomer;
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
  final history = <String, List<EloPoint>>{};
  final bestUpsets = <String, EloUpset>{};

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
        (history[uid] ??= []).add(EloPoint(matchId: m.id, date: m.createdAt, rating: k.display, delta: matchDeltas[uid]!));
      }
    }
    deltas[m.id] = matchDeltas;

    // Upsets: finishing ahead of a side rated higher than you going in.
    for (final si in sides) {
      for (final sj in sides) {
        if (sj.rank <= si.rank) continue;
        final theirs = sj.members.fold(0.0, (sum, uid) => sum + before[uid]!) / sj.members.length;
        for (final uid in si.members) {
          final gap = theirs - before[uid]!;
          if (gap > (bestUpsets[uid]?.gap ?? 0)) {
            bestUpsets[uid] = EloUpset(matchId: m.id, date: m.createdAt, opponentIds: sj.members, gap: gap);
          }
        }
      }
    }
  }

  return EloResult(
    ratings: skills.map((uid, k) => MapEntry(uid, k.display)),
    played: played,
    deltas: deltas,
    history: history,
    skills: skills.map((uid, k) => MapEntry(uid, EloSkill(k.mu, k.sigma))),
    bestUpsets: bestUpsets,
  );
}

// ============================== TIERS ==============================

/// A named rating band — see [kEloTiers].
class EloTier {
  final String name;
  final double min;
  final int color;
  const EloTier(this.name, this.min, this.color);
}

/// Rating bands, lowest first — a newcomer starts in Bronze.
const kEloTiers = [
  EloTier('Bronze', 0, 0xFFB0763B),
  EloTier('Argent', 500, 0xFF8E99A8),
  EloTier('Or', 1000, 0xFFE8A93B),
  EloTier('Platine', 1500, 0xFF2FA59C),
  EloTier('Diamant', 2000, 0xFF5B7FEF),
];

EloTier eloTier(double rating) => kEloTiers.lastWhere((t) => rating >= t.min);

/// The band after [rating]'s, or null at the top one.
EloTier? nextEloTier(double rating) => kEloTiers.where((t) => t.min > rating).firstOrNull;

// ============================== RECORDS ==============================

/// A player's Elo highlights, read from their [EloResult.history].
class EloRecords {
  final EloPoint? peak; // highest rating reached
  final EloPoint? bestGain; // biggest single-match gain
  final int longestStreak; // most rated matches in a row with a gain
  final int currentStreak; // rated matches with a gain since the last loss of points
  final EloUpset? upset; // biggest win against a better-rated side
  const EloRecords({this.peak, this.bestGain, this.longestStreak = 0, this.currentStreak = 0, this.upset});
}

EloRecords eloRecordsOf(EloResult r, String uid) {
  final points = r.history[uid] ?? const <EloPoint>[];
  EloPoint? peak, bestGain;
  var longest = 0, current = 0;
  for (final p in points) {
    if (peak == null || p.rating > peak.rating) peak = p;
    if (p.delta > 0 && (bestGain == null || p.delta > bestGain.delta)) bestGain = p;
    current = p.delta > 0 ? current + 1 : 0;
    if (current > longest) longest = current;
  }
  return EloRecords(peak: peak, bestGain: bestGain, longestStreak: longest, currentStreak: current, upset: r.bestUpsets[uid]);
}

// ============================== PREDICTIONS ==============================

/// Each side's chance of finishing first, in [sides] order — each side one
/// player, or a team (its members' skills summed, as in [computeElo]).
/// Plackett-Luce's first pick: exp(mu/c) over the sum of everyone's.
List<double> eloWinChances(EloResult r, List<List<String>> sides) {
  if (sides.isEmpty) return const [];
  final mus = [for (final s in sides) s.fold(0.0, (sum, uid) => sum + r.skillOf(uid).mu)];
  final c = math.sqrt(sides.fold(0.0, (sum, s) => sum + s.fold(0.0, (acc, uid) => acc + math.pow(r.skillOf(uid).sigma, 2)) + _beta * _beta));
  final top = mus.reduce(math.max);
  final weights = [for (final mu in mus) math.exp((mu - top) / c)]; // shifted for numeric safety
  final total = weights.fold(0.0, (a, b) => a + b);
  return [for (final w in weights) w / total];
}

/// Splits [players] into [teamCount] teams ('A', 'B'…) as evenly matched as
/// possible — sizes differing by at most one, and the gap between the
/// strongest and weakest team's summed skill as small as it can be. Tries
/// every split for up to 12 players, falls back to a greedy draft beyond.
Map<String, String> balanceEloTeams(EloResult r, List<String> players, int teamCount) {
  String label(int i) => String.fromCharCode(65 + i);
  if (teamCount < 2 || players.length <= teamCount) {
    return {for (final (i, uid) in players.indexed) uid: label(i % math.max(teamCount, 1))};
  }
  final sorted = List.of(players)..sort((a, b) => r.skillOf(b).mu.compareTo(r.skillOf(a).mu));
  final strength = [for (final uid in sorted) r.skillOf(uid).mu];
  final n = sorted.length;
  final maxSize = (n / teamCount).ceil();
  final minSize = n ~/ teamCount;

  final assign = List.filled(n, 0);
  final sums = List.filled(teamCount, 0.0);
  final sizes = List.filled(teamCount, 0);

  if (n > 12) {
    // Greedy: strongest remaining player to the weakest team with room.
    for (var p = 0; p < n; p++) {
      var best = -1;
      for (var t = 0; t < teamCount; t++) {
        if (sizes[t] >= maxSize) continue;
        if (best == -1 || sums[t] < sums[best]) best = t;
      }
      assign[p] = best;
      sums[best] += strength[p];
      sizes[best]++;
    }
    return {for (var p = 0; p < n; p++) sorted[p]: label(assign[p])};
  }

  List<int>? bestAssign;
  var bestSpread = double.infinity;
  void search(int p, int used) {
    if (p == n) {
      if (sizes.any((s) => s < minSize)) return;
      final spread = sums.reduce(math.max) - sums.reduce(math.min);
      if (spread < bestSpread - 1e-9) {
        bestSpread = spread;
        bestAssign = List.of(assign);
      }
      return;
    }
    // A player may open at most one new team — teams are interchangeable.
    for (var t = 0; t < math.min(used + 1, teamCount); t++) {
      if (sizes[t] >= maxSize) continue;
      assign[p] = t;
      sums[t] += strength[p];
      sizes[t]++;
      search(p + 1, math.max(used, t + 1));
      sums[t] -= strength[p];
      sizes[t]--;
    }
  }

  search(0, 0);
  return {for (var p = 0; p < n; p++) sorted[p]: label(bestAssign![p])};
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
