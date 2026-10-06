import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/plus.dart';
import '../../models/app_user.dart';
import '../../models/plus_membership.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/appearance_preview.dart';
import '../../widgets/coins.dart';
import '../../widgets/common.dart';
import '../../widgets/option_chip.dart';
import '../../widgets/plus_mark.dart';
import '../../widgets/profile_banners.dart';
import '../../widgets/segmented_control.dart';
import '../plus/plus_screen.dart';
import '../profile/profile_header.dart';
import 'coin_sheet.dart';
import 'shop_item_view.dart';
import 'unlock_sheet.dart';

/// A shelf of the Boutique: the items of one [kind] — or, without one, the
/// themes, sold as packs of their parts.
typedef _Shelf = ({String label, ShopKind? kind});

/// The profile card's shelves — what Podium+ covers…
const _cardShelves = <_Shelf>[
  (label: 'Bannières', kind: ShopKind.banner),
  (label: 'Cadres', kind: ShopKind.frame),
  (label: 'Polices', kind: ShopKind.nameFont),
  (label: 'Effets de pseudo', kind: ShopKind.nameEffect),
  (label: 'Effets de profil', kind: ShopKind.profileEffect),
];

/// …and the interface's — what Podium++ adds.
const _interfaceShelves = <_Shelf>[
  (label: 'Thèmes', kind: null),
  (label: 'Styles', kind: ShopKind.surface),
  (label: 'Fonds', kind: ShopKind.backdrop),
  (label: 'Polices', kind: ShopKind.appFont),
  (label: 'Couleur', kind: ShopKind.accent),
];

/// The Boutique: every paid cosmetic of the profile card and every paid
/// part of the interface, to buy one by one with jetons and keep for good —
/// plus packs, cheaper, and the themes, as packs of their parts. Podium+
/// unlocks the card all at once instead, Podium++ the interface too.
///
/// SIMULATION: jetons and items are "bought" without any payment.
class ShopScreen extends StatefulWidget {
  /// Opens on the interface's half rather than the card's.
  final bool interface;
  const ShopScreen({super.key, this.interface = false});

  static Future<void> open(BuildContext context, {bool interface = false}) {
    return Navigator.of(context).push(MaterialPageRoute(builder: (_) => ShopScreen(interface: interface)));
  }

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  late bool _interface = widget.interface;
  late _Shelf _shelf = (widget.interface ? _interfaceShelves : _cardShelves).first;
  final _scroll = ScrollController();

  /// What sits above the shelves' chips — how far down they pin.
  final _topKey = GlobalKey();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _pickHalf(bool interface) => setState(() {
        _interface = interface;
        _shelf = (interface ? _interfaceShelves : _cardShelves).first;
      });

  /// Shows [shelf] — from its first row, when the Boutique was scrolled
  /// further down than that.
  void _pickShelf(_Shelf shelf) {
    setState(() => _shelf = shelf);
    final top = (_topKey.currentContext?.findRenderObject() as RenderBox?)?.size.height;
    if (top != null && _scroll.hasClients && _scroll.offset > top) _scroll.jumpTo(top);
  }

  Future<void> _openItem(AppState app, AppUser me, ShopItem item) async {
    await showUnlockSheet(
      context,
      items: [item],
      title: shopItemLabel(item),
      message: item.kind.label,
      preview: _ItemPreview(item: item, user: me, app: app),
      plusPreview: item.kind.interface ? null : wearing(me, item),
      plusPreviewLook: item.kind.interface ? lookWith(app.appearance, item) : null,
      plusPreviewDark: app.isDark,
      onUse: () => app.equipItem(item),
    );
  }

  Future<void> _openTheme(AppState app, AppearancePreset theme) async {
    final dark = theme.mode == ThemeMode.dark || (theme.mode == null && app.isDark);
    await showUnlockSheet(
      context,
      pack: themePack(theme),
      title: '${theme.emoji}  Thème ${theme.label}',
      message: '${theme.description} Achetez-le pour en garder chaque élément, à mélanger avec le reste de vos réglages.',
      preview: _LookPreview(child: themePreview(theme, base: app.appearance, dark: app.isDark)),
      plusPreviewLook: app.appearance.withLookOf(theme.look),
      plusPreviewDark: dark,
      onUse: () async {
        await app.applyAppearancePreset(theme);
        return true;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final me = app.currentUser;
    final unlocks = app.unlocks;
    final shelves = _interface ? _interfaceShelves : _cardShelves;
    final kind = _shelf.kind;
    final List<Widget> tiles = kind == null
        ? [for (final t in kShopThemes) _ThemeTile(theme: t, app: app, onTap: () => _openTheme(app, t))]
        : [
            if (me != null)
              for (final i in kShopItems)
                if (i.kind == kind) _ItemTile(item: i, user: me, app: app, onTap: () => _openItem(app, me, i)),
          ];
    final needed = _interface ? PlusTier.plusPlus : PlusTier.plus;
    final covered = unlocks.tier != null && (needed == PlusTier.plus || unlocks.tier == PlusTier.plusPlus);
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.canvas,
        elevation: 0,
        foregroundColor: AppColors.ink,
        title: Text('Boutique', style: bodyFont(size: 17, weight: FontWeight.w800, color: AppColors.ink)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(child: _Wallet(coins: app.coins, onTap: () => showCoinSheet(context))),
          ),
        ],
      ),
      body: me == null
          ? const SizedBox.shrink()
          : SafeArea(
              child: CustomScrollView(
                controller: _scroll,
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      key: _topKey,
                      padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SegmentedControl(labels: const ['Carte de profil', 'Interface'], selectedIndex: _interface ? 1 : 0, fontSize: 13, onChanged: (i) => _pickHalf(i == 1)),
                          const SizedBox(height: 16),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            transitionBuilder: appSwitchTransition,
                            child: KeyedSubtree(
                              key: ValueKey((_interface, unlocks.tier)),
                              child: covered
                                  ? _MemberNote(tier: unlocks.tier!, interface: _interface)
                                  : _PlusBanner(tier: needed, upgrade: unlocks.tier != null, onTap: () => PlusScreen.open(context, minTier: needed)),
                            ),
                          ),
                          if (!_interface) ...[
                            const SizedBox(height: 22),
                            const SectionHeader(title: 'Packs'),
                            SizedBox(
                              height: 196,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                clipBehavior: Clip.none,
                                itemCount: kShopPacks.length,
                                separatorBuilder: (_, _) => const SizedBox(width: 12),
                                itemBuilder: (context, i) => FadeSlideIn(
                                  delay: staggerDelay(i, baseMs: 60, stepMs: 50),
                                  child: _PackCard(
                                    pack: kShopPacks[i],
                                    unlocks: unlocks,
                                    onTap: () => showUnlockSheet(context, pack: kShopPacks[i], title: '${kShopPacks[i].emoji}  ${kShopPacks[i].label}', message: kShopPacks[i].description),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  // The shelves stay pinned over them as they scroll.
                  SliverPersistentHeader(pinned: true, delegate: _ShelvesBar(shelves: shelves, selected: _shelf, onPick: _pickShelf)),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                    sliver: SliverGrid.count(
                      key: ValueKey(_shelf),
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.95,
                      children: [
                        for (final (i, tile) in tiles.indexed) FadeSlideIn(delay: staggerDelay(i, stepMs: 35), child: tile),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// The shelves of one half, as chips pinned over them — on a frosted strip
/// of the screen's own background.
class _ShelvesBar extends SliverPersistentHeaderDelegate {
  final List<_Shelf> shelves;
  final _Shelf selected;
  final ValueChanged<_Shelf> onPick;
  const _ShelvesBar({required this.shelves, required this.selected, required this.onPick});

  static const _height = 62.0;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          color: AppColors.bg.withValues(alpha: 0.86),
          alignment: Alignment.centerLeft,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                for (final shelf in shelves) ...[
                  OptionChip(label: shelf.label, selected: shelf == selected, onTap: () => onPick(shelf)),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Cheap, and keeps up with the app's look changing too.
  @override
  bool shouldRebuild(_ShelvesBar old) => true;
}

/// The balance, in the app bar — tapping it opens the jeton packs.
class _Wallet extends StatelessWidget {
  final int coins;
  final VoidCallback onTap;
  const _Wallet({required this.coins, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Solde : ${coinsLabel(coins)}. Recharger',
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(9, 6, 7, 6),
          decoration: chipDecoration(radius: 999, border: AppColors.gold.withValues(alpha: 0.6), borderWidth: 1.5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CoinAmount(coins, size: 14),
              const SizedBox(width: 6),
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
                child: const Icon(Icons.add_rounded, size: 14, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The membership covering the half on show, offered at the top of it —
/// or, for a Podium+ member on the interface's half, the way up.
class _PlusBanner extends StatelessWidget {
  final PlusTier tier;
  final bool upgrade;
  final VoidCallback onTap;
  const _PlusBanner({required this.tier, required this.upgrade, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final line = switch ((tier, upgrade)) {
      (PlusTier.plus, _) => 'Toute la carte de profil d’un coup. 7 jours offerts.',
      (PlusTier.plusPlus, false) => 'La carte et toute l’interface d’un coup. 7 jours offerts.',
      (PlusTier.plusPlus, true) => 'Passez à Podium++ : toute l’interface en plus de votre carte.',
    };
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(1.6),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.lg + 1.6), gradient: const LinearGradient(colors: kPlusGradient)),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [kPlusNight, Color.lerp(kPlusNight, kPlusGradient[2], 0.4)!]),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PlusWordmark(size: 19, tier: tier),
                    const SizedBox(height: 7),
                    Text(line, style: bodyFont(size: 12.5, weight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.78), height: 1.35)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(Icons.chevron_right_rounded, size: 22, color: Colors.white.withValues(alpha: 0.85)),
            ],
          ),
        ),
      ),
    );
  }
}

/// For a member whose membership covers the half on show: it's all theirs
/// already — buying keeps it for good.
class _MemberNote extends StatelessWidget {
  final PlusTier tier;
  final bool interface;
  const _MemberNote({required this.tier, required this.interface});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(radius: AppRadius.lg),
      child: Row(
        children: [
          PlusMark(size: 24, rim: false, tier: tier),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Avec ${tier.label}, ${interface ? 'toute l’interface' : 'toute la carte'} est déjà à vous. Ce que vous achetez ici reste à vous pour toujours, même sans abonnement.',
              style: bodyFont(size: 13, weight: FontWeight.w700, color: AppColors.ink2, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

/// A pack on its shelf: its first banner behind, what's in it, the price
/// and what it saves.
class _PackCard extends StatelessWidget {
  final ShopPack pack;
  final Unlocks unlocks;
  final VoidCallback onTap;
  const _PackCard({required this.pack, required this.unlocks, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final price = pack.priceFor(unlocks.owned);
    final rest = pack.restFor(unlocks.owned);
    final banner = pack.items.where((i) => i.kind == ShopKind.banner).firstOrNull;
    final saving = rest == 0 ? 0 : ((1 - price / rest) * 100).round();
    return Pressable(
      onTap: onTap,
      child: SizedBox(
        width: 250,
        child: Container(
          decoration: cardDecoration(radius: AppRadius.xl),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (banner != null) ProfileBannerBackground(themeId: banner.id, phase: 0.4) else const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [kPlusNight, Color(0xFF3B2F8F)]))),
                      const DecoratedBox(
                        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x00000000), Color(0xB0000000)])),
                      ),
                      Positioned(
                        left: 14,
                        right: 14,
                        bottom: 10,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${pack.emoji}  ${pack.label}', style: bodyFont(size: 16, weight: FontWeight.w800, color: Colors.white)),
                            const SizedBox(height: 2),
                            Text('${pack.items.length} objets', style: bodyFont(size: 12, weight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.75))),
                          ],
                        ),
                      ),
                      if (saving > 0)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(7)),
                            child: Text('−$saving %', style: bodyFont(size: 11, weight: FontWeight.w800, color: Colors.white)),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                  child: price == 0
                      ? const _Owned()
                      : Row(
                          children: [
                            CoinAmount(price, size: 15),
                            if (rest > price) ...[
                              const SizedBox(width: 8),
                              Text(groupDigits(rest), style: dispFont(size: 12.5, weight: FontWeight.w600, color: AppColors.mut).copyWith(decoration: TextDecoration.lineThrough)),
                            ],
                            const Spacer(),
                            Text(euros(coinsToCents(price)), style: bodyFont(size: 12, weight: FontWeight.w700, color: AppColors.mut)),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Possédé", with a tick.
class _Owned extends StatelessWidget {
  const _Owned();

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(Icons.check_circle_rounded, size: 15, color: AppColors.green),
        const SizedBox(width: 5),
        Text('Possédé', style: bodyFont(size: 12.5, weight: FontWeight.w800, color: AppColors.green)),
      ]);
}

/// "Inclus", with the mark of the member's [tier].
class _Included extends StatelessWidget {
  final PlusTier tier;
  const _Included({required this.tier});

  @override
  Widget build(BuildContext context) => Row(children: [
        PlusMark(size: 14, rim: false, tier: tier),
        const SizedBox(width: 6),
        Text('Inclus', style: bodyFont(size: 12.5, weight: FontWeight.w800, color: AppColors.ink2)),
      ]);
}

/// A price in jetons, and in euros on the right.
class _Price extends StatelessWidget {
  final int coins;
  const _Price(this.coins);

  @override
  Widget build(BuildContext context) => Row(children: [
        CoinAmount(coins, size: 13.5),
        const Spacer(),
        Text(euros(coinsToCents(coins)), style: bodyFont(size: 11.5, weight: FontWeight.w700, color: AppColors.mut)),
      ]);
}

/// A tile of a shelf: a picture, a name, and where it stands for the
/// player — bought, included in their membership, or its price.
class _Tile extends StatelessWidget {
  final Widget picture;
  final String label;
  final Widget status;
  final VoidCallback onTap;
  const _Tile({required this.picture, required this.label, required this.status, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: cardDecoration(radius: AppRadius.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(AppRadius.md), child: SizedBox.expand(child: picture))),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyFont(size: 13.5, weight: FontWeight.w800, color: AppColors.ink)),
            ),
            const SizedBox(height: 4),
            Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 2), child: status),
          ],
        ),
      ),
    );
  }
}

/// One item on its shelf.
class _ItemTile extends StatelessWidget {
  final ShopItem item;
  final AppUser user;
  final AppState app;
  final VoidCallback onTap;
  const _ItemTile({required this.item, required this.user, required this.app, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final unlocks = app.unlocks;
    return _Tile(
      picture: ShopItemThumb(item: item, user: user, base: app.appearance, dark: app.isDark),
      label: shopItemLabel(item),
      status: unlocks.owns(item)
          ? const _Owned()
          : unlocks.covers(item)
              ? _Included(tier: unlocks.tier!)
              : _Price(item.price),
      onTap: onTap,
    );
  }
}

/// A theme on its shelf — priced as the pack of its parts.
class _ThemeTile extends StatelessWidget {
  final AppearancePreset theme;
  final AppState app;
  final VoidCallback onTap;
  const _ThemeTile({required this.theme, required this.app, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final unlocks = app.unlocks;
    final pack = themePack(theme);
    final price = pack.priceFor(unlocks.owned);
    return _Tile(
      picture: themePreview(theme, base: app.appearance, dark: app.isDark),
      label: '${theme.emoji}  ${theme.label}',
      status: price == 0
          ? const _Owned()
          : pack.items.every(unlocks.covers)
              ? _Included(tier: unlocks.tier!)
              : _Price(price),
      onTap: onTap,
    );
  }
}

/// The app in miniature, framed for a sheet.
class _LookPreview extends StatelessWidget {
  final Widget child;
  const _LookPreview({required this.child});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: AspectRatio(
          aspectRatio: AppearancePreview.designSize.aspectRatio,
          child: ClipRRect(borderRadius: BorderRadius.circular(AppRadius.xl), child: child),
        ),
      ),
    );
  }
}

/// An item shown off in its sheet: on the player's own card — or, for a
/// part of the interface, the app wearing it.
class _ItemPreview extends StatelessWidget {
  final ShopItem item;
  final AppUser user;
  final AppState app;
  const _ItemPreview({required this.item, required this.user, required this.app});

  @override
  Widget build(BuildContext context) {
    if (item.kind.interface) return _LookPreview(child: lookPreview(lookWith(app.appearance, item), dark: app.isDark));
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 230),
      child: LayoutBuilder(
        builder: (context, box) => FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topCenter,
          child: SizedBox(width: box.maxWidth, child: ProfileHeaderCard(user: wearing(user.shown, item), subtitle: 'Aperçu')),
        ),
      ),
    );
  }
}
