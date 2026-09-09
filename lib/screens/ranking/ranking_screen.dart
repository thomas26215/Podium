import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';
import '../../widgets/common.dart';
import '../../widgets/podium.dart';
import '../../widgets/rank_row.dart';
import '../../widgets/segmented_control.dart';

const _modes = ['wins', 'points', 'ratio', 'avg'];
const _modeLabels = ['Victoires', 'Points', 'Ratio', 'Par jeu'];

class RankingScreen extends StatelessWidget {
  const RankingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final rows = app.standings(
      app.rankMode,
      gameFilterId: app.gameFilter,
      participantFilter: app.rankingPlayerFilter,
      participantFilterExact: app.rankingPlayerFilterExact,
    );
    final podiumRows = rows.take(3).toList();
    final rest = rows.skip(3).toList();
    final isAvg = app.rankMode == 'avg';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 116),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenHeading(eyebrow: (app.activeContext == ActiveContextKind.salon ? app.currentSalon?.name : app.currentGroup?.name) ?? '', title: 'Classement'),
          SegmentedControl(
            labels: _modeLabels,
            selectedIndex: _modes.indexOf(app.rankMode),
            onChanged: (i) => app.setRankMode(_modes[i]),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                if (!isAvg)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _FilterChip(
                      label: 'Tous les jeux',
                      selected: app.gameFilter == null,
                      onTap: () => app.setGameFilter(null),
                    ),
                  ),
                for (final g in app.games)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _FilterChip(
                      label: g.name,
                      emoji: g.emoji,
                      selected: app.gameFilter == g.id,
                      onTap: () => app.setGameFilter(g.id),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Pressable(
            onTap: () => showModalBottomSheet(
              context: context,
              backgroundColor: Colors.transparent,
              isScrollControlled: true,
              builder: (_) => ChangeNotifierProvider.value(value: app, child: const _PlayerFilterSheet()),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: app.rankingPlayerFilter.isEmpty ? AppColors.card : AppColors.accentSoft,
                border: Border.all(color: app.rankingPlayerFilter.isEmpty ? AppColors.line : AppColors.accent, width: 1.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.people_alt_rounded, size: 15, color: app.rankingPlayerFilter.isEmpty ? AppColors.mut : AppColors.accent),
                  const SizedBox(width: 6),
                  Text(
                    app.rankingPlayerFilter.isEmpty
                        ? 'Filtrer par joueurs'
                        : '${app.rankingPlayerFilter.length} joueur${app.rankingPlayerFilter.length > 1 ? 's' : ''} · ${app.rankingPlayerFilterExact ? 'exactement' : 'au moins'}',
                    style: bodyFont(size: 12.5, weight: FontWeight.w700, color: app.rankingPlayerFilter.isEmpty ? AppColors.ink2 : AppColors.accent),
                  ),
                  if (app.rankingPlayerFilter.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: app.clearRankingPlayerFilter,
                      child: Icon(Icons.close_rounded, size: 15, color: AppColors.accent),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (rows.isEmpty)
            EmptyState(
              emoji: '📊',
              message: isAvg && app.gameFilter == null ? 'Choisissez un jeu pour voir ce classement.' : 'Pas encore de données pour ce classement.',
            )
          else ...[
            FadeSlideIn(
              key: ValueKey(podiumRows.map((r) => r.player.uid).join(',')),
              child: PodiumWidget(columns: [
                if (podiumRows.length > 1)
                  PodiumColumn(row: podiumRows[1], metric: app.metricFor(podiumRows[1], app.rankMode), place: 2, onTap: () => app.openProfile(podiumRows[1].player.uid)),
                PodiumColumn(row: podiumRows[0], metric: app.metricFor(podiumRows[0], app.rankMode), place: 1, onTap: () => app.openProfile(podiumRows[0].player.uid)),
                if (podiumRows.length > 2)
                  PodiumColumn(row: podiumRows[2], metric: app.metricFor(podiumRows[2], app.rankMode), place: 3, onTap: () => app.openProfile(podiumRows[2].player.uid)),
              ]),
            ),
            if (rest.isNotEmpty)
              FadeSlideIn(
                delay: const Duration(milliseconds: 80),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(AppRadius.xl)),
                  child: Column(
                    children: [
                      for (var i = 0; i < rest.length; i++)
                        FadeSlideIn(
                          delay: Duration(milliseconds: 80 + i * 30),
                          child: RankRow(
                            rank: i + 4,
                            player: rest[i].player,
                            sub: app.metricFor(rest[i], app.rankMode).sub,
                            metric: app.metricFor(rest[i], app.rankMode).metric,
                            unit: app.metricFor(rest[i], app.rankMode).unit,
                            onTap: () => app.openProfile(rest[i].player.uid),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String? emoji;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, this.emoji, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.card,
          border: Border.all(color: selected ? AppColors.ink : AppColors.line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (emoji != null) ...[
              Text(emoji!, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 6),
            ],
            Text(label, style: bodyFont(size: 13, weight: FontWeight.w700, color: selected ? Colors.white : AppColors.ink2)),
          ],
        ),
      ),
    );
  }
}

/// Restricts the ranking to matches involving specific players — either
/// they're merely among the participants ("Au moins ces joueurs") or the
/// match's whole roster is exactly that list ("Exactement ces joueurs").
class _PlayerFilterSheet extends StatelessWidget {
  const _PlayerFilterSheet();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final players = app.viewPlayers;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 28 + MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Filtrer par joueurs', style: dispFont(size: 18, weight: FontWeight.w700, color: AppColors.ink)),
              if (app.rankingPlayerFilter.isNotEmpty)
                Pressable(onTap: app.clearRankingPlayerFilter, child: Text('Réinitialiser', style: bodyFont(size: 13, weight: FontWeight.w700, color: AppColors.accent))),
            ],
          ),
          const SizedBox(height: 14),
          SegmentedControl(
            labels: const ['Au moins ces joueurs', 'Exactement ces joueurs'],
            selectedIndex: app.rankingPlayerFilterExact ? 1 : 0,
            onChanged: (i) => app.setRankingPlayerFilterExact(i == 1),
            fontSize: 12,
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              app.rankingPlayerFilterExact
                  ? "Seules les parties jouées exactement par ces joueurs, sans personne d'autre, comptent."
                  : 'Les parties où ces joueurs ont participé comptent, même si d\'autres joueurs étaient aussi de la partie.',
              style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut),
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final p in players)
                    Builder(builder: (_) {
                      final selected = app.rankingPlayerFilter.contains(p.uid);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Pressable(
                          onTap: () => app.toggleRankingPlayerFilter(p.uid),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: selected ? AppColors.accentSoft : AppColors.card,
                              border: Border.all(color: selected ? AppColors.accent : AppColors.line, width: 1.5),
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                            ),
                            child: Row(
                              children: [
                                Avatar(initial: p.initial, color: Color(p.color), size: 32, fontSize: 13),
                                const SizedBox(width: 10),
                                Expanded(child: Text(p.displayName, style: bodyFont(size: 14, weight: FontWeight.w700, color: AppColors.ink))),
                                Icon(
                                  selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                                  color: selected ? AppColors.accent : AppColors.line,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
