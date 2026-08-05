import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Wraps a `GestureDetector`-driven tap target (custom cards, icon buttons
/// that don't already get Material ripple/elevation feedback) with a
/// subtle scale-down-on-press, so every tap in the app feels responsive
/// instead of just snapping to its result.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;
  const Pressable({super.key, required this.child, this.onTap, this.onLongPress, this.pressedScale = 0.96});

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Fades + slides a child down from just above its final position on first
/// build. Give list items an increasing `delay` (e.g. `index * 40ms`) for a
/// staggered entrance instead of everything popping in at once.
class FadeSlideIn extends StatelessWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final double offsetY;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 380),
    this.offsetY = -16,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration + delay,
      curve: Interval(
        (delay.inMilliseconds / (duration + delay).inMilliseconds).clamp(0.0, 1.0),
        1.0,
        curve: Curves.easeOutCubic,
      ),
      builder: (context, t, child) {
        return Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, offsetY * (1 - t)), child: child),
        );
      },
      child: child,
    );
  }
}

/// `.chip3` — the 3-up stat chips under the home hero.
class StatChip extends StatelessWidget {
  final String value;
  final String label;
  const StatChip({super.key, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.card,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: dispFont(size: 22, weight: FontWeight.w700, color: AppColors.ink)),
            const SizedBox(height: 1),
            Text(label, style: bodyFont(size: 11.5, weight: FontWeight.w600, color: AppColors.mut)),
          ],
        ),
      ),
    );
  }
}

/// `.sec` — section header with an optional trailing action link.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  const SectionHeader({super.key, required this.title, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, right: 2, bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: bodyFont(size: 17, weight: FontWeight.w800, color: AppColors.ink, letterSpacing: -0.3)),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              child: Text(actionLabel!, style: bodyFont(size: 13, weight: FontWeight.w700, color: AppColors.accent)),
            ),
        ],
      ),
    );
  }
}

/// Eyebrow + big display title used at the top of most screens.
class ScreenHeading extends StatelessWidget {
  final String eyebrow;
  final String title;
  const ScreenHeading({super.key, required this.eyebrow, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(eyebrow.toUpperCase(), style: bodyFont(size: 12, weight: FontWeight.w700, color: AppColors.mut, letterSpacing: 1.3)),
          const SizedBox(height: 2),
          Text(title, style: dispFont(size: 30, weight: FontWeight.w700, color: AppColors.ink, height: 1.05, letterSpacing: -0.7)),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String emoji;
  final String message;
  const EmptyState({super.key, required this.emoji, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: bodyFont(size: 14, weight: FontWeight.w600, color: AppColors.mut)),
        ],
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  const PrimaryButton({super.key, required this.label, required this.onPressed, this.loading = false});

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.35),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          elevation: 0,
        ),
        child: loading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(label, style: bodyFont(size: 16, weight: FontWeight.w800, color: Colors.white)),
      ),
    );
  }
}
