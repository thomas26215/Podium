import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show HSVColor;

import '../models/app_user.dart';
import '../models/plus_membership.dart';
import '../theme/appearance.dart';

// What's paid in Podium — in this one file, so the free/paid split and
// the prices can be tuned here alone. Each paid item is unlocked either by
// a membership — Podium+ for everything on the profile card, Podium++ for
// that and the whole interface — or by buying it in the Boutique with
// jetons, for good. The rest stays free: avatar emoji and colour, titles
// (earned with badges, never bought), palettes, named accents, corners,
// the nav bar, text size and every comfort setting.
//
// The ids are those of the catalogs in lib/widgets (kBannerThemes,
// kAvatarFrames, kNameFonts, kNameEffects, kProfileEffects) and of the
// look's enums — test/plus_test.dart checks they all exist and that each
// kind keeps free choices.

/// Every banner with a scene, but one per theme left free as a taste
/// (Manette, Dés, Terrain) — the plain colours all stay free.
const kPlusBanners = {
  'aurora', 'warp', 'matrix', 'lava', 'waves', //
  'arcade', 'invaders', 'blocks', 'galaxy', 'gameboy', //
  'chess', 'meeples', 'hexes', 'cards', 'dungeon', 'casino', //
  'parquet', 'clay', //
};

/// Pixel, Lauriers and Dés stay free.
const kPlusAvatarFrames = {'gold', 'neon', 'rainbow', 'royal', 'fire', 'ice', 'stars'};

/// Classique, Rétro and BD stay free.
const kPlusNameFonts = {'arcade', 'medieval', 'script', 'future', 'marker', 'horror'};

/// Dégradé stays free.
const kPlusNameEffects = {'neon', 'gold', 'rainbow', 'fire', 'glitch', 'wave', 'shine', 'holo'};

/// Confettis, Cœurs and Bulles stay free.
const kPlusProfileEffects = {'sparkles', 'snow', 'fireworks', 'dice', 'pixels', 'coins', 'petals', 'lightning', 'shooting'};

/// The app's own look: the showier surface styles, fonts and backdrops
/// (every drifting one), and the made-to-measure accent — each sold on its
/// own, and in the themes that use them (see [themePack]).
const kPlusSurfaces = {SurfaceStyle.neumorphic, SurfaceStyle.glass, SurfaceStyle.clay, SurfaceStyle.brutalist, SurfaceStyle.neon, SurfaceStyle.gradient, SurfaceStyle.satin};
const kPlusFonts = {FontPair.geometric, FontPair.technical, FontPair.mono, FontPair.sport, FontPair.pixel};
const kPlusBackdrops = {BackdropStyle.aurora, BackdropStyle.mesh, BackdropStyle.waves, BackdropStyle.bubbles, BackdropStyle.stars, BackdropStyle.confetti, BackdropStyle.suits};
const kPlusAccents = {AccentId.custom};

// ============================== the Boutique ==============================

/// What the Boutique sells, kind by kind, and what each costs in jetons.
enum ShopKind {
  banner('Bannière', 150),
  frame('Cadre d’avatar', 100),
  nameFont('Police de pseudo', 100),
  nameEffect('Effet de pseudo', 150),
  profileEffect('Effet de profil', 100),
  surface('Style de l’interface', 150, interface: true),
  appFont('Police de l’interface', 100, interface: true),
  backdrop('Fond d’écran', 100, interface: true),
  accent('Couleur de l’interface', 150, interface: true);

  const ShopKind(this.label, this.price, {this.interface = false});
  final String label;
  final int price;

  /// Part of the app's look rather than of the profile card — what
  /// Podium++ adds to Podium+.
  final bool interface;
}

/// One thing the Boutique sells: a paid cosmetic of the profile card, or a
/// paid part of the app's look.
@immutable
class ShopItem {
  final ShopKind kind;

  /// Its id in its catalog — the enum value's name for a part of the look.
  final String id;
  const ShopItem(this.kind, this.id);

  /// How it's kept in AppUser.ownedItems: 'banner:aurora'.
  String get key => '${kind.name}:$id';
  int get price => kind.price;

  /// The membership that has it.
  PlusTier get tier => kind.interface ? PlusTier.plusPlus : PlusTier.plus;

  @override
  bool operator ==(Object other) => other is ShopItem && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);

  @override
  String toString() => key;
}

/// Whether [part] of an app look (a SurfaceStyle, FontPair, BackdropStyle
/// or AccentId) is a paid one.
bool isPaidPart(Object part) => kPlusSurfaces.contains(part) || kPlusFonts.contains(part) || kPlusBackdrops.contains(part) || kPlusAccents.contains(part);

/// The item [part] of an app look is sold as.
ShopItem partItem(Object part) => switch (part) {
      SurfaceStyle s => ShopItem(ShopKind.surface, s.name),
      FontPair f => ShopItem(ShopKind.appFont, f.name),
      BackdropStyle b => ShopItem(ShopKind.backdrop, b.name),
      AccentId a => ShopItem(ShopKind.accent, a.name),
      _ => throw ArgumentError.value(part, 'part', 'not a part of a look'),
    };

/// The part of an app look [item] is — null for a cosmetic of the card.
Object? itemPart(ShopItem item) {
  T? named<T extends Enum>(List<T> values) => values.where((v) => v.name == item.id).firstOrNull;
  return switch (item.kind) {
    ShopKind.surface => named(SurfaceStyle.values),
    ShopKind.appFont => named(FontPair.values),
    ShopKind.backdrop => named(BackdropStyle.values),
    ShopKind.accent => named(AccentId.values),
    _ => null,
  };
}

/// Everything the Boutique sells one by one.
final List<ShopItem> kShopItems = [
  for (final id in kPlusBanners) ShopItem(ShopKind.banner, id),
  for (final id in kPlusAvatarFrames) ShopItem(ShopKind.frame, id),
  for (final id in kPlusNameFonts) ShopItem(ShopKind.nameFont, id),
  for (final id in kPlusNameEffects) ShopItem(ShopKind.nameEffect, id),
  for (final id in kPlusProfileEffects) ShopItem(ShopKind.profileEffect, id),
  for (final s in kPlusSurfaces) partItem(s),
  for (final f in kPlusFonts) partItem(f),
  for (final b in kPlusBackdrops) partItem(b),
  for (final a in kPlusAccents) partItem(a),
];

final Set<String> _paidKeys = {for (final i in kShopItems) i.key};

/// Whether [item] is a paid one — sold in the Boutique, and in a membership.
bool isPaid(ShopItem item) => _paidKeys.contains(item.key);

/// A few items that go together, cheaper than one by one.
@immutable
class ShopPack {
  final String id;
  final String label;
  final String emoji;
  final String description;
  final List<ShopItem> items;
  final int price;
  const ShopPack({required this.id, required this.label, required this.emoji, required this.description, required this.items, this.price = 400});

  /// A theme, sold as its parts (see [themePack]).
  bool get isTheme => id.startsWith('theme:');

  int get fullPrice => items.fold(0, (sum, i) => sum + i.price);

  /// What the items still missing for a player who [owned] some would cost
  /// one by one.
  int restFor(Set<String> owned) => items.where((i) => !owned.contains(i.key)).fold(0, (sum, i) => sum + i.price);

  /// What it costs a player who already has some of it: never more than
  /// the rest bought one by one.
  int priceFor(Set<String> owned) {
    final rest = restFor(owned);
    return rest < price ? rest : price;
  }
}

const kShopPacks = [
  ShopPack(
    id: 'arcade',
    label: 'Pack Arcade',
    emoji: '🕹️',
    description: 'Deux bannières rétro, la police Arcade, l’effet Glitch et le cadre Néon.',
    items: [ShopItem(ShopKind.banner, 'arcade'), ShopItem(ShopKind.banner, 'invaders'), ShopItem(ShopKind.nameFont, 'arcade'), ShopItem(ShopKind.nameEffect, 'glitch'), ShopItem(ShopKind.frame, 'neon')],
  ),
  ShopPack(
    id: 'cosmos',
    label: 'Pack Cosmos',
    emoji: '🌌',
    description: 'Galaxie et Hyperespace, le cadre Étoiles, l’effet Holo et les étoiles filantes.',
    items: [ShopItem(ShopKind.banner, 'galaxy'), ShopItem(ShopKind.banner, 'warp'), ShopItem(ShopKind.frame, 'stars'), ShopItem(ShopKind.nameEffect, 'holo'), ShopItem(ShopKind.profileEffect, 'shooting')],
  ),
  ShopPack(
    id: 'brasier',
    label: 'Pack Brasier',
    emoji: '🔥',
    description: 'La bannière Lave, le cadre et l’effet Feu, les éclairs et la police Horreur.',
    items: [ShopItem(ShopKind.banner, 'lava'), ShopItem(ShopKind.frame, 'fire'), ShopItem(ShopKind.nameEffect, 'fire'), ShopItem(ShopKind.profileEffect, 'lightning'), ShopItem(ShopKind.nameFont, 'horror')],
  ),
  ShopPack(
    id: 'prestige',
    label: 'Pack Prestige',
    emoji: '👑',
    description: 'Les cadres Or et Royal, l’effet Or, la police Médiéval et les pièces d’or.',
    items: [ShopItem(ShopKind.frame, 'gold'), ShopItem(ShopKind.frame, 'royal'), ShopItem(ShopKind.nameEffect, 'gold'), ShopItem(ShopKind.nameFont, 'medieval'), ShopItem(ShopKind.profileEffect, 'coins')],
  ),
  ShopPack(
    id: 'ludo',
    label: 'Pack Ludothèque',
    emoji: '🎲',
    description: 'Cinq bannières de jeux de société : Échecs, Meeples, Plateau, Tapis de cartes et Casino.',
    items: [ShopItem(ShopKind.banner, 'chess'), ShopItem(ShopKind.banner, 'meeples'), ShopItem(ShopKind.banner, 'hexes'), ShopItem(ShopKind.banner, 'cards'), ShopItem(ShopKind.banner, 'casino')],
  ),
];

/// The themes the Boutique sells — the presets whose look has a paid part.
final List<AppearancePreset> kShopThemes = [for (final p in kAppearancePresets) if (p.look.paidParts.isNotEmpty) p];

/// [theme] as its paid parts: buying it buys each part still missing, at
/// its own price — a theme costs what its parts cost, no more, no less, so
/// a part alone is never dearer than in a theme — to keep and mix with
/// anything else.
ShopPack themePack(AppearancePreset theme) {
  final items = [for (final p in theme.look.paidParts) partItem(p)];
  return ShopPack(
    id: 'theme:${theme.id}',
    label: 'Thème ${theme.label}',
    emoji: theme.emoji,
    description: theme.description,
    items: items,
    price: items.fold(0, (sum, i) => sum + i.price),
  );
}

// ============================== the Fondateur offer ==============================

/// When the launch offer — Fondateur: Podium++ for good, paid once — stops
/// being sold: null while it runs until further notice. Setting a date
/// (`final`, then: DateTime has no const constructor) takes the plan off
/// the Podium+ page and, for whoever didn't take it, its exclusive badge
/// off the badges still to unlock (see kBadges).
const DateTime? kFounderOfferEnds = null;

/// Whether the Fondateur plan is on sale at [now].
bool founderOfferOpen(DateTime now) => kFounderOfferEnds == null || now.isBefore(kFounderOfferEnds!);

// ============================== jetons ==============================

/// Jetons are bought at 100 for 1 €: what [coins] are worth, in cents —
/// shown next to every price in jetons, so a price always reads in euros
/// too.
int coinsToCents(int coins) => coins;

/// A way to get jetons for real money: [coins] plus [bonus] for [cents].
/// SIMULATION: placeholder prices until the store's own come in.
@immutable
class CoinPack {
  final int coins;
  final int bonus;
  final int cents;
  final String? tag;
  const CoinPack({required this.coins, this.bonus = 0, required this.cents, this.tag});

  int get total => coins + bonus;

  /// Just [coins] at the base rate, to top a balance up by exactly what's
  /// missing — so nobody has to buy more jetons than they need.
  const CoinPack.exactly(this.coins)
      : bonus = 0,
        cents = coins,
        tag = null;
}

const kCoinPacks = [
  CoinPack(coins: 100, cents: 100),
  CoinPack(coins: 500, bonus: 50, cents: 500, tag: 'Populaire'),
  CoinPack(coins: 1000, bonus: 150, cents: 1000),
  CoinPack(coins: 2000, bonus: 400, cents: 2000, tag: 'Meilleure offre'),
];

/// "1 200" — with the narrow no-break space French groups digits with.
String groupDigits(int n) {
  final s = n.abs().toString();
  final out = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) out.write(' ');
    out.write(s[i]);
  }
  return out.toString();
}

/// "1 200 jetons", "1 jeton".
String coinsLabel(int n) => '${groupDigits(n)} jeton${n.abs() > 1 ? 's' : ''}';

/// "1,50 €".
String euros(int cents) => '${groupDigits(cents ~/ 100)},${(cents % 100).toString().padLeft(2, '0')} €';

// ============================== who may use what ==============================

/// What a player may use beyond the free catalog: what their membership
/// covers — the card with Podium+, the interface too with Podium++ — and
/// what they bought.
@immutable
class Unlocks {
  final PlusTier? tier;
  final Set<String> owned;
  const Unlocks({this.tier, this.owned = const {}});

  Unlocks.of(AppUser? user)
      : tier = user?.plus?.tier,
        owned = {...?user?.ownedItems};

  /// Whether their membership covers [item].
  bool covers(ShopItem item) => switch (tier) {
        null => false,
        PlusTier.plus => !item.kind.interface,
        PlusTier.plusPlus => true,
      };

  bool has(ShopItem item) => owns(item) || covers(item);

  bool owns(ShopItem item) => owned.contains(item.key);

  /// Whether the mark goes on [item] in a picker: a paid one the player
  /// doesn't own — what a membership gives lasts only as long as it.
  bool marks(ShopItem item) => isPaid(item) && !owns(item);

  /// The same for a [part] of an app look.
  bool marksPart(Object part) => isPaidPart(part) && !owns(partItem(part));
}

/// The membership [items] take all together: Podium++ as soon as one is a
/// part of the interface.
PlusTier tierFor(Iterable<ShopItem> items) => items.any((i) => i.kind.interface) ? PlusTier.plusPlus : PlusTier.plus;

extension PlusProfile on AppUser {
  /// The paid cosmetics this card wears.
  List<ShopItem> get paidPicks => [
        if (kPlusBanners.contains(banner)) ShopItem(ShopKind.banner, banner),
        if (kPlusAvatarFrames.contains(avatarFrame)) ShopItem(ShopKind.frame, avatarFrame!),
        if (kPlusNameFonts.contains(nameFont)) ShopItem(ShopKind.nameFont, nameFont!),
        if (kPlusNameEffects.contains(nameEffect)) ShopItem(ShopKind.nameEffect, nameEffect!),
        if (kPlusProfileEffects.contains(profileEffect)) ShopItem(ShopKind.profileEffect, profileEffect!),
      ];

  /// The paid cosmetics on this card that [unlocks] doesn't cover — what
  /// it would take to show it whole.
  List<ShopItem> lockedFor(Unlocks unlocks) => [for (final i in paidPicks) if (!unlocks.has(i)) i];

  /// This card with each cosmetic [unlocks] doesn't cover back to the free
  /// default.
  AppUser within(Unlocks unlocks) {
    final locked = lockedFor(unlocks);
    bool off(ShopKind kind, String? id) => id != null && locked.contains(ShopItem(kind, id));
    return copyWith(
      banner: off(ShopKind.banner, banner) ? kDefaultBanner : null,
      avatarFrame: off(ShopKind.frame, avatarFrame) ? () => null : null,
      nameFont: off(ShopKind.nameFont, nameFont) ? () => null : null,
      nameEffect: off(ShopKind.nameEffect, nameEffect) ? () => null : null,
      profileEffect: off(ShopKind.profileEffect, profileEffect) ? () => null : null,
    );
  }

  /// The card as everyone sees it: what its owner may show — all of it
  /// with a membership, otherwise the free picks and what they bought.
  /// Locked picks stay saved, back as soon as they're unlocked.
  AppUser get shown => within(Unlocks.of(this));
}

extension PlusLook on Appearance {
  /// The paid parts of this look (surface style, fonts, backdrop, accent).
  Set<Object> get paidParts => {
        for (final part in <Object>[surface, font, backdrop, accent])
          if (isPaidPart(part)) part,
      };

  bool allowedBy(Unlocks unlocks) => paidParts.every((p) => partUnlocked(p, unlocks));

  /// This look with each part [unlocks] doesn't cover swapped for a free
  /// one: the original surface and font, a plain background, and the named
  /// accent closest to a custom hue.
  Appearance within(Unlocks unlocks) {
    bool locked(Object part) => !partUnlocked(part, unlocks);
    return copyWith(
      surface: locked(surface) ? SurfaceStyle.flat : null,
      font: locked(font) ? FontPair.podium : null,
      backdrop: locked(backdrop) ? BackdropStyle.none : null,
      accent: locked(accent) ? _closestFreeAccent(customHue) : null,
    );
  }

  /// [part] put on this look.
  Appearance withPart(Object part) => switch (part) {
        SurfaceStyle s => copyWith(surface: s),
        FontPair f => copyWith(font: f),
        BackdropStyle b => copyWith(backdrop: b),
        AccentId a => copyWith(accent: a),
        _ => this,
      };
}

/// Whether [unlocks] covers [part] of an app look: a free part, Podium++,
/// or one the player bought — on its own or with a theme that has it.
bool partUnlocked(Object part, Unlocks unlocks) => !isPaidPart(part) || unlocks.has(partItem(part));

AccentId _closestFreeAccent(double hue) {
  double gap(AccentId a) {
    final d = (HSVColor.fromColor(a.color).hue - hue).abs() % 360;
    return d > 180 ? 360 - d : d;
  }

  return AccentId.values.where((a) => !kPlusAccents.contains(a)).reduce((a, b) => gap(b) < gap(a) ? b : a);
}
