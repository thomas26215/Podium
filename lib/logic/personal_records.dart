import '../models/game.dart';
import '../models/match.dart';
import 'time_format.dart';

/// One player's record on one game under one rule — what "Mon espace solo"
/// shows instead of a ranking (see `AppState.personalRecords`).
class PersonalRecord {
  final Game game;
  final GameRule rule;

  /// The best score or time — highest, or lowest for a lowWins/time rule.
  /// Null when the rule has no comparable score (a classement, a win/loss
  /// mark, manches gagnées): only [played] is meaningful then.
  final int? best;
  final DateTime? bestAt;

  /// `'time'` or `'points'` — how [best] is displayed (see [scoreLabel]).
  final String unit;
  final int played;
  final DateTime lastPlayedAt;

  /// Every result, oldest first — the progression toward [best].
  final List<int> results;

  const PersonalRecord({
    required this.game,
    required this.rule,
    required this.best,
    required this.bestAt,
    required this.unit,
    required this.played,
    required this.lastPlayedAt,
    required this.results,
  });

  String? get bestLabel => best == null ? null : scoreLabel(best!, unit);

  /// How much the last result beat the previous best by, when it did —
  /// e.g. a new time 0.8 s faster than the old record.
  int? get lastImprovement {
    if (best == null || results.length < 2 || results.last != best) return null;
    final before = results.sublist(0, results.length - 1);
    final previous = rule.lowWins ? before.reduce((a, b) => a < b ? a : b) : before.reduce((a, b) => a > b ? a : b);
    final gain = rule.lowWins ? previous - best! : best! - previous;
    return gain > 0 ? gain : null;
  }
}

/// `uid`'s [PersonalRecord] for every game and rule they've played in
/// [matches], most recently played first.
List<PersonalRecord> computePersonalRecords(List<GameMatch> matches, Game? Function(String id) gameById, String uid) {
  final byKey = <String, List<(GameMatch, MatchEntry)>>{};
  final rules = <String, (Game, GameRule)>{};
  for (final m in matches) {
    final game = gameById(m.gameId);
    final entry = m.entries.where((e) => e.playerId == uid).firstOrNull;
    if (game == null || entry == null) continue;
    final rule = game.resolveRule(m.ruleId);
    final key = '${game.id}/${rule.id}';
    rules[key] = (game, rule);
    (byKey[key] ??= []).add((m, entry));
  }
  final out = <PersonalRecord>[];
  byKey.forEach((key, played) {
    final (game, rule) = rules[key]!;
    played.sort((a, b) => a.$1.createdAt.compareTo(b.$1.createdAt));
    final comparable = !rule.isRanks && !rule.isWinLoss && played.every((p) => p.$1.unit != 'wins');
    int? best;
    DateTime? bestAt;
    if (comparable) {
      for (final (m, e) in played) {
        if (best == null || (rule.lowWins ? e.points < best : e.points > best)) {
          best = e.points;
          bestAt = m.createdAt;
        }
      }
    }
    out.add(PersonalRecord(
      game: game,
      rule: rule,
      best: best,
      bestAt: bestAt,
      unit: rule.isTime ? 'time' : 'points',
      played: played.length,
      lastPlayedAt: played.last.$1.createdAt,
      results: [for (final (_, e) in played) e.points],
    ));
  });
  out.sort((a, b) => b.lastPlayedAt.compareTo(a.lastPlayedAt));
  return out;
}

/// One of a player's results on a game and rule, in the order played —
/// whether it beat every earlier one at the time ([wasRecord], always true
/// for the very first) and how far it sits from today's best ([gapToBest],
/// 0 for the best itself).
class SoloAttempt {
  final GameMatch match;
  final GameRule rule;
  final int value;
  final bool wasRecord;
  final int gapToBest;
  const SoloAttempt({required this.match, required this.rule, required this.value, required this.wasRecord, required this.gapToBest});

  String get unit => rule.isTime ? 'time' : 'points';
}

/// Every one of `uid`'s results in [matches], keyed by match id — see
/// [SoloAttempt]. Results under a rule with no comparable score (see
/// [PersonalRecord.best]) are left out.
Map<String, SoloAttempt> computeSoloAttempts(List<GameMatch> matches, Game? Function(String id) gameById, String uid) {
  final byKey = <String, List<(GameMatch, int, Game, GameRule)>>{};
  for (final m in matches) {
    final game = gameById(m.gameId);
    final entry = m.entries.where((e) => e.playerId == uid).firstOrNull;
    if (game == null || entry == null) continue;
    final rule = game.resolveRule(m.ruleId);
    if (rule.isRanks || rule.isWinLoss || m.unit == 'wins') continue;
    (byKey['${game.id}/${rule.id}'] ??= []).add((m, entry.points, game, rule));
  }
  final out = <String, SoloAttempt>{};
  for (final played in byKey.values) {
    played.sort((a, b) => a.$1.createdAt.compareTo(b.$1.createdAt));
    final rule = played.first.$4;
    bool better(int a, int b) => rule.lowWins ? a < b : a > b;
    final best = played.map((p) => p.$2).reduce((a, b) => better(a, b) ? a : b);
    int? running;
    for (final (m, value, _, r) in played) {
      final wasRecord = running == null || better(value, running);
      if (wasRecord) running = value;
      out[m.id] = SoloAttempt(match: m, rule: r, value: value, wasRecord: wasRecord, gapToBest: (value - best).abs());
    }
  }
  return out;
}

/// How many times a record was beaten across [attempts] — a first attempt
/// sets a record but doesn't beat one, so it isn't counted.
int recordsBeaten(Iterable<SoloAttempt> attempts) {
  final firsts = <String>{};
  var n = 0;
  final sorted = [...attempts]..sort((a, b) => a.match.createdAt.compareTo(b.match.createdAt));
  for (final a in sorted) {
    final key = '${a.match.gameId}/${a.rule.id}';
    if (!firsts.add(key) && a.wasRecord) n++;
  }
  return n;
}
