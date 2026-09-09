/// Self-contained invite payload encoded into a QR code so a scanning
/// client can join a group without ever needing to read the group document
/// first (Firestore only allows members to read a group's data — see
/// firestore.rules). Everything the join write needs is baked in by the
/// inviter, who is already a member and can read it.
class GroupInviteCode {
  final String groupId;
  final String name;
  final String emoji;

  const GroupInviteCode({required this.groupId, required this.name, required this.emoji});

  String encode() => Uri(scheme: 'podium', host: 'join', queryParameters: {
        'g': groupId,
        'n': name,
        'e': emoji,
      }).toString();

  static GroupInviteCode? tryParse(String raw) {
    try {
      final uri = Uri.parse(raw.trim());
      if (uri.scheme != 'podium' || uri.host != 'join') return null;
      final g = uri.queryParameters['g'];
      if (g == null || g.isEmpty) return null;
      return GroupInviteCode(groupId: g, name: uri.queryParameters['n'] ?? 'Groupe', emoji: uri.queryParameters['e'] ?? '🎲');
    } catch (_) {
      return null;
    }
  }
}
