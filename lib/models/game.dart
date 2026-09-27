import 'game_themes.dart';
import 'match.dart';

/// How a game's score is counted — mirrors the "Type de comptage" picker
/// in the new-game creation form.
enum CountType {
  highWins, // points, highest wins (Catan, Mario Kart…)
  lowWins, // points, lowest wins (Skyjo, golf…)
  wins, // rounds/hands won (Président, belote…)
  ranks, // per-round finishing order mapped to named roles (Président's roles, etc.)
  winLoss, // no score at all — just mark each player/team victorious or defeated (1v1 games, etc.)
  time, // a time, fastest wins (contre-la-montre, speedrun…) — stored in milliseconds
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
    case 'time':
      return CountType.time;
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
    case CountType.time:
      return 'time';
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

  /// A time ([CountType.time]) is won by the lowest value too.
  bool get lowWins => countType == CountType.lowWins || countType == CountType.time;
  bool get isTime => countType == CountType.time;
  bool get isRanks => countType == CountType.ranks;
  bool get isWinLoss => countType == CountType.winLoss;
  bool get hasScoreFields => scoreFields != null && scoreFields!.isNotEmpty;

  /// The default scoring unit a new match under this rule should start with.
  String get defaultUnit => switch (countType) {
        CountType.wins => 'wins',
        CountType.time => 'time',
        _ => 'points',
      };

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

/// What each player picks for a match, as configured on a [Game] (see
/// [Game.characterChoice]): a user-chosen [label] ("Héros", "Merveille",
/// "Faction"…) with its grammatical gender, so every UI string can read
/// naturally ("Choisir une merveille"), and the [options] offered.
class CharacterChoice {
  static const defaultLabel = 'Personnage';

  final String label;
  final bool feminine;
  final List<String> options;

  const CharacterChoice({this.label = defaultLabel, this.feminine = false, this.options = const []});

  String get _lower => label.isEmpty ? label : label[0].toLowerCase() + label.substring(1);

  /// "Choisir une merveille" / "Choisir un héros".
  String get pickPrompt => 'Choisir ${feminine ? 'une' : 'un'} $_lower';

  /// "Merveille de Léa".
  String ofPlayer(String name) => '$label de $name';

  /// "Déjà prise par Léa" / "Déjà pris par Léa".
  String takenBy(String name) => 'Déjà ${feminine ? 'prise' : 'pris'} par $name';

  Map<String, dynamic> toMap() => {'label': label, if (feminine) 'feminine': feminine, 'options': options};

  factory CharacterChoice.fromMap(Map<String, dynamic> m) => CharacterChoice(
        label: (m['label'] as String?)?.trim().isNotEmpty == true ? (m['label'] as String).trim() : defaultLabel,
        feminine: (m['feminine'] as bool?) ?? false,
        options: ((m['options'] as List?) ?? const []).map((e) => e as String).toList(),
      );
}

/// Something picked once for the whole match, as configured on a [Game]
/// (see [Game.setupChoice]): Dominion's kingdom cards, Catan's expansions,
/// Carcassonne's modules… [label] names what's picked ("Cartes Royaume",
/// "Extensions"…) and [count], when set, how many a match normally uses —
/// only a guide (and what "Tirer au hasard" draws): the wizard never
/// blocks on it.
class SetupChoice {
  static const defaultLabel = 'Extensions';

  final String label;
  final List<String> options;
  final int? count;

  const SetupChoice({this.label = defaultLabel, this.options = const [], this.count});

  Map<String, dynamic> toMap() => {'label': label, 'options': options, if (count != null) 'count': count};

  factory SetupChoice.fromMap(Map<String, dynamic> m) => SetupChoice(
        label: (m['label'] as String?)?.trim().isNotEmpty == true ? (m['label'] as String).trim() : defaultLabel,
        options: ((m['options'] as List?) ?? const []).map((e) => e as String).toList(),
        count: (m['count'] as num?)?.toInt(),
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

  /// How many players the game supports (see [playersLabel]) — both bounds
  /// optional. Only informative: the match wizard warns when the picked
  /// players fall outside it (see `Step2Players`) but never blocks.
  final int? minPlayers;
  final int? maxPlayers;

  /// Ids of the theme tags picked for this game, drawn from its category's
  /// own list (see [themesForCategory]/[themeTags]) — purely descriptive.
  final List<String> themes;

  /// Something each player picks for a match — Dice Throne's heroes, 7
  /// Wonders' wonders, Root's factions… Null for most games (the switch in
  /// the game form is off); when set, the players step offers a per-player
  /// picker (see `MatchEntry.character`).
  final CharacterChoice? characterChoice;

  /// What a match is set up with — Dominion's kingdom cards, Catan's
  /// expansions… Null for most games; when set, the players step offers a
  /// multi-select of what this match uses (see `GameMatch.setupPicks`).
  final SetupChoice? setupChoice;

  /// Only meaningful for a Server's catalog (see
  /// `FirebaseGamesRepository.rootCollection` — a Group's own catalog never
  /// sets this): which Salon this game belongs to, so each Salon gets its
  /// own carved-out catalog instead of sharing the whole Server's. Null
  /// means the game predates this field and stays visible in every Salon of
  /// the Server (see `AppState._resubscribeSalonData`), or that it lives in
  /// a Group, where the concept doesn't apply.
  final String? salonId;

  /// Id of the `gameLibrary` doc this game was imported from, as long as it
  /// still mirrors it: the `onGameLibraryWritten` Cloud Function pushes every
  /// later change of that library game onto each copy still carrying this.
  /// Any edit of the copy itself drops it (see [copyWith]'s
  /// `detachFromLibrary`), so a customized game is never overwritten. Null
  /// for a game created by hand or no longer following the library.
  final String? libraryId;

  const Game({
    required this.id,
    required this.name,
    required this.emoji,
    required this.category,
    required this.rules,
    this.ruleSections = const [],
    this.minPlayers,
    this.maxPlayers,
    this.themes = const [],
    this.characterChoice,
    this.setupChoice,
    this.salonId,
    this.libraryId,
  });

  bool get followsLibrary => libraryId != null;

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
    int? minPlayers,
    int? maxPlayers,
    List<String> themes = const [],
  }) =>
      Game(
        id: id,
        name: name,
        emoji: emoji,
        category: category,
        ruleSections: ruleSections,
        minPlayers: minPlayers,
        maxPlayers: maxPlayers,
        themes: themes,
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

  /// "2–4 joueurs", "3 joueurs", "2 joueurs min." or "4 joueurs max." — null
  /// when no bound is set.
  String? get playersLabel {
    final lo = minPlayers, hi = maxPlayers;
    if (isSoloOnly) return 'Solo';
    if (lo != null && hi != null) return lo == hi ? '$lo joueurs' : '$lo–$hi joueurs';
    if (lo != null) return '$lo joueurs min.';
    if (hi != null) return '$hi joueurs max.';
    return null;
  }

  /// "3–4 joueurs · Stratégie · Gestion" — the players line and the first
  /// [themeCount] themes, or null when the game has neither.
  String? summaryLine({int themeCount = 2}) {
    final bits = [?playersLabel, ...themeTags.take(themeCount).map((t) => t.label)];
    return bits.isEmpty ? null : bits.join(' · ');
  }

  /// Played alone, and only alone — a game of "Mon espace solo" (see
  /// [asSolo]).
  bool get isSoloOnly => minPlayers == 1 && maxPlayers == 1;

  /// Whether this game can be played alone at all (a library game offered
  /// to "Mon espace solo") — no minimum, or a minimum of 1.
  bool get playableSolo => minPlayers == null || minPlayers! <= 1;

  /// Whether this game can be played by several (a library game offered to
  /// a group) — anything but [isSoloOnly]-style "1 player max".
  bool get playableInGroup => maxPlayers == null || maxPlayers! >= 2;

  /// This game as it lives in "Mon espace solo": exactly one player, every
  /// other setting unchanged.
  Game asSolo() => Game(
        id: id,
        name: name,
        emoji: emoji,
        category: category,
        rules: rules,
        ruleSections: ruleSections,
        minPlayers: 1,
        maxPlayers: 1,
        themes: themes,
        characterChoice: characterChoice,
        setupChoice: setupChoice,
        salonId: salonId,
        libraryId: libraryId,
      );

  bool acceptsPlayerCount(int n) => (minPlayers == null || n >= minPlayers!) && (maxPlayers == null || n <= maxPlayers!);

  /// [themes] resolved against this game's category, in the category list's
  /// order — an id the category no longer offers is silently dropped.
  List<GameThemeTag> get themeTags => themesForCategory(category).where((t) => themes.contains(t.id)).toList();

  bool get hasCharacters => characterChoice != null && characterChoice!.options.isNotEmpty;

  bool get hasSetupChoice => setupChoice != null && setupChoice!.options.isNotEmpty;

  /// A setup of exactly one pick — a Mario Kart circuit, a level, a map —
  /// is picked like a radio button, and records only compare matches on
  /// the same pick (a time on one circuit says nothing about another).
  bool get isSinglePickSetup => hasSetupChoice && setupChoice!.count == 1;

  /// What [match] was played on when [isSinglePickSetup] — null otherwise,
  /// or when nothing was picked.
  String? recordPickOf(GameMatch match) => isSinglePickSetup && match.setupPicks.length == 1 ? match.setupPicks.single : null;

  GameRule get defaultRule => rules.first;
  bool get hasMultipleRules => rules.length > 1;

  GameRule? ruleById(String? id) => id == null ? null : rules.where((r) => r.id == id).firstOrNull;

  /// The rule to actually use: [id] if it names one of [rules], otherwise
  /// [defaultRule] — so callers never have to null-check just to fall back
  /// to "the game's one rule" when no explicit choice was made.
  GameRule resolveRule(String? id) => ruleById(id) ?? defaultRule;

  Game copyWith({List<GameRuleSection>? ruleSections, List<GameRule>? rules, bool detachFromLibrary = false}) => Game(
        id: id,
        name: name,
        emoji: emoji,
        category: category,
        ruleSections: ruleSections ?? this.ruleSections,
        rules: rules ?? this.rules,
        minPlayers: minPlayers,
        maxPlayers: maxPlayers,
        themes: themes,
        characterChoice: characterChoice,
        setupChoice: setupChoice,
        salonId: salonId,
        libraryId: detachFromLibrary ? null : libraryId,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'emoji': emoji,
        'category': category,
        'rules': rules.map((r) => r.toMap()).toList(),
        if (ruleSections.isNotEmpty) 'ruleSections': ruleSections.map((s) => s.toMap()).toList(),
        if (minPlayers != null) 'minPlayers': minPlayers,
        if (maxPlayers != null) 'maxPlayers': maxPlayers,
        if (themes.isNotEmpty) 'themes': themes,
        if (characterChoice != null) 'characterChoice': characterChoice!.toMap(),
        if (setupChoice != null) 'setupChoice': setupChoice!.toMap(),
        if (salonId != null) 'salonId': salonId,
        if (libraryId != null) 'libraryId': libraryId,
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
      minPlayers: (data['minPlayers'] as num?)?.toInt(),
      maxPlayers: (data['maxPlayers'] as num?)?.toInt(),
      themes: ((data['themes'] as List?) ?? const []).map((e) => e as String).toList(),
      characterChoice: data['characterChoice'] is Map ? CharacterChoice.fromMap(Map<String, dynamic>.from(data['characterChoice'] as Map)) : null,
      setupChoice: data['setupChoice'] is Map ? SetupChoice.fromMap(Map<String, dynamic>.from(data['setupChoice'] as Map)) : null,
      salonId: data['salonId'] as String?,
      libraryId: data['libraryId'] as String?,
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
