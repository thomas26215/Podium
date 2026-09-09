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
        _FormatCard(
          label: 'Élimination simple',
          sub: 'Une défaite élimine',
          selected: format == TournamentFormat.singleElimination,
          onTap: () => app.setTournamentFormat(TournamentFormat.singleElimination),
        ),
        const SizedBox(height: 8),
        _FormatCard(
          label: 'Élimination double',
          sub: 'Deux défaites éliminent',
          selected: format == TournamentFormat.doubleElimination,
          onTap: () => app.setTournamentFormat(TournamentFormat.doubleElimination),
        ),
        const SizedBox(height: 8),
        _FormatCard(
          label: 'Poules puis élimination',
          sub: 'Phase de groupes, puis bracket',
          selected: format == TournamentFormat.groupsThenElimination,
          onTap: () => app.setTournamentFormat(TournamentFormat.groupsThenElimination),
        ),
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
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.card,
          border: Border.all(color: selected ? AppColors.ink : AppColors.line, width: 1.5),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Row(
          children: [
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked, size: 18, color: selected ? Colors.white : AppColors.mut),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: bodyFont(size: 14.5, weight: FontWeight.w800, color: selected ? Colors.white : AppColors.ink)),
                  Text(sub, style: bodyFont(size: 12, weight: FontWeight.w600, color: selected ? Colors.white.withValues(alpha: 0.7) : AppColors.mut)),
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
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.card,
          border: Border.all(color: selected ? AppColors.ink : AppColors.line, width: 1.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text('$value', style: bodyFont(size: 13.5, weight: FontWeight.w800, color: selected ? Colors.white : AppColors.ink)),
      ),
    );
  }
}
