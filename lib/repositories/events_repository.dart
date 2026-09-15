import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/scheduled_event.dart';

/// Salon-only (see `lib/models/scheduled_event.dart`) — unlike
/// GamesRepository/MatchesRepository/TournamentsRepository, there's no
/// `rootCollection` parameter here: events always live under
/// `servers/{serverId}/events`, since there's no Group equivalent to
/// generalize for.
abstract class EventsRepository {
  /// Every event scheduled in `salonId`, soonest first.
  Stream<List<ScheduledEvent>> watchEvents(String serverId, String salonId);

  Future<ScheduledEvent> addEvent(String serverId, ScheduledEvent event);

  /// Overwrites an event in place — used for status/result-id updates (see
  /// `AppState.startEvent`) as well as sign-up changes.
  Future<void> updateEvent(String serverId, ScheduledEvent event);

  Future<void> deleteEvent(String serverId, String eventId);

  /// Adds `uid` to the event's sign-up list, in order — an `arrayUnion` so a
  /// double-tap can't sign someone up twice.
  Future<void> register({required String serverId, required String eventId, required String uid});

  /// Removes `uid` from the sign-up list — whoever was next on the waitlist
  /// becomes confirmed automatically (see `ScheduledEvent.confirmedIds`),
  /// no separate promotion step needed.
  Future<void> unregister({required String serverId, required String eventId, required String uid});
}

class FirebaseEventsRepository implements EventsRepository {
  final FirebaseFirestore _db;
  FirebaseEventsRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String serverId) =>
      _db.collection('servers').doc(serverId).collection('events');

  @override
  Stream<List<ScheduledEvent>> watchEvents(String serverId, String salonId) {
    return _col(serverId)
        .where('salonId', isEqualTo: salonId)
        .orderBy('scheduledAt')
        .snapshots()
        .map((snap) => snap.docs.map((d) => ScheduledEvent.fromDoc(d.id, d.data())).toList());
  }

  @override
  Future<ScheduledEvent> addEvent(String serverId, ScheduledEvent event) async {
    final ref = _col(serverId).doc();
    await ref.set(event.toMap());
    return ScheduledEvent.fromDoc(ref.id, event.toMap());
  }

  @override
  Future<void> updateEvent(String serverId, ScheduledEvent event) async {
    await _col(serverId).doc(event.id).set(event.toMap());
  }

  @override
  Future<void> deleteEvent(String serverId, String eventId) async {
    await _col(serverId).doc(eventId).delete();
  }

  @override
  Future<void> register({required String serverId, required String eventId, required String uid}) async {
    await _col(serverId).doc(eventId).update({
      'signups': FieldValue.arrayUnion([uid]),
    });
  }

  @override
  Future<void> unregister({required String serverId, required String eventId, required String uid}) async {
    await _col(serverId).doc(eventId).update({
      'signups': FieldValue.arrayRemove([uid]),
    });
  }
}
