import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'common.dart';

/// A selectable pill — used for categories, counting types, theme tags and
/// grid filters. A null [onTap] makes it purely visual, for use as the face
/// of a widget that handles the tap itself (e.g. a `PopupMenuButton`).
class OptionChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  const OptionChip({super.key, required this.label, required this.selected, this.onTap, this.icon});

  @override
  Widget build(BuildContext context) {
    final chip = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: selected ? AppColors.accentSoft : AppColors.card,
        border: Border.all(color: selected ? AppColors.accent : AppColors.line, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: selected ? AppColors.accent : AppColors.mut),
            const SizedBox(width: 6),
          ],
          Text(label, style: bodyFont(size: 13.5, weight: FontWeight.w700, color: selected ? AppColors.accent : AppColors.ink2)),
        ],
      ),
    );
    // Pressable's gesture detector would swallow the tap a wrapping
    // PopupMenuButton needs — so a purely visual chip stays unwrapped.
    return onTap == null ? chip : Pressable(onTap: onTap, child: chip);
  }
}
