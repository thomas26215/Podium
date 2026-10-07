import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/message.dart';

/// How many of a thread's latest messages are loaded at first — each "older
/// messages" tap brings that many more (see AppState.loadOlderMessages).
const kMessagesPage = 50;

abstract class MessagesRepository {
  /// The thread's `limit` latest messages, oldest first. `salonId` scopes it
  /// to one salon when [FirebaseMessagesRepository.rootCollection] is
  /// `'servers'` — left null for a Group, which has exactly one thread.
  Stream<List<GroupMessage>> watchMessages(String rootId, {String? salonId, int limit = kMessagesPage});

  /// `replyTo*` carries a snapshot of the quoted message (see
  /// [GroupMessage.replyToId]) — null for a message that isn't a reply.
  /// `mentionedUids` are the members `@mentioned` in `text` (see
  /// [GroupMessage.mentionedUids]).
  Future<GroupMessage> sendMessage(
    String rootId, {
    required String authorId,
    required String text,
    String? salonId,
    String? replyToId,
    String? replyToAuthorId,
    String? replyToText,
    List<String> mentionedUids = const [],
  });

  /// Posts a "which game tonight?" poll — see [GroupMessage.pollGameIds].
  Future<GroupMessage> sendPoll(String rootId, {required String authorId, required String text, required List<String> gameIds, String? salonId});

  /// Casts (or changes) `uid`'s ballot on a poll message — one vote per
  /// member, overwriting their own previous choice if any.
  Future<void> vote(String rootId, String messageId, {required String uid, required String gameId});

  /// Overwrites a message's text in place and flags it [GroupMessage.edited]
  /// — the author only (enforced by firestore.rules).
  Future<void> editMessage(String rootId, String messageId, String text);

  /// Sets `uid`'s reaction on a message to `emoji`, or clears it when
  /// `emoji` is null — one reaction per member per message (see
  /// [GroupMessage.reactions]).
  Future<void> react(String rootId, String messageId, {required String uid, String? emoji});

  /// Removes a message — the author only (enforced by firestore.rules).
  Future<void> deleteMessage(String rootId, String messageId);
}

class FirebaseMessagesRepository implements MessagesRepository {
  final FirebaseFirestore _db;

  /// Root collection the thread lives under — `'groups'` for a friend
  /// group's discussion (the default), `'servers'` for a Server's (shared by
  /// every one of its Salons, distinguished by `salonId`). Same doc shape
  /// either way.
  final String rootCollection;

  FirebaseMessagesRepository({FirebaseFirestore? db, this.rootCollection = 'groups'}) : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String rootId) =>
      _db.collection(rootCollection).doc(rootId).collection('messages');

  @override
  Stream<List<GroupMessage>> watchMessages(String rootId, {String? salonId, int limit = kMessagesPage}) {
    List<GroupMessage> latest(QuerySnapshot<Map<String, dynamic>> snap) {
      final all = snap.docs.map((d) => GroupMessage.fromDoc(d.id, d.data())).toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return all.length > limit ? all.sublist(all.length - limit) : all;
    }

    final thread = salonId == null ? _col(rootId) : _col(rootId).where('salonId', isEqualTo: salonId);
    final page = thread.orderBy('createdAt', descending: true).limit(limit);
    if (salonId == null) return page.snapshots().map(latest);
    // A salon's page needs the (salonId, createdAt) composite index (see
    // firestore.indexes.json): until it's deployed, the query errors out
    // and the whole thread is read instead — slower and costlier, but the
    // chat keeps working.
    late final StreamController<List<GroupMessage>> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? sub;
    void listen(Query<Map<String, dynamic>> query, {required bool fallBack}) {
      sub = query.snapshots().listen((snap) => controller.add(latest(snap)), onError: (Object e, StackTrace s) {
        if (fallBack && e is FirebaseException && e.code == 'failed-precondition') {
          listen(thread, fallBack: false);
        } else {
          controller.addError(e, s);
        }
      });
    }

    controller = StreamController<List<GroupMessage>>(
      onListen: () => listen(page, fallBack: true),
      onCancel: () => sub?.cancel(),
    );
    return controller.stream;
  }

  @override
  Future<GroupMessage> sendMessage(
    String rootId, {
    required String authorId,
    required String text,
    String? salonId,
    String? replyToId,
    String? replyToAuthorId,
    String? replyToText,
    List<String> mentionedUids = const [],
  }) async {
    final ref = _col(rootId).doc();
    final msg = GroupMessage(
      id: ref.id,
      authorId: authorId,
      text: text,
      createdAt: DateTime.now(),
      salonId: salonId,
      replyToId: replyToId,
      replyToAuthorId: replyToAuthorId,
      replyToText: replyToText,
      mentionedUids: mentionedUids,
    );
    await ref.set(msg.toMap());
    return msg;
  }

  @override
  Future<GroupMessage> sendPoll(String rootId, {required String authorId, required String text, required List<String> gameIds, String? salonId}) async {
    final ref = _col(rootId).doc();
    final msg = GroupMessage(id: ref.id, authorId: authorId, text: text, createdAt: DateTime.now(), salonId: salonId, pollGameIds: gameIds);
    await ref.set(msg.toMap());
    return msg;
  }

  @override
  Future<void> vote(String rootId, String messageId, {required String uid, required String gameId}) async {
    await _col(rootId).doc(messageId).update({'pollVotes.$uid': gameId});
  }

  @override
  Future<void> editMessage(String rootId, String messageId, String text) async {
    await _col(rootId).doc(messageId).update({'text': text, 'edited': true});
  }

  @override
  Future<void> react(String rootId, String messageId, {required String uid, String? emoji}) async {
    await _col(rootId).doc(messageId).update({'reactions.$uid': emoji ?? FieldValue.delete()});
  }

  @override
  Future<void> deleteMessage(String rootId, String messageId) async {
    await _col(rootId).doc(messageId).delete();
  }
}
