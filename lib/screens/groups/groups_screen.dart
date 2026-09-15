import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/group.dart';
import '../../models/server.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../servers/server_detail_screen.dart';
import '../servers/server_form_dialog.dart';
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

/// Standalone page wrapper for [GroupsScreen] — the single place both
/// Groups and Servers are picked from (see GroupsScreen), used when
/// navigating to it via [Navigator.push] (it's no longer a bottom-nav tab).
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

/// The one place both Groups (free-for-all friend spaces) and Servers
/// (rigid communities like a game café — see [ServerCard]) are listed,
/// created and joined from — tapping either kind of card selects it as the
/// active recording context (a Group directly, a Server by drilling into
/// one of its salons first, see [ServerDetailScreen]).
class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  // Collapsed by default — closed groups/servers are reachable but
  // shouldn't compete with the active list for attention on first open.
  bool _archivedExpanded = false;

  Future<void> _chooseCreateKind(BuildContext context, AppState app) async {
    final kind = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quoi créer ?', style: dispFont(size: 18, weight: FontWeight.w700, color: AppColors.ink)),
            const SizedBox(height: 16),
            _CreateKindTile(
              emoji: '👥',
              title: 'Un groupe',
              subtitle: "Entre amis — tout le monde peut tout modifier.",
              onTap: () => Navigator.of(sheetContext).pop('group'),
            ),
            const SizedBox(height: 10),
            _CreateKindTile(
              emoji: '🏠',
              title: 'Un serveur',
              subtitle: "Pour un café jeu ou une structure — vous gardez la main sur le catalogue et les salons.",
              onTap: () => Navigator.of(sheetContext).pop('server'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || kind == null) return;
    if (kind == 'group') {
      await showDialog(context: context, builder: (_) => ChangeNotifierProvider.value(value: app, child: const GroupFormDialog()));
    } else {
      await showDialog(context: context, builder: (_) => ChangeNotifierProvider.value(value: app, child: const ServerFormDialog()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    // Closed groups/servers stay reachable (history, reopening…) but
    // shouldn't compete with the active list for attention — merged into
    // one collapsible "ARCHIVÉS" section underneath instead of scattered
    // "X CLOS" sub-sections (see _ArchivedSection).
    final activeGroups = app.groups.where((g) => !g.closed).toList();
    final closedGroups = app.groups.where((g) => g.closed).toList();
    final activeServers = app.servers.where((s) => !s.closed).toList();
    final closedServers = app.servers.where((s) => s.closed).toList();
    final hasArchived = closedGroups.isNotEmpty || closedServers.isNotEmpty;
    final nothingAtAll = !app.groupsLoading &&
        !app.serversLoading &&
        activeGroups.isEmpty &&
        activeServers.isEmpty &&
        !hasArchived;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ScreenHeading(eyebrow: 'Vos communautés', title: 'Mes groupes & serveurs'),
                if (app.groupsLoading)
                  Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: CircularProgressIndicator(color: AppColors.accent)))
                else if (nothingAtAll)
                  const EmptyState(emoji: '👥', message: 'Créez votre premier groupe pour commencer.')
                else ...[
                  if (activeGroups.isNotEmpty) ...[
                    const _SectionLabel('GROUPES'),
                    for (final (i, g) in activeGroups.indexed) FadeSlideIn(delay: Duration(milliseconds: i * 60), child: _RootGroupCard(group: g)),
                  ],
                  if (activeServers.isNotEmpty || app.serversLoading) ...[
                    if (activeGroups.isNotEmpty) const SizedBox(height: 12),
                    const _SectionLabel('SERVEURS'),
                    if (app.serversLoading)
                      Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator(color: AppColors.accent)))
                    else
                      for (final (i, s) in activeServers.indexed) FadeSlideIn(delay: Duration(milliseconds: i * 60), child: ServerCard(server: s)),
                  ],
                  if (hasArchived) ...[
                    if (activeGroups.isNotEmpty || activeServers.isNotEmpty || app.serversLoading) const SizedBox(height: 12),
                    _ArchivedSection(
                      expanded: _archivedExpanded,
                      onToggle: () => setState(() => _archivedExpanded = !_archivedExpanded),
                      closedGroups: closedGroups,
                      closedServers: closedServers,
                    ),
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
                child: Pressable(
                  onTap: () => _chooseCreateKind(context, app),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(border: Border.all(color: AppColors.line, width: 2), borderRadius: BorderRadius.circular(AppRadius.lg)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add, size: 20, color: AppColors.ink2),
                        const SizedBox(width: 8),
                        Flexible(child: Text('Créer', overflow: TextOverflow.ellipsis, style: bodyFont(size: 14, weight: FontWeight.w700, color: AppColors.ink2))),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Pressable(
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

/// A section's small caps label (GROUPES / SERVEURS) — factored out so both
/// sections stay visually identical.
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 10),
      child: Text(label, style: bodyFont(size: 11.5, weight: FontWeight.w800, color: AppColors.mut, letterSpacing: 0.5)),
    );
  }
}

/// Every closed group and closed server, merged into one collapsible
/// section — closed items stay reachable (history, reopening…) without
/// splitting the page into several separate "X CLOS" sub-sections.
/// Collapsed by default so the active list stays front and center.
class _ArchivedSection extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggle;
  final List<Group> closedGroups;
  final List<Server> closedServers;
  const _ArchivedSection({required this.expanded, required this.onToggle, required this.closedGroups, required this.closedServers});

  @override
  Widget build(BuildContext context) {
    final count = closedGroups.length + closedServers.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Pressable(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                AnimatedRotation(
                  turns: expanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.mut),
                ),
                const SizedBox(width: 2),
                Text('ARCHIVÉS', style: bodyFont(size: 11.5, weight: FontWeight.w800, color: AppColors.mut, letterSpacing: 0.5)),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(20)),
                  child: Text('$count', style: bodyFont(size: 10.5, weight: FontWeight.w800, color: AppColors.mut)),
                ),
              ],
            ),
          ),
        ),
        if (expanded) ...[
          const SizedBox(height: 8),
          for (final g in closedGroups) _RootGroupCard(group: g),
          for (final s in closedServers) ServerCard(server: s),
        ],
      ],
    );
  }
}

class _CreateKindTile extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _CreateKindTile({required this.emoji, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line, width: 1.5), borderRadius: BorderRadius.circular(AppRadius.lg)),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12)),
              child: Text(emoji, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: bodyFont(size: 15, weight: FontWeight.w800, color: AppColors.ink)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.mut),
          ],
        ),
      ),
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
    final closed = group.closed;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line, width: 1.5), borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Padding(
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
                if (!closed) const PopupMenuItem(value: 'invite', child: Text('Inviter un ami')),
                if (app.canDeleteGroup(group) && !closed) const PopupMenuItem(value: 'reassign', child: Text('Réassigner un membre')),
                if (app.canCloseGroup(group))
                  PopupMenuItem(value: closed ? 'reopen' : 'close', child: Text(closed ? 'Rouvrir le groupe' : 'Fermer le groupe')),
                if (app.canDeleteGroup(group))
                  const PopupMenuItem(value: 'delete', child: Text('Supprimer le groupe', style: TextStyle(color: Colors.red))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A server card in the unified list — tapping it opens [ServerDetailScreen]
/// (pick a salon, manage members/roles) rather than selecting it directly,
/// since a Server itself isn't a recording context, only one of its salons
/// is (see AppState.selectSalon).
class ServerCard extends StatelessWidget {
  final Server server;
  const ServerCard({super.key, required this.server});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final uid = app.currentUser?.uid;
    final isOwner = uid != null && server.ownerId == uid;
    final isAdmin = app.isServerAdmin(server);
    final closed = server.closed;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line, width: 1.5), borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ServerDetailScreen(serverId: server.id))),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Opacity(
                opacity: closed ? 0.5 : 1,
                child: Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: Color(server.emojiBg), borderRadius: BorderRadius.circular(14)),
                  child: Text(server.emoji, style: const TextStyle(fontSize: 24)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(child: Text(server.name, overflow: TextOverflow.ellipsis, style: bodyFont(size: 16, weight: FontWeight.w800, color: AppColors.ink))),
                        if (closed) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(color: AppColors.bg, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(6)),
                            child: Text('CLOS', style: bodyFont(size: 10, weight: FontWeight.w800, color: AppColors.mut, letterSpacing: 0.4)),
                          ),
                        ] else if (isOwner || isAdmin) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(color: AppColors.accentSoft, border: Border.all(color: AppColors.accent), borderRadius: BorderRadius.circular(6)),
                            child: Text(isOwner ? 'OWNER' : 'ADMIN', style: bodyFont(size: 10, weight: FontWeight.w800, color: AppColors.accent, letterSpacing: 0.4)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text('${server.memberIds.length} membres', style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.mut),
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
        "Cette action est définitive : toutes les parties et tous les jeux de ce groupe seront supprimés.",
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
