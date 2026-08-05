import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../state/player_row.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';
import '../../widgets/common.dart';
import '../../widgets/live_match_card.dart';
import '../../widgets/match_card.dart';
import '../../widgets/rank_row.dart';
import '../games/games_catalog_screen.dart';
import '../groups/groups_screen.dart';
import '../live/live_match_screen.dart';
import '../new_game/new_game_sheet.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final group = app.currentGroup;
    final players = app.viewPlayers;
    final stats = app.groupStats;
    final winRows = app.standings('wins');

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 116),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: InkWell(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GroupsPage())),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(12)),
                          child: Text(group?.emoji ?? '🎲', style: const TextStyle(fontSize: 19)),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(group?.name ?? 'Podium', overflow: TextOverflow.ellipsis, style: bodyFont(size: 18, weight: FontWeight.w800, color: AppColors.ink, letterSpacing: -0.2)),
                              Text('${stats['joueurs']} joueurs · saison en cours', overflow: TextOverflow.ellipsis, style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.expand_more, size: 18, color: AppColors.mut),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GamesCatalogScreen())),
                  child: Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.casino_rounded, size: 19, color: AppColors.ink2),
                  ),
                ),
                const SizedBox(width: 10),
                AvatarCluster(avatars: [for (final p in players.take(4)) (initial: p.initial, color: Color(p.color))]),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (app.currentGroupClosed) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(AppRadius.lg)),
              child: Row(
                children: [
                  Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.mut),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Groupe clos — l'historique et le classement restent visibles, mais plus aucune action n'est possible.",
                      style: bodyFont(size: 12, weight: FontWeight.w700, color: AppColors.mut),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (!app.groupDataFullyLoaded) ...[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.mut),
                ),
                const SizedBox(width: 8),
                Text(
                  '${app.groupDataFetchedCount}/${AppState.groupDataTotalCount} données récupérées…',
                  style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (app.pendingLocalDraft != null) ...[
            SectionHeader(title: 'Partie non terminée', actionLabel: 'Ignorer', onAction: app.discardLocalDraft),
            _PendingDraftBanner(app: app),
            const SizedBox(height: 18),
          ],
          if (app.liveSessions.isNotEmpty) ...[
            SectionHeader(title: 'Parties en direct'),
            SizedBox(
              height: 128,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: app.liveSessions.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final session = app.liveSessions[i];
                  return LiveMatchCard(
                    session: session,
                    game: app.gameById(session.gameId),
                    appState: app,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LiveMatchScreen(sessionId: session.id))),
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
          ],
          FadeSlideIn(child: winRows.isEmpty ? const _NoDataHero() : _LeaderHero(row: winRows.first)),
          const SizedBox(height: 14),
          FadeSlideIn(
            delay: const Duration(milliseconds: 60),
            child: Row(children: [
              StatChip(value: '${stats['parties']}', label: 'parties'),
              const SizedBox(width: 10),
              StatChip(value: '${stats['jeux']}', label: 'jeux joués'),
              const SizedBox(width: 10),
              StatChip(value: '${stats['joueurs']}', label: 'joueurs'),
            ]),
          ),
          const SizedBox(height: 22),
          SectionHeader(title: 'Classement', actionLabel: 'Tout voir', onAction: () => app.setTab(AppTab.ranking)),
          FadeSlideIn(
            delay: const Duration(milliseconds: 100),
            child: Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(AppRadius.xl)),
              child: winRows.isEmpty
                  ? const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: EmptyState(emoji: '🏆', message: 'Aucune partie enregistrée pour l\'instant.'))
                  : Column(
                      children: [
                        for (var i = 0; i < winRows.length && i < 3; i++)
                          MiniRankRow(rank: i + 1, player: winRows[i].player, wins: winRows[i].wins, onTap: () => app.openProfile(winRows[i].player.uid)),
                      ],
                    ),
            ),
          ),
          SectionHeader(title: 'Dernières parties', actionLabel: 'Historique', onAction: () => app.setTab(AppTab.history)),
          if (app.viewMatches.isEmpty)
            const EmptyState(emoji: '🎲', message: "Pas encore de partie. Lancez-vous avec le bouton +.")
          else
            for (final (i, m) in app.viewMatches.take(3).toList().indexed)
              Builder(builder: (_) {
                final g = app.gameById(m.gameId);
                if (g == null) return const SizedBox.shrink();
                final winners = m.winnerIds();
                final winner = winners.isNotEmpty ? app.playerById(winners.first) : null;
                return FadeSlideIn(delay: Duration(milliseconds: 140 + i * 40), child: HomeMatchTile(game: g, match: m, winner: winner));
              }),
        ],
      ),
    );
  }
}

/// Offers to resume a match found on this device (see
/// `AppState.pendingLocalDraft`) — left over from before the app was
/// killed/closed mid-score.
class _PendingDraftBanner extends StatelessWidget {
  final AppState app;
  const _PendingDraftBanner({required this.app});

  @override
  Widget build(BuildContext context) {
    final pending = app.pendingLocalDraft!;
    final game = app.gameById(pending.draft.gameId ?? '');
    final group = app.groupById(pending.groupId);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line, width: 1.5), borderRadius: BorderRadius.circular(AppRadius.xl)),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(13)),
            child: Text(game?.emoji ?? '🎲', style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(game?.name ?? 'Partie en cours', maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyFont(size: 15, weight: FontWeight.w800, color: AppColors.ink)),
                Text(
                  group != null ? '${group.emoji} ${group.name}' : 'Reprenez là où vous en étiez.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Pressable(
            onTap: () async {
              app.resumeLocalDraft();
              await showNewGameSheet(context, app);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(12)),
              child: Text('Reprendre', style: bodyFont(size: 13, weight: FontWeight.w800, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderHero extends StatelessWidget {
  final PlayerRow row;
  const _LeaderHero({required this.row});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(AppRadius.xxl)),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -40,
            top: -40,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [AppColors.accent.withValues(alpha: 0.55), Colors.transparent]),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('EN TÊTE CETTE SAISON', style: bodyFont(size: 12, weight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.55), letterSpacing: 1.2)),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Avatar(initial: row.player.initial, color: Color(row.player.color), size: 62, fontSize: 26),
                      Positioned(
                        top: -12,
                        left: 0,
                        right: 0,
                        child: Transform.rotate(angle: 0.14, child: Icon(Icons.emoji_events, color: AppColors.gold, size: 26)),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(row.player.displayName, style: dispFont(size: 24, weight: FontWeight.w800, color: Colors.white, letterSpacing: -0.4)),
                      const SizedBox(height: 6),
                      Row(children: [
                        Text('${row.wins}', style: bodyFont(size: 15, weight: FontWeight.w700, color: Colors.white)),
                        const SizedBox(width: 4),
                        Text('victoires', style: bodyFont(size: 13, weight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.6))),
                        const SizedBox(width: 18),
                        Text('${(row.ratio * 100).round()}%', style: bodyFont(size: 15, weight: FontWeight.w700, color: Colors.white)),
                        const SizedBox(width: 4),
                        Text('de winrate', style: bodyFont(size: 13, weight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.6))),
                      ]),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NoDataHero extends StatelessWidget {
  const _NoDataHero();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(AppRadius.xxl)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('EN TÊTE CETTE SAISON', style: bodyFont(size: 12, weight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.55), letterSpacing: 1.2)),
          const SizedBox(height: 10),
          Text('Enregistrez votre première partie pour lancer le classement.', style: bodyFont(size: 14, weight: FontWeight.w600, color: Colors.white)),
        ],
      ),
    );
  }
}
