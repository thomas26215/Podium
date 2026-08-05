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

  const PlayerRow({
    required this.player,
    required this.wins,
    required this.played,
    required this.points,
    required this.ratio,
    required this.avg,
    required this.gamesPlayedOfFilter,
  });
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
