import 'dart:math' as math;

import '../models/match.dart';

// Two numbers per player, per group:
// - their level, a Bayesian estimate of how strong they are — a general
//   level, plus how much better or worse they are at each game they play —
//   which predicts results (see [eloWinChances]);
// - their Elo, the rating shown: everyone starts at [kEloStart] and climbs
//   towards their level as they play. While below it, wins earn more and
//   losses cost less; above it, the other way round. Either way a win
//   always earns and a loss always costs.

/// Displayed rating of a newcomer.
const kEloStart = 100.0;

/// Level of a newcomer: an average player, the Elo they climb towards
/// until their results say otherwise.
const kLevelStart = 1500.0;

const _levelSigma = 400.0; // uncertainty of a newcomer's general level
const _gameSigma = 200.0; // how far someone's level at one game may stray from their general one
const _beta = 246.0; // performance noise of a game of average luck — 400 points ≈ a 70 % favourite
const _tauMatch = 40.0; // how much a general level may drift per match…
const _tauGame = 8.0; // …a game offset per match…
const _tauDay = 8.0; // …and a general level per day away

// Each game's luck — its noise is [_beta] × one of [_luckGrid], learnt from
// how predictable its results turn out ([_luckPrior] before any).
const _luckGrid = [0.354, 0.5, 0.707, 1.0, 1.414, 2.0, 2.828];
const _luckPrior = [0.04, 0.08, 0.18, 0.4, 0.18, 0.08, 0.04];

const _k = 48.0; // Elo points for a completely unexpected duel result
const _boostScale = 250.0; // gap to the level at which a win earns an extra ½ × [_k] and a loss costs half
const _maxBoost = 4.0; // …up to 1.5 × [_k] extra and a quarter of the cost, 750 points below

/// One step of a player's rating history — their rating right after
/// [matchId], and how much that match moved it.
class EloPoint {
  final String matchId;
  final DateTime date;
  final double rating;
  final double delta;
  const EloPoint({required this.matchId, required this.date, required this.rating, required this.delta});
}

/// Below this chance of finishing ahead, doing it anyway is an upset.
const kEloUpsetChance = 1 / 3;

/// A player finishing ahead of [opponentIds] when they had only [chance]
/// of doing so — the lower, the bigger the exploit.
class EloUpset {
  final String matchId;
  final DateTime date;
  final List<String> opponentIds;
  final double chance;
  const EloUpset({required this.matchId, required this.date, required this.opponentIds, required this.chance});
}

/// A level estimate: its mean [mu] and uncertainty [sigma], in Elo points.
class EloSkill {
  final double mu;
  final double sigma;
  const EloSkill(this.mu, this.sigma);
  static const newcomer = EloSkill(kLevelStart, _levelSigma);
}

/// A group's ratings, replayed from its match history.
class EloResult {
  /// uid -> current displayed rating, for every player in a rated match.
  final Map<String, double> ratings;

  /// uid -> number of rated matches played.
  final Map<String, int> played;

  /// match id -> (uid -> displayed rating change from that match). Only
  /// rated matches appear here — see [computeElo].
  final Map<String, Map<String, double>> deltas;

  /// uid -> rating after each of their rated matches, oldest first.
  final Map<String, List<EloPoint>> history;

  /// uid -> current general level.
  final Map<String, EloSkill> skills;

  /// uid -> their biggest upset so far, if they ever finished ahead of a
  /// side with less than [kEloUpsetChance] of doing so.
  final Map<String, EloUpset> bestUpsets;

  /// game id -> (uid -> displayed rating on that game alone).
  final Map<String, Map<String, double>> gameRatings;

  /// game id -> (uid -> rated matches of that game).
  final Map<String, Map<String, int>> gamePlayed;

  /// game id -> (uid -> rating on that game after each of its matches).
  final Map<String, Map<String, List<EloPoint>>> gameHistory;

  /// game id -> (uid -> current level on that game, leaning on their
  /// general level while they've played it little — what predicts it).
  final Map<String, Map<String, EloSkill>> gameSkills;

  /// game id -> (uid -> level on that game from its results alone, which
  /// their Elo on it climbs towards).
  final Map<String, Map<String, double>> gameLevels;

  /// game id -> how much luck its results showed, 1 for an average game:
  /// 2 means twice as much noise, and its matches move ratings half as much.
  final Map<String, double> gameLuck;

  const EloResult({
    required this.ratings,
    required this.played,
    required this.deltas,
    this.history = const {},
    this.skills = const {},
    this.bestUpsets = const {},
    this.gameRatings = const {},
    this.gamePlayed = const {},
    this.gameHistory = const {},
    this.gameSkills = const {},
    this.gameLevels = const {},
    this.gameLuck = const {},
  });

  static const empty = EloResult(ratings: {}, played: {}, deltas: {});

  double? ratingOf(String uid) => ratings[uid];

  EloSkill skillOf(String uid) => skills[uid] ?? EloSkill.newcomer;

  /// [uid]'s level for a match of [gameId] — on a game they've never
  /// played, their general level with that game's extra uncertainty. Just
  /// the general level without a [gameId].
  EloSkill skillFor(String uid, String? gameId) {
    final global = skillOf(uid);
    if (gameId == null) return global;
    return gameSkills[gameId]?[uid] ?? EloSkill(global.mu, math.sqrt(global.sigma * global.sigma + _gameSigma * _gameSigma));
  }

  double luckOf(String? gameId) => gameId == null ? 1 : (gameLuck[gameId] ?? 1);

  /// The level [uid]'s Elo climbs towards — their general level, or their
  /// level on [gameId] — null before they've played it.
  double? levelOf(String uid, {String? gameId}) => gameId == null ? skills[uid]?.mu : gameLevels[gameId]?[uid];
}

/// A player's level: their general level and an offset on each game they
/// played, jointly Gaussian — mean [m] and covariance [p], index 0 for the
/// general level. Playing a game ties the two together, so a game played a
/// lot keeps its own level while the general one moves with other games.
class _Level {
  final m = [kLevelStart];
  final p = [
    [_levelSigma * _levelSigma],
  ];
  final slots = <String, int>{};
  DateTime? lastPlayed;

  int slotOf(String gameId) => slots.putIfAbsent(gameId, () {
        final n = m.length;
        m.add(0);
        for (final row in p) {
          row.add(0);
        }
        p.add(List.filled(n + 1, 0.0, growable: true)..[n] = _gameSigma * _gameSigma);
        return n;
      });

  EloSkill get general => EloSkill(m[0], math.sqrt(p[0][0]));

  EloSkill onGame(int g) => EloSkill(m[0] + m[g], math.sqrt(p[0][0] + 2 * p[0][g] + p[g][g]));
}

/// A player's level at one game from that game's results alone — what their
/// Elo on it climbs towards and is judged against, so that a game's ranking
/// only reflects how its matches went.
class _GameLevel {
  double mu = kLevelStart;
  double sigmaSq = _levelSigma * _levelSigma;
  DateTime? lastPlayed;
}

/// A side's standing in one of the levels a match is judged on.
class _Standing {
  double mu = 0; // its members' average level…
  double sigmaSq = 0; // …and that average's uncertainty
  double surprise = 0; // actual minus expected result against each other side, in duels' worth
  double gradient = 0; // what the results say about the level…
  double information = 0; // …and how surely

  void add(double mu, double sigmaSq, int members) {
    this.mu += mu / members;
    this.sigmaSq += sigmaSq / (members * members);
  }

  /// Counts [score] (see [_score]) against [other], weighing [weight] in a
  /// game of noise [beta] — and returns the chance this side had of it.
  double meet(_Standing other, double score, double weight, double beta) {
    final c = math.sqrt(sigmaSq + other.sigmaSq + 2 * beta * beta);
    final p = 1 / (1 + math.exp((other.mu - mu) / c));
    surprise += weight * (score - p);
    gradient += weight * (score - p) / c;
    information += weight * p * (1 - p) / (c * c);
    return p;
  }
}

class _Side {
  final List<String> members;
  final int points;
  int rank = 0; // 0 = best; tied sides share a rank
  double won = 0, outOf = 0; // duels won against the other sides, in duels' worth
  final level = _Standing(); // judged on the players' levels at the game played
  final gameLevel = _Standing(); // judged on that game's results alone
  _Side(this.members, this.points);

  double get share => outOf == 0 ? 0 : won / outOf;
}

/// Replays [matches] oldest-first into each player's level, Elo and Elo on
/// each game.
///
/// A match is split into sides — each player in free-for-all, each team in
/// team mode (a team plays at its members' average level) — ranked by
/// points in the match's own direction ([GameMatch.lowWins]). Every pair of
/// sides counts as a duel: finishing ahead of a side you were expected to
/// lose to says a lot, ahead of one you were expected to beat little. A
/// tie is a draw between two sides; with three or more, tied sides are
/// co-winners or co-losers (a 2v2 entered as free-for-all…) and say
/// nothing about each other. Each pair weighs 2/(sides) so a big
/// free-for-all doesn't count as that many duels.
///
/// Levels are judged on the game played: someone strong at it is expected
/// to win there even if they're weaker overall. Each game learns its own
/// luck — the more upsets, the less its matches move ratings.
///
/// The Elo, starting at [kEloStart], moves by [_k] × that surprise, scaled
/// down for luck, plus a progression bonus on a win while below the level
/// (see [_change]). The Elo on a game does the same against the level on
/// that game from its results alone. Matches with nothing to compare —
/// coop, solo, everyone tied — aren't rated.
EloResult computeElo(List<GameMatch> matches) {
  final sorted = List.of(matches)
    ..sort((a, b) {
      final c = a.createdAt.compareTo(b.createdAt);
      return c != 0 ? c : a.id.compareTo(b.id);
    });

  final levels = <String, _Level>{};
  final gameLevels = <String, Map<String, _GameLevel>>{};
  final luckLogs = <String, List<double>>{};
  final ratings = <String, double>{};
  final gameRatings = <String, Map<String, double>>{};
  final played = <String, int>{};
  final gamePlayed = <String, Map<String, int>>{};
  final deltas = <String, Map<String, double>>{};
  final history = <String, List<EloPoint>>{};
  final gameHistory = <String, Map<String, List<EloPoint>>>{};
  final bestUpsets = <String, EloUpset>{};

  for (final m in sorted) {
    if (m.isCoop) continue;
    final sides = _sides(m);
    final k = sides.length;
    if (k < 2) continue;
    for (final s in sides) {
      s.rank = sides.where((o) => m.lowWins ? o.points < s.points : o.points > s.points).length;
    }
    if (k >= 3 && sides.every((s) => s.rank == 0)) continue;

    final gameId = m.gameId;
    final onGame = gameLevels.putIfAbsent(gameId, () => {});
    for (final s in sides) {
      final n = s.members.length;
      for (final uid in s.members) {
        final l = levels.putIfAbsent(uid, _Level.new);
        _drift(l, gameId, m.createdAt);
        final level = l.onGame(l.slots[gameId]!);
        s.level.add(level.mu, level.sigma * level.sigma, n);
        final gl = onGame.putIfAbsent(uid, _GameLevel.new);
        _driftGame(gl, m.createdAt);
        s.gameLevel.add(gl.mu, gl.sigmaSq, n);
      }
    }

    // This game's luck so far rates the match, which then adds to it.
    final logs = luckLogs.putIfAbsent(gameId, () => List.filled(_luckGrid.length, 0.0));
    final luck = _luck(logs);
    final weight = 2 / k;
    for (var i = 0; i < k; i++) {
      for (var j = 0; j < k; j++) {
        final si = sides[i], sj = sides[j];
        final score = _score(si, sj, k);
        if (score == null) continue;
        final p = si.level.meet(sj.level, score, weight, _beta * luck);
        si.gameLevel.meet(sj.gameLevel, score, weight, _beta * luck);
        si.won += weight * score;
        si.outOf += weight;
        if (score == 1 && p < kEloUpsetChance) {
          for (final uid in si.members) {
            if (p < (bestUpsets[uid]?.chance ?? kEloUpsetChance)) bestUpsets[uid] = EloUpset(matchId: m.id, date: m.createdAt, opponentIds: sj.members, chance: p);
          }
        }
        if (j < i) continue; // each pair once for the luck
        for (var l = 0; l < _luckGrid.length; l++) {
          final pl = _ahead(si.level, sj.level, _beta * _luckGrid[l]);
          logs[l] += weight * (score * math.log(pl) + (1 - score) * math.log(1 - pl));
        }
      }
    }

    final damp = math.min(1.0, 1 / luck);
    final matchDeltas = <String, double>{};
    final gr = gameRatings.putIfAbsent(gameId, () => {});
    final gh = gameHistory.putIfAbsent(gameId, () => {});
    final gp = gamePlayed.putIfAbsent(gameId, () => {});
    for (final s in sides) {
      final n = s.members.length;
      for (final uid in s.members) {
        final l = levels[uid]!;
        _learn(l, l.slots[gameId]!, s.level, n);
        final gl = onGame[uid]!;
        gl.sigmaSq /= 1 + gl.sigmaSq * s.gameLevel.information / (n * n);
        gl.mu += gl.sigmaSq * s.gameLevel.gradient / n;

        final before = ratings[uid] ?? kEloStart;
        final after = math.max(0.0, before + damp * _change(s.level.surprise, s.share, l.m[0] - before));
        ratings[uid] = after;
        matchDeltas[uid] = after - before;
        played[uid] = (played[uid] ?? 0) + 1;
        (history[uid] ??= []).add(EloPoint(matchId: m.id, date: m.createdAt, rating: after, delta: after - before));

        final gameBefore = gr[uid] ?? kEloStart;
        final gameAfter = math.max(0.0, gameBefore + damp * _change(s.gameLevel.surprise, s.share, gl.mu - gameBefore));
        gr[uid] = gameAfter;
        gp[uid] = (gp[uid] ?? 0) + 1;
        (gh[uid] ??= []).add(EloPoint(matchId: m.id, date: m.createdAt, rating: gameAfter, delta: gameAfter - gameBefore));
      }
    }
    deltas[m.id] = matchDeltas;
  }

  return EloResult(
    ratings: ratings,
    played: played,
    deltas: deltas,
    history: history,
    skills: levels.map((uid, l) => MapEntry(uid, l.general)),
    bestUpsets: bestUpsets,
    gameRatings: gameRatings,
    gamePlayed: gamePlayed,
    gameHistory: gameHistory,
    gameSkills: {
      for (final gameId in gamePlayed.keys)
        gameId: {
          for (final uid in gamePlayed[gameId]!.keys) uid: levels[uid]!.onGame(levels[uid]!.slots[gameId]!),
        },
    },
    gameLevels: gameLevels.map((gameId, ls) => MapEntry(gameId, ls.map((uid, l) => MapEntry(uid, l.mu)))),
    gameLuck: luckLogs.map((gameId, logs) => MapEntry(gameId, _luck(logs))),
  );
}

/// [a]'s chance of finishing ahead of [b], for a game of noise [beta].
double _ahead(_Standing a, _Standing b, double beta) => 1 / (1 + math.exp((b.mu - a.mu) / math.sqrt(a.sigmaSq + b.sigmaSq + 2 * beta * beta)));

/// [a]'s result against [b]: 1 ahead, 0 behind, ½ a draw — or null for
/// tied sides of a match with three or more, which say nothing about each
/// other (co-winners, a 2v2 entered as free-for-all…).
double? _score(_Side a, _Side b, int sideCount) {
  if (identical(a, b)) return null;
  if (a.rank == b.rank) return sideCount >= 3 ? null : 0.5;
  return a.rank < b.rank ? 1 : 0;
}

/// Before [l] plays [gameId] at [at]: their general level may have drifted
/// since their last match (more so after a long break), and their level on
/// that game a little — never beyond a newcomer's uncertainty.
void _drift(_Level l, String gameId, DateTime at) {
  final g = l.slotOf(gameId);
  final days = l.lastPlayed == null ? 0.0 : math.max(0.0, at.difference(l.lastPlayed!).inMinutes / 1440);
  l.p[0][0] = math.min(l.p[0][0] + _tauMatch * _tauMatch + _tauDay * _tauDay * days, _levelSigma * _levelSigma);
  l.p[g][g] = math.min(l.p[g][g] + _tauGame * _tauGame, _gameSigma * _gameSigma);
  l.lastPlayed = at;
}

/// The same for a level on one game, which drifts like a general level.
void _driftGame(_GameLevel l, DateTime at) {
  final days = l.lastPlayed == null ? 0.0 : math.max(0.0, at.difference(l.lastPlayed!).inMinutes / 1440);
  l.sigmaSq = math.min(l.sigmaSq + _tauMatch * _tauMatch + _tauDay * _tauDay * days, _levelSigma * _levelSigma);
  l.lastPlayed = at;
}

/// Updates [l], one of the [n] members of a side, from that side's [result]
/// on game slot [g] — a Bayesian update of their general level and that
/// game's offset together, each by how uncertain it is: the offset of a
/// game they've barely played learns the most, while one played a lot
/// keeps its level as the general one moves.
void _learn(_Level l, int g, _Standing result, int n) {
  final dim = l.m.length;
  final pu = [for (var r = 0; r < dim; r++) l.p[r][0] + l.p[r][g]];
  final info = result.information / (n * n);
  final denom = 1 + (pu[0] + pu[g]) * info;
  final step = result.gradient / n / denom;
  for (var r = 0; r < dim; r++) {
    l.m[r] += pu[r] * step;
  }
  final shrink = info / denom;
  for (var r = 0; r < dim; r++) {
    for (var c = 0; c < dim; c++) {
      l.p[r][c] -= pu[r] * pu[c] * shrink;
    }
  }
}

/// The luck multiplier [logs] (the log-likelihood of a game's results under
/// each of [_luckGrid]) point to — their posterior geometric mean.
double _luck(List<double> logs) {
  final top = logs.reduce(math.max);
  var total = 0.0, acc = 0.0;
  for (var i = 0; i < _luckGrid.length; i++) {
    final w = _luckPrior[i] * math.exp(logs[i] - top);
    total += w;
    acc += w * math.log(_luckGrid[i]);
  }
  return math.exp(acc / total);
}

/// The Elo change for a result [surprise] points of duels above what was
/// expected (below when negative), having won [share] of them, for an Elo
/// [gap] points below its level (negative when above).
///
/// Below the level, a good result also earns a progression bonus, the same
/// whoever the opponents — up to ([_maxBoost] − 1)/2 × [_k] for a win, 0.5
/// × [_k] [_boostScale] points below — and a bad one costs that many times
/// less. Above, gains are divided and losses multiplied instead. Either way
/// the change keeps the sign of [surprise].
double _change(double surprise, double share, double gap) {
  final b = math.min(1 + gap.abs() / _boostScale, _maxBoost);
  if (gap < 0) return _k * surprise * (surprise >= 0 ? 1 / b : b);
  return surprise >= 0 ? _k * (surprise + (b - 1) * share / 2) : _k * surprise / b;
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
  final EloUpset? upset; // least likely win
  const EloRecords({this.peak, this.bestGain, this.longestStreak = 0, this.currentStreak = 0, this.upset});
}

/// Global records by default, or on one game with [gameId] (upsets are
/// only tracked globally).
EloRecords eloRecordsOf(EloResult r, String uid, {String? gameId}) {
  final points = (gameId == null ? r.history[uid] : r.gameHistory[gameId]?[uid]) ?? const <EloPoint>[];
  EloPoint? peak, bestGain;
  var longest = 0, current = 0;
  for (final p in points) {
    if (peak == null || p.rating > peak.rating) peak = p;
    if (p.delta > 0 && (bestGain == null || p.delta > bestGain.delta)) bestGain = p;
    current = p.delta > 0 ? current + 1 : 0;
    if (current > longest) longest = current;
  }
  return EloRecords(peak: peak, bestGain: bestGain, longestStreak: longest, currentStreak: current, upset: gameId == null ? r.bestUpsets[uid] : null);
}

// ============================== PREDICTIONS ==============================

/// Each side's chance of finishing first, in [sides] order — each side one
/// player, or a team at its members' average level, as in [computeElo].
/// Between two sides, the same odds the ratings are learnt from; with more,
/// a Plackett-Luce first pick. With [gameId], levels are those on that
/// game (see [EloResult.skillFor]) and its luck evens the odds out.
List<double> eloWinChances(EloResult r, List<List<String>> sides, {String? gameId}) {
  if (sides.isEmpty) return const [];
  final strengths = [for (final s in sides) _strength(r, s, gameId)];
  final beta = _beta * r.luckOf(gameId);
  final c = math.sqrt(2 / sides.length * strengths.fold(0.0, (sum, s) => sum + s.sigmaSq + beta * beta));
  final top = strengths.map((s) => s.mu).reduce(math.max);
  final weights = [for (final s in strengths) math.exp((s.mu - top) / c)]; // shifted for numeric safety
  final total = weights.fold(0.0, (a, b) => a + b);
  return [for (final w in weights) w / total];
}

({double mu, double sigmaSq}) _strength(EloResult r, List<String> members, String? gameId) {
  if (members.isEmpty) return (mu: kLevelStart, sigmaSq: _levelSigma * _levelSigma);
  final n = members.length;
  var mu = 0.0, sigmaSq = 0.0;
  for (final uid in members) {
    final s = r.skillFor(uid, gameId);
    mu += s.mu / n;
    sigmaSq += s.sigma * s.sigma / (n * n);
  }
  return (mu: mu, sigmaSq: sigmaSq);
}

/// Splits [players] into [teamCount] teams ('A', 'B'…) as evenly matched as
/// possible — sizes differing by at most one, and the gap between the
/// strongest and weakest team's average level as small as it can be. Tries
/// every split for up to 12 players, falls back to a greedy draft beyond.
/// With [gameId], levels are those on that game (see [EloResult.skillFor]).
Map<String, String> balanceEloTeams(EloResult r, List<String> players, int teamCount, {String? gameId}) {
  String label(int i) => String.fromCharCode(65 + i);
  if (teamCount < 2 || players.length <= teamCount) {
    return {for (final (i, uid) in players.indexed) uid: label(i % math.max(teamCount, 1))};
  }
  final sorted = List.of(players)..sort((a, b) => r.skillFor(b, gameId).mu.compareTo(r.skillFor(a, gameId).mu));
  final strength = [for (final uid in sorted) r.skillFor(uid, gameId).mu];
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
      final averages = [for (var t = 0; t < teamCount; t++) sums[t] / sizes[t]];
      final spread = averages.reduce(math.max) - averages.reduce(math.min);
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
