import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/group.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'group_form_dialog.dart';
import 'invite_dialog.dart';
import 'qr_scan_screen.dart';
import 'reassign_member_dialog.dart';

/// Selects `groupId` as the active group and, if this screen was pushed on
/// top of the home tab (its normal use now that Groups isn't a bottom-nav
/// tab), pops back so the switch is immediately visible.
void _selectAndClose(BuildContext context, AppState app, String groupId) {
  app.selectGroup(groupId);
  if (Navigator.of(context).canPop()) Navigator.of(context).pop();
}

/// Standalone page wrapper for [GroupsScreen], used when navigating to it
/// via [Navigator.push] (it's no longer a bottom-nav tab).
class GroupsPage extends StatefulWidget {
  const GroupsPage({super.key});

  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage> {
  @override
  void initState() {
    super.initState();
    // Every group's own "X parties" tally is fetched fresh on entry rather
    // than kept live — a match recorded elsewhere since the last time this
    // screen was open would otherwise show a stale count (see
    // AppState.refreshGroupPartyCounts).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppState>().refreshGroupPartyCounts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.ink),
      ),
      body: const SafeArea(child: GroupsScreen()),
    );
  }
}

class GroupsScreen extends StatelessWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final roots = app.groups.where((g) => g.isRoot).toList();
    // Closed groups stay reachable (history, reopening…) but shouldn't sit
    // mixed in with the ones you're actively playing in — a separate,
    // clearly-labelled section underneath instead.
    final activeRoots = roots.where((g) => !g.closed).toList();
    final closedRoots = roots.where((g) => g.closed).toList();

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ScreenHeading(eyebrow: 'Vos communautés', title: 'Mes groupes'),
                if (app.groupsLoading)
                  Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: CircularProgressIndicator(color: AppColors.accent)))
                else if (roots.isEmpty)
                  const EmptyState(emoji: '👥', message: 'Créez votre premier groupe pour commencer.')
                else ...[
                  for (final (i, g) in activeRoots.indexed) FadeSlideIn(delay: Duration(milliseconds: i * 60), child: _RootGroupCard(group: g)),
                  if (closedRoots.isNotEmpty) ...[
                    if (activeRoots.isNotEmpty) const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 2, bottom: 10),
                      child: Text('GROUPES CLOS', style: bodyFont(size: 11.5, weight: FontWeight.w800, color: AppColors.mut, letterSpacing: 0.5)),
                    ),
                    for (final g in closedRoots) _RootGroupCard(group: g),
                  ],
                ],
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.line)), color: AppColors.bg),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => showDialog(context: context, builder: (_) => ChangeNotifierProvider.value(value: app, child: const GroupFormDialog())),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(border: Border.all(color: AppColors.line, width: 2), borderRadius: BorderRadius.circular(AppRadius.lg)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add, size: 20, color: AppColors.ink2),
                        const SizedBox(width: 8),
                        Flexible(child: Text('Créer un groupe', overflow: TextOverflow.ellipsis, style: bodyFont(size: 14, weight: FontWeight.w700, color: AppColors.ink2))),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const QrScanScreen())),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(border: Border.all(color: AppColors.line, width: 2), borderRadius: BorderRadius.circular(AppRadius.lg)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code_scanner_rounded, size: 20, color: AppColors.ink2),
                        const SizedBox(width: 8),
                        Flexible(child: Text('Rejoindre', overflow: TextOverflow.ellipsis, style: bodyFont(size: 14, weight: FontWeight.w700, color: AppColors.ink2))),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RootGroupCard extends StatelessWidget {
  final Group group;
  const _RootGroupCard({required this.group});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final members = app.getGroupMemberIds(group.id).length;
    final parties = app.groupPartyCount(group.id);
    final subs = group.subGroupIds.map(app.groupById).whereType<Group>().toList();
    final hasSubs = subs.isNotEmpty;
    final expanded = app.expandedGroups.contains(group.id);
    final closed = group.closed;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line, width: 1.5), borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectAndClose(context, app, group.id),
                    child: Row(
                      children: [
                        Opacity(
                          opacity: closed ? 0.5 : 1,
                          child: Container(
                            width: 48,
                            height: 48,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: Color(group.emojiBg), borderRadius: BorderRadius.circular(14)),
                            child: Text(group.emoji, style: const TextStyle(fontSize: 24)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(child: Text(group.name, overflow: TextOverflow.ellipsis, style: bodyFont(size: 16, weight: FontWeight.w800, color: AppColors.ink))),
                                  if (closed) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(color: AppColors.bg, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(6)),
                                      child: Text('CLOS', style: bodyFont(size: 10, weight: FontWeight.w800, color: AppColors.mut, letterSpacing: 0.4)),
                                    ),
                                  ] else if (group.temporary) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(color: AppColors.accentSoft, border: Border.all(color: AppColors.accent), borderRadius: BorderRadius.circular(6)),
                                      child: Text('TEMPORAIRE', style: bodyFont(size: 10, weight: FontWeight.w800, color: AppColors.accent, letterSpacing: 0.4)),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text('$members joueurs · $parties parties', style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_horiz, color: AppColors.mut),
                  onSelected: (v) {
                    if (v == 'invite') {
                      showDialog(context: context, builder: (_) => ChangeNotifierProvider.value(value: app, child: InviteDialog(groupId: group.id, groupName: group.name)));
                    } else if (v == 'sub') {
                      showDialog(context: context, builder: (_) => ChangeNotifierProvider.value(value: app, child: GroupFormDialog(parentId: group.id)));
                    } else if (v == 'reassign') {
                      showDialog(context: context, builder: (_) => ChangeNotifierProvider.value(value: app, child: ReassignMemberDialog(rootGroupId: group.id, rootGroupName: group.name)));
                    } else if (v == 'close') {
                      confirmCloseGroup(context, app, group, closed: true);
                    } else if (v == 'reopen') {
                      app.setGroupClosed(group.id, false);
                    } else if (v == 'delete') {
                      confirmDeleteGroup(context, app, group);
                    }
                  },
                  itemBuilder: (_) => [
                    if (!closed) ...[
                      const PopupMenuItem(value: 'invite', child: Text('Inviter un ami')),
                      const PopupMenuItem(value: 'sub', child: Text('Ajouter un sous-groupe')),
                    ],
                    if (app.canDeleteGroup(group) && !closed) const PopupMenuItem(value: 'reassign', child: Text('Réassigner un membre')),
                    if (app.canCloseGroup(group))
                      PopupMenuItem(value: closed ? 'reopen' : 'close', child: Text(closed ? 'Rouvrir le groupe' : 'Fermer le groupe')),
                    if (app.canDeleteGroup(group))
                      const PopupMenuItem(value: 'delete', child: Text('Supprimer le groupe', style: TextStyle(color: Colors.red))),
                  ],
                ),
                if (hasSubs)
                  IconButton(
                    onPressed: () => app.toggleGroupExpand(group.id),
                    icon: AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(Icons.keyboard_arrow_down, color: AppColors.mut),
                    ),
                  ),
              ],
            ),
          ),
          if (expanded && hasSubs)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.line))),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  for (final sg in subs) _SubGroupRow(group: sg),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SubGroupRow extends StatelessWidget {
  final Group group;
  const _SubGroupRow({required this.group});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final members = app.getGroupMemberIds(group.id).length;
    final parties = app.groupPartyCount(group.id);
    final closed = app.isGroupClosed(group);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _selectAndClose(context, app, group.id),
        onLongPress: closed
            ? null
            : () => showDialog(context: context, builder: (_) => ChangeNotifierProvider.value(value: app, child: InviteDialog(groupId: group.id, groupName: group.name))),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Color(group.emojiBg), borderRadius: BorderRadius.circular(10)),
                child: Text(group.emoji, style: const TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(group.name, style: bodyFont(size: 14, weight: FontWeight.w700, color: AppColors.ink)),
                    Text('$members joueurs · $parties parties', style: bodyFont(size: 11, weight: FontWeight.w600, color: AppColors.mut)),
                  ],
                ),
              ),
              if (app.canDeleteGroup(group))
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_horiz, size: 20, color: AppColors.mut),
                  onSelected: (v) {
                    if (v == 'delete') confirmDeleteGroup(context, app, group);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'delete', child: Text('Supprimer le sous-groupe', style: TextStyle(color: Colors.red))),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Confirms then closes `group` — a "temporary group" wound down (e.g. a
/// weekend get-together that's over): its history/rankings stay fully
/// visible, but nothing new can be recorded until it's reopened (see
/// [AppState.setGroupClosed]). Unlike [confirmDeleteGroup], reversible and
/// keeps every bit of data.
Future<void> confirmCloseGroup(BuildContext context, AppState app, Group group, {required bool closed}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: AppColors.bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
      title: Text('Fermer « ${group.name} » ?', style: dispFont(size: 18, weight: FontWeight.w700, color: AppColors.ink)),
      content: Text(
        "L'historique et le classement resteront visibles, mais plus aucune nouvelle partie, invitation ou modification du catalogue ne sera possible. Vous pourrez rouvrir le groupe à tout moment.",
        style: bodyFont(size: 14, weight: FontWeight.w600, color: AppColors.mut),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annuler')),
        TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Fermer le groupe')),
      ],
    ),
  );
  if (confirmed == true) {
    await app.setGroupClosed(group.id, true);
  }
}

/// Confirms then deletes `group`, showing an error toast-style message via
/// [AppState.flowError] if the delete fails (surfaced by the caller screen).
Future<void> confirmDeleteGroup(BuildContext context, AppState app, Group group) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: AppColors.bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
      title: Text('Supprimer « ${group.name} » ?', style: dispFont(size: 18, weight: FontWeight.w700, color: AppColors.ink)),
      content: Text(
        group.isRoot
            ? "Cette action est définitive : toutes les parties, tous les jeux et tous les sous-groupes de cette communauté seront supprimés."
            : "Cette action est définitive : toutes les parties enregistrées dans ce sous-groupe seront supprimées.",
        style: bodyFont(size: 14, weight: FontWeight.w600, color: AppColors.mut),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annuler')),
        TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Supprimer', style: TextStyle(color: Colors.red))),
      ],
    ),
  );
  if (confirmed == true) {
    await app.deleteGroup(group.id);
  }
}
