class SavedAccount {
  final String email;
  final String displayName;
  final int color;

  /// Firebase uid — used as the key for an already-open session in
  /// [SessionManager] (see lib/state/session_manager.dart), so tapping this
  /// account can switch to it instantly instead of prompting for a
  /// password. Empty for accounts saved before this field existed; treat
  /// that the same as "no open-session fast path available".
  final String uid;

  const SavedAccount({required this.email, required this.displayName, required this.color, this.uid = ''});

  Map<String, dynamic> toJson() => {
        'email': email,
        'displayName': displayName,
        'color': color,
        'uid': uid,
      };

  factory SavedAccount.fromJson(Map<String, dynamic> json) {
    return SavedAccount(
      email: (json['email'] as String?) ?? '',
      displayName: (json['displayName'] as String?) ?? 'Joueur',
      color: (json['color'] as int?) ?? 0,
      uid: (json['uid'] as String?) ?? '',
    );
  }
}