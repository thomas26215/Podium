import 'package:flutter/material.dart';

import '../logic/badges.dart';
import '../models/app_user.dart';
import '../theme/app_theme.dart';
import 'badge_symbols.dart';
import 'common.dart';
import 'player_card.dart';

/// `.mrow` — compact rank row used in the home mini-ranking (top 3 only,
/// wins as the single metric). A player who dressed up their card shows
/// on their [Nameplate].
class MiniRankRow extends StatelessWidget {
  final int rank;
  final AppUser player;
  final int value;
  final String unit; // 'victoires', 'Elo'…
  final VoidCallback onTap;
  const MiniRankRow({super.key, required this.rank, required this.player, required this.value, required this.unit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final plate = player.dressedUp;
    final ink = plate ? Colors.white : AppColors.ink;
    final mut = plate ? Colors.white.withValues(alpha: 0.72) : AppColors.mut;
    TextStyle lift(TextStyle style) => plate ? onBanner(style) : style;
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text('$rank', textAlign: TextAlign.center, style: lift(dispFont(size: 15, weight: FontWeight.w700, color: rank == 1 ? AppColors.gold : mut))),
          ),
          const SizedBox(width: 12),
          PlayerAvatar(player, size: 38, fontSize: 15),
          const SizedBox(width: 12),
          Expanded(child: _NameWithBadges(player: player, size: 15.5, onPlate: plate)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AnimatedCounter(value: value, style: lift(dispFont(size: 16, weight: FontWeight.w700, color: ink))),
              Text(unit, style: lift(bodyFont(size: 11, weight: FontWeight.w600, color: mut))),
            ],
          ),
        ],
      ),
    );
    return Pressable(
      behavior: HitTestBehavior.opaque,
      dimOnPress: true,
      pressedScale: 0.98,
      onTap: onTap,
      child: plate ? Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Nameplate(user: player, borderRadius: BorderRadius.circular(AppRadius.lg), child: row)) : row,
    );
  }
}

/// `.rrow` — full ranking list row (ranks 4+), showing whichever metric the
/// active ranking mode uses — on the player's [Nameplate] if they dressed
/// up their card.
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
    final plate = player.dressedUp;
    final ink = plate ? Colors.white : AppColors.ink;
    final mut = plate ? Colors.white.withValues(alpha: 0.72) : AppColors.mut;
    TextStyle lift(TextStyle style) => plate ? onBanner(style) : style;
    final row = Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          SizedBox(width: 22, child: Text('$rank', textAlign: TextAlign.center, style: lift(dispFont(size: 16, weight: FontWeight.w700, color: mut)))),
          const SizedBox(width: 13),
          PlayerAvatar(player, size: 42, fontSize: 16),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _NameWithBadges(player: player, size: 15.5, onPlate: plate),
                Text(sub, style: lift(bodyFont(size: 12, weight: FontWeight.w600, color: mut))),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(metric, style: lift(dispFont(size: 19, weight: FontWeight.w700, color: ink))),
              Text(unit, style: lift(bodyFont(size: 10.5, weight: FontWeight.w600, color: mut, letterSpacing: 0.3))),
            ],
          ),
        ],
      ),
    );
    return Pressable(
      behavior: HitTestBehavior.opaque,
      dimOnPress: true,
      pressedScale: 0.98,
      onTap: onTap,
      child: plate ? Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Nameplate(user: player, borderRadius: BorderRadius.circular(AppRadius.lg), child: row)) : row,
    );
  }
}

/// A player's name followed by the symbols of the badges they pinned (see
/// AppUser.showcasedBadges) — a little flair in the rankings. In their
/// card's font, and on their nameplate with its effect too.
class _NameWithBadges extends StatelessWidget {
  final AppUser player;
  final double size;
  final bool onPlate;
  const _NameWithBadges({required this.player, required this.size, required this.onPlate});

  @override
  Widget build(BuildContext context) {
    final badges = player.showcasedBadges.map(badgeById).whereType<BadgeDef>();
    return Row(
      children: [
        Flexible(child: onPlate ? CardName(player, size: size) : PlayerName(player, style: bodyFont(size: size, weight: FontWeight.w700, color: AppColors.ink))),
        for (final (i, b) in badges.indexed)
          Padding(padding: EdgeInsets.only(left: i == 0 ? 8 : 4), child: BadgeSymbol(badge: b, earned: true, size: 15)),
      ],
    );
  }
}
