import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/personal_records.dart';
import '../../models/game.dart';
import '../../models/match.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/personal_records.dart';
import '../../widgets/solo_match_card.dart';
import '../groups/groups_screen.dart';
import '../history/match_detail_screen.dart';
import 'solo_game_screen.dart';

/// Home tab of "Mon espace solo" (see `AppState.isPersonalContext`): a
/// "Rejouer" card to go again on the last game in one tap, the headline
/// numbers, the latest records and the last few attempts.
class SoloHomeScreen extends StatelessWidget {
  const SoloHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final matches = app.viewMatches;
    final attempts = app.soloAttempts;
    final records = app.personalRecords;
    final last = matches.isEmpty ? null : matches.reduce((a, b) => a.createdAt.isAfter(b.createdAt) ? a : b);
    final lastGame = last == null ? null : app.gameById(last.gameId);
    final recent = [...matches]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 116),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Pressable(
              behavior: HitTestBehavior.opaque,
              pressedScale: 0.97,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GroupsPage())),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: AppColors.hero, borderRadius: BorderRadius.circular(12)),
                    child: const Text('⏱️', style: TextStyle(fontSize: 19)),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Mon espace solo', overflow: TextOverflow.ellipsis, style: bodyFont(size: 18, weight: FontWeight.w800, color: AppColors.ink, letterSpacing: -0.2)),
                        Text('Rien que pour vous', overflow: TextOverflow.ellipsis, style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.expand_more, size: 18, color: AppColors.mut),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (!app.groupDataFullyLoaded)
            Padding(padding: const EdgeInsets.symmetric(vertical: 48), child: const Center(child: PodiumLoader()))
          else ...[
            FadeSlideIn(
              child: last == null || lastGame == null
                  ? const _WelcomeCard()
                  : _ReplayCard(
                      game: lastGame,
                      match: last,
                      onReplay: () => launchSoloMatch(context, app, lastGame, ruleId: lastGame.resolveRule(last.ruleId).id, setupPick: lastGame.recordPickOf(last)),
                    ),
            ),
            const SizedBox(height: 14),
            FadeSlideIn(
              delay: const Duration(milliseconds: 60),
              child: Row(
                children: [
                  StatChip(value: matches.length, label: 'parties'),
                  const SizedBox(width: 10),
                  StatChip(value: matches.map((m) => m.gameId).toSet().length, label: 'jeux'),
                  const SizedBox(width: 10),
                  StatChip(value: recordsBeaten(attempts.values), label: 'records battus'),
                ],
              ),
            ),
            const SizedBox(height: 22),
            SectionHeader(title: 'Mes records', actionLabel: records.length > 3 ? 'Tout voir' : null, onAction: () => app.setTab(AppTab.ranking)),
            PersonalRecordsList(
              records: records,
              limit: 3,
              onTap: (r) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SoloGameScreen(gameId: r.game.id, initialRuleId: r.rule.id, initialSetupPick: r.setupPick))),
            ),
            if (recent.isNotEmpty) ...[
              const SizedBox(height: 12),
              SectionHeader(title: 'Dernières parties', actionLabel: 'Historique', onAction: () => app.setTab(AppTab.history)),
              for (final (i, m) in recent.take(3).indexed)
                Builder(builder: (_) {
                  final g = app.gameById(m.gameId);
                  if (g == null) return const SizedBox.shrink();
                  return FadeSlideIn(
                    delay: Duration(milliseconds: 100 + i * 40),
                    child: SoloMatchCard(
                      game: g,
                      match: m,
                      attempt: attempts[m.id],
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MatchDetailScreen(game: g, match: m, appState: app))),
                    ),
                  );
                }),
            ],
          ],
        ],
      ),
    );
  }
}

/// "Rejouer" on the last game played, with that attempt's result — the
/// quickest way back into a session.
class _ReplayCard extends StatelessWidget {
  final Game game;
  final GameMatch match;
  final VoidCallback onReplay;
  const _ReplayCard({required this.game, required this.match, required this.onReplay});

  @override
  Widget build(BuildContext context) {
    final rule = game.resolveRule(match.ruleId);
    final detail = [if (game.hasMultipleRules) rule.name, ?game.recordPickOf(match)].join(' · ');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.hero, borderRadius: BorderRadius.circular(AppRadius.xxl)),
      child: Row(
        children: [
          Text(game.emoji, style: const TextStyle(fontSize: 34)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('DERNIER JEU', style: bodyFont(size: 11, weight: FontWeight.w800, color: Colors.white.withValues(alpha: 0.6), letterSpacing: 0.6)),
                const SizedBox(height: 2),
                Text(game.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyFont(size: 17, weight: FontWeight.w800, color: Colors.white)),
                if (detail.isNotEmpty) Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyFont(size: 12.5, weight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.7))),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Pressable(
            onTap: onReplay,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(AppRadius.md)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.replay_rounded, size: 18, color: Colors.white),
                  const SizedBox(width: 6),
                  Text('Rejouer', style: bodyFont(size: 13.5, weight: FontWeight.w800, color: Colors.white)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.hero, borderRadius: BorderRadius.circular(AppRadius.xxl)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bienvenue dans votre espace solo', style: bodyFont(size: 17, weight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 6),
          Text(
            'Contre-la-montre, speedruns, high scores… Ajoutez un jeu depuis « Mes jeux » ou le bouton +, et suivez vos records partie après partie.',
            style: bodyFont(size: 13, weight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.75)),
          ),
        ],
      ),
    );
  }
}
