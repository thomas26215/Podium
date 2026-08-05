import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';

abstract class UsersRepository {
  Future<AppUser?> getByEmail(String email);
  Future<AppUser?> getById(String uid);
  Stream<AppUser?> watchById(String uid);

  /// Deletes the `users/{uid}` doc and its `emailIndex` entry.
  Future<void> deleteUser({required String uid, required String email});

  /// Registers this device's FCM token for push notifications (a user can
  /// have several — one per device signed in).
  Future<void> registerFcmToken({required String uid, required String token});

  /// Deregisters a token — e.g. on sign-out, so a shared/reused device
  /// doesn't keep receiving another account's notifications.
  Future<void> unregisterFcmToken({required String uid, required String token});

  /// Adds `friendUid` to `uid`'s own friend list (see [AppUser.friendIds]).
  Future<void> addFriend({required String uid, required String friendUid});

  /// Removes `friendUid` from `uid`'s friend list.
  Future<void> removeFriend({required String uid, required String friendUid});
}

class FirebaseUsersRepository implements UsersRepository {
  final FirebaseFirestore _db;
  FirebaseUsersRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  @override
  Future<AppUser?> getByEmail(String email) async {
    final key = email.trim().toLowerCase();
    final idx = await _db.collection('emailIndex').doc(key).get();
    if (!idx.exists) return null;
    final uid = idx.data()!['uid'] as String;
    return getById(uid);
  }

  @override
  Future<AppUser?> getById(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromDoc(uid, doc.data()!);
  }

  @override
  Stream<AppUser?> watchById(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return AppUser.fromDoc(uid, doc.data()!);
    });
  }

  @override
  Future<void> deleteUser({required String uid, required String email}) async {
    final batch = _db.batch();
    batch.delete(_db.collection('users').doc(uid));
    if (email.isNotEmpty) batch.delete(_db.collection('emailIndex').doc(email.trim().toLowerCase()));
    await batch.commit();
  }

  @override
  Future<void> registerFcmToken({required String uid, required String token}) async {
    await _db.collection('users').doc(uid).update({
      'fcmTokens': FieldValue.arrayUnion([token]),
    });
  }

  @override
  Future<void> unregisterFcmToken({required String uid, required String token}) async {
    await _db.collection('users').doc(uid).update({
      'fcmTokens': FieldValue.arrayRemove([token]),
    });
  }

  @override
  Future<void> addFriend({required String uid, required String friendUid}) async {
    await _db.collection('users').doc(uid).update({
      'friendIds': FieldValue.arrayUnion([friendUid]),
    });
  }

  @override
  Future<void> removeFriend({required String uid, required String friendUid}) async {
    await _db.collection('users').doc(uid).update({
      'friendIds': FieldValue.arrayRemove([friendUid]),
    });
  }
}

class FakeUsersRepository implements UsersRepository {
  final Map<String, AppUser> users;
  final _controllers = <String, StreamController<AppUser?>>{};
  FakeUsersRepository(this.users);

  StreamController<AppUser?> _ctrl(String uid) => _controllers.putIfAbsent(uid, () => StreamController.broadcast());

  @override
  Future<AppUser?> getByEmail(String email) async {
    try {
      return users.values.firstWhere((u) => u.email.toLowerCase() == email.trim().toLowerCase());
    } catch (_) {
      return null;
    }
  }

  @override
  Future<AppUser?> getById(String uid) async => users[uid];

  @override
  Stream<AppUser?> watchById(String uid) {
    Future.microtask(() => _ctrl(uid).add(users[uid]));
    return _ctrl(uid).stream;
  }

  @override
  Future<void> deleteUser({required String uid, required String email}) async {
    users.remove(uid);
    _ctrl(uid).add(null);
  }

  @override
  Future<void> registerFcmToken({required String uid, required String token}) async {}

  @override
  Future<void> unregisterFcmToken({required String uid, required String token}) async {}

  @override
  Future<void> addFriend({required String uid, required String friendUid}) async {
    final u = users[uid];
    if (u == null || u.friendIds.contains(friendUid)) return;
    users[uid] = AppUser(uid: u.uid, email: u.email, displayName: u.displayName, color: u.color, friendIds: [...u.friendIds, friendUid]);
    _ctrl(uid).add(users[uid]);
  }

  @override
  Future<void> removeFriend({required String uid, required String friendUid}) async {
    final u = users[uid];
    if (u == null) return;
    users[uid] = AppUser(uid: u.uid, email: u.email, displayName: u.displayName, color: u.color, friendIds: u.friendIds.where((f) => f != friendUid).toList());
    _ctrl(uid).add(users[uid]);
  }
}
