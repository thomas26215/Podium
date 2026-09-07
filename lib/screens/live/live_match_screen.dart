import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/match.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';
import '../../widgets/common.dart';
import '../../widgets/live_match_card.dart';
import '../../widgets/match_card.dart';
import '../../widgets/score_evolution_chart.dart';

/// Read-only, real-time view of a match someone else in the group is
/// currently scoring — the scores update live as they play, no
/// interaction needed. Watches [AppState.liveSessions] (already a live
/// Firestore subscription) rather than opening a second listener.
class LiveMatchScreen extends StatelessWidget {
  final String sessionId;
  const LiveMatchScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final session = app.liveSessions.where((s) => s.id == sessionId).firstOrNull;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        foregroundColor: AppColors.ink,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: session?.held == true
              ? [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.mut, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text('Partie hors ligne', style: bodyFont(size: 17, weight: FontWeight.w800, color: AppColors.ink)),
                ]
              : [
                  const LiveDot(),
                  const SizedBox(width: 8),
                  Text('Partie en direct', style: bodyFont(size: 17, weight: FontWeight.w800, color: AppColors.ink)),
                ],
        ),
      ),
      body: session == null
          ? Center(child: EmptyState(emoji: '🏁', message: "Cette partie n'est plus diffusée en direct (terminée, ou son auteur·ice est hors connexion)."))
          : _LiveMatchBody(session: session, app: app),
    );
  }
}

class _LiveMatchBody extends StatelessWidget {
  final LiveMatchSession session;
  final AppState app;
  const _LiveMatchBody({required this.session, required this.app});

  @override
  Widget build(BuildContext context) {
    final game = app.gameById(session.gameId);
    final sorted = [...session.entries]..sort((a, b) => session.lowWins ? a.points.compareTo(b.points) : b.points.compareTo(a.points));
    final bestPoints = sorted.isEmpty ? null : sorted.first.points;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Row(
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(16)),
              child: Text(game?.emoji ?? '🎲', style: const TextStyle(fontSize: 26)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(game?.name ?? 'Partie', style: bodyFont(size: 19, weight: FontWeight.w800, color: AppColors.ink)),
                  Text('Débutée par ${session.startedByName}', style: bodyFont(size: 12.5, weight: FontWeight.w600, color: AppColors.mut)),
                ],
              ),
            ),
          ],
        ),
        if (session.held) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(AppRadius.lg)),
            child: Row(
              children: [
                Icon(Icons.wifi_off_rounded, size: 16, color: AppColors.mut),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "${session.startedByName} est hors ligne — les scores affichés sont les derniers connus.",
                    style: bodyFont(size: 12.5, weight: FontWeight.w700, color: AppColors.mut),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        if (sorted.isEmpty)
          const EmptyState(emoji: '⏳', message: "La partie vient de commencer, les scores n'ont pas encore été saisis.")
        else
          for (final entry in sorted)
            Builder(builder: (_) {
              final p = app.playerById(entry.playerId);
              final isLead = entry.points == bestPoints;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                margin: const EdgeInsets.only(bottom: 9),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isLead ? AppColors.greenSoft : AppColors.card,
                  border: Border.all(color: isLead ? AppColors.green : AppColors.line, width: 1.5),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Row(
                  children: [
                    Avatar(initial: p?.initial ?? '?', color: p != null ? Color(p.color) : AppColors.mut, size: 38, fontSize: 15),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p?.displayName ?? '?', style: bodyFont(size: 15, weight: FontWeight.w700, color: AppColors.ink)),
                          if (entry.teamId != null)
                            Text('Équipe ${entry.teamId}', style: bodyFont(size: 11.5, weight: FontWeight.w700, color: AppColors.mut)),
                          if (entry.role != null)
                            Text(entry.role!, style: bodyFont(size: 11.5, weight: FontWeight.w700, color: AppColors.accent)),
                        ],
                      ),
                    ),
                    AnimatedCounter(value: entry.points, style: dispFont(size: 22, weight: FontWeight.w700, color: AppColors.ink)),
                  ],
                ),
              );
            }),
        if (session.inputMode == 'rounds' && session.timeline.isNotEmpty) ..._roundsSection(app, session),
        if (session.inputMode == 'live' && session.timeline.isNotEmpty) ..._liveFeedSection(app, session),
      ],
    );
  }

  /// Same "MANCHES JOUÉES" table + evolution chart as `_RoundsScoreInput`/
  /// `_RanksRoundsInput` in the real scoring screen (step3_scores.dart) —
  /// no undo button here, this is a spectator view.
  List<Widget> _roundsSection(AppState app, LiveMatchSession session) {
    final rounds = app.roundsFromTimeline(session.timeline, session.entries.length);
    if (rounds.isEmpty) return const [];
    return [
      const SizedBox(height: 20),
      Text('MANCHES JOUÉES', style: bodyFont(size: 11.5, weight: FontWeight.w800, color: AppColors.mut, letterSpacing: 0.5)),
      const SizedBox(height: 9),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line, width: 1.5), borderRadius: BorderRadius.circular(AppRadius.lg)),
        child: Column(
          children: [
            for (final (i, round) in rounds.indexed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(width: 60, child: Text('Manche ${i + 1}', style: bodyFont(size: 12.5, weight: FontWeight.w700, color: AppColors.mut))),
                    Expanded(
                      child: Wrap(
                        spacing: 10,
                        children: [
                          for (final t in round)
                            Text(
                              '${app.playerById(t.playerId)?.displayName ?? '?'} ${t.delta >= 0 ? '+' : ''}${t.delta}',
                              style: bodyFont(size: 12.5, weight: FontWeight.w700, color: AppColors.ink),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      Text('ÉVOLUTION DES SCORES', style: bodyFont(size: 11.5, weight: FontWeight.w800, color: AppColors.mut, letterSpacing: 0.5)),
      const SizedBox(height: 9),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line, width: 1.5), borderRadius: BorderRadius.circular(AppRadius.lg)),
        child: ScoreEvolutionChart(timeline: session.timeline, appState: app),
      ),
    ];
  }

  /// Read-only mirror of the "En direct" timeline feed shown while scoring
  /// (step3_scores.dart) — same list, no undo button.
  List<Widget> _liveFeedSection(AppState app, LiveMatchSession session) {
    return [
      const SizedBox(height: 20),
      Text('HISTORIQUE', style: bodyFont(size: 11.5, weight: FontWeight.w800, color: AppColors.mut, letterSpacing: 0.5)),
      const SizedBox(height: 9),
      Container(
        constraints: const BoxConstraints(maxHeight: 220),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line, width: 1.5), borderRadius: BorderRadius.circular(AppRadius.lg)),
        child: ListView(
          shrinkWrap: true,
          reverse: true,
          children: [
            for (final t in session.timeline.reversed)
              Builder(builder: (_) {
                final p = app.playerById(t.playerId);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  child: Row(
                    children: [
                      Avatar(initial: p?.initial ?? '?', color: p != null ? Color(p.color) : AppColors.mut, size: 28, fontSize: 11),
                      const SizedBox(width: 10),
                      Expanded(child: Text('${p?.displayName ?? '?'} ${t.delta >= 0 ? '+' : ''}${t.delta}', style: bodyFont(size: 13, weight: FontWeight.w700, color: AppColors.ink))),
                      Text(hhmm(t.time), style: bodyFont(size: 11.5, weight: FontWeight.w600, color: AppColors.mut)),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
      const SizedBox(height: 20),
      Text('ÉVOLUTION DES SCORES', style: bodyFont(size: 11.5, weight: FontWeight.w800, color: AppColors.mut, letterSpacing: 0.5)),
      const SizedBox(height: 9),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line, width: 1.5), borderRadius: BorderRadius.circular(AppRadius.lg)),
        child: ScoreEvolutionChart(timeline: session.timeline, appState: app),
      ),
    ];
  }
}
