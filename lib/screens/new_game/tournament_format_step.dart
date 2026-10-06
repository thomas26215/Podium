import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/tournament.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Shown right after picking "Tournoi" on the sheet's first step: the
/// bracket shape, and (for "poules") how many groups and how many qualify
/// from each. Game and participants are picked on the following steps,
/// reusing [Step1Game]/[Step2Players] as-is.
class TournamentFormatStep extends StatelessWidget {
  const TournamentFormatStep({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final format = app.draft.tournamentFormat;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, f) in const [
          (TournamentFormat.singleElimination, 'Élimination simple', 'Une défaite élimine'),
          (TournamentFormat.doubleElimination, 'Élimination double', 'Deux défaites éliminent'),
          (TournamentFormat.groupsThenElimination, 'Poules puis élimination', 'Phase de groupes, puis bracket'),
        ].indexed) ...[
          if (i > 0) const SizedBox(height: 8),
          FadeSlideIn(
            delay: staggerDelay(i, stepMs: 50),
            child: _FormatCard(label: f.$2, sub: f.$3, selected: format == f.$1, onTap: () => app.setTournamentFormat(f.$1)),
          ),
        ],
        if (format == TournamentFormat.groupsThenElimination) ...[
          const SizedBox(height: 20),
          Text('Nombre de poules', style: bodyFont(size: 13.5, weight: FontWeight.w800, color: AppColors.ink2)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (var n = 2; n <= 4; n++)
                _NumberChip(value: n, selected: app.draft.tournamentGroupsCount == n, onTap: () => app.setTournamentGroupsCount(n)),
            ],
          ),
          const SizedBox(height: 16),
          Text('Qualifiés par poule', style: bodyFont(size: 13.5, weight: FontWeight.w800, color: AppColors.ink2)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (var n = 1; n <= 2; n++)
                _NumberChip(value: n, selected: app.draft.tournamentQualifiersPerGroup == n, onTap: () => app.setTournamentQualifiersPerGroup(n)),
            ],
          ),
        ],
      ],
    );
  }
}

class _FormatCard extends StatelessWidget {
  final String label;
  final String sub;
  final bool selected;
  final VoidCallback onTap;
  const _FormatCard({required this.label, required this.sub, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: cardDecoration(
          radius: AppRadius.lg,
          fill: selected ? AppColors.ink : null,
          border: selected ? AppColors.ink : null,
          borderWidth: 1.5,
          selected: selected,
        ),
        child: Row(
          children: [
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked, size: 18, color: selected ? AppColors.onInk : AppColors.mut),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: bodyFont(size: 14.5, weight: FontWeight.w800, color: selected ? AppColors.onInk : AppColors.ink)),
                  Text(sub, style: bodyFont(size: 12, weight: FontWeight.w600, color: selected ? AppColors.onInk.withValues(alpha: 0.7) : AppColors.mut)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NumberChip extends StatelessWidget {
  final int value;
  final bool selected;
  final VoidCallback onTap;
  const _NumberChip({required this.value, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        width: 40,
        padding: const EdgeInsets.symmetric(vertical: 9),
        alignment: Alignment.center,
        decoration: chipDecoration(
          radius: AppRadius.scaled(10),
          fill: selected ? AppColors.ink : null,
          border: selected ? AppColors.ink : null,
          borderWidth: 1.5,
          selected: selected,
        ),
        child: Text('$value', style: bodyFont(size: 13.5, weight: FontWeight.w800, color: selected ? AppColors.onInk : AppColors.ink)),
      ),
    );
  }
}
