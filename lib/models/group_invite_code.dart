/// Public page that turns a shareable invite link into an "open in Podium"
/// button (or a Play Store link when the app isn't installed) — see
/// docs/rejoindre.html. Carries the same `podium://` code as the QR, in `c`.
const kInviteLinkPage = 'https://thomas26215.github.io/Podium/rejoindre.html';

/// A shareable https link for any `podium://` invite `code` (group, server
/// or salon) — see [kInviteLinkPage].
String inviteLinkFor(String code) => '$kInviteLinkPage?c=${Uri.encodeComponent(code)}';

/// The `podium://` invite code inside `raw` — `raw` itself when it's already
/// one, or the `c` parameter of a pasted [inviteLinkFor] link. Null for
/// anything else.
String? unwrapInviteCode(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null) return null;
  if (uri.scheme == 'podium') return raw.trim();
  if (uri.scheme == 'https' && uri.toString().startsWith(kInviteLinkPage)) {
    final inner = uri.queryParameters['c'];
    if (inner != null && Uri.tryParse(inner)?.scheme == 'podium') return inner;
  }
  return null;
}

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
      final uri = Uri.parse(unwrapInviteCode(raw) ?? raw.trim());
      if (uri.scheme != 'podium' || uri.host != 'join') return null;
      final g = uri.queryParameters['g'];
      if (g == null || g.isEmpty) return null;
      return GroupInviteCode(groupId: g, name: uri.queryParameters['n'] ?? 'Groupe', emoji: uri.queryParameters['e'] ?? '🎲');
    } catch (_) {
      return null;
    }
  }
}
