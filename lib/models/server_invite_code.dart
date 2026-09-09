/// Self-contained invite payload for joining a [Server] — same pattern as
/// [GroupInviteCode] (see that file for why it's a dumb client-only URI
/// rather than something read from Firestore first).
class ServerInviteCode {
  final String serverId;
  final String name;
  final String emoji;

  const ServerInviteCode({required this.serverId, required this.name, required this.emoji});

  String encode() => Uri(scheme: 'podium', host: 'join-server', queryParameters: {
        's': serverId,
        'n': name,
        'e': emoji,
      }).toString();

  static ServerInviteCode? tryParse(String raw) {
    try {
      final uri = Uri.parse(raw.trim());
      if (uri.scheme != 'podium' || uri.host != 'join-server') return null;
      final s = uri.queryParameters['s'];
      if (s == null || s.isEmpty) return null;
      return ServerInviteCode(serverId: s, name: uri.queryParameters['n'] ?? 'Serveur', emoji: uri.queryParameters['e'] ?? '🏠');
    } catch (_) {
      return null;
    }
  }
}

/// Self-contained invite payload for joining a [Salon] within a [Server] —
/// scanning it joins both the salon and (if not already a member) the
/// server in one step, see `ServersRepository.joinSalon`.
class SalonInviteCode {
  final String serverId;
  final String salonId;
  final String name;
  final String emoji;

  const SalonInviteCode({required this.serverId, required this.salonId, required this.name, required this.emoji});

  String encode() => Uri(scheme: 'podium', host: 'join-salon', queryParameters: {
        's': serverId,
        'r': salonId,
        'n': name,
        'e': emoji,
      }).toString();

  static SalonInviteCode? tryParse(String raw) {
    try {
      final uri = Uri.parse(raw.trim());
      if (uri.scheme != 'podium' || uri.host != 'join-salon') return null;
      final s = uri.queryParameters['s'];
      final r = uri.queryParameters['r'];
      if (s == null || s.isEmpty || r == null || r.isEmpty) return null;
      return SalonInviteCode(serverId: s, salonId: r, name: uri.queryParameters['n'] ?? 'Salon', emoji: uri.queryParameters['e'] ?? '🎮');
    } catch (_) {
      return null;
    }
  }
}
