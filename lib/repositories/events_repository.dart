import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/scheduled_event.dart';
import 'synced_query.dart';

/// Salon-only (see `lib/models/scheduled_event.dart`) — unlike
/// GamesRepository/MatchesRepository/TournamentsRepository, there's no
/// `rootCollection` parameter here: events always live under
/// `servers/{serverId}/events`, since there's no Group equivalent to
/// generalize for.
abstract class EventsRepository {
  /// Every event scheduled in `salonId`, soonest first. Synced (see
  /// [watchSynced]).
  Stream<List<ScheduledEvent>> watchEvents(String serverId, String salonId);

  Future<ScheduledEvent> addEvent(String serverId, ScheduledEvent event);

  /// Overwrites an event in place — used for status/result-id updates (see
  /// `AppState.startEvent`) as well as sign-up changes.
  Future<void> updateEvent(String serverId, ScheduledEvent event);

  /// Overwritten with a [tombstone], so every device's synced copy drops it.
  Future<void> deleteEvent(String serverId, ScheduledEvent event);

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
    return watchSynced(
      _col(serverId).where('salonId', isEqualTo: salonId),
      parse: ScheduledEvent.fromDoc,
      compare: (a, b) => a.scheduledAt.compareTo(b.scheduledAt),
      key: 'servers/$serverId/events?salonId=$salonId',
    );
  }

  @override
  Future<ScheduledEvent> addEvent(String serverId, ScheduledEvent event) async {
    final ref = _col(serverId).doc();
    await ref.set(stamped(event.toMap()));
    return ScheduledEvent.fromDoc(ref.id, event.toMap());
  }

  @override
  Future<void> updateEvent(String serverId, ScheduledEvent event) async {
    await _col(serverId).doc(event.id).set(stamped(event.toMap()));
  }

  @override
  Future<void> deleteEvent(String serverId, ScheduledEvent event) async {
    await _col(serverId).doc(event.id).set(tombstone({'salonId': event.salonId}));
  }

  @override
  Future<void> register({required String serverId, required String eventId, required String uid}) async {
    await _col(serverId).doc(eventId).update(stamped({
      'signups': FieldValue.arrayUnion([uid]),
    }));
  }

  @override
  Future<void> unregister({required String serverId, required String eventId, required String uid}) async {
    await _col(serverId).doc(eventId).update(stamped({
      'signups': FieldValue.arrayRemove([uid]),
    }));
  }
}
