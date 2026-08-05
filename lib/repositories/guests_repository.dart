import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';

/// Prefix that marks a member id as a guest rather than a Firebase Auth uid
/// (so `AppState` knows which repository to resolve it against).
const _guestPrefix = 'guest:';

bool isGuestId(String id) => id.startsWith(_guestPrefix);

/// Players added without a real account — e.g. a friend scoring a game on
/// someone else's phone. They live in their own top-level collection (not
/// `users/{uid}`, since there's no Firebase Auth uid to key on) and can later
/// be swapped for a real account by whoever built that linking flow.
abstract class GuestsRepository {
  Future<AppUser> createGuest({required String displayName, required String createdBy});
  Future<AppUser?> getById(String guestId);
}

class FirebaseGuestsRepository implements GuestsRepository {
  final FirebaseFirestore _db;
  FirebaseGuestsRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _guests => _db.collection('guests');

  @override
  Future<AppUser> createGuest({required String displayName, required String createdBy}) async {
    final ref = _guests.doc();
    final uid = '$_guestPrefix${ref.id}';
    final color = colorForUid(uid);
    await ref.set({
      'displayName': displayName,
      'color': color,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return AppUser(uid: uid, email: '', displayName: displayName, color: color, isGuest: true);
  }

  @override
  Future<AppUser?> getById(String guestId) async {
    final doc = await _guests.doc(guestId.substring(_guestPrefix.length)).get();
    if (!doc.exists) return null;
    final data = doc.data()!;
    return AppUser(
      uid: guestId,
      email: '',
      displayName: (data['displayName'] as String?) ?? 'Invité',
      color: (data['color'] as int?) ?? colorForUid(guestId),
      isGuest: true,
    );
  }
}

class FakeGuestsRepository implements GuestsRepository {
  final Map<String, AppUser> guests = {};
  int _counter = 0;

  @override
  Future<AppUser> createGuest({required String displayName, required String createdBy}) async {
    final uid = '$_guestPrefix${++_counter}';
    final user = AppUser(uid: uid, email: '', displayName: displayName, color: colorForUid(uid), isGuest: true);
    guests[uid] = user;
    return user;
  }

  @override
  Future<AppUser?> getById(String guestId) async => guests[guestId];
}
