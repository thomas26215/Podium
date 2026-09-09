import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/match.dart';

abstract class MatchesRepository {
  /// All matches recorded in any of `groupIds`, newest first.
  Stream<List<GameMatch>> watchMatches(String rootGroupId, List<String> groupIds);

  /// One-time tally of matches recorded in any of `groupIds` — cheaper than
  /// [watchMatches] when only a count is needed (e.g. the groups list's "X
  /// parties" summary for a group that isn't the currently-selected one, so
  /// its matches aren't already loaded — see AppState.refreshGroupPartyCounts).
  Future<int> countMatches(String rootGroupId, List<String> groupIds);

  /// Persists `match` (its `id` is ignored — the repository assigns one)
  /// and returns the saved match with its real id.
  Future<GameMatch> addMatch(String rootGroupId, GameMatch match);

  /// Overwrites an already-saved match in place (resuming it to add more
  /// rounds, or correcting a mistake) — `match.id` must be the id of an
  /// existing doc. The original `createdAt` is preserved so the match
  /// doesn't jump to the top of the history just because it was edited.
  Future<void> updateMatch(String rootGroupId, GameMatch match);

  /// Permanently removes a recorded match (e.g. entered by mistake, or one
  /// leg — or the whole thing — of a "best of N" series).
  Future<void> deleteMatch(String rootGroupId, String matchId);

  /// Rewrites every match recorded under `rootGroupId` that references
  /// `oldPlayerId` (in its scores or its point-by-point timeline) to
  /// `newPlayerId` instead — the match-history half of handing a player's
  /// identity over to a different account (see
  /// `GroupsRepository.reassignMember` for the membership half).
  Future<void> reassignPlayer({required String rootGroupId, required String oldPlayerId, required String newPlayerId});

  /// Records that a match is being scored, right now, by `startedByUid` —
  /// creates the "live session" doc a Cloud Function picks up to push "Une
  /// partie de X a été débutée par Y" to the rest of the group, and that
  /// [watchLiveSessions] streams back to every other client so they can
  /// watch the match live. Returns the new session's id, used to push score
  /// updates via [updateLiveSession] and clean up via [endLiveSession].
  Future<String> startLiveSession({
    required String rootGroupId,
    required String groupId,
    required String gameId,
    required String startedByUid,
    required String startedByName,
    required String mode,
    required String unit,
    required bool lowWins,
  });

  /// All matches currently being scored in any of `groupIds`, newest first —
  /// lets the rest of the group watch live games update in real time.
  Stream<List<LiveMatchSession>> watchLiveSessions(String rootGroupId, List<String> groupIds);

  /// Pushes the current scores of an in-progress match (see
  /// [startLiveSession]) so everyone watching sees them update live —
  /// including the round/live timeline and current input mode, so spectator
  /// views can render the same round breakdown and chart as the person
  /// scoring.
  /// [held] defaults to false — an actual score push means the scorer is
  /// back and actively playing, which always clears the "held" flag.
  Future<void> updateLiveSession({
    required String rootGroupId,
    required String sessionId,
    required List<MatchEntry> entries,
    required List<TimelinePoint> timeline,
    String? inputMode,
    bool held = false,
  });

  /// Ends a live session — the match was saved or scoring was abandoned.
  Future<void> endLiveSession({required String rootGroupId, required String sessionId});

  /// Flags a session as "held" (scorer has left — app backgrounded/closed —
  /// but the session is still within its grace window, see
  /// `AppState._holdLiveSession`) or clears the flag when they come back.
  /// Doesn't touch scores — a plain [updateLiveSession] call already clears
  /// it as a side effect of resuming.
  Future<void> setLiveSessionHeld({required String rootGroupId, required String sessionId, required bool held});
}

class FirebaseMatchesRepository implements MatchesRepository {
  final FirebaseFirestore _db;
  FirebaseMatchesRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String rootGroupId) =>
      _db.collection('groups').doc(rootGroupId).collection('matches');

  @override
  Stream<List<GameMatch>> watchMatches(String rootGroupId, List<String> groupIds) {
    if (groupIds.isEmpty) return Stream.value(const []);
    // Firestore whereIn caps at 30 values, comfortably above any realistic
    // fan-out for this app.
    return _col(rootGroupId)
        .where('groupId', whereIn: groupIds.take(30).toList())
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => GameMatch.fromDoc(d.id, d.data())).toList());
  }

  @override
  Future<int> countMatches(String rootGroupId, List<String> groupIds) async {
    if (groupIds.isEmpty) return 0;
    final agg = await _col(rootGroupId).where('groupId', whereIn: groupIds.take(30).toList()).count().get();
    return agg.count ?? 0;
  }

  @override
  Future<GameMatch> addMatch(String rootGroupId, GameMatch match) async {
    final ref = _col(rootGroupId).doc();
    final saved = match.copyWithId(ref.id);
    await ref.set(saved.toMap());
    return saved;
  }

  @override
  Future<void> updateMatch(String rootGroupId, GameMatch match) async {
    await _col(rootGroupId).doc(match.id).set(match.toMap());
  }

  @override
  Future<void> deleteMatch(String rootGroupId, String matchId) async {
    await _col(rootGroupId).doc(matchId).delete();
  }

  @override
  Future<void> reassignPlayer({required String rootGroupId, required String oldPlayerId, required String newPlayerId}) async {
    final snap = await _col(rootGroupId).get();
    final updates = <DocumentReference<Map<String, dynamic>>, Map<String, dynamic>>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      var changed = false;
      final entries = ((data['entries'] as List?) ?? const []).map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        if (m['playerId'] == oldPlayerId) {
          m['playerId'] = newPlayerId;
          changed = true;
        }
        return m;
      }).toList();
      final timeline = ((data['timeline'] as List?) ?? const []).map((t) {
        final m = Map<String, dynamic>.from(t as Map);
        if (m['playerId'] == oldPlayerId) {
          m['playerId'] = newPlayerId;
          changed = true;
        }
        return m;
      }).toList();
      if (changed) updates[doc.reference] = {'entries': entries, 'timeline': timeline};
    }
    final refs = updates.keys.toList();
    const chunkSize = 450;
    for (var i = 0; i < refs.length; i += chunkSize) {
      final batch = _db.batch();
      for (final r in refs.skip(i).take(chunkSize)) {
        batch.update(r, updates[r]!);
      }
      await batch.commit();
    }
  }

  CollectionReference<Map<String, dynamic>> _sessionsCol(String rootGroupId) =>
      _db.collection('groups').doc(rootGroupId).collection('matchSessions');

  @override
  Future<String> startLiveSession({
    required String rootGroupId,
    required String groupId,
    required String gameId,
    required String startedByUid,
    required String startedByName,
    required String mode,
    required String unit,
    required bool lowWins,
  }) async {
    final ref = await _sessionsCol(rootGroupId).add({
      'groupId': groupId,
      'gameId': gameId,
      'startedBy': startedByUid,
      'startedByName': startedByName,
      'mode': mode,
      'unit': unit,
      'lowWins': lowWins,
      'entries': const [],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  @override
  Stream<List<LiveMatchSession>> watchLiveSessions(String rootGroupId, List<String> groupIds) {
    if (groupIds.isEmpty) return Stream.value(const []);
    return _sessionsCol(rootGroupId)
        .where('groupId', whereIn: groupIds.take(30).toList())
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => LiveMatchSession.fromDoc(d.id, d.data())).toList());
  }

  @override
  Future<void> updateLiveSession({
    required String rootGroupId,
    required String sessionId,
    required List<MatchEntry> entries,
    required List<TimelinePoint> timeline,
    String? inputMode,
    bool held = false,
  }) async {
    await _sessionsCol(rootGroupId).doc(sessionId).update({
      'entries': entries.map((e) => e.toMap()).toList(),
      'timeline': timeline.map((t) => t.toMap()).toList(),
      if (inputMode != null) 'inputMode': inputMode,
      'held': held,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> endLiveSession({required String rootGroupId, required String sessionId}) async {
    await _sessionsCol(rootGroupId).doc(sessionId).delete();
  }

  @override
  Future<void> setLiveSessionHeld({required String rootGroupId, required String sessionId, required bool held}) async {
    await _sessionsCol(rootGroupId).doc(sessionId).update({'held': held});
  }
}
