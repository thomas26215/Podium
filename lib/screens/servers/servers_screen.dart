import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/server.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../groups/qr_scan_screen.dart';
import 'server_detail_screen.dart';
import 'server_form_dialog.dart';

/// Standalone page wrapper for [ServersScreen] — the "Serveurs" counterpart
/// to [GroupsPage], reached from the home screen header (storefront icon)
/// when a Group is active, or by tapping the header itself while a Salon is
/// active (see HomeScreen).
class ServersPage extends StatelessWidget {
  const ServersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.ink),
      ),
      body: const SafeArea(child: ServersScreen()),
    );
  }
}

class ServersScreen extends StatelessWidget {
  const ServersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final active = app.servers.where((s) => !s.closed).toList();
    final closed = app.servers.where((s) => s.closed).toList();

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ScreenHeading(eyebrow: 'Café jeux & structures', title: 'Mes serveurs'),
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Text(
                    "Plus rigide qu'un groupe : seuls le créateur et ses admins gèrent le catalogue et les salons. Les membres rejoignent chaque salon séparément.",
                    style: bodyFont(size: 12.5, weight: FontWeight.w600, color: AppColors.mut),
                  ),
                ),
                if (app.serversLoading)
                  Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: CircularProgressIndicator(color: AppColors.accent)))
                else if (app.servers.isEmpty)
                  const EmptyState(emoji: '🏠', message: 'Créez ou rejoignez votre premier serveur.')
                else ...[
                  for (final (i, s) in active.indexed) FadeSlideIn(delay: Duration(milliseconds: i * 60), child: _ServerCard(server: s)),
                  if (closed.isNotEmpty) ...[
                    if (active.isNotEmpty) const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 2, bottom: 10),
                      child: Text('SERVEURS CLOS', style: bodyFont(size: 11.5, weight: FontWeight.w800, color: AppColors.mut, letterSpacing: 0.5)),
                    ),
                    for (final s in closed) _ServerCard(server: s),
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
                  onTap: () => showDialog(context: context, builder: (_) => ChangeNotifierProvider.value(value: app, child: const ServerFormDialog())),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(border: Border.all(color: AppColors.line, width: 2), borderRadius: BorderRadius.circular(AppRadius.lg)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add, size: 20, color: AppColors.ink2),
                        const SizedBox(width: 8),
                        Flexible(child: Text('Créer un serveur', overflow: TextOverflow.ellipsis, style: bodyFont(size: 14, weight: FontWeight.w700, color: AppColors.ink2))),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Pressable(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const QrScanScreen(target: QrJoinTarget.server))),
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

class _ServerCard extends StatelessWidget {
  final Server server;
  const _ServerCard({required this.server});

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
