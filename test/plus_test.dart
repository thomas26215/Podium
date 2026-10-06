// Podium+ and the Boutique (simulated purchases for now): what's paid, the
// membership and the jetons on the profile, and how the app keeps paid
// cosmetics and looks for whoever unlocked them — in the profile editor,
// on profile cards, in the appearance settings and in the Boutique.

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:podium/logic/plus.dart';
import 'package:podium/models/app_user.dart';
import 'package:podium/models/group.dart';
import 'package:podium/models/match.dart';
import 'package:podium/models/plus_membership.dart';
import 'package:podium/repositories/fakes.dart';
import 'package:podium/repositories/game_library_repository.dart';
import 'package:podium/repositories/games_repository.dart';
import 'package:podium/repositories/guests_repository.dart';
import 'package:podium/repositories/users_repository.dart';
import 'package:podium/screens/auth/auth_gate.dart';
import 'package:podium/screens/plus/plus_screen.dart';
import 'package:podium/screens/profile/edit_profile_screen.dart';
import 'package:podium/screens/profile/profile_header.dart';
import 'package:podium/screens/profile/profile_screen.dart';
import 'package:podium/screens/settings/settings_screen.dart';
import 'package:podium/screens/shop/shop_screen.dart';
import 'package:podium/state/app_state.dart';
import 'package:podium/theme/app_theme.dart';
import 'package:podium/widgets/appearance_scope.dart';
import 'package:podium/widgets/coins.dart';
import 'package:podium/widgets/plus_mark.dart';
import 'package:podium/widgets/profile_banners.dart';
import 'package:podium/widgets/profile_style.dart';

/// Podium+: the profile card.
final _membership = PlusMembership(plan: PlusPlan.yearly, since: DateTime(2026, 9, 1));

/// Podium++: the card and the whole interface.
final _membershipPlusPlus = PlusMembership(tier: PlusTier.plusPlus, plan: PlusPlan.yearly, since: DateTime(2026, 9, 1));

const _lea = AppUser(uid: 'lea', email: 'lea@test.fr', displayName: 'Léa', color: 0xFFFF5B34);

/// A Podium++ member, wearing paid cosmetics.
final _tom = AppUser(uid: 'tom', email: 'tom@test.fr', displayName: 'Tom', color: 0xFF5B4BE8, banner: 'aurora', nameEffect: 'holo', plus: _membershipPlusPlus);

({AppState state, FakeAuthRepository auth, FakeUsersRepository users}) _seed({AppUser lea = _lea}) {
  final usersMap = {'lea': lea, 'tom': _tom};
  final users = FakeUsersRepository(usersMap);
  final auth = FakeAuthRepository(seedUsers: usersMap);
  final group = Group(id: 'bandits', name: 'Les Bandits', emoji: '🃏', emojiBg: 0xFFFFE9E1, memberIds: const ['lea', 'tom'], ownerId: 'lea');
  final state = AppState(
    authRepo: auth,
    groupsRepo: FakeGroupsRepository(seedGroups: {'bandits': group}, users: users),
    gamesRepo: FakeGamesRepository(seed: {'bandits': List.of(kDefaultGames)}),
    matchesRepo: FakeMatchesRepository(seed: {
      'bandits': [
        GameMatch(
          id: 'm1',
          gameId: 'catan',
          groupId: 'bandits',
          mode: 'ffa',
          unit: 'points',
          lowWins: false,
          entries: const [MatchEntry(playerId: 'lea', points: 10), MatchEntry(playerId: 'tom', points: 8)],
          timeline: const [],
          createdAt: DateTime(2026, 3, 1, 20),
        ),
      ],
    }),
    tournamentsRepo: FakeTournamentsRepository(),
    usersRepo: users,
    guestsRepo: FakeGuestsRepository(),
    gameLibraryRepo: FakeGameLibraryRepository(),
    serversRepo: FakeServersRepository(users: users),
    serverGamesRepo: FakeGamesRepository(),
    serverMatchesRepo: FakeMatchesRepository(),
    serverTournamentsRepo: FakeTournamentsRepository(),
    eventsRepo: FakeEventsRepository(),
    messagesRepo: FakeMessagesRepository(),
    serverMessagesRepo: FakeMessagesRepository(),
  );
  return (state: state, auth: auth, users: users);
}

/// The app as main.dart builds it, signed in as [who] (Léa by default).
Future<({AppState state, FakeUsersRepository users, GlobalKey<NavigatorState> nav})> _pumpApp(WidgetTester tester, {AppUser lea = _lea, String who = 'lea'}) async {
  final seeded = _seed(lea: lea);
  final nav = GlobalKey<NavigatorState>();
  await tester.pumpWidget(ChangeNotifierProvider.value(
    value: seeded.state,
    child: ListenableBuilder(
      listenable: seeded.state,
      builder: (context, _) => MaterialApp(
        navigatorKey: nav,
        theme: buildAppTheme(),
        builder: (context, child) => AppearanceScope(child: child!),
        home: const AuthGate(),
      ),
    ),
  ));
  await tester.pump();
  seeded.auth.debugSignIn(who == 'tom' ? _tom : lea);
  await tester.pumpAndSettle();
  return (state: seeded.state, users: seeded.users, nav: nav);
}

/// Lets transitions play out on screens whose decorations loop forever
/// (Podium+ banners, the Podium+ page's sky), where pumpAndSettle can't.
Future<void> _settle(WidgetTester tester, {int frames = 12}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await _settle(tester, frames: 3);
  await tester.tap(finder);
  await _settle(tester);
}

Finder _banner(String id) => find.byWidgetPredicate((w) => w is ProfileBannerBackground && w.themeId == id);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => AppColors.configure(dark: false, appearance: const Appearance()));

  group('what is paid', () {
    test('every paid id is a real cosmetic, and each kind keeps free ones', () {
      final banners = {for (final b in kBannerThemes) b.id};
      expect(banners.containsAll(kPlusBanners), isTrue);
      // A taste of each theme stays free; the animated ones are all paid.
      for (final category in kBannerCategories.where((c) => c != 'Animées')) {
        expect(kBannerThemes.any((b) => b.category == category && !kPlusBanners.contains(b.id)), isTrue, reason: category);
      }
      expect(kBannerThemes.where((b) => b.category == 'Animées').every((b) => kPlusBanners.contains(b.id)), isTrue);
      expect(kPlusBanners, isNot(contains(kDefaultBanner)));

      void keepsFree(Set<String?> all, Set<String> plus, String kind) {
        expect(all.containsAll(plus), isTrue, reason: kind);
        expect(all.difference(plus).whereType<String>(), isNotEmpty, reason: kind);
      }

      keepsFree({for (final f in kAvatarFrames) f.id}, kPlusAvatarFrames, 'frames');
      keepsFree({for (final f in kNameFonts) f.id}, kPlusNameFonts, 'name fonts');
      keepsFree({for (final e in kNameEffects) e.id}, kPlusNameEffects, 'name effects');
      keepsFree({for (final e in kProfileEffects) e.id}, kPlusProfileEffects, 'profile effects');

      expect(SurfaceStyle.values.where((s) => !kPlusSurfaces.contains(s)), isNotEmpty);
      expect(FontPair.values.where((f) => !kPlusFonts.contains(f)), isNotEmpty);
      expect(BackdropStyle.values.where((b) => !kPlusBackdrops.contains(b)), isNotEmpty);
    });

    test('the free themes are Podium, Minimal and Papier; the others are sold one by one', () {
      expect(kAppearancePresets.where((p) => p.look.paidParts.isEmpty).map((p) => p.id), ['podium', 'minimal', 'paper']);
      expect(kShopThemes.map((t) => t.id), isNot(contains('podium')));
      expect(const Appearance().paidParts, isEmpty);
    });

    test('the Boutique sells every paid cosmetic and every paid part of the interface, priced in jetons; packs cost less than their items', () {
      expect(kShopItems.length, kPlusBanners.length + kPlusAvatarFrames.length + kPlusNameFonts.length + kPlusNameEffects.length + kPlusProfileEffects.length + kPlusSurfaces.length + kPlusFonts.length + kPlusBackdrops.length + kPlusAccents.length);
      expect(kShopItems.toSet().length, kShopItems.length, reason: 'no item twice');
      for (final item in kShopItems) {
        expect(item.price % 50, 0, reason: '$item: a multiple of 50, so a balance can be topped up by exactly what is missing');
        expect(isPaid(item), isTrue);
        if (item.kind.interface) expect(partItem(itemPart(item)!), item, reason: '$item: a part of the look, both ways');
      }
      for (final pack in kShopPacks) {
        expect(pack.items.every(isPaid), isTrue, reason: pack.id);
        expect(pack.price, lessThan(pack.fullPrice), reason: pack.id);
      }
      for (final theme in kShopThemes) {
        final pack = themePack(theme);
        expect(pack.items, isNotEmpty, reason: theme.id);
        expect(pack.items.every((i) => i.kind.interface), isTrue, reason: '${theme.id}: a pack of parts of the interface');
        expect(pack.isTheme, isTrue);
        expect(pack.priceFor(const {}), pack.fullPrice, reason: '${theme.id}: a theme costs exactly its parts');
        for (final part in pack.items) {
          expect(pack.priceFor({part.key}), pack.fullPrice - part.price, reason: '${theme.id}: a part already owned is not paid again');
        }
      }
      for (final pack in kCoinPacks) {
        expect(pack.cents, coinsToCents(pack.coins), reason: 'paid at 100 jetons for 1 €, the bonus on top');
      }
      expect(const CoinPack.exactly(50).cents, 50);
    });

    test('prices read in jetons and euros, French style', () {
      expect(coinsLabel(1), '1 jeton');
      expect(coinsLabel(1200), '1 200 jetons');
      expect(euros(150), '1,50 €');
      expect(euros(2000), '20,00 €');
    });

    test('a card shows what its owner may show: everything with Podium+, otherwise the free picks and what they bought', () {
      const card = AppUser(uid: 'a', email: '', displayName: 'A', color: 0, banner: 'aurora', avatarFrame: 'laurel', nameFont: 'comic', nameEffect: 'holo', profileEffect: 'confetti');
      expect(card.paidPicks, [const ShopItem(ShopKind.banner, 'aurora'), const ShopItem(ShopKind.nameEffect, 'holo')]);
      final free = card.within(const Unlocks());
      expect(free.paidPicks, isEmpty);
      expect(free.banner, kDefaultBanner);
      expect(free.avatarFrame, 'laurel');
      expect(free.nameFont, 'comic');
      expect(free.nameEffect, isNull);
      expect(free.profileEffect, 'confetti');

      expect(card.shown.banner, kDefaultBanner, reason: 'nothing bought, no Podium+');
      final bought = card.copyWith(ownedItems: ['nameEffect:holo']);
      expect(bought.shown.nameEffect, 'holo', reason: 'bought for good');
      expect(bought.shown.banner, kDefaultBanner);
      expect(bought.lockedFor(Unlocks.of(bought)), [const ShopItem(ShopKind.banner, 'aurora')]);
      expect(card.copyWith(plus: () => _membership).shown.banner, 'aurora', reason: 'a member shows it all');
    });

    test('an app look keeps the parts its player unlocked — a bought theme brings its own, to mix with anything', () {
      const look = Appearance(palette: PaletteId.mint, corners: CornerStyle.round, surface: SurfaceStyle.glass, font: FontPair.pixel, backdrop: BackdropStyle.aurora, accent: AccentId.custom, customHue: 215);
      expect(look.allowedBy(const Unlocks()), isFalse);
      final free = look.within(const Unlocks());
      expect(free.paidParts, isEmpty);
      expect(free.palette, PaletteId.mint);
      expect(free.corners, CornerStyle.round);
      expect(free.surface, SurfaceStyle.flat);
      expect(free.font, FontPair.podium);
      expect(free.backdrop, BackdropStyle.none);
      expect(free.accent, AccentId.blue, reason: 'the named accent closest to the custom hue');

      // Buying the Verre theme buys its parts: the glass surface, the
      // Géométrique font and the aurora backdrop.
      final glass = Unlocks(owned: {for (final i in themePack(kShopThemes.firstWhere((t) => t.id == 'glass')).items) i.key});
      final mixed = look.within(glass);
      expect(mixed.surface, SurfaceStyle.glass);
      expect(mixed.backdrop, BackdropStyle.aurora);
      expect(mixed.font, FontPair.podium, reason: 'Pixel comes with the Arcade theme, not Verre');
      expect(look.within(Unlocks(owned: {partItem(FontPair.pixel).key})).font, FontPair.pixel, reason: 'a part bought on its own');

      expect(look.allowedBy(const Unlocks(tier: PlusTier.plus)), isFalse, reason: 'Podium+ is the card only');
      expect(look.allowedBy(const Unlocks(tier: PlusTier.plusPlus)), isTrue, reason: 'Podium++ has the whole interface');
      const cardItem = ShopItem(ShopKind.banner, 'aurora');
      expect(const Unlocks(tier: PlusTier.plus).has(cardItem), isTrue);
      expect(tierFor([cardItem]), PlusTier.plus);
      expect(tierFor([cardItem, partItem(SurfaceStyle.glass)]), PlusTier.plusPlus);
    });

    test('a pack never costs more than what is still missing from it', () {
      final arcade = kShopPacks.firstWhere((p) => p.id == 'arcade');
      expect(arcade.priceFor(const {}), arcade.price);
      expect(arcade.priceFor({for (final i in arcade.items.skip(1)) i.key}), arcade.items.first.price);
      expect(arcade.priceFor({for (final i in arcade.items) i.key}), 0);
    });
  });

  group('membership and wallet', () {
    test('a membership survives the profile doc; anything unreadable is no membership', () {
      final m = PlusMembership(tier: PlusTier.plusPlus, plan: PlusPlan.yearly, since: DateTime(2026, 10, 6, 9), trialEndsAt: DateTime(2026, 10, 13, 9));
      final u = AppUser.fromDoc('lea', {'displayName': 'Léa', 'plus': m.toMap()});
      expect(u.plus, m);
      expect(u.isPlus, isTrue);
      expect(AppUser.fromDoc('lea', {'plus': {'plan': 'yearly', 'since': Timestamp.now()}}).plus?.tier, PlusTier.plus, reason: 'from before the tiers: Podium+');
      expect(AppUser.fromDoc('lea', {'displayName': 'Léa'}).isPlus, isFalse);
      expect(AppUser.fromDoc('lea', {'plus': {'plan': 'platine', 'since': Timestamp.now()}}).isPlus, isFalse);
      expect(AppUser.fromDoc('lea', {'plus': 'oui'}).isPlus, isFalse);
      expect(u.toProfileMap().containsKey('plus'), isFalse, reason: 'a profile save never writes it');
    });

    test('the jetons live on the private doc, what was bought on the public one — neither written by a profile save', () {
      final u = AppUser.fromDoc('lea', {'displayName': 'Léa', 'ownedItems': ['banner:aurora', 3]}, private: {'coins': 350});
      expect(u.ownedItems, ['banner:aurora']);
      expect(u.coins, 350);
      expect(AppUser.fromDoc('lea', {'displayName': 'Léa'}).coins, 0, reason: 'another player\'s account comes without its private doc');
      expect(u.toProfileMap().keys, isNot(contains('ownedItems')));
      expect(u.toProfileMap().keys, isNot(contains('coins')));
    });

    test('the next payment: after the free week, then every year — every month from the start — never for a lifetime', () {
      final yearly = PlusMembership(plan: PlusPlan.yearly, since: DateTime(2026, 10, 6), trialEndsAt: DateTime(2026, 10, 13));
      expect(yearly.inTrial(DateTime(2026, 10, 8)), isTrue);
      expect(yearly.nextPayment(DateTime(2026, 10, 8)), DateTime(2026, 10, 13));
      expect(yearly.inTrial(DateTime(2026, 10, 14)), isFalse);
      expect(yearly.nextPayment(DateTime(2026, 10, 14)), DateTime(2027, 10, 13));

      final monthly = PlusMembership(plan: PlusPlan.monthly, since: DateTime(2026, 1, 31));
      expect(monthly.nextPayment(DateTime(2026, 2, 1)), DateTime(2026, 2, 28), reason: 'a shorter month pays on its last day');
      expect(monthly.nextPayment(DateTime(2026, 3, 1)), DateTime(2026, 3, 31));

      expect(PlusMembership(plan: PlusPlan.lifetime, since: DateTime(2026)).nextPayment(DateTime(2030)), isNull);
    });
  });

  group('in the app', () {
    testWidgets('buying, then cancelling Podium+ (simulation) writes the membership — and its look goes with it', (tester) async {
      final app = await _pumpApp(tester);
      final state = app.state;
      expect(state.isPlus, isFalse);

      expect(await state.simulatePlusPurchase(PlusTier.plusPlus, PlusPlan.yearly), isTrue);
      await tester.pump();
      final m = app.users.users['lea']!.plus!;
      expect(m.tier, PlusTier.plusPlus);
      expect(m.plan, PlusPlan.yearly);
      expect(m.trialEndsAt!.difference(m.since), const Duration(days: 7), reason: 'a yearly plan opens on its free week');
      expect(state.isPlus, isTrue);

      await state.setAppearance(const Appearance(palette: PaletteId.lavender, surface: SurfaceStyle.glass, backdrop: BackdropStyle.aurora));
      expect(await state.simulatePlusCancel(), isTrue);
      await tester.pump();
      expect(app.users.users['lea']!.plus, isNull);
      expect(state.isPlus, isFalse);
      expect(state.appearance.paidParts, isEmpty, reason: 'the paid parts of the look went with it');
      expect(state.appearance.palette, PaletteId.lavender, reason: 'the free ones stay');
    });

    testWidgets('jetons are bought (simulation), then spent on items kept for good — never more than the balance', (tester) async {
      final app = await _pumpApp(tester);
      final state = app.state;
      expect(await state.buyWithCoins([const ShopItem(ShopKind.banner, 'aurora')], price: 150), isFalse);
      expect(state.flowError, 'Il vous manque ${coinsLabel(150)}.');

      expect(await state.simulateBuyCoins(kCoinPacks[1]), isTrue);
      await tester.pump();
      expect(app.users.users['lea']!.coins, 550, reason: '500 and 50 more');
      expect(await state.buyWithCoins([const ShopItem(ShopKind.banner, 'aurora')], price: 150), isTrue);
      await tester.pump();
      expect(app.users.users['lea']!.coins, 400);
      expect(app.users.users['lea']!.ownedItems, ['banner:aurora']);
      expect(state.unlocks.has(const ShopItem(ShopKind.banner, 'aurora')), isTrue);
    });

    testWidgets('a profile save never touches the membership nor the wallet', (tester) async {
      final app = await _pumpApp(tester, lea: _lea.copyWith(coins: 300, ownedItems: ['banner:aurora']));
      await app.state.simulatePlusPurchase(PlusTier.plus, PlusPlan.monthly);
      await tester.pump();
      expect(await app.state.saveProfile(app.state.currentUser!.copyWith(bio: 'Reine du Catan', plus: () => null, coins: 9999, ownedItems: const [])), isTrue);
      await tester.pump();
      final saved = app.users.users['lea']!;
      expect(saved.bio, 'Reine du Catan');
      expect(saved.plus?.plan, PlusPlan.monthly);
      expect(saved.coins, 300);
      expect(saved.ownedItems, ['banner:aurora']);
    });

    for (final (who, membership, kept) in [('nobody', null, false), ('Podium+', _membership, false), ('Podium++', _membershipPlusPlus, true)]) {
      testWidgets('signing in with $who ${kept ? 'keeps' : 'takes off'} a paid look saved on the device', (tester) async {
        SharedPreferences.setMockInitialValues({'appearance_v1': jsonEncode(const Appearance(palette: PaletteId.mint, surface: SurfaceStyle.neon).toJson())});
        final app = await _pumpApp(tester, lea: _lea.copyWith(plus: () => membership));
        expect(app.state.appearance.palette, PaletteId.mint, reason: 'the free part stays either way');
        expect(app.state.appearance.surface, kept ? SurfaceStyle.neon : SurfaceStyle.flat);
      });
    }

    testWidgets('a bought theme keeps its parts in the app\'s look, without Podium+', (tester) async {
      SharedPreferences.setMockInitialValues({'appearance_v1': jsonEncode(const Appearance(surface: SurfaceStyle.neon, font: FontPair.technical, backdrop: BackdropStyle.aurora).toJson())});
      final neon = themePack(kShopThemes.firstWhere((t) => t.id == 'neon'));
      final app = await _pumpApp(tester, lea: _lea.copyWith(ownedItems: [for (final i in neon.items) i.key]));
      expect(app.state.appearance.surface, SurfaceStyle.neon);
      expect(app.state.appearance.font, FontPair.technical);
      expect(app.state.appearance.backdrop, BackdropStyle.none, reason: 'the aurora comes with Verre, not bought');
    });

    testWidgets('a member\'s card shows all their picks and the mark; anyone else\'s, its free picks and what they bought', (tester) async {
      final app = await _pumpApp(tester, lea: _lea.copyWith(banner: 'lava', nameFont: () => 'comic', avatarFrame: () => 'fire', ownedItems: ['frame:fire']));

      app.state.openProfile('tom');
      unawaited(app.nav.currentState!.push(MaterialPageRoute(builder: (_) => const ProfileScreen())));
      await _settle(tester);
      final header = find.byType(ProfileHeaderCard);
      expect(find.descendant(of: header, matching: _banner('aurora')), findsOneWidget);
      expect(find.descendant(of: header, matching: find.byType(PlusMark)), findsOneWidget);

      app.state.openProfile('lea');
      await _settle(tester);
      expect(find.descendant(of: header, matching: _banner('lava')), findsNothing, reason: 'Léa neither bought it nor has Podium+');
      expect(find.descendant(of: header, matching: _banner(kDefaultBanner)), findsOneWidget);
      expect(find.descendant(of: header, matching: find.byWidgetPredicate((w) => w is FramedAvatar && w.frameId == 'fire')), findsOneWidget, reason: 'she bought the Feu frame');
      expect(find.descendant(of: header, matching: find.byType(PlusMark)), findsNothing);
      expect(find.text('Boutique'), findsOneWidget, reason: 'her own profile leads to the Boutique');
    });

    testWidgets('the editor tries a paid pick on the preview; saving offers to unlock it, or to save without it', (tester) async {
      final app = await _pumpApp(tester);
      unawaited(app.nav.currentState!.push(MaterialPageRoute(builder: (_) => const EditProfileScreen())));
      await _settle(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Joueur de Catan invaincu depuis 2019…'), 'Reine du Catan');
      await _tap(tester, find.text('Carte'));
      await _tap(tester, find.text('Aurore boréale'));
      expect(find.descendant(of: find.byType(ProfileHeaderCard), matching: _banner('aurora')), findsOneWidget, reason: 'tried on the preview');
      expect(find.text('Une option de votre carte est à débloquer.'), findsOneWidget);

      await _tap(tester, find.text('Enregistrer'));
      expect(find.text('Débloquer « Aurore boréale »'), findsOneWidget);
      expect(find.text('Ou tout débloquer avec Podium+'), findsOneWidget);
      expect(find.text('Simulation : aucun paiement n’est effectué.'), findsOneWidget);
      await _tap(tester, find.text('Enregistrer sans ces options'));
      expect(find.byType(EditProfileScreen), findsNothing, reason: 'saved and closed');
      expect(app.users.users['lea']!.bio, 'Reine du Catan');
      expect(app.users.users['lea']!.banner, kDefaultBanner);
      await tester.pump(const Duration(seconds: 3)); // the toast goes
    });

    testWidgets('buying a pick with jetons from the editor\'s save keeps it — topping up just what is missing', (tester) async {
      final app = await _pumpApp(tester, lea: _lea.copyWith(coins: 100));
      unawaited(app.nav.currentState!.push(MaterialPageRoute(builder: (_) => const EditProfileScreen())));
      await _settle(tester);
      await _tap(tester, find.text('Carte'));
      await _tap(tester, find.text('Aurore boréale'));
      await _tap(tester, find.text('Enregistrer'));

      await _tap(tester, find.text('Obtenir les ${coinsLabel(50)} manquants · ${euros(50)}'));
      expect(app.users.users['lea']!.coins, 150, reason: 'exactly what was missing');
      await _tap(tester, find.text('Acheter pour ${coinsLabel(150)}'));
      expect(find.byType(EditProfileScreen), findsNothing, reason: 'bought, then saved and closed');
      final saved = app.users.users['lea']!;
      expect(saved.coins, 0);
      expect(saved.ownedItems, ['banner:aurora']);
      expect(saved.banner, 'aurora');
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('joining Podium+ from the editor\'s save keeps the pick', (tester) async {
      final app = await _pumpApp(tester);
      unawaited(app.nav.currentState!.push(MaterialPageRoute(builder: (_) => const EditProfileScreen())));
      await _settle(tester);
      await _tap(tester, find.text('Carte'));
      await _tap(tester, find.text('Aurore boréale'));
      await _tap(tester, find.text('Enregistrer'));

      await _tap(tester, find.text('Ou tout débloquer avec Podium+'));
      await _tap(tester, find.text('Essayer 7 jours gratuitement'));
      expect(find.text('Bienvenue dans Podium+ !'), findsOneWidget);
      expect(app.users.users['lea']!.plus?.plan, PlusPlan.yearly);
      await _tap(tester, find.text('Continuer'));
      expect(find.byType(PlusScreen), findsNothing);
      expect(find.byType(EditProfileScreen), findsNothing, reason: 'unlocked, then saved and closed');
      expect(app.users.users['lea']!.banner, 'aurora');
      expect(app.users.users['lea']!.ownedItems, isEmpty, reason: 'with Podium+, nothing to buy');
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('a member manages their membership on the Podium+ page, and can cancel it', (tester) async {
      final app = await _pumpApp(tester, lea: _lea.copyWith(plus: () => _membership));
      unawaited(PlusScreen.open(app.nav.currentContext!));
      await _settle(tester);
      expect(find.text('Vous êtes membre Podium+'), findsOneWidget);
      expect(find.text('Podium+ · annuel'), findsOneWidget);
      expect(find.text('Passer à Podium++'), findsOneWidget, reason: 'the way up');
      expect(find.text('Essayer 7 jours gratuitement'), findsNothing, reason: 'no plans to pick');

      await _tap(tester, find.text('Résilier l’abonnement'));
      await tester.tap(find.text('Résilier'));
      await _settle(tester);
      expect(find.byType(PlusScreen), findsNothing);
      expect(app.users.users['lea']!.plus, isNull);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('settings: a free theme applies at once; a paid one, or one part, is bought first', (tester) async {
      final app = await _pumpApp(tester, lea: _lea.copyWith(coins: 300));
      unawaited(app.nav.currentState!.push(MaterialPageRoute(builder: (_) => const SettingsScreen())));
      await tester.pumpAndSettle();

      await _tap(tester, find.text('Minimal'));
      expect(app.state.appearance.surface, SurfaceStyle.outlined);

      await _tap(tester, find.text('Soft UI'));
      expect(find.text('☁️  Thème Soft UI'), findsOneWidget);
      expect(find.text('Ou tout débloquer avec Podium++'), findsOneWidget, reason: 'the interface takes Podium++');
      await _tap(tester, find.byTooltip('Fermer'));
      expect(app.state.appearance.surface, SurfaceStyle.outlined, reason: 'closed without buying: nothing changes');

      // Soft UI's one paid part is its surface: the theme costs no more.
      await _tap(tester, find.text('Soft UI'));
      await _tap(tester, find.text('Acheter pour ${coinsLabel(ShopKind.surface.price)}'));
      expect(app.users.users['lea']!.ownedItems, ['surface:neumorphic']);
      expect(app.users.users['lea']!.coins, 300 - ShopKind.surface.price);
      expect(app.state.appearance.surface, SurfaceStyle.neumorphic);

      await _tap(tester, find.text('Couleurs'));
      await _tap(tester, find.text('Sur mesure'));
      await _tap(tester, find.text('Acheter pour ${coinsLabel(ShopKind.accent.price)}'));
      expect(app.users.users['lea']!.ownedItems, contains('accent:custom'));
      expect(app.state.appearance.accent, AccentId.custom);
    });

    testWidgets('a Podium+ member moves up to Podium++ for the interface', (tester) async {
      final app = await _pumpApp(tester, lea: _lea.copyWith(plus: () => _membership));
      unawaited(app.nav.currentState!.push(MaterialPageRoute(builder: (_) => const SettingsScreen())));
      await tester.pumpAndSettle();

      await _tap(tester, find.text('Soft UI'));
      await _tap(tester, find.text('Ou passer à Podium++'));
      expect(find.text('Passez à Podium++'), findsOneWidget);
      expect(find.text('Essayer 7 jours gratuitement'), findsNothing, reason: 'no second free week for a member');
      await _tap(tester, find.text('Passer à Podium++ pour 29,99 € par an'));
      expect(app.users.users['lea']!.plus?.tier, PlusTier.plusPlus);
      expect(app.users.users['lea']!.plus?.trialEndsAt, isNull);
      await _tap(tester, find.text('Continuer'));
      expect(find.byType(PlusScreen), findsNothing);
      expect(app.state.appearance.surface, SurfaceStyle.neumorphic, reason: 'unlocked, then applied');
      expect(app.users.users['lea']!.ownedItems, isEmpty, reason: 'with Podium++, nothing to buy');
    });

    testWidgets('without Podium+, the dice only roll looks the player has unlocked', (tester) async {
      final app = await _pumpApp(tester);
      unawaited(app.nav.currentState!.push(MaterialPageRoute(builder: (_) => const SettingsScreen())));
      await tester.pumpAndSettle();
      for (var i = 0; i < 15; i++) {
        await tester.tap(find.text('Au hasard'));
        await tester.pumpAndSettle();
        expect(app.state.appearance.allowedBy(app.state.unlocks), isTrue, reason: 'roll $i');
      }
    });

    testWidgets('the Boutique: jetons bought, an item bought for good and put on, a pack for less', (tester) async {
      final app = await _pumpApp(tester);
      unawaited(ShopScreen.open(app.nav.currentContext!));
      await tester.pumpAndSettle();

      expect(find.descendant(of: find.byType(AppBar), matching: find.byType(CoinAmount)), findsOneWidget, reason: 'the balance, up top');
      await _tap(tester, find.descendant(of: find.byType(AppBar), matching: find.byIcon(Icons.add_rounded)));
      await _tap(tester, find.text(euros(1000)));
      expect(app.users.users['lea']!.coins, 1150, reason: '1 000 and 150 more');

      await _tap(tester, find.text('Aurore boréale'));
      await _tap(tester, find.text('Acheter pour ${coinsLabel(150)}'));
      expect(app.users.users['lea']!.ownedItems, ['banner:aurora']);
      expect(find.text('À vous pour toujours.'), findsOneWidget);
      await _tap(tester, find.text('Utiliser'));
      expect(app.users.users['lea']!.banner, 'aurora', reason: 'put on the card');

      // Back up to the packs, above the items.
      await tester.drag(find.descendant(of: find.byType(ShopScreen), matching: find.byType(Scrollable)).first, const Offset(0, 3000));
      await _settle(tester);
      await _tap(tester, find.text('🌌  Pack Cosmos'));
      await _tap(tester, find.text('Acheter pour ${coinsLabel(400)}'));
      final lea = app.users.users['lea']!;
      expect(lea.coins, 1150 - 150 - 400);
      expect(lea.ownedItems, containsAll(['banner:galaxy', 'banner:warp', 'frame:stars', 'nameEffect:holo', 'profileEffect:shooting']));

      // The interface's half: a theme, as the pack of its parts.
      await tester.drag(find.descendant(of: find.byType(ShopScreen), matching: find.byType(Scrollable)).first, const Offset(0, 3000));
      await _settle(tester);
      await _tap(tester, find.text('Interface'));
      // Verre is its style (150), its font (100) and its backdrop (100).
      await _tap(tester, find.text('🔮  Verre'));
      expect(find.text('Prix du thème'), findsOneWidget);
      await _tap(tester, find.text('Acheter pour ${coinsLabel(350)}'));
      expect(app.users.users['lea']!.ownedItems, containsAll(['surface:glass', 'appFont:geometric', 'backdrop:aurora']));
      expect(app.users.users['lea']!.coins, 1150 - 150 - 400 - 350);
      await _tap(tester, find.text('Utiliser'));
      expect(app.state.appearance.surface, SurfaceStyle.glass, reason: 'the theme put on');
      await tester.pump(const Duration(seconds: 3));
    });
  });
}
