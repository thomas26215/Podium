import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/game_filter.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';
import '../../widgets/common.dart';
import '../../widgets/podium.dart';
import '../../widgets/rank_row.dart';
import '../../widgets/segmented_control.dart';
import '../../widgets/theme_picker.dart';
import '../profile/profile_screen.dart';

const _modes = ['elo', 'wins', 'points', 'ratio', 'avg'];
const _modeLabels = ['Elo', 'Victoires', 'Points', 'Ratio', 'Par jeu'];

void _openProfile(BuildContext context, AppState app, String uid) {
  app.openProfile(uid);
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
}

class RankingScreen extends StatelessWidget {
  const RankingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final mode = app.effectiveRankMode;
    // Elo is Group-only for now — a Salon doesn't offer that mode at all.
    final modes = app.eloAvailable ? _modes : _modes.sublist(1);
    final labels = app.eloAvailable ? _modeLabels : _modeLabels.sublist(1);
    final rows = app.standings(
      mode,
      gameFilterId: app.gameFilter,
      gameIdsFilter: app.rankingThemeGameIds,
      participantFilter: app.rankingPlayerFilter,
      participantFilterExact: app.rankingPlayerFilterExact,
    );
    final podiumRows = rows.take(3).toList();
    final rest = rows.skip(3).toList();
    final isAvg = mode == 'avg';
    final isElo = mode == 'elo';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 116),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenHeading(eyebrow: (app.activeContext == ActiveContextKind.salon ? app.currentSalon?.name : app.currentGroup?.name) ?? '', title: 'Classement'),
          SegmentedControl(
            labels: labels,
            selectedIndex: modes.indexOf(mode),
            onChanged: (i) => app.setRankMode(modes[i]),
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
          if (isElo)
            Text(
              app.gameFilter == null
                  ? 'Tous jeux confondus, tout le monde démarre à 100. On monte en devançant des joueurs, d\'autant plus qu\'ils sont forts sur le jeu joué, et à mesure que son niveau se confirme.'
                  : 'La cote sur ce jeu seul. Elle pèse sur l\'Elo global : battre un joueur plus fort que soi à ce jeu y rapporte davantage.',
              style: bodyFont(size: 12.5, weight: FontWeight.w600, color: AppColors.mut),
            )
          else ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _FilterPill(
                  icon: Icons.people_alt_rounded,
                  label: app.rankingPlayerFilter.isEmpty
                      ? 'Filtrer par joueurs'
                      : '${app.rankingPlayerFilter.length} joueur${app.rankingPlayerFilter.length > 1 ? 's' : ''} · ${app.rankingPlayerFilterExact ? 'exactement' : 'au moins'}',
                  active: app.rankingPlayerFilter.isNotEmpty,
                  onClear: app.clearRankingPlayerFilter,
                  onTap: () => showModalBottomSheet(
                    context: context,
                    sheetAnimationStyle: appSheetAnimation,
                    backgroundColor: Colors.transparent,
                    isScrollControlled: true,
                    builder: (_) => ChangeNotifierProvider.value(value: app, child: const _PlayerFilterSheet()),
                  ),
                ),
                // Only offered once some game carries a theme — otherwise the picker would be empty.
                if (hasFilterableData(app.games))
                  _FilterPill(
                    icon: Icons.sell_outlined,
                    label: app.rankingThemes.isEmpty ? 'Filtrer par thème' : '${app.rankingThemes.length} thème${app.rankingThemes.length > 1 ? 's' : ''}',
                    active: app.rankingThemes.isNotEmpty,
                    onClear: () => app.setRankingThemes({}),
                    onTap: () async {
                      final picked = await showThemePicker(
                        context,
                        groups: themesInUse(app.games),
                        selected: app.rankingThemes.toList(),
                        title: 'Classement par thème',
                      );
                      if (picked != null) app.setRankingThemes(picked.toSet());
                    },
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          if (rows.isEmpty)
            EmptyState(
              emoji: '📊',
              message: isAvg && app.gameFilter == null
                  ? 'Choisissez un jeu pour voir ce classement.'
                  : 'Pas encore de données pour ce classement.',
            )
          else ...[
            // Keyed on the mode/filter too: switching "Victoires" → "Points"
            // replays the podium's rising bars even when the top 3 stay put.
            FadeSlideIn(
              key: ValueKey('$mode|${app.gameFilter}|${podiumRows.map((r) => r.player.uid).join(',')}'),
              child: PodiumWidget(columns: [
                if (podiumRows.length > 1)
                  PodiumColumn(row: podiumRows[1], metric: app.metricFor(podiumRows[1], mode), place: 2, onTap: () => _openProfile(context, app, podiumRows[1].player.uid)),
                PodiumColumn(row: podiumRows[0], metric: app.metricFor(podiumRows[0], mode), place: 1, onTap: () => _openProfile(context, app, podiumRows[0].player.uid)),
                if (podiumRows.length > 2)
                  PodiumColumn(row: podiumRows[2], metric: app.metricFor(podiumRows[2], mode), place: 3, onTap: () => _openProfile(context, app, podiumRows[2].player.uid)),
              ]),
            ),
            if (rest.isNotEmpty)
              FadeSlideIn(
                key: ValueKey('rest|$mode|${app.gameFilter}'),
                delay: const Duration(milliseconds: 80),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: cardDecoration(radius: AppRadius.xl),
                  child: Column(
                    children: [
                      for (var i = 0; i < rest.length; i++)
                        FadeSlideIn(
                          delay: staggerDelay(i, baseMs: 120, stepMs: 30, maxMs: 450),
                          child: RankRow(
                            rank: i + 4,
                            player: rest[i].player,
                            sub: app.metricFor(rest[i], mode).sub,
                            metric: app.metricFor(rest[i], mode).metric,
                            unit: app.metricFor(rest[i], mode).unit,
                            onTap: () => _openProfile(context, app, rest[i].player.uid),
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

/// A "Filtrer par …" pill under the game chips — accent-coloured with a
/// clear button while its filter is active.
class _FilterPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onClear;
  const _FilterPill({required this.icon, required this.label, required this.active, required this.onTap, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: chipDecoration(
          radius: AppRadius.scaled(12),
          fill: active ? AppColors.accentSoft : null,
          border: active ? AppColors.accent : null,
          borderWidth: 1.5,
          selected: active,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: active ? AppColors.accent : AppColors.mut),
            const SizedBox(width: 6),
            Text(label, style: bodyFont(size: 12.5, weight: FontWeight.w700, color: active ? AppColors.accent : AppColors.ink2)),
            if (active) ...[
              const SizedBox(width: 6),
              GestureDetector(onTap: onClear, child: Icon(Icons.close_rounded, size: 15, color: AppColors.accent)),
            ],
          ],
        ),
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
        duration: AppColors.motion.change,
        curve: AppColors.motion.changeCurve,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: chipDecoration(
          radius: AppRadius.scaled(12),
          fill: selected ? AppColors.ink : null,
          border: selected ? AppColors.ink : null,
          selected: selected,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (emoji != null) ...[
              Text(emoji!, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 6),
            ],
            Text(label, style: bodyFont(size: 13, weight: FontWeight.w700, color: selected ? AppColors.onInk : AppColors.ink2)),
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
                            duration: AppColors.motion.change,
                            curve: AppColors.motion.changeCurve,
                            padding: const EdgeInsets.all(12),
                            decoration: cardDecoration(
                              radius: AppRadius.lg,
                              fill: selected ? AppColors.accentSoft : null,
                              border: selected ? AppColors.accent : null,
                              borderWidth: 1.5,
                              selected: selected,
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
