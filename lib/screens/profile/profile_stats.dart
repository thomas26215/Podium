import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/theme_stats.dart';
import '../../state/app_state.dart';
import '../../state/player_row.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/segmented_control.dart';

/// How many games/themes the profile shows before "Voir tout".
const _previewCount = 4;

/// `uid`'s per-game stats, most played first.
List<ProfileGameStat> _gamesFor(AppState app, String uid) => app.profileGameBreakdown(uid)..sort((a, b) => b.played.compareTo(a.played));

/// `uid`'s per-theme stats, most played first (see [themeStats]).
List<ThemeStat> _themesFor(AppState app, String uid) => themeStats(app.profileGameBreakdown(uid));

/// The profile's compact stats card: "Par jeu" / "Par thème" behind one
/// toggle, only the top few rows each, the full lists one tap away in
/// [ProfileStatsScreen] — instead of two ever-growing lists on the profile.
class ProfileStatsCard extends StatefulWidget {
  final String uid;
  const ProfileStatsCard({super.key, required this.uid});

  @override
  State<ProfileStatsCard> createState() => _ProfileStatsCardState();
}

class _ProfileStatsCardState extends State<ProfileStatsCard> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final games = _gamesFor(app, widget.uid);
    final themes = _themesFor(app, widget.uid);
    final tab = themes.isEmpty ? 0 : _tab;
    final total = tab == 0 ? games.length : themes.length;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      decoration: cardDecoration(radius: AppRadius.xl),
      child: games.isEmpty
          ? const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: EmptyState(emoji: '🎮', message: 'Pas encore de partie jouée.'))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (themes.isNotEmpty) ...[
                  SegmentedControl(labels: const ['Par jeu', 'Par thème'], selectedIndex: tab, onChanged: (i) => setState(() => _tab = i), fontSize: 13),
                  const SizedBox(height: 4),
                ],
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: appSwitchTransition,
                    layoutBuilder: (current, previous) => Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
                    child: Column(
                      key: ValueKey(tab),
                      children: [
                        if (tab == 0)
                          for (final (i, g) in games.take(_previewCount).indexed) GameStatRow(stat: g, uid: widget.uid, divider: i > 0)
                        else
                          for (final (i, t) in themes.take(_previewCount).indexed) ThemeStatRow(stat: t, divider: i > 0),
                      ],
                    ),
                  ),
                ),
                if (total > _previewCount)
                  Pressable(
                    behavior: HitTestBehavior.opaque,
                    dimOnPress: true,
                    pressedScale: 0.98,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProfileStatsScreen(uid: widget.uid, initialTab: tab))),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.line))),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            tab == 0 ? 'Voir les $total jeux' : 'Voir les $total thèmes',
                            style: bodyFont(size: 13.5, weight: FontWeight.w800, color: AppColors.accent),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.accent),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Every game and theme `uid` has played in the active group/salon.
class ProfileStatsScreen extends StatefulWidget {
  final String uid;
  final int initialTab;
  const ProfileStatsScreen({super.key, required this.uid, this.initialTab = 0});

  @override
  State<ProfileStatsScreen> createState() => _ProfileStatsScreenState();
}

class _ProfileStatsScreenState extends State<ProfileStatsScreen> {
  late int _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final user = app.playerById(widget.uid);
    final games = _gamesFor(app, widget.uid);
    final themes = _themesFor(app, widget.uid);
    final tab = themes.isEmpty ? 0 : _tab;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.canvas,
        elevation: 0,
        foregroundColor: AppColors.ink,
        title: Text(
          widget.uid == app.currentUser?.uid ? 'Mes statistiques' : 'Statistiques de ${user?.displayName ?? 'ce joueur'}',
          style: bodyFont(size: 17, weight: FontWeight.w800, color: AppColors.ink),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          if (themes.isNotEmpty) ...[
            SegmentedControl(
              labels: ['Par jeu · ${games.length}', 'Par thème · ${themes.length}'],
              selectedIndex: tab,
              onChanged: (i) => setState(() => _tab = i),
              fontSize: 13,
            ),
            const SizedBox(height: 14),
          ],
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
            decoration: cardDecoration(radius: AppRadius.xl),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: appSwitchTransition,
              child: Column(
                key: ValueKey(tab),
                children: [
                  if (tab == 0)
                    for (final (i, g) in games.indexed) FadeSlideIn(delay: staggerDelay(i, stepMs: 30), child: GameStatRow(stat: g, uid: widget.uid, divider: i > 0))
                  else
                    for (final (i, t) in themes.indexed) FadeSlideIn(delay: staggerDelay(i, stepMs: 30), child: ThemeStatRow(stat: t, divider: i > 0)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One game's line: emoji, games played/won (and per-game Elo in a
/// group), average score.
class GameStatRow extends StatelessWidget {
  final ProfileGameStat stat;
  final String uid;
  final bool divider;
  const GameStatRow({super.key, required this.stat, required this.uid, this.divider = true});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final elo = app.groupElo.gameRatings[stat.game.id]?[uid];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
      decoration: BoxDecoration(border: divider ? Border(top: BorderSide(color: AppColors.line)) : null),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: wellDecoration(radius: AppRadius.scaled(11)),
            child: Text(stat.game.emoji, style: const TextStyle(fontSize: 19)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(stat.game.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyFont(size: 15, weight: FontWeight.w700, color: AppColors.ink)),
                Text(
                  '${stat.played} partie${stat.played > 1 ? 's' : ''} · ${stat.wins} V${elo != null ? ' · ${elo.round()} Elo' : ''}',
                  style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(stat.avg.toStringAsFixed(1), style: dispFont(size: 16, weight: FontWeight.w700, color: AppColors.ink)),
              Text('moy. pts', style: bodyFont(size: 11, weight: FontWeight.w600, color: AppColors.mut)),
            ],
          ),
        ],
      ),
    );
  }
}

/// One theme's line: games played/won and its winrate, with a bar.
class ThemeStatRow extends StatelessWidget {
  final ThemeStat stat;
  final bool divider;
  const ThemeStatRow({super.key, required this.stat, this.divider = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
      decoration: BoxDecoration(border: divider ? Border(top: BorderSide(color: AppColors.line)) : null),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(stat.tag.label, style: bodyFont(size: 15, weight: FontWeight.w700, color: AppColors.ink)),
                    Text('${stat.played} partie${stat.played > 1 ? 's' : ''} · ${stat.wins} V', style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut)),
                  ],
                ),
              ),
              Text('${(stat.ratio * 100).round()}%', style: dispFont(size: 16, weight: FontWeight.w700, color: AppColors.ink)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: stat.ratio),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => LinearProgressIndicator(value: v, minHeight: 5, color: AppColors.accent, backgroundColor: AppColors.segTrack),
            ),
          ),
        ],
      ),
    );
  }
}
