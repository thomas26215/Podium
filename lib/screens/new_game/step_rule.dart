import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/game.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'game_actions_sheet.dart';

/// Wizard step shown right after "Quel jeu ?" whenever the picked game has
/// more than one rule (see `Game.hasMultipleRules`/`AppState.stepSequence`)
/// — picks which one to score the match under (`AppState.pickRule`).
class StepRule extends StatelessWidget {
  const StepRule({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final game = app.gameById(app.draft.gameId ?? '');
    if (game == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, rule) in game.rules.indexed) ...[
          FadeSlideIn(
            delay: staggerDelay(i, stepMs: 45),
            child: _RuleOption(
              rule: rule,
              selected: app.draft.ruleId == rule.id,
              onTap: () => app.pickRule(rule.id),
            ),
          ),
          const SizedBox(height: 8),
        ],
        Pressable(
          // Already inside the new-game sheet here (this step only ever
          // renders as part of it) — no need for game_actions_sheet's
          // "open the sheet fresh" helper, just flip its internal view.
          onTap: () async {
            if (await confirmDetachFromLibrary(context, game)) app.startEditingGame(game);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            decoration: cardDecoration(radius: AppRadius.md, fill: Colors.transparent, border: AppColors.line, borderWidth: 1.5),
            child: Text('+ Ajouter une règle', style: bodyFont(size: 13, weight: FontWeight.w700, color: AppColors.ink2)),
          ),
        ),
      ],
    );
  }
}

class _RuleOption extends StatelessWidget {
  final GameRule rule;
  final bool selected;
  final VoidCallback onTap;
  const _RuleOption({required this.rule, required this.selected, required this.onTap});

  String get _description {
    final bits = <String>[
      switch (rule.countType) {
        CountType.highWins => 'Points — le plus haut gagne',
        CountType.lowWins => 'Points — le plus bas gagne',
        CountType.wins => 'Manches gagnées',
        CountType.ranks => 'Classement',
        CountType.winLoss => 'Victoire / défaite',
        CountType.time => 'Temps — le plus rapide gagne',
      },
      if (rule.pointLimit != null) '${rule.pointLimit} pts max',
      if (rule.coop) 'Coopératif',
    ];
    return bits.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppColors.motion.change,
        curve: AppColors.motion.changeCurve,
        padding: const EdgeInsets.all(14),
        decoration: cardDecoration(
          radius: AppRadius.lg,
          fill: selected ? AppColors.accentSoft : null,
          border: selected ? AppColors.accent : null,
          borderWidth: 1.5,
          selected: selected,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(rule.name, style: bodyFont(size: 15, weight: FontWeight.w800, color: AppColors.ink)),
                  const SizedBox(height: 2),
                  Text(_description, style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut)),
                ],
              ),
            ),
            if (selected) Icon(Icons.check_circle_rounded, color: AppColors.accent, size: 20),
          ],
        ),
      ),
    );
  }
}
