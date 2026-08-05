import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/game.dart';

/// A shared, global catalog of ready-made games (including ones with
/// special scoring rules, e.g. Président's role-based ranks) that any group
/// can import into its own catalog. Lives at the top-level `gameLibrary`
/// collection — not scoped to a group — and is admin-managed directly in
/// the Firebase console (the app only reads it).
abstract class GameLibraryRepository {
  Future<List<Game>> fetchLibrary();
}

class FirebaseGameLibraryRepository implements GameLibraryRepository {
  final FirebaseFirestore _db;
  FirebaseGameLibraryRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  @override
  Future<List<Game>> fetchLibrary() async {
    final snap = await _db.collection('gameLibrary').orderBy('name').get();
    return snap.docs.map((d) => Game.fromDoc(d.id, d.data())).toList();
  }
}

class FakeGameLibraryRepository implements GameLibraryRepository {
  final List<Game> games;
  FakeGameLibraryRepository({List<Game>? seed}) : games = seed ?? [];

  @override
  Future<List<Game>> fetchLibrary() async => List.of(games);
}
