import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/match.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/match_card.dart';
import '../history/match_detail_screen.dart';
import '../new_game/new_game_sheet.dart';
import 'salon_invite_dialog.dart';
import 'server_detail_screen.dart';

/// A salon's own screen: makes it the active recording context (see
/// AppState.selectSalon), then shows matches recorded in it — matches still
/// needing the signed-in player's confirmation surfaced first, above the
/// regular history. Reached by tapping a salon in [ServerDetailScreen].
class SalonDetailScreen extends StatefulWidget {
  final String serverId;
  final String salonId;
  const SalonDetailScreen({super.key, required this.serverId, required this.salonId});

  @override
  State<SalonDetailScreen> createState() => _SalonDetailScreenState();
}

class _SalonDetailScreenState extends State<SalonDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppState>().selectSalon(widget.serverId, widget.salonId);
    });
  }

  Future<void> _openNewGameSheet(BuildContext context, AppState app) async {
    if (app.activeContextClosed) {
      app.showToast('Ce salon est clos — plus aucune nouvelle partie ne peut y être ajoutée.');
      return;
    }
    app.openSheet();
    await showNewGameSheet(context, app);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final server = app.serverById(widget.serverId);
    final salon = app.currentSalonId == widget.salonId ? app.currentSalon : null;
    final uid = app.currentUser?.uid;

    if (server == null || salon == null || app.currentSalonId != widget.salonId) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(backgroundColor: AppColors.bg, elevation: 0, iconTheme: IconThemeData(color: AppColors.ink)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final isAdmin = app.isServerAdmin(server);
    final matches = app.matches;
    final needsMe = matches.where((m) => uid != null && m.requiredConfirmers.contains(uid) && !(m.confirmedBy ?? const []).contains(uid) && !m.isRejected).toList();
    final myRejected = matches.where((m) => m.isRejected && m.createdByUid == uid).toList();
    final rest = matches.where((m) => !needsMe.contains(m) && !myRejected.contains(m)).toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.ink),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(salon.emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Flexible(child: Text(salon.name, overflow: TextOverflow.ellipsis, style: dispFont(size: 17, weight: FontWeight.w700, color: AppColors.ink))),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.person_add_alt_1_rounded, color: AppColors.mut),
            tooltip: 'Inviter au salon',
            onPressed: () => showDialog(
              context: context,
              builder: (_) => ChangeNotifierProvider.value(value: app, child: SalonInviteDialog(serverId: server.id, salonId: salon.id, salonName: salon.name)),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openNewGameSheet(context, app),
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle partie'),
      ),
      body: SafeArea(
        child: !app.groupDataFullyLoaded
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (salon.closed)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(AppRadius.lg)),
                        child: Text(
                          "Ce salon est clos — plus aucune nouvelle partie ne peut y être ajoutée.",
                          style: bodyFont(size: 13, weight: FontWeight.w600, color: AppColors.mut),
                        ),
                      ),
                    if (needsMe.isNotEmpty) ...[
                      SectionHeader(title: 'À confirmer (${needsMe.length})'),
                      for (final (i, m) in needsMe.indexed)
                        FadeSlideIn(
                          delay: Duration(milliseconds: i * 50),
                          child: _MatchTile(match: m, app: app),
                        ),
                      const SizedBox(height: 12),
                    ],
                    if (myRejected.isNotEmpty) ...[
                      SectionHeader(title: 'Refusées — à corriger (${myRejected.length})'),
                      for (final (i, m) in myRejected.indexed)
                        FadeSlideIn(
                          delay: Duration(milliseconds: i * 50),
                          child: _MatchTile(match: m, app: app),
                        ),
                      const SizedBox(height: 12),
                    ],
                    SectionHeader(title: 'Historique'),
                    if (rest.isEmpty && needsMe.isEmpty && myRejected.isEmpty)
                      const EmptyState(emoji: '🎮', message: 'Aucune partie enregistrée pour l\'instant.')
                    else
                      for (final (i, m) in rest.indexed)
                        FadeSlideIn(
                          delay: Duration(milliseconds: i * 40),
                          child: _MatchTile(match: m, app: app),
                        ),
                    const SizedBox(height: 24),
                    if (isAdmin)
                      TextButton.icon(
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ServerDetailScreen(serverId: server.id))),
                        icon: const Icon(Icons.settings_rounded, size: 18),
                        label: Text('Gérer « ${server.name} »'),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _MatchTile extends StatelessWidget {
  final GameMatch match;
  final AppState app;
  const _MatchTile({required this.match, required this.app});

  @override
  Widget build(BuildContext context) {
    final game = app.gameById(match.gameId);
    if (game == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MatchCard(
        game: game,
        match: match,
        appState: app,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MatchDetailScreen(game: game, match: match, appState: app))),
      ),
    );
  }
}
