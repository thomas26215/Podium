import '../models/app_user.dart';
import '../models/game.dart';

/// One player's aggregated stats within a given scope of matches — ported
/// from the prototype's `computeRows()` result shape.
class PlayerRow {
  final AppUser player;
  final int wins;
  final int played;
  final int points;
  final double ratio;
  final double? avg; // average score in the currently filtered game, or null if never played it
  final int gamesPlayedOfFilter;
  final double? elo; // group Elo rating, or null outside a group / before any rated match
  final int eloPlayed;

  const PlayerRow({
    this.elo,
    this.eloPlayed = 0,
    required this.player,
    required this.wins,
    required this.played,
    required this.points,
    required this.ratio,
    required this.avg,
    required this.gamesPlayedOfFilter,
  });
}

/// See AppState.eloSummaryFor.
class EloSaveSummary {
  final Map<String, double> deltas; // uid -> total change
  final Map<String, double> ratingsBefore;
  final Map<String, double> ratingsAfter;
  final Map<String, int> ranksBefore; // uid -> 1-based rank, rated players only
  final Map<String, int> ranksAfter;
  const EloSaveSummary({required this.deltas, required this.ratingsBefore, required this.ratingsAfter, required this.ranksBefore, required this.ranksAfter});
}

class RankMetric {
  final String metric;
  final String unit;
  final String sub;
  const RankMetric(this.metric, this.unit, this.sub);
}

class ProfileGameStat {
  final Game game;
  final int played;
  final int wins;
  final double avg;
  const ProfileGameStat({required this.game, required this.played, required this.wins, required this.avg});
}
