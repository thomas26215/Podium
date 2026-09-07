import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/group.dart';
import 'users_repository.dart';

class InviteException implements Exception {
  final String message;
  InviteException(this.message);
  @override
  String toString() => message;
}

abstract class GroupsRepository {
  /// Every group (root or subgroup) the user can see: groups they're a
  /// direct member of, plus the root/parent of any of those, plus every
  /// subgroup under a root they belong to (so the accordion always has the
  /// full tree to show, matching the prototype's aggregation behavior).
  Stream<List<Group>> watchMyGroups(String uid);

  Future<Group> createGroup({required String name, required String emoji, required int emojiBg, required String ownerId, bool temporary = false});

  Future<Group> createSubGroup({
    required String parentId,
    required String name,
    required String emoji,
    required int emojiBg,
    required String ownerId,
  });

  Future<void> addMemberByEmail({required String groupId, required String email});

  /// Adds `memberId` (a Firebase Auth uid, or a `guest:` id from
  /// [GuestsRepository]) straight to `groupId`'s `memberIds` (and the root's
  /// `allMemberIds`) — the same array-update [addMemberByEmail] does once it
  /// already has a uid in hand.
  Future<void> addMemberId({required String groupId, required String memberId});

  /// Deletes a group. For a root group this also deletes its whole games +
  /// matches history and every subgroup underneath it. For a subgroup, only
  /// the matches recorded under it are deleted (games are shared with the
  /// root and untouched); the parent's `subGroupIds`/`allMemberIds` are kept
  /// in sync.
  Future<void> deleteGroup(String groupId);

  /// Self-service join via a scanned QR invite code: adds `uid` to
  /// `groupId`'s `memberIds` (and, if `groupId` is a root, its own
  /// `allMemberIds`; if it's a subgroup, `rootId`'s `allMemberIds` instead).
  /// Doesn't require reading the group doc first — see GroupInviteCode.
  Future<void> joinGroup({required String groupId, required String rootId, required String uid});

  /// Scrubs `uid` from every group it touches, as part of full account
  /// deletion: groups it owns are deleted outright (cascading subgroups +
  /// history, same as [deleteGroup]); groups it's merely a member of just
  /// have it removed from the roster.
  Future<void> deleteAllUserData(String uid);

  /// Swaps `oldUid` for `newUid` everywhere it's a member across `rootId`'s
  /// whole tree (the root itself and every subgroup underneath it) — hands a
  /// player's slot in the group over to a different account. Doesn't touch
  /// match history; see `MatchesRepository.reassignPlayer` for that half.
  Future<void> reassignMember({required String rootId, required String oldUid, required String newUid});

  /// Marks a ROOT group as closed (a wound-down "temporary group" — its
  /// history stays visible but nothing new can be recorded in it) or
  /// reopens it. See [Group.closed].
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
    // `allMemberIds` (root-only) catches roots a user was only ever added to
    // via a subgroup; `memberIds` catches everything the user directly joined.
    final query = _groups.where(
      Filter.or(
        Filter('memberIds', arrayContains: uid),
        Filter('allMemberIds', arrayContains: uid),
      ),
    );
    return query.snapshots().asyncMap((snap) async {
      final direct = snap.docs.map((d) => Group.fromDoc(d.id, d.data())).toList();
      final byId = <String, Group>{for (final g in direct) g.id: g};

      // Pull in parents of any subgroup we're directly in. A single
      // permission-denied here (e.g. stale data from before security rules
      // were enforced) shouldn't take down the whole groups list — skip it
      // and let the rest load.
      final missingParents = direct.where((g) => g.parentId != null && !byId.containsKey(g.parentId)).map((g) => g.parentId!).toSet();
      for (final pid in missingParents) {
        try {
          final doc = await _groups.doc(pid).get();
          if (doc.exists) byId[pid] = Group.fromDoc(doc.id, doc.data()!);
        } catch (e) {
          debugPrint('watchMyGroups: failed to fetch parent group $pid: $e');
        }
      }

      // Pull in every subgroup of any root group we can see, so the tree is complete.
      final roots = byId.values.where((g) => g.isRoot).toList();
      for (final root in roots) {
        for (final sgid in root.subGroupIds) {
          if (byId.containsKey(sgid)) continue;
          try {
            final doc = await _groups.doc(sgid).get();
            if (doc.exists) byId[sgid] = Group.fromDoc(doc.id, doc.data()!);
          } catch (e) {
            debugPrint('watchMyGroups: failed to fetch subgroup $sgid: $e');
          }
        }
      }
      return byId.values.toList();
    });
  }

  @override
  Future<Group> createGroup({required String name, required String emoji, required int emojiBg, required String ownerId, bool temporary = false}) async {
    final ref = _groups.doc();
    final group = Group(
      id: ref.id,
      name: name,
      emoji: emoji,
      emojiBg: emojiBg,
      parentId: null,
      memberIds: [ownerId],
      subGroupIds: const [],
      allMemberIds: [ownerId],
      ownerId: ownerId,
      temporary: temporary,
    );
    await ref.set(group.toMap());
    return group;
  }

  @override
  Future<Group> createSubGroup({
    required String parentId,
    required String name,
    required String emoji,
    required int emojiBg,
    required String ownerId,
  }) async {
    final ref = _groups.doc();
    final group = Group(
      id: ref.id,
      name: name,
      emoji: emoji,
      emojiBg: emojiBg,
      parentId: parentId,
      memberIds: [ownerId],
      subGroupIds: const [],
      allMemberIds: const [],
      ownerId: ownerId,
    );
    await _db.runTransaction((tx) async {
      tx.set(ref, group.toMap());
      tx.update(_groups.doc(parentId), {
        'subGroupIds': FieldValue.arrayUnion([ref.id]),
        'allMemberIds': FieldValue.arrayUnion([ownerId]),
      });
    });
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
    final doc = await _groups.doc(groupId).get();
    if (!doc.exists) throw InviteException('Groupe introuvable.');
    final group = Group.fromDoc(doc.id, doc.data()!);
    final batch = _db.batch();
    batch.update(_groups.doc(groupId), {
      'memberIds': FieldValue.arrayUnion([memberId]),
      if (group.isRoot) 'allMemberIds': FieldValue.arrayUnion([memberId]),
    });
    if (!group.isRoot && group.parentId != null) {
      batch.update(_groups.doc(group.parentId), {
        'allMemberIds': FieldValue.arrayUnion([memberId]),
      });
    }
    await batch.commit();
  }

  @override
  Future<void> deleteGroup(String groupId) async {
    final doc = await _groups.doc(groupId).get();
    if (!doc.exists) return;
    final group = Group.fromDoc(doc.id, doc.data()!);

    if (group.isRoot) {
      final gamesSnap = await _groups.doc(groupId).collection('games').get();
      final matchesSnap = await _groups.doc(groupId).collection('matches').get();
      await _deleteRefs([...gamesSnap.docs.map((d) => d.reference), ...matchesSnap.docs.map((d) => d.reference)]);
      await _deleteRefs(group.subGroupIds.map(_groups.doc).toList());
      await _groups.doc(groupId).delete();
    } else {
      final parentId = group.parentId!;
      final matchesSnap = await _groups.doc(parentId).collection('matches').where('groupId', isEqualTo: groupId).get();
      await _deleteRefs(matchesSnap.docs.map((d) => d.reference).toList());
      await _groups.doc(groupId).delete();
      await _groups.doc(parentId).update({
        'subGroupIds': FieldValue.arrayRemove([groupId]),
      });
      await _recomputeAllMemberIds(parentId);
    }
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
  Future<void> joinGroup({required String groupId, required String rootId, required String uid}) async {
    final rootDoc = await _groups.doc(rootId).get();
    if (!rootDoc.exists) throw InviteException('Groupe introuvable.');
    if (Group.fromDoc(rootDoc.id, rootDoc.data()!).closed) {
      throw InviteException('Ce groupe est clos et n\'accepte plus de nouveaux membres.');
    }
    // Fast client-side check with a friendly message — the real gate is the
    // matching `inviteWindowOpen` check in firestore.rules' `isSelfJoin`, so
    // a modified client can't just skip this and join anyway.
    final targetDoc = groupId == rootId ? rootDoc : await _groups.doc(groupId).get();
    if (!targetDoc.exists) throw InviteException('Groupe introuvable.');
    final expiresAt = Group.fromDoc(targetDoc.id, targetDoc.data()!).inviteExpiresAt;
    if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
      throw InviteException("Ce code d'invitation a expiré — demandez-en un nouveau.");
    }
    final batch = _db.batch();
    if (groupId == rootId) {
      batch.update(_groups.doc(groupId), {
        'memberIds': FieldValue.arrayUnion([uid]),
        'allMemberIds': FieldValue.arrayUnion([uid]),
      });
    } else {
      batch.update(_groups.doc(groupId), {
        'memberIds': FieldValue.arrayUnion([uid]),
      });
      batch.update(_groups.doc(rootId), {
        'allMemberIds': FieldValue.arrayUnion([uid]),
      });
    }
    await batch.commit();
  }

  @override
  Future<void> deleteAllUserData(String uid) async {
    final snap = await _groups
        .where(
          Filter.or(
            Filter('memberIds', arrayContains: uid),
            Filter('allMemberIds', arrayContains: uid),
          ),
        )
        .get();
    final byId = <String, Group>{for (final d in snap.docs) d.id: Group.fromDoc(d.id, d.data())};

    // Delete every group the user owns outright (cascades subgroups + history).
    final owned = byId.values.where((g) => g.ownerId == uid).toList();
    for (final g in owned) {
      if (!byId.containsKey(g.id)) continue; // already removed by an earlier cascade
      await deleteGroup(g.id);
      byId.remove(g.id);
      for (final subId in g.subGroupIds) {
        byId.remove(subId);
      }
    }

    // Leave every remaining group as a plain member.
    for (final g in byId.values) {
      final ref = _groups.doc(g.id);
      final fresh = await ref.get();
      if (!fresh.exists) continue;
      final current = Group.fromDoc(fresh.id, fresh.data()!);
      if (current.ownerId == uid) continue; // shouldn't happen, guard anyway
      await ref.update({
        'memberIds': FieldValue.arrayRemove([uid]),
        if (current.isRoot) 'allMemberIds': FieldValue.arrayRemove([uid]),
      });
      if (!current.isRoot && current.parentId != null) {
        await _recomputeAllMemberIds(current.parentId!);
      }
    }
  }

  @override
  Future<void> reassignMember({required String rootId, required String oldUid, required String newUid}) async {
    final rootSnap = await _groups.doc(rootId).get();
    if (!rootSnap.exists) throw InviteException('Groupe introuvable.');
    final root = Group.fromDoc(rootSnap.id, rootSnap.data()!);
    for (final id in [rootId, ...root.subGroupIds]) {
      final ref = _groups.doc(id);
      final snap = await ref.get();
      if (!snap.exists) continue;
      final g = Group.fromDoc(snap.id, snap.data()!);
      if (!g.memberIds.contains(oldUid)) continue;
      // Two sequential updates rather than one combined write — a single
      // `.update()` call can't apply both an arrayRemove and an arrayUnion
      // to the same field at once.
      await ref.update({
        'memberIds': FieldValue.arrayRemove([oldUid]),
      });
      await ref.update({
        'memberIds': FieldValue.arrayUnion([newUid]),
      });
    }
    await _recomputeAllMemberIds(rootId);
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

  /// Recomputes a root's `allMemberIds` from scratch (its own members plus
  /// every remaining subgroup's members) — used after a subgroup is removed.
  Future<void> _recomputeAllMemberIds(String rootId) async {
    final rootSnap = await _groups.doc(rootId).get();
    if (!rootSnap.exists) return;
    final root = Group.fromDoc(rootSnap.id, rootSnap.data()!);
    final ids = <String>{...root.memberIds};
    for (final subId in root.subGroupIds) {
      final subSnap = await _groups.doc(subId).get();
      if (subSnap.exists) ids.addAll(Group.fromDoc(subSnap.id, subSnap.data()!).memberIds);
    }
    await _groups.doc(rootId).update({'allMemberIds': ids.toList()});
  }
}
