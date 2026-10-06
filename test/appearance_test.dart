// The "Apparence & réglages" customization: the Appearance model, how it
// resolves into colours and surfaces, and the settings screen applying it
// across the whole app.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:podium/models/app_user.dart';
import 'package:podium/models/group.dart';
import 'package:podium/models/match.dart';
import 'package:podium/repositories/fakes.dart';
import 'package:podium/repositories/game_library_repository.dart';
import 'package:podium/repositories/games_repository.dart';
import 'package:podium/repositories/guests_repository.dart';
import 'package:podium/repositories/users_repository.dart';
import 'package:podium/screens/auth/auth_gate.dart';
import 'package:podium/screens/profile/profile_screen.dart';
import 'package:podium/screens/settings/settings_screen.dart';
import 'package:podium/state/app_state.dart';
import 'package:podium/theme/app_theme.dart';
import 'package:podium/theme/backdrop.dart';
import 'package:podium/widgets/appearance_preview.dart';
import 'package:podium/widgets/appearance_scope.dart';
import 'package:podium/widgets/common.dart';

const _lea = AppUser(uid: 'lea', email: 'lea@test.fr', displayName: 'Léa', color: 0xFFFF5B34);
const _tom = AppUser(uid: 'tom', email: 'tom@test.fr', displayName: 'Tom', color: 0xFF5B4BE8);

({AppState state, FakeAuthRepository auth}) _seed() {
  final usersMap = {'lea': _lea, 'tom': _tom};
  final users = FakeUsersRepository(usersMap);
  final auth = FakeAuthRepository(seedUsers: usersMap);
  final group = Group(id: 'bandits', name: 'Les Bandits', emoji: '🃏', emojiBg: 0xFFFFE9E1, memberIds: const ['lea', 'tom'], ownerId: 'lea');
  final match = GameMatch(
    id: 'm1',
    gameId: 'catan',
    groupId: 'bandits',
    mode: 'ffa',
    unit: 'points',
    lowWins: false,
    entries: const [MatchEntry(playerId: 'lea', points: 10), MatchEntry(playerId: 'tom', points: 8)],
    timeline: const [],
    createdAt: DateTime.now(),
  );
  final state = AppState(
    authRepo: auth,
    groupsRepo: FakeGroupsRepository(seedGroups: {'bandits': group}, users: users),
    gamesRepo: FakeGamesRepository(seed: {'bandits': List.of(kDefaultGames)}),
    matchesRepo: FakeMatchesRepository(seed: {'bandits': [match]}),
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
  return (state: state, auth: auth);
}

/// The app as main.dart builds it — theme rebuilt on every change, the
/// appearance scope under MaterialApp — signed in as Léa.
Future<({AppState state, GlobalKey<NavigatorState> nav})> _pumpApp(WidgetTester tester) async {
  final seeded = _seed();
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
  seeded.auth.debugSignIn(_lea);
  await tester.pumpAndSettle();
  return (state: seeded.state, nav: nav);
}

Future<void> _openSettings(WidgetTester tester, GlobalKey<NavigatorState> nav, {String? tab}) async {
  nav.currentState!.push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
  await tester.pumpAndSettle();
  if (tab != null) {
    await tester.ensureVisible(find.text(tab));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tab));
    await tester.pumpAndSettle();
  }
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => AppColors.configure(dark: false, appearance: const Appearance()));

  group('Appearance', () {
    test('survives a JSON round trip', () {
      const a = Appearance(
        palette: PaletteId.mint,
        accent: AccentId.custom,
        customHue: 123,
        surface: SurfaceStyle.neumorphic,
        corners: CornerStyle.round,
        font: FontPair.editorial,
        backdrop: BackdropStyle.aurora,
        animatedBackdrop: true,
        textSize: TextSize.large,
        navBar: NavBarStyle.floating,
        navLabels: false,
        reduceMotion: true,
      );
      expect(Appearance.fromJson(jsonDecode(jsonEncode(a.toJson())) as Map<String, dynamic>), a);
    });

    test('falls back to the defaults for what it does not know', () {
      final a = Appearance.fromJson({'palette': 'velvet', 'surface': 'glass', 'customHue': 'red', 'corners': 3});
      expect(a, const Appearance(surface: SurfaceStyle.glass));
    });

    test('a theme preset sets the look but keeps the comfort settings', () {
      const mine = Appearance(textSize: TextSize.huge, reduceMotion: true, customHue: 42);
      final soft = kAppearancePresets.firstWhere((p) => p.id == 'soft');
      final applied = mine.withLookOf(soft.look);
      expect(applied.surface, SurfaceStyle.neumorphic);
      expect(applied.textSize, TextSize.huge);
      expect(applied.reduceMotion, isTrue);
      expect(applied.customHue, 42);
      expect(presetMatching(applied), same(soft));
      expect(presetMatching(applied.copyWith(corners: CornerStyle.sharp)), isNull, reason: 'tweaked: no longer that theme');
    });

    test('every theme preset has a look of its own', () {
      for (final a in kAppearancePresets) {
        for (final b in kAppearancePresets) {
          if (!identical(a, b)) expect(a.look.sameLookAs(b.look), isFalse, reason: '${a.id} vs ${b.id}');
        }
      }
    });
  });

  group('tokens', () {
    test('the default look keeps the original Podium colours', () {
      final light = AppTokens.resolve(const Appearance(), dark: false);
      expect(light.bg, const Color(0xFFF4F2EC));
      expect(light.card, const Color(0xFFFFFFFF));
      expect(light.ink, const Color(0xFF18171C));
      expect(light.line, const Color(0x14181713));
      expect(light.accent, const Color(0xFFFF5B34));
      expect(light.accentSoft, const Color(0xFFFFE9E1));
      expect(light.canvas, light.bg, reason: 'no backdrop: screens paint their own background');
      final dark = AppTokens.resolve(const Appearance(), dark: true);
      expect(dark.bg, const Color(0xFF16151A));
      expect(dark.card, const Color(0xFF201F26));
      expect(dark.hero, const Color(0xFF2E2C36));
      expect(dark.accentSoft, const Color(0xFF402A20));
    });

    test('the flat style draws cards exactly as before', () {
      final t = AppTokens.resolve(const Appearance(), dark: false);
      expect(t.surface(radius: 20), BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0x14181713)), borderRadius: BorderRadius.circular(20)));
      expect(
        t.surface(radius: 16, borderWidth: 1.5, fill: t.accentSoft, border: t.accent, selected: true),
        BoxDecoration(color: t.accentSoft, border: Border.all(color: t.accent, width: 1.5), borderRadius: BorderRadius.circular(16)),
      );
      expect(t.well(radius: 13), BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(13)));
      expect(t.heroSurface(radius: 24), BoxDecoration(color: t.hero, borderRadius: BorderRadius.circular(24)));
    });

    test('a backdrop makes screens see-through', () {
      final t = AppTokens.resolve(const Appearance(backdrop: BackdropStyle.dots), dark: false);
      expect(t.canvas.a, 0);
    });

    test('corner styles scale every radius', () {
      AppColors.configure(dark: false, appearance: const Appearance(corners: CornerStyle.sharp));
      expect(AppRadius.xl, closeTo(20 * 0.3, 1e-9));
      expect(AppRadius.scaled(12), closeTo(12 * 0.3, 1e-9));
      AppColors.configure(dark: false, appearance: const Appearance());
      expect(AppRadius.xl, 20);
    });

    test('text stays readable in every palette, mode and surface style', () {
      for (final p in PaletteId.values) {
        for (final s in SurfaceStyle.values) {
          for (final dark in [false, true]) {
            final t = AppTokens.resolve(Appearance(palette: p, surface: s), dark: dark);
            final card = Color.alphaBlend(t.card, t.bg);
            final where = '${p.name} / ${s.name} / ${dark ? 'dark' : 'light'}';
            expect(contrastRatio(t.ink, t.bg), greaterThan(7), reason: where);
            expect(contrastRatio(t.ink, card), greaterThan(7), reason: where);
            expect(contrastRatio(t.mut, card), greaterThan(2.5), reason: where);
          }
        }
      }
    });

    test('white text stays readable on every accent, custom hues included', () {
      for (final a in AccentId.values.where((a) => a != AccentId.custom)) {
        expect(contrastRatio(a.color, Colors.white), greaterThanOrEqualTo(3), reason: a.name);
      }
      for (var h = 0; h < 360; h += 3) {
        expect(contrastRatio(accentForHue(h.toDouble()), Colors.white), greaterThanOrEqualTo(3.2), reason: 'hue $h');
      }
    });

    test('decorations glide from one style to another', () {
      final flat = AppTokens.resolve(const Appearance(), dark: false).surface(radius: 20);
      final neu = AppTokens.resolve(const Appearance(surface: SurfaceStyle.neumorphic), dark: false).surface(radius: 20);
      expect(Decoration.lerp(flat, neu, 0.5), isA<SurfaceDecoration>());
      expect(Decoration.lerp(neu, flat, 0.5), isA<SurfaceDecoration>());
      expect(Decoration.lerp(neu, neu, 0.3), neu);
    });
  });

  testWidgets('every surface style paints every kind of surface, light and dark', (tester) async {
    for (final s in SurfaceStyle.values) {
      for (final dark in [false, true]) {
        final t = AppTokens.resolve(Appearance(surface: s), dark: dark);
        final decorations = [
          t.surface(radius: 20),
          t.surface(radius: 12, depth: 0.55, selected: true, fill: t.accentSoft, border: t.accent, borderWidth: 1.5),
          t.surface(radius: 12, selected: true, fill: t.ink),
          t.surface(radius: 16, fill: t.greenSoft, border: t.green),
          t.surface(shape: BoxShape.circle),
          t.surface(radius: 16, fill: Colors.transparent),
          t.surface(borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), bottomRight: Radius.circular(4))),
          t.well(radius: 13),
          t.well(radius: 11, bordered: true, fill: t.accentSoft),
          t.track(radius: 14),
          t.segmentThumb(radius: 10),
          t.heroSurface(radius: 24),
          t.heroSurface(radius: 12, depth: 0.4),
          t.accentButton(radius: 16),
          t.accentButton(radius: 16, enabled: false),
          t.accentButton(radius: 20, strong: true),
          t.floatingBar(radius: 26),
        ];
        await tester.pumpWidget(MaterialApp(
          home: ColoredBox(
            color: t.bg,
            child: Wrap(children: [for (final d in decorations) Container(width: 70, height: 44, margin: const EdgeInsets.all(8), decoration: d)]),
          ),
        ));
        expect(tester.takeException(), isNull, reason: '${s.name} ${dark ? 'dark' : 'light'}');
      }
    }
  });

  testWidgets('every backdrop paints, still and drifting', (tester) async {
    for (final b in BackdropStyle.values) {
      final t = AppTokens.resolve(Appearance(backdrop: b, animatedBackdrop: true), dark: b.index.isOdd);
      await tester.pumpWidget(MaterialApp(home: SizedBox(width: 390, height: 844, child: BackdropView(tokens: t))));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull, reason: b.name);
    }
    // Stops the drifting ones before the test ends.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reduced motion holds a drifting backdrop still', (tester) async {
    final t = AppTokens.resolve(const Appearance(backdrop: BackdropStyle.aurora, animatedBackdrop: true, reduceMotion: true), dark: false);
    await tester.pumpWidget(MaterialApp(home: BackdropView(tokens: t)));
    // A ticking backdrop would keep this from ever settling.
    await tester.pumpAndSettle();
  });

  testWidgets('reduced motion shows entering content at once', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: MediaQuery(data: MediaQueryData(disableAnimations: true), child: FadeSlideIn(delay: Duration(seconds: 1), child: Text('Bonjour'))),
    ));
    expect(find.byType(Opacity), findsNothing);
    expect(find.text('Bonjour'), findsOneWidget);
  });

  testWidgets('the appearance is kept on the device', (tester) async {
    final first = _seed().state;
    await first.setAppearance(const Appearance(surface: SurfaceStyle.clay, backdrop: BackdropStyle.bubbles));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('appearance_v1'), isNotNull);

    final second = _seed().state;
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump();
    expect(second.appearance.surface, SurfaceStyle.clay);
    expect(second.appearance.backdrop, BackdropStyle.bubbles);
    first.dispose();
    second.dispose();
  });

  testWidgets('the accent picked before appearances existed carries over', (tester) async {
    SharedPreferences.setMockInitialValues({'accent_preset': 'blue'});
    final state = _seed().state;
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump();
    expect(state.appearance.accent, AccentId.blue);
    expect(AppColors.accent, AccentId.blue.color);
    state.dispose();
  });

  testWidgets('picking a theme restyles the whole app, screens underneath included', (tester) async {
    final app = await _pumpApp(tester);
    final oldInk = AppColors.ink;
    // The profile — with its const section headers — stays underneath.
    app.state.openProfile('lea');
    app.nav.currentState!.push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Statistiques'), findsOneWidget);
    await _openSettings(tester, app.nav);

    await _tapVisible(tester, find.text('Soft UI'));
    expect(app.state.appearance.surface, SurfaceStyle.neumorphic);
    expect(app.state.appearance.palette, PaletteId.glacier);
    expect(AppColors.ink, isNot(oldInk));

    // Every text of every route — the home screen under the settings too,
    // const widgets and all — picked the new ink up (but for the previews
    // of the other themes, drawn in their own colours).
    final inPreviews = find.descendant(of: find.byType(AppearancePreview, skipOffstage: false), matching: find.byType(Text, skipOffstage: false), skipOffstage: false);
    final previewTexts = tester.widgetList<Text>(inPreviews).toSet();
    final stale = tester.widgetList<Text>(find.byType(Text, skipOffstage: false)).where((t) => t.style?.color == oldInk && !previewTexts.contains(t));
    expect(stale, isEmpty);
    expect(find.byIcon(Icons.check_circle_rounded), findsWidgets, reason: 'the picked theme is ticked');
  });

  testWidgets('a night theme switches to dark mode', (tester) async {
    final app = await _pumpApp(tester);
    await _openSettings(tester, app.nav);
    await _tapVisible(tester, find.text('Néon'));
    expect(app.state.appearance.surface, SurfaceStyle.neon);
    expect(app.state.themeMode, ThemeMode.dark);
    expect(AppColors.isDark, isTrue);
  });

  testWidgets('each setting can be picked on its own', (tester) async {
    final app = await _pumpApp(tester);
    await _openSettings(tester, app.nav, tab: 'Couleurs');
    await _tapVisible(tester, find.text('Menthe'));
    expect(app.state.appearance.palette, PaletteId.mint);
    await _tapVisible(tester, find.text('Lagon'));
    expect(app.state.appearance.accent, AccentId.teal);

    await _tapVisible(tester, find.text('Effets'));
    await _tapVisible(tester, find.text('Argile'));
    expect(app.state.appearance.surface, SurfaceStyle.clay);
    await _tapVisible(tester, find.text('Ronds'));
    expect(app.state.appearance.corners, CornerStyle.round);

    await _tapVisible(tester, find.text('Fond'));
    await _tapVisible(tester, find.text('Quadrillage'));
    expect(app.state.appearance.backdrop, BackdropStyle.grid);
    expect(AppColors.canvas.a, 0);

    await _tapVisible(tester, find.text('Texte'));
    await _tapVisible(tester, find.text('Éditoriale'));
    expect(app.state.appearance.font, FontPair.editorial);
    await _tapVisible(tester, find.text('Grand'));
    expect(app.state.appearance.textSize, TextSize.large);

    await _tapVisible(tester, find.text('Réglages'));
    await _tapVisible(tester, find.text('Flottante'));
    expect(app.state.appearance.navBar, NavBarStyle.floating);
    await _tapVisible(tester, find.text('Réduire les animations'));
    expect(app.state.appearance.reduceMotion, isTrue);

    // And back to where it all started.
    await _tapVisible(tester, find.text('Réinitialiser l’apparence'));
    await tester.tap(find.text('Réinitialiser'));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(app.state.appearance, const Appearance());
  });

  testWidgets('the custom hue slider sets any accent, saved where it stops', (tester) async {
    final app = await _pumpApp(tester);
    await _openSettings(tester, app.nav, tab: 'Couleurs');
    await _tapVisible(tester, find.text('Sur mesure'));
    expect(app.state.appearance.accent, AccentId.custom);

    final slider = find.byWidgetPredicate((w) => w is GestureDetector && w.onHorizontalDragUpdate != null);
    await tester.ensureVisible(slider);
    await tester.pumpAndSettle();
    await tester.drag(slider, const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(app.state.appearance.customHue, 0);
    expect(AppColors.accent, accentForHue(0));
    final saved = Appearance.fromJson(jsonDecode((await SharedPreferences.getInstance()).getString('appearance_v1')!) as Map<String, dynamic>);
    expect(saved.customHue, 0);
  });

  testWidgets('every settings tab renders in every surface style', (tester) async {
    final app = await _pumpApp(tester);
    for (final s in [SurfaceStyle.flat, SurfaceStyle.neumorphic, SurfaceStyle.glass, SurfaceStyle.brutalist]) {
      await app.state.setAppearance(Appearance(surface: s, backdrop: s == SurfaceStyle.glass ? BackdropStyle.aurora : BackdropStyle.none));
      await _openSettings(tester, app.nav);
      for (final tab in ['Couleurs', 'Effets', 'Fond', 'Texte', 'Réglages', 'Thèmes']) {
        await _tapVisible(tester, find.text(tab));
        expect(tester.takeException(), isNull, reason: '${s.name}: $tab');
      }
      app.nav.currentState!.pop();
      await tester.pumpAndSettle();
    }
  });
}
