import 'package:flutter/material.dart';

import '../logic/personal_records.dart';
import '../logic/time_format.dart';
import '../theme/app_theme.dart';
import 'common.dart';
import 'match_card.dart' show relativeDateLabel;

/// "Mon espace solo"'s answer to a ranking (see `AppState.personalRecords`):
/// one card per game and rule played, its best score or time up front,
/// how many attempts and when the last one was — [limit] keeps just the
/// most recent few (the home screen). [onTap] opens a record's details.
class PersonalRecordsList extends StatelessWidget {
  final List<PersonalRecord> records;
  final int? limit;
  final void Function(PersonalRecord record)? onTap;
  const PersonalRecordsList({super.key, required this.records, this.limit, this.onTap});

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const EmptyState(emoji: '⏱️', message: 'Aucun record pour l’instant. Lancez une partie solo avec le bouton +.');
    }
    final shown = limit == null ? records : records.take(limit!).toList();
    return Column(
      children: [
        for (final (i, r) in shown.indexed)
          FadeSlideIn(
            delay: Duration(milliseconds: i * 40),
            child: Pressable(onTap: onTap == null ? null : () => onTap!(r), child: _RecordCard(record: r)),
          ),
      ],
    );
  }
}

class _RecordCard extends StatelessWidget {
  final PersonalRecord record;
  const _RecordCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final r = record;
    final gain = r.lastImprovement;
    final title = r.title;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(radius: AppRadius.xl),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: wellDecoration(radius: AppRadius.scaled(13), bordered: true),
            child: Text(r.game.emoji, style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyFont(size: 14.5, weight: FontWeight.w800, color: AppColors.ink)),
                const SizedBox(height: 2),
                Text(
                  '${r.played} partie${r.played > 1 ? 's' : ''} · dernière ${relativeDateLabel(r.lastPlayedAt).toLowerCase()}',
                  style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut),
                ),
                if (gain != null)
                  Text(
                    '🏆 Record battu de ${r.unit == 'time' ? formatDuration(gain) : '$gain pts'}',
                    style: bodyFont(size: 11.5, weight: FontWeight.w800, color: AppColors.green),
                  ),
              ],
            ),
          ),
          if (r.bestLabel != null) ...[
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('RECORD', style: bodyFont(size: 10, weight: FontWeight.w800, color: AppColors.mut, letterSpacing: 0.4)),
                Text(r.bestLabel!, style: dispFont(size: 18, weight: FontWeight.w800, color: AppColors.ink)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
