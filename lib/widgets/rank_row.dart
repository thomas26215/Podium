import 'package:flutter/material.dart';

import '../logic/badges.dart';
import '../models/app_user.dart';
import '../theme/app_theme.dart';
import 'avatar.dart';
import 'badge_symbols.dart';
import 'common.dart';

/// `.mrow` — compact rank row used in the home mini-ranking (top 3 only,
/// wins as the single metric).
class MiniRankRow extends StatelessWidget {
  final int rank;
  final AppUser player;
  final int value;
  final String unit; // 'victoires', 'Elo'…
  final VoidCallback onTap;
  const MiniRankRow({super.key, required this.rank, required this.player, required this.value, required this.unit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      behavior: HitTestBehavior.opaque,
      dimOnPress: true,
      pressedScale: 0.98,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: Text('$rank', textAlign: TextAlign.center, style: dispFont(size: 15, weight: FontWeight.w700, color: rank == 1 ? AppColors.gold : AppColors.mut)),
            ),
            const SizedBox(width: 12),
            Avatar(initial: player.initial, color: Color(player.color), size: 38, fontSize: 15),
            const SizedBox(width: 12),
            Expanded(child: _NameWithBadges(player: player, style: bodyFont(size: 15.5, weight: FontWeight.w700, color: AppColors.ink))),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AnimatedCounter(value: value, style: dispFont(size: 16, weight: FontWeight.w700, color: AppColors.ink)),
                Text(unit, style: bodyFont(size: 11, weight: FontWeight.w600, color: AppColors.mut)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// `.rrow` — full ranking list row (ranks 4+), showing whichever metric the
/// active ranking mode uses.
class RankRow extends StatelessWidget {
  final int rank;
  final AppUser player;
  final String sub;
  final String metric;
  final String unit;
  final VoidCallback onTap;
  const RankRow({
    super.key,
    required this.rank,
    required this.player,
    required this.sub,
    required this.metric,
    required this.unit,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      behavior: HitTestBehavior.opaque,
      dimOnPress: true,
      pressedScale: 0.98,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            SizedBox(width: 22, child: Text('$rank', textAlign: TextAlign.center, style: dispFont(size: 16, weight: FontWeight.w700, color: AppColors.mut))),
            const SizedBox(width: 13),
            Avatar(initial: player.initial, color: Color(player.color), size: 42, fontSize: 16),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _NameWithBadges(player: player, style: bodyFont(size: 15.5, weight: FontWeight.w700, color: AppColors.ink)),
                  Text(sub, style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(metric, style: dispFont(size: 19, weight: FontWeight.w700, color: AppColors.ink)),
                Text(unit, style: bodyFont(size: 10.5, weight: FontWeight.w600, color: AppColors.mut, letterSpacing: 0.3)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A player's name followed by the symbols of the badges they pinned (see
/// AppUser.showcasedBadges) — a little flair in the rankings.
class _NameWithBadges extends StatelessWidget {
  final AppUser player;
  final TextStyle style;
  const _NameWithBadges({required this.player, required this.style});

  @override
  Widget build(BuildContext context) {
    final badges = player.showcasedBadges.map(badgeById).whereType<BadgeDef>();
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: player.displayName, style: style),
        for (final (i, b) in badges.indexed)
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(padding: EdgeInsets.only(left: i == 0 ? 8 : 4), child: BadgeSymbol(badge: b, earned: true, size: 15)),
          ),
      ]),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
