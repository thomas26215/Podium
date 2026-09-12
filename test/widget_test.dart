// Exercises the real screens (Home/Ranking/History/Profile/Groups + the
// new-game sheet) against the in-memory Fake* repositories, since this
// environment has no live Firebase project to test against.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:podium/models/app_user.dart';
import 'package:podium/models/game.dart';
import 'package:podium/models/group.dart';
import 'package:podium/models/match.dart';
import 'package:podium/repositories/fakes.dart';
import 'package:podium/repositories/game_library_repository.dart';
import 'package:podium/repositories/games_repository.dart';
import 'package:podium/repositories/guests_repository.dart';
import 'package:podium/repositories/users_repository.dart';
import 'package:podium/screens/auth/auth_gate.dart';
import 'package:podium/state/app_state.dart';

const _lea = AppUser(uid: 'lea', email: 'lea@test.fr', displayName: 'Léa', color: 0xFFFF5B34);
const _tom = AppUser(uid: 'tom', email: 'tom@test.fr', displayName: 'Tom', color: 0xFF5B4BE8);

({AppState state, FakeAuthRepository auth}) _buildSeededState() {
  final usersMap = {'lea': _lea, 'tom': _tom};
  final users = FakeUsersRepository(usersMap);
  final auth = FakeAuthRepository(seedUsers: usersMap);

  final group = Group(
    id: 'bandits',
    name: 'Les Bandits',
    emoji: '🃏',
    emojiBg: 0xFFFFE9E1,
    memberIds: const ['lea', 'tom'],
    ownerId: 'lea',
  );
  final groups = FakeGroupsRepository(seedGroups: {'bandits': group}, users: users);

  final games = FakeGamesRepository(seed: {
    'bandits': List.of(kDefaultGames),
  });

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
  final matches = FakeMatchesRepository(seed: {
    'bandits': [match],
  });

  final state = AppState(
    authRepo: auth,
    groupsRepo: groups,
    gamesRepo: games,
    matchesRepo: matches,
    tournamentsRepo: FakeTournamentsRepository(),
    usersRepo: users,
    guestsRepo: FakeGuestsRepository(),
    gameLibraryRepo: FakeGameLibraryRepository(),
    serversRepo: FakeServersRepository(users: users),
    serverGamesRepo: FakeGamesRepository(),
    serverMatchesRepo: FakeMatchesRepository(),
  );
  return (state: state, auth: auth);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('signed-out shows the login screen', (tester) async {
    final seeded = _buildSeededState();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: seeded.state,
        child: const MaterialApp(home: AuthGate()),
      ),
    );
    await tester.pump();
    expect(find.text('Podium'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
  });

  testWidgets('signing in shows the home tab with group + leader data', (tester) async {
    final seeded = _buildSeededState();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: seeded.state,
        child: const MaterialApp(home: AuthGate()),
      ),
    );
    await tester.pump();

    seeded.auth.debugSignIn(_lea);
    await tester.pumpAndSettle();

    expect(find.text('Les Bandits'), findsOneWidget);
    expect(find.text('Léa'), findsWidgets);
    expect(find.text('Classement'), findsWidgets);
  });

  testWidgets('ranking tab shows both players once signed in', (tester) async {
    final seeded = _buildSeededState();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: seeded.state,
        child: const MaterialApp(home: AuthGate()),
      ),
    );
    await tester.pump();
    seeded.auth.debugSignIn(_lea);
    await tester.pumpAndSettle();

    seeded.state.setTab(AppTab.ranking);
    await tester.pumpAndSettle();

    expect(find.text('Léa'), findsWidgets);
    expect(find.text('Tom'), findsWidgets);
    expect(find.text('Victoires'), findsOneWidget);
  });

  testWidgets('tapping the home group header opens the groups screen', (tester) async {
    final seeded = _buildSeededState();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: seeded.state,
        child: const MaterialApp(home: AuthGate()),
      ),
    );
    await tester.pump();
    seeded.auth.debugSignIn(_lea);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Les Bandits'));
    await tester.pumpAndSettle();

    expect(find.text('Mes groupes & serveurs'), findsOneWidget);
    expect(find.text('Les Bandits'), findsOneWidget);
    expect(find.text('Créer'), findsOneWidget);
  });

  testWidgets('servers are listed alongside groups in the same screen', (tester) async {
    final seeded = _buildSeededState();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: seeded.state,
        child: const MaterialApp(home: AuthGate()),
      ),
    );
    await tester.pump();
    seeded.auth.debugSignIn(_lea);
    await tester.pumpAndSettle();

    await seeded.state.createServer(name: 'Café Test', emoji: '☕', emojiBg: 0);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Les Bandits'));
    await tester.pumpAndSettle();

    expect(find.text('Mes groupes & serveurs'), findsOneWidget);
    expect(find.text('Les Bandits'), findsOneWidget, reason: 'the group card is still there');
    expect(find.text('SERVEURS'), findsOneWidget);
    expect(find.text('Café Test'), findsOneWidget, reason: 'the newly created server shows up in the same list');

    await tester.pump(const Duration(milliseconds: 2700));
  });

  testWidgets('tapping a salon lands back on the normal home tab, not a separate screen', (tester) async {
    final seeded = _buildSeededState();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: seeded.state,
        child: const MaterialApp(home: AuthGate()),
      ),
    );
    await tester.pump();
    seeded.auth.debugSignIn(_tom);
    await tester.pumpAndSettle();

    final state = seeded.state;
    await state.createServer(name: 'Café Test', emoji: '☕', emojiBg: 0);
    await tester.pumpAndSettle();
    final server = state.servers.single;
    await state.createSalon(serverId: server.id, name: 'Tournoi', emoji: '🎮', emojiBg: 0);
    await tester.pumpAndSettle();
    final salon = state.salons.single;

    // Home -> unified groups/servers screen -> server detail -> tap the salon.
    await tester.tap(find.text('Les Bandits'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Café Test'));
    await tester.pumpAndSettle();
    expect(find.text('Salons'), findsOneWidget, reason: 'we are on the server detail screen');
    await tester.tap(find.text('Tournoi'));
    await tester.pumpAndSettle();

    expect(state.activeContext, ActiveContextKind.salon);
    expect(state.currentSalonId, salon.id);
    // Landed back on the ordinary tabbed home screen — not a separate,
    // disconnected screen — so it shows the salon in the same header the
    // group used to occupy, and none of the server-detail-only chrome.
    expect(find.text('Tournoi'), findsOneWidget, reason: 'the home header now shows the salon');
    expect(find.text('Salons'), findsNothing, reason: 'no longer on the server detail screen');
    expect(find.text('Classement'), findsWidgets, reason: 'the ordinary tab bar is back');

    await tester.pump(const Duration(milliseconds: 2700));
  });

  testWidgets('new-game sheet opens from the FAB and shows the game grid', (tester) async {
    final seeded = _buildSeededState();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: seeded.state,
        child: const MaterialApp(home: AuthGate()),
      ),
    );
    await tester.pump();
    seeded.auth.debugSignIn(_lea);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    // First step: "Partie simple" or "Tournoi" — pick the plain match, then
    // continue to the game picker.
    expect(find.text('Partie simple'), findsOneWidget);
    await tester.tap(find.text('Partie simple'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    // The ranking tab's game filter chips stay mounted underneath (IndexedStack),
    // so "Catan" legitimately appears more than once — just assert it's present.
    expect(find.text('Catan'), findsWidgets);
    expect(find.text('Nouveau jeu'), findsOneWidget);
  });

  testWidgets('recent accounts are remembered after sign out', (tester) async {
    final seeded = _buildSeededState();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: seeded.state,
        child: const MaterialApp(home: AuthGate()),
      ),
    );
    await tester.pump();

    seeded.auth.debugSignIn(_lea);
    await tester.pumpAndSettle();

    await seeded.state.signOut();
    await tester.pumpAndSettle();

    expect(find.text('Comptes enregistrés'), findsOneWidget);
    expect(find.text('Léa'), findsWidgets);
    expect(find.text('lea@test.fr'), findsOneWidget);
  });

  testWidgets('history compacts adjacent same-day matches for the same game and players', (tester) async {
    final usersMap = {'lea': _lea, 'tom': _tom};
    final users = FakeUsersRepository(usersMap);
    final auth = FakeAuthRepository(seedUsers: usersMap);
    final group = Group(
      id: 'bandits',
      name: 'Les Bandits',
      emoji: '🃏',
      emojiBg: 0xFFFFE9E1,
      memberIds: const ['lea', 'tom'],
      ownerId: 'lea',
    );
    final groups = FakeGroupsRepository(seedGroups: {'bandits': group}, users: users);

    final catan = Game.simple(
      id: 'catan',
      name: 'Catan',
      emoji: '🎲',
      category: 'Société',
      countType: CountType.highWins,
    );
    final uno = Game.simple(
      id: 'uno',
      name: 'Uno',
      emoji: '🃏',
      category: 'Cartes',
      countType: CountType.highWins,
    );
    final games = FakeGamesRepository(seed: {'bandits': [catan, uno]});

    final matches = FakeMatchesRepository(seed: {
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
          createdAt: DateTime(2026, 8, 25, 10),
        ),
        GameMatch(
          id: 'm2',
          gameId: 'catan',
          groupId: 'bandits',
          mode: 'ffa',
          unit: 'points',
          lowWins: false,
          entries: const [MatchEntry(playerId: 'lea', points: 12), MatchEntry(playerId: 'tom', points: 7)],
          timeline: const [],
          createdAt: DateTime(2026, 8, 25, 9),
        ),
        GameMatch(
          id: 'm3',
          gameId: 'uno',
          groupId: 'bandits',
          mode: 'ffa',
          unit: 'points',
          lowWins: false,
          entries: const [MatchEntry(playerId: 'lea', points: 5), MatchEntry(playerId: 'tom', points: 6)],
          timeline: const [],
          createdAt: DateTime(2026, 8, 25, 8),
        ),
      ],
    });

    final state = AppState(
      authRepo: auth,
      groupsRepo: groups,
      gamesRepo: games,
      matchesRepo: matches,
      tournamentsRepo: FakeTournamentsRepository(),
      usersRepo: users,
      guestsRepo: FakeGuestsRepository(),
      gameLibraryRepo: FakeGameLibraryRepository(),
      serversRepo: FakeServersRepository(users: users),
      serverGamesRepo: FakeGamesRepository(),
      serverMatchesRepo: FakeMatchesRepository(),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: AuthGate()),
      ),
    );
    await tester.pump();

    auth.debugSignIn(_lea);
    await tester.pumpAndSettle();

    state.setTab(AppTab.history);
    await tester.pumpAndSettle();

    expect(find.text('Suite de 2 parties'), findsOneWidget);
    expect(find.text('Uno'), findsOneWidget);

    await tester.tap(find.text('Suite de 2 parties'));
    await tester.pumpAndSettle();

    expect(find.text('Partie 1'), findsWidgets);
    expect(find.text('Partie 2'), findsWidgets);
  });

  testWidgets('creating a tournament via the FAB wizard reaches its bracket screen', (tester) async {
    final seeded = _buildSeededState();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: seeded.state,
        child: const MaterialApp(home: AuthGate()),
      ),
    );
    await tester.pump();
    seeded.auth.debugSignIn(_lea);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    // Step 1: "Partie simple" ou "Tournoi" — pick the tournament branch.
    await tester.tap(find.text('Tournoi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    // Step 2: format — "Élimination simple" is the default, just continue.
    expect(find.text('Élimination simple'), findsOneWidget);
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    // Step 3: game picker, reused as-is from the plain-match flow. "Catan"
    // legitimately appears twice — the ranking tab's game filter chips stay
    // mounted underneath (IndexedStack) — so target the picker's card,
    // which (being inside the sheet's Overlay entry) is last in hit-test order.
    await tester.tap(find.text('Catan').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    // Step 4: participants, also reused as-is — same "already mounted
    // underneath" caveat for player names shown elsewhere on the home tab.
    await tester.tap(find.text('Léa').last);
    await tester.tap(find.text('Tom').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Créer le tournoi'));
    await tester.pumpAndSettle();

    // Lands on the bracket screen instead of a scores step.
    expect(find.text('Créer le tournoi'), findsNothing);
    expect(find.text('Élimination simple'), findsWidgets);
    expect(find.textContaining('Catan'), findsWidgets);

    // Flush AppState.showToast's auto-dismiss timer so it doesn't outlive
    // the test (the binding asserts no pending timers at teardown).
    await tester.pump(const Duration(milliseconds: 2700));
  });

  testWidgets('a salon match stays pending until every player confirms it', (tester) async {
    final seeded = _buildSeededState();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: seeded.state,
        child: const MaterialApp(home: AuthGate()),
      ),
    );
    await tester.pump();
    seeded.auth.debugSignIn(_tom);
    await tester.pumpAndSettle();

    final state = seeded.state;
    await state.createServer(name: 'Café Test', emoji: '☕', emojiBg: 0);
    await tester.pumpAndSettle();
    final server = state.servers.single;
    expect(state.isServerAdmin(server), isTrue, reason: 'the creator is the owner, always an admin');

    await state.createSalon(serverId: server.id, name: 'Tournoi', emoji: '🎮', emojiBg: 0);
    await tester.pumpAndSettle();
    final salon = state.salons.single;

    state.selectSalon(server.id, salon.id);
    await tester.pumpAndSettle();
    expect(state.activeContext, ActiveContextKind.salon);
    expect(state.games.any((g) => g.id == 'catan'), isTrue, reason: 'the server got the default catalog seeded on creation');

    // Record a quick FFA match between Tom (the author) and Léa.
    state.pickGame('catan');
    state.togglePlayer('tom');
    state.togglePlayer('lea');
    state.draft.points['tom'] = 10;
    state.draft.points['lea'] = 8;
    await state.saveGame();
    await tester.pumpAndSettle();

    final saved = state.matches.single;
    expect(saved.isSalonMatch, isTrue);
    expect(saved.isPending, isTrue, reason: 'Léa has not confirmed yet');
    expect(saved.confirmedBy, contains('tom'), reason: "the author's own save counts as their confirmation");
    expect(state.viewMatches, isEmpty, reason: 'a pending match must not count toward stats/rankings yet');

    // Tom already implicitly confirmed his own save (see above) — Léa is the
    // one still missing. Simulate her confirmation arriving from another
    // device by writing straight through the repository, the same path
    // AppState.confirmMatch would take on her behalf.
    await state.serverMatchesRepo.confirmMatch(rootId: server.id, matchId: saved.id, uid: 'lea');
    await tester.pumpAndSettle();
    expect(state.matches.single.isConfirmed, isTrue);
    expect(state.viewMatches, hasLength(1), reason: 'now that everyone confirmed, it counts');

    await tester.pump(const Duration(milliseconds: 2700));
  });

  testWidgets('guests without an account can be added to a group, a server and a salon', (tester) async {
    final seeded = _buildSeededState();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: seeded.state,
        child: const MaterialApp(home: AuthGate()),
      ),
    );
    await tester.pump();
    seeded.auth.debugSignIn(_tom);
    await tester.pumpAndSettle();

    final state = seeded.state;

    // Group: any member can add a guest, no admin gate.
    final groupOk = await state.addGuest(groupId: 'bandits', displayName: 'Karim');
    await tester.pumpAndSettle();
    expect(groupOk, isTrue);
    final groupGuestId = state.groupById('bandits')!.memberIds.firstWhere(isGuestId);
    expect(state.playerById(groupGuestId)?.displayName, 'Karim');

    // Server: owner/admin-only, but Tom is the owner of the server he just created.
    await state.createServer(name: 'Café Test', emoji: '☕', emojiBg: 0);
    await tester.pumpAndSettle();
    final server = state.servers.single;

    final serverOk = await state.addServerGuest(serverId: server.id, displayName: 'Nadia');
    await tester.pumpAndSettle();
    expect(serverOk, isTrue);
    final serverGuestId = state.serverById(server.id)!.memberIds.firstWhere(isGuestId);
    expect(state.playerById(serverGuestId)?.displayName, 'Nadia');
    expect(state.knownGuests.map((g) => g.uid), contains(serverGuestId), reason: 'shows up as a suggestion elsewhere too');

    await state.createSalon(serverId: server.id, name: 'Tournoi', emoji: '🎮', emojiBg: 0);
    await tester.pumpAndSettle();
    final salon = state.salons.single;

    final salonOk = await state.addSalonGuest(serverId: server.id, salonId: salon.id, displayName: 'Yanis');
    await tester.pumpAndSettle();
    expect(salonOk, isTrue);
    final updatedSalon = state.salons.firstWhere((s) => s.id == salon.id);
    final salonGuestId = updatedSalon.memberIds.firstWhere(isGuestId);
    expect(state.playerById(salonGuestId)?.displayName, 'Yanis');
    expect(state.serverById(server.id)!.memberIds, contains(salonGuestId), reason: "adding a guest to a salon also adds them to its server");

    await tester.pump(const Duration(milliseconds: 2700));
  });

  testWidgets('a plain match in a group saves through the full wizard UI', (tester) async {
    final seeded = _buildSeededState();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: seeded.state,
        child: const MaterialApp(home: AuthGate()),
      ),
    );
    await tester.pump();
    seeded.auth.debugSignIn(_lea);
    await tester.pumpAndSettle();

    final before = seeded.state.matches.length;

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Partie simple'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Catan').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Léa').last);
    await tester.tap(find.text('Tom').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer'));
    // Not pumpAndSettle from here: reaching the scores step starts a live
    // session (AppState._startLiveSessionIfNeeded), and its "EN DIRECT"
    // pulsing dot (LiveDot, ..repeat(reverse: true)) animates forever by
    // design — pumpAndSettle would never find a quiet frame and time out.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Enregistrer la partie'), findsOneWidget, reason: 'reached the final scores step');
    await tester.tap(find.text('Enregistrer la partie'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(seeded.state.matches.length, before + 1, reason: 'the match was actually persisted through the repository');
    expect(seeded.state.flowError, isNull);
    expect(seeded.state.tab, AppTab.history, reason: 'saveGame() switches to the history tab on success');

    // Also check what the user actually sees on that tab, not just the
    // repository's internal state — this is the exact screen a real
    // permission-denied write (rejected server-side after an optimistic
    // local commit) would still show as empty despite the redirect.
    await tester.pump();
    expect(find.text('Pas encore de partie. Lancez-vous avec le bouton +.'), findsNothing, reason: 'the new match should show up in the history list, not the empty state');
    expect(find.textContaining('Catan'), findsWidgets);

    await tester.pump(const Duration(milliseconds: 2700));
  });
}
