// Draws Cador's app icon — a mint meeple wearing a gold crown, on night
// blue — as SVG, and renders the PNGs that flutter_launcher_icons turns
// into the Android, iOS and web icons (see flutter_launcher_icons in
// pubspec.yaml), plus the website's icons in docs/assets/:
//   assets/icon/cador.png             the whole icon (iOS, web, Android
//                                     before 8.0)
//   assets/icon/cador_foreground.png  the figure alone, on transparent (the
//                                     adaptive icon's foreground)
//   assets/icon/cador_monochrome.png  the figure in white (Android 13's
//                                     themed icons)
//   assets/icon/cador_512.png         the Play Store's 512 × 512 icon
// The crown sits on the head with a cut-out gap around it, so the two
// still read apart in a single colour.
//
// Rendering goes through ImageMagick (with librsvg). Run it again after
// changing the drawing, then regenerate the platform icons:
//   dart run tool/app_icon.dart
//   dart run flutter_launcher_icons
import 'dart:io';
import 'dart:math' as math;

const _night = '#0B1238';
const _mint = '#5FDDB6';
const _gold = '#FFB938';

typedef _Pt = (double, double);

String _p(_Pt p) => '${p.$1.toStringAsFixed(1)},${p.$2.toStringAsFixed(1)}';

/// Rounds the corner [p1] between the edges coming from [p0] and going to
/// [p2] with an arc of radius [r]: its two tangent points and sweep flag.
(_Pt, _Pt, int) _fillet(_Pt p0, _Pt p1, _Pt p2, double r) {
  final v1 = (p0.$1 - p1.$1, p0.$2 - p1.$2), v2 = (p2.$1 - p1.$1, p2.$2 - p1.$2);
  final l1 = math.sqrt(v1.$1 * v1.$1 + v1.$2 * v1.$2), l2 = math.sqrt(v2.$1 * v2.$1 + v2.$2 * v2.$2);
  final u1 = (v1.$1 / l1, v1.$2 / l1), u2 = (v2.$1 / l2, v2.$2 / l2);
  final angle = math.acos((u1.$1 * u2.$1 + u1.$2 * u2.$2).clamp(-1.0, 1.0));
  final t = r / math.tan(angle / 2);
  return ((p1.$1 + u1.$1 * t, p1.$2 + u1.$2 * t), (p1.$1 + u2.$1 * t, p1.$2 + u2.$2 * t), u1.$1 * u2.$2 - u1.$2 * u2.$1 > 0 ? 0 : 1);
}

/// The meeple, clockwise, on a 1024 grid: a round head joined to the
/// shoulders by fillets tangent to both, arms ending in half circles, and
/// every other corner rounded.
String _meeple() {
  const head = (512.0, 300.0), headR = 112.0, neckR = 40.0;
  const shoulderY = 402.0, armDrop = 30.0, armTip = 792.0, arm = 146.0;
  // The neck fillet's centre C sits neckR above the arm's top edge and
  // neckR + headR from the head's centre: solve along that edge.
  const p0 = (512.0, shoulderY), p1 = (armTip, shoulderY + armDrop);
  final len = math.sqrt(math.pow(p1.$1 - p0.$1, 2) + math.pow(p1.$2 - p0.$2, 2));
  final u = ((p1.$1 - p0.$1) / len, (p1.$2 - p0.$2) / len), n = (u.$2, -u.$1);
  final bx = p0.$1 + neckR * n.$1 - head.$1, by = p0.$2 + neckR * n.$2 - head.$2;
  final b = 2 * (bx * u.$1 + by * u.$2), c = bx * bx + by * by - math.pow(headR + neckR, 2);
  final s = (-b + math.sqrt(b * b - 4 * c)) / 2;
  final centre = (p0.$1 + s * u.$1 + neckR * n.$1, p0.$2 + s * u.$2 + neckR * n.$2);
  final onHead = (head.$1 + (centre.$1 - head.$1) * headR / (headR + neckR), head.$2 + (centre.$2 - head.$2) * headR / (headR + neckR));
  final onArm = (centre.$1 - neckR * n.$1, centre.$2 - neckR * n.$2);
  _Pt mirror(_Pt p) => (1024 - p.$1, p.$2);

  const armR = arm / 2 - 0.5;
  const right = <(_Pt, double)>[
    ((armTip, shoulderY + armDrop), armR),
    ((armTip - 6, shoulderY + armDrop + arm), armR),
    ((512.0 + 118, shoulderY + armDrop + arm), 40), // armpit
    ((512.0 + 272, 870), 44), // outer foot
    ((512.0 + 76, 870), 34), // inner foot
  ];
  final corners = [...right, ((512.0, 704.0), 50.0), for (final (p, r) in right.reversed) (mirror(p), r)];
  final points = [onArm, for (final (p, _) in corners) p, mirror(onArm)];
  final d = StringBuffer('M${_p(onHead)} A$neckR,$neckR 0 0 0 ${_p(onArm)}');
  for (var i = 0; i < corners.length; i++) {
    final (p, r) = corners[i];
    final (a, z, sweep) = _fillet(points[i], p, points[i + 2], r);
    d.write(' L${_p(a)} A$r,$r 0 0 $sweep ${_p(z)}');
  }
  d.write(' L${_p(mirror(onArm))} A$neckR,$neckR 0 0 0 ${_p(mirror(onHead))} A$headR,$headR 0 1 1 ${_p(onHead)}Z');
  return d.toString();
}

/// A three-pointed crown standing on y = 0, centred on x = 0.
String _crown() {
  const w = 104.0;
  const corners = <(_Pt, double)>[
    ((-w * 0.86, 0), 16),
    ((-w * 1.06, -118), 14),
    ((-w * 0.47, -58), 10),
    ((0, -132), 14),
    ((w * 0.47, -58), 10),
    ((w * 1.06, -118), 14),
    ((w * 0.86, 0), 16),
  ];
  final d = StringBuffer();
  for (var i = 0; i < corners.length; i++) {
    final (p, r) = corners[i];
    final (a, z, sweep) = _fillet(corners[(i - 1) % corners.length].$1, p, corners[(i + 1) % corners.length].$1, r);
    d.write('${i == 0 ? 'M' : ' L'}${_p(a)} A$r,$r 0 0 $sweep ${_p(z)}');
  }
  return '$d Z';
}

/// The crowned meeple, its crown tilted and set in a cut-out of the head.
String _figure({required String body, required String crown}) {
  const scale = 1.15, gap = 20.0;
  const place = 'translate(508,228) rotate(-9) scale($scale)';
  final crownPath = _crown();
  return '<defs><mask id="gap" maskUnits="userSpaceOnUse" x="0" y="0" width="1024" height="1024">'
      '<rect width="1024" height="1024" fill="#fff"/>'
      '<path d="$crownPath" transform="$place" fill="#000" stroke="#000" stroke-width="${(gap * 2 / scale).toStringAsFixed(1)}" stroke-linejoin="round"/>'
      '</mask></defs>'
      '<g transform="translate(512,548) scale(0.84) translate(-512,-540)">'
      '<path d="${_meeple()}" fill="$body" mask="url(#gap)"/>'
      '<path d="$crownPath" transform="$place" fill="$crown"/>'
      '</g>';
}

String _svg(String content, {String? background}) =>
    '<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">'
    '${background == null ? '' : '<rect width="1024" height="1024" fill="$background"/>'}$content</svg>\n';

/// Renders [svg] (1024 × 1024) to a [size]-pixel PNG, drawn at that size
/// rather than scaled down, so small icons stay sharp. With [alpha] false
/// (the icons with a background), the PNG has no alpha channel, as the App
/// Store wants; the Play Store wants one, even on an opaque icon.
Future<void> _render(String svg, String out, int size, {bool alpha = false}) async {
  final result = await Process.run('magick', ['-background', 'none', '-density', '${96 * size / 1024}', svg, '-resize', '${size}x$size!', '-alpha', alpha ? 'set' : 'off', '-define', 'png:exclude-chunks=date,time', if (alpha) 'PNG32:$out' else out]);
  if (result.exitCode != 0) throw ProcessException('magick', [svg, out], '${result.stderr}', result.exitCode);
  stdout.writeln('→ $out');
}

Future<void> main() async {
  const dir = 'assets/icon';
  Directory(dir).createSync(recursive: true);
  final sources = {
    'cador': _svg(_figure(body: _mint, crown: _gold), background: _night),
    'cador_foreground': _svg(_figure(body: _mint, crown: _gold)),
    'cador_monochrome': _svg(_figure(body: '#FFFFFF', crown: '#FFFFFF')),
  };
  for (final MapEntry(:key, :value) in sources.entries) {
    File('$dir/$key.svg').writeAsStringSync(value);
    await _render('$dir/$key.svg', '$dir/$key.png', 1024, alpha: key != 'cador');
  }
  await _render('$dir/cador.svg', '$dir/cador_512.png', 512, alpha: true);
  await _render('$dir/cador.svg', 'docs/assets/apple-touch-icon.png', 180);
  await _render('$dir/cador.svg', 'docs/assets/logo-64.png', 64);
  await _render('$dir/cador.svg', 'docs/assets/favicon-32.png', 32);
}
