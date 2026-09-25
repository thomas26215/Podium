import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/message.dart';

abstract class MessagesRepository {
  /// Every message posted to the thread, oldest first. `salonId` scopes it
  /// to one salon when [FirebaseMessagesRepository.rootCollection] is
  /// `'servers'` — left null for a Group, which has exactly one thread.
  Stream<List<GroupMessage>> watchMessages(String rootId, {String? salonId});

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
  Stream<List<GroupMessage>> watchMessages(String rootId, {String? salonId}) {
    Query<Map<String, dynamic>> q = _col(rootId);
    if (salonId != null) q = q.where('salonId', isEqualTo: salonId);
    return q.orderBy('createdAt').snapshots().map((snap) => snap.docs.map((d) => GroupMessage.fromDoc(d.id, d.data())).toList());
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
