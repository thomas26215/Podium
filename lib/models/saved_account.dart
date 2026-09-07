class SavedAccount {
  final String email;
  final String displayName;
  final int color;

  const SavedAccount({required this.email, required this.displayName, required this.color});

  Map<String, dynamic> toJson() => {
        'email': email,
        'displayName': displayName,
        'color': color,
      };

  factory SavedAccount.fromJson(Map<String, dynamic> json) {
    return SavedAccount(
      email: (json['email'] as String?) ?? '',
      displayName: (json['displayName'] as String?) ?? 'Joueur',
      color: (json['color'] as int?) ?? 0,
    );
  }
}