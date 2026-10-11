// The Play Store demo world: every person, group, game and score shown in
// the store screenshots — fictional, and coherent from one screen to the
// next. Léa and her friends ("Les Bandits") have three months of game
// nights behind them, Hugo leads the Elo… until tonight's Skyjo, which is
// played for real in the app during the capture session (kTonightRounds).
// Around them: Léa's family, her colleagues, and her game café "Le Repaire",
// a server. Pure data, deterministic for a given `now`: main_store.dart
// wires it into the app's in-memory Fake* repositories, never into Firebase.

import 'dart:convert';
import 'dart:math';

import 'package:podium/logic/badges.dart';
import 'package:podium/logic/elo.dart';
import 'package:podium/logic/tournament_bracket.dart';
import 'package:podium/models/app_user.dart';
import 'package:podium/models/game.dart';
import 'package:podium/models/group.dart';
import 'package:podium/models/match.dart';
import 'package:podium/models/message.dart';
import 'package:podium/models/salon.dart';
import 'package:podium/models/scheduled_event.dart';
import 'package:podium/models/server.dart';
import 'package:podium/models/tournament.dart';

import 'library_games.dart';

/// Picks Les Bandits' three months of results among all the seeded draws:
/// one where the story holds (see demo_data_test.dart, which can search
/// for another).
const kDemoSeed = 1970;

/// Les Bandits' root group — the story's main stage.
const kBandits = 'bandits';

/// Léa's game café, a server.
const kCafe = 'repaire';

/// Tonight's Skyjo: who plays, in the order they're picked, and each
/// round's points in that same order. Léa, the outsider, finishes on 49;
/// Malik crosses 100 in the sixth round, which ends the game.
const kTonightPlayers = ['lea', 'hugo', 'ines', 'malik'];
const kTonightRounds = [
  [12, 5, 18, 9],
  [8, 14, 21, 17],
  [0, 11, 7, 24],
  [15, 9, 12, 13],
  [6, 22, 15, 19],
  [8, 12, 9, 21],
];

class _Person {
  final String uid;
  final String name;
  final int color;
  final String? avatar;
  const _Person(this.uid, this.name, this.color, [this.avatar]);
}

const _bandits = [
  _Person('lea', 'Léa', 0xFF5B4BE8, 'adventurer/75'),
  _Person('hugo', 'Hugo', 0xFF2AA8B0, 'adventurer/12'),
  _Person('ines', 'Inès', 0xFFE8A93B, 'adventurer/43'),
  _Person('malik', 'Malik', 0xFF1F9D57, 'adventurer/42'),
  _Person('chloe', 'Chloé', 0xFF8B5CF6, 'adventurer/110'),
  _Person('theo', 'Théo', 0xFFFF5B34, 'adventurer/17'),
  _Person('nora', 'Nora', 0xFFE5537B, 'adventurer/2'),
  _Person('sami', 'Sami', 0xFFD9622B, 'adventurer/40'),
];

const _family = [
  _Person('isabelle', 'Isabelle', 0xFFE5537B, 'adventurer/23'),
  _Person('patrick', 'Patrick', 0xFF2AA8B0),
  _Person('lucas', 'Lucas', 0xFF5B4BE8, 'adventurer/96'),
];

const _work = [
  _Person('karim', 'Karim', 0xFFE8A93B),
  _Person('sarah', 'Sarah', 0xFF1F9D57, 'adventurer/34'),
  _Person('julien', 'Julien', 0xFFFF5B34),
  _Person('emma', 'Emma', 0xFF8B5CF6, 'adventurer/64'),
];

/// The café's owner first, then its two admins.
const _cafeStaff = [
  _Person('camille', 'Camille', 0xFFD9622B, 'adventurer/87'),
  _Person('bastien', 'Bastien', 0xFF1F9D57, 'adventurer/9'),
  _Person('julie', 'Julie', 0xFF2AA8B0, 'adventurer/116'),
];

/// About half the café's regulars picked an illustrated avatar.
const _regularAvatars = {
  'Alice': 'adventurer/16', 'Arthur': 'pixel-art/5', 'Bérénice': 'adventurer/22', 'Clément': 'voxel-art/3', 'Élodie': 'adventurer/50', //
  'Florian': 'pixel-art/9', 'Jade': 'adventurer/48', 'Juliette': 'critters/7', 'Lina': 'adventurer/11', 'Louis': 'voxel-art/12', //
  'Mathis': 'pixel-art/14', 'Noah': 'critters/22', 'Océane': 'adventurer/15', 'Romain': 'voxel-art/20', 'Salomé': 'adventurer/7', 'Zoé': 'pixel-art/27',
};

const _cafeRegulars = [
  'Adrien', 'Alice', 'Amandine', 'Antoine', 'Arthur', 'Baptiste', 'Bérénice', 'Clément', 'Diane', 'Élodie', 'Enzo', //
  'Fanny', 'Florian', 'Gabriel', 'Hélène', 'Jade', 'Jérémy', 'Juliette', 'Kevin', 'Laura', 'Lina', 'Louis', //
  'Manon', 'Margaux', 'Mathis', 'Mélanie', 'Noah', 'Océane', 'Pauline', 'Quentin', 'Romain', 'Salomé', 'Valentin', 'Yanis', 'Zoé',
];

String _slug(String name) => name
    .toLowerCase()
    .replaceAll(RegExp('[éèêë]'), 'e')
    .replaceAll(RegExp('[àâ]'), 'a')
    .replaceAll(RegExp('[îï]'), 'i')
    .replaceAll(RegExp('[ôö]'), 'o')
    .replaceAll(RegExp('[ùû]'), 'u');

/// Seeded randomness, so the same `now` always gives the same world.
class _Dice {
  final Random _r;
  _Dice(int seed) : _r = Random(seed);

  /// [min]…[max], both included.
  int range(int min, int max) => min + _r.nextInt(max - min + 1);
  bool chance(double p) => _r.nextDouble() < p;
  List<T> shuffled<T>(Iterable<T> xs) => xs.toList()..shuffle(_r);

  double gauss() {
    final u1 = 1 - _r.nextDouble(), u2 = _r.nextDouble();
    return sqrt(-2 * log(u1)) * cos(2 * pi * u2);
  }

  /// [total] split into [parts] non-negative integers.
  List<int> split(int total, int parts) {
    final cuts = [for (var i = 0; i < parts - 1; i++) range(0, total)]..sort();
    final out = <int>[];
    var prev = 0;
    for (final c in [...cuts, total]) {
      out.add(c - prev);
      prev = c;
    }
    return out;
  }
}

/// How good each Bandit is, overall and at each game — what the generated
/// results lean on, with each game's share of luck.
const _general = {'lea': 1.0, 'hugo': 1.2, 'ines': 0.55, 'malik': 0.45, 'chloe': 0.5, 'theo': 0.25, 'nora': 0.35, 'sami': 0.15};
const _onGame = {
  'skyjo': {'hugo': 1.0, 'lea': -1.6, 'ines': 0.6, 'malik': 0.5, 'nora': 0.2},
  'mk': {'hugo': 1.0, 'theo': 0.7, 'sami': 0.3, 'lea': 0.1},
  'catan': {'lea': 0.9, 'malik': 0.3, 'hugo': -0.1},
  'codenames': {'lea': 0.5, 'chloe': 0.5, 'ines': 0.2},
  'dixit': {'ines': 0.8, 'lea': 0.4, 'nora': 0.3},
  'uno': {'chloe': 0.3, 'theo': 0.2},
  'petanque': {'malik': 0.9, 'sami': 0.4, 'hugo': 0.2},
  'timesup': {'ines': 0.6, 'nora': 0.5, 'chloe': 0.3},
  '7_wonders': {'lea': 0.7, 'hugo': 0.3, 'malik': 0.2},
  'molkky': {'malik': 0.6, 'sami': 0.4, 'theo': 0.2},
};
const _luck = {
  'skyjo': 0.9, 'mk': 0.6, 'catan': 0.7, 'codenames': 0.8, 'dixit': 0.9, //
  'uno': 1.4, 'petanque': 0.7, 'timesup': 0.8, '7_wonders': 0.6, 'molkky': 0.9,
};

/// The rule each game is played under (its id in the library).
const _rules = {
  'skyjo': 'standard', 'catan': 'standard', 'mk': 'grand_prix', 'codenames': 'standard', 'dixit': 'standard', //
  'uno': 'officielle', 'petanque': '13', 'timesup': 'standard', '7_wonders': 'standard', 'molkky': 'standard',
};
const _teamGames = {'codenames', 'petanque', 'timesup'};

/// Les Bandits' Wednesday and Saturday nights, oldest first: what was played.
const _nights = [
  ['catan', 'skyjo'],
  ['mk', 'uno', 'dixit'],
  ['codenames', 'skyjo'],
  ['petanque', 'molkky', 'uno'],
  ['7_wonders', 'skyjo'],
  ['timesup', 'catan'],
  ['dixit', 'skyjo'],
  ['mk', 'codenames', 'uno'],
  ['catan', '7_wonders'],
  ['petanque', 'skyjo', 'timesup'],
  ['codenames', 'dixit'],
  ['mk', 'uno'],
  ['skyjo', 'catan'],
  ['molkky', 'petanque', 'dixit'],
  ['7_wonders', 'codenames'],
  ['timesup', 'skyjo', 'uno'],
  ['catan', 'dixit'],
  ['mk', 'codenames', 'skyjo'],
  ['uno', '7_wonders'],
  ['petanque', 'molkky', 'catan'],
  ['skyjo', 'dixit'],
  ['timesup', 'codenames', 'uno'],
  ['catan', '7_wonders', 'skyjo'],
  ['mk', 'dixit'],
  ['codenames', 'catan'],
  // Last Saturday: the Mario Kart cup (built apart), then a Uno.
  ['uno'],
];

/// The Mario Kart cup's seeding (first-round pairs: 1-2, 3-4, 5-6, 7-8)
/// and who won each meeting.
const _cupSeeds = ['hugo', 'sami', 'ines', 'nora', 'lea', 'theo', 'malik', 'chloe'];
const _cupWinners = {'hugo': 3, 'lea': 2, 'ines': 1, 'malik': 1};

class DemoData {
  final Map<String, AppUser> users;
  final Map<String, Group> groups;
  final Map<String, Server> servers;
  final Map<String, Salon> salons;
  final Map<String, List<Game>> groupGames;
  final Map<String, List<Game>> serverGames;
  final Map<String, List<GameMatch>> groupMatches;
  final Map<String, List<GameMatch>> serverMatches;
  final Map<String, List<Tournament>> groupTournaments;
  final Map<String, List<GroupMessage>> groupMessages;
  final Map<String, List<GroupMessage>> serverMessages;
  final Map<String, List<ScheduledEvent>> events;
  final Map<String, List<String>> rosters;
  final List<Game> library;

  /// Tonight's Skyjo half-way through (five rounds in), as broadcast live
  /// from Léa's phone — only for a world seen by someone else at the table.
  final LiveMatchSession? liveSkyjo;

  DemoData._({
    required this.users,
    required this.groups,
    required this.servers,
    required this.salons,
    required this.groupGames,
    required this.serverGames,
    required this.groupMatches,
    required this.serverMatches,
    required this.groupTournaments,
    required this.groupMessages,
    required this.serverMessages,
    required this.events,
    required this.rosters,
    required this.library,
    required this.liveSkyjo,
  });

  /// The world as of [now]. [liveSkyjo]: tonight's Skyjo is being played
  /// (five rounds in) and broadcast — for the phone of a friend following it.
  factory DemoData.build(DateTime now, {bool liveSkyjo = false, int seed = kDemoSeed}) {
    final today = DateTime(now.year, now.month, now.day);
    DateTime at(int dayOffset, int hour, int minute) => DateTime(today.year, today.month, today.day + dayOffset, hour, minute);

    // ---- the shared library and each catalog ----
    final raw = Map<String, dynamic>.from(jsonDecode(kDemoLibraryJson) as Map);
    Game libraryGame(String id) => Game.fromDoc(id, Map<String, dynamic>.from(raw[id] as Map));
    Game catalogGame(String id) => Game.fromDoc(id, {...Map<String, dynamic>.from(raw[id] as Map), 'libraryId': id});
    final library = [for (final id in raw.keys) libraryGame(id)];
    final banditsGames = [for (final id in _rules.keys) catalogGame(id)];
    final gameById = {for (final g in banditsGames) g.id: g};

    // ---- people ----
    final users = <String, AppUser>{};
    void addPerson(_Person p) => users[p.uid] = AppUser(uid: p.uid, email: '${p.uid}@podium.demo', displayName: p.name, color: p.color, avatar: p.avatar);
    for (final p in [..._bandits, ..._family, ..._work, ..._cafeStaff]) {
      addPerson(p);
    }
    final regulars = <String>[];
    for (final name in _cafeRegulars) {
      final uid = 'c-${_slug(name)}';
      regulars.add(uid);
      users[uid] = AppUser(uid: uid, email: '$uid@podium.demo', displayName: name, color: colorForUid(uid), avatar: _regularAvatars[name]);
    }

    // ---- Les Bandits' three months ----
    final dice = _Dice(seed);
    final banditIds = [for (final p in _bandits) p.uid];
    final matches = <GameMatch>[];
    var n = 0;

    /// [ranked] best first → each player's points, in the game's own terms.
    List<int> scores(String gameId, int count) {
      final out = <int>[];
      switch (gameId) {
        case 'skyjo':
          var v = dice.range(52, 84);
          for (var i = 0; i < count; i++) {
            out.add(v);
            v += dice.range(5, 19);
          }
          if (out.last < 100) out[count - 1] = max(out[count - 2] + dice.range(3, 9), dice.range(100, 113));
        case 'catan':
          var v = 10;
          for (var i = 0; i < count; i++) {
            out.add(v);
            v = max(4, v - dice.range(1, 2));
          }
        case 'mk':
          var v = dice.range(46, 60);
          for (var i = 0; i < count; i++) {
            out.add(v);
            v = max(12, v - dice.range(3, 10));
          }
        case 'dixit':
          var v = dice.range(30, 34);
          for (var i = 0; i < count; i++) {
            out.add(v);
            v = max(10, v - dice.range(1, 5));
          }
        case 'uno':
          out.add(dice.range(500, 565));
          var v = dice.range(380, 480);
          for (var i = 1; i < count; i++) {
            out.add(v);
            v = max(60, v - dice.range(40, 120));
          }
        case 'molkky':
          var v = 50;
          for (var i = 0; i < count; i++) {
            out.add(v);
            v = max(12, v - dice.range(3, 14));
          }
        case '7_wonders':
          var v = dice.range(52, 68);
          for (var i = 0; i < count; i++) {
            out.add(v);
            v = max(30, v - dice.range(2, 9));
          }
      }
      return out;
    }

    /// Catan's and 7 Wonders' score sheet: each player's total spread over
    /// the rule's scoring categories.
    Map<String, int>? breakdown(Game game, int total, {required bool longestRoad, required bool army}) {
      final fields = game.resolveRule(_rules[game.id]).scoreFields;
      if (fields == null || fields.isEmpty) return null;
      if (game.id == 'catan') {
        final road = longestRoad ? 2 : 0, armyPts = army ? 2 : 0;
        final cards = total - road - armyPts >= 5 && dice.chance(0.3) ? 1 : 0;
        final rest = total - road - armyPts - cards;
        var cities = min(4, max(1, (rest - 2) ~/ 2));
        if (rest - 2 * cities < 1) cities = max(0, (rest - 1) ~/ 2);
        return {
          fields[0].id: rest - 2 * cities, // colonies
          fields[1].id: 2 * cities, // villes
          fields[2].id: road,
          fields[3].id: armyPts,
          fields[4].id: cards,
        };
      }
      final parts = dice.split(total, fields.length);
      return {for (final (i, f) in fields.indexed) f.id: parts[i]};
    }

    GameMatch record(String gameId, DateTime when, List<MatchEntry> entries, {String mode = 'ffa', List<TimelinePoint> timeline = const [], String? tournamentId, String? tournamentMatchId}) {
      final game = gameById[gameId]!;
      final rule = game.resolveRule(_rules[gameId]);
      ++n;
      final m = GameMatch(
        id: 'b$n',
        gameId: gameId,
        groupId: kBandits,
        mode: mode,
        unit: 'points',
        lowWins: rule.isWinLoss ? false : rule.lowWins,
        // Drawn apart from the rest, so the world's other draws stay put.
        entries: gameId == '7_wonders' ? _sevenWonders(entries, game, _Dice(7919 * n + 13)) : entries,
        timeline: timeline,
        createdAt: when,
        scoreFields: rule.scoreFields,
        ruleId: rule.id,
        inputMode: timeline.isEmpty ? 'quick' : 'rounds',
        createdByUid: entries[dice.range(0, entries.length - 1)].playerId,
        tournamentId: tournamentId,
        tournamentMatchId: tournamentMatchId,
      );
      matches.add(m);
      return m;
    }

    double skill(String uid, String gameId) => (_general[uid] ?? 0) + (_onGame[gameId]?[uid] ?? 0);
    double perf(String uid, String gameId) => skill(uid, gameId) + dice.gauss() * (_luck[gameId] ?? 1);

    /// A Skyjo scored round by round: [totals] split into as many rounds as
    /// it takes for someone to cross 100.
    List<TimelinePoint> skyjoRounds(List<String> players, List<int> totals, DateTime start) {
      final rounds = dice.range(6, 8);
      final perPlayer = [for (final t in totals) dice.split(t, rounds)];
      final timeline = <TimelinePoint>[];
      final running = List.filled(players.length, 0);
      for (var r = 0; r < rounds; r++) {
        for (var i = 0; i < players.length; i++) {
          running[i] += perPlayer[i][r];
          timeline.add(TimelinePoint(playerId: players[i], val: running[i], delta: perPlayer[i][r], time: start.add(Duration(minutes: 6 * r + 1))));
        }
      }
      return timeline;
    }

    final weekdays = [for (var w = 13; w >= 1; w--) ...[-7 * w, -7 * w + 3]];
    for (final (night, games) in _nights.indexed) {
      final day = weekdays[night];
      final isCupDay = night == _nights.length - 1;
      final present = <String>[
        if (night != 5 && night != 14) 'lea',
        if (night != 10) 'hugo',
        for (final (uid, p) in const [('ines', 0.8), ('malik', 0.75), ('chloe', 0.55), ('theo', 0.5), ('nora', 0.45), ('sami', 0.35)])
          if (dice.chance(p)) uid,
      ];
      for (final uid in dice.shuffled(banditIds)) {
        if (present.length >= 4) break;
        if (!present.contains(uid)) present.add(uid);
      }
      var clock = isCupDay ? at(day, 19, 45) : at(day, 20, 30 + dice.range(0, 20));
      for (final gameId in games) {
        final game = gameById[gameId]!;
        final minP = game.minPlayers ?? 2, maxP = min(game.maxPlayers ?? 8, 6);
        final pool = dice.shuffled(present);
        final count = min(pool.length, max(minP, dice.range(minP, maxP)));
        final players = pool.take(_teamGames.contains(gameId) ? count - count % 2 : count).toList();
        if (_teamGames.contains(gameId)) {
          final ordered = players..sort((a, b) => skill(b, gameId).compareTo(skill(a, gameId)));
          // Snake draft so teams stay close, then one team wins on the night.
          final teamA = [for (final (i, uid) in ordered.indexed) if (i % 4 == 0 || i % 4 == 3) uid];
          final teamB = [for (final uid in ordered) if (!teamA.contains(uid)) uid];
          final aPerf = teamA.map((u) => perf(u, gameId)).reduce((a, b) => a + b);
          final bPerf = teamB.map((u) => perf(u, gameId)).reduce((a, b) => a + b);
          final winners = aPerf >= bPerf ? teamA : teamB;
          final losers = aPerf >= bPerf ? teamB : teamA;
          final (winTotal, loseTotal) = switch (gameId) {
            'codenames' => (winners.length, 0),
            'petanque' => (13, dice.range(4, 12)),
            _ => (dice.range(30, 44), 0),
          };
          final loserTotal = gameId == 'timesup' ? winTotal - dice.range(2, 12) : loseTotal;
          List<MatchEntry> side(List<String> team, String id, int total) => [
                for (final (j, uid) in team.indexed)
                  MatchEntry(playerId: uid, points: gameId == 'codenames' ? (total > 0 ? 1 : 0) : total ~/ team.length + (j < total % team.length ? 1 : 0), teamId: id),
              ];
          record(gameId, clock, [...side(winners, 'A', winTotal), ...side(losers, 'B', loserTotal)], mode: 'team');
        } else {
          final night = {for (final uid in players) uid: perf(uid, gameId)};
          final ranked = players..sort((a, b) => night[b]!.compareTo(night[a]!));
          // Léa never gets the hang of Skyjo: not a single win in three months.
          if (gameId == 'skyjo' && ranked.first == 'lea') {
            ranked
              ..removeAt(0)
              ..insert(1, 'lea');
          }
          final pts = scores(gameId, ranked.length);
          final road = dice.range(0, ranked.length - 1), army = dice.range(0, ranked.length - 1);
          final entries = [
            for (final (i, uid) in ranked.indexed)
              MatchEntry(playerId: uid, points: pts[i], scoreBreakdown: breakdown(game, pts[i], longestRoad: i == road && pts[i] >= 6, army: i == army && pts[i] >= 6)),
          ];
          final timeline = gameId == 'skyjo' ? skyjoRounds(ranked, pts, clock.subtract(const Duration(minutes: 45))) : const <TimelinePoint>[];
          record(gameId, clock, dice.shuffled(entries), timeline: timeline);
        }
        clock = clock.add(Duration(minutes: dice.range(45, 70)));
      }
    }

    // ---- the Mario Kart cup, last Saturday afternoon ----
    final cupDay = weekdays.last;
    final entrants = [for (final (i, uid) in _cupSeeds.indexed) TournamentEntrant(id: 'e${i + 1}', playerIds: [uid])];
    String uidOf(String? entrantId) => entrants.firstWhere((e) => e.id == entrantId).playerIds.first;
    var cup = Tournament(
      id: 'cup-mk',
      groupId: kBandits,
      gameId: 'mk',
      ruleId: _rules['mk'],
      name: 'Coupe Mario Kart',
      format: TournamentFormat.singleElimination,
      entrants: entrants,
      matches: buildSingleElimination([for (final e in entrants) e.id]),
      createdAt: at(cupDay, 14, 20),
      createdByUid: 'hugo',
    );
    final cupWinsLeft = Map.of(_cupWinners);
    var cupClock = at(cupDay, 14, 35);
    while (cup.matches.any((m) => m.isReady)) {
      final node = cup.matches.where((m) => m.isReady).reduce((a, b) => a.round != b.round ? (a.round < b.round ? a : b) : (a.position < b.position ? a : b));
      final a = uidOf(node.entrantAId), b = uidOf(node.entrantBId);
      final aWins = (cupWinsLeft[a] ?? 0) > 0 && ((cupWinsLeft[b] ?? 0) == 0 || (cupWinsLeft[a]! > cupWinsLeft[b]!));
      final (winner, loser) = aWins ? (a, b) : (b, a);
      cupWinsLeft[winner] = cupWinsLeft[winner]! - 1;
      final top = dice.range(44, 58);
      final m = record('mk', cupClock, [MatchEntry(playerId: winner, points: top), MatchEntry(playerId: loser, points: top - dice.range(3, 14))], tournamentId: cup.id, tournamentMatchId: node.id);
      cup = advanceResult(cup, matchId: node.id, winnerEntrantId: aWins ? node.entrantAId! : node.entrantBId!, gameMatchId: m.id);
      cupClock = cupClock.add(Duration(minutes: dice.range(14, 22)));
    }
    matches.sort((x, y) => x.createdAt.compareTo(y.createdAt));

    // ---- the family and the colleagues: a few games now and then ----
    var other = 0;
    /// [star] wins most; Léa, who leads nowhere but at Les Bandits, never.
    List<GameMatch> casual(String groupId, List<String> members, String star, List<String> gameIds, int count, int seed) {
      final d = _Dice(seed);
      return [
        for (var i = 0; i < count; i++)
          () {
            final gameId = gameIds[i % gameIds.length];
            final game = gameById[gameId]!;
            final rule = game.resolveRule(_rules[gameId]);
            final players = d.shuffled(members).take(max(3, min(members.length, game.maxPlayers ?? 6))).toList();
            if (d.chance(0.5)) players.insert(0, players.removeAt(players.indexOf(star)));
            if (players.first == 'lea') players.insert(1, players.removeAt(0));
            final pts = [for (var j = 0; j < players.length; j++) rule.lowWins ? 40 + 12 * j + d.range(0, 9) : 60 - 9 * j - d.range(0, 6)];
            return GameMatch(
              id: 'o${++other}',
              gameId: gameId,
              groupId: groupId,
              mode: 'ffa',
              unit: 'points',
              lowWins: rule.lowWins,
              entries: [for (final (j, uid) in players.indexed) MatchEntry(playerId: uid, points: pts[j])],
              timeline: const [],
              createdAt: at(-3 * (count - i) - 1, 13, 10 + d.range(0, 30)),
              ruleId: rule.id,
              inputMode: 'quick',
              createdByUid: players.first,
            );
          }(),
      ];
    }

    final familyIds = ['lea', for (final p in _family) p.uid];
    final workIds = ['lea', for (final p in _work) p.uid];
    final familyMatches = casual('famille', ['isabelle', 'patrick', 'lea', 'lucas'], 'isabelle', ['uno', 'dixit', 'skyjo'], 14, 7);
    final workMatches = casual('dej', ['karim', 'sarah', 'lea', 'julien', 'emma'], 'karim', ['uno', 'skyjo', 'dixit'], 23, 11);

    // ---- groups ----
    final groups = {
      kBandits: Group(id: kBandits, name: 'Les Bandits', emoji: '🃏', emojiBg: 0xFFFFE9E1, memberIds: banditIds, ownerId: 'hugo'),
      'famille': Group(id: 'famille', name: 'Famille', emoji: '🏡', emojiBg: 0xFFE4F3EA, memberIds: familyIds, ownerId: 'isabelle'),
      'dej': Group(id: 'dej', name: 'Pause déj’', emoji: '🥪', emojiBg: 0xFFE7EBFF, memberIds: workIds, ownerId: 'karim'),
    };

    // ---- the discussion: highlights as the app's Cloud Function posts
    // them, then today's "what do we play tonight?" ----
    final messages = <GroupMessage>[
      ..._highlights(matches, gameById, since: today.subtract(const Duration(days: 12))),
      GroupMessage(id: 'm-gg', authorId: 'lea', text: 'Bien joué Hugo… mais je veux ma revanche.', createdAt: at(cupDay, 17, 2)),
      GroupMessage(id: 'm-tonight', authorId: 'malik', text: 'Soirée jeux chez moi ce soir, 20 h ?', createdAt: at(0, 12, 8)),
      GroupMessage(id: 'm-in', authorId: 'ines', text: 'Partante !', createdAt: at(0, 12, 11)),
      GroupMessage(id: 'm-chloe', authorId: 'chloe', text: 'Pas dispo ce soir… je suivrai la partie en direct !', createdAt: at(0, 12, 15)),
      GroupMessage(
        id: 'm-poll',
        authorId: 'lea',
        text: 'On joue à quoi ce soir ?',
        createdAt: at(0, 12, 19),
        pollGameIds: const ['skyjo', 'catan', 'codenames'],
        pollVotes: const {'hugo': 'skyjo', 'ines': 'skyjo', 'malik': 'skyjo', 'lea': 'catan', 'chloe': 'codenames'},
      ),
      GroupMessage(id: 'm-hugo', authorId: 'hugo', text: 'Skyjo, évidemment. Prépare-toi @Léa', createdAt: at(0, 12, 31), mentionedUids: const ['lea']),
      GroupMessage(id: 'm-lea', authorId: 'lea', text: 'On verra bien ce soir…', createdAt: at(0, 12, 34)),
    ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    // ---- Le Repaire, the game café ----
    final cafeMembers = [for (final p in _cafeStaff) p.uid, 'lea', 'hugo', ...regulars];
    final cafeGames = [for (final id in ['skyjo', 'mk', 'catan', '7_wonders', 'dixit', 'azul', 'splendor', 'king_of_tokyo']) catalogGame(id)];
    final salonSpecs = [
      ('s-skyjo', 'Soirées Skyjo du jeudi', '🃏', 0xFFFFE9E1, 'skyjo', 61),
      ('s-mk', 'Tournois Mario Kart', '🏎️', 0xFFE7EBFF, 'mk', 38),
      ('s-catan', 'Club Catan', '🐑', 0xFFE4F3EA, 'catan', 24),
      ('s-experts', 'Initiation jeux experts', '🧩', 0xFFFFF3D6, '7_wonders', 12),
    ];
    final cafeDice = _Dice(31);
    final salons = <String, Salon>{};
    final cafeMatches = <GameMatch>[];
    var cm = 0;
    for (final (id, name, emoji, bg, gameId, count) in salonSpecs) {
      final members = ['camille', 'lea', 'hugo', ...cafeDice.shuffled(regulars).take(cafeDice.range(14, 24)), 'bastien'];
      salons[id] = Salon(id: id, serverId: kCafe, name: name, emoji: emoji, emojiBg: bg, memberIds: members);
      final rule = cafeGames.firstWhere((g) => g.id == gameId).resolveRule(_rules[gameId]);
      for (var i = 0; i < count; i++) {
        final players = cafeDice.shuffled(members).take(cafeDice.range(2, 5)).toList();
        // Léa is a café regular, not one of its champions.
        if (players.first == 'lea') players.insert(1, players.removeAt(0));
        final pts = [for (var j = 0; j < players.length; j++) rule.lowWins ? 50 + 11 * j + cafeDice.range(0, 9) : 50 - 7 * j - cafeDice.range(0, 5)];
        cafeMatches.add(GameMatch(
          id: 'c${++cm}',
          gameId: gameId,
          groupId: '',
          salonId: id,
          mode: 'ffa',
          unit: 'points',
          lowWins: rule.lowWins,
          entries: [for (final (j, uid) in players.indexed) MatchEntry(playerId: uid, points: pts[j])],
          timeline: const [],
          createdAt: at(-1 - (count - i) * 2, 21, cafeDice.range(0, 50)),
          ruleId: rule.id,
          inputMode: 'quick',
          createdByUid: 'bastien',
          confirmedBy: players,
        ));
      }
    }
    // Played at the café last night, waiting for Léa's confirmation.
    cafeMatches.add(GameMatch(
      id: 'c-pending',
      gameId: 'skyjo',
      groupId: '',
      salonId: 's-skyjo',
      mode: 'ffa',
      unit: 'points',
      lowWins: true,
      entries: const [MatchEntry(playerId: 'bastien', points: 64), MatchEntry(playerId: 'lea', points: 81), MatchEntry(playerId: 'c-manon', points: 97), MatchEntry(playerId: 'c-antoine', points: 104)],
      timeline: const [],
      createdAt: at(-1, 22, 14),
      ruleId: 'standard',
      inputMode: 'quick',
      createdByUid: 'bastien',
      confirmedBy: const ['bastien', 'c-antoine'],
    ));
    if (!salons['s-skyjo']!.memberIds.contains('c-manon')) salons['s-skyjo'] = salons['s-skyjo']!.copyWith(memberIds: [...salons['s-skyjo']!.memberIds, 'c-manon']);
    if (!salons['s-skyjo']!.memberIds.contains('c-antoine')) salons['s-skyjo'] = salons['s-skyjo']!.copyWith(memberIds: [...salons['s-skyjo']!.memberIds, 'c-antoine']);

    // Next Saturday's tournament, full with a waiting list, and Thursday's
    // Skyjo night.
    final toSaturday = (DateTime.saturday - today.weekday) % 7;
    final mkFans = ['c-arthur', 'c-jade', 'c-enzo', 'c-lina', 'lea', 'c-mathis', 'c-zoe', 'c-louis', 'hugo', 'c-oceane', 'c-romain', 'c-salome', 'c-noah', 'c-fanny', 'c-yanis', 'c-alice', 'c-kevin', 'c-margaux', 'c-baptiste'];
    final events = [
      ScheduledEvent(
        id: 'ev-mk',
        salonId: 's-mk',
        gameId: 'mk',
        ruleId: _rules['mk'],
        kind: 'tournament',
        name: 'Grand tournoi',
        scheduledAt: at(toSaturday + 7, 14, 0),
        capacity: 16,
        signups: mkFans,
        createdByUid: 'camille',
        createdAt: at(-6, 10, 0),
      ),
      ScheduledEvent(
        id: 'ev-skyjo',
        salonId: 's-skyjo',
        gameId: 'skyjo',
        ruleId: 'standard',
        kind: 'game',
        name: 'Soirée Skyjo',
        scheduledAt: at((DateTime.thursday - today.weekday) % 7, 20, 0),
        signups: const ['bastien', 'lea', 'c-manon', 'c-antoine', 'c-diane', 'c-gabriel', 'c-helene', 'c-quentin', 'c-pauline'],
        createdByUid: 'bastien',
        createdAt: at(-3, 18, 0),
      ),
    ];
    for (final uid in [...mkFans, 'c-diane', 'c-gabriel', 'c-helene', 'c-quentin', 'c-pauline']) {
      final s = uid.startsWith('c-') && mkFans.contains(uid) ? 's-mk' : 's-skyjo';
      if (!salons[s]!.memberIds.contains(uid)) salons[s] = salons[s]!.copyWith(memberIds: [...salons[s]!.memberIds, uid]);
    }
    final cafeMessages = [
      GroupMessage(id: 'cm1', authorId: 'camille', salonId: 's-mk', text: 'Inscriptions ouvertes pour le grand tournoi de samedi : 16 places !', createdAt: at(-6, 10, 2)),
      GroupMessage(id: 'cm2', authorId: 'c-jade', salonId: 's-mk', text: 'Inscrite, je viens avec ma manette !', createdAt: at(-6, 10, 40)),
      GroupMessage(id: 'cm3', authorId: 'bastien', salonId: 's-mk', text: 'Complet ! Les suivants passent en liste d’attente.', createdAt: at(-2, 19, 5)),
    ];

    // ---- every account's friends and profile ----
    users['lea'] = users['lea']!.copyWith(
      friendIds: [for (final uid in banditIds) if (uid != 'lea') uid],
      bio: 'Catan dans le sang. Toujours partante pour une revanche.',
      pronouns: 'elle',
      banner: 'aurore',
      avatarFrame: () => 'laurel',
      titleId: () => 'pilier',
      favoriteGameId: () => 'catan',
      ownedGameIds: const ['catan', 'skyjo', 'codenames', 'dixit', 'azul', 'splendor', 'aventuriers_du_rail', 'carcassonne', '7_wonders', 'kingdomino', 'just_one', 'love_letter'],
    );
    users['hugo'] = users['hugo']!.copyWith(
      friendIds: [for (final uid in banditIds) if (uid != 'hugo') uid],
      bio: 'Roi de Mario Kart, imbattable au Skyjo (paraît-il).',
      banner: 'gamepad',
      ownedGameIds: const ['skyjo', 'uno', 'king_of_tokyo', 'six_qui_prend'],
    );

    final cafe = Server(id: kCafe, name: 'Le Repaire', emoji: '☕', emojiBg: 0xFFFFF3D6, ownerId: 'camille', adminIds: const ['bastien', 'julie'], memberIds: cafeMembers);

    final data = DemoData._(
      users: users,
      groups: groups,
      servers: {kCafe: cafe},
      salons: salons,
      groupGames: {kBandits: banditsGames, 'famille': List.of(banditsGames), 'dej': List.of(banditsGames)},
      serverGames: {kCafe: cafeGames},
      groupMatches: {kBandits: matches, 'famille': familyMatches, 'dej': workMatches},
      serverMatches: {kCafe: cafeMatches},
      groupTournaments: {kBandits: [cup]},
      groupMessages: {kBandits: messages},
      serverMessages: {kCafe: cafeMessages},
      events: {kCafe: events},
      rosters: {
        kBandits: banditIds,
        'famille': familyIds,
        'dej': workIds,
        kCafe: cafeMembers.toSet().union({for (final s in salons.values) ...s.memberIds}).toList(),
      },
      library: library,
      liveSkyjo: liveSkyjo ? tonightLive(now, rounds: 5) : null,
    );
    data._grantEarnedBadges();
    return data;
  }

  /// Tonight's Skyjo once [rounds] rounds are in, as Léa's phone broadcasts it.
  static LiveMatchSession tonightLive(DateTime now, {required int rounds}) {
    final timeline = tonightTimeline(now, rounds: rounds);
    return LiveMatchSession(
      id: 'live-skyjo',
      gameId: 'skyjo',
      groupId: kBandits,
      startedByUid: 'lea',
      startedByName: 'Léa',
      mode: 'ffa',
      unit: 'points',
      lowWins: true,
      entries: [for (final uid in kTonightPlayers) MatchEntry(playerId: uid, points: timeline.lastWhere((t) => t.playerId == uid).val)],
      timeline: timeline,
      inputMode: 'rounds',
      createdAt: now.subtract(Duration(minutes: 7 * rounds + 4)),
      updatedAt: now,
    );
  }

  static List<TimelinePoint> tonightTimeline(DateTime now, {int rounds = 6}) {
    final running = List.filled(kTonightPlayers.length, 0);
    return [
      for (var r = 0; r < rounds; r++)
        for (final (i, uid) in kTonightPlayers.indexed)
          TimelinePoint(playerId: uid, val: running[i] += kTonightRounds[r][i], delta: kTonightRounds[r][i], time: now.subtract(Duration(minutes: 7 * (rounds - r)))),
    ];
  }

  /// Tonight's Skyjo as the app saves it once the sixth round is in.
  static GameMatch tonightMatch(DateTime now) {
    final timeline = tonightTimeline(now);
    return GameMatch(
      id: 'tonight',
      gameId: 'skyjo',
      groupId: kBandits,
      mode: 'ffa',
      unit: 'points',
      lowWins: true,
      entries: [for (final uid in kTonightPlayers) MatchEntry(playerId: uid, points: timeline.lastWhere((t) => t.playerId == uid).val)],
      timeline: timeline,
      createdAt: now,
      ruleId: 'standard',
      inputMode: 'rounds',
      createdByUid: 'lea',
    );
  }

  /// Saves on each account every badge it already meets somewhere, as the
  /// app would have over those three months — so opening the demo doesn't
  /// celebrate them all at once, and tonight's win alone earns something.
  void _grantEarnedBadges() {
    final contexts = <List<GameMatch>>[
      for (final entry in groupMatches.entries) entry.value,
      for (final s in salons.values) [for (final m in serverMatches[kCafe]!) if (m.salonId == s.id && m.isConfirmed) m],
    ];
    final contextMembers = <List<String>>[
      for (final entry in groupMatches.entries) groups[entry.key]!.memberIds,
      for (final s in salons.values) s.memberIds,
    ];
    final contextTournaments = <List<Tournament>>[
      for (final entry in groupMatches.entries) groupTournaments[entry.key] ?? const [],
      for (final _ in salons.values) const [],
    ];
    final isGroup = [for (final _ in groupMatches.keys) true, for (final _ in salons.values) false];
    final leaders = [
      for (var c = 0; c < contexts.length; c++) isGroup[c] ? eloLeader(contexts[c], contextMembers[c]) : winsLeader(contexts[c], contextMembers[c]),
    ];
    for (final uid in users.keys.toList()) {
      final user = users[uid]!;
      final earned = <String>{};
      for (var c = 0; c < contexts.length; c++) {
        if (!contextMembers[c].contains(uid)) continue;
        final leader = leaders[c];
        final stats = computeBadgeStats(
          uid: uid,
          matches: contexts[c],
          tournaments: contextTournaments[c],
          leading: leader == uid && contextMembers[c].length >= 3 && contexts[c].length >= 5,
          ownedGames: user.ownedGameIds.length,
          friends: user.friendIds.length,
        );
        earned.addAll([for (final b in kBadges) if (b.isEarned(stats)) b.id]);
      }
      final showcase = [for (final id in const ['streak3', 'versatile_5', 'regular', 'curious', 'first_win']) if (earned.contains(id)) id].take(kMaxShowcasedBadges).toList();
      users[uid] = user.copyWith(badges: earned.toList(), showcasedBadges: uid == 'lea' ? showcase : null);
    }
  }

  /// Who tops a group's Elo ranking (as AppState.headlineStandings does).
  static String? eloLeader(List<GameMatch> matches, List<String> members) {
    final r = computeElo(matches);
    final rated = members.where(r.ratings.containsKey).toList()..sort((a, b) => r.ratings[b]!.compareTo(r.ratings[a]!));
    return rated.firstOrNull;
  }

  /// Who has the most wins in a salon (its headline ranking).
  static String? winsLeader(List<GameMatch> matches, List<String> members) {
    final wins = {for (final uid in members) uid: 0};
    for (final m in matches) {
      for (final uid in m.winnerIds()) {
        if (wins.containsKey(uid)) wins[uid] = wins[uid]! + 1;
      }
    }
    final sorted = wins.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.firstOrNull?.key;
  }
}

/// 7 Wonders score sheets that look played: each player on a different
/// wonder, and the points spread the way the game spreads them — a few from
/// the treasury, a wonder built in stages, science in sets… — around the
/// total the match was played to, which stays as it is.
List<MatchEntry> _sevenWonders(List<MatchEntry> entries, Game game, _Dice d) {
  final wonders = d.shuffled(game.characterChoice!.options);
  return [
    for (final (i, e) in entries.indexed)
      MatchEntry(playerId: e.playerId, points: e.points, character: wonders[i], scoreBreakdown: _sevenWondersSheet(e.points, d)),
  ];
}

Map<String, int> _sevenWondersSheet(int total, _Dice d) {
  int pick(List<int> xs) => xs[d.range(0, xs.length - 1)];
  for (var attempt = 0;; attempt++) {
    final sheet = {
      'militaire': pick(const [-4, -2, -1, 1, 3, 4, 6, 7, 9, 10, 12, 13, 15, 18]),
      'tresor': d.range(1, 8),
      'merveille': pick(const [3, 5, 7, 8, 10, 12, 15]),
      'batiments_commerciaux': d.range(0, 9),
      'guildes': pick(const [0, 0, 3, 5, 6, 8, 10, 12]),
      'batiments_scientifiques': pick(const [0, 1, 4, 7, 10, 13, 16, 18, 21, 26]),
    };
    // Civil buildings take the rest, as long as that's believable.
    final civils = total - sheet.values.reduce((a, b) => a + b);
    if ((civils >= 4 && civils <= 30) || attempt > 2000) return {...sheet, 'batiments_civils': max(0, civils)};
  }
}

/// What the app's `onMatchWritten` Cloud Function posts in a group's
/// discussion (functions/index.js, postMatchHighlights): a win streak of 3+
/// at one game, and a new sole leader of the win tally — replayed over
/// [matches], keeping those posted after [since].
List<GroupMessage> _highlights(List<GameMatch> matches, Map<String, Game> games, {required DateTime since}) {
  final out = <GroupMessage>[];
  final wins = <String, int>{};
  String? soleLeader() {
    final sorted = wins.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    if (sorted.isEmpty || sorted.first.value <= 0) return null;
    if (sorted.length > 1 && sorted[1].value == sorted.first.value) return null;
    return sorted.first.key;
  }

  final sorted = List.of(matches)..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  for (final (i, m) in sorted.indexed) {
    final winners = m.winnerIds();
    if (winners.isEmpty) continue;
    final texts = <String>[];
    final history = [for (final x in sorted.take(i + 1)) if (x.gameId == m.gameId) x].reversed.take(25).toList();
    final byLength = <int, List<String>>{};
    for (final uid in winners) {
      var streak = 0;
      for (final x in history) {
        if (!x.winnerIds().contains(uid)) break;
        streak++;
      }
      if (streak >= 3) byLength.putIfAbsent(streak, () => []).add(uid);
    }
    String name(String uid) => switch (uid) {
          'lea' => 'Léa',
          'ines' => 'Inès',
          'chloe' => 'Chloé',
          'theo' => 'Théo',
          _ => uid[0].toUpperCase() + uid.substring(1),
        };
    for (final e in byLength.entries) {
      final names = e.value.map(name).join(' et ');
      texts.add('$names enchaîne${e.value.length > 1 ? 'nt' : ''} ${e.key} victoires d\'affilée à ${games[m.gameId]!.name} 🔥');
    }
    final before = soleLeader();
    for (final uid in winners) {
      wins[uid] = (wins[uid] ?? 0) + 1;
    }
    final after = soleLeader();
    if (i + 1 >= 3 && after != null && after != before && winners.contains(after)) {
      texts.add('${name(after)} prend la tête du classement 👑');
    }
    if (m.createdAt.isAfter(since)) {
      for (final (j, text) in texts.indexed) {
        out.add(GroupMessage(id: 'h-${m.id}-$j', authorId: 'system', system: true, text: text, createdAt: m.createdAt.add(Duration(minutes: 1 + j))));
      }
    }
  }
  return out;
}
