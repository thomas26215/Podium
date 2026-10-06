import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'appearance.dart';

/// How the app moves in one surface style — a tap, an entrance, a page or
/// a dialog opening, a sheet sliding up, a thumb gliding to its segment —
/// resolved from the player's [Appearance] like the colours are, so each
/// effect has a motion of its own: neumorphism presses into the surface,
/// neo-brutalism slams into its hard shadow, clay squashes and wobbles…
///
/// Pure values and recipes: the widgets that play them (`Pressable`,
/// `FadeSlideIn`, `Reveal`, the page and dialog transitions) honour the
/// reduced-motion setting themselves.
@immutable
class AppMotion {
  final SurfaceStyle style;
  const AppMotion._(this.style);

  static const _all = {
    SurfaceStyle.flat: AppMotion._(SurfaceStyle.flat),
    SurfaceStyle.elevated: AppMotion._(SurfaceStyle.elevated),
    SurfaceStyle.neumorphic: AppMotion._(SurfaceStyle.neumorphic),
    SurfaceStyle.glass: AppMotion._(SurfaceStyle.glass),
    SurfaceStyle.clay: AppMotion._(SurfaceStyle.clay),
    SurfaceStyle.brutalist: AppMotion._(SurfaceStyle.brutalist),
    SurfaceStyle.outlined: AppMotion._(SurfaceStyle.outlined),
    SurfaceStyle.neon: AppMotion._(SurfaceStyle.neon),
    SurfaceStyle.gradient: AppMotion._(SurfaceStyle.gradient),
    SurfaceStyle.satin: AppMotion._(SurfaceStyle.satin),
  };

  factory AppMotion.of(SurfaceStyle style) => _all[style]!;

  /// What the player is told about it, under the surface styles.
  String get description => switch (style) {
        SurfaceStyle.flat => 'Les éléments glissent en place et se tassent sous le doigt.',
        SurfaceStyle.elevated => 'Les cartes s’élèvent en apparaissant et se posent quand on appuie.',
        SurfaceStyle.neumorphic => 'Tout émerge de la matière et s’y enfonce au toucher.',
        SurfaceStyle.glass => 'Les panneaux sortent du flou et s’éclairent sous le doigt.',
        SurfaceStyle.clay => 'Ça surgit comme de la gelée, s’écrase et rebondit.',
        SurfaceStyle.brutalist => 'Arrivées sèches, et chaque bouton plonge dans son ombre.',
        SurfaceStyle.outlined => 'Les contours se dessinent, et s’épaississent au toucher.',
        SurfaceStyle.neon => 'Les tubes s’allument en grésillant et s’embrasent au toucher.',
        SurfaceStyle.gradient => 'Tout arrive en vague, les dégradés tournent au toucher.',
        SurfaceStyle.satin => 'Un reflet balaie chaque carte, à l’entrée comme au toucher.',
      };

  // ============================== press ==============================

  /// How long a press takes to sink in, and its curve.
  Duration get pressIn => Duration(
        milliseconds: switch (style) {
          SurfaceStyle.brutalist => 50,
          SurfaceStyle.neon => 70,
          SurfaceStyle.outlined => 80,
          SurfaceStyle.flat => 90,
          SurfaceStyle.gradient => 100,
          SurfaceStyle.elevated => 110,
          SurfaceStyle.glass => 120,
          SurfaceStyle.clay => 130,
          SurfaceStyle.satin => 140,
          SurfaceStyle.neumorphic => 170,
        },
      );

  Curve get pressInCurve => switch (style) {
        SurfaceStyle.brutalist => Curves.linear,
        SurfaceStyle.neumorphic => Curves.easeInOut,
        SurfaceStyle.flat || SurfaceStyle.outlined || SurfaceStyle.neon => Curves.easeOut,
        _ => Curves.easeOutCubic,
      };

  /// How long it takes to come back up, and its curve — springy for the
  /// original style, a physical wobble for clay (see [releaseSpring]).
  Duration get pressOut => Duration(
        milliseconds: switch (style) {
          SurfaceStyle.brutalist => 130,
          SurfaceStyle.flat || SurfaceStyle.outlined => 220,
          SurfaceStyle.elevated || SurfaceStyle.gradient => 280,
          SurfaceStyle.glass => 320,
          SurfaceStyle.neumorphic => 340,
          SurfaceStyle.satin => 380,
          SurfaceStyle.neon => 420,
          SurfaceStyle.clay => 600,
        },
      );

  Curve get pressOutCurve => switch (style) {
        SurfaceStyle.flat => Curves.easeOutBack,
        SurfaceStyle.brutalist => Curves.easeOutExpo,
        SurfaceStyle.neumorphic => Curves.easeInOutCubic,
        _ => Curves.easeOutCubic,
      };

  /// Clay springs back up past its rest and wobbles there — a real spring
  /// rather than a curve, so a press let go halfway keeps its momentum.
  SpringDescription? get releaseSpring => style == SurfaceStyle.clay ? SpringDescription.withDampingRatio(mass: 1, stiffness: 520, ratio: 0.34) : null;

  /// The press transform of a tap target in this style: what its whole
  /// content does under the finger, on top of what its surface does (see
  /// `SurfaceDecoration`). [p] is the press, 0 at rest → 1 held, beyond
  /// either end while it springs; [k] how pronounced it is (1 for a card,
  /// more for a small icon button); [travel] how far its flat shadow lies,
  /// for neo-brutalism to land on it.
  ({Offset offset, double scaleX, double scaleY, Alignment anchor}) press(double p, double k, Offset travel) {
    ({Offset offset, double scaleX, double scaleY, Alignment anchor}) scaled(double amount, [Offset offset = Offset.zero]) {
      final s = 1 - amount * k * p;
      return (offset: offset, scaleX: s, scaleY: s, anchor: Alignment.center);
    }

    return switch (style) {
      SurfaceStyle.flat => scaled(0.04),
      SurfaceStyle.elevated => scaled(0.022, Offset(0, 1.4 * p)),
      SurfaceStyle.neumorphic => scaled(0.016),
      SurfaceStyle.glass => scaled(0.03),
      // Pressed like a ball of clay: flattened onto what it rests on —
      // within reason, even for a small button.
      SurfaceStyle.clay => (offset: Offset.zero, scaleX: 1 + math.min(0.03 * k, 0.055) * p, scaleY: 1 - math.min(0.07 * k, 0.13) * p, anchor: Alignment.bottomCenter),
      // Pushed straight down into its own shadow, no squish at all.
      SurfaceStyle.brutalist => (offset: (travel == Offset.zero ? const Offset(2, 2) : travel) * p, scaleX: 1, scaleY: 1, anchor: Alignment.center),
      SurfaceStyle.outlined => scaled(0.012),
      SurfaceStyle.neon => scaled(0.02),
      SurfaceStyle.gradient => scaled(0.035),
      SurfaceStyle.satin => scaled(0.02, Offset(0, 0.6 * p)),
    };
  }

  // ============================== entrances ==============================

  /// How long an entrance planned at [base] lasts in this style — clay's
  /// spring and the neon strike need longer than a slide.
  Duration entrance(Duration base) => base * _entranceFactor;

  double get _entranceFactor => switch (style) {
        SurfaceStyle.flat || SurfaceStyle.brutalist => 1.0,
        SurfaceStyle.elevated || SurfaceStyle.gradient => 1.1,
        SurfaceStyle.glass => 1.15,
        SurfaceStyle.satin => 1.25,
        SurfaceStyle.outlined => 1.35,
        SurfaceStyle.neumorphic || SurfaceStyle.neon => 1.4,
        SurfaceStyle.clay => 1.5,
      };

  /// Scales the delays of a cascade: brutal rattles through, neon tubes
  /// strike one after the other.
  double get stagger => switch (style) {
        SurfaceStyle.brutalist => 0.7,
        SurfaceStyle.gradient => 0.9,
        SurfaceStyle.flat || SurfaceStyle.elevated => 1.0,
        SurfaceStyle.glass || SurfaceStyle.clay || SurfaceStyle.satin => 1.1,
        SurfaceStyle.outlined => 1.2,
        SurfaceStyle.neumorphic => 1.3,
        SurfaceStyle.neon => 1.4,
      };

  /// One frame of an entrance at linear progress [t] (0 → 1). [travel] is
  /// the vertical offset the original slide starts from (−16: just above);
  /// the other styles keep only its length. [side] is where the sideways
  /// ones come from (1: the right, −1: the left). [amplitude] tones the
  /// rest down — the squash, the blur, the flicker — for something big (a
  /// whole tab: about a third) where a card's would be too much.
  /// [sideways] slides the original style in from [side] instead — the
  /// next step of a flow.
  RevealFrame reveal(double t, {double travel = -16, double side = 1, double amplitude = 1, bool sideways = false}) {
    t = t.clamp(0.0, 1.0);
    final d = travel.abs();
    final a = amplitude;
    switch (style) {
      case SurfaceStyle.flat:
        // Fades in sliding into place — the original Podium entrance.
        final e = Curves.easeOutCubic.transform(t);
        return RevealFrame(opacity: e, offset: sideways ? Offset(d * side * (1 - e), 0) : Offset(0, travel * (1 - e)));
      case SurfaceStyle.elevated:
        // Lifted off the page toward you: rises from below while its
        // shadow grows under it.
        final e = Curves.easeOutCubic.transform(t);
        final s = 1 - 0.035 * a * (1 - e);
        return RevealFrame(opacity: _span(t, 0, 0.6), offset: Offset(0, 1.1 * d * (1 - e)), scaleX: s, scaleY: s, rise: Curves.easeOutCubic.transform(_span(t, 0.2, 1)));
      case SurfaceStyle.neumorphic:
        // Printed flush on the surface, then extruded out of it: a
        // neumorphic card is cut from the background, so until its shadows
        // grow only what's on it shows.
        final s = 1 - 0.015 * a * (1 - Curves.easeOutCubic.transform(t));
        return RevealFrame(opacity: Curves.easeOut.transform(_span(t, 0, 0.35)), scaleX: s, scaleY: s, rise: Curves.easeInOutCubic.transform(_span(t, 0.12, 1)));
      case SurfaceStyle.glass:
        // Comes into focus from behind frosted glass.
        final e = Curves.easeOutCubic.transform(t);
        final s = 1 + 0.04 * a * (1 - e);
        return RevealFrame(opacity: Curves.easeOut.transform(_span(t, 0, 0.7)), offset: Offset(0, 0.4 * d * (1 - e)), scaleX: s, scaleY: s, blur: 9 * a * (1 - e), rise: e);
      case SurfaceStyle.clay:
        // Pops up on a jelly spring — its height lagging its width, so it
        // squashes as it lands and wobbles before it settles.
        final from = 1 - 0.4 * a;
        final w = jelly.transform(t);
        final h = jelly.transform(_span(t, 0.07, 1));
        return RevealFrame(opacity: _span(t, 0, 0.18), scaleX: lerpDouble(from, 1, w)!, scaleY: lerpDouble(from, 1, h)!, anchor: Alignment.bottomCenter, rise: Curves.easeOut.transform(_span(t, 0.1, 0.75)));
      case SurfaceStyle.brutalist:
        // Dropped in from the top left with a hard stop, no fade at all —
        // then its flat shadow snaps out from under it.
        final e = Curves.easeOutExpo.transform(_span(t, 0, 0.5));
        return RevealFrame(
          opacity: t > 0 ? 1 : 0,
          offset: Offset(-0.4 * d * (1 - e), -1.1 * d * (1 - e)),
          rotation: -0.035 * a * (1 - e),
          rise: Curves.easeOutBack.transform(_span(t, 0.38, 0.9)),
        );
      case SurfaceStyle.outlined:
        // The outline draws itself around what it frames (see
        // `SurfaceDecoration`), which settles in meanwhile.
        final e = Curves.easeOutCubic.transform(t);
        return RevealFrame(opacity: Curves.easeOut.transform(_span(t, 0, 0.35)), offset: Offset(0, 0.4 * d * (1 - e)), rise: Curves.easeInOutCubic.transform(_span(t, 0, 0.95)));
      case SurfaceStyle.neon:
        // Strikes on like a tube: a few stutters, then steady — the glow
        // flaring with it.
        final f = 1 - (1 - flicker.transform(t)) * (t < 0.06 ? 1 : a);
        return RevealFrame(opacity: f, rise: f * f);
      case SurfaceStyle.gradient:
        // Sweeps in sideways, its gradient turning into place.
        final e = Curves.easeOutQuart.transform(t);
        final s = 1 - 0.02 * a * (1 - e);
        return RevealFrame(opacity: Curves.easeOut.transform(_span(t, 0, 0.6)), offset: Offset(1.4 * d * (1 - e) * side, 0), scaleX: s, scaleY: s, rise: e);
      case SurfaceStyle.satin:
        // Rises gently while a gloss sweeps across it once.
        final e = Curves.easeOutQuart.transform(t);
        return RevealFrame(opacity: Curves.easeOut.transform(_span(t, 0, 0.55)), offset: Offset(0, 0.8 * d * (1 - e)), rise: t);
    }
  }

  /// One frame of an exit, [t] running from 1 (still there) down to 0
  /// (gone) — what a dialog closing or swapped-out content does: it drops
  /// away rather than playing its entrance backwards, but for the neon
  /// tube stuttering off and the brutal block yanked out.
  RevealFrame leave(double t, {double travel = -16, double amplitude = 1}) {
    t = t.clamp(0.0, 1.0);
    switch (style) {
      case SurfaceStyle.neon:
        return reveal(t, travel: travel, amplitude: amplitude);
      case SurfaceStyle.brutalist:
        final e = Curves.easeInExpo.transform(1 - t);
        return RevealFrame(opacity: t > 0.2 ? 1 : 0, offset: Offset(0, -1.1 * travel.abs() * e));
      case _:
        final e = Curves.easeOut.transform(t);
        final s = 1 - 0.03 * amplitude * (1 - e);
        return RevealFrame(opacity: e, scaleX: s, scaleY: s, rise: style == SurfaceStyle.satin ? 1 : e);
    }
  }

  // ============================== selection ==============================

  /// A selection moving somewhere — a segmented control's thumb, a
  /// toggle's knob. [moveCurve] may overshoot (clay wobbles into place),
  /// so it's only for positions: colours and decorations take [change].
  Duration get move => Duration(
        milliseconds: switch (style) {
          SurfaceStyle.brutalist => 160,
          SurfaceStyle.neon => 240,
          SurfaceStyle.outlined => 260,
          SurfaceStyle.flat => 280,
          SurfaceStyle.elevated => 300,
          SurfaceStyle.gradient => 320,
          SurfaceStyle.glass => 340,
          SurfaceStyle.satin => 360,
          SurfaceStyle.neumorphic => 380,
          SurfaceStyle.clay => 560,
        },
      );

  Curve get moveCurve => switch (style) {
        SurfaceStyle.clay => jelly,
        SurfaceStyle.brutalist => Curves.easeOutExpo,
        SurfaceStyle.neumorphic || SurfaceStyle.outlined => Curves.easeInOutCubic,
        SurfaceStyle.glass || SurfaceStyle.gradient || SurfaceStyle.satin => Curves.easeOutQuart,
        _ => Curves.easeOutCubic,
      };

  /// A state change in place — a chip filling in once picked, a surface
  /// pressing in. Never overshoots.
  Duration get change => Duration(
        milliseconds: switch (style) {
          SurfaceStyle.brutalist => 90,
          SurfaceStyle.flat || SurfaceStyle.outlined || SurfaceStyle.neon => 170,
          SurfaceStyle.elevated || SurfaceStyle.gradient || SurfaceStyle.glass => 220,
          SurfaceStyle.clay || SurfaceStyle.satin => 260,
          SurfaceStyle.neumorphic => 300,
        },
      );

  Curve get changeCurve => switch (style) {
        SurfaceStyle.brutalist => Curves.easeOutExpo,
        SurfaceStyle.neumorphic => Curves.easeInOutCubic,
        _ => Curves.easeOutCubic,
      };

  // ============================== routes ==============================

  /// How long a pushed screen takes to come in.
  Duration get page => Duration(
        milliseconds: switch (style) {
          SurfaceStyle.flat => 300,
          SurfaceStyle.brutalist => 320,
          SurfaceStyle.elevated => 360,
          SurfaceStyle.gradient => 380,
          SurfaceStyle.neon => 400,
          SurfaceStyle.glass || SurfaceStyle.outlined => 420,
          SurfaceStyle.neumorphic || SurfaceStyle.satin => 440,
          SurfaceStyle.clay => 480,
        },
      );

  /// And to go back: a little quicker, as the way out always is.
  Duration get pageReverse => style == SurfaceStyle.flat ? page : page * 0.8;

  /// How long a dialog takes to open.
  Duration get dialog => Duration(
        milliseconds: switch (style) {
          SurfaceStyle.brutalist => 240,
          SurfaceStyle.outlined => 280,
          SurfaceStyle.flat => 320,
          SurfaceStyle.elevated || SurfaceStyle.gradient => 340,
          SurfaceStyle.glass => 380,
          SurfaceStyle.satin => 400,
          SurfaceStyle.neumorphic => 420,
          SurfaceStyle.neon => 460,
          SurfaceStyle.clay => 560,
        },
      );

  /// How a bottom sheet slides up — null keeps Material's own for the
  /// original style. Never an overshooting curve: a sheet lifted past its
  /// height would open a gap under it.
  AnimationStyle? get sheet => switch (style) {
        SurfaceStyle.flat => null,
        SurfaceStyle.brutalist => const AnimationStyle(duration: Duration(milliseconds: 220), curve: Curves.easeOutExpo, reverseDuration: Duration(milliseconds: 160)),
        SurfaceStyle.outlined => const AnimationStyle(duration: Duration(milliseconds: 300), curve: Curves.easeInOutCubic),
        SurfaceStyle.elevated || SurfaceStyle.neon => const AnimationStyle(duration: Duration(milliseconds: 320), curve: Curves.easeOutCubic),
        SurfaceStyle.gradient => const AnimationStyle(duration: Duration(milliseconds: 360), curve: Curves.easeOutQuart),
        SurfaceStyle.glass => const AnimationStyle(duration: Duration(milliseconds: 380), curve: Curves.easeOutCubic),
        SurfaceStyle.satin => const AnimationStyle(duration: Duration(milliseconds: 420), curve: Curves.easeOutQuart),
        SurfaceStyle.neumorphic => const AnimationStyle(duration: Duration(milliseconds: 420), curve: Curves.easeOutQuint),
        SurfaceStyle.clay => const AnimationStyle(duration: Duration(milliseconds: 460), curve: Curves.easeOutQuint),
      };

  @override
  String toString() => 'AppMotion(${style.name})';
}

/// One frame of an entrance (see [AppMotion.reveal]): what `Reveal`
/// applies to its child — and [rise], which it hands down to the surfaces
/// inside, 0 flush with the page → 1 fully raised (a little more while a
/// shadow snaps out).
@immutable
class RevealFrame {
  final double opacity;
  final Offset offset;
  final double scaleX, scaleY;

  /// Where the scale is anchored, in the child's own box.
  final Alignment anchor;
  final double rotation;

  /// A blur sigma, in logical pixels.
  final double blur;
  final double rise;

  const RevealFrame({
    this.opacity = 1,
    this.offset = Offset.zero,
    this.scaleX = 1,
    this.scaleY = 1,
    this.anchor = Alignment.center,
    this.rotation = 0,
    this.blur = 0,
    this.rise = 1,
  });

  bool get transforms => offset != Offset.zero || scaleX != 1 || scaleY != 1 || rotation != 0;
}

double _span(double x, double a, double b) => ((x - a) / (b - a)).clamp(0.0, 1.0);

/// A jelly spring, 0 → 1: overshoots by about a sixth, swings back a
/// little, settles — an underdamped oscillator that has died down by the
/// end of the curve.
const Curve jelly = _SpringCurve(damping: 0.5);

/// A neon tube striking: on, off, on, flickering, then steady from a
/// little before halfway.
const Curve flicker = _KeyframeCurve([(0, 0), (0.06, 0.85), (0.1, 0.2), (0.17, 0.95), (0.22, 0.45), (0.3, 1), (0.36, 0.72), (0.42, 1), (1, 1)]);

/// [flicker] for a whole screen: the same stutter, kept from going dark.
const Curve flickerSoft = _KeyframeCurve([(0, 0), (0.1, 0.7), (0.16, 0.32), (0.26, 0.9), (0.33, 0.56), (0.45, 1), (1, 1)]);

class _SpringCurve extends Curve {
  /// The damping ratio, below 1 for it to overshoot.
  final double damping;
  const _SpringCurve({required this.damping});

  @override
  double transformInternal(double t) {
    // Decayed to a five-hundredth by t = 1: the end of the curve is still.
    final zw = math.log(500);
    final w = zw / damping;
    final wd = w * math.sqrt(1 - damping * damping);
    return 1 - math.exp(-zw * t) * (math.cos(wd * t) + zw / wd * math.sin(wd * t));
  }
}

class _KeyframeCurve extends Curve {
  /// (t, value) pairs from (0, 0) to (1, 1), linearly joined.
  final List<(double, double)> keys;
  const _KeyframeCurve(this.keys);

  @override
  double transformInternal(double t) {
    for (var i = 1; i < keys.length; i++) {
      final (t1, v1) = keys[i];
      if (t <= t1) {
        final (t0, v0) = keys[i - 1];
        return v0 + (v1 - v0) * (t - t0) / (t1 - t0);
      }
    }
    return 1;
  }
}

// ============================== paint channel ==============================

/// What a surface is going through at the moment it's painted — pressed
/// in, rising onto the page — handed down the paint pass by `Pressable`
/// and `Reveal` to the `SurfaceDecoration`s below them.
///
/// Painting is synchronous and depth-first, so a value set before a
/// subtree paints and restored after reaches exactly that subtree: the
/// cards below react in their own style without their widgets rebuilding,
/// or even knowing — every card already in the app presses and rises in
/// its effect. Only what sits behind a repaint boundary of its own (a
/// list's items, a screen's scroll view) paints apart, and stays still.
abstract final class SurfaceMotion {
  static PressSlot? _press;
  static double _rise = 1;

  /// How far the surfaces being painted have risen onto the page: 1 but
  /// inside an entrance.
  static double get rise => _rise;

  /// Paints [paint] with [slot] offered to the surfaces below.
  static void withPress(PressSlot slot, VoidCallback paint) {
    final previous = _press;
    slot.claimed = false;
    _press = slot;
    try {
      paint();
    } finally {
      _press = previous;
    }
  }

  /// Paints [paint] risen by [rise] — within any entrance it's already in.
  static void withRise(double rise, VoidCallback paint) {
    final previous = _rise;
    _rise = previous * rise;
    try {
      paint();
    } finally {
      _rise = previous;
    }
  }

  /// The press for a surface of [size] being painted: the nearest one
  /// above, if that surface is what was tapped — it fills the tap target,
  /// and nothing painted before it claimed the press. So a pressed card
  /// sinks in while the chips and tiles on it stay put, and a tap target
  /// holding a few cards side by side only shrinks as a whole.
  static PressSlot? claim(Size size) {
    final slot = _press;
    if (slot == null || slot.claimed) return null;
    if (size.width < slot.size.width * 0.7 || size.height < slot.size.height * 0.7) return null;
    slot.claimed = true;
    return slot;
  }
}

/// A `Pressable`'s press, as [SurfaceMotion] offers it down the paint pass
/// — and what the surface that takes it reports back.
class PressSlot {
  /// 0 at rest → 1 held down (beyond while it springs back).
  double value = 0;

  /// Where the finger went down, in fractions of the tap target's size.
  Offset touch = const Offset(0.5, 0.5);

  /// The light a pressed glass panel catches: the accent.
  Color tint = const Color(0xFFFFFFFF);

  /// The tap target's size.
  Size size = Size.zero;

  /// Whether a surface took this press, the last time it was painted.
  bool claimed = false;

  /// How far that surface's flat shadow lies — what a neo-brutal press
  /// pushes it by, onto its shadow.
  Offset travel = Offset.zero;
}
