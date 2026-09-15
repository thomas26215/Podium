import 'package:cloud_firestore/cloud_firestore.dart';

/// The 3 supported bracket shapes — chosen once at creation (see
/// `AppState.createTournament`); the actual node layout is built by
/// `lib/logic/tournament_bracket.dart`.
enum TournamentFormat { singleElimination, doubleElimination, groupsThenElimination }

TournamentFormat tournamentFormatFromString(String s) => switch (s) {
      'double' => TournamentFormat.doubleElimination,
      'groups' => TournamentFormat.groupsThenElimination,
      _ => TournamentFormat.singleElimination,
    };

String tournamentFormatToString(TournamentFormat f) => switch (f) {
      TournamentFormat.singleElimination => 'single',
      TournamentFormat.doubleElimination => 'double',
      TournamentFormat.groupsThenElimination => 'groups',
    };

/// One participant in the bracket — a single player (`playerIds.length == 1`)
/// or a fixed team (e.g. doubles) sharing one slot throughout the whole
/// tournament. `label` overrides the auto-derived "player name" / "Équipe A"
/// display when set (currently always null — reserved for a future custom
/// naming step).
class TournamentEntrant {
  final String id;
  final List<String> playerIds;
  final String? label;

  const TournamentEntrant({required this.id, required this.playerIds, this.label});

  Map<String, dynamic> toMap() => {
        'id': id,
        'playerIds': playerIds,
        if (label != null) 'label': label,
      };

  factory TournamentEntrant.fromMap(Map<String, dynamic> m) => TournamentEntrant(
        id: (m['id'] as String?) ?? '',
        playerIds: ((m['playerIds'] as List?) ?? const []).map((e) => e as String).toList(),
        label: m['label'] as String?,
      );
}

/// One node of the bracket, common to all 3 formats — a single-elimination
/// tournament only ever produces `bracket == 'winners'` nodes, a
/// double-elimination one also produces `'losers'` and a final `'final'`
/// node, and a groups-then-elimination one starts with `'group'` nodes (no
/// `nextMatchId` — group results feed a standings table, not a direct
/// advance) until [AppState.generateEliminationStage] appends a
/// single-elimination bracket on top once the group stage is done.
class BracketMatch {
  final String id;
  final String bracket; // 'winners' | 'losers' | 'final' | 'group'
  final int round;
  final int position;

  /// Set only for `bracket == 'group'` — which group-stage pool this belongs
  /// to (index into `Tournament.groupsCount`).
  final int? groupIndex;

  final String? entrantAId;
  final String? entrantBId;
  final String? winnerId;

  /// The real [GameMatch] this bracket node's result was recorded against
  /// (see `AppState.startTournamentMatch`/`_recordTournamentResult`) — null
  /// until it's actually been played.
  final String? gameMatchId;

  /// Where the winner advances to (null for a group-stage match, or the
  /// tournament's very last match).
  final String? nextMatchId;
  final String? nextSlot; // 'A' | 'B'

  /// Double-elimination only: where the loser drops to (null once already in
  /// the losers bracket's final, or for any single-elimination/group node).
  final String? loserNextMatchId;
  final String? loserNextSlot; // 'A' | 'B'

  /// True for a bye slot auto-won by whichever entrant sits in the other
  /// slot — no [GameMatch] is ever recorded for it, [winnerId] is set the
  /// moment the bracket is generated (or as soon as the real entrant is
  /// known, for a later round).
  final bool bye;

  const BracketMatch({
    required this.id,
    required this.bracket,
    required this.round,
    required this.position,
    this.groupIndex,
    this.entrantAId,
    this.entrantBId,
    this.winnerId,
    this.gameMatchId,
    this.nextMatchId,
    this.nextSlot,
    this.loserNextMatchId,
    this.loserNextSlot,
    this.bye = false,
  });

  bool get isReady => entrantAId != null && entrantBId != null && winnerId == null && !bye;
  bool get isDone => winnerId != null;

  BracketMatch copyWith({
    String? entrantAId,
    String? entrantBId,
    String? winnerId,
    String? gameMatchId,
    bool? bye,
  }) =>
      BracketMatch(
        id: id,
        bracket: bracket,
        round: round,
        position: position,
        groupIndex: groupIndex,
        entrantAId: entrantAId ?? this.entrantAId,
        entrantBId: entrantBId ?? this.entrantBId,
        winnerId: winnerId ?? this.winnerId,
        gameMatchId: gameMatchId ?? this.gameMatchId,
        nextMatchId: nextMatchId,
        nextSlot: nextSlot,
        loserNextMatchId: loserNextMatchId,
        loserNextSlot: loserNextSlot,
        bye: bye ?? this.bye,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'bracket': bracket,
        'round': round,
        'position': position,
        if (groupIndex != null) 'groupIndex': groupIndex,
        if (entrantAId != null) 'entrantAId': entrantAId,
        if (entrantBId != null) 'entrantBId': entrantBId,
        if (winnerId != null) 'winnerId': winnerId,
        if (gameMatchId != null) 'gameMatchId': gameMatchId,
        if (nextMatchId != null) 'nextMatchId': nextMatchId,
        if (nextSlot != null) 'nextSlot': nextSlot,
        if (loserNextMatchId != null) 'loserNextMatchId': loserNextMatchId,
        if (loserNextSlot != null) 'loserNextSlot': loserNextSlot,
        if (bye) 'bye': bye,
      };

  factory BracketMatch.fromMap(Map<String, dynamic> m) => BracketMatch(
        id: (m['id'] as String?) ?? '',
        bracket: (m['bracket'] as String?) ?? 'winners',
        round: (m['round'] as num?)?.toInt() ?? 0,
        position: (m['position'] as num?)?.toInt() ?? 0,
        groupIndex: (m['groupIndex'] as num?)?.toInt(),
        entrantAId: m['entrantAId'] as String?,
        entrantBId: m['entrantBId'] as String?,
        winnerId: m['winnerId'] as String?,
        gameMatchId: m['gameMatchId'] as String?,
        nextMatchId: m['nextMatchId'] as String?,
        nextSlot: m['nextSlot'] as String?,
        loserNextMatchId: m['loserNextMatchId'] as String?,
        loserNextSlot: m['loserNextSlot'] as String?,
        bye: m['bye'] as bool? ?? false,
      );
}

class Tournament {
  final String id;

  /// The exact group/subgroup this was created in — empty for a Salon
  /// tournament, which uses [salonId] instead (mutually exclusive, mirrors
  /// [GameMatch.groupId]/[GameMatch.salonId]).
  final String groupId;

  /// Set only for a tournament created in a Salon (see
  /// `lib/models/salon.dart`) — mutually exclusive with the ordinary use of
  /// [groupId] for a tournament created in a friend Group. Null for every
  /// Group tournament, past or future.
  final String? salonId;

  final String gameId;

  /// Which of the game's [GameRule]s this tournament is scored under — fixed
  /// once at creation (see `AppState.createTournament`) so every bracket
  /// match reuses the same rule (`AppState.startTournamentMatch`). Null for
  /// a game that only has its one default rule.
  final String? ruleId;
  final String name;
  final TournamentFormat format;
  final List<TournamentEntrant> entrants;
  final List<BracketMatch> matches;

  /// Only meaningful for [TournamentFormat.groupsThenElimination].
  final int groupsCount;
  final int qualifiersPerGroup;

  final String status; // 'active' | 'completed'
  final String? winnerEntrantId;
  final DateTime createdAt;
  final String? createdByUid;

  const Tournament({
    required this.id,
    required this.groupId,
    this.salonId,
    required this.gameId,
    this.ruleId,
    required this.name,
    required this.format,
    required this.entrants,
    required this.matches,
    this.groupsCount = 0,
    this.qualifiersPerGroup = 0,
    this.status = 'active',
    this.winnerEntrantId,
    required this.createdAt,
    this.createdByUid,
  });

  bool get isCompleted => status == 'completed';
  bool get isSalonTournament => salonId != null;

  TournamentEntrant? entrantById(String? id) => id == null ? null : entrants.where((e) => e.id == id).firstOrNull;

  BracketMatch? matchById(String id) => matches.where((m) => m.id == id).firstOrNull;

  Tournament copyWith({List<BracketMatch>? matches, String? status, String? winnerEntrantId}) => Tournament(
        id: id,
        groupId: groupId,
        salonId: salonId,
        gameId: gameId,
        ruleId: ruleId,
        name: name,
        format: format,
        entrants: entrants,
        matches: matches ?? this.matches,
        groupsCount: groupsCount,
        qualifiersPerGroup: qualifiersPerGroup,
        status: status ?? this.status,
        winnerEntrantId: winnerEntrantId ?? this.winnerEntrantId,
        createdAt: createdAt,
        createdByUid: createdByUid,
      );

  Map<String, dynamic> toMap() => {
        'groupId': groupId,
        if (salonId != null) 'salonId': salonId,
        'gameId': gameId,
        if (ruleId != null) 'ruleId': ruleId,
        'name': name,
        'format': tournamentFormatToString(format),
        'entrants': entrants.map((e) => e.toMap()).toList(),
        'matches': matches.map((m) => m.toMap()).toList(),
        if (groupsCount > 0) 'groupsCount': groupsCount,
        if (qualifiersPerGroup > 0) 'qualifiersPerGroup': qualifiersPerGroup,
        'status': status,
        if (winnerEntrantId != null) 'winnerEntrantId': winnerEntrantId,
        'createdAt': Timestamp.fromDate(createdAt),
        if (createdByUid != null) 'createdByUid': createdByUid,
      };

  factory Tournament.fromDoc(String id, Map<String, dynamic> data) => Tournament(
        id: id,
        groupId: (data['groupId'] as String?) ?? '',
        salonId: data['salonId'] as String?,
        gameId: (data['gameId'] as String?) ?? '',
        ruleId: data['ruleId'] as String?,
        name: (data['name'] as String?) ?? 'Tournoi',
        format: tournamentFormatFromString((data['format'] as String?) ?? 'single'),
        entrants: ((data['entrants'] as List?) ?? const [])
            .map((e) => TournamentEntrant.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
        matches: ((data['matches'] as List?) ?? const [])
            .map((e) => BracketMatch.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
        groupsCount: (data['groupsCount'] as num?)?.toInt() ?? 0,
        qualifiersPerGroup: (data['qualifiersPerGroup'] as num?)?.toInt() ?? 0,
        status: (data['status'] as String?) ?? 'active',
        winnerEntrantId: data['winnerEntrantId'] as String?,
        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        createdByUid: data['createdByUid'] as String?,
      );
}
