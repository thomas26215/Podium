import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../logic/badges.dart';
import '../theme/app_theme.dart';
import 'ambient_loop.dart';
import 'common.dart';
import 'fx_kit.dart';
import 'prestige_medal.dart';

/// Medal colours per tier: rim gradient, then the face behind the emoji.
({Color from, Color to, Color face}) badgeTierColors(BadgeTier t) => switch (t) {
      BadgeTier.bronze => (from: const Color(0xFFB0652A), to: const Color(0xFFE9A86B), face: const Color(0xFFFFF1E4)),
      BadgeTier.silver => (from: const Color(0xFF8D96A5), to: const Color(0xFFE3E7EE), face: const Color(0xFFF5F7FA)),
      BadgeTier.gold => (from: const Color(0xFFC98A12), to: const Color(0xFFFFD873), face: const Color(0xFFFFF8E1)),
      BadgeTier.platinum => (from: const Color(0xFF4F8A96), to: const Color(0xFFCFF4F2), face: const Color(0xFFEFFCFB)),
      BadgeTier.diamond => (from: const Color(0xFF2A6FE8), to: const Color(0xFF9FE6FF), face: const Color(0xFFEAF7FF)),
      BadgeTier.mythic => (from: const Color(0xFF8A2BE2), to: const Color(0xFFFF7AD9), face: const Color(0xFFFCEFFF)),
    };

String badgeTierLabel(BadgeTier t) => switch (t) {
      BadgeTier.bronze => 'Bronze',
      BadgeTier.silver => 'Argent',
      BadgeTier.gold => 'Or',
      BadgeTier.platinum => 'Platine',
      BadgeTier.diamond => 'Diamant',
      BadgeTier.mythic => 'Mythique',
    };

/// A tiny swatch of [tier] — its medal's shape in its colours — for legends.
class BadgeTierGlyph extends StatelessWidget {
  final BadgeTier tier;
  final double size;
  const BadgeTierGlyph({super.key, required this.tier, this.size = 12});

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _TierGlyphPainter(tier));
}

class _TierGlyphPainter extends CustomPainter {
  final BadgeTier tier;
  _TierGlyphPainter(this.tier);

  @override
  void paint(Canvas canvas, Size s) {
    final c = badgeTierColors(tier);
    final shape = isPrestigeTier(tier) ? prestigeGlyph(tier, s.width) : (Path()..addOval(Offset.zero & s));
    canvas.drawPath(shape, Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(s.width, s.height), [c.to, c.from]));
  }

  @override
  bool shouldRepaint(_TierGlyphPainter old) => old.tier != tier;
}

/// The medal for one badge. Bronze, silver and gold ones are round. Locked:
/// greyed out, with a progress ring when [progress] is given. Earned:
/// tier-coloured rim and a shine sweeping across it as it appears — or,
/// when [live], kept alive on its own loop (the light turning round the
/// rim, a shine every few seconds, gold ones twinkling). [phase] draws that
/// live look at one point of the loop, for a parent that runs the loop
/// itself.
///
/// Only go [live] where the player chose to show the badge off: a looping
/// medal on a default screen would keep tests' pumpAndSettle from settling.
/// Rarer tiers are the exception: they get a design of their own, which
/// always moves once earned (see [PrestigeMedal]) — earning one is the
/// player's doing too.
class BadgeMedal extends StatelessWidget {
  final BadgeDef badge;
  final bool earned;
  final double size;
  final double? progress;
  final bool live;
  final double? phase;
  const BadgeMedal({super.key, required this.badge, required this.earned, this.size = 56, this.progress, this.live = false, this.phase});

  @override
  Widget build(BuildContext context) {
    if (isPrestigeTier(badge.tier)) return PrestigeMedal(badge: badge, earned: earned, size: size, progress: progress, phase: phase);
    final c = badgeTierColors(badge.tier);
    final rim = size * 0.09;
    if (!earned) {
      final p = progress;
      return SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: size,
              height: size,
              padding: EdgeInsets.all(rim),
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.segTrack),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.card),
                child: Opacity(opacity: 0.3, child: Text(badge.emoji, style: TextStyle(fontSize: size * 0.4))),
              ),
            ),
            if (p != null && p > 0)
              SizedBox(
                width: size,
                height: size,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: p),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => CircularProgressIndicator(value: v, strokeWidth: rim, color: AppColors.accent, backgroundColor: Colors.transparent, strokeCap: StrokeCap.round),
                ),
              ),
            Positioned(right: 0, bottom: 0, child: BadgeLockPip(size: size)),
          ],
        ),
      );
    }
    Widget medal(double rimTurn) => Container(
          width: size,
          height: size,
          padding: EdgeInsets.all(rim),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(colors: [c.to, c.from, c.to, c.from, c.to], transform: GradientRotation(rimTurn)),
            boxShadow: [BoxShadow(color: c.from.withValues(alpha: 0.4), blurRadius: size * 0.22, offset: Offset(0, size * 0.06))],
          ),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(center: const Alignment(-0.3, -0.35), colors: [Colors.white, c.face])),
            child: Text(badge.emoji, style: TextStyle(fontSize: size * 0.4)),
          ),
        );
    Widget alive(double ph) => CustomPaint(foregroundPainter: _MedalFx(ph, badge.tier), child: medal(ph * tau));
    if (phase != null) return alive(phase!);
    if (live) {
      // Each badge on its own period, so a row of them never shines in unison.
      return RepaintBoundary(child: AmbientLoop(period: Duration(milliseconds: 4200 + (hash01(badge.id.length * 7 + badge.id.codeUnitAt(0)) * 1800).round()), builder: (context, ph) => alive(ph)));
    }
    // The one-off shine as it appears.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeInOut,
      builder: (context, t, child) => CustomPaint(foregroundPainter: _MedalFx(null, badge.tier, shine: t), child: child),
      child: medal(0),
    );
  }
}

/// A shine band across the medal, plus (gold, live) twinkles on its rim.
class _MedalFx extends CustomPainter {
  final double? ph;
  final BadgeTier tier;
  final double? shine;
  _MedalFx(this.ph, this.tier, {this.shine});

  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero);
    final r = s.width / 2;
    final u = shine ?? (ph == null ? null : loopWindow(ph!, 0.05, 0.3));
    if (u != null) drawSheen(canvas, Path()..addOval(Rect.fromCircle(center: c, radius: r)), c, r, u);
    if (ph != null && tier == BadgeTier.gold) {
      for (var i = 0; i < 2; i++) {
        final k = loopWindow(ph!, 0.45 + i * 0.25, 0.18);
        if (k == null) continue;
        final a = -math.pi / 2 + (i == 0 ? -0.9 : 2.1);
        final p = c + Offset(math.cos(a), math.sin(a)) * r * 0.92;
        drawSparkle(canvas, p, r * 0.32 * bump(k), fillPaint(const Color(0xFFFFF6D5), bump(k)));
      }
    }
  }

  @override
  bool shouldRepaint(_MedalFx old) => old.ph != ph || old.shine != shine;
}

/// Full details of one badge: what it takes, how far along [stats] is, and
/// — on the signed-in player's own earned badge — a "show on my profile"
/// toggle.
Future<void> showBadgeDetail(
  BuildContext context, {
  required BadgeDef badge,
  required bool earned,
  BadgeStats? stats,
  bool? showcased,
  VoidCallback? onToggleShowcase,
}) {
  return showAppDialog(
    context: context,
    builder: (dialogContext) {
      final value = stats == null ? null : badge.value(stats).clamp(0, badge.target);
      return Dialog(
        backgroundColor: AppColors.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 800),
                curve: Curves.elasticOut,
                builder: (context, t, child) => Transform.rotate(angle: (1 - t) * -0.5, child: Transform.scale(scale: 0.5 + 0.5 * t, child: child)),
                child: BadgeMedal(badge: badge, earned: earned, size: 96, progress: stats == null ? null : badge.progress(stats)),
              ),
              const SizedBox(height: 16),
              Text(badge.name, textAlign: TextAlign.center, style: dispFont(size: 21, weight: FontWeight.w800, color: AppColors.ink)),
              const SizedBox(height: 4),
              Text(
                '${badgeTierLabel(badge.tier)} · ${earned ? 'Débloqué' : 'À débloquer'}',
                style: bodyFont(size: 12, weight: FontWeight.w800, color: earned ? badgeTierColors(badge.tier).from : AppColors.mut, letterSpacing: 0.3),
              ),
              const SizedBox(height: 12),
              Text(badge.description, textAlign: TextAlign.center, style: bodyFont(size: 14, weight: FontWeight.w600, color: AppColors.ink2)),
              if (!earned && value != null && badge.target > 1) ...[
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: badge.progress(stats!)),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) => LinearProgressIndicator(value: v, minHeight: 8, color: AppColors.accent, backgroundColor: AppColors.segTrack),
                  ),
                ),
                const SizedBox(height: 6),
                Text('$value / ${badge.target}', style: bodyFont(size: 12.5, weight: FontWeight.w800, color: AppColors.mut)),
              ],
              const SizedBox(height: 20),
              if (earned && onToggleShowcase != null)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      onToggleShowcase();
                      Navigator.of(dialogContext).pop();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accent,
                      side: BorderSide(color: AppColors.accent, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    ),
                    icon: Icon(showcased == true ? Icons.push_pin_outlined : Icons.push_pin_rounded, size: 18),
                    label: Text(showcased == true ? 'Retirer de mon profil' : 'Mettre en avant sur mon profil', style: bodyFont(size: 14, weight: FontWeight.w800, color: AppColors.accent)),
                  ),
                ),
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Fermer')),
            ],
          ),
        ),
      );
    },
  );
}

/// The "badge unlocked!" celebration: drops in from the top, the medal
/// spins in, holds a moment, then slides away and calls [onDone]. Driven by
/// one animation controller — no timers — so it always runs to completion.
class BadgeUnlockBanner extends StatefulWidget {
  final List<String> badgeIds;
  final VoidCallback onDone;
  const BadgeUnlockBanner({super.key, required this.badgeIds, required this.onDone});

  @override
  State<BadgeUnlockBanner> createState() => _BadgeUnlockBannerState();
}

class _BadgeUnlockBannerState extends State<BadgeUnlockBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3800))
    ..forward().whenComplete(() {
      if (mounted) widget.onDone();
    });

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The rarest one leads the celebration.
    final badges = widget.badgeIds.map(badgeById).whereType<BadgeDef>().toList()..sort((a, b) => b.tier.index.compareTo(a.tier.index));
    if (badges.isEmpty) return const SizedBox.shrink();
    final first = badges.first;
    final title = badges.length == 1 ? 'Badge débloqué !' : '${badges.length} badges débloqués !';
    final subtitle = badges.length == 1 ? first.name : badges.map((b) => b.name).join(' · ');
    // 0–12%: drop in · 12–85%: hold · 85–100%: leave.
    final inOut = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOutBack)), weight: 12),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 73),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeInCubic)), weight: 15),
    ]).animate(_c);
    final spin = CurvedAnimation(parent: _c, curve: const Interval(0.05, 0.35, curve: Curves.elasticOut));
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, -90 * (1 - inOut.value)),
        child: Opacity(opacity: inOut.value.clamp(0.0, 1.0), child: child),
      ),
      child: GestureDetector(
        onTap: () {
          if (_c.value < 0.85) _c.animateTo(1, duration: const Duration(milliseconds: 260));
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 18, 12),
          decoration: BoxDecoration(
            color: AppColors.hero,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: badgeTierColors(first.tier).to.withValues(alpha: 0.6), width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 28, offset: const Offset(0, 12))],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                children: [
                  AnimatedBuilder(
                    animation: spin,
                    builder: (context, child) => Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..rotateY(math.pi * 2 * (1 - spin.value))
                        ..scaleByDouble(0.6 + 0.4 * spin.value, 0.6 + 0.4 * spin.value, 1, 1),
                      child: child,
                    ),
                    child: BadgeMedal(badge: first, earned: true, size: 48),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(title.toUpperCase(), style: bodyFont(size: 11, weight: FontWeight.w800, color: badgeTierColors(first.tier).to, letterSpacing: 0.8)),
                        const SizedBox(height: 2),
                        Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: bodyFont(size: 15, weight: FontWeight.w800, color: Colors.white)),
                      ],
                    ),
                  ),
                ],
              ),
              // Confetti and sparks bursting out of the medal as it lands.
              Positioned.fill(child: IgnorePointer(child: AnimatedBuilder(animation: _c, builder: (context, _) => CustomPaint(painter: _UnlockBurst(_c.value, badgeTierColors(first.tier).to))))),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnlockBurst extends CustomPainter {
  final double v;
  final Color tier;
  _UnlockBurst(this.v, this.tier);

  static const _colors = [Color(0xFFFF5B34), Color(0xFFFFC94D), Color(0xFF4DC3FF), Color(0xFF6BFF95), Color(0xFFC77DFF), Color(0xFFFF6BB5)];

  @override
  void paint(Canvas canvas, Size s) {
    final sec = (v - 0.08) * 3.8;
    if (sec <= 0 || sec > 2.2) return;
    const origin = Offset(24, 24);
    final fade = 1 - span(sec, 1.4, 2.2);
    for (var k = 0; k < 34; k++) {
      final a = -math.pi / 2 + (hash01(k) - 0.5) * math.pi * 1.6;
      final speed = 220 + 280 * hash01(k + 40);
      final p = ballistic(origin, Offset(math.cos(a), math.sin(a)) * speed, sec, gravity: 700, drag: 1.6);
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(sec * (5 + 6 * hash01(k + 80)) * (k.isEven ? 1 : -1));
      canvas.scale(1, math.cos(sec * 9 + k).abs().clamp(0.2, 1.0));
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: 5, height: 8), fillPaint(k % 4 == 0 ? tier : _colors[k % _colors.length], fade));
      canvas.restore();
    }
    if (sec < 0.9) {
      final ring = sec / 0.9;
      canvas.drawCircle(origin, 20 + ring * 46, strokePaint(tier, 3 * (1 - ring) + 0.5, 1 - ring));
      for (var k = 0; k < 8; k++) {
        final a = k / 8 * tau;
        drawSparkle(canvas, origin + Offset(math.cos(a), math.sin(a)) * (26 + ring * 40), 6 * bump(ring), fillPaint(Colors.white, 1 - ring));
      }
    }
  }

  @override
  bool shouldRepaint(_UnlockBurst old) => old.v != v;
}
