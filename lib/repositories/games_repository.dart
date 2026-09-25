import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/game.dart';

/// The starter catalog every new root group gets, matching the prototype's
/// seed data so a fresh group isn't staring at an empty game grid.
final List<Game> kDefaultGames = [
  Game.simple(
    id: 'catan', name: 'Catan', emoji: '🎲', category: 'Société', countType: CountType.highWins,
    minPlayers: 3, maxPlayers: 4, themes: ['strategie', 'gestion', 'negociation', 'des', 'familial', 'moyen'],
  ),
  Game.simple(
    id: 'uno', name: 'Uno', emoji: '🃏', category: 'Cartes', countType: CountType.highWins,
    minPlayers: 2, maxPlayers: 10, themes: ['paquetSpecifique', 'defausse', 'ambiance', 'familial', 'enfants', 'rapide'],
  ),
  Game.simple(
    id: 'skyjo', name: 'Skyjo', emoji: '🂠', category: 'Cartes', countType: CountType.lowWins,
    minPlayers: 2, maxPlayers: 8, themes: ['paquetSpecifique', 'memoire', 'pousseTaChance', 'familial', 'moyen'],
  ),
  Game.simple(
    id: 'mk', name: 'Mario Kart', emoji: '🏎️', category: 'Jeu vidéo', countType: CountType.highWins,
    minPlayers: 2, maxPlayers: 4, themes: ['course', 'multiLocal', 'ecranPartage', 'enLigne', 'competitif', 'familial'],
  ),
  Game.simple(
    id: 'petanque', name: 'Pétanque', emoji: '🎯', category: 'Sport', countType: CountType.highWins,
    minPlayers: 2, maxPlayers: 6, themes: ['petanque', 'precision', 'exterieur', 'equipes', 'loisir'],
  ),
  Game.simple(
    id: 'timesup', name: "Time's Up", emoji: '⏱️', category: 'Société', countType: CountType.highWins,
    minPlayers: 4, maxPlayers: 12, themes: ['ambiance', 'equipes', 'grandGroupe', 'quiz', 'apero', 'familial', 'moyen'],
  ),
  Game.simple(
    id: 'president', name: 'Président', emoji: '🎩', category: 'Cartes', countType: CountType.wins,
    minPlayers: 3, themes: ['cartes52', 'defausse', 'grandGroupe', 'apero', 'moyen'],
  ),
];

abstract class GamesRepository {
  Stream<List<Game>> watchGames(String rootGroupId);

  /// One-shot read of a root's catalog — used to browse another group's
  /// games without opening a live subscription to a root we're not
  /// currently viewing.
  Future<List<Game>> fetchGames(String rootGroupId);
  Future<Game> createGame(
    String rootGroupId, {
    required String name,
    required String emoji,
    required String category,
    required List<GameRule> rules,
    int? minPlayers,
    int? maxPlayers,
    List<String> themes = const [],
    CharacterChoice? characterChoice,
    String? salonId,
  });

  /// Copies a game definition (typically from the online library) into this
  /// root's own catalog as a brand new doc — this is how "download a
  /// special-rules game" works: the whole config (roles, points, etc.)
  /// comes along, no per-field wiring needed at the call site.
  Future<Game> importGame(String rootGroupId, Game source, {String? salonId});

  /// Overwrites an existing game's settings in place (`game.id` must already
  /// exist) — e.g. adjusting its point limit or roles after the fact.
  Future<void> updateGame(String rootGroupId, Game game);

  Future<void> seedDefaultCatalog(String rootGroupId);

  /// Removes a game from the catalog and deletes every match recorded for
  /// it in this group.
  Future<void> deleteGame(String rootGroupId, String gameId);
}

class FirebaseGamesRepository implements GamesRepository {
  final FirebaseFirestore _db;

  /// Root collection the catalog lives under — `'groups'` for a friend
  /// group's catalog (the default), `'servers'` for a Server's (shared by
  /// all of its Salons). Same doc shape either way.
  final String rootCollection;

  FirebaseGamesRepository({FirebaseFirestore? db, this.rootCollection = 'groups'}) : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String rootGroupId) =>
      _db.collection(rootCollection).doc(rootGroupId).collection('games');

  @override
  Stream<List<Game>> watchGames(String rootGroupId) {
    return _col(rootGroupId).snapshots().map((snap) => snap.docs.map((d) => Game.fromDoc(d.id, d.data())).toList());
  }

  @override
  Future<List<Game>> fetchGames(String rootGroupId) async {
    final snap = await _col(rootGroupId).get();
    return snap.docs.map((d) => Game.fromDoc(d.id, d.data())).toList();
  }

  @override
  Future<Game> createGame(
    String rootGroupId, {
    required String name,
    required String emoji,
    required String category,
    required List<GameRule> rules,
    int? minPlayers,
    int? maxPlayers,
    List<String> themes = const [],
    CharacterChoice? characterChoice,
    String? salonId,
  }) async {
    final ref = _col(rootGroupId).doc();
    final game = Game(
      id: ref.id,
      name: name,
      emoji: emoji,
      category: category,
      rules: rules,
      minPlayers: minPlayers,
      maxPlayers: maxPlayers,
      themes: themes,
      characterChoice: characterChoice,
      salonId: salonId,
    );
    await ref.set(game.toMap());
    return game;
  }

  @override
  Future<Game> importGame(String rootGroupId, Game source, {String? salonId}) async {
    final ref = _col(rootGroupId).doc();
    final game = Game(
      id: ref.id,
      name: source.name,
      emoji: source.emoji,
      category: source.category,
      rules: source.rules,
      ruleSections: source.ruleSections,
      minPlayers: source.minPlayers,
      maxPlayers: source.maxPlayers,
      themes: source.themes,
      characterChoice: source.characterChoice,
      salonId: salonId,
    );
    await ref.set(game.toMap());
    return game;
  }

  @override
  Future<void> updateGame(String rootGroupId, Game game) async {
    await _col(rootGroupId).doc(game.id).set(game.toMap());
  }

  @override
  Future<void> seedDefaultCatalog(String rootGroupId) async {
    final batch = _db.batch();
    for (final g in kDefaultGames) {
      batch.set(_col(rootGroupId).doc(g.id), g.toMap());
    }
    await batch.commit();
  }

  @override
  Future<void> deleteGame(String rootGroupId, String gameId) async {
    final matchesSnap = await _db.collection(rootCollection).doc(rootGroupId).collection('matches').where('gameId', isEqualTo: gameId).get();
    const chunkSize = 450;
    final refs = matchesSnap.docs.map((d) => d.reference).toList();
    for (var i = 0; i < refs.length; i += chunkSize) {
      final batch = _db.batch();
      for (final r in refs.skip(i).take(chunkSize)) {
        batch.delete(r);
      }
      await batch.commit();
    }
    await _col(rootGroupId).doc(gameId).delete();
  }
}
