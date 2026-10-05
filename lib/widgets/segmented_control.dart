import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

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
    // -1…1 across the track; a lone segment just sits centred.
    final x = n <= 1 ? 0.0 : -1 + 2 * selectedIndex.clamp(0, n - 1) / (n - 1);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.segTrack, borderRadius: BorderRadius.circular(14)),
      child: Stack(
        children: [
          // One white thumb that glides to the selected segment, instead of
          // each segment fading its own background in and out.
          if (selectedIndex >= 0 && selectedIndex < n)
            Positioned.fill(
              child: AnimatedAlign(
                alignment: Alignment(x, 0),
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                child: FractionallySizedBox(
                  widthFactor: 1 / n,
                  heightFactor: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      // In dark mode `card` is barely off the track colour —
                      // lift the thumb so the selection actually shows.
                      color: AppColors.isDark ? const Color(0xFF3A3843) : AppColors.card,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 3, offset: const Offset(0, 1))],
                    ),
                  ),
                ),
              ),
            ),
          Row(
            children: [
              for (var i = 0; i < n; i++)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
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
