import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Server time of a synced document's last write
/// (`FieldValue.serverTimestamp()`) — what lets a device ask only for the
/// documents written since the newest one it already holds (see
/// [watchSynced]).
const kUpdatedAt = 'updatedAt';

/// Set on a synced document instead of deleting it (see [tombstone]): the
/// deletion then reaches every device through [kUpdatedAt] like any other
/// change, where a document that's simply gone can't be asked for.
const kDeleted = 'deleted';

/// `data` plus a fresh [kUpdatedAt] — every write to a synced collection goes
/// through this.
Map<String, dynamic> stamped(Map<String, dynamic> data) => {...data, kUpdatedAt: FieldValue.serverTimestamp()};

/// What a deleted synced document is overwritten with: only `keep` (the
/// fields its query and security rules filter on) and the deletion mark.
Map<String, dynamic> tombstone([Map<String, dynamic> keep = const {}]) => stamped({...keep, kDeleted: true});

/// The documents of one synced query as last seen, deletion marks included —
/// kept apart from Firestore so its bookkeeping can be unit-tested.
class SyncedDocs<T> {
  SyncedDocs(this._parse, {this.compare});

  final T Function(String id, Map<String, dynamic> data) _parse;
  final int Function(T a, T b)? compare;
  final _values = <String, T?>{};
  final _stamps = <String, Timestamp>{};

  /// How many documents the query matches, deletion marks included — what a
  /// server-side `count()` of it returns when this copy is complete.
  int get length => _values.length;

  /// The newest [kUpdatedAt] held, or null when none has one (all written
  /// before the field existed).
  Timestamp? get newest {
    Timestamp? out;
    for (final t in _stamps.values) {
      if (out == null || t.compareTo(out) > 0) out = t;
    }
    return out;
  }

  void put(String id, Map<String, dynamic> data) {
    _values[id] = data[kDeleted] == true ? null : _parse(id, data);
    final stamp = data[kUpdatedAt];
    if (stamp is Timestamp) {
      _stamps[id] = stamp;
    } else {
      _stamps.remove(id);
    }
  }

  void remove(String id) {
    _values.remove(id);
    _stamps.remove(id);
  }

  void clear() {
    _values.clear();
    _stamps.clear();
  }

  /// The documents to show: every one but the deleted, sorted by [compare].
  List<T> get visible {
    final out = [for (final v in _values.values) ?v];
    if (compare != null) out.sort(compare);
    return out;
  }
}

bool _missingIndex(Object e) => e is FirebaseException && e.code == 'failed-precondition';

/// How long a synced copy is trusted without checking it against a
/// server-side `count()` again — which costs a read per thousand documents,
/// and only catches what deltas can't: a cache the system evicted, or a
/// document deleted outright by an app predating [tombstone].
const kSyncVerifyEvery = Duration(days: 7);

/// Whether a copy last checked at `checkedAt`, holding `checkedCount`
/// documents then, can skip the check now that it holds `held`: recent
/// enough, and not shrunk since — documents are tombstoned, never removed,
/// so a smaller copy means the cache lost some.
bool trustSyncedCopy({required DateTime? checkedAt, required int checkedCount, required int held, DateTime? now}) =>
    checkedAt != null && (now ?? DateTime.now()).difference(checkedAt) < kSyncVerifyEvery && held >= checkedCount;

Future<bool> _trusted(String? key, int held) async {
  if (key == null || held == 0) return false;
  try {
    final saved = (await SharedPreferences.getInstance()).getString('synced:$key')?.split(':');
    if (saved == null || saved.length != 2) return false;
    return trustSyncedCopy(checkedAt: DateTime.fromMillisecondsSinceEpoch(int.parse(saved[0])), checkedCount: int.parse(saved[1]), held: held);
  } catch (_) {
    return false;
  }
}

Future<void> _trust(String? key, int held) async {
  if (key == null) return;
  try {
    await (await SharedPreferences.getInstance()).setString('synced:$key', '${DateTime.now().millisecondsSinceEpoch}:$held');
  } catch (_) {}
}

/// Streams `query`'s documents (parsed, deleted ones left out, sorted by
/// `compare`) while downloading each one only once per device — a plain
/// listener is billed and re-sent in full every time the app comes back
/// after more than 30 minutes.
///
/// Starts from this device's Firestore cache (free, instant, offline). When
/// a server-side `count()` agrees with it, only listens for what was written
/// since the newest document held ([kUpdatedAt]); otherwise (first launch,
/// cache evicted, a document deleted outright by an app predating
/// [tombstone]) listens to the whole query for this session, which also
/// brings the cache up to date for the next one. With a `key` naming the
/// query, a copy checked less than [kSyncVerifyEvery] ago skips the count.
///
/// `query` must have no `orderBy`: the "written since" variant adds a range
/// filter on [kUpdatedAt], which also needs a composite index alongside
/// `query`'s own filters (see firestore.indexes.json) — without one, falls
/// back to the whole query too.
Stream<List<T>> watchSynced<T>(
  Query<Map<String, dynamic>> query, {
  required T Function(String id, Map<String, dynamic> data) parse,
  int Function(T a, T b)? compare,
  String? key,
}) {
  final docs = SyncedDocs<T>(parse, compare: compare);
  late final StreamController<List<T>> controller;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? sub;
  var closed = false;
  var queue = Future<void>.value();

  void emit() {
    if (!closed) controller.add(docs.visible);
  }

  void listenToAll() {
    var checked = false;
    sub = query.snapshots().listen((snap) {
      docs.clear();
      for (final d in snap.docs) {
        docs.put(d.id, d.data());
      }
      emit();
      if (!checked && !snap.metadata.isFromCache) {
        checked = true;
        unawaited(_trust(key, docs.length));
      }
    }, onError: controller.addError);
  }

  Future<void> applyChanges(QuerySnapshot<Map<String, dynamic>> snap) async {
    for (final change in snap.docChanges) {
      if (change.type != DocumentChangeType.removed) {
        docs.put(change.doc.id, change.doc.data()!);
        continue;
      }
      // Gone from "written since": deleted outright, or edited on this
      // device and still waiting for its server timestamp, which keeps it
      // out of the filter until the server confirms the write. Only the
      // cache knows which.
      try {
        final local = await change.doc.reference.get(const GetOptions(source: Source.cache));
        final data = local.data();
        if (data != null) {
          docs.put(local.id, data);
          continue;
        }
      } catch (_) {}
      docs.remove(change.doc.id);
    }
    emit();
  }

  void listenToChanges(Timestamp since) {
    sub = query.where(kUpdatedAt, isGreaterThanOrEqualTo: since).snapshots().listen(
      (snap) => queue = queue.then((_) => applyChanges(snap)).catchError((Object e, StackTrace s) {
        if (!closed) controller.addError(e, s);
      }),
      onError: (Object e, StackTrace s) {
        if (closed) return;
        if (_missingIndex(e)) {
          listenToAll();
        } else {
          controller.addError(e, s);
        }
      },
    );
  }

  Future<void> start() async {
    try {
      final cached = await query.get(const GetOptions(source: Source.cache));
      for (final d in cached.docs) {
        docs.put(d.id, d.data());
      }
    } catch (_) {
      // No cache here (e.g. web without persistence).
    }
    if (closed) return;
    if (docs.length > 0) emit();
    if (await _trusted(key, docs.length)) {
      if (!closed) listenToChanges(docs.newest ?? Timestamp(0, 0));
      return;
    }
    int? count;
    try {
      count = (await query.count().get()).count;
    } catch (_) {
      // Offline: carry on from the cache, the listener catches up once back.
    }
    if (closed) return;
    if (docs.length == 0 || (count != null && count != docs.length)) {
      listenToAll();
    } else {
      if (count != null) unawaited(_trust(key, docs.length));
      listenToChanges(docs.newest ?? Timestamp(0, 0));
    }
  }

  controller = StreamController<List<T>>(
    onListen: () => unawaited(start()),
    onCancel: () async {
      closed = true;
      await sub?.cancel();
    },
  );
  return controller.stream;
}

/// One-shot [watchSynced]: `query`'s documents, downloading only those
/// written since the newest one this device holds.
Future<List<T>> fetchSynced<T>(
  Query<Map<String, dynamic>> query, {
  required T Function(String id, Map<String, dynamic> data) parse,
  int Function(T a, T b)? compare,
  String? key,
}) async {
  final docs = SyncedDocs<T>(parse, compare: compare);
  try {
    final cached = await query.get(const GetOptions(source: Source.cache));
    for (final d in cached.docs) {
      docs.put(d.id, d.data());
    }
  } catch (_) {}
  void putAll(QuerySnapshot<Map<String, dynamic>> snap) {
    for (final d in snap.docs) {
      docs.put(d.id, d.data());
    }
  }

  Future<List<T>> changesSince() async {
    try {
      putAll(await query.where(kUpdatedAt, isGreaterThanOrEqualTo: docs.newest ?? Timestamp(0, 0)).get(const GetOptions(source: Source.server)));
    } catch (e) {
      if (!_missingIndex(e)) rethrow;
      docs.clear();
      putAll(await query.get());
    }
    return docs.visible;
  }

  if (await _trusted(key, docs.length)) return changesSince();
  int? count;
  try {
    count = (await query.count().get()).count;
  } catch (_) {}

  if (count == null) {
    // Offline (or no count allowed): whatever's at hand.
    if (docs.length == 0) putAll(await query.get());
    return docs.visible;
  }
  if (docs.length == 0 || count != docs.length) {
    // Through a listener rather than a plain get: its first server snapshot
    // only comes once documents deleted outright are cleared from the cache
    // too, so the next call starts from an accurate copy.
    final snap = await query.snapshots(includeMetadataChanges: true).firstWhere((s) => !s.metadata.isFromCache);
    docs.clear();
    putAll(snap);
    unawaited(_trust(key, docs.length));
    return docs.visible;
  }
  unawaited(_trust(key, docs.length));
  return changesSince();
}
