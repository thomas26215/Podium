import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// The sheet's very first step: build a single match, or a whole tournament
/// bracket — see `AppState.isTournamentFlow`, which everything downstream
/// branches on.
class KindChoiceStep extends StatelessWidget {
  const KindChoiceStep({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Column(
      children: [
        _KindCard(
          emoji: '🎲',
          title: 'Partie simple',
          sub: 'Choisissez un jeu, les joueurs, puis entrez les scores.',
          selected: app.draft.creationKind == 'game',
          onTap: () => app.setCreationKind('game'),
        ),
        const SizedBox(height: 10),
        _KindCard(
          emoji: '🏆',
          title: 'Tournoi',
          sub: 'Un bracket à élimination simple, double, ou en poules — chaque match s\'enregistre comme une partie normale.',
          selected: app.draft.creationKind == 'tournament',
          onTap: () => app.setCreationKind('tournament'),
        ),
      ],
    );
  }
}

class _KindCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String sub;
  final bool selected;
  final VoidCallback onTap;
  const _KindCard({required this.emoji, required this.title, required this.sub, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentSoft : AppColors.card,
          border: Border.all(color: selected ? AppColors.accent : AppColors.line, width: 1.5),
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(14)),
              child: Text(emoji, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: bodyFont(size: 15.5, weight: FontWeight.w800, color: AppColors.ink)),
                  Text(sub, style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut)),
                ],
              ),
            ),
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked, size: 20, color: selected ? AppColors.accent : AppColors.mut),
          ],
        ),
      ),
    );
  }
}
