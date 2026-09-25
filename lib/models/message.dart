import 'package:cloud_firestore/cloud_firestore.dart';

/// One message in a group's (or salon's) discussion thread — the
/// "Discussion" tab of `MainShell`, in place of the old games catalog.
class GroupMessage {
  final String id;
  final String authorId;
  final String text;
  final DateTime createdAt;

  /// Set only for a message posted in a Server's Salon (see
  /// `MessagesRepository.rootCollection`) — scopes it to that one salon,
  /// since every salon of a server shares the same `servers/{id}/messages`
  /// collection. Always null for a Group message, which needs no such
  /// scoping (a group has exactly one thread).
  final String? salonId;

  /// True for an auto-generated highlight ("Léa prend la tête du
  /// classement 👑") posted by the `onMatchCreated` Cloud Function
  /// (`authorId` is then the literal string `'system'`, never a real uid —
  /// firestore.rules blocks any client from claiming that authorId itself).
  /// Rendered as a centered pill instead of a normal chat bubble.
  final bool system;

  /// Non-empty for a "which game tonight?" poll (see
  /// `AppState.sendPoll`/`GroupChatScreen`) — the ids of the games offered
  /// as options. Empty for a plain text message.
  final List<String> pollGameIds;

  /// Poll ballots, uid -> the gameId they voted for — one vote per member,
  /// changing it just overwrites their own entry. Always empty outside a
  /// poll message (see [isPoll]).
  final Map<String, String> pollVotes;

  /// True once the author has edited this message's [text] in place — see
  /// `AppState.editMessage`. `createdAt` never changes on edit, so the
  /// message doesn't jump position in the thread.
  final bool edited;

  /// Set for a reply (see `AppState.sendMessage`'s `replyTo` and
  /// `GroupChatScreen`'s swipe-to-reply) — the id of the message being
  /// replied to, plus a snapshot of its author/text taken at reply time so
  /// the quote still renders even if the original was since edited or
  /// deleted. Null for a message that isn't a reply.
  final String? replyToId;
  final String? replyToAuthorId;
  final String? replyToText;

  /// Uids of every member `@mentioned` in [text] (see
  /// `AppState.sendMessage`'s mention parsing and `GroupChatScreen`'s "@"
  /// picker) — pushed a dedicated, louder notification even if they've muted
  /// the regular discussion channel (see functions/index.js's
  /// onMessageCreated).
  final List<String> mentionedUids;

  /// Reactions, uid -> the single emoji they picked (see
  /// `AppState.reactToMessage`) — one reaction per member per message;
  /// tapping the same emoji again clears it. Rendered as grouped, tappable
  /// pills under the bubble.
  final Map<String, String> reactions;

  const GroupMessage({
    required this.id,
    required this.authorId,
    required this.text,
    required this.createdAt,
    this.salonId,
    this.system = false,
    this.pollGameIds = const [],
    this.pollVotes = const {},
    this.edited = false,
    this.replyToId,
    this.replyToAuthorId,
    this.replyToText,
    this.mentionedUids = const [],
    this.reactions = const {},
  });

  bool get isPoll => pollGameIds.isNotEmpty;
  bool get isReply => replyToId != null;

  GroupMessage copyWith({String? text, Map<String, String>? pollVotes, bool? edited, Map<String, String>? reactions}) => GroupMessage(
        id: id,
        authorId: authorId,
        text: text ?? this.text,
        createdAt: createdAt,
        salonId: salonId,
        system: system,
        pollGameIds: pollGameIds,
        pollVotes: pollVotes ?? this.pollVotes,
        edited: edited ?? this.edited,
        replyToId: replyToId,
        replyToAuthorId: replyToAuthorId,
        replyToText: replyToText,
        mentionedUids: mentionedUids,
        reactions: reactions ?? this.reactions,
      );

  Map<String, dynamic> toMap() => {
        'authorId': authorId,
        'text': text,
        'createdAt': Timestamp.fromDate(createdAt),
        if (salonId != null) 'salonId': salonId,
        if (system) 'system': true,
        if (pollGameIds.isNotEmpty) 'pollGameIds': pollGameIds,
        if (pollVotes.isNotEmpty) 'pollVotes': pollVotes,
        if (edited) 'edited': true,
        if (replyToId != null) 'replyToId': replyToId,
        if (replyToAuthorId != null) 'replyToAuthorId': replyToAuthorId,
        if (replyToText != null) 'replyToText': replyToText,
        if (mentionedUids.isNotEmpty) 'mentionedUids': mentionedUids,
        if (reactions.isNotEmpty) 'reactions': reactions,
      };

  factory GroupMessage.fromDoc(String id, Map<String, dynamic> data) => GroupMessage(
        id: id,
        authorId: (data['authorId'] as String?) ?? '',
        text: (data['text'] as String?) ?? '',
        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        salonId: data['salonId'] as String?,
        system: (data['system'] as bool?) ?? false,
        pollGameIds: List<String>.from((data['pollGameIds'] as List?) ?? const []),
        pollVotes: Map<String, String>.from((data['pollVotes'] as Map?) ?? const {}),
        edited: (data['edited'] as bool?) ?? false,
        replyToId: data['replyToId'] as String?,
        replyToAuthorId: data['replyToAuthorId'] as String?,
        replyToText: data['replyToText'] as String?,
        mentionedUids: List<String>.from((data['mentionedUids'] as List?) ?? const []),
        reactions: Map<String, String>.from((data['reactions'] as Map?) ?? const {}),
      );
}
