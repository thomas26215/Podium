import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../models/plus_membership.dart';

abstract class UsersRepository {
  Future<AppUser?> getByEmail(String email);
  Future<AppUser?> getById(String uid);

  /// The signed-in account itself: its public doc merged with its owner-only
  /// `private/account` doc (e-mail, friends). Only readable for your own uid.
  Stream<AppUser?> watchOwnAccount(String uid);

  /// Deletes the `users/{uid}` doc, its private doc and its `emailIndex` entry.
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

  /// Saves `user`'s customizable profile (see [AppUser.toProfileMap]).
  Future<void> updateProfile(AppUser user);

  /// Adds `badgeIds` to `uid`'s unlocked badges — never removes any.
  Future<void> unlockBadges({required String uid, required List<String> badgeIds});

  /// Sets `uid`'s Podium+ membership — null ends it. SIMULATION: the app
  /// calls it itself for now (see PlusMembership).
  Future<void> setPlus({required String uid, PlusMembership? membership});

  /// Sets `uid`'s jetons (on the private doc) and what they own from the
  /// Boutique (on the public one), together. SIMULATION: the app calls it
  /// itself for now; with real purchases only the server will, once the
  /// store has confirmed a payment or the balance covers a price.
  Future<void> setWallet({required String uid, required int coins, required List<String> ownedItems});
}

class FirebaseUsersRepository implements UsersRepository {
  final FirebaseFirestore _db;
  FirebaseUsersRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  /// Fields that used to live on the public `users/{uid}` doc before being
  /// moved to [_private] — see [_migrateLegacyPrivateFields].
  static const _legacyPrivateKeys = ['email', 'friendIds', 'fcmTokens'];

  DocumentReference<Map<String, dynamic>> _public(String uid) => _db.collection('users').doc(uid);
  DocumentReference<Map<String, dynamic>> _private(String uid) => _public(uid).collection('private').doc('account');

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
    final doc = await _public(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromDoc(uid, doc.data()!);
  }

  @override
  Stream<AppUser?> watchOwnAccount(String uid) {
    late final StreamController<AppUser?> controller;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? publicSub, privateSub;
    DocumentSnapshot<Map<String, dynamic>>? publicSnap, privateSnap;
    var migrationStarted = false;

    void emit() {
      if (publicSnap == null || privateSnap == null) return;
      final data = publicSnap!.data();
      if (data == null) {
        controller.add(null);
        return;
      }
      if (!migrationStarted && data.keys.any(_legacyPrivateKeys.contains)) {
        migrationStarted = true;
        unawaited(_migrateLegacyPrivateFields(uid, data));
      }
      controller.add(AppUser.fromDoc(uid, data, private: privateSnap!.data()));
    }

    controller = StreamController<AppUser?>(
      onListen: () {
        publicSub = _public(uid).snapshots().listen((s) {
          publicSnap = s;
          emit();
        }, onError: controller.addError);
        privateSub = _private(uid).snapshots().listen((s) {
          privateSnap = s;
          emit();
        }, onError: controller.addError);
      },
      onCancel: () async {
        await publicSub?.cancel();
        await privateSub?.cancel();
      },
    );
    return controller.stream;
  }

  /// Moves `email`/`friendIds`/`fcmTokens` off an account's public doc (where
  /// every signed-in user could read them) into its private doc. Runs once,
  /// the first time an account created before the split signs in.
  Future<void> _migrateLegacyPrivateFields(String uid, Map<String, dynamic> legacy) async {
    try {
      final batch = _db.batch();
      batch.set(
        _private(uid),
        {
          if (legacy['email'] is String) 'email': legacy['email'],
          if (legacy['friendIds'] is List && (legacy['friendIds'] as List).isNotEmpty) 'friendIds': FieldValue.arrayUnion(legacy['friendIds'] as List),
          if (legacy['fcmTokens'] is List && (legacy['fcmTokens'] as List).isNotEmpty) 'fcmTokens': FieldValue.arrayUnion(legacy['fcmTokens'] as List),
        },
        SetOptions(merge: true),
      );
      batch.update(_public(uid), {for (final k in _legacyPrivateKeys) k: FieldValue.delete()});
      await batch.commit();
    } catch (e) {
      debugPrint('Migration of private user fields failed: $e');
    }
  }

  @override
  Future<void> deleteUser({required String uid, required String email}) async {
    final batch = _db.batch();
    batch.delete(_private(uid));
    batch.delete(_public(uid));
    if (email.isNotEmpty) batch.delete(_db.collection('emailIndex').doc(email.trim().toLowerCase()));
    await batch.commit();
  }

  @override
  Future<void> registerFcmToken({required String uid, required String token}) async {
    await _private(uid).set({
      'fcmTokens': FieldValue.arrayUnion([token]),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> unregisterFcmToken({required String uid, required String token}) async {
    await _private(uid).set({
      'fcmTokens': FieldValue.arrayRemove([token]),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> addFriend({required String uid, required String friendUid}) async {
    await _private(uid).set({
      'friendIds': FieldValue.arrayUnion([friendUid]),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> removeFriend({required String uid, required String friendUid}) async {
    await _private(uid).set({
      'friendIds': FieldValue.arrayRemove([friendUid]),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> updateProfile(AppUser user) async {
    final data = user.toProfileMap();
    // mergeFields, not merge: each field is replaced whole — a plain merge
    // would deep-merge `gameAccounts`, so a removed account never left.
    await _public(user.uid).set(data, SetOptions(mergeFields: data.keys.toList()));
  }

  @override
  Future<void> unlockBadges({required String uid, required List<String> badgeIds}) async {
    if (badgeIds.isEmpty) return;
    await _public(uid).set({'badges': FieldValue.arrayUnion(badgeIds)}, SetOptions(merge: true));
  }

  @override
  Future<void> setPlus({required String uid, PlusMembership? membership}) async {
    await _public(uid).set({'plus': membership?.toMap() ?? FieldValue.delete()}, SetOptions(merge: true));
  }

  @override
  Future<void> setWallet({required String uid, required int coins, required List<String> ownedItems}) async {
    final batch = _db.batch()
      ..set(_private(uid), {'coins': coins}, SetOptions(merge: true))
      ..set(_public(uid), {'ownedItems': ownedItems}, SetOptions(merge: true));
    await batch.commit();
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
  Stream<AppUser?> watchOwnAccount(String uid) {
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
    users[uid] = u.copyWith(friendIds: [...u.friendIds, friendUid]);
    _ctrl(uid).add(users[uid]);
  }

  @override
  Future<void> removeFriend({required String uid, required String friendUid}) async {
    final u = users[uid];
    if (u == null) return;
    users[uid] = u.copyWith(friendIds: u.friendIds.where((f) => f != friendUid).toList());
    _ctrl(uid).add(users[uid]);
  }

  @override
  Future<void> updateProfile(AppUser user) async {
    final u = users[user.uid];
    if (u == null) return;
    // Everything customizable comes from `user`; what updateProfile never
    // writes (badges, friends, Podium+, the Boutique wallet) stays as stored.
    users[user.uid] = user.copyWith(badges: u.badges, friendIds: u.friendIds, plus: () => u.plus, ownedItems: u.ownedItems, coins: u.coins);
    _ctrl(user.uid).add(users[user.uid]);
  }

  @override
  Future<void> unlockBadges({required String uid, required List<String> badgeIds}) async {
    final u = users[uid];
    if (u == null) return;
    users[uid] = u.copyWith(badges: {...u.badges, ...badgeIds}.toList());
    _ctrl(uid).add(users[uid]);
  }

  @override
  Future<void> setPlus({required String uid, PlusMembership? membership}) async {
    final u = users[uid];
    if (u == null) return;
    users[uid] = u.copyWith(plus: () => membership);
    _ctrl(uid).add(users[uid]);
  }

  @override
  Future<void> setWallet({required String uid, required int coins, required List<String> ownedItems}) async {
    final u = users[uid];
    if (u == null) return;
    users[uid] = u.copyWith(coins: coins, ownedItems: ownedItems);
    _ctrl(uid).add(users[uid]);
  }
}
