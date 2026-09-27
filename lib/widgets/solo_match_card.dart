import 'package:flutter/material.dart';

import '../logic/personal_records.dart';
import '../logic/time_format.dart';
import '../models/game.dart';
import '../models/match.dart';
import '../theme/app_theme.dart';
import 'common.dart';
import 'match_card.dart' show relativeDateLabel;

/// A match of "Mon espace solo": no winner nor avatars — the game, the
/// result in large, and how it stands against the record: "Record" for
/// today's best, "Ancien record" for one beaten since, otherwise the gap
/// to today's best (see [SoloAttempt]). A win/loss rule just says whether it was won.
class SoloMatchCard extends StatelessWidget {
  final Game game;
  final GameMatch match;
  final SoloAttempt? attempt;
  final VoidCallback onTap;
  const SoloMatchCard({super.key, required this.game, required this.match, required this.attempt, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final rule = game.resolveRule(match.ruleId);
    final a = attempt;
    final String value;
    if (a != null) {
      value = scoreLabel(a.value, a.unit);
    } else if (rule.isWinLoss || match.unit == 'wins') {
      value = match.winnerIds().isNotEmpty ? 'Victoire' : 'Défaite';
    } else {
      value = scoreLabel(match.entries.firstOrNull?.points ?? 0, match.unit);
    }
    final subtitle = [if (game.hasMultipleRules) rule.name, relativeDateLabel(match.createdAt)].join(' · ');

    return Pressable(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          border: Border.all(color: a?.gapToBest == 0 ? AppColors.green : AppColors.line, width: a?.gapToBest == 0 ? 1.5 : 1),
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.bg, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(13)),
              child: Text(game.emoji, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(game.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyFont(size: 14.5, weight: FontWeight.w800, color: AppColors.ink)),
                  const SizedBox(height: 2),
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(value, style: dispFont(size: 18, weight: FontWeight.w800, color: AppColors.ink)),
                if (a != null) ...[
                  const SizedBox(height: 2),
                  if (a.gapToBest == 0)
                    Text('🏆 Record', style: bodyFont(size: 11.5, weight: FontWeight.w800, color: AppColors.green))
                  else if (a.wasRecord)
                    Text('Ancien record', style: bodyFont(size: 11.5, weight: FontWeight.w800, color: AppColors.ink2))
                  else
                    Text(
                      '${a.unit == 'time' ? '+${formatDuration(a.gapToBest)}' : '−${a.gapToBest} pts'} du record',
                      style: bodyFont(size: 11.5, weight: FontWeight.w700, color: AppColors.mut),
                    ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
