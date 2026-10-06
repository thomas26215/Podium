import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'common.dart';

/// Pill-shaped segmented control — covers `.seg`/`.useg`/`.modeseg` from the
/// prototype, which only differ in font size/padding, not structure.
class SegmentedControl extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final double fontSize;

  const SegmentedControl({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
    this.fontSize = 12.5,
  });

  @override
  Widget build(BuildContext context) {
    final n = labels.length;
    final motion = AppColors.motion;
    // -1…1 across the track; a lone segment just sits centred.
    final x = n <= 1 ? 0.0 : -1 + 2 * selectedIndex.clamp(0, n - 1) / (n - 1);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: AppColors.tokens.track(radius: AppRadius.scaled(14)),
      child: Stack(
        children: [
          // One thumb that glides to the selected segment, instead of each
          // segment fading its own background in and out — at the pace of
          // the surface style: snapping in neo-brutalism, wobbling into
          // place in clay (stopped by the track's ends).
          if (selectedIndex >= 0 && selectedIndex < n)
            Positioned.fill(
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: x),
                duration: motion.move,
                curve: motion.moveCurve,
                builder: (context, x, child) => Align(alignment: Alignment(x.clamp(-1.0, 1.0), 0), child: child),
                child: FractionallySizedBox(
                  widthFactor: 1 / n,
                  heightFactor: 1,
                  // In the surface style — raised out of a hollowed track
                  // in neumorphism, lifted off the track in dark mode.
                  child: Container(decoration: AppColors.tokens.segmentThumb(radius: AppRadius.scaled(10))),
                ),
              ),
            ),
          Row(
            children: [
              for (var i = 0; i < n; i++)
                Expanded(
                  child: Pressable(
                    behavior: HitTestBehavior.opaque,
                    pressedScale: 0.97,
                    onTap: () => onChanged(i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                      child: AnimatedDefaultTextStyle(
                        duration: motion.change,
                        style: bodyFont(
                          size: fontSize,
                          weight: FontWeight.w700,
                          color: i == selectedIndex ? AppColors.ink : AppColors.mut,
                        ),
                        child: Text(labels[i], textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
