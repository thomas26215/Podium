import 'package:cloud_firestore/cloud_firestore.dart';

/// A rigid community (e.g. a game café) — unlike [Group], only the owner and
/// its admins can manage the game catalog and create/delete salons. Regular
/// members just join salons and play.
class Server {
  final String id;
  final String name;
  final String emoji;
  final int emojiBg;
  final String ownerId;
  final List<String> adminIds;
  final List<String> memberIds;
  final bool closed;
  final DateTime? closedAt;
  final DateTime? inviteExpiresAt;

  const Server({
    required this.id,
    required this.name,
    required this.emoji,
    required this.emojiBg,
    required this.ownerId,
    required this.adminIds,
    required this.memberIds,
    this.closed = false,
    this.closedAt,
    this.inviteExpiresAt,
  });

  bool isAdmin(String uid) => uid == ownerId || adminIds.contains(uid);

  Map<String, dynamic> toMap() => {
        'name': name,
        'emoji': emoji,
        'emojiBg': emojiBg,
        'ownerId': ownerId,
        'adminIds': adminIds,
        'memberIds': memberIds,
        'closed': closed,
      };

  factory Server.fromDoc(String id, Map<String, dynamic> data) {
    return Server(
      id: id,
      name: (data['name'] as String?) ?? 'Serveur',
      emoji: (data['emoji'] as String?) ?? '🏠',
      emojiBg: (data['emojiBg'] as int?) ?? 0xFFE7EBFF,
      ownerId: (data['ownerId'] as String?) ?? '',
      adminIds: List<String>.from((data['adminIds'] as List?) ?? const []),
      memberIds: List<String>.from((data['memberIds'] as List?) ?? const []),
      closed: (data['closed'] as bool?) ?? false,
      closedAt: (data['closedAt'] as Timestamp?)?.toDate(),
      inviteExpiresAt: (data['inviteExpiresAt'] as Timestamp?)?.toDate(),
    );
  }

  Server copyWith({
    List<String>? adminIds,
    List<String>? memberIds,
    bool? closed,
    DateTime? closedAt,
    DateTime? inviteExpiresAt,
  }) =>
      Server(
        id: id,
        name: name,
        emoji: emoji,
        emojiBg: emojiBg,
        ownerId: ownerId,
        adminIds: adminIds ?? this.adminIds,
        memberIds: memberIds ?? this.memberIds,
        closed: closed ?? this.closed,
        closedAt: closed == false ? null : (closedAt ?? this.closedAt),
        inviteExpiresAt: inviteExpiresAt ?? this.inviteExpiresAt,
      );
}
