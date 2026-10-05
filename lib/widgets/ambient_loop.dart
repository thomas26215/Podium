import 'package:flutter/material.dart';

/// Drives a looping phase (0 → 1, then again) for ambient decoration —
/// animated banners, avatar frames, name effects. Anything built from it
/// must be periodic in `phase` (whole sine cycles, wrapped offsets…) so
/// the loop has no visible seam.
///
/// Pauses on its own when its route is covered (TickerMode), and holds
/// still at phase 0 when the device asks for reduced motion. Only use it
/// for decorations the player opted into: a looping animation on a default
/// screen would keep `pumpAndSettle()` from ever settling in tests.
class AmbientLoop extends StatefulWidget {
  final Duration period;
  final Widget Function(BuildContext context, double phase) builder;
  const AmbientLoop({super.key, this.period = const Duration(seconds: 6), required this.builder});

  @override
  State<AmbientLoop> createState() => _AmbientLoopState();
}

class _AmbientLoopState extends State<AmbientLoop> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.period);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduced) {
      _c.stop();
      _c.value = 0;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void didUpdateWidget(AmbientLoop old) {
    super.didUpdateWidget(old);
    if (old.period != widget.period) {
      _c.duration = widget.period;
      if (_c.isAnimating) _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: _c, builder: (context, _) => widget.builder(context, _c.value));
}
