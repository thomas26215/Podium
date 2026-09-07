import '../models/game.dart';
import '../models/match.dart';

/// Mutable state for the 3-step "new game" sheet — mirrors the prototype's
/// `state.draft`.
class NewGameDraft {
  String? gameId;
  String mode; // 'ffa' | 'team'
  String unit; // 'points' | 'wins'
  int teamCount;
  List<String> playerIds;
  Map<String, String> team; // uid -> 'A'..'D'
  Map<String, int> points; // uid -> current score
  Map<String, Map<String, int>> scoreBreakdown; // uid -> fieldId -> score
  String inputMode; // 'quick' | 'rounds'
  List<TimelinePoint> timeline;
  List<String> rankOrder; // CountType.ranks games: best-to-worst finishing order

  /// "Best of N" format: 1 = a single ordinary match, otherwise the total
  /// number of legs to play (3/5/7) — see [AppState.saveGame].
  int bestOf;

  /// Id shared by every leg of the current series once the first leg has
  /// been saved (null before then, or for a plain single match).
  String? seriesId;

  /// 1-based index of the leg currently being scored within the series.
  int seriesLegIndex;

  /// When this match was actually played, if backdated ("hier",
  /// "avant-hier", or any picked date) — null means "today, whenever it's
  /// actually saved" (see [AppState.setPlayedAt]/`saveGame`), so a long-running
  /// match still gets its real save time instead of freezing at the moment
  /// the sheet was opened.
  DateTime? playedAt;

  /// Set once the "cette série est déjà jouée d'avance" popup has been
  /// dismissed with "Ne plus afficher pour cette partie" (see
  /// [AppState.draftSeriesDecided]/`dismissSeriesDecidedPrompt`) — stops it
  /// from reappearing after every remaining leg of this same series.
  bool seriesDecidedPromptDismissed;

  /// Team mode only: 'perPlayer' (default — each player has their own score,
  /// the team's total is their sum) or 'global' (one combined score entered
  /// directly per team, split evenly across its members when the match is
  /// saved — see `AppState._teamGlobalEntries`). Only affects "Saisie
  /// rapide"; "Par manche" always stay per-player.
  String teamScoreMode;

  /// Team id ('A'..'D') -> its combined score, used only when
  /// [teamScoreMode] is 'global'.
  Map<String, int> teamPoints;

  NewGameDraft({
    this.gameId,
    this.mode = 'ffa',
    this.unit = 'points',
    this.teamCount = 2,
    List<String>? playerIds,
    Map<String, String>? team,
    Map<String, int>? points,
    Map<String, Map<String, int>>? scoreBreakdown,
    this.inputMode = 'quick',
    List<TimelinePoint>? timeline,
    List<String>? rankOrder,
    this.bestOf = 1,
    this.seriesId,
    this.seriesLegIndex = 1,
    this.playedAt,
    this.seriesDecidedPromptDismissed = false,
    this.teamScoreMode = 'perPlayer',
    Map<String, int>? teamPoints,
  })  : playerIds = playerIds ?? [],
        team = team ?? {},
        points = points ?? {},
        scoreBreakdown = scoreBreakdown ?? {},
        timeline = timeline ?? [],
        rankOrder = rankOrder ?? [],
        teamPoints = teamPoints ?? {};

  factory NewGameDraft.initial() => NewGameDraft();

  /// Serialized for local on-device storage (see `AppState._persistDraftLocally`)
  /// so an in-progress match survives an app kill and can be resumed later —
  /// deliberately separate from `GameMatch.toMap`, which targets Firestore.
  Map<String, dynamic> toJson() => {
        'gameId': gameId,
        'mode': mode,
        'unit': unit,
        'teamCount': teamCount,
        'playerIds': playerIds,
        'team': team,
        'points': points,
        'scoreBreakdown': scoreBreakdown,
        'inputMode': inputMode,
        'timeline': timeline.map((t) => t.toJson()).toList(),
        'rankOrder': rankOrder,
        'bestOf': bestOf,
        'seriesId': seriesId,
        'seriesLegIndex': seriesLegIndex,
        'playedAt': playedAt?.millisecondsSinceEpoch,
        'seriesDecidedPromptDismissed': seriesDecidedPromptDismissed,
        'teamScoreMode': teamScoreMode,
        'teamPoints': teamPoints,
      };

  factory NewGameDraft.fromJson(Map<String, dynamic> m) => NewGameDraft(
        gameId: m['gameId'] as String?,
        mode: m['mode'] as String? ?? 'ffa',
        unit: m['unit'] as String? ?? 'points',
        teamCount: (m['teamCount'] as num?)?.toInt() ?? 2,
        playerIds: (m['playerIds'] as List?)?.map((e) => e as String).toList(),
        team: (m['team'] as Map?)?.map((k, v) => MapEntry(k as String, v as String)),
        points: (m['points'] as Map?)?.map((k, v) => MapEntry(k as String, (v as num).toInt())),
        scoreBreakdown: (m['scoreBreakdown'] as Map?)?.map(
          (k, v) => MapEntry(
            k as String,
            (v as Map).map((fieldId, value) => MapEntry(fieldId as String, (value as num).toInt())),
          ),
        ),
        inputMode: m['inputMode'] as String? ?? 'quick',
        timeline: (m['timeline'] as List?)?.map((e) => TimelinePoint.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
        rankOrder: (m['rankOrder'] as List?)?.map((e) => e as String).toList(),
        bestOf: (m['bestOf'] as num?)?.toInt() ?? 1,
        seriesId: m['seriesId'] as String?,
        seriesLegIndex: (m['seriesLegIndex'] as num?)?.toInt() ?? 1,
        playedAt: (m['playedAt'] as num?) != null ? DateTime.fromMillisecondsSinceEpoch((m['playedAt'] as num).toInt()) : null,
        seriesDecidedPromptDismissed: (m['seriesDecidedPromptDismissed'] as bool?) ?? false,
        teamScoreMode: m['teamScoreMode'] as String? ?? 'perPlayer',
        teamPoints: (m['teamPoints'] as Map?)?.map((k, v) => MapEntry(k as String, (v as num).toInt())),
      );
}

/// A [NewGameDraft] persisted locally while its match was being scored,
/// found on the device at sign-in — offered back to the user as "resume
/// your unfinished match" (see `AppState.pendingLocalDraft`).
class PendingLocalDraft {
  final String rootGroupId;
  final String groupId;
  final NewGameDraft draft;
  final DateTime updatedAt;

  /// The Firebase live session this match was broadcasting under when the
  /// app was left, if any — lets `AppState.resumeLocalDraft` reattach to the
  /// same session (instead of starting a new one) when resumed within the
  /// grace window, so spectators see a continuous match rather than a gap.
  final String? liveSessionId;

  /// When the session was put "on hold" (app backgrounded/closed) — null if
  /// it was still actively broadcasting. Compared against the grace window
  /// to decide whether [liveSessionId] is still good to reuse.
  final DateTime? liveSessionHeldAt;

  const PendingLocalDraft({
    required this.rootGroupId,
    required this.groupId,
    required this.draft,
    required this.updatedAt,
    this.liveSessionId,
    this.liveSessionHeldAt,
  });
}

/// State for the "create a new game" mini-form nested inside step 1.
class GameFormDraft {
  String name;
  String emoji;
  String category;
  CountType countType;
  String pointLimit; // free-text field; parsed to int? on submit

  // CountType.ranks: explicit "Nth place = this role" mapping, defined from
  // each end independently — topRoles[0] = 1st place, bottomRoles[0] = last
  // place, etc. Blanks are dropped on submit (see cleanTopRoles/cleanBottomRoles).
  List<String> topRoles;
  List<String> bottomRoles;
  List<GameScoreField> scoreFields;

  /// Whether this game can be played over several rounds with scores
  /// accumulating — applies to every count type, not just ranks.
  bool multiRound;

  /// Set while creating a variant of an existing game (see [Game.parentGameId])
  /// — carried through to `AppState.createGame`. Not user-editable in the
  /// form itself, just shown as a "Variante de X" label.
  final String? parentGameId;

  GameFormDraft({
    this.name = '',
    this.emoji = '🎲',
    this.category = 'Société',
    this.countType = CountType.highWins,
    this.pointLimit = '',
    List<String>? topRoles,
    List<String>? bottomRoles,
    List<GameScoreField>? scoreFields,
    this.multiRound = false,
    this.parentGameId,
  })  : topRoles = topRoles ?? [''],
      bottomRoles = bottomRoles ?? [''],
      scoreFields = scoreFields ?? [];

  factory GameFormDraft.initial({String? parentGameId}) => GameFormDraft(parentGameId: parentGameId);

  // Leaving every place name blank for CountType.ranks is valid — it's a
  // plain "classement" with no named roles, scored purely by rank.
  bool get isValid => name.trim().isNotEmpty;

  int? get parsedPointLimit => int.tryParse(pointLimit.trim());

  List<String> get cleanTopRoles => topRoles.where((r) => r.trim().isNotEmpty).map((r) => r.trim()).toList();
  List<String> get cleanBottomRoles => bottomRoles.where((r) => r.trim().isNotEmpty).map((r) => r.trim()).toList();

  /// Auto-derived points, best place first (e.g. 2 top roles → 2, 1) and
  /// worst place most negative (e.g. 2 bottom roles → -2, -1), so a neutral
  /// (unranked) player's implicit 0 sits right in the middle.
  List<int> get derivedTopPoints {
    final n = cleanTopRoles.length;
    return List.generate(n, (i) => n - i);
  }

  List<int> get derivedBottomPoints {
    final n = cleanBottomRoles.length;
    return List.generate(n, (i) => -(n - i));
  }
}
