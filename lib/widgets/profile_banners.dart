import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'ambient_loop.dart';
import 'banner_motifs.dart';

export 'avatar_frames.dart';

/// Paints a banner's scene over its gradient for the entrance progress `t`
/// (0 → 1, once) and the ambient loop phase `ph` (0 → 1, repeating) — see
/// banner_motifs.dart.
typedef BannerMotif = void Function(Canvas canvas, Size size, double t, double ph);

/// One profile-card background (see AppUser.banner): a gradient, plus an
/// optional animated scene painted in code — no image assets.
class BannerTheme {
  final String id;
  final String label;
  final String category;
  final List<Color> colors;
  final Alignment begin;
  final Alignment end;
  final BannerMotif? motif;

  /// How long one ambient loop lasts.
  final Duration period;
  const BannerTheme({
    required this.id,
    required this.label,
    required this.category,
    required this.colors,
    this.begin = Alignment.topLeft,
    this.end = Alignment.bottomRight,
    this.motif,
    this.period = const Duration(seconds: 12),
  });

  bool get animated => motif != null;
}

const kBannerCategories = ['Animées', 'Jeux vidéo', 'Jeux de société', 'Sport', 'Couleurs'];

const List<BannerTheme> kBannerThemes = [
  // ---- Animées: motion is the whole point ----
  BannerTheme(id: 'aurora', label: 'Aurore boréale', category: 'Animées', colors: [Color(0xFF020617), Color(0xFF0B1E3B)], begin: Alignment.topCenter, end: Alignment.bottomCenter, motif: auroraMotif),
  BannerTheme(id: 'warp', label: 'Hyperespace', category: 'Animées', colors: [Color(0xFF000005), Color(0xFF0A1440)], motif: warpMotif, period: Duration(seconds: 8)),
  BannerTheme(id: 'matrix', label: 'Code', category: 'Animées', colors: [Color(0xFF000A02), Color(0xFF032110)], motif: matrixMotif),
  BannerTheme(id: 'lava', label: 'Lave', category: 'Animées', colors: [Color(0xFF2A0500), Color(0xFF7A1A00)], motif: lavaMotif, period: Duration(seconds: 16)),
  BannerTheme(id: 'waves', label: 'Vagues', category: 'Animées', colors: [Color(0xFF042C54), Color(0xFF0E7490)], begin: Alignment.topCenter, end: Alignment.bottomCenter, motif: wavesMotif),
  // ---- Jeux vidéo ----
  BannerTheme(id: 'arcade', label: 'Arcade', category: 'Jeux vidéo', colors: [Color(0xFF12052E), Color(0xFF5B1A9E), Color(0xFFE0337E)], begin: Alignment.topCenter, end: Alignment.bottomCenter, motif: arcadeMotif),
  BannerTheme(id: 'invaders', label: 'Invaders', category: 'Jeux vidéo', colors: [Color(0xFF070B1F), Color(0xFF1E2A78)], motif: invadersMotif),
  BannerTheme(id: 'gamepad', label: 'Manette', category: 'Jeux vidéo', colors: [Color(0xFF0F1220), Color(0xFF2B3354)], motif: gamepadMotif),
  BannerTheme(id: 'blocks', label: 'Blocs', category: 'Jeux vidéo', colors: [Color(0xFF1B1446), Color(0xFF3B2F8F)], motif: blocksMotif, period: blocksPeriod),
  BannerTheme(id: 'galaxy', label: 'Galaxie', category: 'Jeux vidéo', colors: [Color(0xFF05010F), Color(0xFF1A0B3D), Color(0xFF0B2A5E)], motif: galaxyMotif, period: Duration(seconds: 20)),
  BannerTheme(id: 'gameboy', label: 'Game Boy', category: 'Jeux vidéo', colors: [Color(0xFF0F380F), Color(0xFF306230)], motif: gameboyMotif),
  // ---- Jeux de société ----
  BannerTheme(id: 'chess', label: 'Échecs', category: 'Jeux de société', colors: [Color(0xFF2B1D12), Color(0xFF7A5534)], motif: chessMotif),
  BannerTheme(id: 'dice', label: 'Dés', category: 'Jeux de société', colors: [Color(0xFF5E0B15), Color(0xFFC81D33)], motif: diceMotif, period: Duration(seconds: 8)),
  BannerTheme(id: 'meeples', label: 'Meeples', category: 'Jeux de société', colors: [Color(0xFF5B2A06), Color(0xFFC57A1C)], motif: meeplesMotif, period: Duration(seconds: 14)),
  BannerTheme(id: 'hexes', label: 'Plateau', category: 'Jeux de société', colors: [Color(0xFF06324F), Color(0xFF0B6FA4)], motif: hexesMotif),
  BannerTheme(id: 'cards', label: 'Tapis de cartes', category: 'Jeux de société', colors: [Color(0xFF03362A), Color(0xFF0B7A55)], motif: cardsMotif),
  BannerTheme(id: 'dungeon', label: 'Donjon', category: 'Jeux de société', colors: [Color(0xFF14081A), Color(0xFF4A1530)], motif: dungeonMotif),
  BannerTheme(id: 'casino', label: 'Casino', category: 'Jeux de société', colors: [Color(0xFF26050A), Color(0xFF7A0F17)], motif: casinoMotif),
  // ---- Sport ----
  BannerTheme(id: 'pitch', label: 'Terrain', category: 'Sport', colors: [Color(0xFF0E4D1F), Color(0xFF1F8A3B)], motif: pitchMotif),
  BannerTheme(id: 'parquet', label: 'Parquet', category: 'Sport', colors: [Color(0xFF7A3E14), Color(0xFFC97B3A)], motif: parquetMotif, period: Duration(seconds: 7)),
  BannerTheme(id: 'clay', label: 'Terre battue', category: 'Sport', colors: [Color(0xFF9A3D18), Color(0xFFD9683A)], motif: clayMotif, period: Duration(seconds: 8)),
  // ---- Couleurs: the plain gradients, still ----
  BannerTheme(id: 'nuit', label: 'Nuit', category: 'Couleurs', colors: [Color(0xFF18171C), Color(0xFF34303F)]),
  BannerTheme(id: 'braise', label: 'Braise', category: 'Couleurs', colors: [Color(0xFFB8321A), Color(0xFFE5537B)]),
  BannerTheme(id: 'ocean', label: 'Océan', category: 'Couleurs', colors: [Color(0xFF0F4C75), Color(0xFF2AA8B0)]),
  BannerTheme(id: 'foret', label: 'Forêt', category: 'Couleurs', colors: [Color(0xFF14532D), Color(0xFF1F9D57)]),
  BannerTheme(id: 'aurore', label: 'Aurore', category: 'Couleurs', colors: [Color(0xFF4C1D95), Color(0xFF3B82F6)]),
  BannerTheme(id: 'or', label: 'Or', category: 'Couleurs', colors: [Color(0xFF7C4A03), Color(0xFFE8A93B)]),
];

BannerTheme bannerThemeById(String id) => kBannerThemes.firstWhere((b) => b.id == id, orElse: () => kBannerThemes.firstWhere((b) => b.id == 'nuit'));

/// A banner's gradient and scene, filling its parent.
///
///  * By default, the scene plays its entrance whenever the theme changes,
///    then keeps moving on its ambient loop (plain gradients stay still).
///  * With [phase], a still frame of the loop at that phase — thumbnails,
///    and visual checks in tests.
///  * With [animate] false, a still frame at the start of the loop.
class ProfileBannerBackground extends StatelessWidget {
  final String themeId;
  final bool animate;
  final double? phase;
  const ProfileBannerBackground({super.key, required this.themeId, this.animate = true, this.phase});

  @override
  Widget build(BuildContext context) {
    final theme = bannerThemeById(themeId);
    final live = phase == null && animate && theme.animated;
    Widget paint(double t, double ph) => DecoratedBox(
          decoration: BoxDecoration(gradient: LinearGradient(begin: theme.begin, end: theme.end, colors: theme.colors)),
          child: theme.motif == null ? const SizedBox.expand() : CustomPaint(painter: _BannerPainter(theme, t, ph), isComplex: true, willChange: live, size: Size.infinite),
        );
    final scene = !live
        ? paint(1, phase ?? 0)
        : TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeOutCubic,
            builder: (context, t, _) => AmbientLoop(period: theme.period, builder: (context, ph) => paint(t, ph)),
          );
    return RepaintBoundary(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 450),
        child: KeyedSubtree(key: ValueKey(theme.id), child: scene),
      ),
    );
  }
}

class _BannerPainter extends CustomPainter {
  final BannerTheme theme;
  final double t;
  final double ph;
  _BannerPainter(this.theme, this.t, this.ph);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    canvas.save();
    canvas.clipRect(rect);
    // The scene fades out towards the left, where the name and bio sit,
    // so the text always stays readable over it.
    canvas.saveLayer(rect, Paint());
    theme.motif!(canvas, size, t, ph);
    canvas.drawRect(
      rect,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = ui.Gradient.linear(Offset.zero, Offset(size.width, 0), const [Color(0x40FFFFFF), Color(0xFFFFFFFF)], const [0.12, 0.62]),
    );
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BannerPainter old) => old.t != t || old.ph != ph || old.theme.id != theme.id;
}
