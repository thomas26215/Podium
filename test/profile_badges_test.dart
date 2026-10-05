import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:podium/logic/badges.dart';
import 'package:podium/models/app_user.dart';
import 'package:podium/models/game.dart';
import 'package:podium/models/group.dart';
import 'package:podium/models/match.dart';
import 'package:podium/models/tournament.dart';
import 'package:podium/repositories/fakes.dart';
import 'package:podium/repositories/game_library_repository.dart';
import 'package:podium/repositories/games_repository.dart';
import 'package:podium/repositories/guests_repository.dart';
import 'package:podium/repositories/users_repository.dart';
import 'package:podium/screens/auth/auth_gate.dart';
import 'package:podium/state/app_state.dart';
import 'package:podium/widgets/badge_widgets.dart';
import 'package:podium/widgets/profile_banners.dart';
import 'package:podium/widgets/profile_style.dart';

GameMatch _match(String id, List<String> winners, List<String> losers, {String game = 'catan', DateTime? at, String mode = 'ffa'}) => GameMatch(
      id: id,
      gameId: game,
      groupId: 'grp',
      mode: mode,
      unit: 'points',
      lowWins: false,
      entries: [
        for (final w in winners) MatchEntry(playerId: w, points: 10, teamId: mode == 'team' ? 'A' : null),
        for (final l in losers) MatchEntry(playerId: l, points: 1, teamId: mode == 'team' ? 'B' : null),
      ],
      timeline: const [],
      createdAt: at ?? DateTime(2026, 3, 1, 20),
    );

void main() {
  group('computeBadgeStats', () {
    test('counts the best winning streak, broken by a loss', () {
      final ms = [
        _match('1', ['a'], ['b'], at: DateTime(2026, 1, 1)),
        _match('2', ['a'], ['b'], at: DateTime(2026, 1, 2)),
        _match('3', ['b'], ['a'], at: DateTime(2026, 1, 3)),
        _match('4', ['a'], ['b'], at: DateTime(2026, 1, 4)),
        _match('5', ['a'], ['b'], at: DateTime(2026, 1, 5)),
        _match('6', ['a'], ['b'], at: DateTime(2026, 1, 6)),
      ];
      final s = computeBadgeStats(uid: 'a', matches: ms.reversed.toList());
      expect(s.played, 6);
      expect(s.wins, 5);
      expect(s.bestWinStreak, 3);
      expect(badgeById('streak3')!.isEarned(s), isTrue);
      expect(badgeById('streak5')!.isEarned(s), isFalse);
    });

    test('ignores matches the player was not in', () {
      final s = computeBadgeStats(uid: 'c', matches: [_match('1', ['a'], ['b'])]);
      expect(s.played, 0);
      expect(badgeById('first_game')!.isEarned(s), isFalse);
    });

    test('distinct games, wins at one game, busiest day, night games and team wins', () {
      final day = DateTime(2026, 5, 2);
      final ms = [
        _match('1', ['a'], ['b'], game: 'catan', at: day.add(const Duration(hours: 1))),
        _match('2', ['a'], ['b'], game: 'catan', at: day.add(const Duration(hours: 20))),
        _match('3', ['b'], ['a'], game: 'skyjo', at: day.add(const Duration(hours: 21))),
        _match('4', ['a', 'c'], ['b', 'd'], game: 'petanque', mode: 'team', at: DateTime(2026, 5, 3, 15)),
      ];
      final s = computeBadgeStats(uid: 'a', matches: ms);
      expect(s.distinctGames, 3);
      expect(s.bestWinsAtOneGame, 2);
      expect(s.bestDay, 3);
      expect(s.nightGames, 1);
      expect(s.teamWins, 1);
      expect(badgeById('night_owl')!.isEarned(s), isTrue);
    });

    test('a completed tournament won by the player earns Champion', () {
      final t = Tournament(
        id: 't',
        groupId: 'grp',
        gameId: 'catan',
        name: 'Coupe',
        format: TournamentFormat.singleElimination,
        entrants: const [TournamentEntrant(id: 'e1', playerIds: ['a']), TournamentEntrant(id: 'e2', playerIds: ['b'])],
        matches: const [],
        status: 'completed',
        winnerEntrantId: 'e1',
        createdAt: DateTime(2026),
      );
      expect(badgeById('champion')!.isEarned(computeBadgeStats(uid: 'a', matches: const [], tournaments: [t])), isTrue);
      expect(badgeById('champion')!.isEarned(computeBadgeStats(uid: 'b', matches: const [], tournaments: [t])), isFalse);
    });

    test('progress is capped at 1', () {
      final s = computeBadgeStats(uid: 'a', matches: const [], ownedGames: 80);
      expect(badgeById('game_library')!.progress(s), 1.0);
      expect(badgeById('collector')!.progress(const BadgeStats(ownedGames: 5)), 0.5);
    });
  });

  test('every banner id resolves, unknown ones fall back to the default', () {
    for (final b in kBannerThemes) {
      expect(bannerThemeById(b.id).id, b.id);
      expect(kBannerCategories, contains(b.category));
    }
    expect(bannerThemeById('n_existe_pas').id, kDefaultBanner);
  });

  test('customization catalogs have unique ids, and state knows every platform', () {
    Set<Object?> ids(Iterable<Object?> xs) => xs.toSet();
    expect(ids(kBannerThemes.map((b) => b.id)).length, kBannerThemes.length);
    expect(ids(kAvatarFrames.map((f) => f.id)).length, kAvatarFrames.length);
    expect(ids(kNameFonts.map((f) => f.id)).length, kNameFonts.length);
    expect(ids(kNameEffects.map((f) => f.id)).length, kNameEffects.length);
    expect(ids(kProfileEffects.map((f) => f.id)).length, kProfileEffects.length);
    expect(ids(kTitles.map((t) => t.id)).length, kTitles.length);
    expect(AppState.gamePlatformIds, kGamePlatforms.map((p) => p.id).toSet());
    for (final t in kTitles) {
      if (t.badgeId != null) expect(badgeById(t.badgeId!), isNotNull, reason: t.id);
    }
  });

  group('AppUser profile fields', () {
    test('round-trip through the public doc, and the emoji replaces the initial', () {
      const u = AppUser(
        uid: 'x',
        email: 'x@test.fr',
        displayName: 'léa',
        color: 0xFF000000,
        bio: 'Salut',
        avatarEmoji: '🦊',
        banner: 'arcade',
        avatarFrame: 'neon',
        showcasedBadges: ['first_win'],
        ownedGameIds: ['catan'],
        favoriteGameId: 'catan',
      );
      final back = AppUser.fromDoc('x', {...u.toProfileMap(), 'badges': ['first_win']});
      expect(back.bio, 'Salut');
      expect(back.avatarEmoji, '🦊');
      expect(back.initial, '🦊');
      expect(back.letter, 'L');
      expect(back.banner, 'arcade');
      expect(back.avatarFrame, 'neon');
      expect(back.badges, ['first_win']);
      expect(back.showcasedBadges, ['first_win']);
      expect(back.ownedGameIds, ['catan']);
      expect(back.favoriteGameId, 'catan');
    });

    test('the Discord-style fields round-trip too', () {
      const u = AppUser(
        uid: 'x',
        email: '',
        displayName: 'Léa',
        color: 0,
        pronouns: 'elle',
        status: 'Partante pour un Catan',
        statusEmoji: '🎲',
        titleId: 'vainqueur',
        nameFont: 'arcade',
        nameEffect: 'neon',
        profileEffect: 'confetti',
        gameAccounts: {'steam': 'lea_42', 'switch': 'SW-1234-5678-9012'},
      );
      final back = AppUser.fromDoc('x', u.toProfileMap());
      expect(back.pronouns, 'elle');
      expect(back.status, 'Partante pour un Catan');
      expect(back.statusEmoji, '🎲');
      expect(back.titleId, 'vainqueur');
      expect(back.nameFont, 'arcade');
      expect(back.nameEffect, 'neon');
      expect(back.profileEffect, 'confetti');
      expect(back.gameAccounts, {'steam': 'lea_42', 'switch': 'SW-1234-5678-9012'});
    });

    test('an old doc without the new fields still loads', () {
      final u = AppUser.fromDoc('x', {'displayName': 'Tom', 'color': 1});
      expect(u.initial, 'T');
      expect(u.banner, kDefaultBanner);
      expect(u.badges, isEmpty);
      expect(u.avatarEmoji, isNull);
      expect(u.avatarFrame, isNull);
    });
  });

  group('profile in the app', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    const lea = AppUser(uid: 'lea', email: 'lea@test.fr', displayName: 'Léa', color: 0xFFFF5B34);
    const tom = AppUser(uid: 'tom', email: 'tom@test.fr', displayName: 'Tom', color: 0xFF5B4BE8);

    ({AppState state, FakeAuthRepository auth, FakeUsersRepository users}) seed({FakeMatchesRepository Function(Map<String, List<GameMatch>> seed)? matchesRepo}) {
      final usersMap = {'lea': lea, 'tom': tom};
      final users = FakeUsersRepository(usersMap);
      final auth = FakeAuthRepository(seedUsers: usersMap);
      final group = Group(id: 'bandits', name: 'Les Bandits', emoji: '🃏', emojiBg: 0, memberIds: const ['lea', 'tom'], ownerId: 'lea');
      final state = AppState(
        authRepo: auth,
        groupsRepo: FakeGroupsRepository(seedGroups: {'bandits': group}, users: users),
        gamesRepo: FakeGamesRepository(seed: {'bandits': List.of(kDefaultGames)}),
        matchesRepo: (matchesRepo ?? (m) => FakeMatchesRepository(seed: m))({
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
        gameLibraryRepo: FakeGameLibraryRepository(seed: [
          ...kDefaultGames,
          Game(id: 'catan_solo', name: 'Catan (solo)', emoji: '🐑', category: 'Société', rules: kDefaultGames.first.rules, minPlayers: 1, maxPlayers: 1, collectible: false),
        ]),
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

    Future<AppState> signIn(WidgetTester tester, ({AppState state, FakeAuthRepository auth, FakeUsersRepository users}) s) async {
      await tester.pumpWidget(ChangeNotifierProvider.value(value: s.state, child: const MaterialApp(home: AuthGate())));
      await tester.pump();
      s.auth.debugSignIn(lea);
      await tester.pump();
      return s.state;
    }

    testWidgets('signing in unlocks the badges already earned, celebrates them once, and saves them', (tester) async {
      final s = seed();
      final state = await signIn(tester, s);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(BadgeUnlockBanner), findsOneWidget);
      expect(state.pendingBadgeUnlocks, containsAll(['first_game', 'first_win']));

      await tester.pumpAndSettle();
      expect(find.byType(BadgeUnlockBanner), findsNothing, reason: 'the celebration plays out and goes away');
      expect(state.pendingBadgeUnlocks, isEmpty);
      expect(s.users.users['lea']!.badges, containsAll(['first_game', 'first_win']));
      expect(s.users.users['lea']!.badges, isNot(contains('legend')));
    });

    testWidgets('badges still unlock when the matches arrive before the rest of the group data', (tester) async {
      final late = _LateLiveSessionsRepository();
      final s = seed(matchesRepo: (m) => late..seedAll(m));
      final state = await signIn(tester, s);
      // Not pumpAndSettle: the home screen's loader keeps animating until
      // every dataset is in.
      await tester.pump(const Duration(milliseconds: 500));
      expect(state.matchesLoaded, isTrue);
      expect(state.groupDataFullyLoaded, isFalse, reason: 'live sessions are still loading');
      expect(s.users.users['lea']!.badges, isEmpty);

      late.sessions.add(const []);
      await tester.pumpAndSettle();
      expect(s.users.users['lea']!.badges, containsAll(['first_game', 'first_win']));
    });

    testWidgets('another player\'s badge they already meet shows as earned before they save it', (tester) async {
      final s = seed();
      final state = await signIn(tester, s);
      await tester.pumpAndSettle();
      expect(s.users.users['tom']!.badges, isEmpty, reason: 'only Tom himself can save his badges');
      expect(state.earnedBadgeIds('tom'), contains('first_game'));
      expect(state.earnedBadgeIds('tom'), isNot(contains('first_win')));
    });

    testWidgets('solo variants stay out of the collection; played games map to the box you own', (tester) async {
      final s = seed();
      final state = await signIn(tester, s);
      await tester.pumpAndSettle();
      await state.ensureGameLibraryLoaded();

      await state.toggleOwnedGame('catan_solo');
      expect(s.users.users['lea']!.ownedGameIds, isEmpty, reason: 'a (solo) variant is not collectible');

      final catan = kDefaultGames.firstWhere((g) => g.id == 'catan');
      expect(state.collectibleLibraryGameFor(const Game(id: 'x', name: 'Catan (solo)', emoji: '🐑', category: 'Société', rules: [], libraryId: 'catan_solo'))?.id, 'catan');
      expect(state.collectibleLibraryGameFor(catan)?.id, 'catan');

      final played = state.playedLibraryGames('lea');
      expect(played.map((p) => p.game.id), ['catan']);
      expect(played.single.played, 1);

      await state.addOwnedGames(['catan', 'catan_solo', 'skyjo']);
      await tester.pumpAndSettle();
      expect(s.users.users['lea']!.ownedGameIds, ['catan', 'skyjo']);
    });

    testWidgets('saving a whole profile cleans it up', (tester) async {
      final s = seed();
      final state = await signIn(tester, s);
      await tester.pumpAndSettle();
      final me = state.currentUser!;

      expect(
        await state.saveProfile(me.copyWith(
          displayName: '  Léa  ',
          pronouns: ' elle ',
          status: '   ',
          statusEmoji: () => '🎲',
          titleId: () => 'legende', // needs the Légende badge — not earned
          nameFont: () => 'comic',
          gameAccounts: {'steam': ' lea_42 ', 'xbox': '   ', 'myspace': 'tom'},
          badges: ['legend'], // can't be granted through a profile save
        )),
        isTrue,
      );
      await tester.pumpAndSettle();
      final saved = s.users.users['lea']!;
      expect(saved.displayName, 'Léa');
      expect(saved.pronouns, 'elle');
      expect(saved.status, isEmpty);
      expect(saved.statusEmoji, isNull, reason: 'no emoji without a status');
      expect(saved.titleId, isNull, reason: 'a locked title is dropped');
      expect(saved.nameFont, 'comic');
      expect(saved.gameAccounts, {'steam': 'lea_42'});
      expect(saved.badges, isNot(contains('legend')));

      await state.saveProfile(state.currentUser!.copyWith(titleId: () => 'vainqueur', gameAccounts: const {}));
      await tester.pumpAndSettle();
      expect(s.users.users['lea']!.titleId, 'vainqueur', reason: 'Léa has won a match');
      expect(s.users.users['lea']!.gameAccounts, isEmpty, reason: 'a removed account goes away');

      expect(await state.saveProfile(state.currentUser!.copyWith(displayName: ' ')), isFalse);
    });

    testWidgets('editing the profile, the collection and the pinned badges', (tester) async {
      final s = seed();
      final state = await signIn(tester, s);
      await tester.pumpAndSettle();

      expect(await state.updateProfile(displayName: '  Léa la Rouge ', bio: 'Reine du Catan', avatarEmoji: () => '🦊', banner: 'braise', avatarFrame: () => 'gold'), isTrue);
      await tester.pumpAndSettle();
      final saved = s.users.users['lea']!;
      expect(saved.displayName, 'Léa la Rouge');
      expect(saved.bio, 'Reine du Catan');
      expect(saved.initial, '🦊');
      expect(saved.banner, 'braise');
      expect(saved.avatarFrame, 'gold');
      await state.updateProfile(avatarFrame: () => null);
      await tester.pumpAndSettle();
      expect(s.users.users['lea']!.avatarFrame, isNull, reason: 'the decoration can be removed again');

      expect(await state.updateProfile(displayName: '   '), isFalse, reason: 'a blank name is refused');
      expect(s.users.users['lea']!.displayName, 'Léa la Rouge');

      await state.toggleOwnedGame('catan');
      await state.toggleOwnedGame('skyjo');
      await state.updateProfile(favoriteGameId: () => 'catan');
      await tester.pumpAndSettle();
      expect(s.users.users['lea']!.ownedGameIds, ['catan', 'skyjo']);
      await state.toggleOwnedGame('catan');
      await tester.pumpAndSettle();
      expect(s.users.users['lea']!.ownedGameIds, ['skyjo']);
      expect(s.users.users['lea']!.favoriteGameId, isNull, reason: 'a game leaving the collection stops being the favourite');

      await state.toggleShowcasedBadge('legend');
      expect(s.users.users['lea']!.showcasedBadges, isEmpty, reason: 'only unlocked badges can be pinned');
      await state.toggleShowcasedBadge('first_win');
      await tester.pumpAndSettle();
      expect(s.users.users['lea']!.showcasedBadges, ['first_win']);
      await state.toggleShowcasedBadge('first_win');
      await tester.pumpAndSettle();
      expect(s.users.users['lea']!.showcasedBadges, isEmpty);
    });
  });
}

/// Live sessions answer only when the test says so — the last dataset of
/// the group to arrive.
class _LateLiveSessionsRepository extends FakeMatchesRepository {
  final sessions = StreamController<List<LiveMatchSession>>.broadcast();
  Map<String, List<GameMatch>> _seed = {};

  _LateLiveSessionsRepository() : super();

  void seedAll(Map<String, List<GameMatch>> seed) => _seed = seed;

  @override
  Stream<List<GameMatch>> watchMatches(String rootGroupId, List<String> groupIds, {bool bySalon = false}) {
    return Stream.value(List.of(_seed[rootGroupId] ?? const []));
  }

  @override
  Stream<List<LiveMatchSession>> watchLiveSessions(String rootGroupId, List<String> groupIds, {bool bySalon = false}) => sessions.stream;
}
