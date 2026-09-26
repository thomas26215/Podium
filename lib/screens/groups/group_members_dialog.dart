import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/group.dart';
import '../../repositories/guests_repository.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';

/// A group's roster: who's in it and who owns it. The owner can remove a
/// member or hand ownership over (see [AppState.removeGroupMember] and
/// [AppState.transferGroupOwnership]); anyone else can leave (see
/// [AppState.leaveGroup]).
class GroupMembersDialog extends StatelessWidget {
  final String groupId;
  const GroupMembersDialog({super.key, required this.groupId});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final group = app.groupById(groupId);
    if (group == null) return const SizedBox.shrink();
    final me = app.currentUser?.uid;
    final isOwner = group.ownerId == me;
    // Owner first, then the caller, then everyone else in roster order.
    final memberIds = [...group.memberIds]..sort((a, b) => _rank(group, me, a).compareTo(_rank(group, me, b)));

    return Dialog(
      backgroundColor: AppColors.bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Membres', style: dispFont(size: 20, weight: FontWeight.w700, color: AppColors.ink)),
              const SizedBox(height: 4),
              Text('« ${group.name} » · ${memberIds.length} joueurs', style: bodyFont(size: 13, weight: FontWeight.w600, color: AppColors.mut)),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final uid in memberIds) _MemberTile(group: group, uid: uid, isMe: uid == me, canManage: isOwner && uid != me),
                    ],
                  ),
                ),
              ),
              if (app.flowError != null) ...[
                const SizedBox(height: 8),
                Text(app.flowError!, style: bodyFont(size: 13, weight: FontWeight.w600, color: AppColors.accent)),
              ],
              const SizedBox(height: 12),
              if (isOwner)
                Text(
                  'Pour quitter ce groupe, transférez d\'abord la propriété à un autre membre.',
                  style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: app.busy ? null : () => confirmLeaveGroup(context, app, group, closeDialog: true),
                    child: const Text('Quitter le groupe', style: TextStyle(color: Colors.red)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static int _rank(Group group, String? me, String uid) {
    if (uid == group.ownerId) return 0;
    if (uid == me) return 1;
    return 2;
  }
}

class _MemberTile extends StatelessWidget {
  final Group group;
  final String uid;
  final bool isMe;
  final bool canManage;
  const _MemberTile({required this.group, required this.uid, required this.isMe, required this.canManage});

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final p = app.playerById(uid);
    final name = p?.displayName ?? 'Joueur';
    final guest = isGuestId(uid);
    final badge = uid == group.ownerId ? 'PROPRIÉTAIRE' : (guest ? 'INVITÉ' : null);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line, width: 1.5), borderRadius: BorderRadius.circular(AppRadius.lg)),
        child: Row(
          children: [
            Avatar(initial: p?.initial ?? '?', color: p != null ? Color(p.color) : AppColors.mut, size: 32, fontSize: 13),
            const SizedBox(width: 10),
            Expanded(
              child: Text(isMe ? '$name (vous)' : name, overflow: TextOverflow.ellipsis, style: bodyFont(size: 14, weight: FontWeight.w700, color: AppColors.ink)),
            ),
            if (badge != null)
              Text(badge, style: bodyFont(size: 10, weight: FontWeight.w800, color: AppColors.mut, letterSpacing: 0.4)),
            if (canManage)
              PopupMenuButton<String>(
                tooltip: 'Gérer $name',
                icon: Icon(Icons.more_vert_rounded, size: 20, color: AppColors.mut),
                onSelected: (v) {
                  if (v == 'owner') _confirmTransfer(context, app, name);
                  if (v == 'remove') _confirmRemove(context, app, name);
                },
                itemBuilder: (_) => [
                  if (!guest) const PopupMenuItem(value: 'owner', child: Text('Rendre propriétaire')),
                  const PopupMenuItem(value: 'remove', child: Text('Retirer du groupe', style: TextStyle(color: Colors.red))),
                ],
              )
            else
              const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmTransfer(BuildContext context, AppState app, String name) async {
    final ok = await _confirm(
      context,
      title: 'Rendre $name propriétaire ?',
      body: 'Vous resterez membre du groupe, mais seul·e $name pourra le fermer, le supprimer, réassigner ou retirer des membres.',
      action: 'Transférer',
    );
    if (ok) await app.transferGroupOwnership(group, uid);
  }

  Future<void> _confirmRemove(BuildContext context, AppState app, String name) async {
    final ok = await _confirm(
      context,
      title: 'Retirer $name du groupe ?',
      body: 'Ses parties déjà jouées restent dans l\'historique. Vous pourrez l\'inviter à nouveau plus tard.',
      action: 'Retirer',
      destructive: true,
    );
    if (ok) await app.removeGroupMember(group, uid);
  }
}

/// Confirms then leaves `group` (see [AppState.leaveGroup]). With
/// [closeDialog], also closes the dialog `context` belongs to once done.
Future<void> confirmLeaveGroup(BuildContext context, AppState app, Group group, {bool closeDialog = false}) async {
  final ok = await _confirm(
    context,
    title: 'Quitter « ${group.name} » ?',
    body: 'Vos parties déjà jouées restent dans l\'historique du groupe. Il faudra une nouvelle invitation pour y revenir.',
    action: 'Quitter',
    destructive: true,
  );
  if (!ok) return;
  final left = await app.leaveGroup(group);
  if (left && closeDialog && context.mounted) Navigator.of(context).pop();
}

Future<bool> _confirm(BuildContext context, {required String title, required String body, required String action, bool destructive = false}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
      title: Text(title, style: dispFont(size: 18, weight: FontWeight.w700, color: AppColors.ink)),
      content: Text(body, style: bodyFont(size: 14, weight: FontWeight.w600, color: AppColors.mut)),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Annuler')),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(action, style: destructive ? const TextStyle(color: Colors.red) : null),
        ),
      ],
    ),
  );
  return confirmed == true;
}
