import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/game_filter.dart';
import '../../models/app_user.dart';
import '../../models/game.dart';
import '../../models/message.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';
import '../../widgets/common.dart';
import '../../widgets/game_filter_bar.dart';
import '../new_game/game_actions_sheet.dart' show ChooserOption;
import '../new_game/new_game_sheet.dart';

/// The group's (or, in a Salon, the active salon's) discussion thread — the
/// "Discussion" tab of `MainShell`, replacing the old standalone games
/// catalog list. A game's own settings/rules/PDF export stay reachable via
/// the "+" new-game picker's long-press menu (see `game_actions_sheet.dart`).
///
/// Three kinds of message render here, alongside plain text: a `system`
/// highlight (auto-posted by the `onMatchCreated` Cloud Function — a streak,
/// or a new leaderboard leader) shown as a centered pill, and a poll (see
/// `GroupMessage.isPoll`) letting the group vote on what to play next, with
/// a one-tap shortcut straight into the new-game wizard for whichever
/// option wins. A plain text message can be swiped sideways by anyone to
/// reply to it, or long-pressed by its own author to edit/delete it.
class GroupChatScreen extends StatefulWidget {
  const GroupChatScreen({super.key});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

const _quickReactions = ['👍', '❤️', '😂', '😮', '😢', '🎉'];

class _GroupChatScreenState extends State<GroupChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _inputFocus = FocusNode();
  int _lastMessageCount = -1;
  final _seenMessageIds = <String>{};

  // At most one of these is set at a time — starting one clears the other
  // (see _startReply/_startEdit). Both are purely local UI state: neither
  // needs to survive a rebuild triggered by something else, so there's no
  // need to lift them into AppState the way the message list itself is.
  GroupMessage? _replyTo;
  GroupMessage? _editing;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  Widget _messageItem(AppState app, List<GroupMessage> messages, int i) {
    final m = messages[i];
    if (m.system) {
      return Padding(padding: const EdgeInsets.only(top: 12), child: _SystemPill(message: m));
    }
    if (m.isPoll) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: _PollBubble(poll: m, app: app, onLaunch: (gameId) => _launchGame(app, gameId)),
      );
    }
    final isMine = m.authorId == app.currentUser?.uid;
    final previous = i > 0 ? messages[i - 1] : null;
    final continuesPrevious = previous != null && !previous.system && !previous.isPoll && previous.authorId == m.authorId;
    return Padding(
      padding: EdgeInsets.only(top: continuesPrevious ? 3 : 12),
      child: Dismissible(
        key: ValueKey(m.id),
        direction: DismissDirection.startToEnd,
        confirmDismiss: (_) async => false,
        onUpdate: (details) {
          if (details.reached && !details.previousReached) _startReply(m);
        },
        background: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Icon(Icons.reply_rounded, color: AppColors.accent, size: 22),
          ),
        ),
        child: _MessageBubble(
          message: m,
          isMine: isMine,
          author: app.playerById(m.authorId),
          replyAuthor: m.replyToAuthorId == null ? null : app.playerById(m.replyToAuthorId!),
          showAuthor: !continuesPrevious && !isMine,
          currentUid: app.currentUser?.uid,
          mentionedNames: m.mentionedUids.map((uid) => app.playerById(uid)?.displayName).whereType<String>().toList(),
          onLongPress: () => _showMessageActions(app, m, isMine),
          onReact: (emoji) => app.reactToMessage(m, emoji),
        ),
      ),
    );
  }

  void _scrollToBottom({bool animated = false}) {
    if (!_scrollController.hasClients) return;
    final target = _scrollController.position.maxScrollExtent;
    if (animated) {
      _scrollController.animateTo(target, duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
    } else {
      _scrollController.jumpTo(target);
    }
  }

  void _startReply(GroupMessage message) {
    setState(() {
      _replyTo = message;
      _editing = null;
    });
    _inputFocus.requestFocus();
  }

  void _startEdit(GroupMessage message) {
    setState(() {
      _editing = message;
      _replyTo = null;
      _controller.text = message.text;
      _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
    });
    _inputFocus.requestFocus();
  }

  void _cancelComposeExtras() {
    setState(() {
      _replyTo = null;
      if (_editing != null) {
        _editing = null;
        _controller.clear();
      }
    });
  }

  Future<void> _send(AppState app) async {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    final editing = _editing;
    final replyTo = _replyTo;
    _controller.clear();
    setState(() {
      _editing = null;
      _replyTo = null;
    });
    if (editing != null) {
      await app.editMessage(editing, text);
    } else {
      await app.sendMessage(text, replyTo: replyTo);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom(animated: true));
    }
  }

  Future<void> _confirmDelete(AppState app, GroupMessage message) async {
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
        title: Text('Supprimer ce message ?', style: dispFont(size: 18, weight: FontWeight.w700, color: AppColors.ink)),
        content: Text('Cette action est définitive.', style: bodyFont(size: 14, weight: FontWeight.w600, color: AppColors.mut)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Supprimer', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) await app.deleteMessage(message);
  }

  /// Long-press menu on any message: a quick-pick reaction row (see
  /// `AppState.reactToMessage`), plus, for the author's own message,
  /// edit/delete — the swipe gesture alone covers replying, open to anyone.
  Future<void> _showMessageActions(AppState app, GroupMessage message, bool isMine) async {
    final myUid = app.currentUser?.uid;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Réagir', style: bodyFont(size: 12.5, weight: FontWeight.w800, color: AppColors.ink2)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final emoji in _quickReactions)
                  Pressable(
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      app.reactToMessage(message, emoji);
                    },
                    child: Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: message.reactions[myUid] == emoji ? AppColors.accentSoft : AppColors.card,
                        shape: BoxShape.circle,
                        border: Border.all(color: message.reactions[myUid] == emoji ? AppColors.accent : AppColors.line, width: 1.5),
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 20)),
                    ),
                  ),
              ],
            ),
            if (isMine) ...[
              const SizedBox(height: 18),
              ChooserOption(
                icon: Icons.edit_rounded,
                title: 'Modifier',
                subtitle: 'Corriger le texte de ce message.',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _startEdit(message);
                },
              ),
              const SizedBox(height: 10),
              ChooserOption(
                icon: Icons.delete_outline_rounded,
                title: 'Supprimer',
                subtitle: 'Cette action est définitive.',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _confirmDelete(app, message);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _launchGame(AppState app, String gameId) {
    app.startMatchForGame(gameId);
    showNewGameSheet(context, app);
  }

  void _insertAtCursor(String insertion) {
    final text = _controller.text;
    final selection = _controller.selection;
    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;
    _controller.text = text.replaceRange(start, end, insertion);
    _controller.selection = TextSelection.collapsed(offset: start + insertion.length);
    _inputFocus.requestFocus();
  }

  /// "@" picker — inserts `@DisplayName ` at the cursor; [AppState.sendMessage]
  /// recognizes it against [AppState.discussionMembers] when the message is
  /// actually sent (see [GroupMessage.mentionedUids]).
  Future<void> _showMentionPicker(AppState app) async {
    final members = app.discussionMembers.where((m) => m.uid != app.currentUser?.uid).toList();
    if (members.isEmpty) {
      app.showToast('Aucun autre membre à mentionner.', error: true);
      return;
    }
    final picked = await showModalBottomSheet<AppUser>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mentionner', style: dispFont(size: 18, weight: FontWeight.w700, color: AppColors.ink)),
            const SizedBox(height: 16),
            for (final m in members)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Pressable(
                  onTap: () => Navigator.of(sheetContext).pop(m),
                  child: Row(
                    children: [
                      Avatar(initial: m.initial, color: Color(m.color), size: 34, fontSize: 13),
                      const SizedBox(width: 12),
                      Text(m.displayName, style: bodyFont(size: 15, weight: FontWeight.w700, color: AppColors.ink)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (picked != null) _insertAtCursor('@${picked.displayName} ');
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final messages = app.messages;

    // Auto-scroll to the newest message once it's actually laid out — but
    // only when the list actually grew (a delete, or just switching tabs and
    // rebuilding, shouldn't yank the scroll position back to the bottom).
    final grew = _lastMessageCount != -1 && messages.length > _lastMessageCount;
    _lastMessageCount = messages.length;
    if (grew) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom(animated: true));
    }

    final title = app.activeContext == ActiveContextKind.salon ? app.currentSalon?.name : app.currentGroup?.name;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenHeading(eyebrow: 'Discussion', title: title ?? 'Discussion'),
          Expanded(
            child: messages.isEmpty && !app.messagesLoaded
                ? const Center(child: PodiumLoader())
                : messages.isEmpty
                ? Center(child: EmptyState(emoji: '💬', message: "Aucun message pour l'instant — lancez la discussion !"))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(bottom: 8),
                    itemCount: messages.length,
                    itemBuilder: (context, i) {
                      final m = messages[i];
                      // Only messages arriving live (sent or received while
                      // the chat is open) pop in — not the backlog, nor rows
                      // rebuilt as the list scrolls back over them.
                      final fresh = _seenMessageIds.add(m.id) && DateTime.now().difference(m.createdAt) < const Duration(seconds: 20);
                      return _MessageAppear(
                        key: ValueKey('appear-${m.id}'),
                        animate: fresh,
                        fromRight: !m.system && !m.isPoll && m.authorId == app.currentUser?.uid,
                        child: _messageItem(app, messages, i),
                      );
                    },
                  ),
          ),
          if (_replyTo != null || _editing != null)
            _ComposeExtraBanner(
              editing: _editing != null,
              author: _editing != null ? null : (app.playerById(_replyTo!.authorId)?.displayName ?? 'Joueur'),
              text: (_editing ?? _replyTo)!.text,
              onCancel: _cancelComposeExtras,
            ),
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Pressable(
                  onTap: () => showPollSheet(context, app),
                  child: Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line, width: 1.5), borderRadius: BorderRadius.circular(AppRadius.md)),
                    child: Icon(Icons.how_to_vote_rounded, color: AppColors.ink2, size: 22),
                  ),
                ),
                const SizedBox(width: 8),
                Pressable(
                  onTap: () => _showMentionPicker(app),
                  child: Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line, width: 1.5), borderRadius: BorderRadius.circular(AppRadius.md)),
                    child: Icon(Icons.alternate_email_rounded, color: AppColors.ink2, size: 22),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _inputFocus,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    style: bodyFont(size: 15, weight: FontWeight.w600, color: AppColors.ink),
                    decoration: appFieldDecoration(hintText: 'Écrire un message…', contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                    onSubmitted: (_) => _send(app),
                  ),
                ),
                const SizedBox(width: 10),
                Pressable(
                  onTap: () => _send(app),
                  child: Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(AppRadius.md)),
                    child: Icon(_editing != null ? Icons.check_rounded : Icons.arrow_upward_rounded, color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The strip above the input row while composing a reply or an edit —
/// "Réponse à Léa" / "Modifier le message" plus a snippet of the target
/// message, with a close button to back out.
class _ComposeExtraBanner extends StatelessWidget {
  final bool editing;
  final String? author;
  final String text;
  final VoidCallback onCancel;
  const _ComposeExtraBanner({required this.editing, required this.author, required this.text, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Row(
        children: [
          Icon(editing ? Icons.edit_rounded : Icons.reply_rounded, size: 16, color: AppColors.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(editing ? 'Modifier le message' : 'Réponse à $author', style: bodyFont(size: 12, weight: FontWeight.w800, color: AppColors.accent)),
                Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyFont(size: 12.5, weight: FontWeight.w600, color: AppColors.ink2)),
              ],
            ),
          ),
          Pressable(onTap: onCancel, child: Icon(Icons.close_rounded, size: 18, color: AppColors.mut)),
        ],
      ),
    );
  }
}

/// A centered, muted pill for an auto-generated highlight (`m.system` —
/// posted by the `onMatchCreated` Cloud Function) — visually distinct from a
/// normal chat bubble, no author/avatar/delete since nobody actually wrote it.
class _SystemPill extends StatelessWidget {
  final GroupMessage message;
  const _SystemPill({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(999)),
        child: Text(
          message.text,
          textAlign: TextAlign.center,
          style: bodyFont(size: 12.5, weight: FontWeight.w700, color: AppColors.ink2),
        ),
      ),
    );
  }
}

/// Splits `text` into spans, styling every `@Name` that matches one of
/// `mentionedNames` (already resolved by the caller — see
/// `GroupMessage.mentionedUids`) differently from the rest. Longest names
/// first so e.g. "@Jean" can't shadow "@Jean Paul" mid-match.
List<InlineSpan> _renderMentionSpans(String text, List<String> mentionedNames, TextStyle base, TextStyle highlight) {
  if (mentionedNames.isEmpty) return [TextSpan(text: text, style: base)];
  final names = mentionedNames.toSet().toList()..sort((a, b) => b.length.compareTo(a.length));
  final pattern = RegExp(names.map((n) => '@${RegExp.escape(n)}').join('|'));
  final spans = <InlineSpan>[];
  var last = 0;
  for (final match in pattern.allMatches(text)) {
    if (match.start > last) spans.add(TextSpan(text: text.substring(last, match.start), style: base));
    spans.add(TextSpan(text: match.group(0), style: highlight));
    last = match.end;
  }
  if (last < text.length) spans.add(TextSpan(text: text.substring(last), style: base));
  return spans;
}

class _MessageBubble extends StatelessWidget {
  final GroupMessage message;
  final bool isMine;
  final AppUser? author;
  final AppUser? replyAuthor;
  final bool showAuthor;
  final String? currentUid;
  final List<String> mentionedNames;
  final VoidCallback? onLongPress;
  final ValueChanged<String>? onReact;

  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.author,
    this.replyAuthor,
    required this.showAuthor,
    this.currentUid,
    this.mentionedNames = const [],
    this.onLongPress,
    this.onReact,
  });

  String _time(DateTime dt) => '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  Map<String, int> get _reactionCounts {
    final counts = <String, int>{};
    for (final emoji in message.reactions.values) {
      counts[emoji] = (counts[emoji] ?? 0) + 1;
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    final quoteColor = isMine ? Colors.white : AppColors.ink;
    final textStyle = bodyFont(size: 14.5, weight: FontWeight.w600, color: isMine ? Colors.white : AppColors.ink);
    final mentionStyle = textStyle.copyWith(fontWeight: FontWeight.w800, color: isMine ? Colors.white : AppColors.accent, backgroundColor: (isMine ? Colors.white : AppColors.accent).withValues(alpha: 0.16));
    final bubble = Pressable(
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMine ? AppColors.accent : AppColors.card,
          border: isMine ? null : Border.all(color: AppColors.line, width: 1.5),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMine ? 16 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showAuthor)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(author?.displayName ?? 'Joueur', style: bodyFont(size: 12, weight: FontWeight.w800, color: AppColors.accent)),
              ),
            if (message.isReply)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: (isMine ? Colors.white : AppColors.accent).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                  border: Border(left: BorderSide(color: quoteColor.withValues(alpha: 0.6), width: 2.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(replyAuthor?.displayName ?? 'Joueur', style: bodyFont(size: 11.5, weight: FontWeight.w800, color: quoteColor)),
                    Text(
                      message.replyToText ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: bodyFont(size: 12.5, weight: FontWeight.w600, color: quoteColor.withValues(alpha: 0.85)),
                    ),
                  ],
                ),
              ),
            Text.rich(TextSpan(children: _renderMentionSpans(message.text, mentionedNames, textStyle, mentionStyle))),
            const SizedBox(height: 2),
            Text(
              message.edited ? '${_time(message.createdAt)} · modifié' : _time(message.createdAt),
              style: bodyFont(size: 10.5, weight: FontWeight.w600, color: isMine ? Colors.white.withValues(alpha: 0.75) : AppColors.mut),
            ),
          ],
        ),
      ),
    );

    final reactions = _reactionCounts;
    final reactionRow = reactions.isEmpty
        ? null
        : Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              spacing: 5,
              children: [
                for (final entry in reactions.entries)
                  Pressable(
                    onTap: onReact == null ? null : () => onReact!(entry.key),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: message.reactions[currentUid] == entry.key ? AppColors.accentSoft : AppColors.card,
                        border: Border.all(color: message.reactions[currentUid] == entry.key ? AppColors.accent : AppColors.line, width: 1.2),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text('${entry.key} ${entry.value}', style: bodyFont(size: 11.5, weight: FontWeight.w700, color: AppColors.ink2)),
                    ),
                  ),
              ],
            ),
          );

    if (isMine) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [Flexible(child: bubble)]),
          ?reactionRow,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Avatar(initial: author?.initial ?? '?', color: Color(author?.color ?? 0xFF8C8A93), size: 30, fontSize: 12),
            const SizedBox(width: 8),
            Flexible(child: bubble),
          ],
        ),
        if (reactionRow != null) Padding(padding: const EdgeInsets.only(left: 38), child: reactionRow),
      ],
    );
  }
}

/// A "which game tonight?" poll — every option is a game from the catalog,
/// each row a vote-share bar the current user can tap to cast/change their
/// ballot, with a play button to jump straight into the new-game wizard for
/// that game (see `AppState.startMatchForGame`).
class _PollBubble extends StatelessWidget {
  final GroupMessage poll;
  final AppState app;
  final ValueChanged<String> onLaunch;
  const _PollBubble({required this.poll, required this.app, required this.onLaunch});

  @override
  Widget build(BuildContext context) {
    final myUid = app.currentUser?.uid;
    final myVote = myUid == null ? null : poll.pollVotes[myUid];
    final totalVotes = poll.pollVotes.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line, width: 1.5), borderRadius: BorderRadius.circular(AppRadius.xl)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.how_to_vote_rounded, size: 17, color: AppColors.accent),
              const SizedBox(width: 7),
              Expanded(child: Text(poll.text, style: bodyFont(size: 14.5, weight: FontWeight.w800, color: AppColors.ink))),
            ],
          ),
          const SizedBox(height: 12),
          for (final gameId in poll.pollGameIds) ...[
            _PollOption(
              game: app.gameById(gameId),
              votes: poll.pollVotes.values.where((v) => v == gameId).length,
              totalVotes: totalVotes,
              selected: myVote == gameId,
              onTap: () => app.voteInPoll(poll, gameId),
              onLaunch: () => onLaunch(gameId),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _PollOption extends StatelessWidget {
  final Game? game;
  final int votes;
  final int totalVotes;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLaunch;
  const _PollOption({required this.game, required this.votes, required this.totalVotes, required this.selected, required this.onTap, required this.onLaunch});

  @override
  Widget build(BuildContext context) {
    final g = game;
    if (g == null) return const SizedBox.shrink();
    final share = totalVotes > 0 ? votes / totalVotes : 0.0;
    return Pressable(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.bg,
              border: Border.all(color: selected ? AppColors.accent : AppColors.line, width: 1.5),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                if (share > 0)
                  FractionallySizedBox(
                    widthFactor: share,
                    child: Container(height: 44, color: AppColors.accentSoft),
                  ),
                SizedBox(
                  height: 44,
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      Text(g.emoji, style: const TextStyle(fontSize: 17)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(g.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyFont(size: 14, weight: FontWeight.w700, color: AppColors.ink)),
                      ),
                      Text('$votes', style: bodyFont(size: 12.5, weight: FontWeight.w800, color: AppColors.mut)),
                      IconButton(
                        icon: Icon(Icons.play_circle_fill_rounded, color: AppColors.accent, size: 26),
                        tooltip: 'Lancer cette partie',
                        onPressed: onLaunch,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens the poll-creation sheet — pick 2+ games from the catalog, optionally
/// a custom question, then posts it via [AppState.sendPoll].
Future<void> showPollSheet(BuildContext context, AppState app) async {
  if (app.games.length < 2) {
    app.showToast('Il faut au moins 2 jeux dans le catalogue pour lancer un sondage.');
    return;
  }
  final questionController = TextEditingController();
  final selected = <String>{};
  // Narrows the games offered — "we're 5 tonight", "something in duel" — and
  // only ever offers games that pass it, so a filtered-out game can't stay
  // silently selected.
  var filter = const GameFilter();
  final filterable = hasFilterableData(app.games);
  await showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setState) => Container(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(sheetContext).viewInsets.bottom + 28),
        decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quel jeu ce soir ?', style: dispFont(size: 18, weight: FontWeight.w700, color: AppColors.ink)),
            const SizedBox(height: 4),
            Text('Choisissez au moins 2 jeux — le groupe vote, vous lancez la partie gagnante.', style: bodyFont(size: 12.5, weight: FontWeight.w600, color: AppColors.mut)),
            const SizedBox(height: 14),
            TextField(
              controller: questionController,
              style: bodyFont(size: 14.5, weight: FontWeight.w700, color: AppColors.ink),
              decoration: appFieldDecoration(hintText: 'Quel jeu ce soir ? (optionnel)', contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
            ),
            const SizedBox(height: 14),
            if (filterable) ...[
              GameFilterBar(
                games: app.games,
                filter: filter,
                shownCount: filter.apply(app.games).length,
                onChanged: (f) => setState(() {
                  filter = f;
                  selected.removeWhere((id) {
                    final game = app.gameById(id);
                    return game == null || !f.matches(game);
                  });
                }),
              ),
              const SizedBox(height: 14),
            ],
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final g in filter.apply(app.games))
                      Pressable(
                        onTap: () => setState(() => selected.contains(g.id) ? selected.remove(g.id) : selected.add(g.id)),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                          decoration: BoxDecoration(
                            color: selected.contains(g.id) ? AppColors.accentSoft : AppColors.card,
                            border: Border.all(color: selected.contains(g.id) ? AppColors.accent : AppColors.line, width: 1.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(g.emoji, style: const TextStyle(fontSize: 15)),
                              const SizedBox(width: 6),
                              Text(g.name, style: bodyFont(size: 13.5, weight: FontWeight.w700, color: AppColors.ink)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            PrimaryButton(
              label: 'Lancer le sondage',
              onPressed: selected.length < 2
                  ? null
                  : () {
                      Navigator.of(sheetContext).pop();
                      app.sendPoll(questionController.text, selected.toList());
                    },
            ),
          ],
        ),
      ),
    ),
  );
}

/// Pops a just-arrived message in from its own side (yours from the right,
/// others' from the left) — a no-op wrapper for messages already on screen
/// before, so rebuilding the list never replays it.
class _MessageAppear extends StatefulWidget {
  final bool animate;
  final bool fromRight;
  final Widget child;
  const _MessageAppear({super.key, required this.animate, required this.fromRight, required this.child});

  @override
  State<_MessageAppear> createState() => _MessageAppearState();
}

class _MessageAppearState extends State<_MessageAppear> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 380), value: widget.animate ? 0 : 1);
  late final Animation<double> _curve = CurvedAnimation(parent: _c, curve: Curves.easeOutBack);

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Opacity(
        opacity: _c.value,
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - _curve.value)),
          child: Transform.scale(
            scale: 0.85 + 0.15 * _curve.value,
            alignment: widget.fromRight ? Alignment.bottomRight : Alignment.bottomLeft,
            child: child,
          ),
        ),
      ),
      child: widget.child,
    );
  }
}
