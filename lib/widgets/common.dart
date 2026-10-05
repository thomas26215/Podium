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

  /// Also dims the child slightly while held — for full-width rows/cards,
  /// where a 2% scale alone is too subtle to notice under a thumb.
  final bool dimOnPress;

  /// [HitTestBehavior.opaque] for rows whose padding/gaps should be
  /// tappable too, not just the painted text/icons.
  final HitTestBehavior? behavior;
  const Pressable({super.key, required this.child, this.onTap, this.onLongPress, this.pressedScale = 0.96, this.dimOnPress = false, this.behavior});

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    if (_pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    // Quick to sink in, a touch springy on release.
    Widget child = AnimatedScale(
      scale: _pressed ? widget.pressedScale : 1.0,
      duration: Duration(milliseconds: _pressed ? 90 : 220),
      curve: _pressed ? Curves.easeOut : Curves.easeOutBack,
      child: widget.child,
    );
    if (widget.dimOnPress) {
      child = AnimatedOpacity(opacity: _pressed ? 0.7 : 1.0, duration: const Duration(milliseconds: 120), child: child);
    }
    return GestureDetector(
      behavior: widget.behavior,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: child,
    );
  }
}

/// Entrance delay for the [index]th item of a staggered list — capped, so a
/// long list's 40th row doesn't sit invisible for over a second while the
/// user is already scrolling past it.
Duration staggerDelay(int index, {int baseMs = 0, int stepMs = 40, int maxMs = 360}) {
  return Duration(milliseconds: (baseMs + index * stepMs).clamp(0, maxMs));
}

/// Wraps each of [children] in a [FadeSlideIn] with an increasing delay —
/// the one-liner for "this screen's sections cascade in" instead of
/// hand-numbering every delay.
List<Widget> staggered(List<Widget> children, {int baseMs = 0, int stepMs = 50, int maxMs = 400}) {
  return [
    for (final (i, c) in children.indexed) FadeSlideIn(delay: staggerDelay(i, baseMs: baseMs, stepMs: stepMs, maxMs: maxMs), child: c),
  ];
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

/// Custom ease-out, much more front-loaded than any named `Curves` constant
/// (even `easeOutExpo`, which is already the steepest standard one — and
/// still spends 30% of the duration covering the last ~12% of the value).
/// The control points here shove almost the entire climb into roughly the
/// first tenth of the duration, so the back nine-tenths reads as a
/// deliberate, visible crawl into place rather than "arrived, then idle."
const Curve _counterCurve = Cubic(0.03, 0.98, 0.15, 1.0);

/// Animates an integer value counting up/down to its new total whenever it
/// changes, instead of snapping — used anywhere a score/tally is displayed
/// (stat chips, ranking metrics, live scores) so updates read as *movement*
/// rather than a jump cut. Deliberately a strong ease-out (races through
/// the early numbers, visibly slows into the last few) rather than a
/// gentler curve — that "counting down into place" feel is the whole point,
/// not just a smoothing pass.
class AnimatedCounter extends StatelessWidget {
  final int value;
  final TextStyle? style;
  final TextAlign? textAlign;
  final Duration duration;
  const AnimatedCounter({super.key, required this.value, this.style, this.textAlign, this.duration = const Duration(milliseconds: 1100)});

  @override
  Widget build(BuildContext context) {
    // `begin: 0` only actually matters for the very first build (before any
    // paint, so this widget counts up from zero right as it appears) —
    // TweenAnimationBuilder itself takes care of animating from whatever is
    // currently on screen to the new `end` on every later rebuild where
    // `value` changed, never jumping back to 0 on an update.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: _counterCurve,
      builder: (context, v, _) => Text('${v.round()}', style: style, textAlign: textAlign),
    );
  }
}

/// `.chip3` — the 3-up stat chips under the home hero.
class StatChip extends StatelessWidget {
  final int value;
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
            AnimatedCounter(value: value, style: dispFont(size: 22, weight: FontWeight.w700, color: AppColors.ink)),
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
          // Shortened rather than overflowing when an action shares the
          // row — only then, since a bare header may sit in a Row of its own
          // (unbounded width, where Flexible can't lay out).
          if (actionLabel != null)
            Flexible(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyFont(size: 17, weight: FontWeight.w800, color: AppColors.ink, letterSpacing: -0.3)))
          else
            Text(title, style: bodyFont(size: 17, weight: FontWeight.w800, color: AppColors.ink, letterSpacing: -0.3)),
          if (actionLabel != null) ...[
            const SizedBox(width: 12),
            Pressable(
              onTap: onAction,
              child: Text(actionLabel!, style: bodyFont(size: 13, weight: FontWeight.w700, color: AppColors.accent)),
            ),
          ],
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
          // One-shot springy pop with a little tilt, then rests — never a
          // looping bob (that would keep `pumpAndSettle()` from settling).
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 700),
            curve: Curves.elasticOut,
            builder: (context, t, child) => Transform.rotate(
              angle: 0.25 * (1 - t),
              child: Transform.scale(scale: 0.4 + 0.6 * t, child: child),
            ),
            child: Container(
              width: 76,
              height: 76,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.card, shape: BoxShape.circle, border: Border.all(color: AppColors.line)),
              child: Text(emoji, style: const TextStyle(fontSize: 36)),
            ),
          ),
          const SizedBox(height: 14),
          FadeSlideIn(
            delay: const Duration(milliseconds: 120),
            offsetY: 8,
            child: Text(message, textAlign: TextAlign.center, style: bodyFont(size: 14, weight: FontWeight.w600, color: AppColors.mut)),
          ),
        ],
      ),
    );
  }
}

/// The app's loading indicator: three podium bars (2nd, 1st, 3rd) rising
/// and settling in a wave — on-brand where a bare spinner felt generic.
/// Loops while shown, exactly like the `CircularProgressIndicator` it
/// replaces, so only use it where a spinner would have been.
class PodiumLoader extends StatefulWidget {
  final Color? color;
  final double size;
  final String? label;
  const PodiumLoader({super.key, this.color, this.size = 34, this.label});

  @override
  State<PodiumLoader> createState() => _PodiumLoaderState();
}

class _PodiumLoaderState extends State<PodiumLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();

  // Display order 2nd · 1st · 3rd: each bar's resting height and its
  // offset in the wave.
  static const _bars = [(rest: 0.62, phase: 0.15), (rest: 1.0, phase: 0.0), (rest: 0.42, phase: 0.3)];

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppColors.accent;
    final barW = widget.size * 0.26;
    final gap = widget.size * 0.1;
    final loader = SizedBox(
      width: barW * 3 + gap * 2,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final (i, b) in _bars.indexed) ...[
              if (i > 0) SizedBox(width: gap),
              Builder(builder: (_) {
                // A smooth 0→1→0 pulse per bar, offset by its phase.
                final t = (_c.value - b.phase) % 1.0;
                final pulse = Curves.easeInOut.transform(t < 0.5 ? t * 2 : (1 - t) * 2);
                return Container(
                  width: barW,
                  height: widget.size * b.rest * (0.45 + 0.55 * pulse),
                  decoration: BoxDecoration(
                    color: i == 1 ? color : color.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(barW * 0.35), bottom: Radius.circular(barW * 0.12)),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
    if (widget.label == null) return loader;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        loader,
        const SizedBox(height: 14),
        Text(widget.label!, textAlign: TextAlign.center, style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut)),
      ],
    );
  }
}

/// `showDialog` with the app's own entrance: the dialog springs up from
/// slightly smaller while the barrier fades in, instead of Material's flat
/// fade — use it for every dialog so they all open the same way.
Future<T?> showAppDialog<T>({required BuildContext context, required WidgetBuilder builder, bool barrierDismissible = true}) {
  final themes = InheritedTheme.capture(from: context, to: Navigator.of(context, rootNavigator: true).context);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: AppColors.isDark ? 0.6 : 0.42),
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (dialogContext, _, _) => themes.wrap(SafeArea(child: Builder(builder: builder))),
    transitionBuilder: (context, animation, _, child) {
      final scale = CurvedAnimation(parent: animation, curve: Curves.easeOutBack, reverseCurve: Curves.easeInCubic);
      final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut, reverseCurve: Curves.easeIn);
      return FadeTransition(
        opacity: fade,
        child: ScaleTransition(scale: Tween<double>(begin: 0.9, end: 1).animate(scale), child: child),
      );
    },
  );
}

/// The app's one recurring `TextField`/`TextFormField` look: filled card
/// background, a hairline border that turns accent-colored on focus. Every
/// text input in the app should build its `decoration:` from this instead of
/// repeating the three-`OutlineInputBorder` block inline.
InputDecoration appFieldDecoration({
  String? hintText,
  EdgeInsetsGeometry contentPadding = const EdgeInsets.all(14),
  Widget? prefixIcon,
  Widget? suffixIcon,
  Color? focusColor,
  Color? fillColor,
}) {
  final border = OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.line, width: 1.5));
  return InputDecoration(
    hintText: hintText,
    filled: true,
    fillColor: fillColor ?? AppColors.card,
    contentPadding: contentPadding,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    border: border,
    enabledBorder: border,
    focusedBorder: border.copyWith(borderSide: BorderSide(color: focusColor ?? AppColors.accent, width: 1.5)),
  );
}

/// Shared "emoji box + title/subtitle column + trailing add icon" row used
/// by both the game-library and other-groups game browsers (see
/// `game_library_browser.dart`/`other_groups_game_browser.dart`) — those two
/// only ever differed in what goes in [title]/[subtitle], never in the
/// surrounding card chrome.
class GameTileRow extends StatelessWidget {
  final String emoji;
  final Widget title;
  final Widget subtitle;
  final VoidCallback onTap;

  /// Replaces the default "add" icon at the end of the row.
  final Widget? trailing;
  const GameTileRow({super.key, required this.emoji, required this.title, required this.subtitle, required this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line, width: 1.5), borderRadius: BorderRadius.circular(AppRadius.lg)),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(13)),
              child: Text(emoji, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [title, subtitle],
              ),
            ),
            trailing ?? Icon(Icons.add_circle_rounded, color: AppColors.accent, size: 26),
          ],
        ),
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
    // A soft accent glow under the button only while it's actionable —
    // fades out as it disables, so "you can go now" reads at a glance.
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: enabled ? 0.28 : 0), blurRadius: 18, offset: const Offset(0, 8))],
      ),
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
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, a) => FadeTransition(opacity: a, child: ScaleTransition(scale: Tween<double>(begin: 0.8, end: 1).animate(a), child: child)),
          child: loading
              ? const SizedBox(key: ValueKey('loading'), width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(label, key: const ValueKey('label'), style: bodyFont(size: 16, weight: FontWeight.w800, color: Colors.white)),
        ),
      ),
    );
  }
}
