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

    expect(find.text('Mes groupes'), findsOneWidget);
    expect(find.text('Les Bandits'), findsOneWidget);
    expect(find.text('Créer un groupe'), findsOneWidget);
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
}
