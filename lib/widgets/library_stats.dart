import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic/count_format.dart';
import '../models/library_game_stats.dart';
import '../theme/app_theme.dart';
import 'common.dart';

String _downloadsLabel(int n) => n > 1 ? 'téléchargements' : 'téléchargement';
String _playsLabel(int n) => n > 1 ? 'parties jouées' : 'partie jouée';

/// "12 téléchargements, 845 parties jouées, 32 J'aime" — what a screen
/// reader says for a library game's counts.
String libraryStatsLabel(LibraryGameStats s) =>
    "${compactCount(s.downloads)} ${_downloadsLabel(s.downloads)}, ${compactCount(s.plays)} ${_playsLabel(s.plays)}, ${compactCount(s.likes)} J'aime";

IconData _likeIcon(bool liked) => liked ? Icons.thumb_up_alt_rounded : Icons.thumb_up_off_alt_rounded;

/// A library game's counts in a list row, under its name — only the ones
/// it has, the likes in accent once the player likes it too.
class LibraryStatsLine extends StatelessWidget {
  final LibraryGameStats stats;
  final bool liked;
  const LibraryStatsLine({super.key, required this.stats, this.liked = false});

  @override
  Widget build(BuildContext context) {
    Widget metric(IconData icon, int value, Color color) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 3),
            Text(compactCount(value), style: bodyFont(size: 11.5, weight: FontWeight.w800, color: color)),
          ],
        );
    return Semantics(
      label: libraryStatsLabel(stats),
      excludeSemantics: true,
      child: Wrap(
        spacing: 10,
        runSpacing: 2,
        children: [
          if (stats.downloads > 0) metric(Icons.download_rounded, stats.downloads, AppColors.mut),
          if (stats.plays > 0) metric(Icons.casino_rounded, stats.plays, AppColors.mut),
          if (stats.likes > 0) metric(_likeIcon(liked), stats.likes, liked ? AppColors.accent : AppColors.mut),
        ],
      ),
    );
  }
}

/// A library game's downloads, matches played and likes side by side on its
/// page, the 3-up chips of the home hero — the last one also the button to
/// like it.
class LibraryStatsStrip extends StatelessWidget {
  final LibraryGameStats stats;
  final bool liked;
  final VoidCallback onLike;
  const LibraryStatsStrip({super.key, required this.stats, required this.liked, required this.onLike});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatCell(icon: Icons.download_rounded, value: stats.downloads, label: _downloadsLabel(stats.downloads)),
        const SizedBox(width: 8),
        _StatCell(icon: Icons.casino_rounded, value: stats.plays, label: _playsLabel(stats.plays)),
        const SizedBox(width: 8),
        _LikeCell(likes: stats.likes, liked: liked, onTap: onLike),
      ],
    );
  }
}

class _StatCell extends StatelessWidget {
  final IconData icon;
  final int value;
  final String label;
  const _StatCell({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: cardDecoration(radius: AppRadius.lg),
        child: _CellContent(
          icon: Icon(icon, size: 16, color: AppColors.mut),
          value: AnimatedCounter(value: value, format: compactCount, style: dispFont(size: 19, weight: FontWeight.w700, color: AppColors.ink)),
          label: label,
        ),
      ),
    );
  }
}

class _LikeCell extends StatelessWidget {
  final int likes;
  final bool liked;
  final VoidCallback onTap;
  const _LikeCell({required this.likes, required this.liked, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    void like() {
      HapticFeedback.selectionClick();
      onTap();
    }

    return Expanded(
      child: Semantics(
        container: true,
        button: true,
        toggled: liked,
        label: "J'aime, ${compactCount(likes)}",
        onTap: like,
        excludeSemantics: true,
        child: Pressable(
          onTap: like,
          pressedScale: 0.94,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            decoration: cardDecoration(radius: AppRadius.lg, fill: liked ? AppColors.accentSoft : null, border: liked ? AppColors.accent : null, borderWidth: liked ? 1.5 : 1, selected: liked),
            child: _CellContent(
              // Pops in when liked, like a thumb pressed up.
              icon: TweenAnimationBuilder<double>(
                key: ValueKey(liked),
                tween: Tween(begin: liked && !still ? 0.4 : 1, end: 1),
                duration: const Duration(milliseconds: 520),
                curve: Curves.elasticOut,
                builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
                child: Icon(_likeIcon(liked), size: 16, color: liked ? AppColors.accent : AppColors.ink2),
              ),
              value: AnimatedCounter(value: likes, format: compactCount, duration: const Duration(milliseconds: 500), style: dispFont(size: 19, weight: FontWeight.w700, color: liked ? AppColors.accent : AppColors.ink)),
              label: "J'aime",
              labelColor: liked ? AppColors.accent : AppColors.mut,
            ),
          ),
        ),
      ),
    );
  }
}

/// Icon and number on one line, what they count underneath.
class _CellContent extends StatelessWidget {
  final Widget icon;
  final Widget value;
  final String label;
  final Color? labelColor;
  const _CellContent({required this.icon, required this.value, required this.label, this.labelColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 5),
            Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: value)),
          ],
        ),
        const SizedBox(height: 2),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: bodyFont(size: 11, weight: FontWeight.w600, color: labelColor ?? AppColors.mut)),
      ],
    );
  }
}
