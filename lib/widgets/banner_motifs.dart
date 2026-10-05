import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'fx_kit.dart';

// Procedural scenes behind the profile card. Each motif paints one frame
// for the entrance progress `t` (0 → 1, once) and the ambient loop phase
// `ph` (0 → 1, repeating — see AmbientLoop and fx_kit.dart): everything
// that moves with `ph` is periodic in it, so the loop never shows a seam.
// The card's text sits on the left, so the action happens on the right;
// ProfileBannerBackground also fades every motif out towards the left.

/// The motifs' scale: the card's height, capped — a tall card (long bio,
/// pinned badges) gets more of the scene, not bigger props.
double unitOf(Size s) => math.min(s.height, 170.0);

/// How far down the card the "hero band" reaches: the strip beside and just
/// below the name, where a banner's main props go. On a short card that's
/// the whole card; on a tall one (status, bio, pinned badges), what's
/// below it keeps a calm backdrop so the text stays readable.
double heroHeight(Size s) => math.min(s.height, unitOf(s) * 1.1);

/// Staggers element [i] of [n] across the entrance: 0 before its turn, 1
/// once it has landed.
double stagger(double t, int i, int n) => ((t * 1.6) - (i / n) * 0.6).clamp(0.0, 1.0);

/// Flame-flicker noise: like [loopNoise] but an order of magnitude faster
/// (still whole cycles per loop).
double _flicker(double ph, double seed) => wave(ph, seed, 29) * 0.5 + wave(ph, seed * 1.3 + 0.2, 47) * 0.3 + wave(ph, seed * 1.9 + 0.5, 71) * 0.2;

double _mod(double a, double m) => a - (a / m).floorToDouble() * m;

// ============================== Jeux vidéo ==============================

const _neonPink = Color(0xFFFF4FD8);

/// Synthwave: a striped sun sinking behind neon mountains, the grid
/// rolling towards you, stars and the odd shooting star.
void arcadeMotif(Canvas canvas, Size s, double t, double ph) {
  final w = s.width, h = s.height, u = unitOf(s);
  final horizon = math.min(h * 0.6, heroHeight(s) * 0.62);

  for (var i = 0; i < 46; i++) {
    final p = Offset(hash01(i) * w, hash01(i + 101) * horizon * 0.9);
    final tw = wave01(ph, hash01(i + 202), 5 + i % 6);
    canvas.drawCircle(p, 0.4 + hash01(i + 303) * 1.2, fillPaint(Colors.white, (0.2 + 0.7 * tw) * t));
  }

  for (var k = 0; k < 2; k++) {
    final u0 = loopWindow(ph, 0.18 + k * 0.47, 0.06);
    if (u0 == null) continue;
    final start = Offset(w * (0.62 + 0.3 * hash01(k + 7)), horizon * (0.06 + 0.22 * hash01(k + 13)));
    const dir = Offset(-0.91, 0.41);
    final head = start + dir * (easeOutCubic(u0) * w * 0.42);
    final tail = head - dir * (w * 0.16 * bump(u0));
    final a = bump(u0) * t;
    canvas.drawLine(tail, head, Paint()
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..shader = ui.Gradient.linear(tail, head, [Colors.white.withValues(alpha: 0), Colors.white.withValues(alpha: a)]));
    drawGlow(canvas, head, 7, Colors.white, 0.8 * a);
  }

  // The sun: haloed, its cut-out stripes drifting down and thickening.
  final sunR = u * 0.44;
  final sunC = Offset(w * 0.78, horizon - sunR * 0.18 + (1 - t) * sunR * 0.8);
  drawGlow(canvas, sunC, sunR * (1.75 + 0.12 * wave(ph, 0, 4)), const Color(0xFFFF4F9A), 0.5 * t);
  canvas.saveLayer(Rect.fromCircle(center: sunC, radius: sunR + 2), Paint());
  canvas.drawCircle(
    sunC,
    sunR,
    Paint()..shader = ui.Gradient.linear(sunC - Offset(0, sunR), sunC + Offset(0, sunR), const [Color(0xFFFFF3B0), Color(0xFFFFB347), Color(0xFFFF4F9A)], const [0, 0.45, 1]),
  );
  final drift = fract(ph * 6);
  for (var j = 0; j < 10; j++) {
    final pos = j + drift; // thickness follows position, so the wrap is seamless
    canvas.drawRect(Rect.fromLTWH(sunC.dx - sunR, sunC.dy - sunR * 0.38 + pos * sunR * 0.12, sunR * 2, pos * 0.9), Paint()..blendMode = BlendMode.dstOut);
  }
  canvas.restore();

  // Neon mountains sliding past — their profile is periodic over the
  // width, so scrolling it by one width per loop wraps cleanly.
  final ridge = Path();
  final mountains = Path()..moveTo(0, horizon);
  for (var x = 0.0; x <= w + 4; x += 4) {
    final f = x / w + ph;
    final m = 0.55 + 0.28 * math.sin(f * tau * 2) + 0.17 * math.sin(f * tau * 5 + 1.3);
    final y = horizon - h * 0.12 * m * t;
    mountains.lineTo(x, y);
    x == 0 ? ridge.moveTo(x, y) : ridge.lineTo(x, y);
  }
  mountains
    ..lineTo(w + 4, horizon)
    ..close();
  canvas.drawPath(mountains, Paint()..shader = ui.Gradient.linear(Offset(0, horizon - h * 0.13), Offset(0, horizon), const [Color(0xFF3A0E6B), Color(0xFF14052B)]));
  canvas.drawPath(ridge, strokePaint(_neonPink, 1.4, 0.85 * t)..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2.5));

  // Ground and its grid rolling towards the viewer.
  final ground = Rect.fromLTWH(0, horizon, w, h - horizon);
  canvas.drawRect(ground, Paint()..shader = ui.Gradient.linear(ground.topCenter, ground.bottomCenter, const [Color(0xFF1B0436), Color(0xFF2A0A4F)]));
  final vanish = Offset(w * 0.62, horizon);
  for (var i = -16; i <= 16; i++) {
    final bottom = Offset(vanish.dx + i * w * 0.11, h);
    canvas.drawLine(vanish, bottom, Paint()
      ..strokeWidth = 1.1
      ..shader = ui.Gradient.linear(vanish, bottom, [_neonPink.withValues(alpha: 0), _neonPink.withValues(alpha: 0.8 * t)]));
  }
  // One line past the bottom edge, and each new line fading in at the
  // horizon, so the roll wraps without a line popping in or out.
  final roll = fract(ph * 9);
  for (var i = 0; i <= 9; i++) {
    final z = (i + roll) / 9;
    final y = horizon + math.pow(z, 2.2) * (h - horizon);
    canvas.drawLine(Offset(0, y), Offset(w, y), strokePaint(_neonPink, 0.5 + z * 1.5, (0.1 + 0.8 * z) * span(z, 0, 0.06) * t));
  }
  canvas.drawLine(Offset(0, horizon), Offset(w, horizon), strokePaint(const Color(0xFFFFB3F0), 1.6, (0.7 + 0.3 * wave(ph, 0, 6)) * t)..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3));

  // CRT scanlines over everything.
  final scan = fillPaint(Colors.black, 0.12);
  for (var y = 0.0; y < h; y += 3) {
    canvas.drawRect(Rect.fromLTWH(0, y, w, 1), scan);
  }
}

const _squidA = ['00011000', '00111100', '01111110', '11011011', '11111111', '00100100', '01011010', '10100101'];
const _squidB = ['00011000', '00111100', '01111110', '11011011', '11111111', '01011010', '10000001', '01000010'];
const _crabA = ['00100000100', '00010001000', '00111111100', '01101110110', '11111111111', '10111111101', '10100000101', '00011011000'];
const _crabB = ['00100000100', '10010001001', '10111111101', '11101110111', '11111111111', '01111111110', '00100000100', '01000000010'];
const _octoA = ['000011110000', '011111111110', '111111111111', '111001100111', '111111111111', '000110011000', '001101101100', '110000000011'];
const _octoB = ['000011110000', '011111111110', '111111111111', '111001100111', '111111111111', '001110011100', '011001100110', '001100001100'];
const _cannon = ['0000001000000', '0000011100000', '0000011100000', '0111111111110', '1111111111111', '1111111111111', '1111111111111', '1111111111111'];
const _ufo = ['0000011111100000', '0001111111111000', '0011111111111100', '0110110110110110', '1111111111111111', '0011100110011100', '0001000000001000'];

/// Space Invaders in miniature: the fleet steps side to side, the cannon
/// below strafes and fires, shots burst on the formation, and a mystery
/// ship crosses the top once a loop.
void invadersMotif(Canvas canvas, Size s, double t, double ph) {
  final w = s.width, h = s.height, u = unitOf(s);

  // Stars streaming down at three depths — we're flying up.
  for (var i = 0; i < 54; i++) {
    final depth = 1 + i % 3;
    final y = fract(hash01(i + 9) + ph * depth) * h;
    canvas.drawRect(Rect.fromLTWH(hash01(i + 77) * w, y, depth * 0.8, depth * 1.6), fillPaint(Colors.white, (0.12 + 0.18 * depth) * t));
  }

  const cols = 4, rows = 3;
  final cell = math.min(u * 0.024, w * 0.44 / (cols * 15));
  final colW = cell * 15, rowH = cell * 12;
  final fx0 = w - cols * colW - cell * 6;
  final fy0 = h * 0.1 - (1 - t) * 30;
  // Stepped march: 16 steps per sweep, three sweeps per loop — offset by
  // half a step, so the loop wraps mid-step rather than on one.
  final step = (fract(ph * 3 + 1 / 32) * 16).floor();
  final march = (((step <= 8 ? step : 16 - step) / 8) - 0.5) * colW * 0.9;
  final frame = step % 2;
  const rowColors = [Color(0xFFF472B6), Color(0xFF22D3EE), Color(0xFFA3E635)];
  for (var r = 0; r < rows; r++) {
    final sprite = switch (r) {
      0 => frame == 0 ? _squidA : _squidB,
      1 => frame == 0 ? _crabA : _crabB,
      _ => frame == 0 ? _octoA : _octoB,
    };
    final spriteW = sprite.first.length * cell;
    for (var c = 0; c < cols; c++) {
      final o = Offset(fx0 + c * colW + (colW - spriteW) / 2 + march, fy0 + r * rowH);
      drawSprite(canvas, sprite, o, cell, {'1': rowColors[r]}, alpha: stagger(t, r * cols + c, rows * cols), glow: 0.9);
    }
  }
  final formationBottom = fy0 + rows * rowH - cell * 3;

  final cannonY = math.min(h, heroHeight(s) * 1.2) - cell * 11;
  double cannonX(double p) => w * 0.7 + w * 0.17 * wave(p, 0, 2);
  drawSprite(canvas, _cannon, Offset(cannonX(ph) - 6.5 * cell, cannonY), cell, {'1': const Color(0xFF4ADE80)}, alpha: t, glow: 1);

  // Six shots a loop, each bursting on the formation.
  for (var k = 0; k < 6; k++) {
    final fireAt = k / 6 + 0.02;
    final shot = loopWindow(ph, fireAt, 0.075);
    if (shot == null) continue;
    final bx = cannonX(fireAt);
    if (shot < 0.75) {
      final by = cannonY - (cannonY - formationBottom) * (shot / 0.75);
      canvas.drawRect(Rect.fromCenter(center: Offset(bx, by), width: cell * 0.9, height: cell * 3.6), fillPaint(const Color(0xFFFDE047), t));
      drawGlow(canvas, Offset(bx, by), cell * 5, const Color(0xFFFDE047), 0.5 * t);
    } else {
      final e = (shot - 0.75) / 0.25;
      final hit = Offset(bx, formationBottom);
      for (var j = 0; j < 12; j++) {
        final a = j / 12 * tau + hash01(k * 13 + j);
        final p = hit + Offset(math.cos(a), math.sin(a)) * (cell * 1.5 + easeOutCubic(e) * cell * 8);
        canvas.drawRect(Rect.fromCenter(center: p, width: cell, height: cell), fillPaint(j.isEven ? const Color(0xFFFDE047) : Colors.white, (1 - e) * t));
      }
      drawGlow(canvas, hit, cell * 9 * (1 - e * 0.4), Colors.white, 0.7 * (1 - e) * t);
    }
  }

  final ufo = loopWindow(ph, 0.55, 0.22);
  if (ufo != null) {
    final x = lerpD(w + 10, w * 0.35, ufo);
    final a = t * span(ufo, 0, 0.12) * (1 - span(ufo, 0.88, 1));
    drawSprite(canvas, _ufo, Offset(x, h * 0.025), cell * 0.85, {'1': const Color(0xFFF43F5E)}, alpha: a, glow: 1.2);
    if ((ph * 40).floor().isEven) drawGlow(canvas, Offset(x + 8 * cell * 0.85, h * 0.025 + 3 * cell), cell * 6, const Color(0xFFF43F5E), 0.5 * a);
  }
}

void _psSymbol(Canvas canvas, int kind, Offset c, double size, double angle, Paint paint) {
  canvas.save();
  canvas.translate(c.dx, c.dy);
  if (angle != 0) canvas.rotate(angle);
  switch (kind) {
    case 0:
      canvas.drawPath(Path()
        ..moveTo(0, -size * 0.62)
        ..lineTo(size * 0.56, size * 0.4)
        ..lineTo(-size * 0.56, size * 0.4)
        ..close(), paint);
    case 1:
      canvas.drawCircle(Offset.zero, size * 0.52, paint);
    case 2:
      canvas.drawLine(Offset(-size * 0.45, -size * 0.45), Offset(size * 0.45, size * 0.45), paint);
      canvas.drawLine(Offset(size * 0.45, -size * 0.45), Offset(-size * 0.45, size * 0.45), paint);
    default:
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: size * 0.88, height: size * 0.88), paint);
  }
  canvas.restore();
}

final _controllerCache = <String, Path>{};

/// A gamepad silhouette centred on the origin: a rounded body merged with
/// two grips.
Path _controllerPath(double bw, double bh) => _controllerCache.putIfAbsent('${bw.round()}x${bh.round()}', () {
      final body = Path()..addRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(0, -bh * 0.08), width: bw, height: bh * 0.62), Radius.circular(bh * 0.31)));
      final left = Path()..addOval(Rect.fromCircle(center: Offset(-bw * 0.33, bh * 0.16), radius: bh * 0.33));
      final right = Path()..addOval(Rect.fromCircle(center: Offset(bw * 0.33, bh * 0.16), radius: bh * 0.33));
      return Path.combine(PathOperation.union, Path.combine(PathOperation.union, body, left), right);
    });

/// A big gamepad outline whose buttons light up in a combo (↑ ↑ ↓ ↓ ← → ←
/// → □ ✕ △ ○), sticks drifting, with face-button symbols floating up
/// behind it.
void gamepadMotif(Canvas canvas, Size s, double t, double ph) {
  final w = s.width, h = s.height, u = unitOf(s);
  const colors = [Color(0xFF34D399), Color(0xFFF87171), Color(0xFF60A5FA), Color(0xFFF472B6)]; // △ ○ ✕ □

  for (var i = 0; i < 18; i++) {
    final kind = i % 4;
    final y = h + 20 - fract(hash01(i + 3) + ph * (1 + i % 2)) * (h + 40);
    final x = w * (0.3 + 0.7 * hash01(i + 41)) + wave(ph, hash01(i), 2) * 8;
    _psSymbol(canvas, kind, Offset(x, y), 7 + hash01(i + 19) * 9, hash01(i + 5) * tau + ph * tau * (i.isEven ? 1 : -1), strokePaint(colors[kind], 2, 0.3 * t));
  }

  final bw = math.min(u * 1.1, w * 0.5), bh = bw * 0.5;
  final c = Offset(w - bw * 0.62, heroHeight(s) * 0.55 + (1 - t) * 24);
  final body = _controllerPath(bw, bh).shift(c);
  canvas.drawPath(body, Paint()..shader = ui.Gradient.linear(c - Offset(0, bh / 2), c + Offset(0, bh / 2), [Colors.white.withValues(alpha: 0.18 * t), Colors.white.withValues(alpha: 0.05 * t)]));
  canvas.drawPath(body, strokePaint(Colors.white, 2, 0.6 * t)..maskFilter = const MaskFilter.blur(BlurStyle.solid, 1.5));

  const combo = ['up', 'up', 'down', 'down', 'left', 'right', 'left', 'right', 'sq', 'x', 'tri', 'o'];
  final active = combo[(ph * 12).floor() % 12];
  final pulse = bump(span(fract(ph * 12), 0, 0.85));

  final dp = c + Offset(-bw * 0.27, -bh * 0.06);
  final arm = bh * 0.13, thick = bh * 0.12;
  for (final (name, dir) in const [('up', Offset(0, -1)), ('down', Offset(0, 1)), ('left', Offset(-1, 0)), ('right', Offset(1, 0))]) {
    final center = dp + dir * arm;
    final on = active == name ? pulse : 0.0;
    final r = Rect.fromCenter(center: center, width: dir.dx == 0 ? thick : arm * 1.1, height: dir.dy == 0 ? thick : arm * 1.1);
    canvas.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(thick * 0.2)), fillPaint(Color.lerp(Colors.white, const Color(0xFFFDE047), on)!, (0.2 + 0.75 * on) * t));
    if (on > 0) drawGlow(canvas, center, arm * 1.8, const Color(0xFFFDE047), 0.7 * on * t);
  }
  canvas.drawRect(Rect.fromCenter(center: dp, width: thick, height: thick), fillPaint(Colors.white, 0.2 * t));

  final fb = c + Offset(bw * 0.27, -bh * 0.06);
  final br = bh * 0.085, gap = bh * 0.16;
  for (final (name, kind, off) in const [('tri', 0, Offset(0, -1)), ('o', 1, Offset(1, 0)), ('x', 2, Offset(0, 1)), ('sq', 3, Offset(-1, 0))]) {
    final p = fb + off * gap;
    final on = active == name ? pulse : 0.0;
    final rr = br * (1 + 0.18 * on);
    canvas.drawCircle(p, rr, fillPaint(colors[kind], (0.14 + 0.6 * on) * t));
    canvas.drawCircle(p, rr, strokePaint(colors[kind], 1.2, 0.75 * t));
    _psSymbol(canvas, kind, p, br * 0.9, 0, strokePaint(on > 0.3 ? Colors.white : colors[kind], 1.3, t));
    if (on > 0) drawGlow(canvas, p, br * 3.4, colors[kind], 0.8 * on * t);
  }

  for (var i = 0; i < 2; i++) {
    final base = c + Offset(bw * (i == 0 ? -0.11 : 0.11), bh * 0.2);
    canvas.drawCircle(base, bh * 0.11, strokePaint(Colors.white, 1.2, 0.35 * t));
    final nub = base + Offset(wave(ph, i * 0.3, 3), wave(ph, i * 0.3 + 0.25, 3)) * bh * 0.04;
    canvas.drawCircle(nub, bh * 0.07, fillPaint(Colors.white, 0.25 * t));
  }
}

// ---- Blocs: a real game of falling blocks, scripted ----

// Piece types, in the order of [_tetroColors] (the guideline colours).
const _pI = 0, _pO = 1, _pT = 2, _pS = 3, _pZ = 4, _pJ = 5, _pL = 6;
const _tetroColors = [Color(0xFF22D3EE), Color(0xFFFACC15), Color(0xFFC084FC), Color(0xFF4ADE80), Color(0xFFF87171), Color(0xFF60A5FA), Color(0xFFFB923C)];

/// The pieces as the Super Rotation System has them at spawn: the size of
/// the box they turn in, and their cells in it (y up).
const _srs = <(int, List<(int, int)>)>[
  (4, [(0, 2), (1, 2), (2, 2), (3, 2)]), // I
  (2, [(0, 0), (1, 0), (0, 1), (1, 1)]), // O
  (3, [(0, 1), (1, 1), (2, 1), (1, 2)]), // T
  (3, [(0, 1), (1, 1), (1, 2), (2, 2)]), // S
  (3, [(1, 1), (2, 1), (0, 2), (1, 2)]), // Z
  (3, [(0, 1), (1, 1), (2, 1), (0, 2)]), // J
  (3, [(0, 1), (1, 1), (2, 1), (2, 2)]), // L
];

/// A piece's cells in its box after [rot] clockwise quarter turns.
List<(int, int)> _pieceCells(int type, int rot) {
  final (n, cells) = _srs[type];
  var out = cells;
  for (var q = 0; q < rot % 4; q++) {
    out = [for (final (x, y) in out) (y, n - 1 - x)];
  }
  return out;
}

/// Whether a piece fits in the well (rows bottom-up, -1 for empty) with its
/// box at column [x], row [y].
bool _fits(List<List<int>> well, int type, int rot, int x, int y) {
  for (final (cx, cy) in _pieceCells(type, rot)) {
    final bx = x + cx, by = y + cy;
    if (bx < 0 || bx > 9 || by < 0) return false;
    if (by < well.length && well[by][bx] >= 0) return false;
  }
  return true;
}

/// Where a piece dropped straight down from above lands (its box row).
int _landing(List<List<int>> well, int type, int rot, int x) {
  var y = 12;
  while (_fits(well, type, rot, x, y - 1)) {
    y--;
  }
  return y;
}

/// One piece of the scripted game: its type, its quarter turns from spawn
/// (negative: counter-clockwise), and the column its box lands in. A [spin]
/// drops one turn short and makes the last turn at the bottom, into a slot
/// it couldn't drop into.
class _Drop {
  final int type, turns, col;
  final bool spin;
  const _Drop(this.type, this.turns, this.col, {this.spin = false});
}

/// The game the "Blocs" banner plays, by the rules of modern Tetris: a
/// 10-wide well, SRS pieces dealt from 7-piece bags. The first bag builds
/// a T-spin double; the second stacks four lines with the right-hand
/// column left open; the I dropped down it clears all four — a Tetris, and
/// an all clear: the empty well the loop starts from.
const _blocksGame = [
  _Drop(_pI, 0, 0),
  _Drop(_pL, 0, 7),
  _Drop(_pS, 0, 5),
  _Drop(_pO, 0, 0),
  _Drop(_pZ, -1, 2),
  _Drop(_pJ, 2, 6),
  _Drop(_pT, 2, 3, spin: true),
  _Drop(_pS, 0, 4),
  _Drop(_pJ, 0, 0),
  _Drop(_pT, 2, 3),
  _Drop(_pO, 0, 7),
  _Drop(_pZ, 0, 0),
  _Drop(_pL, 2, 6),
  _Drop(_pI, 0, 2),
  _Drop(_pI, 1, 7),
];

/// How long one game lasts, the all clear's celebration included.
const blocksPeriod = Duration(seconds: 15);

// The pace of play, in seconds.
const _appearT = 0.10, _turnT = 0.10, _moveT = 0.06, _aimT = 0.08, _hardDropT = 0.14, _settleT = 0.20;
const _softDropT = 0.45, _holdT = 0.20, _spinT = 0.14;
const _flashT = 0.14, _dissolveT = 0.28, _collapseT = 0.20;

/// One piece's part in the game, worked out once from [_blocksGame].
class _Play {
  final _Drop drop;
  final int spawnX, topTurns, landY;
  final double spawn, dropStart, dropEnd, lockAt;
  final double? spinAt;

  /// The well before it locks, and once its lines have cleared.
  final List<List<int>> well, after;
  final List<(int, int)> cells;
  final List<int> cleared;
  final bool tSpin;
  _Play({
    required this.drop,
    required this.spawnX,
    required this.topTurns,
    required this.landY,
    required this.spawn,
    required this.dropStart,
    required this.dropEnd,
    required this.lockAt,
    required this.spinAt,
    required this.well,
    required this.after,
    required this.cells,
    required this.cleared,
    required this.tSpin,
  });

  int get dir => drop.turns < 0 ? -1 : 1;
  bool get allClear => cleared.isNotEmpty && after.isEmpty;
  double turnAt(int j) => spawn + _appearT + j * _turnT;
  double moveAt(int j) => spawn + _appearT + topTurns.abs() * _turnT + j * _moveT;
}

final List<_Play> _blocksPlays = () {
  final plays = <_Play>[];
  var well = <List<int>>[];
  var time = 0.45;
  for (final d in _blocksGame) {
    final dir = d.turns < 0 ? -1 : 1;
    final topTurns = d.spin ? d.turns - dir : d.turns;
    final y = _landing(well, d.type, topTurns, d.col);
    // A spin turns in place: SRS's first, unkicked rotation test.
    assert(!d.spin || _fits(well, d.type, d.turns, d.col, y), 'the spin does not fit');
    final cells = [for (final (cx, cy) in _pieceCells(d.type, d.turns)) (d.col + cx, y + cy)];
    // A T-spin: three of the four corners round the T's centre taken.
    var corners = 0;
    for (final (cx, cy) in const [(0, 0), (2, 0), (0, 2), (2, 2)]) {
      final bx = d.col + cx, by = y + cy;
      if (bx < 0 || bx > 9 || by < 0 || (by < well.length && well[by][bx] >= 0)) corners++;
    }
    final locked = [for (final row in well) [...row]];
    for (final (x, row) in cells) {
      while (locked.length <= row) {
        locked.add(List.filled(10, -1));
      }
      locked[row][x] = d.type;
    }
    final cleared = [for (var r = 0; r < locked.length; r++) if (!locked[r].contains(-1)) r];
    final after = [for (final row in locked) if (row.contains(-1)) row];
    final spawnX = d.type == _pO ? 4 : 3;
    final dropStart = time + _appearT + topTurns.abs() * _turnT + (d.col - spawnX).abs() * _moveT + _aimT;
    final dropEnd = dropStart + (d.spin ? _softDropT : _hardDropT);
    final spinAt = d.spin ? dropEnd + _holdT : null;
    final lockAt = spinAt == null ? dropEnd : spinAt + _spinT;
    final play = _Play(
      drop: d,
      spawnX: spawnX,
      topTurns: topTurns,
      landY: y,
      spawn: time,
      dropStart: dropStart,
      dropEnd: dropEnd,
      lockAt: lockAt,
      spinAt: spinAt,
      well: well,
      after: after,
      cells: cells,
      cleared: cleared,
      tSpin: d.spin && d.type == _pT && corners >= 3,
    );
    plays.add(play);
    well = after;
    time = cleared.isEmpty ? lockAt + _settleT : (play.allClear ? lockAt : lockAt + _flashT + _dissolveT + _collapseT + 0.06);
  }
  return plays;
}();

/// What the "Blocs" banner's game does, piece by piece — for tests, which
/// check that it plays by the rules.
@visibleForTesting
List<({String piece, List<(int, int)> cells, int lines, bool tSpin, bool allClear, double lockAt})> blocksGameLog() => [
      for (final p in _blocksPlays) (piece: 'IOTSZJL'[p.drop.type], cells: p.cells, lines: p.cleared.length, tSpin: p.tSpin, allClear: p.allClear, lockAt: p.lockAt),
    ];

void _blockCell(Canvas canvas, Rect r, Color color, double alpha) {
  if (alpha <= 0.01) return;
  final inner = r.deflate(0.8);
  canvas.drawRect(inner, fillPaint(color, 0.92 * alpha));
  canvas.drawRect(Rect.fromLTWH(inner.left, inner.top, inner.width, inner.height * 0.2), fillPaint(Colors.white, 0.38 * alpha));
  canvas.drawRect(Rect.fromLTWH(inner.left, inner.bottom - inner.height * 0.18, inner.width, inner.height * 0.18), fillPaint(Colors.black, 0.28 * alpha));
  canvas.drawRect(inner.deflate(inner.width * 0.32), fillPaint(Colors.white, 0.14 * alpha));
}

final _callouts = <String, (TextPainter, TextPainter)>{};
var _calloutsListening = false;

/// A game callout ("T-SPIN", "ALL CLEAR"): heavy letters filled with [fill]
/// top to bottom over a dark outline — laid out once, then cached.
(TextPainter, TextPainter) _calloutPainters(String text, double size, List<Color> fill, Color outline) {
  if (!_calloutsListening) {
    _calloutsListening = true;
    PaintingBindingFonts.onChange(_callouts.clear);
  }
  final q = size.roundToDouble();
  return _callouts.putIfAbsent('$text|$q|${fill.first.toARGB32()}|${outline.toARGB32()}', () {
    TextPainter layout(Paint paint) => TextPainter(
          text: TextSpan(text: text, style: TextStyle(fontSize: q, height: 1, fontWeight: FontWeight.w900, letterSpacing: q * 0.04, foreground: paint)),
          textDirection: TextDirection.ltr,
        )..layout();
    final box = Offset.zero & layout(Paint()).size;
    return (
      layout(Paint()..shader = ui.Gradient.linear(box.topCenter, box.bottomCenter, fill, [for (var k = 0; k < fill.length; k++) k / (fill.length - 1)])),
      layout(Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = q * 0.2
        ..strokeJoin = StrokeJoin.round
        ..color = outline),
    );
  });
}

/// Pops a callout at [center]: [age] seconds into its [life], slanted like
/// the game's own, bouncing in and drifting up as it fades; never wider
/// than [maxWidth].
void _callout(Canvas canvas, Offset center, String text, double size, List<Color> fill, Color outline, Color glow, double age, double life, double t, {required double maxWidth}) {
  if (age < 0 || age > life) return;
  final alpha = t * (1 - span(age, life - 0.35, life));
  final (filled, stroked) = _calloutPainters(text, size, fill, outline);
  final scale = (0.35 + 0.65 * easeOutBack(span(age, 0, 0.28))) * math.min(1.0, maxWidth / (filled.width + size * 0.4));
  final c = center - Offset(0, size * 0.5 * easeInCubic(span(age, life - 0.5, life)));
  drawGlow(canvas, c, filled.width * 0.65 * scale, glow, 0.5 * alpha);
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.scale(scale);
  canvas.skew(-0.2, 0);
  canvas.saveLayer(Rect.fromCenter(center: Offset.zero, width: filled.width + size * 2, height: filled.height + size * 2), Paint()..color = Color.fromRGBO(0, 0, 0, clamp01(alpha)));
  final o = Offset(-filled.width / 2, -filled.height / 2);
  stroked.paint(canvas, o);
  filled.paint(canvas, o);
  canvas.restore();
  canvas.restore();
}

/// A falling-blocks game played for real (see [_blocksGame]): pieces spawn
/// at the top, turn and slide into place, hard-drop and lock; a T spins
/// into its slot for a T-spin double, and a last I down the right-hand
/// column clears the well — Tetris, all clear — for the loop to begin anew.
void blocksMotif(Canvas canvas, Size s, double t, double ph) {
  final w = s.width, u = unitOf(s), zh = heroHeight(s);
  final cell = math.min(u / 9.5, w * 0.46 / 10);
  final rows = math.max(6, (zh / cell).floor());
  final floorY = rows * cell;
  final spawnBase = math.max(8, rows - 3);
  final time = ph * blocksPeriod.inMilliseconds / 1000;
  final plays = _blocksPlays;
  var i = -1;
  while (i + 1 < plays.length && plays[i + 1].spawn <= time) {
    i++;
  }
  final play = i < 0 ? null : plays[i];

  // A jolt through the well when lines go: the T-spin, the all clear.
  var shake = 0.0;
  for (final p in plays) {
    if (p.cleared.isEmpty) continue;
    final age = time - p.lockAt;
    if (age >= 0 && age < 0.3) shake = math.sin(age * 70) * cell * 0.12 * (1 - age / 0.3);
  }
  final x0 = w - cell * 10.4 + shake;
  Rect cellRect(num x, num y) => Rect.fromLTWH(x0 + x * cell, floorY - (y + 1) * cell, cell, cell);

  // The well.
  canvas.drawRect(Rect.fromLTRB(x0, 0, x0 + 10 * cell, floorY), fillPaint(Colors.black, 0.22 * t));
  final grid = strokePaint(Colors.white, 0.6, 0.06 * t);
  for (var c = 1; c < 10; c++) {
    canvas.drawLine(Offset(x0 + c * cell, 0), Offset(x0 + c * cell, floorY), grid);
  }
  for (var r = 1; r <= rows; r++) {
    canvas.drawLine(Offset(x0, floorY - r * cell), Offset(x0 + 10 * cell, floorY - r * cell), grid);
  }
  final wall = strokePaint(const Color(0xFFB9AEFF), 1.2, 0.3 * t);
  canvas.drawLine(Offset(x0, 0), Offset(x0, floorY), wall);
  canvas.drawLine(Offset(x0 + 10 * cell, 0), Offset(x0 + 10 * cell, floorY), wall);
  canvas.drawLine(Offset(x0 - 1, floorY), Offset(x0 + 10 * cell + 1, floorY), strokePaint(const Color(0xFFB9AEFF), 2, 0.55 * t));

  void stack(List<List<int>> well) {
    for (var r = 0; r < well.length; r++) {
      for (var x = 0; x < 10; x++) {
        final type = well[r][x];
        if (type >= 0) _blockCell(canvas, cellRect(x, r), _tetroColors[type], t);
      }
    }
  }

  if (play != null) {
    final d = play.drop;
    if (time < play.lockAt) {
      stack(play.well);
      // Where it stands: turns and moves done, in progress; the drop.
      final turnsDone = [for (var j = 0; j < play.topTurns.abs(); j++) if (time >= play.turnAt(j)) j].length;
      final turnP = turnsDone == 0 ? 1.0 : span(time, play.turnAt(turnsDone - 1), play.turnAt(turnsDone - 1) + _turnT * 0.8);
      final moves = (d.col - play.spawnX).abs(), step = (d.col - play.spawnX).sign;
      final movesDone = [for (var j = 0; j < moves; j++) if (time >= play.moveAt(j)) j].length;
      final moveP = movesDone == 0 ? 1.0 : span(time, play.moveAt(movesDone - 1), play.moveAt(movesDone - 1) + _moveT * 0.75);
      var rot = play.dir * turnsDone;
      var angle = turnP < 1 ? play.dir * (math.pi / 2) * (easeOutCubic(turnP) - 1) : 0.0;
      final bx = play.spawnX + step * (movesDone == 0 ? 0 : movesDone - 1 + easeOutCubic(moveP));
      final spawnY = spawnBase - _pieceCells(d.type, 0).map((c) => c.$2).reduce(math.min) + 0.5 * (1 - easeOutCubic(span(time, play.spawn, play.spawn + _appearT)));
      double by;
      if (time < play.dropStart) {
        by = spawnY;
      } else if (time < play.dropEnd) {
        final p = span(time, play.dropStart, play.dropEnd);
        by = lerpD(spawnY, play.landY.toDouble(), d.spin ? easeInOutSine(p) : p * p);
      } else {
        by = play.landY.toDouble();
      }
      // The spin: the last turn, made at the bottom.
      final spinAt = play.spinAt;
      if (spinAt != null && time >= spinAt) {
        rot += play.dir;
        final p = span(time, spinAt, spinAt + _spinT);
        angle = play.dir * (math.pi / 2) * (easeOutBack(p) - 1);
      }
      // The ghost: where a drop would land it now.
      final gx = play.spawnX + step * movesDone, gRot = play.dir * turnsDone;
      final gy = _landing(play.well, d.type, gRot, gx);
      if (time < play.dropEnd && gy < by - 0.5) {
        for (final (cx, cy) in _pieceCells(d.type, gRot)) {
          final r = cellRect(gx + cx, gy + cy).deflate(1.6);
          canvas.drawRect(r, fillPaint(_tetroColors[d.type], 0.1 * t));
          canvas.drawRect(r, strokePaint(_tetroColors[d.type], 1.1, 0.5 * t));
        }
      }
      // A hard drop's streak.
      if (!d.spin && time >= play.dropStart) {
        final p = span(time, play.dropStart, play.dropEnd);
        for (final (cx, cy) in _pieceCells(d.type, rot)) {
          final r = cellRect(bx + cx, by + cy);
          final top = floorY - (spawnY + cy + 1) * cell;
          if (top < r.top) {
            final streak = Rect.fromLTRB(r.left + cell * 0.15, top, r.right - cell * 0.15, r.top);
            canvas.drawRect(streak, Paint()..shader = ui.Gradient.linear(streak.topCenter, streak.bottomCenter, [_tetroColors[d.type].withValues(alpha: 0), _tetroColors[d.type].withValues(alpha: 0.4 * p * t)]));
          }
        }
      }
      // The piece, turning about its box's centre.
      final (n, _) = _srs[d.type];
      final alpha = t * span(time, play.spawn, play.spawn + _appearT * 0.7);
      canvas.save();
      canvas.translate(x0 + (bx + n / 2) * cell, floorY - (by + n / 2) * cell);
      canvas.rotate(angle);
      for (final (cx, cy) in _pieceCells(d.type, rot)) {
        _blockCell(canvas, Rect.fromLTWH((cx - n / 2) * cell, -(cy + 1 - n / 2) * cell, cell, cell), _tetroColors[d.type], alpha);
      }
      canvas.restore();
      if (spinAt != null && time >= spinAt) {
        final c = cellRect(d.col + 1, play.landY + 1).center;
        final p = span(time, spinAt, spinAt + _spinT);
        drawGlow(canvas, c, cell * (1.5 + 1.5 * p), const Color(0xFFC084FC), 0.7 * t);
      }
    } else {
      final age = time - play.lockAt;
      final cleared = play.cleared.toSet();
      final locked = [for (final row in play.well) [...row]];
      for (final (x, row) in play.cells) {
        while (locked.length <= row) {
          locked.add(List.filled(10, -1));
        }
        locked[row][x] = d.type;
      }
      if (cleared.isEmpty) {
        stack(locked);
      } else if (play.allClear) {
        // Every block bursts, from the middle out.
        for (var r = 0; r < locked.length; r++) {
          for (var x = 0; x < 10; x++) {
            final type = locked[r][x];
            if (type < 0) continue;
            final pop = span(age, 0.12 + (x - 4.5).abs() * 0.025, 0.32 + (x - 4.5).abs() * 0.025);
            final rect = cellRect(x, r);
            if (pop < 1) _blockCell(canvas, Rect.fromCenter(center: rect.center, width: cell * (1 + 0.3 * pop), height: cell * (1 + 0.3 * pop)), Color.lerp(_tetroColors[type], Colors.white, pop)!, t * (1 - pop));
            for (var k = 0; k < 2; k++) {
              final seed = r * 20 + x * 2 + k;
              final pa = age - 0.12 - (x - 4.5).abs() * 0.025;
              if (pa <= 0 || pa > 1.1) continue;
              final v = Offset((x - 4.5) * cell * (0.6 + 1.2 * hash01(seed)) + (hash01(seed + 7) - 0.5) * cell * 4, -cell * (5 + 7 * hash01(seed + 3)));
              final q = ballistic(rect.center, v, pa, gravity: cell * 26, drag: 1.2);
              final sz = cell * (0.2 + 0.18 * hash01(seed + 5)) * (1 - pa / 1.1);
              canvas.drawRect(Rect.fromCenter(center: q, width: sz, height: sz), fillPaint(k == 0 ? _tetroColors[type] : Colors.white, t * (1 - pa / 1.1)));
            }
          }
        }
        if (age < 0.3) {
          canvas.drawRect(Rect.fromLTRB(x0, floorY - locked.length * cell, x0 + 10 * cell, floorY), Paint()
            ..blendMode = BlendMode.plus
            ..color = Colors.white.withValues(alpha: 0.7 * (1 - age / 0.3) * t));
        }
      } else if (age < _flashT + _dissolveT) {
        // The full rows flash, then dissolve from the middle out.
        for (var r = 0; r < locked.length; r++) {
          for (var x = 0; x < 10; x++) {
            final type = locked[r][x];
            if (type < 0) continue;
            final rect = cellRect(x, r);
            if (!cleared.contains(r)) {
              _blockCell(canvas, rect, _tetroColors[type], t);
              continue;
            }
            final v = span(age - _flashT, (x - 4.5).abs() / 4.5 * _dissolveT * 0.5, (x - 4.5).abs() / 4.5 * _dissolveT * 0.5 + _dissolveT * 0.5);
            _blockCell(canvas, rect.deflate(cell * 0.5 * v), Color.lerp(_tetroColors[type], Colors.white, 0.6 + 0.4 * v)!, t * (1 - v));
            if (age < _flashT) canvas.drawRect(rect, Paint()..blendMode = BlendMode.plus..color = Colors.white.withValues(alpha: 0.75 * span(age, 0, 0.05) * t));
          }
        }
      } else {
        // What was above them falls into place.
        final p = easeInCubic(span(age, _flashT + _dissolveT, _flashT + _dissolveT + _collapseT));
        final kept = [for (var r = 0; r < locked.length; r++) if (!cleared.contains(r)) r];
        for (final (k, r) in kept.indexed) {
          for (var x = 0; x < 10; x++) {
            final type = locked[r][x];
            if (type >= 0) _blockCell(canvas, cellRect(x, lerpD(r.toDouble(), k.toDouble(), p)), _tetroColors[type], t);
          }
        }
      }
      // The lock: a flash over the piece just placed.
      if (age < 0.18 && !play.allClear) {
        for (final (x, row) in play.cells) {
          if (cleared.contains(row) && age > _flashT) continue;
          canvas.drawRect(cellRect(x, row).deflate(0.8), Paint()..blendMode = BlendMode.plus..color = Colors.white.withValues(alpha: 0.55 * (1 - age / 0.18) * t));
        }
      }
      // The streak of its hard drop, fading.
      if (!d.spin && age < 0.18) {
        for (final (x, row) in play.cells) {
          final r = cellRect(x, row);
          final streak = Rect.fromLTRB(r.left + cell * 0.15, r.top - cell * 4, r.right - cell * 0.15, r.top);
          canvas.drawRect(streak, Paint()..shader = ui.Gradient.linear(streak.topCenter, streak.bottomCenter, [_tetroColors[d.type].withValues(alpha: 0), _tetroColors[d.type].withValues(alpha: 0.4 * (1 - age / 0.18) * t)]));
        }
      }
    }
  }

  // Callouts.
  for (final p in plays) {
    if (p.tSpin && p.cleared.isNotEmpty) {
      final c = Offset(x0 + (p.drop.col + 1.5) * cell, floorY - 6.2 * cell);
      const names = ['', 'SINGLE', 'DOUBLE', 'TRIPLE'];
      _callout(canvas, c, 'T-SPIN', cell * 1.25, const [Colors.white, Color(0xFFE9D5FF), Color(0xFFC084FC)], const Color(0xFF3B0764), const Color(0xFFC084FC), time - p.lockAt, 1.6, t, maxWidth: cell * 9.4);
      _callout(canvas, c + Offset(0, cell * 1.25), names[p.cleared.length], cell * 0.8, const [Color(0xFFF5EEFF), Color(0xFFD8B4FE)], const Color(0xFF3B0764), const Color(0xFFC084FC), time - p.lockAt - 0.08, 1.52, t, maxWidth: cell * 9.4);
    }
    if (p.allClear) {
      final c = Offset(x0 + 5 * cell, floorY - 3.4 * cell);
      final age = time - p.lockAt;
      if (p.cleared.length == 4) _callout(canvas, c - Offset(0, cell * 1.55), 'TETRIS', cell * 0.85, const [Colors.white, Color(0xFFA5F3FC), Color(0xFF22D3EE)], const Color(0xFF083344), const Color(0xFF22D3EE), age - 0.05, 2.1, t, maxWidth: cell * 9.4);
      _callout(canvas, c, 'ALL CLEAR', cell * 1.3, const [Colors.white, Color(0xFFFFE08A), Color(0xFFF59E0B)], const Color(0xFF431407), const Color(0xFFFFB703), age - 0.18, 1.97, t, maxWidth: cell * 9.4);
      // Sparkles round it.
      for (var k = 0; k < 7; k++) {
        final local = span(age - 0.3 - k * 0.14, 0, 0.5);
        if (local <= 0 || local >= 1) continue;
        final q = c + Offset((hash01(k + 40) - 0.5) * cell * 9, (hash01(k + 50) - 0.5) * cell * 3.4);
        drawSparkle(canvas, q, cell * 0.45 * bump(local), fillPaint(Colors.white, bump(local) * t));
      }
    }
  }
}

/// A spiral galaxy turning slowly (inner stars faster than outer), deep
/// stars drifting by at three depths, a ringed planet and a comet.
void galaxyMotif(Canvas canvas, Size s, double t, double ph) {
  final w = s.width, h = s.height, u = unitOf(s);

  for (var i = 0; i < 80; i++) {
    final depth = 1 + i % 3;
    final x = fract(hash01(i) - ph * depth) * w;
    final tw = wave01(ph, hash01(i + 90), 5 + i % 4);
    canvas.drawCircle(Offset(x, hash01(i + 50) * h), 0.35 + depth * 0.35, fillPaint(Colors.white, (0.15 + 0.22 * depth) * (0.45 + 0.55 * tw) * t));
  }

  for (final (c, r, color, seed) in [
    (Offset(w * 0.7, h * 0.3), u * 0.8, const Color(0xFF9D4EDD), 0.1),
    (Offset(w * 0.95, h * 0.85), u * 0.65, const Color(0xFF2EC4B6), 0.4),
    (Offset(w * 0.55, h * 0.95), u * 0.55, const Color(0xFFE0337E), 0.7),
  ]) {
    drawGlow(canvas, c, r * (0.85 + 0.15 * wave(ph, seed, 2)), color, 0.4 * t);
  }

  final zh = heroHeight(s);
  final gc = Offset(w * 0.72, zh * 0.55);
  final gr = math.min(u * 0.62, w * 0.3);
  canvas.save();
  canvas.translate(gc.dx, gc.dy);
  canvas.rotate(-0.35);
  canvas.scale(1, 0.48);
  canvas.drawCircle(
    Offset.zero,
    gr * 0.55,
    Paint()
      ..blendMode = BlendMode.plus
      ..shader = ui.Gradient.radial(Offset.zero, gr * 0.55, [const Color(0xFFFFF1D6).withValues(alpha: 0.85 * t), const Color(0xFFFFB86B).withValues(alpha: 0.3 * t), const Color(0x00FFB86B)], const [0, 0.3, 1]),
  );
  const starColors = [Color(0xFFFFE8C2), Color(0xFFA5C8FF), Color(0xFFFFA8E2), Color(0xFF8FA8FF)];
  const sizes = [1.5, 1.9, 1.9, 1.1];
  const alphas = [0.9, 0.85, 0.85, 0.35];
  final buckets = [<Offset>[], <Offset>[], <Offset>[], <Offset>[]];
  for (var arm = 0; arm < 2; arm++) {
    for (var i = 0; i < 260; i++) {
      final id = arm * 1000 + i;
      final r01 = math.pow(hash01(id), 0.8).toDouble();
      final spread = (hash01(id + 500) - 0.5) * 0.75 * (1 - r01 * 0.35);
      final turns = r01 < 0.45 ? 2 : 1; // differential rotation, whole turns per loop
      final theta = arm * math.pi + r01 * 4.6 + spread + ph * tau * turns;
      final r = (0.1 + r01 * 0.9) * gr * (1 + (hash01(id + 900) - 0.5) * 0.12);
      buckets[r01 < 0.2 ? 0 : (hash01(id + 7) < 0.2 ? 2 : 1)].add(Offset(math.cos(theta), math.sin(theta)) * r);
    }
  }
  // A faint disc of unresolved stars, and a dense bulge.
  for (var i = 0; i < 320; i++) {
    final r = math.sqrt(hash01(i + 3000)) * gr * 1.05;
    final theta = hash01(i + 4000) * tau + ph * tau * (r < gr * 0.5 ? 2 : 1);
    buckets[3].add(Offset(math.cos(theta), math.sin(theta)) * r);
  }
  for (var i = 0; i < 90; i++) {
    final r = math.pow(hash01(i + 5000), 2).toDouble() * gr * 0.3;
    final theta = hash01(i + 6000) * tau + ph * tau * 2;
    buckets[0].add(Offset(math.cos(theta), math.sin(theta)) * r);
  }
  for (var b = 0; b < 4; b++) {
    canvas.drawPoints(ui.PointMode.points, buckets[b], Paint()
      ..strokeWidth = sizes[b]
      ..strokeCap = StrokeCap.round
      ..blendMode = BlendMode.plus
      ..color = starColors[b].withValues(alpha: alphas[b] * t));
  }
  canvas.restore();

  // Ringed planet bobbing in the corner.
  final pc = Offset(w * 0.93, zh * 0.17 + wave(ph, 0, 2) * 3 + (1 - t) * -20);
  final pr = u * 0.085;
  final ring = Rect.fromCenter(center: pc, width: pr * 3.4, height: pr * 0.9);
  final ringPaint = strokePaint(const Color(0xFFFFD6A5), pr * 0.18, 0.85 * t);
  canvas.save();
  canvas.translate(pc.dx, pc.dy);
  canvas.rotate(-0.4);
  canvas.translate(-pc.dx, -pc.dy);
  canvas.drawArc(ring, math.pi, math.pi, false, ringPaint);
  canvas.drawCircle(pc, pr, Paint()..shader = ui.Gradient.linear(pc - Offset(pr, pr), pc + Offset(pr, pr), [const Color(0xFFFFC38A).withValues(alpha: t), const Color(0xFFB83B2B).withValues(alpha: t)]));
  canvas.drawArc(ring, 0, math.pi, false, ringPaint);
  canvas.restore();

  final comet = loopWindow(ph, 0.6, 0.12);
  if (comet != null) {
    final head = Offset(lerpD(w * 1.02, w * 0.45, comet), lerpD(zh * 0.05, zh * 0.5, comet));
    final tail = head + const Offset(0.9, -0.55) * (u * 0.4);
    canvas.drawLine(tail, head, Paint()
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..shader = ui.Gradient.linear(tail, head, [const Color(0x00A5F3FC), const Color(0xFFA5F3FC).withValues(alpha: bump(comet) * t)]));
    drawGlow(canvas, head, 9, const Color(0xFFE0FBFF), bump(comet) * t);
  }
}

const _gbDark = Color(0xFF0F380F), _gbMid = Color(0xFF306230), _gbLight = Color(0xFF8BAC0F), _gbPale = Color(0xFF9BBC0F);
const _heroA = ['00111100', '01111110', '01121210', '01111110', '00111100', '01133110', '11333311', '00333300', '00300300', '01100110'];
const _heroB = ['00111100', '01111110', '01121210', '01111110', '00111100', '01133110', '01333310', '00333300', '00033000', '00110110'];
const _heroJump = ['00111100', '01111110', '01121210', '01111110', '10111101', '11133111', '00333300', '00333300', '01100110', '01000010'];
const _gbCloud = ['000111100000', '001111110110', '011111111111', '111111111111', '011111111110'];
const _gbPipe = ['1111111111', '1222222221', '1111111111', '0122222210', '0122222210', '0122222210', '0122222210', '0122222210', '0122222210', '0122222210'];
const _gbHeart = ['0110110', '1111111', '1111111', '0111110', '0011100', '0001000'];

/// A Game Boy side-scroller: hills and clouds in parallax, the ground
/// scrolling under a little hero who walks and hops every pipe, coins
/// spinning above them, and a low-health heart blinking.
void gameboyMotif(Canvas canvas, Size s, double t, double ph) {
  final w = s.width, h = s.height, u = unitOf(s);
  final left = w * 0.3;
  final pxl = u * 0.024;
  final zh = heroHeight(s);
  final groundY = zh * 0.98 - u * 0.17;
  // The scene lives in the screen right of `left`: what scrolls out of it
  // is cut off there rather than vanishing past it.
  canvas.save();
  canvas.clipRect(Rect.fromLTRB(left, 0, w, h));

  // LCD pixel grid.
  final lcd = strokePaint(_gbDark, 0.7, 0.18 * t);
  for (var x = left; x < w; x += 5) {
    canvas.drawLine(Offset(x, 0), Offset(x, h), lcd);
  }
  for (var y = 0.0; y < h; y += 5) {
    canvas.drawLine(Offset(left, y), Offset(w, y), lcd);
  }

  // Far hills, pixel-stepped, one width per loop.
  final hills = Path()..moveTo(left, groundY);
  for (var x = left; x <= w + 4; x += 4) {
    final f = x / w + ph;
    final m = 0.5 + 0.3 * math.sin(f * tau * 2) + 0.2 * math.sin(f * tau * 3 + 1);
    hills.lineTo(x, ((groundY - u * 0.38 * m) / (pxl * 2)).floorToDouble() * pxl * 2);
  }
  hills
    ..lineTo(w + 4, groundY)
    ..close();
  canvas.drawPath(hills, fillPaint(_gbMid, 0.85 * t));

  for (var i = 0; i < 3; i++) {
    final cw = _gbCloud.first.length * pxl;
    final x = fract(hash01(i + 1) - ph * 2) * (w - left + cw) + left - cw;
    drawSprite(canvas, _gbCloud, Offset(x, zh * (0.1 + 0.11 * i)), pxl, {'1': _gbPale}, alpha: 0.9 * t);
  }

  // The world scrolls `loopLen` px per loop; bricks and pipes repeat with
  // it, so the loop wraps cleanly.
  final loopLen = w * 1.2;
  final scroll = ph * loopLen;
  canvas.drawRect(Rect.fromLTWH(left, groundY, w - left, h - groundY), fillPaint(_gbMid, t));
  final brickCount = (loopLen / (pxl * 8)).round();
  final brick = loopLen / brickCount;
  final off = fract(ph * brickCount) * brick;
  for (var r = 0; r < 3; r++) {
    for (var x = left - brick - off + (r.isOdd ? brick / 2 : 0); x < w; x += brick) {
      canvas.drawRect(Rect.fromLTWH(x + 1, groundY + r * brick * 0.5 + 1, brick - 2, brick * 0.5 - 2), fillPaint(_gbLight, (r == 0 ? 0.85 : 0.5) * t));
    }
  }

  final heroX = w * 0.72;
  final pipeW = _gbPipe.first.length * pxl, pipeH = _gbPipe.length * pxl;
  var jump = 0.0;
  const pipes = 3;
  for (var k = 0; k < pipes; k++) {
    final sx = left - pipeW + _mod(k * loopLen / pipes - scroll - (left - pipeW), loopLen);
    if (sx > w) continue;
    drawSprite(canvas, _gbPipe, Offset(sx, groundY - pipeH), pxl, {'1': _gbDark, '2': _gbLight}, alpha: t);
    // A coin spinning over each pipe.
    final coinC = Offset(sx + pipeW / 2, groundY - pipeH - u * 0.32 + wave(ph, k / pipes, 4) * 3);
    final spin = math.cos(ph * tau * 8 + k).abs();
    canvas.save();
    canvas.translate(coinC.dx, coinC.dy);
    canvas.scale(math.max(0.15, spin), 1);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: pxl * 5, height: pxl * 6), fillPaint(_gbPale, t));
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: pxl * 2, height: pxl * 3.6), fillPaint(_gbMid, t));
    canvas.restore();
    // The hero hops every pipe it meets: a parabola in its distance to it.
    final d = (sx + pipeW / 2) - heroX;
    final range = pipeW * 1.7;
    if (d.abs() < range) jump = math.max(jump, 1 - (d / range) * (d / range));
  }
  final heroH = _heroA.length * pxl;
  // Steps and blinks are offset by half a beat so none lands on the wrap.
  final sprite = jump > 0.05 ? _heroJump : ((ph * 96 + 0.5).floor().isEven ? _heroA : _heroB);
  drawSprite(canvas, sprite, Offset(heroX - 4 * pxl, groundY - heroH - jump * (pipeH + u * 0.12)), pxl, {'1': _gbPale, '2': _gbDark, '3': _gbLight}, alpha: t);

  for (var i = 0; i < 3; i++) {
    final blink = i == 2 && (ph * 12 + 0.5).floor().isOdd ? 0.25 : 1.0;
    drawSprite(canvas, _gbHeart, Offset(w - (3 - i) * pxl * 9 - pxl * 2, h * 0.05), pxl, {'1': _gbPale}, alpha: t * blink);
  }
  canvas.restore();
}

// ============================== Jeux de société ==============================

/// A chessboard under a sweeping light, a knight hopping round a closed
/// circuit of L-moves (each landing square lighting up just before), the
/// other pieces standing guard.
void chessMotif(Canvas canvas, Size s, double t, double ph) {
  final w = s.width, h = s.height, u = unitOf(s);
  final sq = u / 5;
  final cols = (w / sq).ceil();
  // The board is shifted so the knight's 4×4 circuit sits centred in the
  // hero band, still on whole squares.
  final top = math.max(0.0, (heroHeight(s) - 4 * sq) / 2);
  final shift = top - (top / sq).floorToDouble() * sq;
  final rows = ((h - shift) / sq).ceil() + 1;
  for (var y = -1; y < rows; y++) {
    for (var x = 0; x < cols; x++) {
      if ((x + y).isOdd) continue;
      final d = fract((x + y) / (cols + rows) - ph);
      final glow = math.max(0.0, 1 - (d - 0.5).abs() * 7);
      canvas.drawRect(Rect.fromLTWH(x * sq, shift + y * sq, sq, sq), fillPaint(const Color(0xFFF5DEB3), (0.1 + 0.16 * glow) * t));
    }
  }

  final ac = cols - 5;
  final ar = (top / sq).floor();
  Offset at(Offset cell) => Offset((ac + cell.dx + 0.5) * sq, shift + (ar + cell.dy + 0.5) * sq);
  const cream = Color(0xFFFFF4E0);
  for (final (glyph, cell, seed) in const [('♜', Offset(0, 3), 0.1), ('♛', Offset(1, 0), 0.4), ('♝', Offset(3, 1), 0.7), ('♚', Offset(2, 3), 0.9)]) {
    final p = at(cell);
    drawGlow(canvas, p, sq * 0.7, const Color(0xFFFFD166), 0.12 * wave01(ph, seed, 2) * t);
    drawGlyph(canvas, glyph, p, sq * 0.82, cream.withValues(alpha: 0.5 * t));
  }

  // The knight's circuit: four L-moves that close the loop.
  const circuit = [Offset(0, 0), Offset(2, 1), Offset(3, 3), Offset(1, 2)];
  final seg = (ph * 4).floor() % 4;
  final f = fract(ph * 4);
  final from = at(circuit[seg]), to = at(circuit[(seg + 1) % 4]);
  final jump = span(f, 0.55, 0.88);
  final landing = span(f, 0.88, 1);
  final antic = bump(span(f, 0.3, 0.98));
  canvas.drawRect(Rect.fromCenter(center: to, width: sq, height: sq), Paint()
    ..blendMode = BlendMode.plus
    ..color = const Color(0xFFFFD166).withValues(alpha: 0.38 * antic * t));
  canvas.drawRect(Rect.fromCenter(center: to, width: sq, height: sq).deflate(1.5), strokePaint(const Color(0xFFFFD166), 1.5, 0.7 * antic * t));
  // The L itself, dotted, while it's being considered.
  final corner = Offset(to.dx, from.dy);
  final dots = strokePaint(const Color(0xFFFFD166), 2.2, 0.5 * antic * (1 - jump) * t);
  for (final (a, b) in [(from, corner), (corner, to)]) {
    final n = ((b - a).distance / 7).floor();
    for (var i = 1; i < n; i++) {
      canvas.drawPoints(ui.PointMode.points, [Offset.lerp(a, b, i / n)!], dots);
    }
  }
  final pos = Offset.lerp(from, to, easeInOutSine(jump))!;
  final lift = bump(jump) * sq * 0.95;
  final squash = 1 - 0.14 * bump(landing);
  canvas.drawOval(Rect.fromCenter(center: pos + Offset(0, sq * 0.34), width: sq * 0.62 * (1 - lift / (sq * 2.4)), height: sq * 0.16), fillPaint(Colors.black, 0.4 * t));
  drawGlow(canvas, pos - Offset(0, lift), sq * 0.9, const Color(0xFFFFD166), 0.25 * t);
  drawGlyph(canvas, '♞', pos - Offset(0, lift + sq * (1 - squash) * 0.4), sq * 0.98, cream.withValues(alpha: t), angle: (to.dx > from.dx ? 1 : -1) * 0.28 * bump(jump), scaleX: 2 - squash, scaleY: squash);
}

/// Dice on felt, each re-rolled twice a loop: a hop with a full spin,
/// faces tumbling, a squash and a puff of dust on landing.
void diceMotif(Canvas canvas, Size s, double t, double ph) {
  final w = s.width, h = s.height, u = unitOf(s);
  for (var i = 0; i < 140; i++) {
    canvas.drawCircle(Offset(hash01(i) * w, hash01(i + 500) * h), 0.6 + hash01(i + 900) * 0.9, fillPaint(hash01(i + 1300) > 0.5 ? Colors.white : Colors.black, 0.05));
  }
  const xs = [0.58, 0.75, 0.91, 0.67, 0.86], ys = [0.3, 0.62, 0.3, 0.86, 0.85];
  for (var i = 0; i < 5; i++) {
    final size = u * (0.17 + 0.04 * hash01(i + 3));
    final rest = Offset(w * xs[i], heroHeight(s) * ys[i] - (1 - stagger(t, i, 5)) * h);
    final cyc = (ph + i / 5) * 2;
    final rollIndex = cyc.floor();
    final local = fract(cyc);
    const rollLen = 0.3;
    var height = 0.0, angle = hash01(i) * 0.7 - 0.35, sqx = 1.0, sqy = 1.0;
    var face = 1 + (hash01(i * 31 + rollIndex % 2) * 6).floor();
    if (local < rollLen) {
      final r = local / rollLen;
      height = 4 * r * (1 - r) * math.min(u * 0.42, rest.dy - size * 0.8);
      angle += easeOutCubic(r) * tau; // one full turn: it comes to rest square again
      face = 1 + (hash01(i * 97 + (r * 9).floor()) * 6).floor();
    } else {
      final land = span(local, rollLen, rollLen + 0.07);
      final k = bump(land);
      sqx = 1 + 0.14 * k;
      sqy = 1 - 0.14 * k;
      if (land > 0 && land < 1) {
        canvas.drawOval(Rect.fromCenter(center: rest + Offset(0, size * 0.55), width: size * (1.2 + land * 1.4), height: size * (0.3 + land * 0.35)), strokePaint(const Color(0xFFFFE4C4), 1.4, 0.5 * (1 - land) * t));
      }
    }
    canvas.drawOval(Rect.fromCenter(center: rest + Offset(height * 0.1, size * 0.62), width: size * (1.15 - height / (u * 1.2)), height: size * 0.3), fillPaint(Colors.black, 0.35 * t));
    drawDie(canvas, rest - Offset(0, height), size, face, angle: angle, alpha: t, squashX: sqx, squashY: sqy);
  }
}

Path _meeplePath(double size) {
  final u = size;
  return Path()
    ..addOval(Rect.fromCircle(center: Offset(0, -0.32 * u), radius: 0.17 * u))
    ..addPolygon([
      Offset(-0.36 * u, -0.14 * u),
      Offset(0.36 * u, -0.14 * u),
      Offset(0.5 * u, 0.02 * u),
      Offset(0.2 * u, 0.08 * u),
      Offset(0.4 * u, 0.5 * u),
      Offset(0.08 * u, 0.5 * u),
      Offset(0, 0.3 * u),
      Offset(-0.08 * u, 0.5 * u),
      Offset(-0.4 * u, 0.5 * u),
      Offset(-0.2 * u, 0.08 * u),
      Offset(-0.5 * u, 0.02 * u),
    ], true);
}

/// A board-game track of coloured spaces in perspective, meeples hopping
/// round it one space per beat, nearer ones bigger.
void meeplesMotif(Canvas canvas, Size s, double t, double ph) {
  final w = s.width, u = unitOf(s);
  final zh = heroHeight(s);
  final c = Offset(w * 0.72, zh * 0.56);
  final rx = math.min(w * 0.24, u * 0.95), ry = math.min(zh * 0.3, u * 0.4);
  const spaces = 16;
  Offset spaceAt(double k) {
    final a = k / spaces * tau - math.pi / 2;
    return c + Offset(math.cos(a) * rx, math.sin(a) * ry);
  }

  double depthOf(Offset p) => clamp01((p.dy - (c.dy - ry)) / (2 * ry));
  const spaceColors = [Color(0xFFFFF1D6), Color(0xFFE63946), Color(0xFF3A86FF), Color(0xFF2EC4B6), Color(0xFFFFBE0B)];
  for (var k = 0; k < spaces; k++) {
    final p = spaceAt(k.toDouble());
    final d = depthOf(p);
    final sz = u * (0.075 + 0.045 * d);
    final r = RRect.fromRectAndRadius(Rect.fromCenter(center: p, width: sz * 1.6, height: sz), Radius.circular(sz * 0.3));
    final a = (0.5 + 0.3 * d) * stagger(t, k, spaces);
    canvas.drawRRect(r.shift(Offset(0, sz * 0.18)), fillPaint(Colors.black, 0.3 * a));
    canvas.drawRRect(r, fillPaint(spaceColors[k % 5], a));
  }

  const colors = [Color(0xFFE63946), Color(0xFF3A86FF), Color(0xFFFFBE0B), Color(0xFF2EC4B6), Color(0xFFF1FAEE)];
  final draws = <(double, void Function())>[];
  for (var j = 0; j < 5; j++) {
    final beat = ph * spaces + j * 0.2; // 16 hops a loop, staggered
    final k0 = (beat.floor() + j * 3) % spaces;
    final hop = span(fract(beat), 0, 0.45);
    final land = span(fract(beat), 0.45, 0.6);
    final pos = Offset.lerp(spaceAt(k0.toDouble()), spaceAt(k0 + 1.0), easeInOutSine(hop))!;
    final d = depthOf(pos);
    final size = u * (0.2 + 0.09 * d);
    final lift = bump(hop) * u * 0.16;
    final squash = 1 - 0.16 * bump(land);
    draws.add((pos.dy, () {
      canvas.drawOval(Rect.fromCenter(center: pos, width: size * 0.7 * (1 - lift / (u * 0.5)), height: size * 0.2), fillPaint(Colors.black, 0.35 * t));
      canvas.save();
      canvas.translate(pos.dx, pos.dy - lift - size * 0.48 * squash);
      canvas.rotate((j.isEven ? 1 : -1) * 0.18 * bump(hop));
      canvas.scale(2 - squash, squash);
      final path = _meeplePath(size);
      final color = colors[j];
      canvas.drawPath(path, Paint()..shader = ui.Gradient.linear(Offset(-size * 0.5, -size * 0.5), Offset(size * 0.5, size * 0.5), [Color.lerp(color, Colors.white, 0.35)!.withValues(alpha: t), color.withValues(alpha: t), Color.lerp(color, Colors.black, 0.3)!.withValues(alpha: t)], const [0, 0.5, 1]));
      canvas.drawPath(path, strokePaint(Color.lerp(color, Colors.black, 0.45)!, 1, 0.6 * t));
      canvas.restore();
    }));
  }
  draws.sort((a, b) => a.$1.compareTo(b.$1));
  for (final d in draws) {
    d.$2();
  }
}

const _terrainColors = {
  'wood': Color(0xFF2D6A4F),
  'wheat': Color(0xFFE9C46A),
  'sheep': Color(0xFF95D5B2),
  'brick': Color(0xFFC1663B),
  'ore': Color(0xFF8D99AE),
  'desert': Color(0xFFE9D8A6),
};
const _terrainIcons = {'wood': '🌲', 'wheat': '🌾', 'sheep': '🐑', 'brick': '🧱', 'ore': '⛰️', 'desert': '🏜️'};
const _island = [
  ('ore', 10), ('sheep', 2), ('wood', 9), //
  ('wheat', 12), ('brick', 6), ('sheep', 4), ('brick', 10), //
  ('wheat', 9), ('wood', 11), ('desert', 0), ('wood', 3), ('ore', 8), //
  ('wood', 8), ('ore', 3), ('wheat', 4), ('sheep', 5), //
  ('brick', 5), ('wheat', 6), ('sheep', 11), //
];

/// A Catan-like island: three rolls a loop — the dice tumble in the
/// corner, the matching number tokens light up and resource cubes fly off
/// their hexes to the bank. The robber idles on the desert.
void hexesMotif(Canvas canvas, Size s, double t, double ph) {
  final w = s.width, h = s.height, u = unitOf(s);
  // Swell lines on the sea.
  for (var i = 0; i < 9; i++) {
    final y = h * (0.1 + i * 0.1);
    final x = fract(hash01(i) + ph * (1 + i % 2)) * w;
    canvas.drawLine(Offset(x, y), Offset(x + u * 0.25, y), strokePaint(Colors.white, 1.2, 0.12 * t));
  }
  final c = Offset(w * 0.72, heroHeight(s) * 0.53);
  final r = math.min(u / 7.6, w * 0.3 / 4.4);
  final cells = <(Offset, String, int)>[];
  var idx = 0;
  for (var row = -2; row <= 2; row++) {
    final count = 5 - row.abs();
    for (var k = 0; k < count; k++) {
      final x = (k - (count - 1) / 2) * r * math.sqrt(3);
      final p = c + Offset(x, row * r * 1.5);
      final (terrain, number) = _island[idx++];
      cells.add((p, terrain, number));
    }
  }
  Path hexAt(Offset p, double rr) {
    final path = Path();
    for (var v = 0; v < 6; v++) {
      final a = math.pi / 3 * v - math.pi / 2;
      final q = p + Offset(math.cos(a), math.sin(a)) * rr;
      v == 0 ? path.moveTo(q.dx, q.dy) : path.lineTo(q.dx, q.dy);
    }
    return path..close();
  }

  // The coast.
  canvas.drawPath(hexAt(c, r * 4.9), fillPaint(const Color(0xFFE9D8A6), 0.18 * t));
  const rolls = [6, 8, 5];
  final rollIdx = (ph * 3).floor() % 3;
  final rf = fract(ph * 3);
  final rolled = rolls[rollIdx];
  for (final (i, (p, terrain, number)) in cells.indexed) {
    final k = stagger(t, i, cells.length);
    final hex = hexAt(p, (r - 1.2) * (0.6 + 0.4 * k));
    final color = _terrainColors[terrain]!;
    canvas.drawPath(hex, Paint()..shader = ui.Gradient.linear(p - Offset(0, r), p + Offset(0, r), [Color.lerp(color, Colors.white, 0.25)!.withValues(alpha: k), Color.lerp(color, Colors.black, 0.15)!.withValues(alpha: k)]));
    canvas.drawPath(hex, strokePaint(const Color(0xFFFFF4E0), 1.4, 0.8 * k));
    drawGlyph(canvas, _terrainIcons[terrain]!, p - Offset(0, r * 0.4), r * 0.62, Colors.white.withValues(alpha: k));
    if (number == 0) continue;
    final hit = number == rolled ? bump(span(rf, 0.2, 0.7)) : 0.0;
    final tokenC = p + Offset(0, r * 0.2);
    if (hit > 0) drawGlow(canvas, tokenC, r * 1.3, const Color(0xFFFFD166), 0.8 * hit * k);
    canvas.drawCircle(tokenC, r * 0.32 * (1 + 0.25 * hit), fillPaint(const Color(0xFFFFF4E0), k));
    final red = number == 6 || number == 8;
    drawGlyph(canvas, '$number', tokenC, r * 0.34 * (1 + 0.25 * hit), (red ? const Color(0xFFC0392B) : const Color(0xFF3B2A1A)).withValues(alpha: k), weight: FontWeight.w900);
    // Resource cubes flying off to the bank.
    final fly = span(rf, 0.3, 0.75);
    if (number == rolled && fly > 0 && fly < 1) {
      final bank = Offset(w - u * 0.3, u * 0.42);
      final q = Offset.lerp(tokenC, bank, easeInOutSine(fly))! - Offset(0, bump(fly) * u * 0.25);
      canvas.save();
      canvas.translate(q.dx, q.dy);
      canvas.rotate(fly * tau);
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: r * 0.32, height: r * 0.32), fillPaint(color, (1 - fly * 0.6) * t));
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: r * 0.32, height: r * 0.32), strokePaint(Colors.white, 1, 0.8 * (1 - fly * 0.6) * t));
      canvas.restore();
    }
    // The robber, idling on the desert.
  }
  final desert = cells.firstWhere((cell) => cell.$2 == 'desert').$1;
  final bob = wave(ph, 0, 3) * 1.5;
  final robber = desert + Offset(0, r * 0.15 + bob);
  canvas.drawOval(Rect.fromCenter(center: robber + Offset(0, r * 0.32), width: r * 0.55, height: r * 0.16), fillPaint(Colors.black, 0.35 * t));
  canvas.drawPath(Path()
    ..moveTo(robber.dx - r * 0.2, robber.dy + r * 0.3)
    ..lineTo(robber.dx + r * 0.2, robber.dy + r * 0.3)
    ..lineTo(robber.dx + r * 0.1, robber.dy - r * 0.15)
    ..lineTo(robber.dx - r * 0.1, robber.dy - r * 0.15)
    ..close(), fillPaint(const Color(0xFF2B2B2B), t));
  canvas.drawCircle(robber - Offset(0, r * 0.25), r * 0.14, fillPaint(const Color(0xFF2B2B2B), t));

  // The dice for this roll, tumbling in then settling, in the corner.
  const pairs = {6: (2, 4), 8: (3, 5), 5: (1, 4)};
  final (a, b) = pairs[rolled]!;
  final settle = span(rf, 0, 0.2);
  for (var d = 0; d < 2; d++) {
    final face = settle < 1 ? 1 + (hash01(rollIdx * 7 + d + (settle * 8).floor()) * 6).floor() : (d == 0 ? a : b);
    final base = Offset(w - u * (0.42 - d * 0.22), u * 0.2);
    drawDie(canvas, base - Offset(0, bump(settle) * u * 0.12), u * 0.13, face, angle: (1 - easeOutCubic(settle)) * tau * (d == 0 ? 1 : -1) + (d == 0 ? -0.15 : 0.12), alpha: t);
  }
}

void _cardFace(Canvas canvas, RRect card, String rank, String suit, bool red, double alpha) {
  canvas.drawRRect(card.shift(const Offset(1.5, 2.5)), fillPaint(Colors.black, 0.3 * alpha));
  canvas.drawRRect(card, fillPaint(const Color(0xFFFFFDF7), alpha));
  canvas.drawRRect(card.deflate(2), strokePaint(const Color(0xFFE8E2D4), 1, alpha));
  final color = (red ? const Color(0xFFD62839) : const Color(0xFF1D1D1D)).withValues(alpha: alpha);
  final cw = card.width, ch = card.height;
  drawGlyph(canvas, rank, Offset(card.left + cw * 0.18, card.top + ch * 0.13), cw * 0.24, color, weight: FontWeight.w800);
  drawGlyph(canvas, suit, Offset(card.left + cw * 0.18, card.top + ch * 0.28), cw * 0.2, color);
  drawGlyph(canvas, suit, card.center + Offset(0, ch * 0.04), cw * 0.5, color);
}

void _cardBack(Canvas canvas, RRect card, double alpha) {
  canvas.drawRRect(card.shift(const Offset(1.5, 2.5)), fillPaint(Colors.black, 0.3 * alpha));
  canvas.drawRRect(card, fillPaint(const Color(0xFFFFFDF7), alpha));
  final inner = card.deflate(card.width * 0.08);
  canvas.drawRRect(inner, fillPaint(const Color(0xFFB3202F), alpha));
  canvas.save();
  canvas.clipRRect(inner);
  final lattice = strokePaint(const Color(0xFFFFD6DA), 1, 0.5 * alpha);
  final step = card.width * 0.18;
  for (var d = -card.height; d < card.width + card.height; d += step) {
    canvas.drawLine(Offset(inner.left + d, inner.top), Offset(inner.left + d - card.height, inner.bottom), lattice);
    canvas.drawLine(Offset(inner.left + d - card.height, inner.top), Offset(inner.left + d, inner.bottom), lattice);
  }
  canvas.restore();
}

/// A card table: a hand of five is dealt off the deck one card at a time
/// (each flipping face up in flight), fanned, glinting — then swept back
/// and dealt again. Suits shimmer in the felt.
void cardsMotif(Canvas canvas, Size s, double t, double ph) {
  final w = s.width, h = s.height, u = unitOf(s);
  const suits = ['♠', '♥', '♦', '♣'];
  final step = u / 3.2;
  var i = 0;
  for (var y = 0.0; y < h + step; y += step) {
    for (var x = (i.isEven ? 0.0 : step / 2); x < w + step; x += step) {
      final suit = suits[i % 4];
      final shimmer = 0.55 + 0.45 * wave(ph, (x / w + y / h) * 0.5, 2);
      drawGlyph(canvas, suit, Offset(x, y), step * 0.32, (suit == '♥' || suit == '♦' ? const Color(0xFFFFB4B4) : Colors.white).withValues(alpha: 0.2 * t * shimmer));
      i++;
    }
    i++;
  }

  final cw = u * 0.3, ch = u * 0.42;
  final zh = heroHeight(s);
  final deck = Offset(w - cw * 0.75, zh - ch * 0.62);
  RRect cardAt(Offset c) => RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: cw, height: ch), Radius.circular(cw * 0.1));
  for (var k = 2; k >= 0; k--) {
    canvas.save();
    canvas.translate(deck.dx + k * 1.5, deck.dy - k * 1.5);
    canvas.rotate(0.25);
    _cardBack(canvas, cardAt(Offset.zero), t);
    canvas.restore();
  }

  const hand = [('A', '♠', false), ('K', '♥', true), ('Q', '♦', true), ('J', '♣', false), ('10', '♥', true)];
  final pivot = Offset(w * 0.7, zh + u * 0.55);
  final radius = u * 0.95;
  final glint = span(ph, 0.5, 0.62);
  for (var j = 0; j < hand.length; j++) {
    final dealt = span(ph, 0.04 + j * 0.065, 0.13 + j * 0.065);
    final collect = span(ph, 0.86, 0.95);
    if (dealt == 0 || collect >= 1) continue;
    final slotA = -0.42 + j * 0.21 + wave(ph, j * 0.1, 4) * 0.02;
    final slot = pivot + Offset(math.sin(slotA), -math.cos(slotA)) * radius;
    var pos = Offset.lerp(deck, slot, easeOutCubic(dealt))!;
    var angle = lerpD(0.25, slotA, easeOutCubic(dealt));
    var flip = span(dealt, 0.35, 1);
    if (collect > 0) {
      pos = Offset.lerp(pos, deck, easeInCubic(collect))!;
      angle = lerpD(angle, 0.25, collect);
      flip = 1 - span(collect, 0, 0.6);
    }
    final sx = math.cos(math.pi * (1 - flip)); // −1 = back up, 1 = face up
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(angle);
    canvas.scale(sx.abs().clamp(0.02, 1.0), 1);
    final card = cardAt(Offset.zero);
    if (sx < 0) {
      _cardBack(canvas, card, t);
    } else {
      final (rank, suit, red) = hand[j];
      _cardFace(canvas, card, rank, suit, red, t);
      if (glint > 0 && glint < 1) {
        canvas.save();
        canvas.clipRRect(card);
        final gx = lerpD(-cw * 1.2, cw * 1.2, fract(glint * 1.0 + j * 0.08));
        canvas.drawRect(Rect.fromCenter(center: Offset(gx, 0), width: cw * 0.35, height: ch * 2), Paint()
          ..blendMode = BlendMode.plus
          ..shader = ui.Gradient.linear(Offset(gx - cw * 0.2, 0), Offset(gx + cw * 0.2, 0), [const Color(0x00FFFFFF), Colors.white.withValues(alpha: 0.7 * t), const Color(0x00FFFFFF)], const [0, 0.5, 1]));
        canvas.restore();
      }
    }
    canvas.restore();
  }
  if (glint > 0 && glint < 1) {
    for (var k = 0; k < 6; k++) {
      final p = Offset(w * (0.55 + 0.35 * hash01(k + 3)), h * (0.2 + 0.4 * hash01(k + 9)));
      drawSparkle(canvas, p, 5 * bump(span(glint, k * 0.08, k * 0.08 + 0.5)), fillPaint(const Color(0xFFFFF4C2), t));
    }
  }
}

// The regular icosahedron: 12 vertices, 20 faces — the d20.
final _icoVerts = () {
  final p = (1 + math.sqrt(5)) / 2;
  final raw = [
    [-1.0, p, 0.0], [1.0, p, 0.0], [-1.0, -p, 0.0], [1.0, -p, 0.0], //
    [0.0, -1.0, p], [0.0, 1.0, p], [0.0, -1.0, -p], [0.0, 1.0, -p], //
    [p, 0.0, -1.0], [p, 0.0, 1.0], [-p, 0.0, -1.0], [-p, 0.0, 1.0],
  ];
  return [
    for (final v in raw) [for (final c in v) c / math.sqrt(1 + p * p)],
  ];
}();
const _icoFaces = [
  [0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], //
  [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8], //
  [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], //
  [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1],
];

void _flame(Canvas canvas, Offset base, double size, double ph, double t, double seed) {
  Path tongue(double wid, double hgt, double sway) => Path()
    ..moveTo(base.dx - wid, base.dy)
    ..cubicTo(base.dx - wid * 1.05, base.dy - hgt * 0.45, base.dx + sway * 0.5 - wid * 0.25, base.dy - hgt * 0.72, base.dx + sway, base.dy - hgt)
    ..cubicTo(base.dx + sway * 0.5 + wid * 0.25, base.dy - hgt * 0.72, base.dx + wid * 1.05, base.dy - hgt * 0.45, base.dx + wid, base.dy)
    ..arcToPoint(Offset(base.dx - wid, base.dy), radius: Radius.circular(wid))
    ..close();
  for (final (scale, color, k) in const [(1.0, Color(0xFFE85D04), 0.0), (0.72, Color(0xFFFFA62B), 0.3), (0.45, Color(0xFFFFF3B0), 0.6)]) {
    final hgt = size * scale * (0.85 + 0.22 * _flicker(ph, seed + k));
    final sway = size * 0.16 * _flicker(ph, seed + k + 0.5);
    canvas.drawPath(tongue(size * 0.26 * scale, hgt, sway), Paint()
      ..blendMode = BlendMode.plus
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, size * 0.04)
      ..color = color.withValues(alpha: 0.9 * t));
  }
}

/// A dungeon wall: a torch flickering and shedding embers, fog creeping by,
/// and a shaded d20 spinning in 3D — with a critical-hit flash once a
/// loop when its 20 faces you.
void dungeonMotif(Canvas canvas, Size s, double t, double ph) {
  final w = s.width, h = s.height, u = unitOf(s);
  // Stone wall.
  final brickH = u * 0.13, brickW = brickH * 2.1;
  final mortar = strokePaint(Colors.black, 1.2, 0.35 * t);
  var r = 0;
  for (var y = 0.0; y < h; y += brickH, r++) {
    canvas.drawLine(Offset(w * 0.3, y), Offset(w, y), mortar);
    for (var x = w * 0.3 + (r.isOdd ? brickW / 2 : 0); x < w; x += brickW) {
      canvas.drawLine(Offset(x, y), Offset(x, y + brickH), mortar);
      canvas.drawRect(Rect.fromLTWH(x + 1, y + 1, brickW - 2, brickH - 2), fillPaint(Colors.white, 0.025 + 0.025 * hash01(x * 3 + y)));
    }
  }

  // Torch on the wall.
  final zh = heroHeight(s);
  final torch = Offset(w * 0.92, zh * 0.3);
  final flick = 0.85 + 0.15 * _flicker(ph, 0.2);
  drawGlow(canvas, torch - Offset(0, u * 0.1), u * 1.1 * flick, const Color(0xFFFF8C42), 0.42 * t * flick);
  canvas.drawRect(Rect.fromCenter(center: torch + Offset(0, u * 0.14), width: u * 0.035, height: u * 0.22), fillPaint(const Color(0xFF3B2416), t));
  canvas.drawPath(Path()
    ..moveTo(torch.dx - u * 0.06, torch.dy)
    ..lineTo(torch.dx + u * 0.06, torch.dy)
    ..lineTo(torch.dx + u * 0.035, torch.dy + u * 0.05)
    ..lineTo(torch.dx - u * 0.035, torch.dy + u * 0.05)
    ..close(), fillPaint(const Color(0xFF6B4F3A), t));
  _flame(canvas, torch, u * 0.22, ph, t, 0.3);
  for (var i = 0; i < 14; i++) {
    final life = fract(ph * (5 + i % 3) + hash01(i));
    final p = torch + Offset(wave(ph, hash01(i + 4), 3) * u * 0.05 + (hash01(i + 8) - 0.5) * u * 0.08, -u * 0.08 - life * u * 0.55);
    canvas.drawCircle(p, 1.4 * (1 - life) + 0.4, fillPaint(Color.lerp(const Color(0xFFFFF3B0), const Color(0xFFE85D04), life)!, (1 - life) * t));
  }

  // The d20.
  final dc = Offset(w * 0.72, zh * 0.62 + wave(ph, 0, 2) * u * 0.02);
  final R = math.min(u * 0.3, w * 0.17);
  final crit = loopWindow(ph, 0.46, 0.14);
  drawGlow(canvas, dc, R * 2.1, const Color(0xFF9D4EDD), 0.45 * t);
  final ax = ph * tau + 0.45, ay = ph * tau * 2;
  final pts = <List<double>>[];
  for (final v in _icoVerts) {
    final y1 = v[1] * math.cos(ax) - v[2] * math.sin(ax);
    final z1 = v[1] * math.sin(ax) + v[2] * math.cos(ax);
    final x2 = v[0] * math.cos(ay) + z1 * math.sin(ay);
    final z2 = -v[0] * math.sin(ay) + z1 * math.cos(ay);
    pts.add([x2, y1, z2]);
  }
  Offset proj(List<double> p) => dc + Offset(p[0], p[1]) * (R * t.clamp(0.3, 1.0));
  const light = [-0.45, -0.6, 0.66];
  var bestZ = -1.0;
  Offset? bestC;
  for (final f in _icoFaces) {
    final a = pts[f[0]], b = pts[f[1]], c = pts[f[2]];
    final e1 = [b[0] - a[0], b[1] - a[1], b[2] - a[2]], e2 = [c[0] - a[0], c[1] - a[1], c[2] - a[2]];
    var n = [e1[1] * e2[2] - e1[2] * e2[1], e1[2] * e2[0] - e1[0] * e2[2], e1[0] * e2[1] - e1[1] * e2[0]];
    final len = math.sqrt(n[0] * n[0] + n[1] * n[1] + n[2] * n[2]);
    n = [n[0] / len, n[1] / len, n[2] / len];
    final cen = [(a[0] + b[0] + c[0]) / 3, (a[1] + b[1] + c[1]) / 3, (a[2] + b[2] + c[2]) / 3];
    if (n[0] * cen[0] + n[1] * cen[1] + n[2] * cen[2] < 0) n = [-n[0], -n[1], -n[2]];
    if (n[2] <= 0) continue;
    final shade = 0.22 + 0.78 * math.max(0.0, n[0] * light[0] + n[1] * light[1] + n[2] * light[2]);
    final tri = Path()..addPolygon([proj(a), proj(b), proj(c)], true);
    canvas.drawPath(tri, fillPaint(Color.lerp(const Color(0xFF2E1065), const Color(0xFFC4B5FD), shade)!, t));
    canvas.drawPath(tri, strokePaint(const Color(0xFFE8C26B), 1.3, 0.9 * t));
    if (n[2] > bestZ) {
      bestZ = n[2];
      bestC = proj(cen);
    }
  }
  if (bestC != null && bestZ > 0.8) {
    drawGlyph(canvas, '20', bestC, R * 0.3, const Color(0xFFFFE8A3).withValues(alpha: t * span(bestZ, 0.8, 0.95)), weight: FontWeight.w900);
  }
  if (crit != null) {
    final k = bump(crit);
    canvas.drawCircle(dc, R * (1.1 + crit * 1.4), strokePaint(const Color(0xFFFFD166), 3 * (1 - crit) + 0.5, (1 - crit) * t));
    drawGlow(canvas, dc, R * 2.4, const Color(0xFFFFD166), 0.6 * k * t);
    for (var j = 0; j < 8; j++) {
      final a = j / 8 * tau + 0.3;
      drawSparkle(canvas, dc + Offset(math.cos(a), math.sin(a)) * R * (1.25 + crit * 0.9), 6 * k, fillPaint(const Color(0xFFFFF4C2), t));
    }
  }

  // Fog drifting low.
  for (var i = 0; i < 4; i++) {
    final x = fract(hash01(i + 2) + ph * (1 + i % 2)) * (w * 1.4) - w * 0.2;
    drawGlow(canvas, Offset(x, h * (0.82 + 0.1 * hash01(i + 6))), u * (0.5 + 0.2 * hash01(i)), const Color(0xFFD8C8E8), 0.1 * t);
  }
}

void _chipTop(Canvas canvas, Offset c, double rx, Color color, double alpha, [double spin = 0]) {
  final rect = Rect.fromCenter(center: c, width: rx * 2, height: rx * 0.7);
  canvas.drawOval(rect.shift(Offset(0, rx * 0.16)), fillPaint(Color.lerp(color, Colors.black, 0.35)!, alpha));
  canvas.drawOval(rect, fillPaint(color, alpha));
  final stripe = strokePaint(color == const Color(0xFFF1FAEE) ? const Color(0xFFE63946) : Colors.white, rx * 0.16, 0.9 * alpha);
  for (var j = 0; j < 6; j++) {
    canvas.drawArc(rect.deflate(rx * 0.1), j * math.pi / 3 + spin, math.pi / 10, false, stripe);
  }
  canvas.drawOval(rect.deflate(rx * 0.45), strokePaint(Colors.white, 1, 0.5 * alpha));
}

/// A roulette wheel spinning at the edge of the card — the ball rides the
/// track, slows, rattles down into a pocket and rides it round — with
/// stacks of chips and one chip flipping onto a stack each loop.
void casinoMotif(Canvas canvas, Size s, double t, double ph) {
  final w = s.width, u = unitOf(s);
  final zh = heroHeight(s);
  final c = Offset(w * 0.86, zh * 0.52);
  final R = math.min(u * 0.55, w * 0.34) * (0.7 + 0.3 * t);
  const chipColors = [Color(0xFF1D1D1D), Color(0xFFE63946), Color(0xFF2B59C3), Color(0xFF2A9D8F), Color(0xFFF1FAEE)];

  // Chip stacks beside the wheel.
  final stackBase = Offset(c.dx - R - u * 0.16, zh * 0.9);
  for (var st = 0; st < 2; st++) {
    final b = stackBase + Offset(st * u * 0.26, -st * u * 0.04);
    final count = 4 + st * 2;
    for (var k = 0; k < count; k++) {
      _chipTop(canvas, b - Offset(0, k * u * 0.035), u * 0.1, chipColors[(st * 2 + k) % 5], t);
    }
  }
  final toss = loopWindow(ph, 0.2, 0.18);
  if (toss != null) {
    final from = Offset(w * 0.45, zh + 30), to = stackBase - Offset(0, 4 * u * 0.035 + u * 0.03);
    final p = Offset.lerp(from, to, easeOutCubic(toss))! - Offset(0, bump(toss) * u * 0.5);
    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.scale(1, math.cos(toss * tau * 2).abs().clamp(0.2, 1.0));
    _chipTop(canvas, Offset.zero, u * 0.1, chipColors[1], t);
    canvas.restore();
  }

  // The wheel.
  final wheelA = ph * tau * 2;
  canvas.drawCircle(c + Offset(0, R * 0.06), R, fillPaint(Colors.black, 0.4 * t));
  canvas.drawCircle(c, R, Paint()..shader = ui.Gradient.radial(c, R, [const Color(0xFF5A2E0E).withValues(alpha: t), const Color(0xFF9A5523).withValues(alpha: t), const Color(0xFF3B1A06).withValues(alpha: t)], const [0.72, 0.9, 1]));
  canvas.drawCircle(c, R * 0.86, fillPaint(const Color(0xFF1C0F08), t));
  const n = 37;
  final r1 = R * 0.6, r2 = R * 0.76;
  final outer = Rect.fromCircle(center: c, radius: r2), inner = Rect.fromCircle(center: c, radius: r1);
  for (var k = 0; k < n; k++) {
    final a0 = wheelA + k * tau / n;
    final color = k == 0 ? const Color(0xFF1B8A3A) : (k.isOdd ? const Color(0xFFC1121F) : const Color(0xFF151515));
    canvas.drawPath(Path()
      ..arcTo(outer, a0, tau / n, true)
      ..arcTo(inner, a0 + tau / n, -tau / n, false)
      ..close(), fillPaint(color, t));
    canvas.drawLine(c + Offset(math.cos(a0), math.sin(a0)) * r1, c + Offset(math.cos(a0), math.sin(a0)) * r2, strokePaint(const Color(0xFFE8C26B), 0.8, 0.8 * t));
  }
  canvas.drawCircle(c, r1, Paint()..shader = ui.Gradient.radial(c - Offset(r1 * 0.3, r1 * 0.3), r1 * 1.3, [const Color(0xFFE8C26B).withValues(alpha: t), const Color(0xFF8B5A1E).withValues(alpha: t)]));
  for (var k = 0; k < 4; k++) {
    final a = wheelA + k * math.pi / 2;
    canvas.drawLine(c, c + Offset(math.cos(a), math.sin(a)) * r1 * 0.62, strokePaint(const Color(0xFFFFE8A3), R * 0.045, t));
  }
  canvas.drawCircle(c, R * 0.09, Paint()..shader = ui.Gradient.radial(c - Offset(R * 0.03, R * 0.03), R * 0.1, [Colors.white.withValues(alpha: t), const Color(0xFFE8C26B).withValues(alpha: t)]));

  // The ball: rides the track, spirals in, settles and rides its pocket;
  // it fades out at the end of the loop as the croupier picks it up.
  const launchEnd = 0.6, settleAt = 0.76;
  final seg = tau / n;
  double trackAngle(double p) {
    final x = p / launchEnd;
    return 0.6 - tau * 4.2 * (x - 0.32 * x * x);
  }
  double wheelAt(double p) => p * tau * 2;
  final natural = trackAngle(launchEnd) - 0.8;
  final pocket = ((natural - wheelAt(settleAt)) / seg - 0.5).roundToDouble();
  double lockAngle(double p) => wheelAt(p) + (pocket + 0.5) * seg;
  final rTrack = R * 0.81, rPocket = R * 0.68;
  double angle, radius;
  if (ph < launchEnd) {
    angle = trackAngle(ph);
    radius = rTrack;
  } else if (ph < settleAt) {
    final k = span(ph, launchEnd, settleAt);
    angle = lerpD(trackAngle(launchEnd), lockAngle(settleAt), easeOutCubic(k));
    radius = lerpD(rTrack, rPocket, easeInCubic(k)) + (math.sin(k * math.pi * 4)).abs() * (1 - k) * R * 0.06;
  } else {
    angle = lockAngle(ph);
    radius = rPocket;
  }
  final ballA = t * span(ph, 0, 0.04) * (1 - span(ph, 0.94, 1));
  final ball = c + Offset(math.cos(angle), math.sin(angle)) * radius;
  canvas.drawCircle(ball + const Offset(1, 1.5), R * 0.05, fillPaint(Colors.black, 0.4 * ballA));
  canvas.drawCircle(ball, R * 0.05, Paint()..shader = ui.Gradient.radial(ball - Offset(R * 0.015, R * 0.015), R * 0.06, [Colors.white.withValues(alpha: ballA), const Color(0xFFB8B8B8).withValues(alpha: ballA)]));

  // Lacquer sheen.
  canvas.drawCircle(c - Offset(R * 0.3, R * 0.35), R * 0.7, Paint()
    ..blendMode = BlendMode.plus
    ..shader = ui.Gradient.radial(c - Offset(R * 0.3, R * 0.35), R * 0.7, [Colors.white.withValues(alpha: 0.12 * t), const Color(0x00FFFFFF)]));
}

// ============================== Sport ==============================

void _football(Canvas canvas, Offset c, double r, double spin, double alpha) {
  canvas.drawCircle(c, r, Paint()..shader = ui.Gradient.radial(c - Offset(r * 0.35, r * 0.35), r * 1.3, [Colors.white.withValues(alpha: alpha), const Color(0xFFD6D6D6).withValues(alpha: alpha)]));
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.clipPath(Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: r)));
  canvas.rotate(spin);
  final patch = fillPaint(const Color(0xFF1D1D1D), alpha);
  Path penta(Offset o, double rr) {
    final p = Path();
    for (var i = 0; i < 5; i++) {
      final a = -math.pi / 2 + i * tau / 5;
      final q = o + Offset(math.cos(a), math.sin(a)) * rr;
      i == 0 ? p.moveTo(q.dx, q.dy) : p.lineTo(q.dx, q.dy);
    }
    return p..close();
  }

  canvas.drawPath(penta(Offset.zero, r * 0.38), patch);
  for (var i = 0; i < 5; i++) {
    final a = -math.pi / 2 + i * tau / 5 + math.pi / 5;
    canvas.drawPath(penta(Offset(math.cos(a), math.sin(a)) * r * 1.0, r * 0.36), patch);
  }
  canvas.restore();
  canvas.drawCircle(c, r, strokePaint(Colors.black, 0.6, 0.4 * alpha));
}

/// A football pitch: the red team strings four passes together and buries
/// a shot — the net ripples, the goal flares — then the ball is brought
/// back for kick-off.
void pitchMotif(Canvas canvas, Size s, double t, double ph) {
  final w = s.width, h = s.height, u = unitOf(s);
  final band = w / 9;
  for (var i = 0; i < 9; i += 2) {
    canvas.drawRect(Rect.fromLTWH(i * band, 0, band, h), fillPaint(Colors.white, 0.05));
  }
  final line = strokePaint(Colors.white, 2, 0.6 * t);
  final field = Rect.fromLTWH(10, 10, w - 20, heroHeight(s) - 20);
  canvas.drawRect(field, line);
  final midX = field.left + field.width * 0.42;
  canvas.drawLine(Offset(midX, field.top), Offset(midX, field.bottom), line);
  canvas.drawCircle(Offset(midX, field.center.dy), field.height * 0.24, line);
  final box = Rect.fromLTWH(field.right - field.width * 0.15, field.center.dy - field.height * 0.3, field.width * 0.15, field.height * 0.6);
  canvas.drawRect(box, line);

  // The goal: a net on the right edge that ripples when the ball hits it.
  final goalH = field.height * 0.34, depth = u * 0.12;
  final goal = Rect.fromLTWH(field.right - 2, field.center.dy - goalH / 2, depth, goalH);
  final celebrate = span(ph, 0.56, 0.86);
  final ripple = bump(celebrate) * (1 - celebrate);
  final net = strokePaint(Colors.white, 0.8, 0.5 * t);
  for (var i = 0; i <= 6; i++) {
    final y = goal.top + goal.height * i / 6;
    final dx = math.sin(i * 1.3 + celebrate * 30) * ripple * depth * 0.5;
    canvas.drawLine(Offset(goal.left, y), Offset(goal.right + dx, y), net);
  }
  for (var i = 0; i <= 3; i++) {
    final x = goal.left + goal.width * i / 3;
    canvas.drawLine(Offset(x + ripple * depth * 0.3 * (i / 3), goal.top), Offset(x + ripple * depth * 0.3 * (i / 3), goal.bottom), net);
  }
  canvas.drawLine(goal.topLeft, goal.bottomLeft, strokePaint(Colors.white, 3, t));
  if (celebrate > 0 && celebrate < 1) drawGlow(canvas, goal.center, goalH * 1.2, Colors.white, 0.55 * ripple * 3 * t);

  // Players: red attackers, blue defenders, idling on the spot.
  Offset fieldAt(double fx, double fy) => Offset(field.left + field.width * fx, field.top + field.height * fy);
  final reds = [fieldAt(0.5, 0.3), fieldAt(0.62, 0.72), fieldAt(0.73, 0.28), fieldAt(0.8, 0.62)];
  final blues = [fieldAt(0.86, 0.4), fieldAt(0.7, 0.5), fieldAt(0.9, 0.7), fieldAt(0.58, 0.55)];
  void player(Offset p, Color color, int i) {
    final q = p + Offset(wave(ph, i * 0.17, 3), wave(ph, i * 0.29 + 0.2, 3)) * u * 0.02;
    canvas.drawOval(Rect.fromCenter(center: q + Offset(0, u * 0.045), width: u * 0.08, height: u * 0.025), fillPaint(Colors.black, 0.3 * t));
    canvas.drawCircle(q, u * 0.036, fillPaint(color, t));
    canvas.drawCircle(q, u * 0.036, strokePaint(Colors.white, 1.4, t));
  }

  for (final (i, p) in blues.indexed) {
    player(p, const Color(0xFF3A86FF), i + 10);
  }
  for (final (i, p) in reds.indexed) {
    player(p, const Color(0xFFE63946), i);
  }

  // The ball: four passes, the shot, then back to the first player.
  final shotTarget = Offset(goal.left + depth * 0.45, goal.center.dy + goalH * 0.12);
  final legs = [(reds[0], reds[1], 0.0, 0.13), (reds[1], reds[2], 0.15, 0.28), (reds[2], reds[3], 0.3, 0.43), (reds[3], shotTarget, 0.48, 0.56), (shotTarget, reds[0], 0.86, 1.0)];
  var ballPos = reds[0];
  for (final (a, b, start, end) in legs) {
    if (ph >= start) ballPos = Offset.lerp(a, b, easeInOutSine(span(ph, start, end)))!;
  }
  if (ph >= 0.56 && ph < 0.86) ballPos = shotTarget;
  final ballR = u * 0.045;
  canvas.drawOval(Rect.fromCenter(center: ballPos + Offset(0, ballR * 1.2), width: ballR * 2.2, height: ballR * 0.7), fillPaint(Colors.black, 0.3 * t));
  _football(canvas, ballPos, ballR, (ballPos.dx + ballPos.dy) / ballR, t);
}

void _basketball(Canvas canvas, Offset c, double r, double spin, double alpha) {
  canvas.drawCircle(c, r, Paint()..shader = ui.Gradient.radial(c - Offset(r * 0.35, r * 0.35), r * 1.3, [const Color(0xFFFFA45B).withValues(alpha: alpha), const Color(0xFFD8570B).withValues(alpha: alpha)]));
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.rotate(spin);
  final seam = strokePaint(const Color(0xFF3B1E0A), 1.3, 0.9 * alpha);
  canvas.drawLine(Offset(-r, 0), Offset(r, 0), seam);
  canvas.drawLine(Offset(0, -r), Offset(0, r), seam);
  canvas.drawArc(Rect.fromCircle(center: Offset(-r * 1.15, 0), radius: r), -0.95, 1.9, false, seam);
  canvas.drawArc(Rect.fromCircle(center: Offset(r * 1.15, 0), radius: r), math.pi - 0.95, 1.9, false, seam);
  canvas.restore();
}

/// A basketball court: dribble, dribble, jump shot — swish, the net
/// whips, +2 floats up — and the ball bounces back for the next one.
void parquetMotif(Canvas canvas, Size s, double t, double ph) {
  final w = s.width, h = s.height, u = unitOf(s);
  final plank = u * 0.14;
  for (var x = 0.0, i = 0; x < w; x += plank, i++) {
    canvas.drawRect(Rect.fromLTWH(x, 0, plank, h), fillPaint(hash01(i) > 0.5 ? Colors.white : Colors.black, 0.03 + hash01(i + 40) * 0.05));
    canvas.drawLine(Offset(x, 0), Offset(x, h), strokePaint(Colors.black, 1, 0.12));
  }
  final zh = heroHeight(s);
  final floorY = zh * 0.86;
  canvas.drawLine(Offset(w * 0.3, floorY), Offset(w, floorY), strokePaint(Colors.white, 2.2, 0.6 * t));
  canvas.drawArc(Rect.fromCircle(center: Offset(w, floorY), radius: u * 0.9), math.pi, math.pi * 0.5 * t, false, strokePaint(Colors.white, 2.2, 0.45 * t));

  // Hoop, side on.
  final boardX = w - u * 0.08;
  final rimY = zh * 0.36, rimW = u * 0.3;
  canvas.drawRect(Rect.fromLTWH(boardX, rimY - u * 0.34, u * 0.035, u * 0.42), fillPaint(Colors.white, 0.9 * t));
  canvas.drawRect(Rect.fromLTWH(boardX + u * 0.035, rimY - u * 0.05, u * 0.08, u * 0.025), fillPaint(const Color(0xFF9CA3AF), t));
  final rimL = Offset(boardX - rimW, rimY), rimR = Offset(boardX, rimY);
  final swish = span(ph, 0.7, 0.86);
  final whip = bump(swish) * (1 - swish * 0.5);
  final netPaint = strokePaint(Colors.white, 1, 0.75 * t);
  final netDepth = u * 0.22;
  for (var i = 0; i <= 4; i++) {
    final top = Offset.lerp(rimL, rimR, i / 4)!;
    final bottom = Offset.lerp(rimL + Offset(rimW * 0.18, netDepth), rimR + Offset(-rimW * 0.18, netDepth), i / 4)! + Offset(math.sin(i + swish * 25) * whip * u * 0.04, whip * u * 0.05);
    canvas.drawLine(top, bottom, netPaint);
  }
  for (var j = 1; j <= 3; j++) {
    final y = j / 3;
    canvas.drawLine(Offset.lerp(rimL, rimL + Offset(rimW * 0.18, netDepth), y)! + Offset(0, whip * u * 0.05 * y), Offset.lerp(rimR, rimR + Offset(-rimW * 0.18, netDepth), y)! + Offset(0, whip * u * 0.05 * y), netPaint);
  }

  final ballR = u * 0.075;
  final dribbleX = w * 0.6;
  final bounceH = zh * 0.3;
  Offset ball;
  if (ph < 0.48) {
    final b = ph / 0.48 * 2.5; // two and a half bounces: ends at the top of one
    ball = Offset(dribbleX + wave(ph, 0, 2) * u * 0.03, floorY - ballR - bounceH * math.sin(math.pi * b).abs());
  } else if (ph < 0.7) {
    final k = span(ph, 0.48, 0.7);
    final from = Offset(dribbleX, floorY - ballR - bounceH);
    final to = Offset(boardX - rimW / 2, rimY - ballR * 0.6);
    final arc = math.min(u * 0.55, math.min(from.dy, to.dy) - ballR * 1.6);
    ball = Offset.lerp(from, to, k)! - Offset(0, 4 * k * (1 - k) * arc);
  } else if (ph < 0.82) {
    final k = span(ph, 0.7, 0.82);
    ball = Offset(boardX - rimW / 2, lerpD(rimY - ballR * 0.6, floorY - ballR, easeInCubic(k)));
  } else {
    final k = span(ph, 0.82, 1);
    final x = lerpD(boardX - rimW / 2, dribbleX, easeInOutSine(k));
    ball = Offset(x, floorY - ballR - bounceH * 0.55 * math.sin(math.pi * k * 2).abs() * (1 - k));
  }
  final airborne = (floorY - ballR - ball.dy) / (zh * 0.6);
  canvas.drawOval(Rect.fromCenter(center: Offset(ball.dx, floorY), width: ballR * 2.4 * (1 - airborne * 0.5), height: ballR * 0.5), fillPaint(Colors.black, 0.3 * t));
  _basketball(canvas, ball, ballR, ball.dx / ballR, t);
  // The rim in front of the ball.
  canvas.drawLine(rimL, rimR, strokePaint(const Color(0xFFFF6B1A), u * 0.025, t));
  final plus2 = span(ph, 0.72, 0.92);
  if (plus2 > 0 && plus2 < 1) {
    drawGlyph(canvas, '+2', Offset(boardX - rimW * 0.5, rimY - u * 0.15 - plus2 * u * 0.3), u * 0.16, const Color(0xFFFFE066).withValues(alpha: bump(plus2) * t), weight: FontWeight.w900);
  }
}

/// A clay court seen from above: a rally across the net — the ball arcs
/// (its shadow on the clay), kicks up dust where it bounces, and the
/// players shuffle to meet it.
void clayMotif(Canvas canvas, Size s, double t, double ph) {
  final w = s.width, h = s.height, u = unitOf(s);
  for (var i = 0; i < 170; i++) {
    canvas.drawCircle(Offset(hash01(i) * w, hash01(i + 300) * h), hash01(i + 600) * 1.4, fillPaint(hash01(i + 900) > 0.5 ? Colors.white : Colors.black, 0.08));
  }
  final court = Rect.fromLTWH(w * 0.45, 12, w * 0.55 - 12, heroHeight(s) - 24);
  final line = strokePaint(Colors.white, 2.2, 0.8 * t);
  canvas.drawRect(court, line);
  final alley = court.height * 0.1;
  canvas.drawLine(Offset(court.left, court.top + alley), Offset(court.right, court.top + alley), line);
  canvas.drawLine(Offset(court.left, court.bottom - alley), Offset(court.right, court.bottom - alley), line);
  final netX = court.center.dx;
  for (final sx in [court.left + court.width * 0.22, court.right - court.width * 0.22]) {
    canvas.drawLine(Offset(sx, court.top + alley), Offset(sx, court.bottom - alley), line);
  }
  canvas.drawLine(Offset(court.left + court.width * 0.22, court.center.dy), Offset(court.right - court.width * 0.22, court.center.dy), line);
  canvas.drawLine(Offset(netX, court.top - 6), Offset(netX, court.bottom + 6), strokePaint(const Color(0xFF1D1D1D), 3, 0.7 * t));
  canvas.drawLine(Offset(netX, court.top - 6), Offset(netX, court.bottom + 6), strokePaint(Colors.white, 1, 0.9 * t));

  // Four shots a loop; hitter alternates sides.
  double hitY(int k) => court.top + alley + (court.height - alley * 2) * (0.2 + 0.6 * hash01(k % 4 + 3));
  Offset hitter(int k) => Offset(k.isEven ? court.left + court.width * 0.06 : court.right - court.width * 0.06, hitY(k));
  final shot = (ph * 4).floor() % 4;
  final f = fract(ph * 4);
  final from = hitter(shot), to = hitter(shot + 1);
  final ground = Offset.lerp(from, to, f)!;
  // Struck at racket height, it arcs over the net, bounces, and rises back
  // to racket height as the next hit meets it.
  const bounceAt = 0.68;
  final racketH = u * 0.12;
  final x = f / bounceAt;
  final height = f < bounceAt ? (1 - x) * racketH + 4 * x * (1 - x) * u * 0.3 : math.sin(math.pi / 2 * span(f, bounceAt, 1)) * racketH;
  final bouncePt = Offset.lerp(from, to, bounceAt)!;
  final dust = span(f, bounceAt, bounceAt + 0.2);
  if (dust > 0 && dust < 1) {
    canvas.drawOval(Rect.fromCenter(center: bouncePt, width: u * (0.05 + dust * 0.12), height: u * (0.03 + dust * 0.06)), fillPaint(const Color(0xFFF4C7A1), 0.6 * (1 - dust) * t));
  }

  // Each player glides from where they last hit to where they'll hit
  // next (their shots are every other one), racket up around each hit.
  final clock = ph * 4;
  for (var side = 0; side < 2; side++) {
    final last = side + 2 * ((clock - side) / 2).floor();
    final since = clock - last; // 0…2
    final p = Offset(hitter(side).dx, lerpD(hitY(last), hitY(last + 2), easeInOutSine(since / 2)));
    final swing = since < 0.2 ? 1 - since / 0.2 : (since > 1.8 ? (since - 1.8) / 0.2 : 0.0);
    canvas.drawOval(Rect.fromCenter(center: p + Offset(0, u * 0.05), width: u * 0.09, height: u * 0.03), fillPaint(Colors.black, 0.3 * t));
    canvas.drawCircle(p, u * 0.04, fillPaint(side == 0 ? const Color(0xFF3A86FF) : const Color(0xFFFFFFFF), t));
    final dir = side == 0 ? 1.0 : -1.0;
    final racketA = 0.9 - swing * 1.5;
    final rc = p + Offset(math.cos(racketA) * dir, -math.sin(racketA)) * u * 0.085;
    canvas.drawLine(p, rc, strokePaint(const Color(0xFF1D1D1D), 2, t));
    canvas.drawOval(Rect.fromCenter(center: rc, width: u * 0.05, height: u * 0.07), strokePaint(const Color(0xFF1D1D1D), 1.6, t));
  }

  canvas.drawOval(Rect.fromCenter(center: ground, width: u * 0.05, height: u * 0.025), fillPaint(Colors.black, 0.35 * t));
  final ball = ground - Offset(0, height);
  canvas.drawCircle(ball, u * 0.028, fillPaint(const Color(0xFFD7F542), t));
  canvas.drawArc(Rect.fromCircle(center: ball - Offset(u * 0.022, 0), radius: u * 0.02), -0.9, 1.8, false, strokePaint(Colors.white, 1, t));
}

// ============================== Animées ==============================

/// Northern lights: rippling curtains made of vertical rays over a
/// mountain lake that mirrors them, under a twinkling sky.
void auroraMotif(Canvas canvas, Size s, double t, double ph) {
  final w = s.width, h = s.height, u = unitOf(s);
  final zh = heroHeight(s);
  for (var i = 0; i < 60; i++) {
    final p = Offset(hash01(i) * w, hash01(i + 40) * zh * 0.7);
    canvas.drawCircle(p, 0.4 + hash01(i + 80) * 0.9, fillPaint(Colors.white, (0.25 + 0.6 * wave01(ph, hash01(i + 120), 4 + i % 5)) * t));
  }
  final shooting = loopWindow(ph, 0.3, 0.06);
  if (shooting != null) {
    final head = Offset(lerpD(w * 0.95, w * 0.5, easeOutCubic(shooting)), lerpD(zh * 0.05, zh * 0.25, easeOutCubic(shooting)));
    final tail = head + const Offset(0.88, -0.45) * (u * 0.3 * bump(shooting));
    canvas.drawLine(tail, head, Paint()
      ..strokeWidth = 1.5
      ..shader = ui.Gradient.linear(tail, head, [const Color(0x00FFFFFF), Colors.white.withValues(alpha: bump(shooting) * t)]));
  }

  final lakeY = zh * 0.8;
  const ribbons = [(Color(0xFF34D399), 0.0, 0.42, 1), (Color(0xFF22D3EE), 0.33, 0.52, 2), (Color(0xFFC084FC), 0.66, 0.62, 1)];
  for (final (color, offset, yBase, speed) in ribbons) {
    double baseAt(double x) {
      final f = x / w;
      return zh * yBase + math.sin((f * 1.4 + ph * speed + offset) * tau) * zh * 0.09 + math.sin((f * 4 - ph * speed * 2 + offset) * tau) * zh * 0.025;
    }

    // Soft body of the curtain.
    final top = <Offset>[], bottom = <Offset>[];
    for (var x = -8.0; x <= w + 8; x += 8) {
      final y = baseAt(x);
      top.add(Offset(x, y - zh * (0.26 + 0.07 * math.sin((x / w * 3 + ph + offset) * tau))));
      bottom.add(Offset(x, y));
    }
    final yTop = zh * (yBase - 0.36), yBot = zh * (yBase + 0.06);
    canvas.drawPath(Path()..addPolygon([...top, ...bottom.reversed], true), Paint()
      ..blendMode = BlendMode.plus
      ..shader = ui.Gradient.linear(Offset(0, yTop), Offset(0, yBot), [color.withValues(alpha: 0), color.withValues(alpha: 0.35 * t), color.withValues(alpha: 0)], const [0, 0.82, 1]));
    // Rays: thin vertical streaks whose brightness ripples along it.
    for (var x = 0.0; x <= w; x += 3) {
      final y = baseAt(x);
      final ray = math.max(0.0, math.sin(x * 0.11 + ph * tau * 3 * speed + offset * 9) * 0.6 + loopNoise(ph, x * 0.013 + offset) * 0.5);
      if (ray <= 0.05) continue;
      final len = zh * (0.16 + 0.14 * ray);
      canvas.drawLine(Offset(x, y - len), Offset(x, y), Paint()
        ..blendMode = BlendMode.plus
        ..strokeWidth = 1.6
        ..color = color.withValues(alpha: 0.22 * ray * t));
      canvas.drawLine(Offset(x, y - len * 0.25), Offset(x, y), Paint()
        ..blendMode = BlendMode.plus
        ..strokeWidth = 1.6
        ..color = Color.lerp(color, Colors.white, 0.4)!.withValues(alpha: 0.3 * ray * t));
    }
  }

  // Mountains and the lake.
  final mountains = Path()..moveTo(0, lakeY);
  for (var x = 0.0; x <= w + 6; x += 6) {
    final f = x / w;
    mountains.lineTo(x, lakeY - u * (0.18 + 0.12 * math.sin(f * tau * 2.3 + 0.6).abs() + 0.06 * math.sin(f * tau * 7)));
  }
  mountains
    ..lineTo(w + 6, lakeY)
    ..close();
  canvas.drawPath(mountains, fillPaint(const Color(0xFF020617), 0.95));
  canvas.drawRect(Rect.fromLTWH(0, lakeY, w, h - lakeY), fillPaint(const Color(0xFF041128), 0.95));
  for (var i = 0; i < 18; i++) {
    final y = lakeY + 3 + i * (h - lakeY) / 18;
    final x = fract(hash01(i + 7) + ph * (1 + i % 2)) * w;
    final color = ribbons[i % 3].$1;
    canvas.drawLine(Offset(x, y), Offset(x + u * (0.15 + 0.2 * hash01(i)), y), Paint()
      ..blendMode = BlendMode.plus
      ..strokeWidth = 1.2
      ..color = color.withValues(alpha: 0.35 * (1 - i / 18) * t));
  }
}

/// Hyperspace: stars stretching into streaks from a vanishing point, a
/// jump to light speed every loop (streaks lengthen, the view flares
/// white), then back to cruising.
void warpMotif(Canvas canvas, Size s, double t, double ph) {
  final w = s.width, h = s.height, u = unitOf(s);
  final c = Offset(w * 0.74, heroHeight(s) * 0.5);
  final reach = math.sqrt(w * w + h * h);
  // Distance travelled: cruising at 2 laps a loop plus one extra lap
  // crammed into the jump — the integral of the speed, so stars stay put
  // between frames and the loop still wraps (3 whole laps).
  final x = span(ph, 0.42, 0.58);
  final jump = x * x * (3 - 2 * x);
  final travel = ph * 2 + jump;
  final speed = 2 + (x > 0 && x < 1 ? 6 * x * (1 - x) / 0.16 : 0);
  drawGlow(canvas, c, u * (0.45 + 0.04 * speed), Color.lerp(const Color(0xFF7DD3FC), const Color(0xFFC4B5FD), wave01(ph, 0, 1))!, 0.45 * t);
  for (var i = 0; i < 170; i++) {
    final a = hash01(i) * tau;
    final dir = Offset(math.cos(a), math.sin(a));
    final z = fract(hash01(i + 300) + travel * (1 + i % 2));
    final head = math.pow(z, 2.4) * reach;
    final tail = math.pow(math.max(0.0, z - 0.035 * speed), 2.4) * reach;
    canvas.drawLine(c + dir * tail.toDouble(), c + dir * head.toDouble(), Paint()
      ..strokeWidth = 0.5 + z * 2.4
      ..strokeCap = StrokeCap.round
      ..color = Color.lerp(const Color(0xFF93C5FD), Colors.white, z)!.withValues(alpha: (0.2 + 0.8 * z) * t));
  }
  final flash = bump(span(ph, 0.47, 0.62));
  if (flash > 0) {
    canvas.drawRect(Offset.zero & s, Paint()
      ..blendMode = BlendMode.plus
      ..shader = ui.Gradient.radial(c, reach * 0.6, [Colors.white.withValues(alpha: 0.6 * flash * t), const Color(0x00FFFFFF)]));
  }
}

const _matrixChars = '01<>+=#*/%\$&@ABCDEFXZ';
final _matrixCache = <String, TextPainter>{};

TextPainter _matrixGlyph(String ch, int level) => _matrixCache.putIfAbsent('$ch$level', () {
      const colors = [Color(0xFFE6FFEE), Color(0xFF4ADE80), Color(0xB322C55E), Color(0x5515803D)];
      return TextPainter(
        text: TextSpan(
          text: ch,
          style: TextStyle(fontSize: 12, height: 1, color: colors[level], fontWeight: FontWeight.w700, fontFamily: 'monospace'),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    });

/// Digital rain: columns of glyphs falling at their own pace, each led by
/// a glowing head, the glyphs behind it mutating as they fade.
void matrixMotif(Canvas canvas, Size s, double t, double ph) {
  final w = s.width, h = s.height;
  const cell = 14.0;
  final rows = (h / cell).ceil();
  var col = 0;
  for (var x = w * 0.28; x < w; x += cell, col++) {
    final speed = 1 + (hash01(col) * 3).floor();
    final trail = 6 + (hash01(col + 50) * 9).floor();
    final span_ = rows + trail;
    final head = ((fract(hash01(col + 100) + ph * speed)) * span_).floor();
    final seed = (hash01(col + 150) * 97).floor();
    for (var k = 0; k < trail; k++) {
      final row = head - k;
      if (row < 0 || row >= rows) continue;
      if (t < 1 && hash01(col * 31 + k * 17) > t) continue;
      final ch = _matrixChars[(seed + row * 7 + (ph * speed * 24).floor() * (k + 1)) % _matrixChars.length];
      final level = k == 0 ? 0 : (k < trail * 0.3 ? 1 : (k < trail * 0.65 ? 2 : 3));
      final g = _matrixGlyph(ch, level);
      final p = Offset(x + (cell - g.width) / 2, row * cell);
      if (k == 0) drawGlow(canvas, p + Offset(g.width / 2, g.height / 2), cell * 1.1, const Color(0xFF4ADE80), 0.6 * t);
      g.paint(canvas, p);
    }
  }
}

/// A lava lamp: molten blobs rising and sinking, merging and splitting —
/// soft blobs passed through an alpha threshold, the classic "gooey"
/// trick — with glossy highlights and tiny bubbles.
void lavaMotif(Canvas canvas, Size s, double t, double ph) {
  final w = s.width, h = s.height, u = unitOf(s);
  drawGlow(canvas, Offset(w * 0.75, h * 0.62), u * 1.3, const Color(0xFFFF5400), 0.4 * t);
  final blobs = <(Offset, double, double)>[];
  for (var i = 0; i < 8; i++) {
    final cyc = 1 + (hash01(i + 4) * 2).floor();
    final roam = math.min(h, heroHeight(s) * 1.3);
    final y = roam * (0.5 + 0.5 * wave(ph, hash01(i + 9), cyc));
    final x = w * (0.55 + 0.38 * hash01(i + 13)) + wave(ph, hash01(i + 17), 1) * u * 0.12;
    final r = u * (0.11 + 0.08 * hash01(i + 21)) * (1 + 0.12 * wave(ph, hash01(i + 25), 2));
    final stretch = 1 + 0.25 * math.cos((ph * cyc + hash01(i + 9)) * tau).abs(); // elongate while moving fastest
    blobs.add((Offset(x, y), r, stretch));
  }
  final rect = Offset.zero & s;
  canvas.saveLayer(rect, Paint()
    ..colorFilter = const ColorFilter.matrix(<double>[
      1, 0, 0, 0, 0, //
      0, 1, 0, 0, 0, //
      0, 0, 1, 0, 0, //
      0, 0, 0, 24, -11 * 255,
    ]));
  for (final (c, r, stretch) in blobs) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(1 / math.sqrt(stretch), stretch);
    canvas.drawCircle(Offset.zero, r * 1.7, Paint()..shader = ui.Gradient.radial(Offset.zero, r * 1.7, [const Color(0xFFFFD166).withValues(alpha: t), const Color(0xFFFF7B00).withValues(alpha: 0.9 * t), const Color(0x00FF3D00)], const [0, 0.45, 1]));
    canvas.restore();
  }
  canvas.restore();
  for (final (c, r, stretch) in blobs) {
    final hl = c + Offset(-r * 0.35, -r * 0.45 * stretch);
    canvas.drawOval(Rect.fromCenter(center: hl, width: r * 0.5, height: r * 0.28), fillPaint(Colors.white, 0.28 * t));
  }
  for (var i = 0; i < 12; i++) {
    final y = h - fract(hash01(i + 60) + ph * (1 + i % 3)) * h;
    final x = w * (0.5 + 0.48 * hash01(i + 70)) + wave(ph, hash01(i), 3) * 4;
    canvas.drawCircle(Offset(x, y), 1 + hash01(i + 80) * 1.6, strokePaint(const Color(0xFFFFE8A3), 0.9, 0.5 * t));
  }
}

void _boat(Canvas canvas, Offset p, double size, double angle, double t, double ph) {
  canvas.save();
  canvas.translate(p.dx, p.dy);
  canvas.rotate(angle);
  canvas.drawPath(Path()
    ..moveTo(-size * 0.62, -size * 0.04)
    ..lineTo(size * 0.62, -size * 0.04)
    ..lineTo(size * 0.42, size * 0.2)
    ..lineTo(-size * 0.44, size * 0.2)
    ..close(), fillPaint(const Color(0xFF2A1A10), t));
  canvas.drawLine(Offset(0, -size * 0.04), Offset(0, -size * 0.95), strokePaint(const Color(0xFF2A1A10), 1.6, t));
  canvas.drawPath(Path()
    ..moveTo(size * 0.03, -size * 0.92)
    ..quadraticBezierTo(size * 0.5, -size * 0.45, size * 0.46, -size * 0.12)
    ..lineTo(size * 0.03, -size * 0.12)
    ..close(), fillPaint(const Color(0xFFFFF4E0), 0.95 * t));
  canvas.drawPath(Path()
    ..moveTo(-size * 0.03, -size * 0.75)
    ..lineTo(-size * 0.34, -size * 0.12)
    ..lineTo(-size * 0.03, -size * 0.12)
    ..close(), fillPaint(const Color(0xFFE8DCC4), 0.9 * t));
  final lantern = 0.75 + 0.25 * _flicker(ph, 0.4);
  drawGlow(canvas, Offset(size * 0.5, -size * 0.1), size * 0.4 * lantern, const Color(0xFFFFC857), 0.9 * t);
  canvas.restore();
}

/// A night sea: swells rolling at four depths with foam on their crests, a
/// little sailboat riding them with its lantern lit, the moon's path
/// shimmering on the water and gulls gliding by.
void wavesMotif(Canvas canvas, Size s, double t, double ph) {
  final w = s.width, h = s.height, u = unitOf(s);
  for (var i = 0; i < 40; i++) {
    canvas.drawCircle(Offset(hash01(i) * w, hash01(i + 40) * h * 0.4), 0.4 + hash01(i + 80) * 0.8, fillPaint(Colors.white, (0.2 + 0.5 * wave01(ph, hash01(i + 9), 5 + i % 3)) * t));
  }
  final moon = Offset(w * 0.84, u * 0.2);
  drawGlow(canvas, moon, u * 0.35, const Color(0xFFFFF7D6), 0.3 * t);
  canvas.drawCircle(moon, u * 0.085, fillPaint(const Color(0xFFFFF7D6), t));
  canvas.drawCircle(moon + Offset(u * 0.03, -u * 0.02), u * 0.075, fillPaint(const Color(0xFF042C54), 0.25 * t));

  for (var g = 0; g < 2; g++) {
    final x = fract(hash01(g + 3) - ph * (1 + g)) * w * 0.9 + w * 0.15;
    final y = heroHeight(s) * (0.12 + 0.1 * g) + wave(ph, g * 0.3, 3) * 4;
    final flap = 0.25 + 0.3 * wave01(ph, g * 0.5, 20 + g * 4);
    final span_ = u * 0.07;
    final gull = strokePaint(const Color(0xFFE5E7EB), 1.4, 0.85 * t);
    canvas.drawPath(Path()
      ..moveTo(x - span_, y - span_ * flap)
      ..quadraticBezierTo(x - span_ * 0.45, y - span_ * (flap + 0.25), x, y)
      ..quadraticBezierTo(x + span_ * 0.45, y - span_ * (flap + 0.25), x + span_, y - span_ * flap), gull);
  }

  const layers = 4;
  for (var i = 0; i < layers; i++) {
    final zh = heroHeight(s);
    final baseY = zh * (0.42 + i * 0.14);
    final amp = 5.0 + i * 3;
    final speed = (i.isEven ? 1 : -1) * (1 + i % 2);
    double yAt(double x) => baseY + math.sin((x / w * (2 + i) + ph * speed) * tau) * amp + math.sin((x / w * (5 + i) - ph * 2) * tau) * amp * 0.3;
    final path = Path()..moveTo(0, h);
    final crest = Path();
    for (var x = 0.0; x <= w + 6; x += 6) {
      final y = yAt(x);
      path.lineTo(x, y);
      x == 0 ? crest.moveTo(x, y) : crest.lineTo(x, y);
    }
    path
      ..lineTo(w + 6, h)
      ..close();
    final color = Color.lerp(const Color(0xFF0B4F7A), const Color(0xFF38BDF8), i / layers)!;
    canvas.drawPath(path, Paint()..shader = ui.Gradient.linear(Offset(0, baseY - amp), Offset(0, h), [color.withValues(alpha: (0.55 + 0.1 * i) * t), Color.lerp(color, Colors.black, 0.4)!.withValues(alpha: 0.9 * t)]));
    canvas.drawPath(crest, strokePaint(Colors.white, 1.3, (0.2 + 0.08 * i) * t));
    // Foam glints on the crests.
    for (var k = 0; k < 10; k++) {
      final x = fract(hash01(i * 20 + k) + ph * speed * 0.5) * w;
      final glint = wave01(ph, hash01(i * 20 + k + 5), 6);
      if (glint < 0.6) continue;
      canvas.drawCircle(Offset(x, yAt(x) - 1), 1.2, fillPaint(Colors.white, (glint - 0.6) * 2 * t));
    }
    if (i == 0) {
      // The moon's path on the water.
      for (var k = 0; k < 14; k++) {
        final y = baseY + 4 + k * 5;
        if (y > h) break;
        final jitter = wave(ph, k * 0.13, 4) * u * 0.04;
        final len = u * (0.18 - k * 0.008) * (0.6 + 0.4 * wave01(ph, k * 0.21, 6));
        canvas.drawLine(Offset(moon.dx + jitter - len / 2, y), Offset(moon.dx + jitter + len / 2, y), Paint()
          ..blendMode = BlendMode.plus
          ..strokeWidth = 1.4
          ..color = const Color(0xFFFFF7D6).withValues(alpha: 0.4 * (1 - k / 14) * t));
      }
    }
    if (i == 1) {
      final bx = w * 0.68;
      final slope = (yAt(bx + 6) - yAt(bx - 6)) / 12;
      _boat(canvas, Offset(bx, yAt(bx) - u * 0.02), u * 0.24, math.atan(slope), t, ph);
    }
  }
}
