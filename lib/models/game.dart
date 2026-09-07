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

class Game {
  final String id;
  final String name;
  final String emoji;
  final String category;
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

  /// Whether a match for this game can span several rounds, with scores
  /// accumulating round after round, instead of a single entry deciding
  /// the whole match. Applies uniformly across every [CountType]: for
  /// points/wins games it unlocks the "Par manche" input mode; for
  /// [CountType.ranks] it unlocks "Plusieurs manches" (rank each hand,
  /// points accumulate — e.g. Président played over several hands).
  final bool multiRound;

  /// Set when this game is a variant of another game in the same catalog
  /// (e.g. "Président — variante à 1 joueur") — a full standalone game in
  /// its own right (own rules, playable/scoreable independently), just
  /// grouped under its parent in the picker instead of shown as its own
  /// top-level entry. Null for a regular, standalone game.
  final String? parentGameId;

  /// Rules reminders, grouped by category — purely a reference for players,
  /// never consulted by the scoring logic (see [GameRuleSection]).
  final List<GameRuleSection> ruleSections;

  /// Optional color-coded score breakdown used by point-based games.
  final List<GameScoreField>? scoreFields;

  const Game({
    required this.id,
    required this.name,
    required this.emoji,
    required this.category,
    required this.countType,
    this.pointLimit,
    this.topRoles,
    this.bottomRoles,
    this.topPoints,
    this.bottomPoints,
    this.multiRound = false,
    this.parentGameId,
    this.ruleSections = const [],
    this.scoreFields,
  });

  bool get lowWins => countType == CountType.lowWins;
  bool get isRanks => countType == CountType.ranks;
  bool get isWinLoss => countType == CountType.winLoss;
  bool get isVariant => parentGameId != null;

  Game copyWith({List<GameRuleSection>? ruleSections, List<GameScoreField>? scoreFields}) => Game(
        id: id,
        name: name,
        emoji: emoji,
        category: category,
        countType: countType,
        pointLimit: pointLimit,
        topRoles: topRoles,
        bottomRoles: bottomRoles,
        topPoints: topPoints,
        bottomPoints: bottomPoints,
        multiRound: multiRound,
        parentGameId: parentGameId,
        ruleSections: ruleSections ?? this.ruleSections,
          scoreFields: scoreFields ?? this.scoreFields,
      );

        bool get hasScoreFields => scoreFields != null && scoreFields!.isNotEmpty;

  /// The default scoring unit a new match for this game should start with.
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
    if (fromEnd >= 0 && fromEnd < bottom.length) return fromEnd < bottomPts.length ? bottomPts[fromEnd] : 0;
    if (top.isEmpty && bottom.isEmpty) return playerCount - 1 - position;
    return 0;
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'emoji': emoji,
        'category': category,
        'countType': countTypeToString(countType),
        if (pointLimit != null) 'pointLimit': pointLimit,
        if (topRoles != null) 'topRoles': topRoles,
        if (bottomRoles != null) 'bottomRoles': bottomRoles,
        if (topPoints != null) 'topPoints': topPoints,
        if (bottomPoints != null) 'bottomPoints': bottomPoints,
        if (multiRound) 'multiRound': multiRound,
        if (parentGameId != null) 'parentGameId': parentGameId,
        if (ruleSections.isNotEmpty) 'ruleSections': ruleSections.map((s) => s.toMap()).toList(),
        if (scoreFields != null && scoreFields!.isNotEmpty) 'scoreFields': scoreFields!.map((f) => f.toMap()).toList(),
      };

  factory Game.fromDoc(String id, Map<String, dynamic> data) {
    return Game(
      id: id,
      name: (data['name'] as String?) ?? 'Jeu',
      emoji: (data['emoji'] as String?) ?? '🎲',
      category: (data['category'] as String?) ?? 'Autre',
      countType: countTypeFromString((data['countType'] as String?) ?? 'points'),
      pointLimit: (data['pointLimit'] as num?)?.toInt(),
      topRoles: (data['topRoles'] as List?)?.map((e) => e as String).toList(),
      bottomRoles: (data['bottomRoles'] as List?)?.map((e) => e as String).toList(),
      topPoints: (data['topPoints'] as List?)?.map((e) => (e as num).toInt()).toList(),
      bottomPoints: (data['bottomPoints'] as List?)?.map((e) => (e as num).toInt()).toList(),
      multiRound: (data['multiRound'] as bool?) ?? false,
      parentGameId: data['parentGameId'] as String?,
      ruleSections: ((data['ruleSections'] as List?) ?? const [])
          .map((e) => GameRuleSection.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
        scoreFields: ((data['scoreFields'] as List?) ?? const [])
          .map((e) => GameScoreField.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  static const List<String> categories = ['Société', 'Cartes', 'Jeu vidéo', 'Sport', 'Autre'];

  static const List<String> emojiChoices = [
    '🎲', '🃏', '🂠', '🏎️', '🎯', '⏱️', '🎩', '♟️',
    '🎳', '🏓', '⚽', '🎮', '🀄', '🧩', '🎱', '🥏',
  ];
}
