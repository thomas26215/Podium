import 'package:flutter/material.dart';

import '../logic/plus.dart';
import '../state/player_row.dart';
import '../theme/app_theme.dart';
import 'avatar_frames.dart';
import 'common.dart';
import 'player_card.dart';

/// One column of the top-3 podium (`.pcol`/`.pbar`).
class PodiumColumn {
  final PlayerRow row;
  final RankMetric metric;
  final int place; // 1, 2 or 3
  final VoidCallback onTap;
  const PodiumColumn({required this.row, required this.metric, required this.place, required this.onTap});
}

class PodiumWidget extends StatefulWidget {
  final List<PodiumColumn> columns; // already in display order: 2nd, 1st, 3rd
  const PodiumWidget({super.key, required this.columns});

  @override
  State<PodiumWidget> createState() => _PodiumWidgetState();
}

class _PodiumWidgetState extends State<PodiumWidget> with TickerProviderStateMixin {
  static const _barHeight = {1: 120.0, 2: 88.0, 3: 64.0};
  static Map<int, Color> get _barColor => {1: AppColors.accent, 2: AppColors.hero, 3: const Color(0xFFB8B3A6)};
  static const _avatarSize = {1: 60.0, 2: 52.0, 3: 52.0};

  // Revealed in ascending suspense: 3rd, then 2nd, then the champion.
  static const _revealOrder = {3: 0, 2: 1, 1: 2};

  // A single one-shot controller — every column's reveal (and the
  // champion's crown pop) is just a differently-timed slice of it, so it
  // settles for good once it completes instead of looping forever (an
  // endless `repeat()` here would make `pumpAndSettle()` hang in tests, and
  // pointlessly keep redrawing long after the reveal is done).
  late final AnimationController _entrance = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  Animation<double> _revealFor(int place) {
    final start = 0.12 * _revealOrder[place]!;
    return CurvedAnimation(parent: _entrance, curve: Interval(start, (start + 0.62).clamp(0.0, 1.0), curve: Curves.easeOutCubic));
  }

  /// The champion's crown "pop" — an overshooting scale-in on the same
  /// timing slice as its reveal, instead of a separate looping animation.
  Animation<double> _crownPop() {
    const start = 0.12 * 2; // place 1's slot in _revealOrder
    return CurvedAnimation(parent: _entrance, curve: const Interval(start, start + 0.62, curve: Curves.easeOutBack));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < widget.columns.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            _column(widget.columns[i]),
          ],
        ],
      ),
    );
  }

  Widget _column(PodiumColumn c) {
    final p = c.row.player;
    final reveal = _revealFor(c.place);
    final crownPop = c.place == 1 ? _crownPop() : kAlwaysCompleteAnimation;
    final size = _avatarSize[c.place]!;
    final framed = p.shown.avatarFrame != null;
    // Room for the decoration round the avatar, which takes none itself.
    final reach = framed ? size * (kFrameReach - 1) / 2 : 0.0;
    final metric = '${c.metric.metric} ${c.metric.unit}';
    return Pressable(
      onTap: c.onTap,
      pressedScale: 0.95,
      child: AnimatedBuilder(
        animation: reveal,
        builder: (context, child) {
          return Opacity(
            opacity: reveal.value,
            child: Transform.translate(offset: Offset(0, 14 * (1 - reveal.value)), child: child),
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (c.place == 1)
              Padding(
                padding: EdgeInsets.only(bottom: 2 + reach),
                child: AnimatedBuilder(
                  animation: crownPop,
                  builder: (context, child) => Transform.scale(scale: crownPop.value, child: child),
                  child: Icon(Icons.emoji_events, color: AppColors.gold, size: 22),
                ),
              ),
            // The podium is a spotlight: decorations and name effects play.
            if (framed)
              Padding(padding: EdgeInsets.only(bottom: 9 + reach), child: PlayerAvatar(p, size: size, fontSize: c.place == 1 ? 23 : 20, live: true))
            else
              Container(
                margin: const EdgeInsets.only(bottom: 9),
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.bg, width: 3), boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 4)),
                ]),
                child: PlayerAvatar(p, size: size, fontSize: c.place == 1 ? 23 : 20),
              ),
            // A player who dressed up their card stands on a little copy of
            // it: their banner (still — too small for its scene to tell),
            // their name as they styled it.
            if (p.dressedUp)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: SizedBox(
                  width: 96,
                  child: Nameplate(
                    user: p,
                    borderRadius: BorderRadius.circular(AppRadius.scaled(12)),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                      child: Column(
                        children: [
                          CardName(p, size: 13.5, live: true),
                          Text(metric, style: onBanner(bodyFont(size: 11.5, weight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.8))), maxLines: 1, softWrap: false, overflow: TextOverflow.fade),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            else ...[
              PlayerName(p, style: bodyFont(size: 13, weight: FontWeight.w800, color: AppColors.ink)),
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(metric, style: bodyFont(size: 12, weight: FontWeight.w700, color: AppColors.mut), maxLines: 1, softWrap: false, overflow: TextOverflow.visible),
              ),
            ],
            AnimatedBuilder(
              animation: reveal,
              builder: (context, _) => Container(
                width: 96,
                height: _barHeight[c.place]! * reveal.value.clamp(0.0, 1.0),
                alignment: Alignment.topCenter,
                padding: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: _barColor[c.place],
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: reveal.value > 0.6
                    ? Opacity(
                        opacity: ((reveal.value - 0.6) / 0.4).clamp(0.0, 1.0),
                        child: Text('${c.place}', style: dispFont(size: 26, weight: FontWeight.w700, color: Colors.white)),
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
