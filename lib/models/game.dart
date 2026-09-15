/// How a game's score is counted — mirrors the "Type de comptage" picker
/// in the new-game creation form.
enum CountType {
  highWins, // points, highest wins (Catan, Mario Kart…)
  lowWins, // points, lowest wins (Skyjo, golf…)
  wins, // rounds/hands won (Président, belote…)
  ranks, // per-round finishing order mapped to named roles (Président's roles, etc.)
  winLoss, // no score at all — just mark each player/team victorious or defeated (1v1 games, etc.)
}

CountType countTypeFromString(String s) {
  switch (s) {
    case 'low':
      return CountType.lowWins;
    case 'wins':
      return CountType.wins;
    case 'ranks':
      return CountType.ranks;
    case 'winloss':
      return CountType.winLoss;
    default:
      return CountType.highWins;
  }
}

String countTypeToString(CountType c) {
  switch (c) {
    case CountType.lowWins:
      return 'low';
    case CountType.wins:
      return 'wins';
    case CountType.ranks:
      return 'ranks';
    case CountType.winLoss:
      return 'winloss';
    case CountType.highWins:
      return 'points';
  }
}

/// One colored scoring category used by point-based games such as 7 Wonders.
class GameScoreField {
  final String id;
  final String label;
  final int color;

  const GameScoreField({required this.id, required this.label, required this.color});

  GameScoreField copyWith({String? id, String? label, int? color}) => GameScoreField(
        id: id ?? this.id,
        label: label ?? this.label,
        color: color ?? this.color,
      );

  Map<String, dynamic> toMap() => {'id': id, 'label': label, 'color': color};

  factory GameScoreField.fromMap(Map<String, dynamic> m) => GameScoreField(
        id: (m['id'] as String?) ?? '',
        label: (m['label'] as String?) ?? '',
        color: (m['color'] as num?)?.toInt() ?? palette.first,
      );

  static const palette = [
    0xFF3B82F6,
    0xFF22C55E,
    0xFFEF4444,
    0xFFF59E0B,
    0xFF8B5CF6,
    0xFF06B6D4,
    0xFFF97316,
    0xFFEC4899,
  ];
}

/// A category of rules reminders (e.g. for Rami: "Règles générales", "Règle
/// de la première pose", "Règles spéciales"…), each holding its own list of
/// individual rules. Purely informational — never read by the scoring logic.
class GameRuleSection {
  final String title;
  final List<String> rules;
  const GameRuleSection({required this.title, required this.rules});

  Map<String, dynamic> toMap() => {'title': title, 'rules': rules};

  factory GameRuleSection.fromMap(Map<String, dynamic> m) => GameRuleSection(
        title: (m['title'] as String?) ?? '',
        rules: ((m['rules'] as List?) ?? const []).map((e) => e as String).toList(),
      );
}

/// One named way to count the score for a [Game] (e.g. "Standard", "Rapide
/// (50 pts)", "Avec rôles"…) — a game always has at least one. Picked on the
/// dedicated wizard step right after the game itself when a game has more
/// than one (see `AppState.pickRule`/`Game.hasMultipleRules`).
class GameRule {
  final String id;
  final String name;
  final CountType countType;

  /// Optional score threshold that ends a match (e.g. Skyjo: lowest score
  /// wins, but the game is over once someone hits 100 points). Only
  /// meaningful for point-based counting (highWins/lowWins) — not for a
  /// rounds-won count, and not for [CountType.winLoss], which has no score
  /// at all.
  final int? pointLimit;

  /// Only set when [countType] is [CountType.ranks]: an explicit "Nth place
  /// = this role" mapping, defined from both ends independently (e.g.
  /// Président: topRoles = ["Président", "Vice-président"], bottomRoles =
  /// ["Trou du cul", "Vice-trou du cul"]). [topRoles] is ordered 1st, 2nd,
  /// 3rd… from the best finish; [bottomRoles] is ordered last,
  /// second-to-last, third-to-last… from the worst finish. Any position not
  /// covered by either list (the middle of the pack) gets no role at all —
  /// it's not a "place", just neutral (see [rankRole]).
  final List<String>? topRoles;
  final List<String>? bottomRoles;

  /// Parallel to [topRoles]/[bottomRoles]: the numeric score awarded for
  /// each named place, so leaderboards/standings can keep using plain point
  /// totals without special-casing ranks games. Unranked (neutral) players
  /// score 0.
  final List<int>? topPoints;
  final List<int>? bottomPoints;

  /// Whether a match scored under this rule can span several rounds, with
  /// scores accumulating round after round, instead of a single entry
  /// deciding the whole match. Applies uniformly across every [CountType]:
  /// for points/wins it unlocks the "Par manche" input mode; for
  /// [CountType.ranks] it unlocks "Plusieurs manches" (rank each hand,
  /// points accumulate — e.g. Président played over several hands).
  final bool multiRound;

  /// Optional color-coded score breakdown used by point-based rules.
  final List<GameScoreField>? scoreFields;

  /// Whether every match scored under this rule is played by the whole
  /// group together against the game itself, sharing one outcome — as
  /// opposed to the default competitive rule, where the "Chacun pour
  /// soi"/"Équipes" choice is still made per-match on the players step (see
  /// [NewGameDraft.mode] and `AppState._applyRule`). Meaningless (and left
  /// false) for [CountType.ranks], which is always a solo classement.
  final bool coop;

  const GameRule({
    required this.id,
    required this.name,
    required this.countType,
    this.pointLimit,
    this.topRoles,
    this.bottomRoles,
    this.topPoints,
    this.bottomPoints,
    this.multiRound = false,
    this.scoreFields,
    this.coop = false,
  });

  bool get lowWins => countType == CountType.lowWins;
  bool get isRanks => countType == CountType.ranks;
  bool get isWinLoss => countType == CountType.winLoss;
  bool get hasScoreFields => scoreFields != null && scoreFields!.isNotEmpty;

  /// The default scoring unit a new match under this rule should start with.
  String get defaultUnit => countType == CountType.wins ? 'wins' : 'points';

  /// Role label for finishing at 0-based `position` out of `playerCount`
  /// players. `position` counts from the top (0 = 1st place); positions
  /// covered by neither [topRoles] nor [bottomRoles] (the middle of the
  /// pack) get `null` — no role, not even a generic "neutral" one.
  String? rankRole(int position, int playerCount) {
    final top = topRoles ?? const [];
    if (position < top.length) return top[position];
    final bottom = bottomRoles ?? const [];
    final fromEnd = playerCount - 1 - position;
    if (fromEnd >= 0 && fromEnd < bottom.length) return bottom[fromEnd];
    return null;
  }

  /// Points for finishing at 0-based `position` out of `playerCount`
  /// players — same distribution as [rankRole]. If no named places are
  /// defined at all (a plain "classement" with no roles), every position
  /// scores purely by rank instead of defaulting to 0 across the board.
  int rankPoints(int position, int playerCount) {
    final top = topRoles ?? const [];
    final topPts = topPoints ?? const [];
    if (position < top.length) return position < topPts.length ? topPts[position] : 0;
    final bottom = bottomRoles ?? const [];
    final bottomPts = bottomPoints ?? const [];
    final fromEnd = playerCount - 1 - position;
    if (fromEnd >= 0 && fromEnd < bottomPts.length) return fromEnd < bottomPts.length ? bottomPts[fromEnd] : 0;
    if (top.isEmpty && bottom.isEmpty) return playerCount - 1 - position;
    return 0;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'countType': countTypeToString(countType),
        if (pointLimit != null) 'pointLimit': pointLimit,
        if (topRoles != null) 'topRoles': topRoles,
        if (bottomRoles != null) 'bottomRoles': bottomRoles,
        if (topPoints != null) 'topPoints': topPoints,
        if (bottomPoints != null) 'bottomPoints': bottomPoints,
        if (multiRound) 'multiRound': multiRound,
        if (scoreFields != null && scoreFields!.isNotEmpty) 'scoreFields': scoreFields!.map((f) => f.toMap()).toList(),
        if (coop) 'coop': coop,
      };

  factory GameRule.fromMap(Map<String, dynamic> m) => GameRule(
        id: (m['id'] as String?) ?? '',
        name: (m['name'] as String?) ?? 'Standard',
        countType: countTypeFromString((m['countType'] as String?) ?? 'points'),
        pointLimit: (m['pointLimit'] as num?)?.toInt(),
        topRoles: (m['topRoles'] as List?)?.map((e) => e as String).toList(),
        bottomRoles: (m['bottomRoles'] as List?)?.map((e) => e as String).toList(),
        topPoints: (m['topPoints'] as List?)?.map((e) => (e as num).toInt()).toList(),
        bottomPoints: (m['bottomPoints'] as List?)?.map((e) => (e as num).toInt()).toList(),
        multiRound: (m['multiRound'] as bool?) ?? false,
        scoreFields: ((m['scoreFields'] as List?) ?? const [])
            .map((e) => GameScoreField.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
        coop: (m['coop'] as bool?) ?? false,
      );
}

class Game {
  final String id;
  final String name;
  final String emoji;
  final String category;

  /// Rules reminders, grouped by category — purely a reference for players,
  /// never consulted by the scoring logic (see [GameRuleSection]).
  final List<GameRuleSection> ruleSections;

  /// Every named way this game can be scored (see [GameRule]) — always at
  /// least one. Picked via the dedicated wizard step when there's more than
  /// one (see [hasMultipleRules]).
  final List<GameRule> rules;

  /// Only meaningful for a Server's catalog (see
  /// `FirebaseGamesRepository.rootCollection` — a Group's own catalog never
  /// sets this): which Salon this game belongs to, so each Salon gets its
  /// own carved-out catalog instead of sharing the whole Server's. Null
  /// means the game predates this field and stays visible in every Salon of
  /// the Server (see `AppState._resubscribeSalonData`), or that it lives in
  /// a Group, where the concept doesn't apply.
  final String? salonId;

  const Game({
    required this.id,
    required this.name,
    required this.emoji,
    required this.category,
    required this.rules,
    this.ruleSections = const [],
    this.salonId,
  });

  /// Convenience constructor for the common case of a game with exactly one
  /// rule — takes the same flat scoring fields the old single-rule `Game`
  /// used to, so call sites like the default catalog seed or tests don't
  /// need to spell out a whole `GameRule` themselves.
  factory Game.simple({
    required String id,
    required String name,
    required String emoji,
    required String category,
    required CountType countType,
    int? pointLimit,
    List<String>? topRoles,
    List<String>? bottomRoles,
    List<int>? topPoints,
    List<int>? bottomPoints,
    bool multiRound = false,
    List<GameScoreField>? scoreFields,
    List<GameRuleSection> ruleSections = const [],
  }) =>
      Game(
        id: id,
        name: name,
        emoji: emoji,
        category: category,
        ruleSections: ruleSections,
        rules: [
          GameRule(
            id: 'default',
            name: 'Standard',
            countType: countType,
            pointLimit: pointLimit,
            topRoles: topRoles,
            bottomRoles: bottomRoles,
            topPoints: topPoints,
            bottomPoints: bottomPoints,
            multiRound: multiRound,
            scoreFields: scoreFields,
          ),
        ],
      );

  GameRule get defaultRule => rules.first;
  bool get hasMultipleRules => rules.length > 1;

  GameRule? ruleById(String? id) => id == null ? null : rules.where((r) => r.id == id).firstOrNull;

  /// The rule to actually use: [id] if it names one of [rules], otherwise
  /// [defaultRule] — so callers never have to null-check just to fall back
  /// to "the game's one rule" when no explicit choice was made.
  GameRule resolveRule(String? id) => ruleById(id) ?? defaultRule;

  Game copyWith({List<GameRuleSection>? ruleSections, List<GameRule>? rules}) => Game(
        id: id,
        name: name,
        emoji: emoji,
        category: category,
        ruleSections: ruleSections ?? this.ruleSections,
        rules: rules ?? this.rules,
        salonId: salonId,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'emoji': emoji,
        'category': category,
        'rules': rules.map((r) => r.toMap()).toList(),
        if (ruleSections.isNotEmpty) 'ruleSections': ruleSections.map((s) => s.toMap()).toList(),
        if (salonId != null) 'salonId': salonId,
      };

  factory Game.fromDoc(String id, Map<String, dynamic> data) {
    final rawRules = data['rules'] as List?;
    final rules = (rawRules != null && rawRules.isNotEmpty)
        ? rawRules.map((e) => GameRule.fromMap(Map<String, dynamic>.from(e as Map))).toList()
        : [_legacyRuleFromFlatFields(data)];
    return Game(
      id: id,
      name: (data['name'] as String?) ?? 'Jeu',
      emoji: (data['emoji'] as String?) ?? '🎲',
      category: (data['category'] as String?) ?? 'Autre',
      rules: rules,
      ruleSections: ((data['ruleSections'] as List?) ?? const [])
          .map((e) => GameRuleSection.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      salonId: data['salonId'] as String?,
    );
  }

  /// Reconstructs a single "Standard" rule from a game document saved before
  /// rules existed, when the scoring config lived directly on the game doc —
  /// so an old catalog keeps working unchanged, with no migration script
  /// needed. (Any `parentGameId` such a document carries is simply ignored:
  /// a former "variant" game just surfaces as its own standalone entry.)
  static GameRule _legacyRuleFromFlatFields(Map<String, dynamic> data) => GameRule(
        id: 'default',
        name: 'Standard',
        countType: countTypeFromString((data['countType'] as String?) ?? 'points'),
        pointLimit: (data['pointLimit'] as num?)?.toInt(),
        topRoles: (data['topRoles'] as List?)?.map((e) => e as String).toList(),
        bottomRoles: (data['bottomRoles'] as List?)?.map((e) => e as String).toList(),
        topPoints: (data['topPoints'] as List?)?.map((e) => (e as num).toInt()).toList(),
        bottomPoints: (data['bottomPoints'] as List?)?.map((e) => (e as num).toInt()).toList(),
        multiRound: (data['multiRound'] as bool?) ?? false,
        scoreFields: ((data['scoreFields'] as List?) ?? const [])
            .map((e) => GameScoreField.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );

  static const List<String> categories = ['Société', 'Cartes', 'Jeu vidéo', 'Sport', 'Autre'];

  static const List<String> emojiChoices = [
    '🎲', '🃏', '🂠', '🏎️', '🎯', '⏱️', '🎩', '♟️',
    '🎳', '🏓', '⚽', '🎮', '🀄', '🧩', '🎱', '🥏',
  ];
}
