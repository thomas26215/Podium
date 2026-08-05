import 'package:flutter/material.dart';

import '../state/player_row.dart';
import '../theme/app_theme.dart';
import 'avatar.dart';

/// One column of the top-3 podium (`.pcol`/`.pbar`).
class PodiumColumn {
  final PlayerRow row;
  final RankMetric metric;
  final int place; // 1, 2 or 3
  final VoidCallback onTap;
  const PodiumColumn({required this.row, required this.metric, required this.place, required this.onTap});
}

class PodiumWidget extends StatelessWidget {
  final List<PodiumColumn> columns; // already in display order: 2nd, 1st, 3rd
  const PodiumWidget({super.key, required this.columns});

  static const _barHeight = {1: 120.0, 2: 88.0, 3: 64.0};
  static Map<int, Color> get _barColor => {1: AppColors.accent, 2: AppColors.ink, 3: const Color(0xFFB8B3A6)};
  static const _avatarSize = {1: 60.0, 2: 52.0, 3: 52.0};

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < columns.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            _column(columns[i]),
          ],
        ],
      ),
    );
  }

  Widget _column(PodiumColumn c) {
    final p = c.row.player;
    return GestureDetector(
      onTap: c.onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (c.place == 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Icon(Icons.emoji_events, color: AppColors.gold, size: 22),
            ),
          Container(
            margin: const EdgeInsets.only(bottom: 9),
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.bg, width: 3), boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 4)),
            ]),
            child: Avatar(initial: p.initial, color: Color(p.color), size: _avatarSize[c.place]!, fontSize: c.place == 1 ? 23 : 20),
          ),
          Text(p.displayName, style: bodyFont(size: 13, weight: FontWeight.w800, color: AppColors.ink)),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('${c.metric.metric} ${c.metric.unit}',
                style: bodyFont(size: 12, weight: FontWeight.w700, color: AppColors.mut), maxLines: 1, softWrap: false, overflow: TextOverflow.visible),
          ),
          Container(
            width: 96,
            height: _barHeight[c.place],
            alignment: Alignment.topCenter,
            padding: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: _barColor[c.place],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Text('${c.place}', style: dispFont(size: 26, weight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
