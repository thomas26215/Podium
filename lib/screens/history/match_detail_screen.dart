import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/game.dart';
import '../../models/match.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';
import '../../widgets/common.dart';
import '../../widgets/match_card.dart';
import '../../widgets/score_evolution_chart.dart';
import '../new_game/new_game_sheet.dart';

/// Full breakdown of a single match: hero result banner, per-player/team
/// scores, and — for round-synced matches (Par manche / Plusieurs manches)
/// — the score-evolution chart plus a round-by-round table. Reached by
/// tapping a condensed [MatchCard] in the history list.
class MatchDetailScreen extends StatelessWidget {
  final Game game;
  final GameMatch match;
  final AppState appState;
  const MatchDetailScreen({super.key, required this.game, required this.match, required this.appState});

  List<String> get _winners => match.winnerIds();

  @override
  Widget build(BuildContext context) {
    final unitLabel = match.unit == 'wins' ? ' · Manches' : '';
    final modeLabel = match.isCoop ? ' · Coopératif$unitLabel' : (match.isTeam ? ' · Équipes$unitLabel' : unitLabel);
    final rounds = _rounds();
    final isRoundSynced = match.resolvedInputMode == 'rounds';

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.ink),
        title: Text(
          match.seriesId != null ? 'Partie ${match.seriesGame}/${match.seriesLength} · ${game.category}$modeLabel' : '${game.category}$modeLabel',
          style: bodyFont(size: 13, weight: FontWeight.w700, color: AppColors.mut),
        ),
        actions: [
          if (appState.canDeleteMatch(match))
            IconButton(
              onPressed: () => _confirmDelete(context),
              icon: Icon(Icons.delete_outline_rounded, color: AppColors.mut),
              tooltip: 'Supprimer cette partie',
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeSlideIn(child: _hero()),
              if (match.isSalonMatch) ...[
                const SizedBox(height: 16),
                FadeSlideIn(delay: const Duration(milliseconds: 40), child: _confirmationCard(context)),
              ],
              const SizedBox(height: 22),
              FadeSlideIn(delay: const Duration(milliseconds: 60), child: match.isCoop ? _coopCard() : (match.isTeam ? _teamBlocks() : _ffaCard())),
              if (match.hasTimeline) ...[
                const SizedBox(height: 22),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 120),
                  child: _sectionCard(
                    title: 'ÉVOLUTION DES SCORES',
                    child: ScoreEvolutionChart(timeline: match.timeline, appState: appState),
                  ),
                ),
                const SizedBox(height: 22),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 180),
                  child: _sectionCard(
                    title: isRoundSynced ? 'MANCHES' : 'CHRONOLOGIE',
                    child: isRoundSynced ? _roundsTable(rounds) : _chronology(),
                  ),
                ),
              ],
              if (!(match.isSalonMatch ? appState.activeContextClosed : appState.isGroupIdClosed(match.groupId))) ...[
                const SizedBox(height: 22),
                FadeSlideIn(
                  delay: Duration(milliseconds: match.hasTimeline ? 240 : 120),
                  child: OutlinedButton.icon(
                    onPressed: () => _resume(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.ink,
                      side: BorderSide(color: AppColors.line, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                      minimumSize: const Size.fromHeight(0),
                    ),
                    icon: const Icon(Icons.replay_rounded, size: 20),
                    label: Text('Reprendre cette partie', style: bodyFont(size: 14, weight: FontWeight.w700, color: AppColors.ink)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final isLeg = match.seriesId != null;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
        title: Text(isLeg ? 'Supprimer cette partie de la série ?' : 'Supprimer cette partie ?', style: dispFont(size: 18, weight: FontWeight.w700, color: AppColors.ink)),
        content: Text(
          isLeg
              ? "Cette action est définitive : seule cette manche (Partie ${match.seriesGame}/${match.seriesLength}) sera supprimée, le reste de la série n'est pas affecté."
              : "Cette action est définitive : le classement sera recalculé sans cette partie.",
          style: bodyFont(size: 14, weight: FontWeight.w600, color: AppColors.mut),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Supprimer', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) {
      final ok = await appState.deleteMatch(match);
      if (ok && context.mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _resume(BuildContext context) async {
    appState.resumeMatch(match, game);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x6B141318),
      enableDrag: false,
      isDismissible: false,
      builder: (_) => ChangeNotifierProvider.value(value: appState, child: const NewGameSheet()),
    );
    // Only leave the detail screen if the resume actually got saved
    // (isEditingMatch is cleared by saveGame() on success) — if the sheet
    // was just dismissed without saving, stay put.
    final saved = !appState.isEditingMatch;
    appState.closeSheet();
    if (saved && context.mounted) Navigator.of(context).pop();
  }

  Widget _hero() {
    final resultLine = matchResultLine(game, match, appState);
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
              decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [AppColors.accent.withValues(alpha: 0.5), Colors.transparent])),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(game.emoji, style: const TextStyle(fontSize: 30)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(game.name, style: dispFont(size: 22, weight: FontWeight.w800, color: Colors.white, letterSpacing: -0.3)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (resultLine.isNotEmpty) Text(resultLine, style: bodyFont(size: 15, weight: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 4),
              Text(relativeDateLabel(match.createdAt), style: bodyFont(size: 12.5, weight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.6))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(AppRadius.xl)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: bodyFont(size: 11.5, weight: FontWeight.w800, color: AppColors.mut, letterSpacing: 0.5)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  /// Status banner + confirm/reject actions for a Salon match (see
  /// GameMatch.status) — irrelevant for a Group match, never called there.
  Widget _confirmationCard(BuildContext context) {
    final uid = appState.currentUser?.uid;
    final needsMyConfirmation = uid != null && match.requiredConfirmers.contains(uid) && !(match.confirmedBy ?? const []).contains(uid) && !match.isRejected;
    final (label, color) = switch (match.status) {
      'confirmed' => ('Confirmée par tous les joueurs', AppColors.ink2),
      'rejected' => ('Refusée — en attente de correction par son auteur', AppColors.accent),
      _ => ('En attente de confirmation', AppColors.accent),
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                switch (match.status) { 'confirmed' => Icons.check_circle_rounded, 'rejected' => Icons.cancel_rounded, _ => Icons.hourglass_top_rounded },
                size: 18,
                color: color,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(label, style: bodyFont(size: 13, weight: FontWeight.w700, color: color))),
            ],
          ),
          if (needsMyConfirmation) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => appState.rejectMatch(match),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accent,
                      side: BorderSide(color: AppColors.accent, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    ),
                    child: const Text('Refuser'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PrimaryButton(label: 'Confirmer', onPressed: () => appState.confirmMatch(match)),
                ),
              ],
            ),
          ] else if (match.isPending) ...[
            const SizedBox(height: 6),
            Text(
              'En attente de : ${match.requiredConfirmers.where((id) => !(match.confirmedBy ?? const []).contains(id)).map((id) => appState.playerById(id)?.displayName ?? id).join(', ')}',
              style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut),
            ),
          ],
          if (appState.canEditRejectedMatch(match)) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _resume(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.ink,
                side: BorderSide(color: AppColors.line, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
              ),
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: const Text('Corriger et renvoyer'),
            ),
          ],
        ],
      ),
    );
  }

  bool get _isWinLoss => game.resolveRule(match.ruleId).isWinLoss;

  Widget _ffaCard() {
    if (match.hasScoreBreakdown) {
      return _detailedBreakdownCard();
    }
    final winners = _winners;
    final isWinLoss = _isWinLoss;
    final sorted = [...match.entries]..sort((a, b) => match.lowWins ? a.points.compareTo(b.points) : b.points.compareTo(a.points));
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(AppRadius.xl)),
      child: Column(
        children: sorted.map((e) {
          final p = appState.playerById(e.playerId);
          final win = winners.contains(e.playerId);
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(color: win ? AppColors.greenSoft : null, borderRadius: BorderRadius.circular(11)),
            child: Row(
              children: [
                _memberAvatar(e.playerId),
                const SizedBox(width: 10),
                Expanded(child: Text(p?.displayName ?? '?', style: bodyFont(size: 14.5, weight: FontWeight.w700, color: AppColors.ink))),
                if (win)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                    child: Text(isWinLoss ? 'VICTOIRE' : '1ER', style: bodyFont(size: 10, weight: FontWeight.w800, color: AppColors.green, letterSpacing: 0.3)),
                  ),
                if (isWinLoss)
                  (win ? const SizedBox.shrink() : Text('Défaite', style: bodyFont(size: 12.5, weight: FontWeight.w700, color: AppColors.mut)))
                else if (e.role != null)
                  Text(e.role!, style: bodyFont(size: 13.5, weight: FontWeight.w800, color: AppColors.ink2))
                else
                  AnimatedCounter(value: e.points, style: dispFont(size: 16, weight: FontWeight.w700, color: AppColors.ink)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _detailedBreakdownCard() {
    final fields = match.scoreFields ?? const [];
    final sorted = [...match.entries]..sort((a, b) => match.lowWins ? a.points.compareTo(b.points) : b.points.compareTo(a.points));
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(AppRadius.xl)),
      child: Column(
        children: [
          for (final entry in sorted)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bg,
                border: Border.all(color: AppColors.line, width: 1.2),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _memberAvatar(entry.playerId),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(appState.playerById(entry.playerId)?.displayName ?? '?', style: bodyFont(size: 14.5, weight: FontWeight.w700, color: AppColors.ink)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(999)),
                        child: AnimatedCounter(value: entry.points, style: bodyFont(size: 13, weight: FontWeight.w800, color: Colors.white)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (fields.isNotEmpty)
                    for (final field in fields)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: Row(
                          children: [
                            Container(width: 10, height: 10, decoration: BoxDecoration(color: Color(field.color), shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Expanded(child: Text(field.label, style: bodyFont(size: 12.5, weight: FontWeight.w700, color: AppColors.ink2))),
                            AnimatedCounter(value: entry.scoreBreakdown?[field.id] ?? 0, style: bodyFont(size: 12.5, weight: FontWeight.w800, color: AppColors.ink)),
                          ],
                        ),
                      )
                  else
                    for (final item in (entry.scoreBreakdown ?? {}).entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: Row(
                          children: [
                            Icon(Icons.circle, size: 10, color: AppColors.mut),
                            const SizedBox(width: 8),
                            Expanded(child: Text(item.key, style: bodyFont(size: 12.5, weight: FontWeight.w700, color: AppColors.ink2))),
                            AnimatedCounter(value: item.value, style: bodyFont(size: 12.5, weight: FontWeight.w800, color: AppColors.ink)),
                          ],
                        ),
                      ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Single shared-outcome card for a coop match — every entry carries the
  /// same points value by construction (see AppState.setCoopPoints), so
  /// there's nothing to break down per player.
  Widget _coopCard() {
    final isWin = _winners.isNotEmpty;
    final isWinLoss = _isWinLoss || match.unit == 'wins';
    final score = match.entries.firstOrNull?.points ?? 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: isWinLoss && isWin ? AppColors.green : AppColors.line, width: 1.5),
        color: isWinLoss && isWin ? AppColors.greenSoft : AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Row(children: [for (final e in match.entries) Padding(padding: const EdgeInsets.only(right: 7), child: _memberAvatar(e.playerId))]),
          const SizedBox(width: 10),
          Expanded(child: Text('Le groupe', style: bodyFont(size: 14.5, weight: FontWeight.w700, color: AppColors.ink))),
          if (isWinLoss)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: isWin ? AppColors.green : AppColors.bg, borderRadius: BorderRadius.circular(999)),
              child: Text(
                isWin ? 'VICTOIRE' : 'DÉFAITE',
                style: bodyFont(size: 11, weight: FontWeight.w800, color: isWin ? Colors.white : AppColors.mut, letterSpacing: 0.3),
              ),
            )
          else
            AnimatedCounter(value: score, style: dispFont(size: 18, weight: FontWeight.w700, color: AppColors.ink)),
        ],
      ),
    );
  }

  Widget _teamBlocks() {
    final winners = _winners;
    final teamIds = <String>[];
    for (final e in match.entries) {
      if (!teamIds.contains(e.teamId)) teamIds.add(e.teamId ?? 'A');
    }
    teamIds.sort();
    return Column(
      children: teamIds.map((t) {
        final es = match.entries.where((e) => (e.teamId ?? 'A') == t).toList();
        final pts = es.fold<int>(0, (s, e) => s + e.points);
        final win = es.isNotEmpty && winners.contains(es.first.playerId);
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: win ? AppColors.green : AppColors.line, width: 1.5),
            color: win ? AppColors.greenSoft : AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('ÉQUIPE $t', style: bodyFont(size: 13, weight: FontWeight.w800, color: AppColors.ink, letterSpacing: 0.3)),
                  Row(children: [
                    if (win)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                        child: Text('GAGNE', style: bodyFont(size: 10, weight: FontWeight.w800, color: AppColors.green, letterSpacing: 0.3)),
                      ),
                    AnimatedCounter(value: pts, style: dispFont(size: 18, weight: FontWeight.w700, color: AppColors.ink)),
                  ]),
                ],
              ),
              const SizedBox(height: 10),
              Row(children: [for (final e in es) Padding(padding: const EdgeInsets.only(right: 7), child: _memberAvatar(e.playerId))]),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _memberAvatar(String uid) {
    final p = appState.playerById(uid);
    return Avatar(initial: p?.initial ?? '?', color: p != null ? Color(p.color) : AppColors.mut, size: 32, fontSize: 13);
  }

  List<List<TimelinePoint>> _rounds() {
    final n = match.entries.length;
    if (n == 0) return const [];
    final rounds = <List<TimelinePoint>>[];
    for (var i = 0; i < match.timeline.length; i += n) {
      rounds.add(match.timeline.sublist(i, (i + n).clamp(0, match.timeline.length)));
    }
    return rounds;
  }

  Widget _chronology() {
    return Column(
      children: [
        for (final t in match.timeline)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                _memberAvatar(t.playerId),
                const SizedBox(width: 9),
                Expanded(child: Text('${appState.playerById(t.playerId)?.displayName ?? '?'} ${t.delta >= 0 ? '+' : ''}${t.delta}', style: bodyFont(size: 13, weight: FontWeight.w700, color: AppColors.ink))),
                Text(hhmm(t.time), style: bodyFont(size: 11.5, weight: FontWeight.w600, color: AppColors.mut)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _roundsTable(List<List<TimelinePoint>> rounds) {
    final playerIds = rounds.first.map((t) => t.playerId).toList();
    const roundColWidth = 56.0;
    const playerColWidth = 68.0;

    Widget cell(String s, {bool bold = false}) => SizedBox(
          width: playerColWidth,
          child: Text(s, textAlign: TextAlign.center, style: bodyFont(size: 12.5, weight: bold ? FontWeight.w800 : FontWeight.w700, color: bold ? AppColors.ink : AppColors.mut)),
        );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(width: roundColWidth),
              for (final uid in playerIds) SizedBox(width: playerColWidth, child: Center(child: _memberAvatar(uid))),
            ],
          ),
          const SizedBox(height: 8),
          for (final (i, round) in rounds.indexed)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(color: i.isEven ? AppColors.bg : Colors.transparent, borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  SizedBox(width: roundColWidth, child: Text('M${i + 1}', style: bodyFont(size: 12.5, weight: FontWeight.w700, color: AppColors.mut))),
                  for (final uid in playerIds)
                    Builder(builder: (_) {
                      final t = round.where((e) => e.playerId == uid);
                      final delta = t.isEmpty ? 0 : t.first.delta;
                      return cell('${delta >= 0 ? '+' : ''}$delta');
                    }),
                ],
              ),
            ),
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.line))),
            child: Row(
              children: [
                SizedBox(width: roundColWidth, child: Text('Total', style: bodyFont(size: 12.5, weight: FontWeight.w800, color: AppColors.ink))),
                for (final uid in playerIds)
                  Builder(builder: (_) {
                    final e = match.entries.where((e) => e.playerId == uid);
                    return cell(e.isEmpty ? '0' : '${e.first.points}', bold: true);
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
