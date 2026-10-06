// Fetches the avatars — each a DiceBear style (https://www.dicebear.com)
// and a seed, as listed in kAvatarCollections (lib/widgets/avatar_art.dart)
// — and flattens each one into the few steps AvatarArt paints: shapes
// filled or outlined, clips and see-through groups. The style's own
// background is left out, so the player's colour shows behind. Written to
// lib/widgets/avatar_art_data.dart.
//
// Run it again after adding an avatar:
//   dart run tool/avatars.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:path_parsing/path_parsing.dart';
import 'package:xml/xml.dart';

const _catalog = 'lib/widgets/avatar_art.dart';
const _out = 'lib/widgets/avatar_art_data.dart';
const _api = 'https://api.dicebear.com/10.x';

Future<String> _get(HttpClient client, String url) async {
  for (var attempt = 1;; attempt++) {
    final request = await client.getUrl(Uri.parse(url));
    request.headers.set(HttpHeaders.userAgentHeader, 'podium-avatars');
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode == 200) return body;
    // The API asks to slow down now and then.
    if (response.statusCode != 429 || attempt == 5) throw HttpException('${response.statusCode} on $url');
    await Future<void>.delayed(Duration(seconds: 2 * attempt));
  }
}

/// A number as short as it goes: 3 decimals at most, no trailing zeros.
String _n(double v) {
  final s = v.toStringAsFixed(3);
  return s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;
}

/// An affine transform, SVG's matrix(a b c d e f).
class _M {
  final double a, b, c, d, e, f;
  const _M(this.a, this.b, this.c, this.d, this.e, this.f);
  static const identity = _M(1, 0, 0, 1, 0, 0);

  _M operator *(_M o) => _M(a * o.a + c * o.b, b * o.a + d * o.b, a * o.c + c * o.d, b * o.c + d * o.d, a * o.e + c * o.f + e, b * o.e + d * o.f + f);

  bool get isIdentity => a == 1 && b == 0 && c == 0 && d == 1 && e == 0 && f == 0;

  /// How much it scales lengths, for a stroke's width.
  double get scale => math.sqrt((a * d - b * c).abs());

  (double, double) apply(double x, double y) => (a * x + c * y + e, b * x + d * y + f);

  @override
  String toString() => isIdentity ? '-' : [a, b, c, d, e, f].map(_n).join(' ');
}

final _number = RegExp(r'[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?');

List<double> _numbers(String s) => [for (final m in _number.allMatches(s)) double.parse(m.group(0)!)];

_M _transform(String? t) {
  var m = _M.identity;
  if (t == null) return m;
  for (final op in RegExp(r'([a-zA-Z]+)\s*\(([^)]*)\)').allMatches(t)) {
    final v = _numbers(op.group(2)!);
    m = m *
        switch (op.group(1)) {
          'translate' => _M(1, 0, 0, 1, v[0], v.length > 1 ? v[1] : 0),
          'scale' => _M(v[0], 0, 0, v.length > 1 ? v[1] : v[0], 0, 0),
          'matrix' => _M(v[0], v[1], v[2], v[3], v[4], v[5]),
          'rotate' => () {
              final r = v[0] * math.pi / 180;
              final turn = _M(math.cos(r), math.sin(r), -math.sin(r), math.cos(r), 0, 0);
              if (v.length < 3) return turn;
              return _M(1, 0, 0, 1, v[1], v[2]) * turn * _M(1, 0, 0, 1, -v[1], -v[2]);
            }(),
          final other => throw StateError('unsupported transform $other'),
        };
  }
  return m;
}

/// Path data with [m] applied, in absolute moves, lines and curves.
class _Baker extends PathProxy {
  final _M m;
  final out = StringBuffer();
  _Baker(this.m);

  void _point(double x, double y) {
    final (px, py) = m.apply(x, y);
    out
      ..write(_n(px))
      ..write(' ')
      ..write(_n(py));
  }

  @override
  void moveTo(double x, double y) {
    out.write('M');
    _point(x, y);
  }

  @override
  void lineTo(double x, double y) {
    out.write('L');
    _point(x, y);
  }

  @override
  void cubicTo(double x1, double y1, double x2, double y2, double x3, double y3) {
    out.write('C');
    _point(x1, y1);
    out.write(' ');
    _point(x2, y2);
    out.write(' ');
    _point(x3, y3);
  }

  @override
  void close() => out.write('Z');
}

String _bake(String d, _M m) {
  final baker = _Baker(m);
  writeSvgPathDataToPath(d, baker);
  return baker.out.toString();
}

const _named = {'black': 0x000000, 'white': 0xFFFFFF, 'red': 0xFF0000};

/// A paint as RRGGBBAA, or null for none.
String? _color(String value, double opacity) {
  if (value == 'none' || value == 'transparent' || opacity <= 0) return null;
  int rgb;
  if (value.startsWith('#')) {
    var hex = value.substring(1);
    if (hex.length == 3) hex = hex.split('').map((c) => '$c$c').join();
    if (hex.length != 6) throw StateError('unsupported colour $value');
    rgb = int.parse(hex, radix: 16);
  } else {
    rgb = _named[value.toLowerCase()] ?? (throw StateError('unsupported paint $value'));
  }
  final alpha = (opacity.clamp(0, 1) * 255).round();
  return (rgb << 8 | alpha).toRadixString(16).padLeft(8, '0');
}

/// What a shape inherits from the groups round it.
class _Style {
  final Map<String, String> props;
  const _Style(this.props);

  static const inherited = {'fill', 'fill-opacity', 'fill-rule', 'clip-rule', 'stroke', 'stroke-width', 'stroke-opacity', 'stroke-linecap', 'stroke-linejoin', 'stroke-miterlimit'};

  _Style merge(Map<String, String> own) => _Style({...props, for (final e in own.entries) if (inherited.contains(e.key)) e.key: e.value});

  String operator [](String key) => props[key] ?? const {'fill': '#000000', 'stroke': 'none', 'stroke-width': '1', 'fill-rule': 'nonzero', 'clip-rule': 'nonzero', 'stroke-linecap': 'butt', 'stroke-linejoin': 'miter'}[key] ?? '1';
}

const _known = {
  'id', 'class', 'd', 'x', 'y', 'width', 'height', 'rx', 'ry', 'cx', 'cy', 'r', 'x1', 'y1', 'x2', 'y2', 'points', 'transform', 'opacity', 'clip-path', 'style', 'href', //
  'xlink:href', 'shape-rendering', ..._Style.inherited,
};

/// An element's attributes, its `style` folded in.
Map<String, String> _attributes(XmlElement e) {
  final out = {for (final a in e.attributes) a.name.qualified: a.value};
  final style = out.remove('style');
  if (style != null) {
    for (final decl in style.split(';')) {
      final i = decl.indexOf(':');
      if (i > 0) out[decl.substring(0, i).trim()] = decl.substring(i + 1).trim();
    }
  }
  for (final key in out.keys) {
    if (!_known.contains(key)) throw StateError('unsupported attribute $key on <${e.name.local}>');
  }
  return out;
}

double _num(Map<String, String> a, String key, [double fallback = 0]) => a[key] == null ? fallback : double.parse(a[key]!);

/// A basic shape as path data, in its own coordinates.
String? _shape(XmlElement e, Map<String, String> a) {
  String ellipse(double cx, double cy, double rx, double ry) =>
      'M${_n(cx - rx)} ${_n(cy)}a${_n(rx)} ${_n(ry)} 0 1 0 ${_n(2 * rx)} 0a${_n(rx)} ${_n(ry)} 0 1 0 ${_n(-2 * rx)} 0Z';
  switch (e.name.local) {
    case 'path':
      return a['d'];
    case 'circle':
      return ellipse(_num(a, 'cx'), _num(a, 'cy'), _num(a, 'r'), _num(a, 'r'));
    case 'ellipse':
      return ellipse(_num(a, 'cx'), _num(a, 'cy'), _num(a, 'rx'), _num(a, 'ry'));
    case 'rect':
      final x = _num(a, 'x'), y = _num(a, 'y'), w = _num(a, 'width'), h = _num(a, 'height');
      var rx = a['rx'] != null ? _num(a, 'rx') : _num(a, 'ry');
      var ry = a['ry'] != null ? _num(a, 'ry') : rx;
      rx = math.min(rx, w / 2);
      ry = math.min(ry, h / 2);
      if (rx <= 0 || ry <= 0) return 'M${_n(x)} ${_n(y)}h${_n(w)}v${_n(h)}h${_n(-w)}Z';
      final arc = 'a${_n(rx)} ${_n(ry)} 0 0 1';
      return 'M${_n(x + rx)} ${_n(y)}h${_n(w - 2 * rx)}$arc ${_n(rx)} ${_n(ry)}v${_n(h - 2 * ry)}$arc ${_n(-rx)} ${_n(ry)}'
          'h${_n(2 * rx - w)}$arc ${_n(-rx)} ${_n(-ry)}v${_n(2 * ry - h)}$arc ${_n(rx)} ${_n(-ry)}Z';
    case 'line':
      return 'M${_n(_num(a, 'x1'))} ${_n(_num(a, 'y1'))}L${_n(_num(a, 'x2'))} ${_n(_num(a, 'y2'))}';
    case 'polygon' || 'polyline':
      final p = _numbers(a['points'] ?? '');
      final points = [for (var i = 0; i + 1 < p.length; i += 2) '${_n(p[i])} ${_n(p[i + 1])}'].join('L');
      return 'M$points${e.name.local == 'polygon' ? 'Z' : ''}';
  }
  return null;
}

/// Flattens one avatar's SVG into its drawing steps, split by ; — see
/// AvatarArt for what each step means.
String _flatten(String svg) {
  final root = XmlDocument.parse(svg).rootElement;
  final box = _numbers(root.getAttribute('viewBox')!);
  final width = box[2], height = box[3];
  final byId = {for (final e in root.descendantElements) if (e.getAttribute('id') != null) e.getAttribute('id')!: e};
  XmlElement ref(String url) {
    final id = RegExp(r'#([^)]+)').firstMatch(url)!.group(1)!;
    return byId[id] ?? (throw StateError('nothing at #$id'));
  }

  final steps = <String>['v,${_n(width)},${_n(height)}${root.getAttribute('shape-rendering') == 'crispEdges' ? ',crisp' : ''}'];

  /// The clip [url] points to, in the coordinates [m] leads to, as one path.
  String clipData(String url, _M m, _Style style) {
    final clip = ref(url);
    final parts = <String>[];
    var rule = 'nonzero';
    void collect(XmlElement e, _M at, _Style s) {
      final a = _attributes(e);
      final here = at * _transform(a['transform']);
      final st = s.merge(a);
      if (e.name.local == 'use') {
        collect(ref(a['href'] ?? a['xlink:href']!), here * _M(1, 0, 0, 1, _num(a, 'x'), _num(a, 'y')), st);
        return;
      }
      if (e.name.local == 'g') {
        for (final child in e.childElements) {
          collect(child, here, st);
        }
        return;
      }
      final d = _shape(e, a) ?? (throw StateError('unsupported <${e.name.local}> in a clip'));
      parts.add(_bake(d, here));
      rule = st['clip-rule'];
    }

    for (final child in clip.childElements) {
      collect(child, m * _transform(clip.getAttribute('transform')), style);
    }
    if (parts.length > 1 && rule == 'evenodd') throw StateError('an even-odd clip of several shapes');
    return 'c,${rule == 'evenodd' ? 'e' : 'n'}:${parts.join()}';
  }

  /// Whether [url] clips to the whole box anyway — the root's own clip.
  bool clipsNothing(String url, _M m) {
    final clip = ref(url);
    final shapes = clip.childElements.toList();
    if (shapes.length != 1 || shapes.single.name.local != 'rect' || !m.isIdentity) return false;
    final a = _attributes(shapes.single);
    return _num(a, 'x') <= 0 && _num(a, 'y') <= 0 && _num(a, 'width') >= width && _num(a, 'height') >= height && _num(a, 'rx') == 0 && _num(a, 'ry') == 0;
  }

  void walk(XmlElement e, _M parent, _Style inherited) {
    final name = e.name.local;
    if (const {'defs', 'metadata', 'title', 'desc', 'clipPath'}.contains(name)) return;
    if (const {'mask', 'filter', 'linearGradient', 'radialGradient', 'pattern', 'image', 'text', 'style', 'svg'}.contains(name)) throw StateError('unsupported <$name>');
    final a = _attributes(e);
    for (final key in const ['mask', 'filter']) {
      if (a[key] != null) throw StateError('unsupported $key');
    }
    final m = parent * _transform(a['transform']);
    final style = inherited.merge(a);
    final opacity = _num(a, 'opacity', 1);
    if (opacity <= 0) return;

    // The background: a rect over the whole box, under everything else.
    if (name == 'rect' && m.isIdentity && _num(a, 'x') == 0 && _num(a, 'y') == 0 && _num(a, 'width') == width && _num(a, 'height') == height && steps.length == 1) return;

    final clip = a['clip-path'];
    final clipped = clip != null && !clipsNothing(clip, m);
    if (clipped) steps.add(clipData(clip, m, style));

    final d = name == 'g' || name == 'use' ? null : (_shape(e, a) ?? (throw StateError('unsupported <$name>')));
    final fill = d == null ? null : _color(style['fill'], double.parse(style['fill-opacity']));
    final strokeWidth = double.parse(style['stroke-width']);
    final stroke = d == null || strokeWidth <= 0 ? null : _color(style['stroke'], double.parse(style['stroke-opacity']));
    // A see-through shape takes its opacity in its paint; a group — or a
    // shape both filled and outlined — is painted in a layer, faded whole.
    final layered = opacity < 1 && (d == null || (fill != null && stroke != null));
    if (layered) steps.add('o,${_n(opacity)}');
    String faded(String rgba) => opacity < 1 && !layered ? (int.parse(rgba, radix: 16) & 0xFFFFFF00 | (int.parse(rgba.substring(6), radix: 16) * opacity).round()).toRadixString(16).padLeft(8, '0') : rgba;

    if (name == 'g') {
      for (final child in e.childElements) {
        walk(child, m, style);
      }
    } else if (name == 'use') {
      walk(ref(a['href'] ?? a['xlink:href']!), m * _M(1, 0, 0, 1, _num(a, 'x'), _num(a, 'y')), style);
    } else {
      if (fill != null) steps.add('f,${faded(fill)},${style['fill-rule'] == 'evenodd' ? 'e' : 'n'},$m:$d');
      if (stroke != null) {
        const caps = {'butt': 'b', 'round': 'r', 'square': 's'};
        const joins = {'miter': 'm', 'round': 'r', 'bevel': 'b'};
        steps.add('s,${faded(stroke)},${_n(strokeWidth * m.scale)},${caps[style['stroke-linecap']]}${joins[style['stroke-linejoin']]},$m:$d');
      }
    }
    if (layered) steps.add('r');
    if (clipped) steps.add('r');
  }

  final style = const _Style({}).merge({for (final a in root.attributes) a.name.qualified: a.value});
  for (final child in root.childElements) {
    walk(child, _M.identity, style);
  }
  return steps.join(';');
}

Future<void> main() async {
  final catalog = File(_catalog).readAsStringSync();
  final ids = [
    for (final m in RegExp(r"style: '([a-z-]+)',\s*seeds: \[([\d,\s]+)\]").allMatches(catalog))
      for (final seed in _numbers(m.group(2)!)) '${m.group(1)}/${seed.toInt()}',
  ];
  if (ids.isEmpty) throw StateError('no avatar in $_catalog');
  final client = HttpClient();
  try {
    final out = StringBuffer()
      ..writeln('// GENERATED by tool/avatars.dart — run it again rather than editing this')
      ..writeln('// file.')
      ..writeln('//')
      ..writeln('// The avatars, drawn from DiceBear styles (https://www.dicebear.com): see')
      ..writeln('// kAvatarCollections for who drew each style, and under which licence.')
      ..writeln()
      ..writeln('/// Each avatar, \'style/seed\': its drawing steps (see AvatarArt), split by ;.')
      ..writeln('const kAvatarArt = <String, String>{');
    for (final id in ids) {
      final (style, seed) = (id.split('/').first, id.split('/').last);
      final svg = await _get(client, '$_api/$style/svg?seed=$seed');
      try {
        out.writeln("  '$id': '${_flatten(svg)}',");
      } on StateError catch (e) {
        throw StateError('$id: ${e.message} — pick another seed');
      }
    }
    out.writeln('};');
    File(_out).writeAsStringSync(out.toString());
    stdout.writeln('${ids.length} avatars written to $_out (${(File(_out).lengthSync() / 1024).round()} Ko).');
  } finally {
    client.close();
  }
}
