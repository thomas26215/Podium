import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/game.dart';
import '../models/library_game_stats.dart';
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

  /// Downloads, matches played and likes of every library game that has
  /// any, by game id — kept by Cloud Functions (see
  /// functions/library_stats.js). Synced like [fetchLibrary]: after the
  /// first time, only the counts that moved since are downloaded.
  Future<Map<String, LibraryGameStats>> fetchStats();

  /// The library games `uid` likes — their own list, in their private
  /// `users/{uid}/private/libraryLikes` doc.
  Future<Set<String>> fetchLikes(String uid);

  /// Adds `gameId` to `uid`'s likes, or takes it off. The
  /// onLibraryLikesWritten Cloud Function carries it over to the game's
  /// [LibraryGameStats.likes] a moment later.
  Future<void> setLiked({required String uid, required String gameId, required bool liked});
}

class FirebaseGameLibraryRepository implements GameLibraryRepository {
  final FirebaseFirestore _db;
  FirebaseGameLibraryRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _likes(String uid) => _db.collection('users').doc(uid).collection('private').doc('libraryLikes');

  @override
  Future<List<Game>> fetchLibrary() => fetchSynced(_db.collection('gameLibrary'), parse: Game.fromDoc, compare: (a, b) => a.name.compareTo(b.name), key: 'gameLibrary');

  @override
  Future<Map<String, LibraryGameStats>> fetchStats() async {
    final stats = await fetchSynced(_db.collection('gameLibraryStats'), parse: LibraryGameStats.fromDoc, key: 'gameLibraryStats');
    return {for (final s in stats) s.gameId: s};
  }

  @override
  Future<Set<String>> fetchLikes(String uid) async {
    final snap = await _likes(uid).get();
    return {...((snap.data()?['gameIds'] as List?) ?? const []).whereType<String>()};
  }

  @override
  Future<void> setLiked({required String uid, required String gameId, required bool liked}) async {
    await _likes(uid).set({
      'gameIds': liked ? FieldValue.arrayUnion([gameId]) : FieldValue.arrayRemove([gameId]),
    }, SetOptions(merge: true));
  }
}

class FakeGameLibraryRepository implements GameLibraryRepository {
  final List<Game> games;
  final Map<String, LibraryGameStats> stats;
  final Map<String, Set<String>> likes;
  FakeGameLibraryRepository({List<Game>? seed, Map<String, LibraryGameStats>? stats, Map<String, Set<String>>? likes})
      : games = seed ?? [],
        stats = stats ?? {},
        likes = likes ?? {};

  @override
  Future<List<Game>> fetchLibrary() async => List.of(games);

  @override
  Future<Map<String, LibraryGameStats>> fetchStats() async => Map.of(stats);

  @override
  Future<Set<String>> fetchLikes(String uid) async => Set.of(likes[uid] ?? const {});

  /// Tallies the like at once, as the Cloud Function would a moment later.
  @override
  Future<void> setLiked({required String uid, required String gameId, required bool liked}) async {
    final mine = likes.putIfAbsent(uid, () => {});
    if (!(liked ? mine.add(gameId) : mine.remove(gameId))) return;
    final s = stats[gameId] ?? LibraryGameStats(gameId: gameId);
    stats[gameId] = s.withLikes(s.likes + (liked ? 1 : -1));
  }
}
