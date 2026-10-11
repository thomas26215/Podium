/// How a `gameLibrary` game fares across every Cador catalog — kept by
/// Cloud Functions in `gameLibraryStats/{gameId}` (see
/// functions/library_stats.js), which the app only reads. Counted since
/// those functions went live, never back in time; downloads and plays only
/// ever go up.
class LibraryGameStats {
  final String gameId;

  /// Copies of it taken into a catalog — a group's, a salon's or a solo
  /// space's — still counted once the copy is deleted.
  final int downloads;

  /// Matches recorded with it in every catalog — with an imported copy, even
  /// one edited since, or with a default catalog game, which shares its
  /// library game's id — still counted once deleted, or their game is.
  final int plays;

  /// Players who like it now (see `AppState.toggleLibraryLike`).
  final int likes;

  const LibraryGameStats({required this.gameId, this.downloads = 0, this.plays = 0, this.likes = 0});

  bool get isEmpty => downloads == 0 && plays == 0 && likes == 0;

  LibraryGameStats withLikes(int likes) => LibraryGameStats(gameId: gameId, downloads: downloads, plays: plays, likes: likes < 0 ? 0 : likes);

  factory LibraryGameStats.fromDoc(String id, Map<String, dynamic> data) {
    // Never shown below zero, whatever a count briefly went through.
    int count(String field) {
      final n = (data[field] as num?)?.toInt() ?? 0;
      return n < 0 ? 0 : n;
    }

    return LibraryGameStats(gameId: id, downloads: count('downloads'), plays: count('plays'), likes: count('likes'));
  }
}
