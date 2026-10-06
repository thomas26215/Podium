import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../theme/app_theme.dart';
import 'motion_paint.dart';

export 'motion_paint.dart' show Reveal;

/// Every tap target that isn't a Material button — cards, chips, rows,
/// icon buttons — pressed in the player's surface style (see
/// [AppMotion.press]): it sinks into the surface in neumorphism, lands on
/// its hard shadow in neo-brutalism, squashes and wobbles like clay,
/// flares like neon, just shrinks a little in the original style… The
/// surface that fills it takes the press itself (see [SurfaceMotion]), so
/// a card only has to be inside one.
///
/// A quick tap still plays the whole press before it springs back.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// How far it shrinks held down in the original style — and so how
  /// pronounced its press is in every style: 0.98 for a big card, 0.9 for
  /// a small icon button.
  final double pressedScale;

  /// For full-width rows inside a card, which have no surface of their
  /// own: the press shows as the style's highlight behind them (a hollow
  /// in neumorphism, a lit frame in neon…), where a 2% scale alone would
  /// be too subtle to notice under a thumb.
  final bool dimOnPress;

  /// [HitTestBehavior.opaque] for rows whose padding/gaps should be
  /// tappable too, not just the painted text/icons.
  final HitTestBehavior? behavior;
  const Pressable({super.key, required this.child, this.onTap, this.onLongPress, this.pressedScale = 0.96, this.dimOnPress = false, this.behavior});

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> with SingleTickerProviderStateMixin {
  /// 0 at rest → 1 held, unbounded so a release can spring past its rest.
  late final AnimationController _press = AnimationController.unbounded(vsync: this);
  Offset _touch = const Offset(0.5, 0.5);
  bool _held = false;

  /// Let go before it was all the way in: it comes back up once it is.
  bool _releaseOnceIn = false;

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;
  bool get _still => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  void _down(TapDownDetails details) {
    if (!_enabled) return;
    final size = context.size;
    if (size != null && !size.isEmpty) {
      setState(() => _touch = Offset((details.localPosition.dx / size.width).clamp(0.0, 1.0), (details.localPosition.dy / size.height).clamp(0.0, 1.0)));
    }
    _held = true;
    _releaseOnceIn = false;
    if (_still) {
      _press.value = 1;
      return;
    }
    final motion = AppColors.motion;
    _press.animateTo(1, duration: motion.pressIn, curve: motion.pressInCurve).whenCompleteOrCancel(() {
      if (_releaseOnceIn && mounted) _release();
    });
  }

  void _up() {
    if (!_held) return;
    _held = false;
    if (_press.isAnimating && _press.value < 1) {
      _releaseOnceIn = true;
      return;
    }
    _release();
  }

  void _release() {
    _releaseOnceIn = false;
    if (_still) {
      _press.value = 0;
      return;
    }
    final motion = AppColors.motion;
    final spring = motion.releaseSpring;
    if (spring != null) {
      _press.animateWith(SpringSimulation(spring, _press.value, 0, _press.velocity));
    } else {
      _press.animateBack(0, duration: motion.pressOut, curve: motion.pressOutCurve);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppColors.tokens;
    return GestureDetector(
      behavior: widget.behavior,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onTapDown: _down,
      onTapUp: (_) => _up(),
      onTapCancel: _up,
      child: PressPaint(
        press: _press,
        motion: tokens.motion,
        intensity: ((1 - widget.pressedScale) / 0.04).clamp(0.25, 3.0),
        touch: _touch,
        tint: tokens.accent,
        highlight: widget.dimOnPress ? tokens.pressHighlight(radius: AppRadius.md) : null,
        child: widget.child,
      ),
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

/// Brings a child in on first build, in the player's surface style (see
/// [AppMotion.reveal]): it fades in sliding down into place in the original
/// style, extrudes out of the surface in neumorphism, comes into focus in
/// glass, pops on a jelly spring in clay, strikes on like a tube in neon…
/// Give list items an increasing `delay` (e.g. `index * 40ms`, or see
/// [staggered]) for a cascade instead of everything popping in at once.
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;

  /// Where the original slide starts from, vertically (−16: just above).
  /// The other styles only keep how far that is.
  final double offsetY;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 380),
    this.offsetY = -16,
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  CurvedAnimation? _progress;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null || (MediaQuery.maybeDisableAnimationsOf(context) ?? false)) return;
    final motion = AppColors.motion;
    final delay = widget.delay * motion.stagger;
    final total = delay + motion.entrance(widget.duration);
    if (total <= Duration.zero) return;
    final controller = _controller = AnimationController(vsync: this, duration: total)..forward();
    // Linear after the delay: the style shapes it.
    _progress = CurvedAnimation(parent: controller, curve: Interval(delay.inMicroseconds / total.inMicroseconds, 1));
  }

  @override
  void dispose() {
    _progress?.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress;
    if (progress == null || (MediaQuery.maybeDisableAnimationsOf(context) ?? false)) return widget.child;
    return Reveal(animation: progress, motion: AppColors.motion, travel: widget.offsetY, child: widget.child);
  }
}

/// The transition of an [AnimatedSwitcher] swapping content in place, in
/// the player's surface style: what comes in plays a toned-down entrance,
/// what goes drops away.
Widget appSwitchTransition(Widget child, Animation<double> animation) => Reveal(animation: animation, motion: AppColors.motion, travel: -8, amplitude: 0.6, anchor: Alignment.center, child: child);

/// The transition of an [AnimatedSwitcher] moving on to the next step or
/// tab of a screen, in the player's surface style — sliding in from the
/// right in the original one.
Widget appStepTransition(Widget child, Animation<double> animation) =>
    Reveal(animation: animation, motion: AppColors.motion, travel: 15, sideways: true, amplitude: 0.5, anchor: Alignment.topCenter, child: child);

/// How a bottom sheet slides up in the player's surface style — pass it
/// as `sheetAnimationStyle` to `showModalBottomSheet`.
AnimationStyle? get appSheetAnimation => AppColors.motion.sheet;

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
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return Text('$value', style: style, textAlign: textAlign);
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
        decoration: cardDecoration(radius: AppRadius.lg),
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
    final badge = Container(
      width: 76,
      height: 76,
      alignment: Alignment.center,
      decoration: cardDecoration(shape: BoxShape.circle),
      child: Text(emoji, style: const TextStyle(fontSize: 36)),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          // One-shot springy pop with a little tilt, then rests — never a
          // looping bob (that would keep `pumpAndSettle()` from settling).
          // The other styles bring it in their own way.
          if (AppColors.motion.style != SurfaceStyle.flat)
            FadeSlideIn(duration: const Duration(milliseconds: 460), child: badge)
          else
            TweenAnimationBuilder<double>(
              tween: Tween(begin: (MediaQuery.maybeDisableAnimationsOf(context) ?? false) ? 1 : 0, end: 1),
              duration: const Duration(milliseconds: 700),
              curve: Curves.elasticOut,
              builder: (context, t, child) => Transform.rotate(
                angle: 0.25 * (1 - t),
                child: Transform.scale(scale: 0.4 + 0.6 * t, child: child),
              ),
              child: badge,
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

/// `showDialog` with the app's own entrance, in the player's surface style:
/// in the original one the dialog springs up from slightly smaller while
/// the barrier fades in; it pops like jelly in clay, drops in hard in
/// neo-brutalism, strikes on in neon, comes into focus over a frosted app
/// in glass… — use it for every dialog so they all open the same way.
Future<T?> showAppDialog<T>({required BuildContext context, required WidgetBuilder builder, bool barrierDismissible = true}) {
  final themes = InheritedTheme.capture(from: context, to: Navigator.of(context, rootNavigator: true).context);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: AppColors.isDark ? 0.6 : 0.42),
    transitionDuration: AppColors.motion.dialog,
    pageBuilder: (dialogContext, _, _) => themes.wrap(SafeArea(child: Builder(builder: builder))),
    transitionBuilder: (context, animation, _, child) => _DialogTransition(animation: animation, child: child),
  );
}

class _DialogTransition extends StatefulWidget {
  final Animation<double> animation;
  final Widget child;
  const _DialogTransition({required this.animation, required this.child});

  @override
  State<_DialogTransition> createState() => _DialogTransitionState();
}

class _DialogTransitionState extends State<_DialogTransition> {
  // Built once: the route rebuilds its transition on every tick.
  late final _scale = CurvedAnimation(parent: widget.animation, curve: Curves.easeOutBack, reverseCurve: Curves.easeInCubic);
  late final _fade = CurvedAnimation(parent: widget.animation, curve: Curves.easeOut, reverseCurve: Curves.easeIn);

  @override
  void dispose() {
    _scale.dispose();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motion = AppColors.motion;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return FadeTransition(opacity: widget.animation, child: widget.child);
    if (motion.style == SurfaceStyle.flat) {
      return FadeTransition(
        opacity: _fade,
        child: ScaleTransition(scale: Tween<double>(begin: 0.9, end: 1).animate(_scale), child: widget.child),
      );
    }
    final dialog = Reveal(animation: widget.animation, motion: motion, travel: 28, amplitude: 0.6, anchor: Alignment.center, child: widget.child);
    if (motion.style != SurfaceStyle.glass) return dialog;
    // Glass: the app frosts over behind it.
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedBuilder(
          animation: widget.animation,
          builder: (context, _) {
            final sigma = 9 * Curves.easeOut.transform(widget.animation.value);
            return BackdropFilter(enabled: sigma > 0.05, filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma), child: const SizedBox.expand());
          },
        ),
        dialog,
      ],
    );
  }
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
  final field = AppColors.tokens.field;
  final border = OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: field.border, width: field.width));
  return InputDecoration(
    hintText: hintText,
    filled: true,
    fillColor: fillColor ?? field.fill,
    contentPadding: contentPadding,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    border: border,
    enabledBorder: border,
    focusedBorder: border.copyWith(borderSide: BorderSide(color: focusColor ?? AppColors.accent, width: field.width)),
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
        decoration: cardDecoration(radius: AppRadius.lg, borderWidth: 1.5),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: wellDecoration(radius: AppRadius.scaled(13)),
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
    final motion = AppColors.motion;
    // The fill and a soft accent glow, in the player's surface style — the
    // glow only while it's actionable, fading out as it disables, so "you
    // can go now" reads at a glance. Pressed like any surface of the style:
    // sunk in, landed on its shadow, flared…
    return Semantics(
      button: true,
      enabled: enabled,
      child: Pressable(
        onTap: enabled ? onPressed : null,
        pressedScale: 0.97,
        child: AnimatedContainer(
          duration: motion.change,
          curve: motion.changeCurve,
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 52),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: accentDecoration(radius: AppRadius.lg, enabled: enabled),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, a) => FadeTransition(opacity: a, child: ScaleTransition(scale: Tween<double>(begin: 0.8, end: 1).animate(a), child: child)),
            child: loading
                ? const SizedBox(key: ValueKey('loading'), width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(label, key: const ValueKey('label'), textAlign: TextAlign.center, style: bodyFont(size: 16, weight: FontWeight.w800, color: Colors.white)),
          ),
        ),
      ),
    );
  }
}
