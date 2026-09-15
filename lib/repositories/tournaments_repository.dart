import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/tournament.dart';

abstract class TournamentsRepository {
  /// All tournaments recorded in any of `groupIds`, newest first. Matches on
  /// the `groupId` field by default; pass `bySalon: true` to match on
  /// `salonId` instead (a Salon tournament's `groupId` is always empty — see
  /// [Tournament.salonId]).
  Stream<List<Tournament>> watchTournaments(String rootGroupId, List<String> groupIds, {bool bySalon = false});

  /// Persists `tournament` (its `id` is ignored — the repository assigns
  /// one) and returns the saved tournament with its real id.
  Future<Tournament> addTournament(String rootGroupId, Tournament tournament);

  /// Overwrites an already-saved tournament in place — the whole bracket
  /// lives in this one document, so every result recorded against it (see
  /// `AppState._recordTournamentResult`) is a full-document rewrite.
  Future<void> updateTournament(String rootGroupId, Tournament tournament);

  /// Permanently removes a tournament (see `AppState.canDeleteTournament`).
  Future<void> deleteTournament(String rootGroupId, String tournamentId);
}

class FirebaseTournamentsRepository implements TournamentsRepository {
  final FirebaseFirestore _db;

  /// Root collection tournaments live under — `'groups'` for a friend
  /// group's own (the default), `'servers'` for a Server's Salon tournaments.
  /// Same doc shape either way; a Salon tournament additionally carries
  /// `salonId` (see [Tournament.salonId]).
  final String rootCollection;

  FirebaseTournamentsRepository({FirebaseFirestore? db, this.rootCollection = 'groups'}) : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String rootGroupId) =>
      _db.collection(rootCollection).doc(rootGroupId).collection('tournaments');

  @override
  Stream<List<Tournament>> watchTournaments(String rootGroupId, List<String> groupIds, {bool bySalon = false}) {
    if (groupIds.isEmpty) return Stream.value(const []);
    return _col(rootGroupId)
        .where(bySalon ? 'salonId' : 'groupId', whereIn: groupIds.take(30).toList())
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Tournament.fromDoc(d.id, d.data())).toList());
  }

  @override
  Future<Tournament> addTournament(String rootGroupId, Tournament tournament) async {
    final ref = _col(rootGroupId).doc();
    await ref.set(tournament.toMap());
    return Tournament.fromDoc(ref.id, tournament.toMap());
  }

  @override
  Future<void> updateTournament(String rootGroupId, Tournament tournament) async {
    await _col(rootGroupId).doc(tournament.id).set(tournament.toMap());
  }

  @override
  Future<void> deleteTournament(String rootGroupId, String tournamentId) async {
    await _col(rootGroupId).doc(tournamentId).delete();
  }
}
