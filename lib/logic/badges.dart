import '../models/match.dart';
import '../models/tournament.dart';

/// How prestigious a badge is — drives its medal colours.
enum BadgeTier { bronze, silver, gold }

/// Everything badges are judged on, boiled down to counters (see
/// [computeBadgeStats]) so each badge is just "this counter ≥ target".
class BadgeStats {
  final int played;
  final int wins;
  final int bestWinStreak;
  final int distinctGames;
  final int bestWinsAtOneGame;
  final int teamWins;
  final int bestDay;
  final int nightGames;
  final int tournamentsWon;
  final int leading;
  final int ownedGames;
  final int friends;

  const BadgeStats({
    this.played = 0,
    this.wins = 0,
    this.bestWinStreak = 0,
    this.distinctGames = 0,
    this.bestWinsAtOneGame = 0,
    this.teamWins = 0,
    this.bestDay = 0,
    this.nightGames = 0,
    this.tournamentsWon = 0,
    this.leading = 0,
    this.ownedGames = 0,
    this.friends = 0,
  });
}

class BadgeDef {
  final String id;
  final String emoji;
  final String name;
  final String description;
  final BadgeTier tier;
  final int target;
  final int Function(BadgeStats s) value;
  const BadgeDef({required this.id, required this.emoji, required this.name, required this.description, required this.tier, required this.target, required this.value});

  /// 0…1 — how close [s] is to unlocking this badge.
  double progress(BadgeStats s) => (value(s) / target).clamp(0.0, 1.0);
  bool isEarned(BadgeStats s) => value(s) >= target;
}

/// Every badge, in display order (rough difficulty within each theme).
final List<BadgeDef> kBadges = [
  BadgeDef(id: 'first_game', emoji: '🎲', name: 'Première partie', description: 'Jouer sa toute première partie.', tier: BadgeTier.bronze, target: 1, value: (s) => s.played),
  BadgeDef(id: 'regular', emoji: '🪑', name: 'Habitué', description: 'Jouer 25 parties.', tier: BadgeTier.silver, target: 25, value: (s) => s.played),
  BadgeDef(id: 'die_hard', emoji: '🏟️', name: 'Acharné', description: 'Jouer 100 parties.', tier: BadgeTier.gold, target: 100, value: (s) => s.played),
  BadgeDef(id: 'first_win', emoji: '🥇', name: 'Première victoire', description: 'Remporter une partie.', tier: BadgeTier.bronze, target: 1, value: (s) => s.wins),
  BadgeDef(id: 'winner', emoji: '🏆', name: 'Machine à gagner', description: 'Remporter 25 parties.', tier: BadgeTier.silver, target: 25, value: (s) => s.wins),
  BadgeDef(id: 'legend', emoji: '🌟', name: 'Légende', description: 'Remporter 100 parties.', tier: BadgeTier.gold, target: 100, value: (s) => s.wins),
  BadgeDef(id: 'streak3', emoji: '🔥', name: 'En feu', description: 'Gagner 3 parties d\'affilée.', tier: BadgeTier.silver, target: 3, value: (s) => s.bestWinStreak),
  BadgeDef(id: 'streak5', emoji: '⚡', name: 'Inarrêtable', description: 'Gagner 5 parties d\'affilée.', tier: BadgeTier.gold, target: 5, value: (s) => s.bestWinStreak),
  BadgeDef(id: 'curious', emoji: '🧭', name: 'Touche-à-tout', description: 'Jouer à 5 jeux différents.', tier: BadgeTier.bronze, target: 5, value: (s) => s.distinctGames),
  BadgeDef(id: 'explorer', emoji: '🗺️', name: 'Explorateur', description: 'Jouer à 15 jeux différents.', tier: BadgeTier.silver, target: 15, value: (s) => s.distinctGames),
  BadgeDef(id: 'specialist', emoji: '🎯', name: 'Spécialiste', description: 'Gagner 10 fois au même jeu.', tier: BadgeTier.silver, target: 10, value: (s) => s.bestWinsAtOneGame),
  BadgeDef(id: 'team_player', emoji: '🤝', name: 'Esprit d\'équipe', description: 'Gagner 5 parties en équipe ou en coopératif.', tier: BadgeTier.silver, target: 5, value: (s) => s.teamWins),
  BadgeDef(id: 'marathon', emoji: '⏱️', name: 'Marathon', description: 'Jouer 10 parties dans la même journée.', tier: BadgeTier.silver, target: 10, value: (s) => s.bestDay),
  BadgeDef(id: 'night_owl', emoji: '🌙', name: 'Oiseau de nuit', description: 'Jouer une partie entre minuit et 5 h.', tier: BadgeTier.bronze, target: 1, value: (s) => s.nightGames),
  BadgeDef(id: 'champion', emoji: '👑', name: 'Champion', description: 'Remporter un tournoi.', tier: BadgeTier.gold, target: 1, value: (s) => s.tournamentsWon),
  BadgeDef(id: 'leader', emoji: '📈', name: 'Numéro 1', description: 'Prendre la tête du classement d\'un groupe (au moins 3 joueurs et 5 parties).', tier: BadgeTier.gold, target: 1, value: (s) => s.leading),
  BadgeDef(id: 'collector', emoji: '📚', name: 'Collectionneur', description: 'Avoir 10 jeux dans sa collection.', tier: BadgeTier.bronze, target: 10, value: (s) => s.ownedGames),
  BadgeDef(id: 'game_library', emoji: '🏛️', name: 'Ludothèque', description: 'Avoir 50 jeux dans sa collection.', tier: BadgeTier.gold, target: 50, value: (s) => s.ownedGames),
  BadgeDef(id: 'social', emoji: '👥', name: 'Bien entouré', description: 'Ajouter 5 amis.', tier: BadgeTier.bronze, target: 5, value: (s) => s.friends),
];

BadgeDef? badgeById(String id) {
  for (final b in kBadges) {
    if (b.id == id) return b;
  }
  return null;
}

/// Boils `uid`'s [matches] (finalised ones only — the caller filters out
/// pending/rejected salon matches) and [tournaments] down to [BadgeStats].
BadgeStats computeBadgeStats({
  required String uid,
  required List<GameMatch> matches,
  List<Tournament> tournaments = const [],
  bool leading = false,
  int ownedGames = 0,
  int friends = 0,
}) {
  final mine = matches.where((m) => m.entries.any((e) => e.playerId == uid)).toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  var wins = 0, streak = 0, bestStreak = 0, teamWins = 0, night = 0;
  final winsByGame = <String, int>{};
  final perDay = <DateTime, int>{};
  final games = <String>{};
  for (final m in mine) {
    games.add(m.gameId);
    final day = DateTime(m.createdAt.year, m.createdAt.month, m.createdAt.day);
    perDay[day] = (perDay[day] ?? 0) + 1;
    if (m.createdAt.hour < 5) night++;
    if (m.winnerIds().contains(uid)) {
      wins++;
      streak++;
      if (streak > bestStreak) bestStreak = streak;
      winsByGame[m.gameId] = (winsByGame[m.gameId] ?? 0) + 1;
      if (m.isTeam || m.isCoop) teamWins++;
    } else {
      streak = 0;
    }
  }
  final tournamentsWon = tournaments.where((t) {
    if (!t.isCompleted || t.winnerEntrantId == null) return false;
    return t.entrantById(t.winnerEntrantId)?.playerIds.contains(uid) ?? false;
  }).length;
  int maxOf(Iterable<int> xs) => xs.fold(0, (a, b) => a > b ? a : b);
  return BadgeStats(
    played: mine.length,
    wins: wins,
    bestWinStreak: bestStreak,
    distinctGames: games.length,
    bestWinsAtOneGame: maxOf(winsByGame.values),
    teamWins: teamWins,
    bestDay: maxOf(perDay.values),
    nightGames: night,
    tournamentsWon: tournamentsWon,
    leading: leading ? 1 : 0,
    ownedGames: ownedGames,
    friends: friends,
  );
}

/// A title shown under a player's name (see AppUser.titleId). Most are
/// earned with a badge ([badgeId]); a few are open to everyone.
class TitleDef {
  final String id;
  final String label;
  final String? badgeId;
  const TitleDef(this.id, this.label, [this.badgeId]);

  bool isUnlocked(Iterable<String> earnedBadges) => badgeId == null || earnedBadges.contains(badgeId);
}

const List<TitleDef> kTitles = [
  TitleDef('joueur', 'Joueur du dimanche'),
  TitleDef('stratege', 'Stratège en herbe'),
  TitleDef('bon_perdant', 'Bon perdant'),
  TitleDef('recrue', 'Nouvelle recrue', 'first_game'),
  TitleDef('vainqueur', 'Vainqueur', 'first_win'),
  TitleDef('pilier', 'Pilier du groupe', 'regular'),
  TitleDef('acharne', 'Acharné', 'die_hard'),
  TitleDef('machine', 'Machine à gagner', 'winner'),
  TitleDef('legende', 'Légende vivante', 'legend'),
  TitleDef('en_feu', 'En feu', 'streak3'),
  TitleDef('inarretable', 'Inarrêtable', 'streak5'),
  TitleDef('curieux', 'Touche-à-tout', 'curious'),
  TitleDef('explorateur', 'Grand explorateur', 'explorer'),
  TitleDef('specialiste', 'Spécialiste', 'specialist'),
  TitleDef('coequipier', 'Coéquipier modèle', 'team_player'),
  TitleDef('marathonien', 'Marathonien', 'marathon'),
  TitleDef('noctambule', 'Noctambule', 'night_owl'),
  TitleDef('champion', 'Champion de tournoi', 'champion'),
  TitleDef('numero_un', 'Numéro 1', 'leader'),
  TitleDef('collectionneur', 'Collectionneur', 'collector'),
  TitleDef('ludothecaire', 'Ludothécaire', 'game_library'),
  TitleDef('sociable', 'Âme sociable', 'social'),
];

TitleDef? titleById(String? id) {
  if (id == null) return null;
  for (final t in kTitles) {
    if (t.id == id) return t;
  }
  return null;
}
