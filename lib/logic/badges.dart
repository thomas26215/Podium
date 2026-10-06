import '../models/match.dart';
import '../models/tournament.dart';

/// How prestigious a badge is — drives its medal colours, from the most
/// common to the rarest.
enum BadgeTier { bronze, silver, gold, platinum, diamond, mythic }

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
  final int distinctGamesWon;
  final int crowdWins;
  final int distinctOpponents;
  final int daysPlayed;
  final int bestDayStreak;
  final int tournamentsPlayed;

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
    this.distinctGamesWon = 0,
    this.crowdWins = 0,
    this.distinctOpponents = 0,
    this.daysPlayed = 0,
    this.bestDayStreak = 0,
    this.tournamentsPlayed = 0,
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

/// Every badge, in display order: by theme, then from the easiest tier to
/// the rarest.
final List<BadgeDef> kBadges = [
  // Parties jouées
  BadgeDef(id: 'first_game', emoji: '🎲', name: 'Première partie', description: 'Jouer sa toute première partie.', tier: BadgeTier.bronze, target: 1, value: (s) => s.played),
  BadgeDef(id: 'played_10', emoji: '🃏', name: 'Mise en jambes', description: 'Jouer 10 parties.', tier: BadgeTier.bronze, target: 10, value: (s) => s.played),
  BadgeDef(id: 'regular', emoji: '🪑', name: 'Habitué', description: 'Jouer 25 parties.', tier: BadgeTier.silver, target: 25, value: (s) => s.played),
  BadgeDef(id: 'die_hard', emoji: '🏟️', name: 'Acharné', description: 'Jouer 100 parties.', tier: BadgeTier.gold, target: 100, value: (s) => s.played),
  BadgeDef(id: 'played_250', emoji: '🎖️', name: 'Vétéran', description: 'Jouer 250 parties.', tier: BadgeTier.platinum, target: 250, value: (s) => s.played),
  BadgeDef(id: 'played_500', emoji: '🗿', name: 'Monument', description: 'Jouer 500 parties.', tier: BadgeTier.diamond, target: 500, value: (s) => s.played),
  BadgeDef(id: 'played_1000', emoji: '♾️', name: 'Immortel', description: 'Jouer 1 000 parties.', tier: BadgeTier.mythic, target: 1000, value: (s) => s.played),
  // Victoires
  BadgeDef(id: 'first_win', emoji: '🥇', name: 'Première victoire', description: 'Remporter une partie.', tier: BadgeTier.bronze, target: 1, value: (s) => s.wins),
  BadgeDef(id: 'wins_10', emoji: '✌️', name: 'Gagneur', description: 'Remporter 10 parties.', tier: BadgeTier.bronze, target: 10, value: (s) => s.wins),
  BadgeDef(id: 'winner', emoji: '🏆', name: 'Machine à gagner', description: 'Remporter 25 parties.', tier: BadgeTier.silver, target: 25, value: (s) => s.wins),
  BadgeDef(id: 'legend', emoji: '🌟', name: 'Légende', description: 'Remporter 100 parties.', tier: BadgeTier.gold, target: 100, value: (s) => s.wins),
  BadgeDef(id: 'wins_250', emoji: '⚔️', name: 'Conquérant', description: 'Remporter 250 parties.', tier: BadgeTier.platinum, target: 250, value: (s) => s.wins),
  BadgeDef(id: 'wins_500', emoji: '🦾', name: 'Titan', description: 'Remporter 500 parties.', tier: BadgeTier.diamond, target: 500, value: (s) => s.wins),
  BadgeDef(id: 'wins_1000', emoji: '🪐', name: 'Dieu du jeu', description: 'Remporter 1 000 parties.', tier: BadgeTier.mythic, target: 1000, value: (s) => s.wins),
  // Séries de victoires
  BadgeDef(id: 'streak3', emoji: '🔥', name: 'En feu', description: 'Gagner 3 parties d\'affilée.', tier: BadgeTier.silver, target: 3, value: (s) => s.bestWinStreak),
  BadgeDef(id: 'streak5', emoji: '⚡', name: 'Inarrêtable', description: 'Gagner 5 parties d\'affilée.', tier: BadgeTier.gold, target: 5, value: (s) => s.bestWinStreak),
  BadgeDef(id: 'streak8', emoji: '🌪️', name: 'Intouchable', description: 'Gagner 8 parties d\'affilée.', tier: BadgeTier.platinum, target: 8, value: (s) => s.bestWinStreak),
  BadgeDef(id: 'streak12', emoji: '☄️', name: 'Invaincu', description: 'Gagner 12 parties d\'affilée.', tier: BadgeTier.diamond, target: 12, value: (s) => s.bestWinStreak),
  BadgeDef(id: 'streak20', emoji: '🐉', name: 'Divinité', description: 'Gagner 20 parties d\'affilée.', tier: BadgeTier.mythic, target: 20, value: (s) => s.bestWinStreak),
  // Jeux différents
  BadgeDef(id: 'curious', emoji: '🧭', name: 'Touche-à-tout', description: 'Jouer à 5 jeux différents.', tier: BadgeTier.bronze, target: 5, value: (s) => s.distinctGames),
  BadgeDef(id: 'explorer', emoji: '🗺️', name: 'Explorateur', description: 'Jouer à 15 jeux différents.', tier: BadgeTier.silver, target: 15, value: (s) => s.distinctGames),
  BadgeDef(id: 'games_30', emoji: '🌍', name: 'Globe-trotteur', description: 'Jouer à 30 jeux différents.', tier: BadgeTier.gold, target: 30, value: (s) => s.distinctGames),
  BadgeDef(id: 'games_50', emoji: '📖', name: 'Encyclopédie', description: 'Jouer à 50 jeux différents.', tier: BadgeTier.platinum, target: 50, value: (s) => s.distinctGames),
  BadgeDef(id: 'games_100', emoji: '🔭', name: 'Omniscient', description: 'Jouer à 100 jeux différents.', tier: BadgeTier.diamond, target: 100, value: (s) => s.distinctGames),
  // Jeux gagnés
  BadgeDef(id: 'versatile_5', emoji: '🎨', name: 'Polyvalent', description: 'Gagner à 5 jeux différents.', tier: BadgeTier.silver, target: 5, value: (s) => s.distinctGamesWon),
  BadgeDef(id: 'versatile_15', emoji: '🎭', name: 'Virtuose', description: 'Gagner à 15 jeux différents.', tier: BadgeTier.gold, target: 15, value: (s) => s.distinctGamesWon),
  BadgeDef(id: 'versatile_30', emoji: '🧠', name: 'Génie', description: 'Gagner à 30 jeux différents.', tier: BadgeTier.platinum, target: 30, value: (s) => s.distinctGamesWon),
  BadgeDef(id: 'versatile_60', emoji: '💫', name: 'Prodige', description: 'Gagner à 60 jeux différents.', tier: BadgeTier.diamond, target: 60, value: (s) => s.distinctGamesWon),
  // Un seul jeu
  BadgeDef(id: 'specialist', emoji: '🎯', name: 'Spécialiste', description: 'Gagner 10 fois au même jeu.', tier: BadgeTier.silver, target: 10, value: (s) => s.bestWinsAtOneGame),
  BadgeDef(id: 'specialist_25', emoji: '🏹', name: 'Expert', description: 'Gagner 25 fois au même jeu.', tier: BadgeTier.gold, target: 25, value: (s) => s.bestWinsAtOneGame),
  BadgeDef(id: 'specialist_50', emoji: '🥋', name: 'Maître', description: 'Gagner 50 fois au même jeu.', tier: BadgeTier.platinum, target: 50, value: (s) => s.bestWinsAtOneGame),
  BadgeDef(id: 'specialist_100', emoji: '🧙', name: 'Grand maître', description: 'Gagner 100 fois au même jeu.', tier: BadgeTier.diamond, target: 100, value: (s) => s.bestWinsAtOneGame),
  // En équipe
  BadgeDef(id: 'team_player', emoji: '🤝', name: 'Esprit d\'équipe', description: 'Gagner 5 parties en équipe ou en coopératif.', tier: BadgeTier.silver, target: 5, value: (s) => s.teamWins),
  BadgeDef(id: 'team_25', emoji: '🧱', name: 'Ciment de l\'équipe', description: 'Gagner 25 parties en équipe ou en coopératif.', tier: BadgeTier.gold, target: 25, value: (s) => s.teamWins),
  BadgeDef(id: 'team_100', emoji: '🛡️', name: 'Âme du collectif', description: 'Gagner 100 parties en équipe ou en coopératif.', tier: BadgeTier.platinum, target: 100, value: (s) => s.teamWins),
  // Grandes tablées
  BadgeDef(id: 'crowd_1', emoji: '🎪', name: 'Seul contre tous', description: 'Gagner une partie chacun pour soi à 6 joueurs ou plus.', tier: BadgeTier.silver, target: 1, value: (s) => s.crowdWins),
  BadgeDef(id: 'crowd_10', emoji: '🦁', name: 'Roi de la foule', description: 'Gagner 10 parties chacun pour soi à 6 joueurs ou plus.', tier: BadgeTier.platinum, target: 10, value: (s) => s.crowdWins),
  BadgeDef(id: 'crowd_30', emoji: '🌋', name: 'Force de la nature', description: 'Gagner 30 parties chacun pour soi à 6 joueurs ou plus.', tier: BadgeTier.diamond, target: 30, value: (s) => s.crowdWins),
  // Adversaires
  BadgeDef(id: 'opponents_5', emoji: '👋', name: 'Nouvelles têtes', description: 'Affronter 5 joueurs différents.', tier: BadgeTier.bronze, target: 5, value: (s) => s.distinctOpponents),
  BadgeDef(id: 'opponents_15', emoji: '📇', name: 'Carnet d\'adresses', description: 'Affronter 15 joueurs différents.', tier: BadgeTier.silver, target: 15, value: (s) => s.distinctOpponents),
  BadgeDef(id: 'opponents_40', emoji: '🎤', name: 'Célébrité locale', description: 'Affronter 40 joueurs différents.', tier: BadgeTier.gold, target: 40, value: (s) => s.distinctOpponents),
  // Journées de jeu
  BadgeDef(id: 'day_5', emoji: '🍕', name: 'Belle soirée', description: 'Jouer 5 parties dans la même journée.', tier: BadgeTier.bronze, target: 5, value: (s) => s.bestDay),
  BadgeDef(id: 'marathon', emoji: '⏱️', name: 'Marathon', description: 'Jouer 10 parties dans la même journée.', tier: BadgeTier.silver, target: 10, value: (s) => s.bestDay),
  BadgeDef(id: 'day_20', emoji: '🏃', name: 'Ultra-trail', description: 'Jouer 20 parties dans la même journée.', tier: BadgeTier.gold, target: 20, value: (s) => s.bestDay),
  BadgeDef(id: 'day_35', emoji: '🔋', name: 'Increvable', description: 'Jouer 35 parties dans la même journée.', tier: BadgeTier.platinum, target: 35, value: (s) => s.bestDay),
  // La nuit
  BadgeDef(id: 'night_owl', emoji: '🌙', name: 'Oiseau de nuit', description: 'Jouer une partie entre minuit et 5 h.', tier: BadgeTier.bronze, target: 1, value: (s) => s.nightGames),
  BadgeDef(id: 'night_10', emoji: '🦉', name: 'Noctambule', description: 'Jouer 10 parties entre minuit et 5 h.', tier: BadgeTier.silver, target: 10, value: (s) => s.nightGames),
  BadgeDef(id: 'night_50', emoji: '🦇', name: 'Vampire', description: 'Jouer 50 parties entre minuit et 5 h.', tier: BadgeTier.gold, target: 50, value: (s) => s.nightGames),
  BadgeDef(id: 'night_150', emoji: '🌌', name: 'Créature de la nuit', description: 'Jouer 150 parties entre minuit et 5 h.', tier: BadgeTier.platinum, target: 150, value: (s) => s.nightGames),
  // Fidélité
  BadgeDef(id: 'days_10', emoji: '📅', name: 'Fidèle', description: 'Jouer sur 10 journées différentes.', tier: BadgeTier.bronze, target: 10, value: (s) => s.daysPlayed),
  BadgeDef(id: 'days_50', emoji: '🗓️', name: 'Assidu', description: 'Jouer sur 50 journées différentes.', tier: BadgeTier.silver, target: 50, value: (s) => s.daysPlayed),
  BadgeDef(id: 'days_100', emoji: '💯', name: 'Inconditionnel', description: 'Jouer sur 100 journées différentes.', tier: BadgeTier.gold, target: 100, value: (s) => s.daysPlayed),
  BadgeDef(id: 'days_200', emoji: '🏯', name: 'Institution', description: 'Jouer sur 200 journées différentes.', tier: BadgeTier.platinum, target: 200, value: (s) => s.daysPlayed),
  BadgeDef(id: 'days_365', emoji: '🎂', name: 'Une année de jeu', description: 'Jouer sur 365 journées différentes.', tier: BadgeTier.diamond, target: 365, value: (s) => s.daysPlayed),
  BadgeDef(id: 'days_1000', emoji: '⏳', name: 'Éternel', description: 'Jouer sur 1 000 journées différentes.', tier: BadgeTier.mythic, target: 1000, value: (s) => s.daysPlayed),
  // Jours d'affilée
  BadgeDef(id: 'daily_3', emoji: '🔁', name: 'Sur sa lancée', description: 'Jouer 3 jours d\'affilée.', tier: BadgeTier.bronze, target: 3, value: (s) => s.bestDayStreak),
  BadgeDef(id: 'daily_7', emoji: '📆', name: 'Semaine de jeu', description: 'Jouer 7 jours d\'affilée.', tier: BadgeTier.gold, target: 7, value: (s) => s.bestDayStreak),
  BadgeDef(id: 'daily_14', emoji: '🧲', name: 'Accro', description: 'Jouer 14 jours d\'affilée.', tier: BadgeTier.platinum, target: 14, value: (s) => s.bestDayStreak),
  BadgeDef(id: 'daily_30', emoji: '🌕', name: 'Mois parfait', description: 'Jouer 30 jours d\'affilée.', tier: BadgeTier.diamond, target: 30, value: (s) => s.bestDayStreak),
  BadgeDef(id: 'daily_100', emoji: '🌠', name: 'Sans relâche', description: 'Jouer 100 jours d\'affilée.', tier: BadgeTier.mythic, target: 100, value: (s) => s.bestDayStreak),
  // Tournois
  BadgeDef(id: 'tourney_1', emoji: '🎟️', name: 'Compétiteur', description: 'Participer à un tournoi.', tier: BadgeTier.bronze, target: 1, value: (s) => s.tournamentsPlayed),
  BadgeDef(id: 'tourney_10', emoji: '🏅', name: 'Habitué des tournois', description: 'Participer à 10 tournois.', tier: BadgeTier.silver, target: 10, value: (s) => s.tournamentsPlayed),
  BadgeDef(id: 'champion', emoji: '👑', name: 'Champion', description: 'Remporter un tournoi.', tier: BadgeTier.gold, target: 1, value: (s) => s.tournamentsWon),
  BadgeDef(id: 'champion_3', emoji: '🔱', name: 'Triple couronne', description: 'Remporter 3 tournois.', tier: BadgeTier.platinum, target: 3, value: (s) => s.tournamentsWon),
  BadgeDef(id: 'champion_10', emoji: '🏰', name: 'Empereur', description: 'Remporter 10 tournois.', tier: BadgeTier.diamond, target: 10, value: (s) => s.tournamentsWon),
  BadgeDef(id: 'champion_25', emoji: '⚜️', name: 'Panthéon', description: 'Remporter 25 tournois.', tier: BadgeTier.mythic, target: 25, value: (s) => s.tournamentsWon),
  // Classement
  BadgeDef(id: 'leader', emoji: '📈', name: 'Numéro 1', description: 'Prendre la tête du classement d\'un groupe (au moins 3 joueurs et 5 parties).', tier: BadgeTier.gold, target: 1, value: (s) => s.leading),
  // Collection
  BadgeDef(id: 'collector', emoji: '📚', name: 'Collectionneur', description: 'Avoir 10 jeux dans sa collection.', tier: BadgeTier.bronze, target: 10, value: (s) => s.ownedGames),
  BadgeDef(id: 'collection_25', emoji: '🗃️', name: 'Amateur éclairé', description: 'Avoir 25 jeux dans sa collection.', tier: BadgeTier.silver, target: 25, value: (s) => s.ownedGames),
  BadgeDef(id: 'game_library', emoji: '🏛️', name: 'Ludothèque', description: 'Avoir 50 jeux dans sa collection.', tier: BadgeTier.gold, target: 50, value: (s) => s.ownedGames),
  BadgeDef(id: 'collection_100', emoji: '🖼️', name: 'Musée du jeu', description: 'Avoir 100 jeux dans sa collection.', tier: BadgeTier.platinum, target: 100, value: (s) => s.ownedGames),
  BadgeDef(id: 'collection_200', emoji: '💎', name: 'Caverne d\'Ali Baba', description: 'Avoir 200 jeux dans sa collection.', tier: BadgeTier.diamond, target: 200, value: (s) => s.ownedGames),
  // Amis
  BadgeDef(id: 'social', emoji: '👥', name: 'Bien entouré', description: 'Ajouter 5 amis.', tier: BadgeTier.bronze, target: 5, value: (s) => s.friends),
  BadgeDef(id: 'friends_15', emoji: '🎉', name: 'Populaire', description: 'Ajouter 15 amis.', tier: BadgeTier.silver, target: 15, value: (s) => s.friends),
  BadgeDef(id: 'friends_30', emoji: '⭐', name: 'Star', description: 'Ajouter 30 amis.', tier: BadgeTier.gold, target: 30, value: (s) => s.friends),
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
  var wins = 0, streak = 0, bestStreak = 0, teamWins = 0, night = 0, crowdWins = 0;
  final winsByGame = <String, int>{};
  final perDay = <DateTime, int>{};
  final games = <String>{};
  final opponents = <String>{};
  for (final m in mine) {
    games.add(m.gameId);
    final day = DateTime(m.createdAt.year, m.createdAt.month, m.createdAt.day);
    perDay[day] = (perDay[day] ?? 0) + 1;
    if (m.createdAt.hour < 5) night++;
    // Co-op tables have no opponents; team ones only the other teams.
    if (!m.isCoop) {
      final myTeam = m.entries.firstWhere((e) => e.playerId == uid).teamId;
      for (final e in m.entries) {
        if (e.playerId != uid && (!m.isTeam || e.teamId != myTeam)) opponents.add(e.playerId);
      }
    }
    if (m.winnerIds().contains(uid)) {
      wins++;
      streak++;
      if (streak > bestStreak) bestStreak = streak;
      winsByGame[m.gameId] = (winsByGame[m.gameId] ?? 0) + 1;
      if (m.isTeam || m.isCoop) teamWins++;
      if (!m.isTeam && !m.isCoop && m.entries.length >= 6) crowdWins++;
    } else {
      streak = 0;
    }
  }
  // Longest run of consecutive calendar days with at least one game.
  var dayStreak = 0, bestDayStreak = 0;
  DateTime? prev;
  for (final d in perDay.keys.toList()..sort()) {
    dayStreak = prev != null && DateTime(prev.year, prev.month, prev.day + 1) == d ? dayStreak + 1 : 1;
    if (dayStreak > bestDayStreak) bestDayStreak = dayStreak;
    prev = d;
  }
  bool inTournament(Tournament t, String? entrantId) => t.entrantById(entrantId)?.playerIds.contains(uid) ?? false;
  final tournamentsWon = tournaments.where((t) => t.isCompleted && t.winnerEntrantId != null && inTournament(t, t.winnerEntrantId)).length;
  final tournamentsPlayed = tournaments.where((t) => !t.isPending && t.entrants.any((e) => e.playerIds.contains(uid))).length;
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
    distinctGamesWon: winsByGame.length,
    crowdWins: crowdWins,
    distinctOpponents: opponents.length,
    daysPlayed: perDay.length,
    bestDayStreak: bestDayStreak,
    tournamentsPlayed: tournamentsPlayed,
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
  TitleDef('veteran', 'Vétéran', 'played_250'),
  TitleDef('monument', 'Monument vivant', 'played_500'),
  TitleDef('immortel', 'Immortel', 'played_1000'),
  TitleDef('conquerant', 'Conquérant', 'wins_250'),
  TitleDef('titan', 'Titan', 'wins_500'),
  TitleDef('dieu', 'Dieu du jeu', 'wins_1000'),
  TitleDef('intouchable', 'Intouchable', 'streak8'),
  TitleDef('invaincu', 'Invaincu', 'streak12'),
  TitleDef('divinite', 'Divinité', 'streak20'),
  TitleDef('encyclopedie', 'Encyclopédie vivante', 'games_50'),
  TitleDef('polyvalent', 'Polyvalent', 'versatile_5'),
  TitleDef('genie', 'Génie', 'versatile_30'),
  TitleDef('maitre', 'Maître', 'specialist_50'),
  TitleDef('grand_maitre', 'Grand maître', 'specialist_100'),
  TitleDef('roi_foule', 'Roi de la foule', 'crowd_10'),
  TitleDef('vampire', 'Vampire', 'night_50'),
  TitleDef('fidele', 'Fidèle au poste', 'days_10'),
  TitleDef('eternel', 'Éternel', 'days_1000'),
  TitleDef('accro', 'Accro', 'daily_14'),
  TitleDef('competiteur', 'Compétiteur', 'tourney_1'),
  TitleDef('empereur', 'Empereur des tournois', 'champion_10'),
  TitleDef('pantheon', 'Entré au Panthéon', 'champion_25'),
  TitleDef('musee', 'Conservateur de musée', 'collection_100'),
  TitleDef('star', 'Star', 'friends_30'),
];

TitleDef? titleById(String? id) {
  if (id == null) return null;
  for (final t in kTitles) {
    if (t.id == id) return t;
  }
  return null;
}
