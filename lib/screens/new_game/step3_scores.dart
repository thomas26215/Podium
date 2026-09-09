import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../models/game.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';
import '../../widgets/common.dart';
import '../../widgets/match_card.dart';
import '../../widgets/score_evolution_chart.dart';
import '../../widgets/segmented_control.dart';

/// Scoring UI for [CountType.ranks] games (Président & co.): instead of
/// entering points, you order the players from 1st to last and the app
/// maps each position to the game's named role (and its points, under the
/// hood) via [Game.rankRole]/[Game.rankPoints].
class _RanksScoreList extends StatelessWidget {
  final Game game;
  const _RanksScoreList({required this.game});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final order = app.draft.rankOrder;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Classez les joueurs du 1er au dernier.', style: bodyFont(size: 13, weight: FontWeight.w700, color: AppColors.mut)),
        const SizedBox(height: 14),
        for (final (i, uid) in order.indexed)
          Builder(builder: (_) {
            final p = app.playerById(uid);
            if (p == null) return const SizedBox.shrink();
            final role = game.rankRole(i, order.length);
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.only(bottom: 9),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line, width: 1.5), borderRadius: BorderRadius.circular(AppRadius.lg)),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: AppColors.ink, shape: BoxShape.circle),
                    child: Text('${i + 1}', style: bodyFont(size: 13, weight: FontWeight.w800, color: Colors.white)),
                  ),
                  const SizedBox(width: 12),
                  Avatar(initial: p.initial, color: Color(p.color), size: 38, fontSize: 15),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.displayName, style: bodyFont(size: 15, weight: FontWeight.w700, color: AppColors.ink)),
                        if (role != null) Text(role, style: bodyFont(size: 12, weight: FontWeight.w700, color: AppColors.accent)),
                      ],
                    ),
                  ),
                  _stepperButton(Icons.keyboard_arrow_up, i == 0 ? null : () => app.moveRankUp(uid)),
                  _stepperButton(Icons.keyboard_arrow_down, i == order.length - 1 ? null : () => app.moveRankDown(uid)),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _stepperButton(IconData icon, VoidCallback? onTap) => _rankStepperButton(icon, onTap);
}

Widget _rankStepperButton(IconData icon, VoidCallback? onTap) {
  return Pressable(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 34,
      height: 34,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: onTap == null ? Colors.transparent : AppColors.bg, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(11)),
      child: Icon(icon, size: 18, color: onTap == null ? AppColors.line : AppColors.ink),
    ),
  );
}

/// Multi-round variant of [_RanksScoreList] (Président played over several
/// hands, say): rank the players for the current round, submit it (points
/// accumulate via [AppState.submitRankRound]), then review past rounds and
/// the cumulative score-evolution chart — same review UI as [_RoundsScoreInput].
class _RanksRoundsInput extends StatelessWidget {
  final Game game;
  const _RanksRoundsInput({required this.game});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final d = app.draft;
    final order = d.rankOrder;
    final rounds = app.draftRounds;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Manche ${rounds.length + 1} — classez les joueurs du 1er au dernier.', style: bodyFont(size: 13, weight: FontWeight.w700, color: AppColors.mut)),
        const SizedBox(height: 14),
        for (final (i, uid) in order.indexed)
          Builder(builder: (_) {
            final p = app.playerById(uid);
            if (p == null) return const SizedBox.shrink();
            final role = game.rankRole(i, order.length);
            return Container(
              margin: const EdgeInsets.only(bottom: 9),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line, width: 1.5), borderRadius: BorderRadius.circular(AppRadius.lg)),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: AppColors.ink, shape: BoxShape.circle),
                    child: Text('${i + 1}', style: bodyFont(size: 13, weight: FontWeight.w800, color: Colors.white)),
                  ),
                  const SizedBox(width: 12),
                  Avatar(initial: p.initial, color: Color(p.color), size: 38, fontSize: 15),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.displayName, style: bodyFont(size: 15, weight: FontWeight.w700, color: AppColors.ink)),
                        if (role != null) Text(role, style: bodyFont(size: 12, weight: FontWeight.w700, color: AppColors.accent)),
                      ],
                    ),
                  ),
                  _rankStepperButton(Icons.keyboard_arrow_up, i == 0 ? null : () => app.moveRankUp(uid)),
                  _rankStepperButton(Icons.keyboard_arrow_down, i == order.length - 1 ? null : () => app.moveRankDown(uid)),
                ],
              ),
            );
          }),
        const SizedBox(height: 6),
        PrimaryButton(label: 'Valider la manche', onPressed: () => app.submitRankRound()),
        if (rounds.isNotEmpty) ...[
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('MANCHES JOUÉES', style: bodyFont(size: 11.5, weight: FontWeight.w800, color: AppColors.mut, letterSpacing: 0.5)),
              Pressable(
                onTap: () => app.undoRound(),
                child: Text('↶ Annuler la dernière', style: bodyFont(size: 12, weight: FontWeight.w700, color: AppColors.accent)),
              ),
            ],
          ),
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
            child: ScoreEvolutionChart(timeline: d.timeline, appState: app),
          ),
        ],
      ],
    );
  }
}

/// Two-way "Défaite"/"Victoire" pill, shared by [_WinLossScoreList] and
/// [_WinLossRoundsInput].
class _WinLossToggle extends StatelessWidget {
  final bool isWin;
  final ValueChanged<bool> onChanged;
  const _WinLossToggle({required this.isWin, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: AppColors.bg, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(11)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _pill('Défaite', !isWin, AppColors.ink, () => onChanged(false)),
          _pill('Victoire', isWin, AppColors.green, () => onChanged(true)),
        ],
      ),
    );
  }

  Widget _pill(String label, bool selected, Color activeColor, VoidCallback onTap) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: selected ? activeColor : null, borderRadius: BorderRadius.circular(8)),
        child: Text(label, style: bodyFont(size: 12.5, weight: FontWeight.w800, color: selected ? Colors.white : AppColors.mut)),
      ),
    );
  }
}

/// Scoring UI for [CountType.winLoss] games: no score at all, just mark
/// each player victorious or defeated — for a single manche (see
/// [_WinLossRoundsInput] for the "plusieurs manches" variant).
class _WinLossScoreList extends StatelessWidget {
  const _WinLossScoreList();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final d = app.draft;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Marquez qui a gagné et qui a perdu.', style: bodyFont(size: 13, weight: FontWeight.w700, color: AppColors.mut)),
        const SizedBox(height: 14),
        for (final uid in d.playerIds)
          Builder(builder: (_) {
            final p = app.playerById(uid);
            if (p == null) return const SizedBox.shrink();
            final isWin = (d.points[uid] ?? 0) > 0;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 9),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isWin ? AppColors.greenSoft : AppColors.card,
                border: Border.all(color: isWin ? AppColors.green : AppColors.line, width: 1.5),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Row(
                children: [
                  Avatar(initial: p.initial, color: Color(p.color), size: 38, fontSize: 15),
                  const SizedBox(width: 12),
                  Expanded(child: Text(p.displayName, style: bodyFont(size: 15, weight: FontWeight.w700, color: AppColors.ink))),
                  _WinLossToggle(isWin: isWin, onChanged: (win) => app.setPoints(uid, win ? 1 : 0)),
                ],
              ),
            );
          }),
      ],
    );
  }
}

/// Multi-round variant of [_WinLossScoreList]: mark winners/losers for the
/// current round, submit it (accumulates a running win count per player via
/// [AppState.addRound]), then review past rounds and the cumulative
/// score-evolution chart — same review UI as [_RoundsScoreInput]. Also
/// reused for the generic "Manches gagnées" unit (any highWins/lowWins
/// game, not just [CountType.winLoss]) — see [Step3Scores]/`AppState.setUnit`
/// — since both need the same guarantee: one declared winner per manche,
/// so the tally can never drift from how many manches were actually played.
/// In team mode a whole team wins or loses a manche together.
class _WinLossRoundsInput extends StatefulWidget {
  const _WinLossRoundsInput();

  @override
  State<_WinLossRoundsInput> createState() => _WinLossRoundsInputState();
}

class _WinLossRoundsInputState extends State<_WinLossRoundsInput> {
  // Keyed by uid in FFA, by team id ('A'..'D') in team mode — see _submitRound.
  final Map<String, bool> _roundWinners = {};

  void _submitRound(AppState app) {
    final d = app.draft;
    final deltas = d.mode == 'team'
        // A whole team wins or loses a manche together — every member gets
        // the same +1/0, not just whoever happened to be toggled.
        ? <String, int>{for (final uid in d.playerIds) uid: (_roundWinners[d.team[uid] ?? 'A'] ?? false) ? 1 : 0}
        : <String, int>{for (final uid in d.playerIds) uid: (_roundWinners[uid] ?? false) ? 1 : 0};
    app.addRound(deltas);
    setState(() => _roundWinners.clear());
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final d = app.draft;
    final rounds = app.draftRounds;
    final hasWinner = _roundWinners.values.any((v) => v);
    final isTeam = d.mode == 'team';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Manche ${rounds.length + 1} — marquez qui a gagné.', style: bodyFont(size: 13, weight: FontWeight.w800, color: AppColors.ink2)),
        const SizedBox(height: 9),
        if (isTeam)
          for (var i = 0; i < d.teamCount; i++)
            Builder(builder: (_) {
              final teamId = String.fromCharCode(65 + i);
              final members = d.playerIds.where((id) => (d.team[id] ?? 'A') == teamId).map(app.playerById).whereType<AppUser>().toList();
              if (members.isEmpty) return const SizedBox.shrink();
              final isWin = _roundWinners[teamId] ?? false;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    AvatarCluster(avatars: [for (final p in members.take(4)) (initial: p.initial, color: Color(p.color))]),
                    const SizedBox(width: 10),
                    Expanded(child: Text('Équipe $teamId', style: bodyFont(size: 14, weight: FontWeight.w700, color: AppColors.ink))),
                    _WinLossToggle(isWin: isWin, onChanged: (win) => setState(() => _roundWinners[teamId] = win)),
                  ],
                ),
              );
            })
        else
          for (final uid in d.playerIds)
            Builder(builder: (_) {
              final p = app.playerById(uid);
              if (p == null) return const SizedBox.shrink();
              final isWin = _roundWinners[uid] ?? false;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Avatar(initial: p.initial, color: Color(p.color), size: 34, fontSize: 13),
                    const SizedBox(width: 10),
                    Expanded(child: Text(p.displayName, style: bodyFont(size: 14, weight: FontWeight.w700, color: AppColors.ink))),
                    _WinLossToggle(isWin: isWin, onChanged: (win) => setState(() => _roundWinners[uid] = win)),
                  ],
                ),
              );
            }),
        const SizedBox(height: 6),
        PrimaryButton(label: 'Valider la manche', onPressed: hasWinner ? () => _submitRound(app) : null),
        if (rounds.isNotEmpty) ...[
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('MANCHES JOUÉES', style: bodyFont(size: 11.5, weight: FontWeight.w800, color: AppColors.mut, letterSpacing: 0.5)),
              Pressable(
                onTap: () => app.undoRound(),
                child: Text('↶ Annuler la dernière', style: bodyFont(size: 12, weight: FontWeight.w700, color: AppColors.accent)),
              ),
            ],
          ),
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
                              for (final t in round.where((t) => t.delta > 0))
                                Text(
                                  app.playerById(t.playerId)?.displayName ?? '?',
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
            child: ScoreEvolutionChart(timeline: d.timeline, appState: app),
          ),
        ],
      ],
    );
  }
}

/// Detailed point entry for games that define colored score categories.
/// Each category contributes to the player's final total automatically,
/// making end-of-game scoring explicit without duplicating the math.
class _DetailedScoreInput extends StatefulWidget {
  final Game game;
  const _DetailedScoreInput({required this.game});

  @override
  State<_DetailedScoreInput> createState() => _DetailedScoreInputState();
}

class _DetailedScoreInputState extends State<_DetailedScoreInput> {
  final Map<String, Map<String, TextEditingController>> _controllers = {};

  TextEditingController _ctrlFor(String uid, String fieldId, int initialValue) {
    final perPlayer = _controllers.putIfAbsent(uid, () => {});
    return perPlayer.putIfAbsent(fieldId, () => TextEditingController(text: initialValue == 0 ? '' : '$initialValue'));
  }

  @override
  void dispose() {
    for (final perPlayer in _controllers.values) {
      for (final controller in perPlayer.values) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final d = app.draft;
    final fields = widget.game.scoreFields ?? const [];
    final players = [for (final uid in d.playerIds) if (app.playerById(uid) != null) uid];

    if (fields.isEmpty || players.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (d.bestOf > 1) const _SeriesProgressBanner(),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: AppColors.accentSoft, border: Border.all(color: AppColors.accent.withValues(alpha: 0.35), width: 1.2), borderRadius: BorderRadius.circular(AppRadius.lg)),
          child: Row(
            children: [
              Icon(Icons.calculate_rounded, size: 16, color: AppColors.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Le total se calcule automatiquement à partir de chaque catégorie.', style: bodyFont(size: 12.5, weight: FontWeight.w700, color: AppColors.ink)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        for (final uid in players)
          Builder(builder: (_) {
            final p = app.playerById(uid);
            if (p == null) return const SizedBox.shrink();
            final isLead = app.draftLeaderIds.contains(uid);
            final total = d.points[uid] ?? 0;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isLead ? AppColors.greenSoft : AppColors.card,
                border: Border.all(color: isLead ? AppColors.green : AppColors.line, width: 1.5),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Avatar(initial: p.initial, color: Color(p.color), size: 40, fontSize: 15),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.displayName, style: bodyFont(size: 15, weight: FontWeight.w700, color: AppColors.ink)),
                            if (isLead) Text('▲ EN TÊTE', style: bodyFont(size: 11, weight: FontWeight.w800, color: AppColors.green, letterSpacing: 0.3)),
                          ],
                        ),
                      ),
                      AnimatedCounter(value: total, style: dispFont(size: 22, weight: FontWeight.w700, color: AppColors.ink)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (final field in fields) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(width: 10, height: 10, decoration: BoxDecoration(color: Color(field.color), shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(field.label, style: bodyFont(size: 13.5, weight: FontWeight.w700, color: AppColors.ink2))),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 88,
                            child: TextField(
                              controller: _ctrlFor(uid, field.id, d.scoreBreakdown[uid]?[field.id] ?? 0),
                              keyboardType: const TextInputType.numberWithOptions(signed: true),
                              textAlign: TextAlign.center,
                              style: bodyFont(size: 15, weight: FontWeight.w700, color: AppColors.ink),
                              decoration: appFieldDecoration(
                                hintText: '0',
                                fillColor: AppColors.bg,
                                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                focusColor: Color(field.color),
                              ),
                              onChanged: (text) => app.setDetailedScore(uid, field.id, int.tryParse(text.trim()) ?? 0),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
      ],
    );
  }
}

/// "Par manche" input mode: enter every player's score for the current
/// round at once (e.g. round 1: 8, 7 — round 2: 7, -2), then review past
/// rounds and the cumulative score-evolution chart.
class _RoundsScoreInput extends StatefulWidget {
  const _RoundsScoreInput();

  @override
  State<_RoundsScoreInput> createState() => _RoundsScoreInputState();
}

class _RoundsScoreInputState extends State<_RoundsScoreInput> {
  final Map<String, TextEditingController> _controllers = {};

  TextEditingController _ctrlFor(String uid) => _controllers.putIfAbsent(uid, () => TextEditingController());

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _submitRound(AppState app) {
    final deltas = <String, int>{
      for (final uid in app.draft.playerIds) uid: int.tryParse(_ctrlFor(uid).text.trim()) ?? 0,
    };
    app.addRound(deltas);
    for (final c in _controllers.values) {
      c.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final d = app.draft;
    final rounds = app.draftRounds;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Manche ${rounds.length + 1}', style: bodyFont(size: 13, weight: FontWeight.w800, color: AppColors.ink2)),
        const SizedBox(height: 9),
        for (final uid in d.playerIds)
          Builder(builder: (_) {
            final p = app.playerById(uid);
            if (p == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Avatar(initial: p.initial, color: Color(p.color), size: 34, fontSize: 13),
                  const SizedBox(width: 10),
                  Expanded(child: Text(p.displayName, style: bodyFont(size: 14, weight: FontWeight.w700, color: AppColors.ink))),
                  SizedBox(
                    width: 90,
                    child: TextField(
                      controller: _ctrlFor(uid),
                      keyboardType: const TextInputType.numberWithOptions(signed: true),
                      textAlign: TextAlign.center,
                      style: bodyFont(size: 15, weight: FontWeight.w700, color: AppColors.ink),
                      decoration: appFieldDecoration(hintText: '0', contentPadding: const EdgeInsets.symmetric(vertical: 10)),
                    ),
                  ),
                ],
              ),
            );
          }),
        const SizedBox(height: 6),
        PrimaryButton(label: 'Valider la manche', onPressed: () => _submitRound(app)),
        if (rounds.isNotEmpty) ...[
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('MANCHES JOUÉES', style: bodyFont(size: 11.5, weight: FontWeight.w800, color: AppColors.mut, letterSpacing: 0.5)),
              Pressable(
                onTap: () => app.undoRound(),
                child: Text('↶ Annuler la dernière', style: bodyFont(size: 12, weight: FontWeight.w700, color: AppColors.accent)),
              ),
            ],
          ),
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
            child: ScoreEvolutionChart(timeline: d.timeline, appState: app),
          ),
        ],
      ],
    );
  }
}

/// Recap banner shown atop the scores step while a "best of N" series is in
/// progress: which leg is being played now, and who won the ones already
/// finished — so players don't lose track across several full matches.
class _SeriesProgressBanner extends StatelessWidget {
  const _SeriesProgressBanner();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final d = app.draft;
    final legs = app.draftSeriesLegs;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.accent, width: 1.5), borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.repeat_rounded, size: 16, color: AppColors.accent),
              const SizedBox(width: 8),
              Text('PARTIE ${d.seriesLegIndex}/${d.bestOf}', style: bodyFont(size: 12.5, weight: FontWeight.w800, color: AppColors.ink, letterSpacing: 0.4)),
            ],
          ),
          if (legs.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                for (final leg in legs)
                  Text('P${leg.seriesGame} : ${app.legWinnerLabel(leg)}', style: bodyFont(size: 12, weight: FontWeight.w700, color: AppColors.mut)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class Step3Scores extends StatelessWidget {
  const Step3Scores({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final d = app.draft;
    final game = app.gameById(d.gameId ?? '');
    if (game?.isRanks == true) {
      final useRounds = game!.multiRound && d.inputMode == 'rounds';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (d.bestOf > 1) const _SeriesProgressBanner(),
          if (game.multiRound) ...[
            SegmentedControl(
              labels: const ['Une manche', 'Plusieurs manches'],
              selectedIndex: useRounds ? 1 : 0,
              onChanged: (i) => app.setInputMode(i == 1 ? 'rounds' : 'quick'),
              fontSize: 13,
            ),
            const SizedBox(height: 16),
          ],
          useRounds ? _RanksRoundsInput(game: game) : _RanksScoreList(game: game),
        ],
      );
    }
    if (game?.isWinLoss == true) {
      final useRounds = game!.multiRound && d.inputMode == 'rounds';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (d.bestOf > 1) const _SeriesProgressBanner(),
          if (game.multiRound) ...[
            SegmentedControl(
              labels: const ['Une manche', 'Plusieurs manches'],
              selectedIndex: useRounds ? 1 : 0,
              onChanged: (i) => app.setInputMode(i == 1 ? 'rounds' : 'quick'),
              fontSize: 13,
            ),
            const SizedBox(height: 16),
          ],
          useRounds ? const _WinLossRoundsInput() : const _WinLossScoreList(),
        ],
      );
    }
    if (game?.hasScoreFields == true && !game!.isWinLoss && !game.isRanks && game.countType != CountType.wins) {
      return _DetailedScoreInput(game: game);
    }
    final leaderIds = app.draftLeaderIds;
    final pointLimit = d.unit == 'wins' ? null : app.gameById(d.gameId ?? '')?.pointLimit;
    final unitLabel = d.unit == 'wins' ? 'Manches gagnées' : 'Points';
    final playersAtLimit = pointLimit == null
        ? const <String>[]
        : d.playerIds.where((uid) => (d.points[uid] ?? 0) >= pointLimit).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (d.bestOf > 1) const _SeriesProgressBanner(),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: AppColors.accentSoft, border: Border.all(color: AppColors.accent.withValues(alpha: 0.35), width: 1.2), borderRadius: BorderRadius.circular(AppRadius.lg)),
          child: Row(
            children: [
              Icon(Icons.lock_rounded, size: 16, color: AppColors.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Mode imposé par le jeu : $unitLabel', style: bodyFont(size: 12.5, weight: FontWeight.w700, color: AppColors.ink)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // "Manches gagnées" always scores round-by-round (one declared
        // winner per manche — see AppState.setUnit/_WinLossRoundsInput), so
        // only the round-based choice applies there.
        if (d.unit != 'wins') ...[
          if (game?.multiRound == true)
            SegmentedControl(
              labels: const ['Saisie rapide', 'Par manche'],
              selectedIndex: d.inputMode == 'rounds' ? 1 : 0,
              onChanged: (i) => app.setInputMode(i == 1 ? 'rounds' : 'quick'),
              fontSize: 12,
            )
        ],
        if (d.mode == 'team' && d.inputMode == 'quick' && d.unit != 'wins') ...[
          const SizedBox(height: 12),
          SegmentedControl(
            labels: const ['Par équipe', 'Par joueur'],
            selectedIndex: d.teamScoreMode == 'global' ? 0 : 1,
            onChanged: (i) => app.setTeamScoreMode(i == 0 ? 'global' : 'perPlayer'),
            fontSize: 13,
          ),
        ],
        if (playersAtLimit.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.accentSoft, border: Border.all(color: AppColors.accent, width: 1.5), borderRadius: BorderRadius.circular(AppRadius.lg)),
            child: Row(
              children: [
                const Text('🎯', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${playersAtLimit.map((uid) => app.playerById(uid)?.displayName ?? '?').join(', ')} '
                    '${playersAtLimit.length > 1 ? 'ont' : 'a'} atteint la limite de $pointLimit points — la partie peut se terminer.',
                    style: bodyFont(size: 13, weight: FontWeight.w700, color: AppColors.ink),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (d.unit == 'wins')
          const _WinLossRoundsInput()
        else if (d.inputMode == 'rounds')
          const _RoundsScoreInput()
        else if (d.inputMode == 'quick' && d.mode == 'team' && d.teamScoreMode == 'global')
          ..._teamQuickRows(context, app)
        else if (d.inputMode == 'quick')
          for (final uid in d.playerIds)
            Builder(builder: (_) {
              final p = app.playerById(uid);
              if (p == null) return const SizedBox.shrink();
              final isLead = leaderIds.contains(uid);
              final low = d.unit == 'wins' ? false : (app.gameById(d.gameId ?? '')?.lowWins ?? false);
              final label = isLead ? (low ? '▼ EN TÊTE' : '▲ EN TÊTE') : (d.mode == 'team' ? 'Équipe ${d.team[uid] ?? 'A'}' : '');
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 9),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isLead ? AppColors.greenSoft : AppColors.card,
                  border: Border.all(color: isLead ? AppColors.green : AppColors.line, width: 1.5),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Row(
                  children: [
                    Avatar(initial: p.initial, color: Color(p.color), size: 40, fontSize: 15),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.displayName, style: bodyFont(size: 15, weight: FontWeight.w700, color: AppColors.ink)),
                          if (label.isNotEmpty) Text(label, style: bodyFont(size: 11, weight: FontWeight.w800, color: AppColors.green, letterSpacing: 0.3)),
                        ],
                      ),
                    ),
                    _stepperButton(Icons.remove, () => app.bump(uid, -1)),
                    Pressable(
                      onTap: () => _showEditScoreDialog(context, app, uid, p.displayName, d.points[uid] ?? 0, onSubmit: (v) => app.setPoints(uid, v)),
                      child: SizedBox(
                        width: 40,
                        child: AnimatedCounter(value: d.points[uid] ?? 0, textAlign: TextAlign.center, style: dispFont(size: 20, weight: FontWeight.w700, color: AppColors.ink)),
                      ),
                    ),
                    _stepperButton(Icons.add, () => app.bump(uid, 1)),
                  ],
                ),
              );
            })
        else ...[
          for (final uid in d.playerIds)
            Builder(builder: (_) {
              final p = app.playerById(uid);
              if (p == null) return const SizedBox.shrink();
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line, width: 1.5), borderRadius: BorderRadius.circular(AppRadius.lg)),
                child: Row(
                  children: [
                    Avatar(initial: p.initial, color: Color(p.color), size: 42, fontSize: 16),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.displayName, style: bodyFont(size: 15, weight: FontWeight.w700, color: AppColors.ink)),
                          Pressable(
                            onTap: () => _showEditScoreDialog(
                              context,
                              app,
                              uid,
                              p.displayName,
                              d.points[uid] ?? 0,
                              onSubmit: (v) => app.addPoints(uid, v - (d.points[uid] ?? 0)),
                            ),
                            child: AnimatedCounter(value: d.points[uid] ?? 0, style: dispFont(size: 28, weight: FontWeight.w700, color: AppColors.ink)),
                          ),
                        ],
                      ),
                    ),
                    Pressable(
                      onTap: () => app.addPoints(uid, 1),
                      onLongPress: () => _showAddPointsSheet(context, app, uid, p.displayName),
                      child: Container(
                        width: 56,
                        height: 56,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(14)),
                        child: Text('+1', style: bodyFont(size: 20, weight: FontWeight.w700, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Pressable(
                      onTap: () => _showAddPointsSheet(context, app, uid, p.displayName),
                      child: Container(
                        width: 44,
                        height: 56,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: AppColors.bg, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(14)),
                        child: Icon(Icons.tune_rounded, size: 20, color: AppColors.ink2),
                      ),
                    ),
                  ],
                ),
              );
            }),
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            constraints: const BoxConstraints(maxHeight: 160),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line, width: 1.5), borderRadius: BorderRadius.circular(AppRadius.lg)),
            child: d.timeline.isEmpty
                ? Center(child: Text('Les points marqués apparaîtront ici.', style: bodyFont(size: 12.5, weight: FontWeight.w600, color: AppColors.mut)))
                : ListView(
                    shrinkWrap: true,
                    reverse: true,
                    children: [
                      for (final t in d.timeline.reversed)
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
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: d.timeline.isEmpty ? null : () => app.undoPoint(),
              style: OutlinedButton.styleFrom(
                backgroundColor: AppColors.card,
                side: BorderSide(color: AppColors.line, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
              ),
              child: Text('↶ Annuler le dernier', style: bodyFont(size: 13, weight: FontWeight.w700, color: AppColors.ink2)),
            ),
          ),
        ],
      ],
    );
  }

  /// "Par équipe" quick-scoring rows: one combined score per team instead
  /// of one per player — the team's score is split evenly across its
  /// members when the match is saved (see `AppState._teamGlobalEntries`),
  /// so per-player ranking stats stay sane without tracking who
  /// specifically contributed what.
  List<Widget> _teamQuickRows(BuildContext context, AppState app) {
    final d = app.draft;
    String? leadingTeam;
    if (d.teamPoints.values.any((v) => v != 0)) {
      var best = -1 << 31;
      d.teamPoints.forEach((t, v) {
        if (v > best) {
          best = v;
          leadingTeam = t;
        }
      });
    }
    final teamIds = [for (var i = 0; i < d.teamCount; i++) String.fromCharCode(65 + i)];
    return [
      for (final teamId in teamIds)
        Builder(builder: (_) {
          final members = d.playerIds.where((id) => (d.team[id] ?? 'A') == teamId).map(app.playerById).whereType<AppUser>().toList();
          if (members.isEmpty) return const SizedBox.shrink();
          final isLead = teamId == leadingTeam;
          final score = d.teamPoints[teamId] ?? 0;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 9),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isLead ? AppColors.greenSoft : AppColors.card,
              border: Border.all(color: isLead ? AppColors.green : AppColors.line, width: 1.5),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Row(
              children: [
                AvatarCluster(avatars: [for (final p in members.take(4)) (initial: p.initial, color: Color(p.color))]),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Équipe $teamId', style: bodyFont(size: 15, weight: FontWeight.w700, color: AppColors.ink)),
                      Text(
                        isLead ? '▲ EN TÊTE' : members.map((p) => p.displayName).join(', '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: bodyFont(size: 11, weight: isLead ? FontWeight.w800 : FontWeight.w600, color: isLead ? AppColors.green : AppColors.mut, letterSpacing: isLead ? 0.3 : 0),
                      ),
                    ],
                  ),
                ),
                _stepperButton(Icons.remove, () => app.bumpTeam(teamId, -1)),
                Pressable(
                  onTap: () => _showEditScoreDialog(context, app, teamId, 'Équipe $teamId', score, onSubmit: (v) => app.setTeamPoints(teamId, v)),
                  child: SizedBox(
                    width: 40,
                    child: AnimatedCounter(value: score, textAlign: TextAlign.center, style: dispFont(size: 20, weight: FontWeight.w700, color: AppColors.ink)),
                  ),
                ),
                _stepperButton(Icons.add, () => app.bumpTeam(teamId, 1)),
              ],
            ),
          );
        }),
    ];
  }

  Widget _stepperButton(IconData icon, VoidCallback onTap) {
    return Pressable(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: AppColors.bg, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(11)),
        child: Icon(icon, size: 18, color: AppColors.ink),
      ),
    );
  }
}

Future<void> _showEditScoreDialog(
  BuildContext context,
  AppState app,
  String uid,
  String playerName,
  int currentValue, {
  required void Function(int value) onSubmit,
}) async {
  final ctrl = TextEditingController(text: '$currentValue');
  await showDialog(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: AppColors.bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Score de $playerName', style: dispFont(size: 18, weight: FontWeight.w700, color: AppColors.ink)),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: dispFont(size: 28, weight: FontWeight.w700, color: AppColors.ink),
              decoration: appFieldDecoration(),
              onSubmitted: (_) {
                final v = int.tryParse(ctrl.text.trim());
                if (v != null) onSubmit(v);
                Navigator.of(dialogContext).pop();
              },
            ),
            const SizedBox(height: 18),
            PrimaryButton(
              label: 'Valider',
              onPressed: () {
                final v = int.tryParse(ctrl.text.trim());
                if (v == null) return;
                onSubmit(v);
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        ),
      ),
    ),
  );
}

const _quickDeltas = [-10, -5, -1, 1, 5, 10, 20, 25];

Future<void> _showAddPointsSheet(BuildContext context, AppState app, String uid, String playerName) async {
  final ctrl = TextEditingController();
  await showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ajouter des points — $playerName', style: dispFont(size: 18, weight: FontWeight.w700, color: AppColors.ink)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final d in _quickDeltas)
                    Pressable(
                      onTap: () {
                        app.addPoints(uid, d);
                        Navigator.of(sheetContext).pop();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line, width: 1.5), borderRadius: BorderRadius.circular(12)),
                        child: Text(d > 0 ? '+$d' : '$d', style: bodyFont(size: 14, weight: FontWeight.w700, color: AppColors.ink)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Text('Valeur exacte', style: bodyFont(size: 12.5, weight: FontWeight.w800, color: AppColors.ink2)),
              const SizedBox(height: 9),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: ctrl,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(signed: true),
                      style: bodyFont(size: 16, weight: FontWeight.w700, color: AppColors.ink),
                      decoration: appFieldDecoration(hintText: 'Ex. 12 ou -3'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        final v = int.tryParse(ctrl.text.trim());
                        if (v == null || v == 0) return;
                        app.addPoints(uid, v);
                        Navigator.of(sheetContext).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                        elevation: 0,
                      ),
                      child: Text('Ajouter', style: bodyFont(size: 14, weight: FontWeight.w800, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
