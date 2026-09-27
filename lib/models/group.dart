import 'package:cloud_firestore/cloud_firestore.dart';

/// A community of players — a friend group where everyone can edit the game
/// catalog and record/modify any match.
class Group {
  final String id;
  final String name;
  final String emoji;
  final int emojiBg;
  final List<String> memberIds;
  final String ownerId;

  /// The group has been wound down — its history/rankings stay fully
  /// visible, but nothing new can be recorded in it (new matches, invites,
  /// catalog changes…) until it's reopened. Never deletes anything, unlike
  /// [GroupsRepository.deleteGroup].
  final bool closed;
  final DateTime? closedAt;

  /// Set at creation, never changed afterwards: just the owner's stated
  /// intent for the group ("a one-off weekend with friends" vs. "our regular
  /// game night"), shown as a hint in the UI. Doesn't do anything on its
  /// own — [closed] is the field that actually freezes a group; a temporary
  /// group still has to be closed explicitly once it's over.
  final bool temporary;

  /// End of the current QR self-join window (see
  /// [GroupsRepository.refreshInviteWindow]): a scanned invite code can only
  /// be used to join while `DateTime.now()` is before this. `null` means no
  /// window has ever been opened for this group — self-join is then allowed
  /// unconditionally (back-compat for groups created before this field
  /// existed; see firestore.rules' `inviteWindowOpen`). Refreshed every time
  /// the invite dialog's QR tab is opened, so a screenshot/photo of an old
  /// code stops working once its window elapses instead of staying a
  /// forever-valid bearer token.
  final DateTime? inviteExpiresAt;

  /// The owner's private "Mon espace solo" (see `AppState.openPersonalSpace`)
  /// — one per account, never shared: it holds the matches played alone
  /// (a Mario Kart contre-la-montre…) with their own catalog, kept out of
  /// every list of groups ([AppState.groups] never contains it).
  final bool personal;

  const Group({
    required this.id,
    required this.name,
    required this.emoji,
    required this.emojiBg,
    required this.memberIds,
    required this.ownerId,
    this.closed = false,
    this.closedAt,
    this.temporary = false,
    this.inviteExpiresAt,
    this.personal = false,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'emoji': emoji,
        'emojiBg': emojiBg,
        'memberIds': memberIds,
        'ownerId': ownerId,
        'closed': closed,
        'temporary': temporary,
        if (personal) 'personal': true,
      };

  factory Group.fromDoc(String id, Map<String, dynamic> data) {
    return Group(
      id: id,
      name: (data['name'] as String?) ?? 'Groupe',
      emoji: (data['emoji'] as String?) ?? '🎲',
      emojiBg: (data['emojiBg'] as int?) ?? 0xFFE7EBFF,
      memberIds: List<String>.from((data['memberIds'] as List?) ?? const []),
      ownerId: (data['ownerId'] as String?) ?? '',
      closed: (data['closed'] as bool?) ?? false,
      closedAt: (data['closedAt'] as Timestamp?)?.toDate(),
      temporary: (data['temporary'] as bool?) ?? false,
      inviteExpiresAt: (data['inviteExpiresAt'] as Timestamp?)?.toDate(),
      personal: (data['personal'] as bool?) ?? false,
    );
  }

  Group copyWith({
    List<String>? memberIds,
    String? ownerId,
    bool? closed,
    DateTime? closedAt,
    DateTime? inviteExpiresAt,
  }) =>
      Group(
        id: id,
        name: name,
        emoji: emoji,
        emojiBg: emojiBg,
        memberIds: memberIds ?? this.memberIds,
        ownerId: ownerId ?? this.ownerId,
        closed: closed ?? this.closed,
        closedAt: closed == false ? null : (closedAt ?? this.closedAt),
        temporary: temporary,
        inviteExpiresAt: inviteExpiresAt ?? this.inviteExpiresAt,
        personal: personal,
      );
}
