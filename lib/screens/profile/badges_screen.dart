import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/badges.dart';
import '../../models/app_user.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/badge_widgets.dart';
import '../../widgets/common.dart';

/// Every badge for [uid]: unlocked ones first, then the rest with how far
/// along they are (judged on the active group/salon — see
/// AppState.badgeStatsFor).
class BadgesScreen extends StatelessWidget {
  final String uid;
  const BadgesScreen({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final user = app.playerById(uid);
    final isMe = uid == app.currentUser?.uid;
    final stats = app.badgeStatsFor(uid);
    final earnedIds = app.earnedBadgeIds(uid);
    final earned = kBadges.where((b) => earnedIds.contains(b.id)).toList();
    final locked = kBadges.where((b) => !earnedIds.contains(b.id)).toList()..sort((a, b) => b.progress(stats).compareTo(a.progress(stats)));

    Widget tile(BadgeDef b, bool isEarned) {
      final pinned = user?.showcasedBadges.contains(b.id) ?? false;
      return Pressable(
        onTap: () => showBadgeDetail(
          context,
          badge: b,
          earned: isEarned,
          stats: stats,
          showcased: pinned,
          onToggleShowcase: isMe ? () => app.toggleShowcasedBadge(b.id) : null,
        ),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                BadgeMedal(badge: b, earned: isEarned, size: 64, progress: isEarned ? null : b.progress(stats)),
                if (pinned)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(color: AppColors.accent, shape: BoxShape.circle, border: Border.all(color: AppColors.bg, width: 2)),
                      child: const Icon(Icons.push_pin_rounded, size: 11, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 7),
            Text(b.name, textAlign: TextAlign.center, maxLines: 2, style: bodyFont(size: 11.5, weight: FontWeight.w800, color: isEarned ? AppColors.ink : AppColors.mut, height: 1.15)),
          ],
        ),
      );
    }

    Widget grid(List<BadgeDef> badges, bool isEarned, int baseMs) => GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 14,
          crossAxisSpacing: 8,
          childAspectRatio: 0.66,
          children: [
            for (final (i, b) in badges.indexed) FadeSlideIn(delay: staggerDelay(i, baseMs: baseMs, stepMs: 35, maxMs: 500), child: tile(b, isEarned)),
          ],
        );

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        foregroundColor: AppColors.ink,
        title: Text(isMe ? 'Mes badges' : 'Badges de ${user?.displayName ?? 'ce joueur'}', style: bodyFont(size: 17, weight: FontWeight.w800, color: AppColors.ink)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 40),
        children: [
          FadeSlideIn(child: _ProgressSummary(earned: earned.length, total: kBadges.length)),
          if (isMe)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Touchez un badge débloqué pour le mettre en avant sous votre nom ($kMaxShowcasedBadges maximum).',
                style: bodyFont(size: 12.5, weight: FontWeight.w600, color: AppColors.mut),
              ),
            ),
          const SizedBox(height: 22),
          if (earned.isNotEmpty) ...[
            SectionHeader(title: 'Débloqués · ${earned.length}'),
            grid(earned, true, 60),
            const SizedBox(height: 18),
          ],
          if (locked.isNotEmpty) ...[
            SectionHeader(title: 'À débloquer · ${locked.length}'),
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('Progression calculée sur les parties de ce groupe.', style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut)),
              ),
            grid(locked, false, 120),
          ],
        ],
      ),
    );
  }
}

class _ProgressSummary extends StatelessWidget {
  final int earned;
  final int total;
  const _ProgressSummary({required this.earned, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(AppRadius.xl)),
      child: Row(
        children: [
          Text('🏅', style: const TextStyle(fontSize: 30)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    AnimatedCounter(value: earned, style: dispFont(size: 24, weight: FontWeight.w800, color: AppColors.ink)),
                    Text(' / $total badges', style: bodyFont(size: 13, weight: FontWeight.w700, color: AppColors.mut)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: total == 0 ? 0 : earned / total),
                    duration: const Duration(milliseconds: 1000),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) => LinearProgressIndicator(value: v, minHeight: 8, color: AppColors.gold, backgroundColor: AppColors.segTrack),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
