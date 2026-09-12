import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../state/player_row.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';
import '../../widgets/common.dart';
import '../../widgets/live_match_card.dart';
import '../../widgets/match_card.dart';
import '../../models/game.dart';
import '../../models/tournament.dart';
import '../../widgets/rank_row.dart';
import '../games/games_catalog_screen.dart';
import '../groups/groups_screen.dart';
import '../live/live_match_screen.dart';
import '../new_game/new_game_sheet.dart';
import '../tournaments/tournament_detail_screen.dart';
import '../tournaments/tournaments_list_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final inSalon = app.activeContext == ActiveContextKind.salon;
    final salon = app.currentSalon;
    final group = app.currentGroup;
    final headerEmoji = inSalon ? (salon?.emoji ?? '🎮') : (group?.emoji ?? '🎲');
    final headerName = inSalon ? (salon?.name ?? 'Salon') : (group?.name ?? 'Podium');
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
                          child: Text(headerEmoji, style: const TextStyle(fontSize: 19)),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(headerName, overflow: TextOverflow.ellipsis, style: bodyFont(size: 18, weight: FontWeight.w800, color: AppColors.ink, letterSpacing: -0.2)),
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
          if (app.activeContextClosed)
            KeyedSubtree(
              key: const ValueKey('closed-banner'),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
              ),
            ),
          // Nothing data-dependent below renders with zero/empty placeholder
          // values while still loading — the whole body waits for
          // groupDataFullyLoaded and appears together once real numbers are
          // in, instead of a stat chip flashing "0" then popping to its real
          // count a beat later.
          if (!app.groupDataFullyLoaded)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(strokeWidth: 2, color: AppColors.mut),
                    const SizedBox(height: 12),
                    Text(
                      '${app.groupDataFetchedCount}/${AppState.groupDataTotalCount} données récupérées…',
                      style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // Every section below is wrapped in a KeyedSubtree with a stable
            // key — not decorative. "Parties en direct"/"Partie non terminée"
            // can each pop in or out later (e.g. a live session starting or
            // ending) independently of one another, which shifts list
            // indices; without a key, Column reconciles purely by index, so
            // a shift anywhere would tear down (and restart from scratch)
            // every FadeSlideIn/AnimatedCounter after it that's mid-
            // animation. A stable key anchors each section's identity
            // regardless of what its siblings do.
            if (app.pendingLocalDraft != null)
              KeyedSubtree(
                key: const ValueKey('pending-draft'),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(title: 'Partie non terminée', actionLabel: 'Ignorer', onAction: app.discardLocalDraft),
                    _PendingDraftBanner(app: app),
                    const SizedBox(height: 18),
                  ],
                ),
              ),
            if (app.liveSessions.isNotEmpty)
              KeyedSubtree(
                key: const ValueKey('live-sessions'),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                ),
              ),
            KeyedSubtree(
              key: const ValueKey('dashboard'),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: app.dashboardStyle == DashboardStyle.simple ? _simpleSections(app, winRows) : _completeSections(app, stats, winRows),
              ),
            ),
            if (app.viewTournaments.any((t) => !t.isCompleted))
              KeyedSubtree(
                key: const ValueKey('tournaments-section'),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _tournamentsSection(context, app),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Tournaments currently in progress — deliberately low on the home screen
/// (below the classement/dernières parties, not competing with "live"/
/// "unfinished match" banners at the top) and only shown at all once
/// there's actually one running; creating a new one is only ever reached
/// via the main "+" (see `AppState.startTournamentCreationFlow`), not from
/// here.
List<Widget> _tournamentsSection(BuildContext context, AppState app) {
  final activeTournaments = app.viewTournaments.where((t) => !t.isCompleted).toList();
  return [
    SectionHeader(
      title: 'Tournois en cours',
      actionLabel: 'Tout voir',
      onAction: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TournamentsListScreen())),
    ),
    SizedBox(
      height: 128,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: activeTournaments.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final t = activeTournaments[i];
          return _TournamentCard(
            tournament: t,
            game: app.gameById(t.gameId),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TournamentDetailScreen(tournamentId: t.id))),
          );
        },
      ),
    ),
  ];
}

/// Épuré: just who's leading and the very last game — the rest of the
/// dashboard (stat chips, full mini-ranking, recent-matches list) is
/// dropped for a calmer, less busy home screen.
List<Widget> _simpleSections(AppState app, List<PlayerRow> winRows) {
  final lastMatch = app.viewMatches.firstOrNull;
  final lastMatchGame = lastMatch != null ? app.gameById(lastMatch.gameId) : null;

  return [
    FadeSlideIn(child: winRows.isEmpty ? const _SimpleNoDataCard() : _SimpleLeaderCard(row: winRows.first)),
    const SizedBox(height: 22),
    SectionHeader(title: 'Dernière partie', actionLabel: 'Historique', onAction: () => app.setTab(AppTab.history)),
    if (lastMatch == null || lastMatchGame == null)
      const EmptyState(emoji: '🎲', message: "Pas encore de partie. Lancez-vous avec le bouton +.")
    else
      FadeSlideIn(
        delay: const Duration(milliseconds: 60),
        child: HomeMatchTile(
          game: lastMatchGame,
          match: lastMatch,
          winner: lastMatch.winnerIds().isNotEmpty ? app.playerById(lastMatch.winnerIds().first) : null,
        ),
      ),
  ];
}

/// Complet: the full hero + stat chips + top-3 ranking + recent-matches
/// dashboard.
List<Widget> _completeSections(AppState app, Map<String, int> stats, List<PlayerRow> winRows) {
  return [
    FadeSlideIn(child: winRows.isEmpty ? const _NoDataHero() : _LeaderHero(row: winRows.first)),
    const SizedBox(height: 14),
    FadeSlideIn(
      delay: const Duration(milliseconds: 60),
      child: Row(children: [
        StatChip(value: stats['parties'] ?? 0, label: 'parties'),
        const SizedBox(width: 10),
        StatChip(value: stats['jeux'] ?? 0, label: 'jeux joués'),
        const SizedBox(width: 10),
        StatChip(value: stats['joueurs'] ?? 0, label: 'joueurs'),
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
  ];
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
                        AnimatedCounter(value: row.wins, style: bodyFont(size: 15, weight: FontWeight.w700, color: Colors.white)),
                        const SizedBox(width: 4),
                        Text('victoires', style: bodyFont(size: 13, weight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.6))),
                        const SizedBox(width: 18),
                        Row(children: [
                          AnimatedCounter(value: (row.ratio * 100).round(), style: bodyFont(size: 15, weight: FontWeight.w700, color: Colors.white)),
                          Text('%', style: bodyFont(size: 15, weight: FontWeight.w700, color: Colors.white)),
                        ]),
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

/// Épuré version of [_LeaderHero]: same info (who's leading, wins, winrate)
/// on a plain card instead of the dark gradient hero — quieter, less
/// "look at me" for users who found the full dashboard too busy.
class _SimpleLeaderCard extends StatelessWidget {
  final PlayerRow row;
  const _SimpleLeaderCard({required this.row});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(AppRadius.xl)),
      child: Row(
        children: [
          Avatar(initial: row.player.initial, color: Color(row.player.color), size: 48, fontSize: 19),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('En tête · ${row.player.displayName}', style: bodyFont(size: 15, weight: FontWeight.w800, color: AppColors.ink)),
                const SizedBox(height: 2),
                Row(children: [
                  AnimatedCounter(value: row.wins, style: bodyFont(size: 12.5, weight: FontWeight.w600, color: AppColors.mut)),
                  Text(' victoires · ', style: bodyFont(size: 12.5, weight: FontWeight.w600, color: AppColors.mut)),
                  AnimatedCounter(value: (row.ratio * 100).round(), style: bodyFont(size: 12.5, weight: FontWeight.w600, color: AppColors.mut)),
                  Text('% de winrate', style: bodyFont(size: 12.5, weight: FontWeight.w600, color: AppColors.mut)),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SimpleNoDataCard extends StatelessWidget {
  const _SimpleNoDataCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(AppRadius.xl)),
      child: Text('Enregistrez votre première partie pour lancer le classement.', style: bodyFont(size: 13.5, weight: FontWeight.w600, color: AppColors.mut)),
    );
  }
}

/// One active tournament in the home screen's "Tournois" section.
class _TournamentCard extends StatelessWidget {
  final Tournament tournament;
  final Game? game;
  final VoidCallback onTap;
  const _TournamentCard({required this.tournament, required this.game, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final done = tournament.matches.where((m) => m.bracket != 'group' && (m.gameMatchId != null || m.bye)).length;
    final total = tournament.matches.where((m) => m.bracket != 'group').length;
    return Pressable(
      onTap: onTap,
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line, width: 1.5), borderRadius: BorderRadius.circular(AppRadius.xl)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(game?.emoji ?? '🏆', style: const TextStyle(fontSize: 22)),
            const Spacer(),
            Text(tournament.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyFont(size: 13.5, weight: FontWeight.w800, color: AppColors.ink)),
            Text(
              total > 0 ? '$done/$total matchs' : '${tournament.entrants.length} participants',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: bodyFont(size: 11.5, weight: FontWeight.w600, color: AppColors.mut),
            ),
          ],
        ),
      ),
    );
  }
}
