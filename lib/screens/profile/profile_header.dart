import 'package:flutter/material.dart';

import '../../logic/badges.dart';
import '../../models/app_user.dart';
import '../../models/game.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ambient_loop.dart';
import '../../widgets/avatar.dart';
import '../../widgets/badge_widgets.dart';
import '../../widgets/fx_kit.dart';
import '../../widgets/profile_banners.dart';
import '../../widgets/profile_style.dart';

/// The top of a profile: the player's chosen banner gradient behind their
/// avatar, name, bio, pinned badges and favourite game. Also the live
/// preview in `EditProfileScreen`, which is why it takes the user as-is
/// rather than reading AppState.
class ProfileHeaderCard extends StatelessWidget {
  final AppUser user;
  final String? subtitle;
  final Game? favoriteGame;
  final VoidCallback? onEdit;
  final void Function(BadgeDef badge)? onTapBadge;

  /// Changing it replays the profile effect (the editor's "Rejouer").
  final Object? effectReplayToken;
  const ProfileHeaderCard({super.key, required this.user, this.subtitle, this.favoriteGame, this.onEdit, this.onTapBadge, this.effectReplayToken});

  @override
  Widget build(BuildContext context) {
    final theme = bannerThemeById(user.banner);
    final showcased = user.showcasedBadges.map(badgeById).whereType<BadgeDef>().toList();
    final title = titleById(user.titleId);
    final titleBadge = title?.badgeId == null ? null : badgeById(title!.badgeId!);
    final meta = [if (user.pronouns.isNotEmpty) user.pronouns, ?subtitle].join(' · ');
    return AnimatedContainer(
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        boxShadow: [BoxShadow(color: theme.colors.last.withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        child: Stack(
          children: [
            Positioned.fill(child: ProfileBannerBackground(themeId: user.banner)),
            // A soft light blob for depth, in the player's own avatar colour.
            Positioned(
              right: -50,
              top: -60,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 450),
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [Color(user.color).withValues(alpha: 0.45), Colors.transparent]),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      FramedAvatar(
                        frameId: user.avatarFrame,
                        size: 72,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, a) => ScaleTransition(scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack), child: child),
                          child: Avatar(key: ValueKey('${user.initial}|${user.color}'), initial: user.initial, color: Color(user.color), size: 72, fontSize: 30),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            StyledName(text: user.displayName, fontId: user.nameFont, effectId: user.nameEffect, accent: Color(user.color)),
                            if (title != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                '✦ ${title.label}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: bodyFont(size: 12.5, weight: FontWeight.w800, color: titleBadge == null ? Colors.white.withValues(alpha: 0.9) : badgeTierColors(titleBadge.tier).to, letterSpacing: 0.3)
                                    .copyWith(shadows: const [Shadow(color: Color(0x80000000), blurRadius: 6)]),
                              ),
                            ],
                            if (meta.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(meta, maxLines: 2, style: bodyFont(size: 12.5, weight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.72))),
                            ],
                          ],
                        ),
                      ),
                      if (onEdit != null) const SizedBox(width: 44),
                    ],
                  ),
                  if (user.status.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _StatusBubble(emoji: user.statusEmoji, text: user.status),
                  ],
                  if (user.bio.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(user.bio, style: bodyFont(size: 14, weight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.95), height: 1.35).copyWith(shadows: const [Shadow(color: Color(0x80000000), blurRadius: 6)])),
                  ],
                  if (favoriteGame != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(favoriteGame!.emoji, style: const TextStyle(fontSize: 15)),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text.rich(
                            TextSpan(children: [
                              TextSpan(text: 'Jeu préféré · ', style: bodyFont(size: 12.5, weight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.65))),
                              TextSpan(text: favoriteGame!.name, style: bodyFont(size: 12.5, weight: FontWeight.w800, color: Colors.white)),
                            ]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (showcased.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    _BadgeShowcase(badges: showcased, onTap: onTapBadge),
                  ],
                ],
              ),
            ),
            Positioned.fill(child: ProfileEffectOverlay(effectId: user.profileEffect, replayToken: effectReplayToken)),
            if (onEdit != null)
              Positioned(
                top: 12,
                right: 12,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.25),
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: 'Modifier le profil',
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_rounded, size: 19, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The player's pinned badges as a trophy shelf across the bottom of the
/// card: full medals on a glow of their tier colour, each dropping in with
/// a bounce — meant to read as achievements, not tags.
class _BadgeShowcase extends StatelessWidget {
  final List<BadgeDef> badges;
  final void Function(BadgeDef badge)? onTap;
  const _BadgeShowcase({required this.badges, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 14, 6, 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, b) in badges.indexed)
            Expanded(
              child: TweenAnimationBuilder<double>(
                key: ValueKey(b.id),
                tween: Tween(begin: 0, end: 1),
                duration: Duration(milliseconds: 750 + i * 160),
                curve: Interval(i * 0.15, 1, curve: Curves.elasticOut),
                builder: (context, t, child) => Transform.translate(
                  offset: Offset(0, -18 * (1 - t)),
                  child: Transform.scale(scale: 0.5 + 0.5 * t, child: Opacity(opacity: t.clamp(0.0, 1.0), child: child)),
                ),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onTap == null ? null : () => onTap!(b),
                  child: _ShowcasedMedal(badge: b, index: i),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ShowcasedMedal extends StatelessWidget {
  final BadgeDef badge;
  final int index;
  const _ShowcasedMedal({required this.badge, required this.index});

  @override
  Widget build(BuildContext context) {
    final c = badgeTierColors(badge.tier);
    // Floating gently, its halo breathing, the medal itself alive (light
    // round the rim, a shine now and then) — each a beat apart from the
    // others.
    return AmbientLoop(
      period: const Duration(milliseconds: 5200),
      builder: (context, ph) {
        final p = fract(ph + index * 0.29);
        return Column(
          children: [
            SizedBox(
              width: 84,
              height: 66,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [c.to.withValues(alpha: 0.4 + 0.25 * wave01(p, 0, 2)), c.to.withValues(alpha: 0)]),
                    ),
                  ),
                  Transform.translate(offset: Offset(0, wave(p, 0, 1) * 3), child: BadgeMedal(badge: badge, earned: true, size: 60, phase: p)),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              badge.name,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: bodyFont(size: 12, weight: FontWeight.w800, color: Colors.white, height: 1.15),
            ),
            const SizedBox(height: 2),
            Text(badgeTierLabel(badge.tier).toUpperCase(), style: bodyFont(size: 9, weight: FontWeight.w800, color: c.to, letterSpacing: 1)),
          ],
        );
      },
    );
  }
}

/// The player's custom status, as a little speech bubble pointing up at
/// their avatar.
class _StatusBubble extends StatelessWidget {
  final String? emoji;
  final String text;
  const _StatusBubble({required this.emoji, required this.text});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 28),
          child: CustomPaint(size: const Size(14, 7), painter: _BubbleTail(Colors.black.withValues(alpha: 0.32))),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.32),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (emoji != null) ...[
                Text(emoji!, style: const TextStyle(fontSize: 15)),
                const SizedBox(width: 7),
              ],
              Flexible(child: Text(text, style: bodyFont(size: 13, weight: FontWeight.w700, color: Colors.white))),
            ],
          ),
        ),
      ],
    );
  }
}

class _BubbleTail extends CustomPainter {
  final Color color;
  _BubbleTail(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(Path()..moveTo(0, size.height)..lineTo(size.width / 2, 0)..lineTo(size.width, size.height)..close(), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_BubbleTail old) => old.color != color;
}
