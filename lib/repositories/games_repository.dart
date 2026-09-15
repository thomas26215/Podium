import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/game.dart';

/// The starter catalog every new root group gets, matching the prototype's
/// seed data so a fresh group isn't staring at an empty game grid.
final List<Game> kDefaultGames = [
  Game.simple(id: 'catan', name: 'Catan', emoji: '🎲', category: 'Société', countType: CountType.highWins),
  Game.simple(id: 'uno', name: 'Uno', emoji: '🃏', category: 'Cartes', countType: CountType.highWins),
  Game.simple(id: 'skyjo', name: 'Skyjo', emoji: '🂠', category: 'Cartes', countType: CountType.lowWins),
  Game.simple(id: 'mk', name: 'Mario Kart', emoji: '🏎️', category: 'Jeu vidéo', countType: CountType.highWins),
  Game.simple(id: 'petanque', name: 'Pétanque', emoji: '🎯', category: 'Sport', countType: CountType.highWins),
  Game.simple(id: 'timesup', name: "Time's Up", emoji: '⏱️', category: 'Société', countType: CountType.highWins),
  Game.simple(id: 'president', name: 'Président', emoji: '🎩', category: 'Cartes', countType: CountType.wins),
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
    String? salonId,
  }) async {
    final ref = _col(rootGroupId).doc();
    final game = Game(
      id: ref.id,
      name: name,
      emoji: emoji,
      category: category,
      rules: rules,
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
