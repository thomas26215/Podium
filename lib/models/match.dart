import 'package:cloud_firestore/cloud_firestore.dart';

import '../repositories/guests_repository.dart' show isGuestId;
import 'game.dart';

class MatchEntry {
  final String playerId;
  final int points;
  final String? teamId; // 'A'..'D', only set in team mode
  final String? role; // e.g. "Président" — only set for CountType.ranks games
  final Map<String, int>? scoreBreakdown; // score field id -> points for this player

  const MatchEntry({required this.playerId, required this.points, this.teamId, this.role, this.scoreBreakdown});

  Map<String, dynamic> toMap() => {
        'playerId': playerId,
        'points': points,
        if (teamId != null) 'teamId': teamId,
        if (role != null) 'role': role,
        if (scoreBreakdown != null && scoreBreakdown!.isNotEmpty) 'scoreBreakdown': scoreBreakdown,
      };

  factory MatchEntry.fromMap(Map<String, dynamic> m) => MatchEntry(
        playerId: m['playerId'] as String,
        points: (m['points'] as num?)?.toInt() ?? 0,
        teamId: m['teamId'] as String?,
        role: m['role'] as String?,
        scoreBreakdown: (m['scoreBreakdown'] as Map?)?.map((k, v) => MapEntry(k as String, (v as num).toInt())),
      );
}

/// One recorded point in "live" scoring mode, so history can replay when
/// each point was scored.
class TimelinePoint {
  final String playerId;
  final int val;
  final int delta; // how much was added/removed at this step (freely chosen, not always ±1)
  final DateTime time;

  const TimelinePoint({required this.playerId, required this.val, this.delta = 1, required this.time});

  Map<String, dynamic> toMap() => {
        'playerId': playerId,
        'val': val,
        'delta': delta,
        'time': Timestamp.fromDate(time),
      };

  factory TimelinePoint.fromMap(Map<String, dynamic> m) => TimelinePoint(
        playerId: m['playerId'] as String,
        delta: (m['delta'] as num?)?.toInt() ?? 1,
        val: (m['val'] as num?)?.toInt() ?? 0,
        time: (m['time'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );

  /// JSON-safe variant of [toMap]/[fromMap] (epoch millis instead of a
  /// Firestore [Timestamp]) — used to persist an in-progress draft to local
  /// device storage for match resumption.
  Map<String, dynamic> toJson() => {
        'playerId': playerId,
        'val': val,
        'delta': delta,
        'time': time.millisecondsSinceEpoch,
      };

  factory TimelinePoint.fromJson(Map<String, dynamic> m) => TimelinePoint(
        playerId: m['playerId'] as String,
        val: (m['val'] as num?)?.toInt() ?? 0,
        delta: (m['delta'] as num?)?.toInt() ?? 1,
        time: DateTime.fromMillisecondsSinceEpoch((m['time'] as num?)?.toInt() ?? 0),
      );
}

/// A match currently being scored, right now, by someone in the group —
/// mirrors the live in-progress state of a [GameMatch] so the rest of the
/// group can watch it update in real time. Lives at
/// `groups/{rootId}/matchSessions/{sessionId}`; deleted once the match is
/// saved or the scoring flow is abandoned.
class LiveMatchSession {
  final String id;
  final String gameId;
  final String groupId;

  /// Set only for a live session broadcasting a match being scored in a
  /// Salon — mutually exclusive with the ordinary use of [groupId] for one
  /// in a friend Group. Null for every Group session, past or future.
  final String? salonId;

  final String startedByUid;
  final String startedByName;
  final String mode; // 'ffa' | 'team' | 'coop'
  final String unit; // 'points' | 'wins'
  final bool lowWins;
  final List<MatchEntry> entries;

  /// Same shape as [GameMatch.timeline] — kept in sync live so spectators
  /// (see `LiveMatchScreen`) can render the same round-by-round breakdown
  /// and score-evolution chart the person scoring sees, just read-only.
  final List<TimelinePoint> timeline;

  /// 'quick' | 'live' | 'rounds' — which detail view spectators should
  /// render (see [GameMatch.inputMode]).
  final String? inputMode;

  /// True while the scorer has left the match (app backgrounded/closed) but
  /// the session hasn't yet expired — see `AppState._holdLiveSession`.
  /// Spectators should show this as "hors ligne" rather than actively live.
  final bool held;
  final DateTime createdAt;
  final DateTime updatedAt;

  const LiveMatchSession({
    required this.id,
    required this.gameId,
    required this.groupId,
    this.salonId,
    required this.startedByUid,
    required this.startedByName,
    required this.mode,
    required this.unit,
    required this.lowWins,
    required this.entries,
    required this.timeline,
    this.inputMode,
    this.held = false,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isTeam => mode == 'team';
  bool get isSalonSession => salonId != null;

  factory LiveMatchSession.fromDoc(String id, Map<String, dynamic> data) {
    return LiveMatchSession(
      id: id,
      gameId: data['gameId'] as String? ?? '',
      groupId: data['groupId'] as String? ?? '',
      salonId: data['salonId'] as String?,
      startedByUid: data['startedBy'] as String? ?? '',
      startedByName: data['startedByName'] as String? ?? 'Un joueur',
      mode: data['mode'] as String? ?? 'ffa',
      unit: data['unit'] as String? ?? 'points',
      lowWins: data['lowWins'] as bool? ?? false,
      entries: ((data['entries'] as List?) ?? const [])
          .map((e) => MatchEntry.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      timeline: ((data['timeline'] as List?) ?? const [])
          .map((e) => TimelinePoint.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      inputMode: data['inputMode'] as String?,
      held: data['held'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class GameMatch {
  final String id;
  final String gameId;
  final String groupId; // the exact group/subgroup this was played in
  final String mode; // 'ffa' | 'team' | 'coop'
  final String unit; // 'points' | 'wins'
  final bool lowWins;
  final List<MatchEntry> entries;
  final List<TimelinePoint> timeline;
  final DateTime createdAt;
  final List<GameScoreField>? scoreFields;

  /// Which of the game's [GameRule]s scored this match (see
  /// `AppState.pickRule`) — null for matches recorded before rules existed,
  /// or for a game that only ever had its one default rule. Lets
  /// `AppState.resumeMatch` reopen the match under the same rule it was
  /// originally scored with.
  final String? ruleId;

  /// How the score was entered: 'quick' | 'live' | 'rounds' (or `null` for
  /// matches recorded before this field existed). Lets the history UI show
  /// the right detail view — the round-by-round table only for a genuinely
  /// round-synced match — without guessing from the timeline's shape.
  final String? inputMode;

  /// Who recorded this match — lets the "match finished" push notification
  /// skip notifying the person who just saved it themselves.
  final String? createdByUid;

  /// Groups this match with the other legs of the same "best of N" series
  /// (see [NewGameDraft.bestOf]) — null for a standalone match. All legs of
  /// a series share the same [seriesId] and [seriesLength]; [seriesGame] is
  /// this leg's 1-based position within it. Purely a display/grouping
  /// concern: each leg is still a full, independently-scored [GameMatch]
  /// that counts on its own toward the rankings.
  final String? seriesId;
  final int? seriesGame;
  final int? seriesLength;

  /// Set on every already-saved leg once a series is stopped before all
  /// [seriesLength] legs were played (see `AppState.endSeriesEarly` — e.g.
  /// after the "cette série est déjà jouée d'avance" prompt). Deliberately
  /// doesn't touch [seriesLength] itself: the series is still labelled
  /// "Best of {seriesLength}" — it's just marked finished early rather than
  /// left looking "En cours" forever (see `SeriesMatchCard`).
  final bool seriesEndedEarly;

  /// Set when this match was played as one node of a tournament bracket (see
  /// `lib/models/tournament.dart`) — [tournamentMatchId] is the id of the
  /// specific `BracketMatch` it settled. Purely descriptive (lets the
  /// history UI show a "Tournoi" badge); the actual bracket-advancement
  /// bookkeeping lives on the `Tournament` document itself, updated by
  /// `AppState._recordTournamentResult`.
  final String? tournamentId;
  final String? tournamentMatchId;

  /// Set only for a match recorded in a Salon (see `lib/models/salon.dart`)
  /// — mutually exclusive with the ordinary use of [groupId] for a match
  /// recorded in a friend Group. Null for every Group match, past or future.
  final String? salonId;

  /// Uids of the human (non-guest) players from [entries] who have approved
  /// this Salon match — irrelevant for a Group match (always implicitly
  /// confirmed, see [status]).
  final List<String>? confirmedBy;

  /// Uid of the player who rejected this Salon match, if any — sends it back
  /// to [createdByUid] for editing/resubmission. A single rejection is
  /// enough to block confirmation; there's no partial-veto concept.
  final String? rejectedBy;

  const GameMatch({
    required this.id,
    required this.gameId,
    required this.groupId,
    required this.mode,
    required this.unit,
    required this.lowWins,
    required this.entries,
    required this.timeline,
    required this.createdAt,
    this.scoreFields,
    this.ruleId,
    this.inputMode,
    this.createdByUid,
    this.seriesId,
    this.seriesGame,
    this.seriesLength,
    this.seriesEndedEarly = false,
    this.tournamentId,
    this.tournamentMatchId,
    this.salonId,
    this.confirmedBy,
    this.rejectedBy,
  });

  bool get isTeam => mode == 'team';
  bool get isCoop => mode == 'coop';
  bool get hasTimeline => timeline.isNotEmpty;
  bool get isSeriesLeg => seriesId != null;
  bool get hasScoreBreakdown => entries.any((e) => e.scoreBreakdown != null && e.scoreBreakdown!.isNotEmpty);
  bool get isSalonMatch => salonId != null;

  /// Human (non-guest) players who must confirm this match before it counts
  /// — guests have no account to confirm with, so they're excluded.
  List<String> get requiredConfirmers => entries.map((e) => e.playerId).where((id) => !isGuestId(id)).toList();

  /// A Group match is always implicitly confirmed (unchanged legacy
  /// behavior). A Salon match starts 'pending' and becomes 'confirmed' once
  /// every [requiredConfirmers] appears in [confirmedBy], or 'rejected' as
  /// soon as [rejectedBy] is set (which always wins over confirmations —
  /// re-confirming doesn't clear a rejection, only the author editing and
  /// resubmitting does, see AppState.saveGame).
  String get status {
    if (!isSalonMatch) return 'confirmed';
    if (rejectedBy != null) return 'rejected';
    final required = requiredConfirmers;
    final confirmed = confirmedBy ?? const [];
    return required.every(confirmed.contains) ? 'confirmed' : 'pending';
  }

  bool get isPending => status == 'pending';
  bool get isRejected => status == 'rejected';
  bool get isConfirmed => status == 'confirmed';

  /// [inputMode] when known; for matches saved before that field existed,
  /// infers it from the timeline's shape — round-synced (chunks cleanly
  /// into `entries.length`-sized batches, more than one of them) means
  /// 'rounds', any other non-empty timeline means 'live', otherwise 'quick'.
  /// Used both by the history detail view and by [resumeMatch] so an old
  /// match reopens in the right mode instead of losing its round history.
  String get resolvedInputMode {
    if (inputMode != null) return inputMode!;
    final n = entries.length;
    if (n > 0 && timeline.isNotEmpty && timeline.length % n == 0 && timeline.length ~/ n > 1) {
      return 'rounds';
    }
    return timeline.isEmpty ? 'quick' : 'live';
  }

  GameMatch copyWithId(String newId) => GameMatch(
        id: newId,
        gameId: gameId,
        groupId: groupId,
        mode: mode,
        unit: unit,
        lowWins: lowWins,
        entries: entries,
        timeline: timeline,
        createdAt: createdAt,
        scoreFields: scoreFields,
        ruleId: ruleId,
        inputMode: inputMode,
        createdByUid: createdByUid,
        seriesId: seriesId,
        seriesGame: seriesGame,
        seriesLength: seriesLength,
        seriesEndedEarly: seriesEndedEarly,
        tournamentId: tournamentId,
        tournamentMatchId: tournamentMatchId,
        salonId: salonId,
        confirmedBy: confirmedBy,
        rejectedBy: rejectedBy,
      );

  /// Used to flag already-saved legs when a "best of N" series is cut short
  /// before every leg was played (see `AppState.endSeriesEarly`), or to
  /// update a Salon match's confirmation state (see `AppState.confirmMatch`/
  /// `rejectMatch`) — every other field carries over unchanged. Passing
  /// `resetConfirmation: true` clears both [confirmedBy] and [rejectedBy]
  /// (the author editing and resubmitting a rejected match).
  GameMatch copyWith({
    bool? seriesEndedEarly,
    List<String>? confirmedBy,
    String? rejectedBy,
    bool resetConfirmation = false,
  }) =>
      GameMatch(
        id: id,
        gameId: gameId,
        groupId: groupId,
        mode: mode,
        unit: unit,
        lowWins: lowWins,
        entries: entries,
        timeline: timeline,
        createdAt: createdAt,
        scoreFields: scoreFields,
        ruleId: ruleId,
        inputMode: inputMode,
        createdByUid: createdByUid,
        seriesId: seriesId,
        seriesGame: seriesGame,
        seriesLength: seriesLength,
        seriesEndedEarly: seriesEndedEarly ?? this.seriesEndedEarly,
        tournamentId: tournamentId,
        tournamentMatchId: tournamentMatchId,
        salonId: salonId,
        confirmedBy: resetConfirmation ? const [] : (confirmedBy ?? this.confirmedBy),
        rejectedBy: resetConfirmation ? null : (rejectedBy ?? this.rejectedBy),
      );

  Map<String, dynamic> toMap() => {
        'gameId': gameId,
        'groupId': groupId,
        'mode': mode,
        'unit': unit,
        'lowWins': lowWins,
        'entries': entries.map((e) => e.toMap()).toList(),
        'timeline': timeline.map((t) => t.toMap()).toList(),
        if (scoreFields != null && scoreFields!.isNotEmpty) 'scoreFields': scoreFields!.map((f) => f.toMap()).toList(),
        if (ruleId != null) 'ruleId': ruleId,
        // A client-side timestamp rather than FieldValue.serverTimestamp() —
        // this is the moment the match was recorded as having been *played*
        // (see NewGameDraft.playedAt), which the player can backdate to
        // "hier"/"avant-hier"/any past date, not necessarily "now".
        'createdAt': Timestamp.fromDate(createdAt),
        if (inputMode != null) 'inputMode': inputMode,
        if (createdByUid != null) 'createdByUid': createdByUid,
        if (seriesId != null) 'seriesId': seriesId,
        if (seriesGame != null) 'seriesGame': seriesGame,
        if (seriesLength != null) 'seriesLength': seriesLength,
        if (seriesEndedEarly) 'seriesEndedEarly': seriesEndedEarly,
        if (tournamentId != null) 'tournamentId': tournamentId,
        if (tournamentMatchId != null) 'tournamentMatchId': tournamentMatchId,
        if (salonId != null) 'salonId': salonId,
        if (confirmedBy != null) 'confirmedBy': confirmedBy,
        if (rejectedBy != null) 'rejectedBy': rejectedBy,
      };

  factory GameMatch.fromDoc(String id, Map<String, dynamic> data) {
    return GameMatch(
      id: id,
      gameId: data['gameId'] as String? ?? '',
      groupId: data['groupId'] as String? ?? '',
      mode: data['mode'] as String? ?? 'ffa',
      unit: data['unit'] as String? ?? 'points',
      lowWins: data['lowWins'] as bool? ?? false,
      entries: ((data['entries'] as List?) ?? const [])
          .map((e) => MatchEntry.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      timeline: ((data['timeline'] as List?) ?? const [])
          .map((e) => TimelinePoint.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
        scoreFields: ((data['scoreFields'] as List?) ?? const [])
          .map((e) => GameScoreField.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      ruleId: data['ruleId'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      inputMode: data['inputMode'] as String?,
      createdByUid: data['createdByUid'] as String?,
      seriesId: data['seriesId'] as String?,
      seriesGame: (data['seriesGame'] as num?)?.toInt(),
      seriesLength: (data['seriesLength'] as num?)?.toInt(),
      seriesEndedEarly: data['seriesEndedEarly'] as bool? ?? false,
      tournamentId: data['tournamentId'] as String?,
      tournamentMatchId: data['tournamentMatchId'] as String?,
      salonId: data['salonId'] as String?,
      confirmedBy: (data['confirmedBy'] as List?)?.map((e) => e as String).toList(),
      rejectedBy: data['rejectedBy'] as String?,
    );
  }

  /// Winners of this match: the top team's players in team mode, or every
  /// player tied for the best individual score in FFA — ported from the
  /// prototype's `winnerIds()`.
  List<String> winnerIds() {
    if (isCoop) {
      // Every entry shares the exact same points value by construction (see
      // AppState.setCoopPoints) — the whole group succeeds or fails
      // together, so there's nothing to compare entries against each other
      // for. A positive shared value (a win/loss game's "Victoire", a
      // "manches gagnées" tally with at least one round won, or a
      // highWins-style shared score above zero) counts everyone as a
      // winner; zero counts as a shared loss. lowWins coop has no such
      // failure signal (a lower shared score is the *better* one, and 0 is
      // the best possible), so it's always credited as a group win.
      if (entries.isEmpty) return const [];
      return (lowWins || entries.first.points > 0) ? entries.map((e) => e.playerId).toList() : const [];
    }
    if (isTeam) {
      final sums = <String, int>{};
      for (final e in entries) {
        sums[e.teamId ?? 'A'] = (sums[e.teamId ?? 'A'] ?? 0) + e.points;
      }
      String? bestTeam;
      var bestVal = -1 << 31;
      sums.forEach((team, val) {
        if (val > bestVal) {
          bestVal = val;
          bestTeam = team;
        }
      });
      return entries.where((e) => (e.teamId ?? 'A') == bestTeam).map((e) => e.playerId).toList();
    }
    if (entries.isEmpty) return const [];
    final best = lowWins
        ? entries.map((e) => e.points).reduce((a, b) => a < b ? a : b)
        : entries.map((e) => e.points).reduce((a, b) => a > b ? a : b);
    return entries.where((e) => e.points == best).map((e) => e.playerId).toList();
  }
}

/// Tally of legs won by each player (FFA) or team (team mode) across a
/// "best of N" series — see `AppState.draftSeriesDecided` and
/// `seriesResultLine` in widgets/match_card.dart.
class SeriesTally {
  final List<String> leaders; // player or team ids tied for most legs won
  final int leaderWins;
  final bool isTeam;
  const SeriesTally({required this.leaders, required this.leaderWins, required this.isTeam});
}

SeriesTally seriesTally(List<GameMatch> legs) {
  final isTeam = legs.isNotEmpty && legs.first.isTeam;
  final tally = <String, int>{};
  for (final leg in legs) {
    final winners = leg.winnerIds();
    if (isTeam) {
      final teamIds = <String>{};
      for (final id in winners) {
        final t = leg.entries.where((e) => e.playerId == id).firstOrNull?.teamId;
        if (t != null) teamIds.add(t);
      }
      for (final t in teamIds) {
        tally[t] = (tally[t] ?? 0) + 1;
      }
    } else {
      for (final id in winners) {
        tally[id] = (tally[id] ?? 0) + 1;
      }
    }
  }
  var best = 0;
  tally.forEach((_, v) {
    if (v > best) best = v;
  });
  final leaders = tally.entries.where((e) => e.value == best).map((e) => e.key).toList();
  return SeriesTally(leaders: leaders, leaderWins: best, isTeam: isTeam);
}
