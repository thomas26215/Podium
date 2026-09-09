import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/game.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

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
        for (final rule in game.rules) ...[
          _RuleOption(
            rule: rule,
            selected: app.draft.ruleId == rule.id,
            onTap: () => app.pickRule(rule.id),
          ),
          const SizedBox(height: 8),
        ],
        Pressable(
          // Already inside the new-game sheet here (this step only ever
          // renders as part of it) — no need for game_actions_sheet's
          // "open the sheet fresh" helper, just flip its internal view.
          onTap: () => app.startEditingGame(game),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(border: Border.all(color: AppColors.line, width: 1.5), borderRadius: BorderRadius.circular(AppRadius.md)),
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
      },
      if (rule.pointLimit != null) '${rule.pointLimit} pts max',
    ];
    return bits.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentSoft : AppColors.card,
          border: Border.all(color: selected ? AppColors.accent : AppColors.line, width: 1.5),
          borderRadius: BorderRadius.circular(AppRadius.lg),
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
