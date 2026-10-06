import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../theme/app_theme.dart';

/// Plays an entrance in a surface style (see [AppMotion.reveal]) as
/// [animation] runs from 0 to 1 — and its exit ([AppMotion.leave]) when it
/// runs back. Fades, moves and blurs [child] at paint time, so the subtree
/// never rebuilds, and raises the surfaces inside as it goes (see
/// [SurfaceMotion]): shadows extruding out of a neumorphic page, a brutal
/// one snapping out, an outline tracing itself…
///
/// Hit-tests (and reports its child's geometry) where the child will land:
/// what's tappable stays put under the finger while it settles. With
/// reduced motion it only fades.
class Reveal extends SingleChildRenderObjectWidget {
  final Animation<double> animation;
  final AppMotion motion;

  /// See [AppMotion.reveal].
  final double travel;
  final double side;
  final double amplitude;
  final bool sideways;

  /// Where it scales from, instead of the style's own — the centre, for
  /// something as big as the screen.
  final Alignment? anchor;

  const Reveal({super.key, required this.animation, required this.motion, this.travel = -16, this.side = 1, this.amplitude = 1, this.sideways = false, this.anchor, super.child});

  static bool _still(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderReveal(animation, motion, travel, side, amplitude, sideways, anchor, _still(context));

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderReveal).configure(animation, motion, travel, side, amplitude, sideways, anchor, _still(context));
  }
}

class _RenderReveal extends RenderProxyBox {
  _RenderReveal(this._animation, this._motion, this._travel, this._side, this._amplitude, this._sideways, this._anchor, this._still) {
    _frame = _compute();
    _layered = _needsLayers(_frame);
  }

  Animation<double> _animation;
  AppMotion _motion;
  double _travel, _side, _amplitude;
  bool _sideways;
  Alignment? _anchor;

  /// Reduced motion: a plain fade.
  bool _still;
  late RevealFrame _frame;
  late bool _layered;

  /// Whether the repaint boundaries below were repainted out of the
  /// entrance yet (see [_repaintBoundariesBelow]).
  bool _primed = false;

  final _opacityLayer = LayerHandle<OpacityLayer>();
  final _filterLayer = LayerHandle<ImageFilterLayer>();
  final _transformLayer = LayerHandle<TransformLayer>();

  void configure(Animation<double> animation, AppMotion motion, double travel, double side, double amplitude, bool sideways, Alignment? anchor, bool still) {
    var changed = false;
    if (animation != _animation) {
      if (attached) _unlisten();
      _animation = animation;
      if (attached) _listen();
      changed = true;
    }
    if (motion != _motion || travel != _travel || side != _side || amplitude != _amplitude || sideways != _sideways || anchor != _anchor || still != _still) {
      _motion = motion;
      _travel = travel;
      _side = side;
      _amplitude = amplitude;
      _sideways = sideways;
      _anchor = anchor;
      _still = still;
      changed = true;
    }
    if (changed) _update();
  }

  RevealFrame _compute() {
    final t = _animation.value;
    if (_still) return RevealFrame(opacity: t.clamp(0.0, 1.0));
    return _animation.status == AnimationStatus.reverse
        ? _motion.leave(t, travel: _travel, amplitude: _amplitude)
        : _motion.reveal(t, travel: _travel, side: _side, amplitude: _amplitude, sideways: _sideways);
  }

  static bool _needsLayers(RevealFrame f) => f.opacity > 0 && (f.opacity < 1 || f.blur > 0.05);

  void _update() {
    _frame = _compute();
    final layered = _needsLayers(_frame);
    if (layered != _layered) {
      _layered = layered;
      markNeedsCompositingBitsUpdate();
    }
    markNeedsPaint();
    if (!_primed) {
      _primed = true;
      _repaintBoundariesBelow();
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status.isCompleted || status.isDismissed) _repaintBoundariesBelow();
  }

  /// What sits behind a repaint boundary of its own paints apart from
  /// this, so outside the entrance — but its very first paint happens
  /// right here, mid-entrance, and would stay frozen there: repainting
  /// those once as it starts and once as it ends leaves them as they
  /// should be.
  void _repaintBoundariesBelow() {
    void visit(RenderObject node) {
      if (node.isRepaintBoundary && node.attached) node.markNeedsPaint();
      node.visitChildren(visit);
    }

    if (attached) visitChildren(visit);
  }

  void _listen() {
    _animation.addListener(_update);
    _animation.addStatusListener(_onStatus);
  }

  void _unlisten() {
    _animation.removeListener(_update);
    _animation.removeStatusListener(_onStatus);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _listen();
    _frame = _compute();
    final layered = _needsLayers(_frame);
    if (layered != _layered) {
      _layered = layered;
      markNeedsCompositingBitsUpdate();
    }
  }

  @override
  void detach() {
    _unlisten();
    super.detach();
  }

  @override
  void dispose() {
    _opacityLayer.layer = null;
    _filterLayer.layer = null;
    _transformLayer.layer = null;
    super.dispose();
  }

  @override
  bool get alwaysNeedsCompositing => child != null && _layered;

  Matrix4 _matrix(RevealFrame f) {
    final a = (_anchor ?? f.anchor).alongSize(size);
    return Matrix4.identity()
      ..translateByDouble(f.offset.dx + a.dx, f.offset.dy + a.dy, 0, 1)
      ..rotateZ(f.rotation)
      ..scaleByDouble(f.scaleX, f.scaleY, 1, 1)
      ..translateByDouble(-a.dx, -a.dy, 0, 1);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    final f = _frame;
    if (child == null || f.opacity <= 0) {
      _opacityLayer.layer = null;
      _filterLayer.layer = null;
      _transformLayer.layer = null;
      return;
    }

    void risen(PaintingContext context, Offset offset) => SurfaceMotion.withRise(f.rise, () => context.paintChild(child, offset));

    void transformed(PaintingContext context, Offset offset) {
      if (!f.transforms) {
        _transformLayer.layer = null;
        risen(context, offset);
        return;
      }
      _transformLayer.layer = context.pushTransform(needsCompositing, offset, _matrix(f), risen, oldLayer: _transformLayer.layer);
    }

    void blurred(PaintingContext context, Offset offset) {
      if (f.blur <= 0.05) {
        _filterLayer.layer = null;
        transformed(context, offset);
        return;
      }
      final layer = _filterLayer.layer ??= ImageFilterLayer();
      layer.imageFilter = ui.ImageFilter.blur(sigmaX: f.blur, sigmaY: f.blur, tileMode: TileMode.decal);
      context.pushLayer(layer, transformed, offset);
    }

    if (f.opacity >= 1) {
      _opacityLayer.layer = null;
      blurred(context, offset);
    } else {
      _opacityLayer.layer = context.pushOpacity(offset, (f.opacity * 255).round(), blurred, oldLayer: _opacityLayer.layer);
    }
  }
}

/// Paints a tap target pressed by [press] (0 at rest → 1 held) in its
/// surface style: moves its content ([AppMotion.press]) and offers the
/// press to the surface that fills it, which sinks in, lands on its
/// shadow, flares up… (see [SurfaceMotion]). With a [highlight], a row
/// with no surface of its own gets that one drawn behind it instead.
///
/// Hit-tests untransformed: the target doesn't slip from under the finger.
class PressPaint extends SingleChildRenderObjectWidget {
  final Animation<double> press;
  final AppMotion motion;

  /// How pronounced the press is: 1 for a card, more for a small button.
  final double intensity;

  /// Where the finger went down, in fractions of its size.
  final Offset touch;

  /// The light a pressed glass panel catches.
  final Color tint;
  final Decoration? highlight;

  const PressPaint({super.key, required this.press, required this.motion, this.intensity = 1, this.touch = const Offset(0.5, 0.5), this.tint = const Color(0xFFFFFFFF), this.highlight, super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderPressPaint(press, motion, intensity, touch, tint, highlight);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderPressPaint).configure(press, motion, intensity, touch, tint, highlight);
  }
}

class _RenderPressPaint extends RenderProxyBox {
  _RenderPressPaint(this._press, this._motion, this._intensity, this._touch, this._tint, this._highlight);

  Animation<double> _press;
  AppMotion _motion;
  double _intensity;
  Offset _touch;
  Color _tint;
  Decoration? _highlight;
  final _slot = PressSlot();
  final _transformLayer = LayerHandle<TransformLayer>();

  void configure(Animation<double> press, AppMotion motion, double intensity, Offset touch, Color tint, Decoration? highlight) {
    if (press != _press) {
      if (attached) _press.removeListener(markNeedsPaint);
      _press = press;
      if (attached) _press.addListener(markNeedsPaint);
    }
    if (motion == _motion && intensity == _intensity && touch == _touch && tint == _tint && highlight == _highlight) return;
    _motion = motion;
    _intensity = intensity;
    _touch = touch;
    _tint = tint;
    _highlight = highlight;
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _press.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _press.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void dispose() {
    _transformLayer.layer = null;
    super.dispose();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    final p = _press.value;
    final wasClaimed = _slot.claimed;
    _slot
      ..value = p
      ..touch = _touch
      ..tint = _tint
      ..size = size;

    void pressed(PaintingContext context, Offset offset) {
      // A surface below takes the press itself — or, for a bare row, the
      // style's highlight shows it (known from the last paint: the press
      // starts from nothing, so that's soon enough).
      final highlight = _highlight;
      if (highlight != null && !wasClaimed && p > 0) {
        final painter = Decoration.lerp(null, highlight, p.clamp(0.0, 1.0))?.createBoxPainter();
        painter?.paint(context.canvas, offset, ImageConfiguration(size: size));
        painter?.dispose();
      }
      SurfaceMotion.withPress(_slot, () => context.paintChild(child, offset));
    }

    final t = _motion.press(p, _intensity, _slot.travel);
    if (t.offset == Offset.zero && t.scaleX == 1 && t.scaleY == 1) {
      _transformLayer.layer = null;
      pressed(context, offset);
      return;
    }
    final a = t.anchor.alongSize(size);
    final matrix = Matrix4.identity()
      ..translateByDouble(t.offset.dx + a.dx, t.offset.dy + a.dy, 0, 1)
      ..scaleByDouble(t.scaleX, t.scaleY, 1, 1)
      ..translateByDouble(-a.dx, -a.dy, 0, 1);
    _transformLayer.layer = context.pushTransform(needsCompositing, offset, matrix, pressed, oldLayer: _transformLayer.layer);
  }
}
