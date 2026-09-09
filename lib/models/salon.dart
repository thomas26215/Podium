import 'package:cloud_firestore/cloud_firestore.dart';

/// A room within a [Server] (e.g. "Tournoi TCG du jeudi") — a two-level
/// membership under the server: joining the server doesn't automatically
/// grant access to every salon, each is joined separately. Matches recorded
/// here stay pending until every human player involved confirms them (see
/// GameMatch.status).
class Salon {
  final String id;
  final String serverId;
  final String name;
  final String emoji;
  final int emojiBg;
  final List<String> memberIds;
  final bool closed;
  final DateTime? closedAt;
  final DateTime? inviteExpiresAt;

  const Salon({
    required this.id,
    required this.serverId,
    required this.name,
    required this.emoji,
    required this.emojiBg,
    required this.memberIds,
    this.closed = false,
    this.closedAt,
    this.inviteExpiresAt,
  });

  Map<String, dynamic> toMap() => {
        'serverId': serverId,
        'name': name,
        'emoji': emoji,
        'emojiBg': emojiBg,
        'memberIds': memberIds,
        'closed': closed,
      };

  factory Salon.fromDoc(String id, Map<String, dynamic> data) {
    return Salon(
      id: id,
      serverId: (data['serverId'] as String?) ?? '',
      name: (data['name'] as String?) ?? 'Salon',
      emoji: (data['emoji'] as String?) ?? '🎮',
      emojiBg: (data['emojiBg'] as int?) ?? 0xFFE7EBFF,
      memberIds: List<String>.from((data['memberIds'] as List?) ?? const []),
      closed: (data['closed'] as bool?) ?? false,
      closedAt: (data['closedAt'] as Timestamp?)?.toDate(),
      inviteExpiresAt: (data['inviteExpiresAt'] as Timestamp?)?.toDate(),
    );
  }

  Salon copyWith({
    List<String>? memberIds,
    bool? closed,
    DateTime? closedAt,
    DateTime? inviteExpiresAt,
  }) =>
      Salon(
        id: id,
        serverId: serverId,
        name: name,
        emoji: emoji,
        emojiBg: emojiBg,
        memberIds: memberIds ?? this.memberIds,
        closed: closed ?? this.closed,
        closedAt: closed == false ? null : (closedAt ?? this.closedAt),
        inviteExpiresAt: inviteExpiresAt ?? this.inviteExpiresAt,
      );
}
