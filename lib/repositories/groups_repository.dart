import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/group.dart';
import 'users_repository.dart';

class InviteException implements Exception {
  final String message;
  InviteException(this.message);
  @override
  String toString() => message;
}

abstract class GroupsRepository {
  /// Every group the user is a direct member of.
  Stream<List<Group>> watchMyGroups(String uid);

  Future<Group> createGroup({required String name, required String emoji, required int emojiBg, required String ownerId, bool temporary = false});

  Future<void> addMemberByEmail({required String groupId, required String email});

  /// Adds `memberId` (a Firebase Auth uid, or a `guest:` id from
  /// [GuestsRepository]) straight to `groupId`'s `memberIds`.
  Future<void> addMemberId({required String groupId, required String memberId});

  /// Deletes a group, its whole games + matches history.
  Future<void> deleteGroup(String groupId);

  /// Self-service join via a scanned QR invite code: adds `uid` to
  /// `groupId`'s `memberIds`. Doesn't require reading the group doc first —
  /// see GroupInviteCode.
  Future<void> joinGroup({required String groupId, required String uid});

  /// Scrubs `uid` from every group it touches, as part of full account
  /// deletion: groups it owns are deleted outright; groups it's merely a
  /// member of just have it removed from the roster.
  Future<void> deleteAllUserData(String uid);

  /// Swaps `oldUid` for `newUid` as a member of `groupId` — hands a player's
  /// slot in the group over to a different account. Doesn't touch match
  /// history; see `MatchesRepository.reassignPlayer` for that half.
  Future<void> reassignMember({required String groupId, required String oldUid, required String newUid});

  /// Marks a group as closed (a wound-down "temporary group" — its history
  /// stays visible but nothing new can be recorded in it) or reopens it. See
  /// [Group.closed].
  Future<void> setGroupClosed({required String groupId, required bool closed});

  /// Opens (or extends) `groupId`'s QR self-join window — see
  /// [Group.inviteExpiresAt]. Called whenever the invite dialog's QR tab is
  /// shown, so a freshly displayed code is always good for a fresh window.
  Future<void> refreshInviteWindow(String groupId);
}

class FirebaseGroupsRepository implements GroupsRepository {
  final FirebaseFirestore _db;
  final UsersRepository _users;
  FirebaseGroupsRepository({FirebaseFirestore? db, UsersRepository? users})
      : _db = db ?? FirebaseFirestore.instance,
        _users = users ?? FirebaseUsersRepository();

  CollectionReference<Map<String, dynamic>> get _groups => _db.collection('groups');

  @override
  Stream<List<Group>> watchMyGroups(String uid) {
    return _groups.where('memberIds', arrayContains: uid).snapshots().map(
          (snap) => snap.docs.map((d) => Group.fromDoc(d.id, d.data())).toList(),
        );
  }

  @override
  Future<Group> createGroup({required String name, required String emoji, required int emojiBg, required String ownerId, bool temporary = false}) async {
    final ref = _groups.doc();
    final group = Group(
      id: ref.id,
      name: name,
      emoji: emoji,
      emojiBg: emojiBg,
      memberIds: [ownerId],
      ownerId: ownerId,
      temporary: temporary,
    );
    await ref.set(group.toMap());
    return group;
  }

  @override
  Future<void> addMemberByEmail({required String groupId, required String email}) async {
    final user = await _users.getByEmail(email);
    if (user == null) {
      throw InviteException("Aucun compte trouvé avec cet e-mail.");
    }
    await addMemberId(groupId: groupId, memberId: user.uid);
  }

  @override
  Future<void> addMemberId({required String groupId, required String memberId}) async {
    await _groups.doc(groupId).update({
      'memberIds': FieldValue.arrayUnion([memberId]),
    });
  }

  @override
  Future<void> deleteGroup(String groupId) async {
    final doc = await _groups.doc(groupId).get();
    if (!doc.exists) return;
    final gamesSnap = await _groups.doc(groupId).collection('games').get();
    final matchesSnap = await _groups.doc(groupId).collection('matches').get();
    await _deleteRefs([...gamesSnap.docs.map((d) => d.reference), ...matchesSnap.docs.map((d) => d.reference)]);
    await _groups.doc(groupId).delete();
  }

  /// Deletes `refs` in batches of 450 to stay under Firestore's 500-write
  /// limit per batch.
  Future<void> _deleteRefs(List<DocumentReference<Map<String, dynamic>>> refs) async {
    const chunkSize = 450;
    for (var i = 0; i < refs.length; i += chunkSize) {
      final batch = _db.batch();
      for (final r in refs.skip(i).take(chunkSize)) {
        batch.delete(r);
      }
      await batch.commit();
    }
  }

  @override
  Future<void> joinGroup({required String groupId, required String uid}) async {
    final doc = await _groups.doc(groupId).get();
    if (!doc.exists) throw InviteException('Groupe introuvable.');
    final group = Group.fromDoc(doc.id, doc.data()!);
    if (group.closed) {
      throw InviteException('Ce groupe est clos et n\'accepte plus de nouveaux membres.');
    }
    // Fast client-side check with a friendly message — the real gate is the
    // matching `inviteWindowOpen` check in firestore.rules' `isSelfJoin`, so
    // a modified client can't just skip this and join anyway.
    if (group.inviteExpiresAt != null && DateTime.now().isAfter(group.inviteExpiresAt!)) {
      throw InviteException("Ce code d'invitation a expiré — demandez-en un nouveau.");
    }
    await _groups.doc(groupId).update({
      'memberIds': FieldValue.arrayUnion([uid]),
    });
  }

  @override
  Future<void> deleteAllUserData(String uid) async {
    final snap = await _groups.where('memberIds', arrayContains: uid).get();
    final byId = <String, Group>{for (final d in snap.docs) d.id: Group.fromDoc(d.id, d.data())};

    // Delete every group the user owns outright (cascades history).
    final owned = byId.values.where((g) => g.ownerId == uid).toList();
    for (final g in owned) {
      await deleteGroup(g.id);
      byId.remove(g.id);
    }

    // Leave every remaining group as a plain member.
    for (final g in byId.values) {
      await _groups.doc(g.id).update({
        'memberIds': FieldValue.arrayRemove([uid]),
      });
    }
  }

  @override
  Future<void> reassignMember({required String groupId, required String oldUid, required String newUid}) async {
    final ref = _groups.doc(groupId);
    final snap = await ref.get();
    if (!snap.exists) throw InviteException('Groupe introuvable.');
    final g = Group.fromDoc(snap.id, snap.data()!);
    if (!g.memberIds.contains(oldUid)) return;
    // Two sequential updates rather than one combined write — a single
    // `.update()` call can't apply both an arrayRemove and an arrayUnion to
    // the same field at once.
    await ref.update({
      'memberIds': FieldValue.arrayRemove([oldUid]),
    });
    await ref.update({
      'memberIds': FieldValue.arrayUnion([newUid]),
    });
  }

  @override
  Future<void> setGroupClosed({required String groupId, required bool closed}) async {
    await _groups.doc(groupId).update({
      'closed': closed,
      'closedAt': closed ? FieldValue.serverTimestamp() : FieldValue.delete(),
    });
  }

  @override
  Future<void> refreshInviteWindow(String groupId) async {
    await _groups.doc(groupId).update({
      'inviteExpiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(minutes: 30))),
    });
  }
}
