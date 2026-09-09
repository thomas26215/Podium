import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/salon.dart';
import '../models/server.dart';
import 'groups_repository.dart' show InviteException;
import 'users_repository.dart';

abstract class ServersRepository {
  /// Every server the user is a direct member of (owner, admin or plain
  /// member).
  Stream<List<Server>> watchMyServers(String uid);

  Future<Server> createServer({required String name, required String emoji, required int emojiBg, required String ownerId});

  Future<void> addMemberByEmail({required String serverId, required String email});
  Future<void> addMemberId({required String serverId, required String memberId});

  /// Promotes/demotes `uid` to/from admin — owner-only (revalidated by
  /// firestore.rules). Promoting someone who isn't a member yet is a no-op.
  Future<void> setAdmin({required String serverId, required String uid, required bool admin});

  Future<void> deleteServer(String serverId);

  /// Self-service join via a scanned QR invite code — adds `uid` to the
  /// server's `memberIds`. Doesn't grant access to any Salon by itself (see
  /// [joinSalon]).
  Future<void> joinServer({required String serverId, required String uid});

  Future<void> setServerClosed({required String serverId, required bool closed});
  Future<void> refreshServerInviteWindow(String serverId);

  /// Every salon of `serverId` the user belongs to, plus (for an owner/admin)
  /// every salon of the server, so management screens can show the full
  /// list.
  Stream<List<Salon>> watchSalons(String serverId);

  Future<Salon> createSalon({required String serverId, required String name, required String emoji, required int emojiBg});

  Future<void> addSalonMemberId({required String serverId, required String salonId, required String memberId});
  Future<void> addSalonMemberByEmail({required String serverId, required String salonId, required String email});

  Future<void> deleteSalon({required String serverId, required String salonId});

  /// Self-service join via a scanned QR invite code — adds `uid` to the
  /// salon's `memberIds` and, if not already there, to the server's
  /// `memberIds` too (so scanning a salon invite alone is enough, no need to
  /// separately join the server first).
  Future<void> joinSalon({required String serverId, required String salonId, required String uid});

  Future<void> setSalonClosed({required String serverId, required String salonId, required bool closed});
  Future<void> refreshSalonInviteWindow({required String serverId, required String salonId});

  /// Scrubs `uid` from every server/salon it touches, as part of full
  /// account deletion (see `GroupsRepository.deleteAllUserData` for the
  /// Group half): servers it owns are deleted outright (cascading salons +
  /// history); everywhere else it's merely a member/admin, it's just
  /// removed from the roster.
  Future<void> deleteAllUserData(String uid);
}

class FirebaseServersRepository implements ServersRepository {
  final FirebaseFirestore _db;
  final UsersRepository _users;
  FirebaseServersRepository({FirebaseFirestore? db, UsersRepository? users})
      : _db = db ?? FirebaseFirestore.instance,
        _users = users ?? FirebaseUsersRepository();

  CollectionReference<Map<String, dynamic>> get _servers => _db.collection('servers');
  CollectionReference<Map<String, dynamic>> _salons(String serverId) => _servers.doc(serverId).collection('salons');

  @override
  Stream<List<Server>> watchMyServers(String uid) {
    return _servers.where('memberIds', arrayContains: uid).snapshots().map(
          (snap) => snap.docs.map((d) => Server.fromDoc(d.id, d.data())).toList(),
        );
  }

  @override
  Future<Server> createServer({required String name, required String emoji, required int emojiBg, required String ownerId}) async {
    final ref = _servers.doc();
    final server = Server(id: ref.id, name: name, emoji: emoji, emojiBg: emojiBg, ownerId: ownerId, adminIds: const [], memberIds: [ownerId]);
    await ref.set(server.toMap());
    return server;
  }

  @override
  Future<void> addMemberByEmail({required String serverId, required String email}) async {
    final user = await _users.getByEmail(email);
    if (user == null) throw InviteException("Aucun compte trouvé avec cet e-mail.");
    await addMemberId(serverId: serverId, memberId: user.uid);
  }

  @override
  Future<void> addMemberId({required String serverId, required String memberId}) async {
    await _servers.doc(serverId).update({
      'memberIds': FieldValue.arrayUnion([memberId]),
    });
  }

  @override
  Future<void> setAdmin({required String serverId, required String uid, required bool admin}) async {
    await _servers.doc(serverId).update({
      'adminIds': admin ? FieldValue.arrayUnion([uid]) : FieldValue.arrayRemove([uid]),
    });
  }

  @override
  Future<void> deleteServer(String serverId) async {
    final salonsSnap = await _salons(serverId).get();
    for (final salonDoc in salonsSnap.docs) {
      final matchesSnap = await _servers.doc(serverId).collection('matches').where('salonId', isEqualTo: salonDoc.id).get();
      await _deleteRefs(matchesSnap.docs.map((d) => d.reference).toList());
      await salonDoc.reference.delete();
    }
    final gamesSnap = await _servers.doc(serverId).collection('games').get();
    await _deleteRefs(gamesSnap.docs.map((d) => d.reference).toList());
    await _servers.doc(serverId).delete();
  }

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
  Future<void> joinServer({required String serverId, required String uid}) async {
    final doc = await _servers.doc(serverId).get();
    if (!doc.exists) throw InviteException('Serveur introuvable.');
    final server = Server.fromDoc(doc.id, doc.data()!);
    if (server.closed) throw InviteException("Ce serveur est clos et n'accepte plus de nouveaux membres.");
    if (server.inviteExpiresAt != null && DateTime.now().isAfter(server.inviteExpiresAt!)) {
      throw InviteException("Ce code d'invitation a expiré — demandez-en un nouveau.");
    }
    await _servers.doc(serverId).update({
      'memberIds': FieldValue.arrayUnion([uid]),
    });
  }

  @override
  Future<void> setServerClosed({required String serverId, required bool closed}) async {
    await _servers.doc(serverId).update({
      'closed': closed,
      'closedAt': closed ? FieldValue.serverTimestamp() : FieldValue.delete(),
    });
  }

  @override
  Future<void> refreshServerInviteWindow(String serverId) async {
    await _servers.doc(serverId).update({
      'inviteExpiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(minutes: 30))),
    });
  }

  @override
  Stream<List<Salon>> watchSalons(String serverId) {
    return _salons(serverId).snapshots().map((snap) => snap.docs.map((d) => Salon.fromDoc(d.id, d.data())).toList());
  }

  @override
  Future<Salon> createSalon({required String serverId, required String name, required String emoji, required int emojiBg}) async {
    final ref = _salons(serverId).doc();
    final salon = Salon(id: ref.id, serverId: serverId, name: name, emoji: emoji, emojiBg: emojiBg, memberIds: const []);
    await ref.set(salon.toMap());
    return salon;
  }

  @override
  Future<void> addSalonMemberId({required String serverId, required String salonId, required String memberId}) async {
    await _salons(serverId).doc(salonId).update({
      'memberIds': FieldValue.arrayUnion([memberId]),
    });
  }

  @override
  Future<void> addSalonMemberByEmail({required String serverId, required String salonId, required String email}) async {
    final user = await _users.getByEmail(email);
    if (user == null) throw InviteException("Aucun compte trouvé avec cet e-mail.");
    await addSalonMemberId(serverId: serverId, salonId: salonId, memberId: user.uid);
  }

  @override
  Future<void> deleteSalon({required String serverId, required String salonId}) async {
    final matchesSnap = await _servers.doc(serverId).collection('matches').where('salonId', isEqualTo: salonId).get();
    await _deleteRefs(matchesSnap.docs.map((d) => d.reference).toList());
    await _salons(serverId).doc(salonId).delete();
  }

  @override
  Future<void> joinSalon({required String serverId, required String salonId, required String uid}) async {
    final salonDoc = await _salons(serverId).doc(salonId).get();
    if (!salonDoc.exists) throw InviteException('Salon introuvable.');
    final salon = Salon.fromDoc(salonDoc.id, salonDoc.data()!);
    if (salon.closed) throw InviteException("Ce salon est clos et n'accepte plus de nouveaux membres.");
    if (salon.inviteExpiresAt != null && DateTime.now().isAfter(salon.inviteExpiresAt!)) {
      throw InviteException("Ce code d'invitation a expiré — demandez-en un nouveau.");
    }
    final batch = _db.batch();
    batch.update(_salons(serverId).doc(salonId), {
      'memberIds': FieldValue.arrayUnion([uid]),
    });
    batch.update(_servers.doc(serverId), {
      'memberIds': FieldValue.arrayUnion([uid]),
    });
    await batch.commit();
  }

  @override
  Future<void> setSalonClosed({required String serverId, required String salonId, required bool closed}) async {
    await _salons(serverId).doc(salonId).update({
      'closed': closed,
      'closedAt': closed ? FieldValue.serverTimestamp() : FieldValue.delete(),
    });
  }

  @override
  Future<void> refreshSalonInviteWindow({required String serverId, required String salonId}) async {
    await _salons(serverId).doc(salonId).update({
      'inviteExpiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(minutes: 30))),
    });
  }

  @override
  Future<void> deleteAllUserData(String uid) async {
    final snap = await _servers.where('memberIds', arrayContains: uid).get();
    final byId = <String, Server>{for (final d in snap.docs) d.id: Server.fromDoc(d.id, d.data())};

    final owned = byId.values.where((s) => s.ownerId == uid).toList();
    for (final s in owned) {
      await deleteServer(s.id);
      byId.remove(s.id);
    }

    for (final s in byId.values) {
      await _servers.doc(s.id).update({
        'memberIds': FieldValue.arrayRemove([uid]),
        'adminIds': FieldValue.arrayRemove([uid]),
      });
      final salonsSnap = await _salons(s.id).where('memberIds', arrayContains: uid).get();
      for (final salonDoc in salonsSnap.docs) {
        await salonDoc.reference.update({
          'memberIds': FieldValue.arrayRemove([uid]),
        });
      }
    }
  }
}
