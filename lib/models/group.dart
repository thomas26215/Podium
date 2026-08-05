import 'package:cloud_firestore/cloud_firestore.dart';

/// A community of players. Root groups have `parentId == null`; a subgroup
/// points at its parent and its `memberIds` are only the *additional*
/// players it brings in — the parent's roster is layered underneath (see
/// AppState.getGroupMemberIds).
///
/// `allMemberIds` is maintained on ROOT groups only: it's the union of the
/// root's own members plus every member of every subgroup underneath it,
/// kept in sync whenever a subgroup is created or someone is invited
/// anywhere in the tree. It exists purely so Firestore security rules can
/// decide "can this uid see the root doc?" with a single field check
/// instead of walking every subgroup.
class Group {
  final String id;
  final String name;
  final String emoji;
  final int emojiBg;
  final String? parentId;
  final List<String> memberIds;
  final List<String> subGroupIds;
  final List<String> allMemberIds;
  final String ownerId;

  /// Meaningful on ROOT groups only (see [AppState.isGroupClosed], which
  /// resolves a subgroup's closed status through its root): the group has
  /// been wound down — its history/rankings stay fully visible, but nothing
  /// new can be recorded in it (new matches, invites, catalog changes…)
  /// until it's reopened. Never deletes anything, unlike
  /// [GroupsRepository.deleteGroup].
  final bool closed;
  final DateTime? closedAt;

  /// Set at creation (root groups only — see [temporary] doc below), never
  /// changed afterwards: just the owner's stated intent for the group ("a
  /// one-off weekend with friends" vs. "our regular game night"), shown as a
  /// hint in the UI. Doesn't do anything on its own — [closed] is the field
  /// that actually freezes a group; a temporary group still has to be
  /// closed explicitly once it's over.
  final bool temporary;

  const Group({
    required this.id,
    required this.name,
    required this.emoji,
    required this.emojiBg,
    required this.parentId,
    required this.memberIds,
    required this.subGroupIds,
    required this.allMemberIds,
    required this.ownerId,
    this.closed = false,
    this.closedAt,
    this.temporary = false,
  });

  bool get isRoot => parentId == null;

  Map<String, dynamic> toMap() => {
        'name': name,
        'emoji': emoji,
        'emojiBg': emojiBg,
        'parentId': parentId,
        'memberIds': memberIds,
        'subGroupIds': subGroupIds,
        'allMemberIds': allMemberIds,
        'ownerId': ownerId,
        'closed': closed,
        'temporary': temporary,
      };

  factory Group.fromDoc(String id, Map<String, dynamic> data) {
    return Group(
      id: id,
      name: (data['name'] as String?) ?? 'Groupe',
      emoji: (data['emoji'] as String?) ?? '🎲',
      emojiBg: (data['emojiBg'] as int?) ?? 0xFFE7EBFF,
      parentId: data['parentId'] as String?,
      memberIds: List<String>.from((data['memberIds'] as List?) ?? const []),
      subGroupIds: List<String>.from((data['subGroupIds'] as List?) ?? const []),
      allMemberIds: List<String>.from((data['allMemberIds'] as List?) ?? const []),
      ownerId: (data['ownerId'] as String?) ?? '',
      closed: (data['closed'] as bool?) ?? false,
      closedAt: (data['closedAt'] as Timestamp?)?.toDate(),
      temporary: (data['temporary'] as bool?) ?? false,
    );
  }

  Group copyWith({List<String>? memberIds, List<String>? subGroupIds, List<String>? allMemberIds, bool? closed, DateTime? closedAt}) => Group(
        id: id,
        name: name,
        emoji: emoji,
        emojiBg: emojiBg,
        parentId: parentId,
        memberIds: memberIds ?? this.memberIds,
        subGroupIds: subGroupIds ?? this.subGroupIds,
        allMemberIds: allMemberIds ?? this.allMemberIds,
        ownerId: ownerId,
        closed: closed ?? this.closed,
        closedAt: closed == false ? null : (closedAt ?? this.closedAt),
        temporary: temporary,
      );
}
