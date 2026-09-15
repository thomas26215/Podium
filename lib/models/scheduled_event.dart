import 'package:cloud_firestore/cloud_firestore.dart';

/// A game or tournament scheduled ahead of time in a Salon (see
/// `lib/models/salon.dart`), open for members to sign up to before it's
/// actually played — e.g. a game café's "Tournoi TCG samedi 14h". Salon-only
/// for now (no Group equivalent, unlike `GameMatch`/`Tournament`).
///
/// Starting it (see `AppState.startEvent`) doesn't create the match/
/// tournament itself right away — it just opens the normal new-game wizard
/// pre-filled with [gameId] and [confirmedIds], exactly like tapping "+"
/// would, so an admin can still adjust for no-shows/walk-ins before saving.
class ScheduledEvent {
  final String id;
  final String salonId;
  final String gameId;

  /// Which of the game's rules this will be scored under — see
  /// `AppState.pickRule`. Null for a game with only its one default rule.
  final String? ruleId;

  /// 'game' | 'tournament' — the same values as `NewGameDraft.creationKind`,
  /// so `AppState.startEvent` can assign it straight through.
  final String kind;

  final String name;
  final DateTime scheduledAt;

  /// Max number of confirmed sign-ups — null means unlimited (no waitlist
  /// ever forms). See [confirmedIds]/[waitlistIds].
  final int? capacity;

  /// Every uid that signed up, in sign-up order — the first [capacity] are
  /// confirmed, the rest are waitlisted (see [confirmedIds]/[waitlistIds]).
  /// Deliberately a single ordered list rather than two separate ones: when
  /// someone confirmed cancels (a plain `arrayRemove`), whoever was next on
  /// the waitlist becomes confirmed automatically just by virtue of the
  /// slice shifting — no explicit "promote" bookkeeping needed.
  final List<String> signups;

  /// 'upcoming' | 'started' — set to 'started' once an admin actually
  /// launches it (see [resultMatchId]/[resultTournamentId]); it then drops
  /// out of the "à venir" home section but stays around for reference.
  final String status;

  /// Set once started as a plain match/tournament, respectively — mutually
  /// exclusive, matching [kind].
  final String? resultMatchId;
  final String? resultTournamentId;

  final String createdByUid;
  final DateTime createdAt;

  const ScheduledEvent({
    required this.id,
    required this.salonId,
    required this.gameId,
    this.ruleId,
    required this.kind,
    required this.name,
    required this.scheduledAt,
    this.capacity,
    required this.signups,
    this.status = 'upcoming',
    this.resultMatchId,
    this.resultTournamentId,
    required this.createdByUid,
    required this.createdAt,
  });

  bool get isStarted => status == 'started';

  List<String> get confirmedIds => capacity == null ? signups : signups.take(capacity!).toList();
  List<String> get waitlistIds => capacity == null ? const [] : signups.skip(capacity!).toList();

  /// Whether every confirmed slot is taken — a further sign-up still
  /// succeeds, it just lands on the waitlist (see [waitlistIds]).
  bool get isFull => capacity != null && signups.length >= capacity!;

  ScheduledEvent copyWith({
    List<String>? signups,
    String? status,
    String? resultMatchId,
    String? resultTournamentId,
  }) =>
      ScheduledEvent(
        id: id,
        salonId: salonId,
        gameId: gameId,
        ruleId: ruleId,
        kind: kind,
        name: name,
        scheduledAt: scheduledAt,
        capacity: capacity,
        signups: signups ?? this.signups,
        status: status ?? this.status,
        resultMatchId: resultMatchId ?? this.resultMatchId,
        resultTournamentId: resultTournamentId ?? this.resultTournamentId,
        createdByUid: createdByUid,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'salonId': salonId,
        'gameId': gameId,
        if (ruleId != null) 'ruleId': ruleId,
        'kind': kind,
        'name': name,
        'scheduledAt': Timestamp.fromDate(scheduledAt),
        if (capacity != null) 'capacity': capacity,
        'signups': signups,
        'status': status,
        if (resultMatchId != null) 'resultMatchId': resultMatchId,
        if (resultTournamentId != null) 'resultTournamentId': resultTournamentId,
        'createdByUid': createdByUid,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory ScheduledEvent.fromDoc(String id, Map<String, dynamic> data) => ScheduledEvent(
        id: id,
        salonId: (data['salonId'] as String?) ?? '',
        gameId: (data['gameId'] as String?) ?? '',
        ruleId: data['ruleId'] as String?,
        kind: (data['kind'] as String?) ?? 'game',
        name: (data['name'] as String?) ?? 'Évènement',
        scheduledAt: (data['scheduledAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        capacity: (data['capacity'] as num?)?.toInt(),
        signups: ((data['signups'] as List?) ?? const []).map((e) => e as String).toList(),
        status: (data['status'] as String?) ?? 'upcoming',
        resultMatchId: data['resultMatchId'] as String?,
        resultTournamentId: data['resultTournamentId'] as String?,
        createdByUid: (data['createdByUid'] as String?) ?? '',
        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
}
