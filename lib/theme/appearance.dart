import 'package:flutter/material.dart';

/// Everything the "Apparence & réglages" screen lets a player change about
/// how the app looks — one immutable value, persisted as JSON on the device
/// (see AppState.setAppearance) and turned into concrete colours and
/// decorations by `AppTokens` for the current light/dark mode.
@immutable
class Appearance {
  final PaletteId palette;
  final AccentId accent;

  /// The hue (0…360) of the accent when [accent] is [AccentId.custom].
  final double customHue;
  final SurfaceStyle surface;
  final CornerStyle corners;
  final FontPair font;
  final BackdropStyle backdrop;

  /// Lets the backdrop drift slowly — only for the backdrops that move
  /// (see [BackdropStyle.animatable]).
  final bool animatedBackdrop;
  final TextSize textSize;
  final NavBarStyle navBar;
  final bool navLabels;

  /// Skips entrance animations and holds animated decorations still.
  final bool reduceMotion;

  const Appearance({
    this.palette = PaletteId.classic,
    this.accent = AccentId.orange,
    this.customHue = 200,
    this.surface = SurfaceStyle.flat,
    this.corners = CornerStyle.standard,
    this.font = FontPair.podium,
    this.backdrop = BackdropStyle.none,
    this.animatedBackdrop = false,
    this.textSize = TextSize.normal,
    this.navBar = NavBarStyle.classic,
    this.navLabels = true,
    this.reduceMotion = false,
  });

  Appearance copyWith({
    PaletteId? palette,
    AccentId? accent,
    double? customHue,
    SurfaceStyle? surface,
    CornerStyle? corners,
    FontPair? font,
    BackdropStyle? backdrop,
    bool? animatedBackdrop,
    TextSize? textSize,
    NavBarStyle? navBar,
    bool? navLabels,
    bool? reduceMotion,
  }) {
    return Appearance(
      palette: palette ?? this.palette,
      accent: accent ?? this.accent,
      customHue: customHue ?? this.customHue,
      surface: surface ?? this.surface,
      corners: corners ?? this.corners,
      font: font ?? this.font,
      backdrop: backdrop ?? this.backdrop,
      animatedBackdrop: animatedBackdrop ?? this.animatedBackdrop,
      textSize: textSize ?? this.textSize,
      navBar: navBar ?? this.navBar,
      navLabels: navLabels ?? this.navLabels,
      reduceMotion: reduceMotion ?? this.reduceMotion,
    );
  }

  /// [look] applied as a theme preset: it sets everything but the player's
  /// comfort settings (text size, motion) and their own custom hue, kept
  /// for whenever they go back to it.
  Appearance withLookOf(Appearance look) => look.copyWith(customHue: customHue, animatedBackdrop: animatedBackdrop, textSize: textSize, reduceMotion: reduceMotion);

  /// Whether this shares [other]'s look — what a theme preset covers.
  bool sameLookAs(Appearance other) => _look == other._look;

  Appearance get _look => copyWith(
        customHue: accent == AccentId.custom ? customHue : 0,
        animatedBackdrop: false,
        textSize: TextSize.normal,
        reduceMotion: false,
      );

  Map<String, Object> toJson() => {
        'palette': palette.name,
        'accent': accent.name,
        'customHue': customHue,
        'surface': surface.name,
        'corners': corners.name,
        'font': font.name,
        'backdrop': backdrop.name,
        'animatedBackdrop': animatedBackdrop,
        'textSize': textSize.name,
        'navBar': navBar.name,
        'navLabels': navLabels,
        'reduceMotion': reduceMotion,
      };

  /// Tolerant of missing or unknown values (an older or newer app version
  /// wrote them) — each falls back to its default.
  factory Appearance.fromJson(Map<String, dynamic> json) {
    T pick<T extends Enum>(List<T> values, Object? name, T fallback) => values.firstWhere((v) => v.name == name, orElse: () => fallback);
    const d = Appearance();
    final hue = json['customHue'];
    return Appearance(
      palette: pick(PaletteId.values, json['palette'], d.palette),
      accent: pick(AccentId.values, json['accent'], d.accent),
      customHue: hue is num ? hue.toDouble().clamp(0, 360) : d.customHue,
      surface: pick(SurfaceStyle.values, json['surface'], d.surface),
      corners: pick(CornerStyle.values, json['corners'], d.corners),
      font: pick(FontPair.values, json['font'], d.font),
      backdrop: pick(BackdropStyle.values, json['backdrop'], d.backdrop),
      animatedBackdrop: json['animatedBackdrop'] == true,
      textSize: pick(TextSize.values, json['textSize'], d.textSize),
      navBar: pick(NavBarStyle.values, json['navBar'], d.navBar),
      navLabels: json['navLabels'] != false,
      reduceMotion: json['reduceMotion'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Appearance &&
      other.palette == palette &&
      other.accent == accent &&
      other.customHue == customHue &&
      other.surface == surface &&
      other.corners == corners &&
      other.font == font &&
      other.backdrop == backdrop &&
      other.animatedBackdrop == animatedBackdrop &&
      other.textSize == textSize &&
      other.navBar == navBar &&
      other.navLabels == navLabels &&
      other.reduceMotion == reduceMotion;

  @override
  int get hashCode => Object.hash(palette, accent, customHue, surface, corners, font, backdrop, animatedBackdrop, textSize, navBar, navLabels, reduceMotion);
}

/// The neutral tones behind everything — background, cards, text. Most are
/// generated from a hue and how strongly it tints the light and dark
/// backgrounds; [classic] keeps the original hand-picked values and [pure]
/// goes for plain white and true black.
enum PaletteId {
  classic('Podium', 45, 0.26, 0.11),
  neutral('Neutre', 240, 0.06, 0.06),
  glacier('Glacier', 212, 0.38, 0.26),
  mint('Menthe', 152, 0.28, 0.18),
  lavender('Lavande', 262, 0.38, 0.22),
  blush('Rosé', 350, 0.48, 0.2),
  sand('Sable', 40, 0.5, 0.2),
  mocha('Moka', 24, 0.3, 0.22),
  midnight('Minuit', 226, 0.26, 0.42),
  pure('Pur', 240, 0, 0),
  tinted('Teinté', 0, 0.42, 0.26);

  const PaletteId(this.label, this.hue, this.lightTint, this.darkTint);
  final String label;
  final double hue;
  final double lightTint;
  final double darkTint;
}

/// The accent colour (buttons, highlights, charts…). Every one keeps white
/// text readable on top of it; [custom] is any hue, darkened as needed.
enum AccentId {
  orange('Orange', Color(0xFFFF5B34)),
  red('Rouge', Color(0xFFE5484D)),
  pink('Rose', Color(0xFFE5537B)),
  fuchsia('Fuchsia', Color(0xFFC026D3)),
  purple('Violet', Color(0xFF8B5CF6)),
  indigo('Indigo', Color(0xFF5B5BD6)),
  blue('Bleu', Color(0xFF3B82F6)),
  sky('Ciel', Color(0xFF0B8BD0)),
  teal('Lagon', Color(0xFF0E9F94)),
  green('Vert', Color(0xFF1F9D57)),
  lime('Olive', Color(0xFF5E9A12)),
  amber('Ambre', Color(0xFFD97706)),
  custom('Sur mesure', Color(0xFF0B8BD0));

  const AccentId(this.label, this.color);
  final String label;
  final Color color;
}

/// How cards, tiles and chips are drawn — the "effects".
enum SurfaceStyle {
  flat('Plat', 'Fond net et filet discret — le style d’origine.'),
  elevated('Relief', 'Cartes posées sur des ombres douces.'),
  neumorphic('Néomorphisme', 'Formes moulées dans le fond, entre lumière et ombre.'),
  glass('Verre', 'Panneaux translucides aux bords lumineux.'),
  clay('Argile', 'Volumes doux et gonflés, comme modelés à la main.'),
  brutalist('Néo-brutal', 'Contours épais et ombres franches, sans flou.'),
  outlined('Contour', 'Tout en traits fins, sans ombre ni relief.'),
  neon('Néon', 'Contours lumineux et halos colorés.'),
  gradient('Dégradé', 'Cartes nuancées de votre couleur d’accent.'),
  satin('Satin', 'Reflets brillants et bords vernis.');

  const SurfaceStyle(this.label, this.description);
  final String label;
  final String description;
}

/// Scales every corner radius of the app.
enum CornerStyle {
  sharp('Droits', 0.3),
  soft('Légers', 0.65),
  standard('Standard', 1),
  round('Ronds', 1.3),
  extra('Très ronds', 1.6);

  const CornerStyle(this.label, this.factor);
  final String label;
  final double factor;
}

/// A body + display (numbers & headings) font pairing. [bodyScale] and
/// [displayScale] even out each font's apparent size, so layouts sized for
/// the default pairing still fit; [tight] fonts keep the negative letter
/// spacing headings use, the others (monospaced, pixel) drop it.
enum FontPair {
  podium('Podium', 'Manrope', 'Space Grotesk'),
  modern('Moderne', 'Inter', 'Inter Tight', bodyScale: 0.97),
  rounded('Arrondie', 'Nunito', 'Fredoka', bodyScale: 1.02),
  geometric('Géométrique', 'Figtree', 'Outfit'),
  technical('Technique', 'IBM Plex Sans', 'JetBrains Mono', displayScale: 0.9, tight: false),
  mono('Machine', 'Space Grotesk', 'Space Mono', displayScale: 0.9, tight: false),
  editorial('Éditoriale', 'Source Sans 3', 'Playfair Display', bodyScale: 1.04),
  sport('Sport', 'Barlow', 'Barlow Condensed', displayScale: 1.1),
  pixel('Pixel', 'Space Grotesk', 'Silkscreen', displayScale: 0.78, tight: false),
  system('Système', null, null);

  const FontPair(this.label, this.bodyFamily, this.displayFamily, {this.bodyScale = 1, this.displayScale = 1, this.tight = true});
  final String label;

  /// Google Fonts family names — null for the device's own font.
  final String? bodyFamily;
  final String? displayFamily;
  final double bodyScale;
  final double displayScale;
  final bool tight;
}

/// What's painted behind every screen.
enum BackdropStyle {
  none('Uni'),
  gradient('Dégradé'),
  aurora('Aurore', animatable: true),
  mesh('Maillage', animatable: true),
  dots('Points'),
  grid('Quadrillage'),
  stripes('Rayures'),
  notebook('Cahier'),
  waves('Vagues', animatable: true),
  bubbles('Bulles', animatable: true),
  stars('Étoiles', animatable: true),
  confetti('Confettis'),
  suits('Cartes');

  const BackdropStyle(this.label, {this.animatable = false});
  final String label;
  final bool animatable;
}

enum TextSize {
  small('Petit', 0.92),
  normal('Normal', 1),
  large('Grand', 1.08),
  huge('Très grand', 1.16);

  const TextSize(this.label, this.scale);
  final String label;
  final double scale;
}

enum NavBarStyle {
  classic('Classique'),
  floating('Flottante');

  const NavBarStyle(this.label);
  final String label;
}

/// A ready-made look (see [Appearance.withLookOf]) — the night themes
/// switch to dark mode too.
class AppearancePreset {
  final String id;
  final String label;
  final String emoji;
  final String description;
  final Appearance look;
  final ThemeMode? mode;
  const AppearancePreset({required this.id, required this.label, required this.emoji, required this.description, required this.look, this.mode});
}

const kAppearancePresets = <AppearancePreset>[
  AppearancePreset(id: 'podium', label: 'Podium', emoji: '🏆', description: 'Le style d’origine.', look: Appearance()),
  AppearancePreset(
    id: 'soft',
    label: 'Soft UI',
    emoji: '☁️',
    description: 'Néomorphisme tout en douceur.',
    look: Appearance(palette: PaletteId.glacier, accent: AccentId.blue, surface: SurfaceStyle.neumorphic, corners: CornerStyle.round, font: FontPair.modern, navBar: NavBarStyle.floating),
  ),
  AppearancePreset(
    id: 'glass',
    label: 'Verre',
    emoji: '🔮',
    description: 'Verre dépoli sur une aurore.',
    look: Appearance(palette: PaletteId.lavender, accent: AccentId.purple, surface: SurfaceStyle.glass, corners: CornerStyle.round, font: FontPair.geometric, backdrop: BackdropStyle.aurora, navBar: NavBarStyle.floating),
  ),
  AppearancePreset(
    id: 'brutal',
    label: 'Néo-brutal',
    emoji: '🧱',
    description: 'Traits épais, ombres franches.',
    look: Appearance(palette: PaletteId.sand, accent: AccentId.pink, surface: SurfaceStyle.brutalist, corners: CornerStyle.sharp, font: FontPair.mono, backdrop: BackdropStyle.dots),
  ),
  AppearancePreset(
    id: 'neon',
    label: 'Néon',
    emoji: '🌃',
    description: 'Halos lumineux sur noir profond.',
    mode: ThemeMode.dark,
    look: Appearance(palette: PaletteId.pure, accent: AccentId.fuchsia, surface: SurfaceStyle.neon, corners: CornerStyle.soft, font: FontPair.technical, backdrop: BackdropStyle.grid),
  ),
  AppearancePreset(
    id: 'clay',
    label: 'Argile',
    emoji: '🧸',
    description: 'Volumes gonflés et pastel.',
    look: Appearance(palette: PaletteId.blush, accent: AccentId.pink, surface: SurfaceStyle.clay, corners: CornerStyle.extra, font: FontPair.rounded, backdrop: BackdropStyle.bubbles, navBar: NavBarStyle.floating),
  ),
  AppearancePreset(
    id: 'minimal',
    label: 'Minimal',
    emoji: '◻️',
    description: 'Des traits, rien de plus.',
    look: Appearance(palette: PaletteId.pure, accent: AccentId.indigo, surface: SurfaceStyle.outlined, corners: CornerStyle.soft, font: FontPair.modern),
  ),
  AppearancePreset(
    id: 'paper',
    label: 'Papier',
    emoji: '📜',
    description: 'Un carnet de scores à l’ancienne.',
    look: Appearance(palette: PaletteId.sand, accent: AccentId.red, surface: SurfaceStyle.outlined, corners: CornerStyle.soft, font: FontPair.editorial, backdrop: BackdropStyle.notebook),
  ),
  AppearancePreset(
    id: 'ocean',
    label: 'Océan',
    emoji: '🌊',
    description: 'Dégradés marins et vagues.',
    look: Appearance(palette: PaletteId.glacier, accent: AccentId.teal, surface: SurfaceStyle.gradient, corners: CornerStyle.round, font: FontPair.geometric, backdrop: BackdropStyle.waves),
  ),
  AppearancePreset(
    id: 'forest',
    label: 'Forêt',
    emoji: '🌲',
    description: 'Verts profonds et ombres douces.',
    look: Appearance(palette: PaletteId.mint, accent: AccentId.green, surface: SurfaceStyle.elevated, font: FontPair.rounded, backdrop: BackdropStyle.mesh),
  ),
  AppearancePreset(
    id: 'arcade',
    label: 'Arcade',
    emoji: '👾',
    description: 'Pixels et étoiles, comme en salle.',
    mode: ThemeMode.dark,
    look: Appearance(palette: PaletteId.midnight, accent: AccentId.fuchsia, surface: SurfaceStyle.brutalist, corners: CornerStyle.sharp, font: FontPair.pixel, backdrop: BackdropStyle.stars),
  ),
  AppearancePreset(
    id: 'prestige',
    label: 'Prestige',
    emoji: '👑',
    description: 'Satin, or et belles lettres.',
    look: Appearance(palette: PaletteId.mocha, accent: AccentId.amber, surface: SurfaceStyle.satin, font: FontPair.editorial, backdrop: BackdropStyle.gradient),
  ),
];

/// The preset whose look [a] currently matches, if any.
AppearancePreset? presetMatching(Appearance a) {
  for (final p in kAppearancePresets) {
    if (a.sameLookAs(p.look)) return p;
  }
  return null;
}
