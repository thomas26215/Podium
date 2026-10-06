import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'avatar_art_data.dart';
import 'fx_kit.dart';

/// A set of avatars drawn in one DiceBear style (https://www.dicebear.com).
class AvatarCollection {
  final String label;

  /// The DiceBear style, and the seeds of the avatars picked from it — run
  /// tool/avatars.dart after changing them.
  final String style;
  final List<int> seeds;

  /// Who drew the style, and under which licence: shown under its avatars.
  final String credit;

  const AvatarCollection(this.label, {required this.style, required this.seeds, required this.credit});

  /// Its avatars, named as AppUser.avatar names them.
  List<String> get ids => [for (final seed in seeds) '$style/$seed'];
}

/// The avatars a player can pick (see AppUser.avatar).
const kAvatarCollections = [
  AvatarCollection(
    'Aventuriers',
    style: 'adventurer',
    seeds: [2, 9, 22, 75, 17, 110, 42, 12, 43, 50, 16, 23, 40, 87, 7, 34, 96, 44, 24, 64, 11, 116, 15, 48],
    credit: 'Dessins de Lisa Wischofsky (« Adventurer », remixé par DiceBear), détourés — licence CC BY 4.0.',
  ),
  AvatarCollection(
    'Voxel',
    style: 'voxel-art',
    seeds: [1, 2, 3, 4, 5, 6, 7, 11, 12, 14, 15, 17, 18, 20, 22, 23, 24, 25, 33, 34, 35, 37, 43, 48],
    credit: '« Voxel Art » de DiceBear — domaine public (CC0).',
  ),
  AvatarCollection(
    'Robots',
    style: 'voxel-bot',
    seeds: [1, 2, 3, 6, 8, 9, 10, 13, 16, 18, 19, 22, 24, 26, 29, 31, 32, 34, 36, 38, 40, 41, 44, 48],
    credit: '« Voxel Bot » de DiceBear — domaine public (CC0).',
  ),
  AvatarCollection(
    'Créatures',
    style: 'critters',
    seeds: [2, 3, 4, 7, 8, 9, 12, 13, 14, 15, 17, 19, 22, 24, 25, 28, 29, 31, 33, 34, 36, 37, 46, 48],
    credit: '« Critters » de DiceBear — domaine public (CC0).',
  ),
  AvatarCollection(
    'Pixel',
    style: 'pixel-art',
    seeds: [1, 2, 5, 6, 7, 8, 9, 10, 11, 14, 15, 19, 20, 22, 25, 27, 28, 31, 32, 37, 41, 42, 47, 48],
    credit: '« Pixel Art » de DiceBear — domaine public (CC0).',
  ),
];

/// Whether [id] names one of the avatars — rather than being a letter.
bool isAvatarArt(String id) => kAvatarArt.containsKey(id);

/// The collection the avatar [id] belongs to, if any.
AvatarCollection? avatarCollectionOf(String? id) {
  for (final c in kAvatarCollections) {
    if (c.ids.contains(id)) return c;
  }
  return null;
}

/// An avatar, decoded: the box it's drawn in, then what it does on the
/// canvas, step by step.
class _Art {
  final Size box;
  final List<void Function(Canvas canvas)> steps;
  const _Art(this.box, this.steps);
}

final _decoded = <String, _Art>{};

/// Decodes the avatar [id] (once). Its steps are split by ;, each a kind
/// and its settings split by commas — then, for a shape or a clip, a colon
/// and the shape's SVG path data:
///   v,W,H[,crisp]      the box (crisp: pixel art, drawn without smoothing)
///   f,RRGGBBAA,R,M:d   fill d — R its fill rule (n nonzero, e even-odd), M
///                      its transform as SVG's matrix(), or - for none
///   s,RRGGBBAA,W,CJ,M:d  stroke d, W wide — C its cap and J its join, by
///                      their initials (b butt, r round, s square / m miter,
///                      r round, b bevel)
///   c,R:d              clip to d, until the matching r
///   o,A                draw what follows in a layer A opaque, until the
///                      matching r
///   r                  end of a clip or a layer
_Art _decode(String id) => _decoded.putIfAbsent(id, () {
      var box = const Size(1, 1);
      var crisp = false;
      final steps = <void Function(Canvas canvas)>[];
      for (final step in kAvatarArt[id]!.split(';')) {
        final colon = step.indexOf(':');
        final head = (colon < 0 ? step : step.substring(0, colon)).split(',');
        Path shape(String rule, String matrix) {
          var path = svgPath(step.substring(colon + 1));
          if (matrix != '-') {
            final m = matrix.split(' ').map(double.parse).toList();
            path = path.transform(Float64List.fromList([m[0], m[1], 0, 0, m[2], m[3], 0, 0, 0, 0, 1, 0, m[4], m[5], 0, 1]));
          }
          return path..fillType = rule == 'e' ? PathFillType.evenOdd : PathFillType.nonZero;
        }

        Color color(String rgba) => Color(int.parse(rgba.substring(6), radix: 16) << 24 | int.parse(rgba.substring(0, 6), radix: 16));
        switch (head[0]) {
          case 'v':
            box = Size(double.parse(head[1]), double.parse(head[2]));
            crisp = head.length > 3;
          case 'f':
            final path = shape(head[2], head[3]);
            final paint = Paint()
              ..color = color(head[1])
              ..isAntiAlias = !crisp;
            steps.add((canvas) => canvas.drawPath(path, paint));
          case 's':
            final path = shape('n', head[4]);
            final paint = Paint()
              ..style = PaintingStyle.stroke
              ..color = color(head[1])
              ..strokeWidth = double.parse(head[2])
              ..strokeCap = const {'r': StrokeCap.round, 's': StrokeCap.square}[head[3][0]] ?? StrokeCap.butt
              ..strokeJoin = const {'r': StrokeJoin.round, 'b': StrokeJoin.bevel}[head[3][1]] ?? StrokeJoin.miter;
            steps.add((canvas) => canvas.drawPath(path, paint));
          case 'c':
            final path = shape(head[1], '-');
            steps.add((canvas) => canvas
              ..save()
              ..clipPath(path));
          case 'o':
            final paint = Paint()..color = Color.fromRGBO(0, 0, 0, double.parse(head[1]));
            steps.add((canvas) => canvas.saveLayer(null, paint));
          case 'r':
            steps.add((canvas) => canvas.restore());
        }
      }
      return _Art(box, steps);
    });

/// The avatar [id] (see kAvatarCollections), [size] wide, on a clear
/// background — for a round frame to clip. It never moves, so it keeps a
/// layer of its own, drawn once, whatever animates round it.
class AvatarArt extends StatelessWidget {
  final String id;
  final double size;
  const AvatarArt({super.key, required this.id, required this.size});

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: CustomPaint(size: Size.square(size), painter: _ArtPainter(_decode(id))),
      );
}

class _ArtPainter extends CustomPainter {
  final _Art art;
  _ArtPainter(this.art);

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..clipRect(Offset.zero & size)
      ..scale(size.width / art.box.width, size.height / art.box.height);
    for (final step in art.steps) {
      step(canvas);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ArtPainter old) => old.art != art;
}
