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
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.segTrack, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                  decoration: BoxDecoration(
                    color: i == selectedIndex ? AppColors.card : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: i == selectedIndex
                        ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 3, offset: const Offset(0, 1))]
                        : null,
                  ),
                  child: Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: bodyFont(
                      size: fontSize,
                      weight: FontWeight.w700,
                      color: i == selectedIndex ? AppColors.ink : AppColors.mut,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
