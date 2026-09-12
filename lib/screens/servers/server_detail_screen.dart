import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/salon.dart';
import '../../models/server.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';
import '../../widgets/common.dart';
import 'salon_form_dialog.dart';
import 'salon_invite_dialog.dart';
import 'server_invite_dialog.dart';

/// Server management screen: its salons (create/delete admin-only), its
/// roster with role management (promote/demote admin, owner-only), invite,
/// close/reopen/delete. Reached by tapping a server card in [GroupsScreen]
/// (the same screen Groups are picked from).
class ServerDetailScreen extends StatefulWidget {
  final String serverId;
  const ServerDetailScreen({super.key, required this.serverId});

  @override
  State<ServerDetailScreen> createState() => _ServerDetailScreenState();
}

class _ServerDetailScreenState extends State<ServerDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppState>().selectServer(widget.serverId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final server = app.serverById(widget.serverId);
    if (server == null) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(backgroundColor: AppColors.bg, elevation: 0, iconTheme: IconThemeData(color: AppColors.ink)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final isAdmin = app.isServerAdmin(server);
    final isOwner = app.currentUser?.uid == server.ownerId;
    final salons = app.currentServerId == widget.serverId ? app.salons : const <Salon>[];

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.ink),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(server.emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Flexible(child: Text(server.name, overflow: TextOverflow.ellipsis, style: dispFont(size: 17, weight: FontWeight.w700, color: AppColors.ink))),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_horiz, color: AppColors.mut),
            onSelected: (v) {
              if (v == 'invite') {
                showDialog(context: context, builder: (_) => ChangeNotifierProvider.value(value: app, child: ServerInviteDialog(serverId: server.id, serverName: server.name)));
              } else if (v == 'close') {
                _confirmCloseServer(context, app, server, closed: true);
              } else if (v == 'reopen') {
                app.setServerClosed(server.id, false);
              } else if (v == 'delete') {
                _confirmDeleteServer(context, app, server);
              }
            },
            itemBuilder: (_) => [
              if (!server.closed) const PopupMenuItem(value: 'invite', child: Text('Inviter au serveur')),
              if (isOwner)
                PopupMenuItem(value: server.closed ? 'reopen' : 'close', child: Text(server.closed ? 'Rouvrir le serveur' : 'Fermer le serveur')),
              if (isOwner) const PopupMenuItem(value: 'delete', child: Text('Supprimer le serveur', style: TextStyle(color: Colors.red))),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (server.closed)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(AppRadius.lg)),
                  child: Text(
                    "Ce serveur est clos — plus aucune nouvelle action n'est possible, mais l'historique reste visible.",
                    style: bodyFont(size: 13, weight: FontWeight.w600, color: AppColors.mut),
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SectionHeader(title: 'Salons'),
                  if (isAdmin && !server.closed)
                    TextButton.icon(
                      onPressed: () => showDialog(context: context, builder: (_) => ChangeNotifierProvider.value(value: app, child: SalonFormDialog(serverId: server.id))),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Créer'),
                    ),
                ],
              ),
              if (salons.isEmpty)
                const EmptyState(emoji: '🎮', message: 'Aucun salon pour l\'instant.')
              else
                for (final (i, s) in salons.indexed)
                  FadeSlideIn(delay: Duration(milliseconds: i * 40), child: _SalonRow(server: server, salon: s, isAdmin: isAdmin)),
              const SizedBox(height: 24),
              SectionHeader(title: 'Membres (${server.memberIds.length})'),
              for (final uid in server.memberIds) _MemberRow(server: server, uid: uid, isOwner: isOwner),
            ],
          ),
        ),
      ),
    );
  }
}

class _SalonRow extends StatelessWidget {
  final Server server;
  final Salon salon;
  final bool isAdmin;
  const _SalonRow({required this.server, required this.salon, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final closed = salon.closed;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line, width: 1.5), borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        // Selecting a salon works exactly like selecting a group (see
        // AppState.selectSalon + _selectAndClose in groups_screen.dart): pop
        // back to the tabbed shell instead of pushing a separate screen — a
        // salon is just another recording context, not a different app.
        onTap: () {
          app.selectSalon(server.id, salon.id);
          Navigator.of(context).popUntil((route) => route.isFirst);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Color(salon.emojiBg), borderRadius: BorderRadius.circular(10)),
                child: Text(salon.emoji, style: const TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(child: Text(salon.name, overflow: TextOverflow.ellipsis, style: bodyFont(size: 14, weight: FontWeight.w700, color: AppColors.ink))),
                        if (closed) ...[
                          const SizedBox(width: 6),
                          Text('CLOS', style: bodyFont(size: 10, weight: FontWeight.w800, color: AppColors.mut, letterSpacing: 0.4)),
                        ],
                      ],
                    ),
                    Text('${salon.memberIds.length} joueurs', style: bodyFont(size: 11, weight: FontWeight.w600, color: AppColors.mut)),
                  ],
                ),
              ),
              if (isAdmin)
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_horiz, size: 20, color: AppColors.mut),
                  onSelected: (v) {
                    if (v == 'invite') {
                      showDialog(context: context, builder: (_) => ChangeNotifierProvider.value(value: app, child: SalonInviteDialog(serverId: server.id, salonId: salon.id, salonName: salon.name)));
                    } else if (v == 'close') {
                      app.setSalonClosed(serverId: server.id, salonId: salon.id, closed: true);
                    } else if (v == 'reopen') {
                      app.setSalonClosed(serverId: server.id, salonId: salon.id, closed: false);
                    } else if (v == 'delete') {
                      _confirmDeleteSalon(context, app, server, salon);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'invite', child: Text('Inviter au salon')),
                    PopupMenuItem(value: closed ? 'reopen' : 'close', child: Text(closed ? 'Rouvrir le salon' : 'Fermer le salon')),
                    const PopupMenuItem(value: 'delete', child: Text('Supprimer le salon', style: TextStyle(color: Colors.red))),
                  ],
                )
              else
                Icon(Icons.chevron_right_rounded, color: AppColors.mut),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  final Server server;
  final String uid;
  final bool isOwner;
  const _MemberRow({required this.server, required this.uid, required this.isOwner});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final p = app.playerById(uid);
    final isServerOwner = uid == server.ownerId;
    final isServerAdmin = server.adminIds.contains(uid);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Avatar(initial: p?.initial ?? '?', color: p != null ? Color(p.color) : AppColors.mut, size: 32, fontSize: 13),
          const SizedBox(width: 10),
          Expanded(child: Text(p?.displayName ?? uid, style: bodyFont(size: 14, weight: FontWeight.w700, color: AppColors.ink))),
          if (isServerOwner)
            Text('OWNER', style: bodyFont(size: 10.5, weight: FontWeight.w800, color: AppColors.mut, letterSpacing: 0.4))
          else if (isOwner)
            TextButton(
              onPressed: () => app.setServerAdmin(server: server, uid: uid, admin: !isServerAdmin),
              child: Text(isServerAdmin ? 'Retirer admin' : 'Rendre admin', style: bodyFont(size: 12.5, weight: FontWeight.w700, color: AppColors.accent)),
            )
          else if (isServerAdmin)
            Text('ADMIN', style: bodyFont(size: 10.5, weight: FontWeight.w800, color: AppColors.mut, letterSpacing: 0.4)),
        ],
      ),
    );
  }
}

Future<void> _confirmCloseServer(BuildContext context, AppState app, Server server, {required bool closed}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: AppColors.bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
      title: Text('Fermer « ${server.name} » ?', style: dispFont(size: 18, weight: FontWeight.w700, color: AppColors.ink)),
      content: Text(
        "L'historique et le classement resteront visibles, mais plus aucune nouvelle partie, invitation ou modification du catalogue ne sera possible. Vous pourrez rouvrir le serveur à tout moment.",
        style: bodyFont(size: 14, weight: FontWeight.w600, color: AppColors.mut),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annuler')),
        TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Fermer le serveur')),
      ],
    ),
  );
  if (confirmed == true) await app.setServerClosed(server.id, true);
}

Future<void> _confirmDeleteServer(BuildContext context, AppState app, Server server) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: AppColors.bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
      title: Text('Supprimer « ${server.name} » ?', style: dispFont(size: 18, weight: FontWeight.w700, color: AppColors.ink)),
      content: Text(
        "Cette action est définitive : tous les salons, toutes les parties et tout le catalogue de ce serveur seront supprimés.",
        style: bodyFont(size: 14, weight: FontWeight.w600, color: AppColors.mut),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annuler')),
        TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Supprimer', style: TextStyle(color: Colors.red))),
      ],
    ),
  );
  if (confirmed == true) {
    final ok = await app.deleteServer(server.id);
    if (ok && context.mounted) Navigator.of(context).pop();
  }
}

Future<void> _confirmDeleteSalon(BuildContext context, AppState app, Server server, Salon salon) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: AppColors.bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
      title: Text('Supprimer « ${salon.name} » ?', style: dispFont(size: 18, weight: FontWeight.w700, color: AppColors.ink)),
      content: Text(
        "Cette action est définitive : toutes les parties enregistrées dans ce salon seront supprimées.",
        style: bodyFont(size: 14, weight: FontWeight.w600, color: AppColors.mut),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annuler')),
        TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Supprimer', style: TextStyle(color: Colors.red))),
      ],
    ),
  );
  if (confirmed == true) await app.deleteSalon(serverId: server.id, salonId: salon.id);
}
