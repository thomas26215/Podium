import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/elo.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/elo_widgets.dart';
import '../../widgets/match_card.dart' show frenchDayMonth;

/// A player's Elo on their profile: their tier and how far the next one is,
/// their rating curve, and their highlights (see [eloRecordsOf]).
class ProfileEloSection extends StatelessWidget {
  final String uid;
  const ProfileEloSection({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final elo = app.groupElo;
    final rating = elo.ratingOf(uid);
    if (rating == null) return const SizedBox.shrink();
    final tier = eloTier(rating);
    final next = nextEloTier(rating);
    final records = eloRecordsOf(elo, uid);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(AppRadius.xl)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              EloTierBadge(tier: tier, fontSize: 13),
              const Spacer(),
              Text('${rating.round()}', style: dispFont(size: 22, weight: FontWeight.w800, color: Color(tier.color))),
              const SizedBox(width: 4),
              Text('Elo', style: bodyFont(size: 12, weight: FontWeight.w700, color: AppColors.mut)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: next == null ? 1 : ((rating - tier.min) / (next.min - tier.min)).clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: AppColors.line,
              color: Color(tier.color),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            next == null ? 'Palier maximum atteint.' : 'Plus que ${(next.min - rating).ceil()} pour ${next.name}.',
            style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut),
          ),
          const SizedBox(height: 16),
          EloHistoryChart(points: elo.history[uid] ?? const []),
          const SizedBox(height: 10),
          if (records.peak != null) _record('🏔️', 'Record', '${records.peak!.rating.round()} · ${frenchDayMonth(records.peak!.date)}'),
          if (records.bestGain != null) _record('🚀', 'Plus gros gain', '+${records.bestGain!.delta.round()} · ${frenchDayMonth(records.bestGain!.date)}'),
          if (records.longestStreak >= 2) _record('🔥', 'Plus longue série de gains', '${records.longestStreak} parties'),
          if (records.currentStreak >= 2) _record('📈', 'Série en cours', '${records.currentStreak} parties'),
          if (records.upset != null)
            _record(
              '⚡',
              'Plus bel exploit',
              'devant ${records.upset!.opponentIds.map((id) => app.playerById(id)?.displayName ?? '?').join(' et ')} '
                  '(${records.upset!.gap.round()} Elo de plus) · ${frenchDayMonth(records.upset!.date)}',
            ),
        ],
      ),
    );
  }

  Widget _record(String emoji, String label, String value) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 26, child: Text(emoji, style: const TextStyle(fontSize: 15))),
            Text('$label  ', style: bodyFont(size: 13, weight: FontWeight.w700, color: AppColors.ink2)),
            Expanded(child: Text(value, textAlign: TextAlign.right, style: bodyFont(size: 13, weight: FontWeight.w800, color: AppColors.ink))),
          ],
        ),
      );
}
