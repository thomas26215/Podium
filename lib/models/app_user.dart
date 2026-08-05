import 'package:cloud_firestore/cloud_firestore.dart';

/// Palette a new account is assigned from, deterministically, so avatars
/// stay stable across sessions without needing a color picker at signup.
const List<int> kAvatarPalette = [
  0xFFFF5B34,
  0xFF5B4BE8,
  0xFF1F9D57,
  0xFFE8A93B,
  0xFFE5537B,
  0xFF2AA8B0,
  0xFF8B5CF6,
  0xFFD9622B,
];

int colorForUid(String uid) {
  var hash = 0;
  for (final unit in uid.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return kAvatarPalette[hash % kAvatarPalette.length];
}

class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final int color;
  /// True for a player added without a real account (see [GuestsRepository]).
  /// Its `uid` is a `guest:<id>` string rather than a Firebase Auth uid.
  final bool isGuest;

  /// Uids of this account's friends — a personal, one-directional address
  /// book (adding someone doesn't require their consent, same trust model
  /// as inviting a member into a group) used to prefill the group-invite
  /// picker instead of typing an e-mail every time (see
  /// [AppState.addFriend]/[AppState.friends]).
  final List<String> friendIds;

  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.color,
    this.isGuest = false,
    this.friendIds = const [],
  });

  String get initial => displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

  Map<String, dynamic> toMap() => {
        'email': email,
        'displayName': displayName,
        'color': color,
        'friendIds': friendIds,
        'createdAt': FieldValue.serverTimestamp(),
      };

  factory AppUser.fromDoc(String uid, Map<String, dynamic> data) {
    return AppUser(
      uid: uid,
      email: (data['email'] as String?) ?? '',
      displayName: (data['displayName'] as String?) ?? 'Joueur',
      color: (data['color'] as int?) ?? colorForUid(uid),
      friendIds: List<String>.from((data['friendIds'] as List?) ?? const []),
    );
  }
}
