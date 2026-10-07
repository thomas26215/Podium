import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/game.dart';
import 'synced_query.dart';

/// A shared, global catalog of ready-made games (including ones with
/// special scoring rules, e.g. Président's role-based ranks) that any group
/// can import into its own catalog. Lives at the top-level `gameLibrary`
/// collection — not scoped to a group — and is admin-managed directly in
/// the Firebase console (the app only reads it).
abstract class GameLibraryRepository {
  /// The whole library, by name. Synced (see [fetchSynced]): after the first
  /// time, only the games edited since are downloaded — tool/seed_game_library.js
  /// stamps each one it changes.
  Future<List<Game>> fetchLibrary();
}

class FirebaseGameLibraryRepository implements GameLibraryRepository {
  final FirebaseFirestore _db;
  FirebaseGameLibraryRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  @override
  Future<List<Game>> fetchLibrary() => fetchSynced(_db.collection('gameLibrary'), parse: Game.fromDoc, compare: (a, b) => a.name.compareTo(b.name), key: 'gameLibrary');
}

class FakeGameLibraryRepository implements GameLibraryRepository {
  final List<Game> games;
  FakeGameLibraryRepository({List<Game>? seed}) : games = seed ?? [];

  @override
  Future<List<Game>> fetchLibrary() async => List.of(games);
}
