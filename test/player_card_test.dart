// A player's card — banner, avatar decoration, name font and effect —
// carried wherever they show up: their decorated avatar and styled name
// everywhere, their banner as a nameplate where players are listed, their
// whole card for the leader. Only what they may show (PlusProfile.shown).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
import 'package:podium/state/app_state.dart';
import 'package:podium/theme/app_theme.dart';
import 'package:podium/widgets/appearance_scope.dart';
import 'package:podium/widgets/player_card.dart';
import 'package:podium/widgets/podium.dart';
import 'package:podium/widgets/profile_banners.dart';
import 'package:podium/widgets/profile_style.dart';
import 'package:podium/widgets/rank_row.dart';

final _membership = PlusMembership(plan: PlusPlan.yearly, since: DateTime(2026, 9, 1));

/// A Cador+ member, dressed up from head to toe.
final _lea = AppUser(uid: 'lea', email: 'lea@test.fr', displayName: 'Léa', color: 0xFFFF5B34, banner: 'aurora', avatarFrame: 'neon', nameEffect: 'holo', plus: _membership);

/// Free picks only: the Dés banner, the Lauriers decoration.
const _nina = AppUser(uid: 'nina', email: 'nina@test.fr', displayName: 'Nina', color: 0xFF1F9D57, banner: 'dice', avatarFrame: 'laurel');

/// Paid picks she never unlocked: none of it shows.
const _tom = AppUser(uid: 'tom', email: 'tom@test.fr', displayName: 'Tom', color: 0xFF5B4BE8, banner: 'lava', avatarFrame: 'fire');

/// The app's plain look.
const _karim = AppUser(uid: 'karim', email: 'karim@test.fr', displayName: 'Karim', color: 0xFFE8A93B);

AppState _seed() {
  final usersMap = {for (final u in [_lea, _nina, _tom, _karim]) u.uid: u};
  final users = FakeUsersRepository(usersMap);
  final auth = FakeAuthRepository(seedUsers: usersMap);
  final group = Group(id: 'bandits', name: 'Les Bandits', emoji: '🃏', emojiBg: 0xFFFFE9E1, memberIds: const ['lea', 'nina', 'tom', 'karim'], ownerId: 'karim');
  GameMatch m(String id, Map<String, int> points) => GameMatch(
        id: id,
        gameId: 'catan',
        groupId: 'bandits',
        mode: 'ffa',
        unit: 'points',
        lowWins: false,
        entries: [for (final e in points.entries) MatchEntry(playerId: e.key, points: e.value)],
        timeline: const [],
        createdAt: DateTime(2026, 3, 1, 20),
      );
  final state = AppState(
    authRepo: auth,
    groupsRepo: FakeGroupsRepository(seedGroups: {'bandits': group}, users: users),
    gamesRepo: FakeGamesRepository(seed: {'bandits': List.of(kDefaultGames)}),
    // Léa leads; Nina, Tom and Karim follow.
    matchesRepo: FakeMatchesRepository(seed: {
      'bandits': [
        m('m1', {'lea': 10, 'nina': 8, 'tom': 6, 'karim': 4}),
        m('m2', {'lea': 10, 'nina': 8, 'tom': 6, 'karim': 4}),
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
  auth.debugSignIn(_karim);
  return state;
}

/// The app signed in as Karim. Its leader's card plays on the home screen:
/// no pumpAndSettle.
Future<AppState> _pumpApp(WidgetTester tester) async {
  final state = _seed();
  await tester.pumpWidget(ChangeNotifierProvider.value(
    value: state,
    child: ListenableBuilder(
      listenable: state,
      builder: (context, _) => MaterialApp(theme: buildAppTheme(), builder: (context, child) => AppearanceScope(child: child!), home: const AuthGate()),
    ),
  ));
  await _settle(tester, frames: 50);
  return state;
}

Future<void> _settle(WidgetTester tester, {int frames = 12}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Finder _plateOf(String uid) => find.byWidgetPredicate((w) => w is Nameplate && w.user.uid == uid);
Finder _frameOf(String frame) => find.byWidgetPredicate((w) => w is FramedAvatar && w.frameId == frame);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a card is dressed up by what its owner may show: free picks, or paid ones unlocked', () {
    expect(_lea.dressedUp, isTrue, reason: 'a member shows it all');
    expect(_nina.dressedUp, isTrue, reason: 'free picks');
    expect(_tom.dressedUp, isFalse, reason: 'paid picks never unlocked show nothing');
    expect(_tom.copyWith(ownedItems: ['frame:fire']).dressedUp, isTrue, reason: 'bought for good');
    expect(_karim.dressedUp, isFalse);
    expect(_karim.copyWith(nameFont: () => 'comic').dressedUp, isTrue, reason: 'a free name font');
  });

  // A widget test: the fonts it asks for are never fetched.
  testWidgets('a name in a sentence takes its owner\'s font, and only theirs', (tester) async {
    final base = const TextStyle(fontSize: 13);
    final styled = _karim.copyWith(nameFont: () => 'comic');
    final span = nameInText('Gagné par Karim · 10 pts', styled, base);
    expect(span.toPlainText(), 'Gagné par Karim · 10 pts');
    expect(span.children, hasLength(3));
    expect((span.children![1] as TextSpan).style!.fontFamily, nameFontStyle('comic', 13).fontFamily);
    expect(nameInText('Gagné par Karim', _karim, base).children, isNull, reason: 'the app\'s font: nothing to set apart');
    expect(nameInText('Victoire du groupe', styled, base).children, isNull, reason: 'not named');
    final ga = _karim.copyWith(displayName: 'Ga', nameFont: () => 'comic');
    expect((nameInText('Gagné par Ga', ga, base).children![0] as TextSpan).text, 'Gagné par ', reason: 'the name as a whole word, not the start of "Gagné"');
    expect(playerNameStyle(_tom.copyWith(nameFont: () => 'horror'), base), base, reason: 'a paid font never unlocked');
  });

  testWidgets('an avatar wears its decoration — still in a list, playing in a spotlight', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Row(children: [
        PlayerAvatar(_nina, size: 38),
        PlayerAvatar(_lea, size: 38, live: true),
        const PlayerAvatar(_tom, size: 38),
        const PlayerAvatar(null, size: 38),
      ]),
    ));
    final laurel = tester.widget<FramedAvatar>(_frameOf('laurel'));
    expect(laurel.phase, kStillFramePhase, reason: 'held still: a list costs one paint per row');
    expect(tester.widget<FramedAvatar>(_frameOf('neon')).phase, isNull, reason: 'live');
    expect(_frameOf('fire'), findsNothing, reason: 'not unlocked');
    expect(tester.getSize(find.byType(PlayerAvatar).first), const Size(38, 38), reason: 'the decoration takes no room');
    expect(find.text('?'), findsOneWidget, reason: 'an unknown player');
  });

  testWidgets('the leader shows on their card on the home screen; the top three on their nameplates', (tester) async {
    await _pumpApp(tester);
    expect(find.byWidgetPredicate((w) => w is ProfileBannerBackground && w.themeId == 'aurora' && w.phase == null), findsOneWidget, reason: 'Léa leads: her banner plays behind her');
    expect(find.byWidgetPredicate((w) => w is StyledName && w.text == 'Léa' && w.effectId == 'holo' && w.phase == null), findsOneWidget, reason: 'her name effect, live');
    expect(find.byWidgetPredicate((w) => w is FramedAvatar && w.frameId == 'neon' && w.phase == null), findsOneWidget, reason: 'her decoration, live');

    final rows = find.byType(MiniRankRow);
    expect(rows, findsNWidgets(3));
    expect(find.descendant(of: rows, matching: _plateOf('lea')), findsOneWidget);
    expect(find.descendant(of: rows, matching: _plateOf('nina')), findsOneWidget, reason: 'free picks are a card too');
    expect(find.descendant(of: rows, matching: _plateOf('tom')), findsNothing, reason: 'nothing unlocked: the plain row');
    expect(find.descendant(of: rows, matching: _frameOf('fire')), findsNothing);
  });

  testWidgets('the ranking: decorations play on the podium, nameplates hold still below it', (tester) async {
    final state = await _pumpApp(tester);
    state.setTab(AppTab.ranking);
    await _settle(tester);
    final podium = find.byType(PodiumWidget);
    expect(find.descendant(of: podium, matching: _plateOf('lea')), findsOneWidget, reason: 'a dressed-up player stands on a copy of their card');
    expect(find.descendant(of: podium, matching: _plateOf('tom')), findsNothing);
    expect(tester.widget<FramedAvatar>(find.descendant(of: podium, matching: _frameOf('laurel'))).phase, isNull);

    final rest = find.byType(RankRow);
    expect(rest, findsOneWidget, reason: 'Karim, fourth');
    expect(find.descendant(of: rest, matching: find.byType(Nameplate)), findsNothing);
  });
}
