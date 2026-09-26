// Exercises the real screens (Home/Ranking/History/Profile/Groups + the
// new-game sheet) against the in-memory Fake* repositories, since this
// environment has no live Firebase project to test against.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:podium/models/app_user.dart';
import 'package:podium/models/game.dart';
import 'package:podium/models/group.dart';
import 'package:podium/models/group_invite_code.dart';
import 'package:podium/models/server_invite_code.dart';
import 'package:podium/models/match.dart';
import 'package:podium/models/tournament.dart';
import 'package:podium/repositories/fakes.dart';
import 'package:podium/repositories/game_library_repository.dart';
import 'package:podium/repositories/games_repository.dart';
import 'package:podium/repositories/guests_repository.dart';
import 'package:podium/repositories/users_repository.dart';
import 'package:podium/screens/auth/auth_gate.dart';
import 'package:podium/screens/auth/invite_link_handler.dart';
import 'package:podium/screens/groups/groups_screen.dart';
import 'package:podium/logic/game_filter.dart';
import 'package:podium/logic/game_sort.dart';
import 'package:podium/screens/new_game/game_form.dart';
import 'package:podium/screens/new_game/library_game_preview_screen.dart';
import 'package:podium/screens/new_game/step1_game.dart';
import 'package:podium/screens/profile/profile_screen.dart';
import 'package:podium/widgets/common.dart';
import 'package:podium/widgets/game_filter_bar.dart';
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
    serverTournamentsRepo: FakeTournamentsRepository(),
    eventsRepo: FakeEventsRepository(),
    messagesRepo: FakeMessagesRepository(),
    serverMessagesRepo: FakeMessagesRepository(),
  );
  return (state: state, auth: auth);
}

/// Picks [n] in the filter bar's "Joueurs" menu.
Future<void> pickPlayers(WidgetTester tester, int n) async {
  await tester.tap(find.descendant(of: find.byType(GameFilterBar), matching: find.byType(PopupMenuButton<int>)));
  await tester.pumpAndSettle();
  await tester.tap(find.text('$n joueurs').last);
  await tester.pumpAndSettle();
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

  testWidgets('discussion tab lets a member send a message and see others\' messages', (tester) async {
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

    seeded.state.setTab(AppTab.games);
    await tester.pumpAndSettle();

    expect(find.text('Discussion'), findsWidgets);

    await tester.enterText(find.byType(TextField), 'Salut la team !');
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Salut la team !'), findsOneWidget);

    // A message from someone else shows their name as the author label.
    await seeded.state.messagesRepo.sendMessage('bandits', authorId: 'tom', text: 'Yo !');
    await tester.pumpAndSettle();

    expect(find.text('Yo !'), findsOneWidget);
    expect(find.text('Tom'), findsWidgets);
  });

  testWidgets('long-pressing your own message lets you edit it', (tester) async {
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

    seeded.state.setTab(AppTab.games);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Salut');
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Salut'), findsOneWidget);

    await tester.longPress(find.text('Salut'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Modifier'));
    await tester.pumpAndSettle();

    // Editing pre-fills the compose field and shows the "editing" banner.
    expect(find.text('Modifier le message'), findsOneWidget);
    expect(find.text('Salut'), findsWidgets); // banner snippet + the field itself

    await tester.enterText(find.byType(TextField), 'Salut tout le monde');
    await tester.tap(find.byIcon(Icons.check_rounded));
    await tester.pumpAndSettle();

    expect(find.textContaining('Salut tout le monde'), findsOneWidget);
    expect(find.textContaining('modifié'), findsOneWidget);
    expect(find.text('Modifier le message'), findsNothing);
  });

  testWidgets('swiping a message opens a reply to it, quoted in the sent message', (tester) async {
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

    seeded.state.setTab(AppTab.games);
    await tester.pumpAndSettle();

    await seeded.state.messagesRepo.sendMessage('bandits', authorId: 'tom', text: 'Yo !');
    await tester.pumpAndSettle();

    final bubble = find.ancestor(of: find.text('Yo !'), matching: find.byType(Dismissible));
    await tester.drag(bubble, const Offset(500, 0));
    await tester.pumpAndSettle();

    expect(find.textContaining('Réponse à'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Salut !');
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Salut !'), findsOneWidget);
    // The reply quotes the original inside its own bubble.
    expect(find.text('Yo !'), findsNWidgets(2));
  });

  testWidgets('long-pressing a message lets you react to it, and tapping the pill again clears it', (tester) async {
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

    seeded.state.setTab(AppTab.games);
    await tester.pumpAndSettle();

    await seeded.state.messagesRepo.sendMessage('bandits', authorId: 'tom', text: 'Yo !');
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Yo !'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('👍'));
    await tester.pumpAndSettle();

    expect(find.text('👍 1'), findsOneWidget);

    // Tapping the pill directly (no need to reopen the sheet) toggles it off.
    await tester.tap(find.text('👍 1'));
    await tester.pumpAndSettle();
    expect(find.text('👍 1'), findsNothing);
  });

  testWidgets('mentioning a member via the @ picker tags them on the sent message', (tester) async {
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

    seeded.state.setTab(AppTab.games);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.alternate_email_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tom'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '@Tom tu confirmes samedi ?');
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();

    expect(find.textContaining('tu confirmes samedi'), findsOneWidget);
    final fake = seeded.state.messagesRepo as FakeMessagesRepository;
    final sent = fake.byRoot['bandits']!.last;
    expect(sent.mentionedUids, ['tom']);
  });

  testWidgets('the discussion tab clears its unread badge once opened', (tester) async {
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
    expect(seeded.state.tab, AppTab.home);

    await seeded.state.messagesRepo.sendMessage('bandits', authorId: 'tom', text: 'Yo !');
    await tester.pumpAndSettle();
    expect(seeded.state.hasUnreadDiscussionMessages, isTrue);

    seeded.state.setTab(AppTab.games);
    await tester.pumpAndSettle();
    expect(seeded.state.hasUnreadDiscussionMessages, isFalse);
  });

  testWidgets('a system highlight renders as a centered pill in the discussion thread', (tester) async {
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

    seeded.state.setTab(AppTab.games);
    await tester.pumpAndSettle();

    // Mirrors what the onMatchCreated Cloud Function posts (see
    // functions/index.js's postMatchHighlights) — authorId 'system'.
    final fake = seeded.state.messagesRepo as FakeMessagesRepository;
    fake.debugSeedSystemMessage('bandits', 'Léa prend la tête du classement 👑');
    await tester.pumpAndSettle();

    expect(find.text('Léa prend la tête du classement 👑'), findsOneWidget);
  });

  testWidgets('a poll lets the group vote and launch the winning game', (tester) async {
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

    seeded.state.setTab(AppTab.games);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.how_to_vote_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Catan'));
    await tester.tap(find.text('Uno'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lancer le sondage'));
    await tester.pumpAndSettle();

    expect(find.text('Quel jeu ce soir ?'), findsOneWidget);
    expect(find.text('Catan'), findsOneWidget);
    expect(find.text('Uno'), findsOneWidget);

    // Voting for Catan bumps its tally to 1.
    await tester.tap(find.text('Catan'));
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);

    // The play button on an option jumps straight into the new-game wizard,
    // pre-filled with that game, at the players step. Catan is the first
    // option (selected first above), so its play button is the first match.
    await tester.tap(find.byIcon(Icons.play_circle_fill_rounded).first);
    await tester.pumpAndSettle();

    expect(seeded.state.sheetOpen, isTrue);
    expect(seeded.state.draft.gameId, 'catan');
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
      serverTournamentsRepo: FakeTournamentsRepository(),
      eventsRepo: FakeEventsRepository(),
      messagesRepo: FakeMessagesRepository(),
      serverMessagesRepo: FakeMessagesRepository(),
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

    // Created pending: participants can be rearranged, nothing can be
    // scored until it's started.
    expect(find.text('En préparation'), findsOneWidget);
    expect(find.text('Mélanger'), findsOneWidget);
    expect(find.text('Winners'), findsNothing);
    await tester.tap(find.text('Commencer le tournoi'));
    await tester.pumpAndSettle();
    expect(find.text('En cours'), findsOneWidget);
    expect(find.text('Mélanger'), findsNothing);
    expect(find.text('Commencer le tournoi'), findsNothing);

    // Tournaments are online-only: going offline hides the bracket behind
    // a notice, and every tournament action refuses to run.
    final started = seeded.state.tournaments.single;
    seeded.state.isOnline = false;
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    seeded.state.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.text(AppState.tournamentsOfflineMessage), findsOneWidget);
    expect(find.text('Élimination simple'), findsNothing);
    seeded.state.startTournamentMatch(started, started.matches.first);
    expect(seeded.state.isEditingTournamentMatch, isFalse);
    seeded.state.isOnline = true;
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    seeded.state.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.text('Élimination simple'), findsWidgets);

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

  testWidgets('the game form lets the user name the per-player choice and type its options', (tester) async {
    final seeded = _buildSeededState();
    final state = seeded.state;
    state.startNewGame();
    state.setGameForm((f) => f..name = '7 Wonders');
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: Scaffold(body: SingleChildScrollView(child: CreateGameForm()))),
      ),
    );
    expect(find.text('Nom du choix'), findsNothing, reason: 'hidden while the switch is off');

    await tester.tap(find.text('Chacun choisit un élément'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Personnage'), 'Merveille');
    await tester.tap(find.text('une'));
    await tester.enterText(find.widgetWithText(TextField, 'Ex. Babylone, Rhodes, Gizeh…'), 'Babylone');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Ajouter un élément'), 'Rhodes');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    final choice = state.gameForm.cleanCharacterChoice!;
    expect(choice.label, 'Merveille');
    expect(choice.feminine, isTrue);
    expect(choice.options, ['Babylone', 'Rhodes']);
    expect(find.text('Affiché « Choisir une merveille » pendant la partie.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('each player can pick a character, saved on the match and kept when resumed', (tester) async {
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

    final state = seeded.state;
    state.openSheet();
    state.startNewGame();
    state.setGameForm((f) => f
      ..name = 'Dice Throne'
      ..characterEnabled = true
      ..characterLabel = 'Héros'
      ..characters = ['Barbare', 'Moine', ' ', 'Barbare']);
    await state.createGame();
    await tester.pumpAndSettle();
    final game = state.games.firstWhere((g) => g.name == 'Dice Throne');
    expect(game.characterChoice!.label, 'Héros');
    expect(game.characterChoice!.options, ['Barbare', 'Moine']);

    state.pickGame(game.id);
    state.togglePlayer('lea');
    state.togglePlayer('tom');
    state.setPlayerCharacter('lea', 'Moine');
    state.setPlayerCharacter('tom', 'Barbare');
    state.setPlayerCharacter('tom', null);
    state.setPlayerCharacter('tom', 'Barbare');
    state.draft.points['lea'] = 10;
    state.draft.points['tom'] = 8;
    await state.saveGame();
    await tester.pumpAndSettle();

    final saved = state.matches.firstWhere((m) => m.gameId == game.id);
    expect({for (final e in saved.entries) e.playerId: e.character}, {'lea': 'Moine', 'tom': 'Barbare'});

    state.resumeMatch(saved, game);
    expect(state.draft.characters, {'lea': 'Moine', 'tom': 'Barbare'});
    state.closeSheet();

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

  testWidgets('a coop game auto-picks the coop mode and saves a shared group result', (tester) async {
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

    // Create a brand-new game configured as coop right from the "Partie
    // coopérative" switch on the game-creation form (see GameRule.coop).
    await tester.ensureVisible(find.text('Nouveau jeu'));
    await tester.tap(find.text('Nouveau jeu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Créer un jeu personnalisé'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Pandemic');
    await tester.ensureVisible(find.text('Victoire / défaite'));
    await tester.tap(find.text('Victoire / défaite'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Partie coopérative'));
    await tester.tap(find.text('Partie coopérative'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Créer le jeu'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    // Players step: the rule's coop style should already have picked the
    // draft's mode by itself — no "Chacun pour soi"/"Équipes" choice to
    // make, just the coop explainer banner.
    expect(find.text('Chacun pour soi'), findsNothing, reason: 'coop rule skips the mode choice entirely');
    expect(find.textContaining('Partie coopérative'), findsOneWidget);

    await tester.tap(find.text('Léa').last);
    await tester.tap(find.text('Tom').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Scores step: one shared Victoire/Défaite for the whole group.
    expect(find.text('Le groupe a-t-il gagné ou perdu ?'), findsOneWidget);
    await tester.tap(find.text('Victoire'));
    await tester.pump();

    expect(find.text('Enregistrer la partie'), findsOneWidget);
    await tester.tap(find.text('Enregistrer la partie'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(seeded.state.matches.length, before + 1);
    // AppState.matches is sorted newest-first (see FakeMatchesRepository's
    // createdAt-descending _filtered) — the just-saved match is .first.
    final saved = seeded.state.matches.first;
    expect(saved.mode, 'coop');
    expect(saved.entries.map((e) => e.points), everyElement(1), reason: 'every player shares the same group outcome');
    expect(saved.winnerIds().toSet(), {'lea', 'tom'}, reason: 'a coop win credits the whole group');

    await tester.pump();
    expect(find.textContaining('Victoire du groupe'), findsWidgets);

    await tester.pump(const Duration(milliseconds: 2700));
  });

  testWidgets('a game keeps its player count and theme tags, and the wizard warns outside the range', (tester) async {
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
    await tester.tap(find.text('Partie simple'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Nouveau jeu'));
    await tester.tap(find.text('Nouveau jeu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Créer un jeu personnalisé'));
    await tester.pumpAndSettle();

    // Form fields, in tree order: game name, then the min/max player count.
    await tester.enterText(find.byType(TextFormField).at(0), 'Dixit');
    await tester.enterText(find.byType(TextFormField).at(1), '3');
    await tester.enterText(find.byType(TextFormField).at(2), '6');
    // Themes are picked from a searchable sheet: "Duel" sits in the Format
    // group, "Stratégie" in Genre.
    await tester.ensureVisible(find.text('Ajouter des thèmes'));
    await tester.tap(find.text('Ajouter des thèmes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Duel'));
    await tester.tap(find.text('Stratégie'));
    await tester.enterText(find.byType(TextField).last, 'escape');
    await tester.pumpAndSettle();
    expect(find.text('Duel'), findsNothing, reason: 'the search hides non-matching themes');
    await tester.tap(find.text('Escape game'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();
    expect(seeded.state.gameForm.themes.toSet(), {'duel', 'strategie', 'escapeGame'});

    // Switching category drops the tags the new category doesn't offer —
    // "Duel" and "Stratégie" exist for Cartes too, "Escape game" doesn't.
    await tester.ensureVisible(find.text('Cartes'));
    await tester.tap(find.text('Cartes'));
    await tester.pumpAndSettle();
    expect(seeded.state.gameForm.themes.toSet(), {'duel', 'strategie'});

    await tester.tap(find.text('Société'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Créer le jeu'));
    await tester.pumpAndSettle();

    final dixit = seeded.state.games.firstWhere((g) => g.name == 'Dixit');
    expect(dixit.minPlayers, 3);
    expect(dixit.maxPlayers, 6);
    expect(dixit.themes.toSet(), {'duel', 'strategie'});

    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Léa').last);
    await tester.tap(find.text('Tom').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Prévu pour 3–6 joueurs — vous en avez sélectionné 2'), findsOneWidget, reason: 'two players is below the minimum');
  });

  testWidgets('the game grid can be filtered by player count and by theme', (tester) async {
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

    // The home screen behind the sheet also lists some games — only look at the wizard's grid.
    Finder inGrid(String name) => find.descendant(of: find.byType(Step1Game), matching: find.text(name));

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Partie simple'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    expect(inGrid('Catan'), findsOneWidget);
    expect(inGrid('Uno'), findsOneWidget);

    // Catan is 3–4 players, Uno 2–10: two players keeps only Uno.
    await pickPlayers(tester, 2);
    expect(inGrid('Catan'), findsNothing);
    expect(inGrid('Uno'), findsOneWidget);

    await tester.tap(find.text('Réinitialiser'));
    await tester.pumpAndSettle();
    expect(inGrid('Catan'), findsOneWidget);

    // The theme picker only offers themes some game carries — "Course" is
    // Mario Kart's.
    await tester.tap(find.text('Thèmes'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'cour');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Course'));
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();
    expect(inGrid('Mario Kart'), findsOneWidget);
    expect(inGrid('Catan'), findsNothing);
    expect(find.text('Thèmes · 1'), findsOneWidget);

    // Opening the sheet afresh starts unfiltered.
    expect(seeded.state.gameGridFilter.isActive, isTrue);
    seeded.state.openSheet();
    expect(seeded.state.gameGridFilter.isActive, isFalse);
  });

  testWidgets('the game step can be searched and sorted', (tester) async {
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

    Finder inGrid(String name) => find.descendant(of: find.byType(Step1Game), matching: find.text(name));

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Partie simple'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    // Default order is by last game: Catan (the only one played) comes first.
    expect(seeded.state.gameSort, GameSort.lastPlayed);
    expect(seeded.state.filteredGames.first.id, 'catan');

    // The search reaches names and theme labels, ignoring accents.
    await tester.enterText(find.byType(TextField).last, 'skyj');
    await tester.pumpAndSettle();
    expect(inGrid('Skyjo'), findsOneWidget);
    expect(inGrid('Catan'), findsNothing);
    await tester.enterText(find.byType(TextField).last, 'petanque');
    await tester.pumpAndSettle();
    expect(seeded.state.filteredGames.map((g) => g.id), ['petanque']);
    await tester.enterText(find.byType(TextField).last, 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('Aucun jeu ne correspond à votre recherche.'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, '');
    await tester.pumpAndSettle();

    // The sort chip shows the current choice and opens the sort menu.
    await tester.tap(find.text('Récent'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nom (A → Z)'));
    await tester.pumpAndSettle();
    expect(seeded.state.gameSort, GameSort.name);
    expect(find.text('A → Z'), findsOneWidget);
    expect(seeded.state.filteredGames.map((g) => g.id), ['catan', 'mk', 'petanque', 'president', 'skyjo', 'timesup', 'uno']);

    // Going back and forth keeps the search box and the grid in agreement.
    await tester.enterText(find.byType(TextField).last, 'uno');
    await tester.pumpAndSettle();
    await tester.tap(inGrid('Uno'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(seeded.state.gameSearch, 'uno');
    expect(tester.widget<TextField>(find.byType(TextField).last).controller!.text, 'uno');
    expect(inGrid('Catan'), findsNothing);

    // Opening the sheet afresh clears the search but remembers the sort.
    seeded.state.openSheet();
    expect(seeded.state.gameSearch, isEmpty);
    expect(seeded.state.gameSort, GameSort.name);
  });

  testWidgets('the poll sheet only offers games passing the filter, and drops filtered-out picks', (tester) async {
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

    seeded.state.setTab(AppTab.games);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.how_to_vote_rounded));
    await tester.pumpAndSettle();

    Finder inSheet(String text) => find.descendant(of: find.byType(BottomSheet), matching: find.text(text));
    bool launchEnabled() => tester.widget<PrimaryButton>(find.widgetWithText(PrimaryButton, 'Lancer le sondage')).onPressed != null;

    await tester.tap(inSheet('Catan'));
    await tester.tap(inSheet('Uno'));
    await tester.pumpAndSettle();
    expect(launchEnabled(), isTrue);

    // Catan is 3–4 players: filtering on 2 hides it, and it must not stay
    // selected behind the scenes — only Uno is left, below the 2-game minimum.
    await pickPlayers(tester, 2);
    expect(inSheet('Catan'), findsNothing);
    expect(inSheet('Uno'), findsOneWidget);
    expect(launchEnabled(), isFalse);
  });

  testWidgets('the ranking can be restricted to games carrying a theme', (tester) async {
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
    expect(find.text('Tom'), findsWidgets);

    // The only recorded match is Catan — "Course" is Mario Kart's theme, so
    // restricting to it leaves every player at zero victories.
    await tester.tap(find.text('Filtrer par thème'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'cour');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Course'));
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();
    expect(seeded.state.rankingThemeGameIds, {'mk'});
    expect(find.text('1 thème'), findsOneWidget);
    var rows = seeded.state.standings('wins', gameIdsFilter: seeded.state.rankingThemeGameIds);
    expect(rows.map((r) => r.wins), everyElement(0));

    // Clearing the pill and picking "Stratégie" (Catan's) counts Léa's win again.
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(seeded.state.rankingThemes, isEmpty);
    expect(seeded.state.rankingThemeGameIds, isNull);
    await tester.tap(find.text('Filtrer par thème'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'strat');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stratégie'));
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();
    expect(seeded.state.rankingThemeGameIds, {'catan'});
    rows = seeded.state.standings('wins', gameIdsFilter: seeded.state.rankingThemeGameIds);
    expect(rows.first.player.uid, 'lea');
    expect(rows.first.wins, 1);
  });

  testWidgets('a profile breaks results down by theme', (tester) async {
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

    seeded.state.openProfile('lea');
    tester.state<NavigatorState>(find.byType(Navigator).first).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
    await tester.pumpAndSettle();

    // Léa won the one recorded Catan match (Stratégie, Gestion, Négociation…).
    expect(find.text('Par thème'), findsOneWidget);
    expect(find.text('Stratégie'), findsOneWidget);
    expect(find.text('100%'), findsWidgets);
  });

  testWidgets('the library browser filters imports by players and searches themes', (tester) async {
    final seeded = _buildSeededState();
    final wonders = Game.simple(
      id: 'wonders', name: '7 Wonders', emoji: '🏛️', category: 'Société', countType: CountType.highWins,
      minPlayers: 3, maxPlayers: 7, themes: const ['strategie', 'draft', 'antiquite'],
    );
    final duel = Game.simple(
      id: 'duel', name: '7 Wonders Duel', emoji: '⚔️', category: 'Société', countType: CountType.highWins,
      minPlayers: 2, maxPlayers: 2, themes: const ['duel', 'strategie', 'draft'],
    );
    // Pre-filled so startBrowsingLibrary doesn't need to fetch anything.
    seeded.state.gameLibrary = [wonders, duel];

    // The search box reaches theme labels ("Antiquité" is only on 7 Wonders).
    seeded.state.librarySearch = 'antiq';
    expect(seeded.state.filteredLibrary.map((g) => g.id), ['wonders']);
    seeded.state.librarySearch = '';
    seeded.state.setLibraryFilter(const GameFilter(players: 2));
    expect(seeded.state.filteredLibrary.map((g) => g.id), ['duel']);
    seeded.state.setLibraryFilter(const GameFilter(themes: {'duel'}));
    expect(seeded.state.filteredLibrary.map((g) => g.id), ['duel']);

    // Picking a category narrows the list and drops the previous filter,
    // whose themes belonged to another category.
    final uno = Game.simple(id: 'uno', name: 'Uno', emoji: '🃏', category: 'Cartes', countType: CountType.highWins, themes: const ['defausse']);
    seeded.state.gameLibrary = [wonders, duel, uno];
    seeded.state.setLibraryCategory('Cartes');
    expect(seeded.state.libraryFilter.isActive, isFalse);
    expect(seeded.state.filteredLibrary.map((g) => g.id), ['uno']);
    expect(seeded.state.libraryInCategory.map((g) => g.id), ['uno']);
    seeded.state.setLibraryCategory(null);
    expect(seeded.state.filteredLibrary.map((g) => g.id), ['wonders', 'duel', 'uno']);
    seeded.state.gameLibrary = [wonders, duel];
    seeded.state.otherGroupsGames = [
      OtherGroupGame(game: wonders, groupId: 'g1', groupName: 'Amis'),
      OtherGroupGame(game: duel, groupId: 'g1', groupName: 'Amis'),
    ];
    seeded.state.setOtherGroupsFilter(const GameFilter(themes: {'antiquite'}));
    expect(seeded.state.filteredOtherGroupsGames.map((og) => og.game.id), ['wonders']);

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
    await tester.tap(find.text('Partie simple'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Nouveau jeu'));
    await tester.tap(find.text('Nouveau jeu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Importer depuis la bibliothèque'));
    await tester.pumpAndSettle();

    expect(find.text('7 Wonders'), findsOneWidget);
    expect(find.text('7 Wonders Duel'), findsOneWidget);
    await pickPlayers(tester, 2);
    expect(find.text('7 Wonders'), findsNothing, reason: '3–7 players does not accept 2');
    expect(find.text('7 Wonders Duel'), findsOneWidget);
    await tester.tap(find.text('Thèmes'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'duel');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Duel'));
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();
    await pickPlayers(tester, 8);
    expect(find.text('Aucun jeu ne correspond à ces filtres.'), findsOneWidget);
  });

  testWidgets('a library game opens a full preview before import, then is ticked as already imported', (tester) async {
    final seeded = _buildSeededState();
    final wonders = Game.simple(
      id: 'wonders', name: '7 Wonders', emoji: '🏛️', category: 'Société', countType: CountType.highWins,
      minPlayers: 3, maxPlayers: 7, themes: const ['strategie', 'draft'],
      ruleSections: const [GameRuleSection(title: 'Fin de partie', rules: ['Après le 3e âge'])],
    );
    seeded.state.gameLibrary = [wonders];

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
    await tester.tap(find.text('Partie simple'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Nouveau jeu'));
    await tester.tap(find.text('Nouveau jeu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Importer depuis la bibliothèque'));
    await tester.pumpAndSettle();

    // Tapping only previews — nothing is imported yet.
    final before = seeded.state.games.length;
    await tester.tap(find.text('7 Wonders'));
    await tester.pumpAndSettle();
    expect(find.byType(LibraryGamePreviewScreen), findsOneWidget);
    expect(find.text('Après le 3e âge'), findsOneWidget);
    expect(seeded.state.games.length, before);

    await tester.tap(find.text('Ajouter à mon catalogue'));
    await tester.pumpAndSettle();
    expect(find.byType(LibraryGamePreviewScreen), findsNothing);
    final copy = seeded.state.libraryCopyOf(wonders);
    expect(copy, isNotNull);
    expect(copy!.libraryId, 'wonders');
    expect(seeded.state.draft.gameId, copy.id);

    // Back in the library, the game is ticked and its preview offers the
    // existing copy instead of a duplicate import.
    await seeded.state.startBrowsingLibrary();
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    await tester.tap(find.text('7 Wonders'));
    await tester.pumpAndSettle();
    expect(find.text('Déjà dans votre catalogue'), findsOneWidget);
    await tester.tap(find.text('Utiliser ce jeu'));
    await tester.pumpAndSettle();
    expect(seeded.state.games.length, before + 1);
    expect(seeded.state.browsingLibrary, isFalse);
    await tester.pump(const Duration(seconds: 3)); // let the import toast expire
  });

  testWidgets('a game created inside one salon is not visible from another salon of the same server', (tester) async {
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

    final state = seeded.state;
    await state.createServer(name: 'Café Test', emoji: '☕', emojiBg: 0);
    await tester.pumpAndSettle();
    final server = state.servers.single;

    await state.createSalon(serverId: server.id, name: 'Salon A', emoji: '🎮', emojiBg: 0);
    await state.createSalon(serverId: server.id, name: 'Salon B', emoji: '🎯', emojiBg: 0);
    await tester.pumpAndSettle();
    final salonA = state.salons.firstWhere((s) => s.name == 'Salon A');
    final salonB = state.salons.firstWhere((s) => s.name == 'Salon B');

    state.selectSalon(server.id, salonA.id);
    await tester.pumpAndSettle();
    // The server's starter catalog (seeded on creation, no salonId) is
    // shared legacy — visible from every salon.
    expect(state.games.any((g) => g.id == 'catan'), isTrue);

    state.startNewGame();
    state.setGameForm((f) => f..name = 'Jeu du Salon A');
    await state.createGame();
    await tester.pumpAndSettle();
    expect(
      state.games.any((g) => g.name == 'Jeu du Salon A'),
      isTrue,
      reason: 'the just-created game is visible from the salon it was created in',
    );

    state.selectSalon(server.id, salonB.id);
    await tester.pumpAndSettle();
    expect(
      state.games.any((g) => g.name == 'Jeu du Salon A'),
      isFalse,
      reason: 'a game created in Salon A must not leak into Salon B\'s catalog',
    );
    expect(state.games.any((g) => g.id == 'catan'), isTrue, reason: 'the shared legacy catalog still shows up everywhere');

    state.selectSalon(server.id, salonA.id);
    await tester.pumpAndSettle();
    expect(state.games.any((g) => g.name == 'Jeu du Salon A'), isTrue, reason: 'still there when switching back to Salon A');
  });

  testWidgets('scoring a match inside a salon broadcasts a live session scoped to that salon', (tester) async {
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

    final state = seeded.state;
    await state.createServer(name: 'Café Test', emoji: '☕', emojiBg: 0);
    await tester.pumpAndSettle();
    final server = state.servers.single;
    await state.createSalon(serverId: server.id, name: 'Tournoi', emoji: '🎮', emojiBg: 0);
    await tester.pumpAndSettle();
    final salon = state.salons.single;
    await state.addSalonMemberByEmail(serverId: server.id, salonId: salon.id, email: 'tom@test.fr');
    await tester.pumpAndSettle();

    state.selectSalon(server.id, salon.id);
    await tester.pumpAndSettle();
    expect(state.liveSessions, isEmpty);

    // Drive the wizard directly through AppState (kind -> game -> players ->
    // scores) instead of tapping through the sheet's UI — reaching the
    // scores step via primaryAction() is what actually matters here (it's
    // what fires _startLiveSessionIfNeeded), and the wizard's own navigation
    // is already covered by the plain-match UI test.
    state.openSheet();
    state.setCreationKind('game');
    await state.primaryAction();
    state.pickGame('catan');
    await state.primaryAction();
    state.togglePlayer('lea');
    state.togglePlayer('tom');
    await state.primaryAction();
    // Same reasoning as the group live-session test: don't pumpAndSettle
    // through the "EN DIRECT" pulsing dot's endless animation.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(state.liveSessions, hasLength(1), reason: 'reaching the scores step in a salon must now broadcast a live session too');
    final session = state.liveSessions.single;
    expect(session.salonId, salon.id);
    expect(session.groupId, isEmpty);

    // Bump a score and let the debounced push go through.
    state.bump('lea', 5);
    await tester.pump(const Duration(milliseconds: 600));
    expect(state.liveSessions.single.entries.firstWhere((e) => e.playerId == 'lea').points, 5);

    state.draft.points['lea'] = 10;
    state.draft.points['tom'] = 8;
    await state.saveGame();
    await tester.pumpAndSettle();
    expect(state.liveSessions, isEmpty, reason: 'saving ends the live session');

    await tester.pump(const Duration(milliseconds: 2700));
  });

  testWidgets('a scheduled event handles sign-ups, a waitlist, and pre-fills the wizard when started', (tester) async {
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

    final state = seeded.state;
    await state.createServer(name: 'Café Test', emoji: '☕', emojiBg: 0);
    await tester.pumpAndSettle();
    final server = state.servers.single;
    await state.createSalon(serverId: server.id, name: 'Tournoi', emoji: '🎮', emojiBg: 0);
    await tester.pumpAndSettle();
    final salon = state.salons.single;
    await state.addSalonMemberByEmail(serverId: server.id, salonId: salon.id, email: 'tom@test.fr');
    await tester.pumpAndSettle();

    state.selectSalon(server.id, salon.id);
    await tester.pumpAndSettle();
    expect(state.canManageEvents(server), isTrue, reason: 'the creator is the owner, always an admin');

    final event = await state.createScheduledEvent(
      serverId: server.id,
      salonId: salon.id,
      gameId: 'catan',
      kind: 'game',
      name: 'Catan du samedi',
      scheduledAt: DateTime.now().add(const Duration(days: 3)),
      capacity: 1,
    );
    await tester.pumpAndSettle();
    expect(event, isNotNull);
    expect(state.viewEvents, hasLength(1));

    // Two sign-ups against a capacity of 1: the first is confirmed, the
    // second lands on the waitlist.
    await state.registerForEvent(event!);
    await tester.pumpAndSettle();
    var current = state.events.firstWhere((e) => e.id == event.id);
    expect(current.confirmedIds, ['lea']);
    expect(current.waitlistIds, isEmpty);

    // Simulate tom signing up too, straight through the repository — the
    // same path AppState.registerForEvent would take on his behalf (mirrors
    // how the salon-match confirmation test simulates another device).
    await state.eventsRepo.register(serverId: server.id, eventId: event.id, uid: 'tom');
    await tester.pumpAndSettle();
    current = state.events.firstWhere((e) => e.id == event.id);
    expect(current.confirmedIds, ['lea']);
    expect(current.waitlistIds, ['tom']);

    // Léa cancels — tom is promoted automatically, no separate step needed.
    await state.unregisterFromEvent(current);
    await tester.pumpAndSettle();
    current = state.events.firstWhere((e) => e.id == event.id);
    expect(current.confirmedIds, ['tom']);
    expect(current.waitlistIds, isEmpty);

    // Starting the event pre-fills the wizard with whoever is confirmed.
    state.startEvent(current);
    await tester.pumpAndSettle();
    expect(state.sheetOpen, isTrue);
    expect(state.draft.creationKind, 'game');
    expect(state.draft.gameId, 'catan');
    expect(state.draft.playerIds, ['tom']);
    expect(state.currentStepKind, WizardStepKind.players);

    await tester.pump(const Duration(milliseconds: 2700));
  });

  testWidgets('a tournament created inside a salon is salon-scoped and its matches stay pending until confirmed', (tester) async {
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

    final state = seeded.state;
    await state.createServer(name: 'Café Test', emoji: '☕', emojiBg: 0);
    await tester.pumpAndSettle();
    final server = state.servers.single;
    await state.createSalon(serverId: server.id, name: 'Tournoi', emoji: '🎮', emojiBg: 0);
    await tester.pumpAndSettle();
    final salon = state.salons.single;
    await state.addSalonMemberByEmail(serverId: server.id, salonId: salon.id, email: 'tom@test.fr');
    await tester.pumpAndSettle();

    state.selectSalon(server.id, salon.id);
    await tester.pumpAndSettle();
    expect(state.games.any((g) => g.id == 'catan'), isTrue, reason: 'the server\'s shared starter catalog is available here');

    final tournament = await state.createTournament(
      name: 'Tournoi Catan',
      gameId: 'catan',
      format: TournamentFormat.singleElimination,
      entrantPlayerIds: const [
        ['lea'],
        ['tom'],
      ],
    );
    await tester.pumpAndSettle();

    expect(tournament, isNotNull, reason: 'tournaments must actually work from within a salon now');
    expect(tournament!.isSalonTournament, isTrue);
    expect(tournament.groupId, isEmpty);
    expect(state.tournaments, contains(predicate<Tournament>((t) => t.id == tournament.id)), reason: 'the salon subscription picks it up');

    // A pending tournament refuses scoring until it's started.
    expect(tournament.isPending, isTrue);
    state.startTournamentMatch(tournament, tournament.matches.single);
    expect(state.isEditingTournamentMatch, isFalse);
    expect(await state.startTournament(tournament), isTrue);
    await tester.pumpAndSettle();
    final started = state.tournaments.firstWhere((t) => t.id == tournament.id);
    expect(started.isPending, isFalse);

    final bracketMatch = started.matches.single;
    state.startTournamentMatch(started, bracketMatch);
    state.draft.points['lea'] = 10;
    state.draft.points['tom'] = 5;
    await state.saveGame();
    await tester.pumpAndSettle();

    final saved = state.matches.firstWhere((m) => m.tournamentId == tournament.id);
    expect(saved.isSalonMatch, isTrue);
    expect(saved.salonId, salon.id);
    expect(saved.status, 'pending', reason: 'lea authored it (auto-confirmed) but tom still needs to confirm');

    // The bracket itself already advanced off the real (if not yet fully
    // confirmed) result — mirrors how a Group tournament always has.
    final updatedTournament = state.tournaments.firstWhere((t) => t.id == tournament.id);
    final leaEntrantId = updatedTournament.entrants.firstWhere((e) => e.playerIds.contains('lea')).id;
    expect(updatedTournament.matchById(bracketMatch.id)?.winnerId, leaEntrantId);

    // lea (the author) already auto-confirmed on save — simulate tom's
    // confirmation arriving from another device, same as the plain-salon-match
    // test above.
    await state.serverMatchesRepo.confirmMatch(rootId: server.id, matchId: saved.id, uid: 'tom');
    await tester.pumpAndSettle();
    final confirmed = state.matches.firstWhere((m) => m.id == saved.id);
    expect(confirmed.status, 'confirmed');

    await tester.pump(const Duration(milliseconds: 2700));
  });

  testWidgets('the server detail screen shows a match count per salon, scoped correctly', (tester) async {
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

    await state.createSalon(serverId: server.id, name: 'Salon A', emoji: '🎮', emojiBg: 0);
    await state.createSalon(serverId: server.id, name: 'Salon B', emoji: '🎯', emojiBg: 0);
    await tester.pumpAndSettle();
    final salonA = state.salons.firstWhere((s) => s.name == 'Salon A');

    // Record one match in Salon A only — this exercises the fix for a real
    // bug found while investigating: watchMatches/countMatches used to
    // filter on the `groupId` field even for Salon matches, which are
    // always empty on that field (they carry `salonId` instead), so a
    // Salon's matches never actually matched the query.
    state.selectSalon(server.id, salonA.id);
    await tester.pumpAndSettle();
    state.pickGame('catan');
    state.togglePlayer('tom');
    state.draft.points['tom'] = 10;
    await state.saveGame();
    await tester.pumpAndSettle();
    expect(state.matches, hasLength(1), reason: 'the match is visible from within Salon A itself');

    // saveGame() switched to the History tab — back to Home to reach the
    // header (IndexedStack keeps History mounted but not hit-testable).
    state.setTab(AppTab.home);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salon A'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Café Test'));
    await tester.pumpAndSettle();

    expect(find.textContaining('1 parties'), findsOneWidget, reason: 'Salon A shows its 1 recorded match');
    expect(find.textContaining('0 parties'), findsOneWidget, reason: 'Salon B has none');

    await tester.pump(const Duration(milliseconds: 2700));
  });

  group('group membership', () {
    Future<AppState> signedIn(WidgetTester tester, AppUser who) async {
      final seeded = _buildSeededState();
      await tester.pumpWidget(
        ChangeNotifierProvider.value(value: seeded.state, child: const MaterialApp(home: GroupsPage())),
      );
      seeded.auth.debugSignIn(who);
      await tester.pumpAndSettle();
      return seeded.state;
    }

    Future<void> openGroupMenu(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.more_horiz).first);
      await tester.pumpAndSettle();
    }

    testWidgets('a plain member can leave the group from its menu', (tester) async {
      final app = await signedIn(tester, _tom);
      expect(find.text('Les Bandits'), findsOneWidget);

      await openGroupMenu(tester);
      expect(find.text('Supprimer le groupe'), findsNothing);
      await tester.tap(find.text('Quitter le groupe'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quitter'));
      await tester.pumpAndSettle();

      expect(app.groups, isEmpty);
      expect(find.text('Les Bandits'), findsNothing);
      await tester.pump(const Duration(milliseconds: 2700));
    });

    testWidgets('the owner can remove a member from the members dialog', (tester) async {
      final app = await signedIn(tester, _lea);

      await openGroupMenu(tester);
      expect(find.text('Quitter le groupe'), findsNothing);
      await tester.tap(find.text('Membres'));
      await tester.pumpAndSettle();
      expect(find.text('Léa (vous)'), findsOneWidget);
      expect(find.text('PROPRIÉTAIRE'), findsOneWidget);

      await tester.tap(find.byTooltip('Gérer Tom'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retirer du groupe'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retirer'));
      await tester.pumpAndSettle();

      expect(app.groupById('bandits')!.memberIds, ['lea']);
      expect(find.text('Tom'), findsNothing);
      await tester.pump(const Duration(milliseconds: 2700));
    });

    testWidgets('the owner can hand ownership over, then leave', (tester) async {
      final app = await signedIn(tester, _lea);

      await openGroupMenu(tester);
      await tester.tap(find.text('Membres'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Gérer Tom'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rendre propriétaire'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Transférer'));
      await tester.pumpAndSettle();

      expect(app.groupById('bandits')!.ownerId, 'tom');
      // No longer the owner: the owner-only actions are gone and leaving is offered.
      expect(find.byTooltip('Gérer Tom'), findsNothing);
      await tester.tap(find.text('Quitter le groupe'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quitter'));
      await tester.pumpAndSettle();

      expect(app.groups, isEmpty);
      await tester.pump(const Duration(milliseconds: 2700));
    });

    testWidgets('the owner cannot leave, nor be removed, nor hand ownership to a guest', (tester) async {
      final app = await signedIn(tester, _lea);
      final group = app.groupById('bandits')!;

      expect(await app.leaveGroup(group), isFalse);
      expect(app.flowError, contains('Transférez la propriété'));
      expect(await app.removeGroupMember(group, 'lea'), isFalse);
      expect(await app.transferGroupOwnership(group, 'guest:g1'), isFalse);
      expect(app.groupById('bandits')!.memberIds, ['lea', 'tom']);
      expect(app.groupById('bandits')!.ownerId, 'lea');
    });

    testWidgets('a plain member cannot remove others or take ownership', (tester) async {
      final app = await signedIn(tester, _tom);
      final group = app.groupById('bandits')!;

      expect(await app.removeGroupMember(group, 'lea'), isFalse);
      expect(await app.transferGroupOwnership(group, 'tom'), isFalse);
      expect(app.groupById('bandits')!.memberIds, ['lea', 'tom']);
      expect(app.groupById('bandits')!.ownerId, 'lea');
    });
  });

  group('invite links', () {
    test('a shared link wraps the QR code and parses back from either form', () {
      const code = GroupInviteCode(groupId: 'bandits', name: 'Les Bandits & co', emoji: '🃏');
      final link = inviteLinkFor(code.encode());
      expect(link, startsWith('https://thomas26215.github.io/Podium/rejoindre.html?c='));
      expect(unwrapInviteCode(link), code.encode());
      expect(unwrapInviteCode(code.encode()), code.encode());
      expect(GroupInviteCode.tryParse(link)?.name, 'Les Bandits & co');

      const salon = SalonInviteCode(serverId: 's', salonId: 'r', name: 'Mardi', emoji: '🎮');
      expect(SalonInviteCode.tryParse(inviteLinkFor(salon.encode()))?.salonId, 'r');

      expect(unwrapInviteCode('https://example.com/rejoindre.html?c=${Uri.encodeComponent(code.encode())}'), isNull);
      expect(unwrapInviteCode('https://thomas26215.github.io/Podium/rejoindre.html?c=https%3A%2F%2Fevil.fr'), isNull);
    });

    testWidgets('sharing a link opens the join window for 7 days, and the QR tab never shortens it', (tester) async {
      final seeded = _buildSeededState();
      seeded.auth.debugSignIn(_lea);
      await tester.pump();
      final app = seeded.state;

      final message = await app.shareGroupInviteLink(app.groupById('bandits')!);
      expect(message, contains('Les Bandits'));
      expect(GroupInviteCode.tryParse(message!.split(' ').last)?.groupId, 'bandits');
      await tester.pump();
      final linkExpiry = app.groupById('bandits')!.inviteExpiresAt!;
      expect(linkExpiry.isAfter(DateTime.now().add(const Duration(days: 6))), isTrue);

      await app.refreshInviteWindow('bandits');
      await tester.pump();
      expect(app.groupById('bandits')!.inviteExpiresAt, linkExpiry);

      await app.setGroupClosed('bandits', true);
      await tester.pump();
      expect(await app.shareGroupInviteLink(app.groupById('bandits')!), isNull);
      await tester.pump(const Duration(milliseconds: 2700));
    });

    Future<(AppState, FakeAuthRepository, StreamController<Uri>, String)> pumpWithLinks(WidgetTester tester) async {
      final seeded = _buildSeededState();
      final links = StreamController<Uri>();
      addTearDown(links.close);
      final other = await seeded.state.groupsRepo.createGroup(name: 'Soirée jeux', emoji: '🎲', emojiBg: 0xFFFFE9E1, ownerId: 'tom');
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: seeded.state,
          child: MaterialApp(home: InviteLinkHandler(links: links.stream, child: const AuthGate())),
        ),
      );
      return (seeded.state, seeded.auth, links, other.id);
    }

    testWidgets('a link opening the app asks to join, then joins the group', (tester) async {
      final (app, auth, links, groupId) = await pumpWithLinks(tester);
      auth.debugSignIn(_lea);
      await tester.pumpAndSettle();

      links.add(Uri.parse(GroupInviteCode(groupId: groupId, name: 'Soirée jeux', emoji: '🎲').encode()));
      await tester.pumpAndSettle();
      expect(find.text('🎲 Rejoindre « Soirée jeux » ?'), findsOneWidget);

      await tester.tap(find.text('Rejoindre'));
      await tester.pumpAndSettle();
      expect(app.groupById(groupId)!.memberIds, contains('lea'));
      await tester.pump(const Duration(milliseconds: 2700));
    });

    testWidgets('a link arriving before sign-in waits for it, and cancelling joins nothing', (tester) async {
      final (app, auth, links, groupId) = await pumpWithLinks(tester);
      links.add(Uri.parse(GroupInviteCode(groupId: groupId, name: 'Soirée jeux', emoji: '🎲').encode()));
      await tester.pumpAndSettle();
      expect(find.textContaining('Rejoindre « Soirée jeux »'), findsNothing);

      auth.debugSignIn(_lea);
      await tester.pumpAndSettle();
      expect(find.text('🎲 Rejoindre « Soirée jeux » ?'), findsOneWidget);

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(app.groupById(groupId), isNull);
      expect(find.textContaining('Rejoindre « Soirée jeux »'), findsNothing);
    });

    testWidgets('an expired link says why it can\'t be used', (tester) async {
      final (app, auth, links, groupId) = await pumpWithLinks(tester);
      await app.groupsRepo.refreshInviteWindow(groupId, until: DateTime.now().subtract(const Duration(minutes: 1)));
      auth.debugSignIn(_lea);
      await tester.pumpAndSettle();

      links.add(Uri.parse(GroupInviteCode(groupId: groupId, name: 'Soirée jeux', emoji: '🎲').encode()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rejoindre'));
      await tester.pumpAndSettle();

      expect(find.text('Impossible de rejoindre'), findsOneWidget);
      expect(find.textContaining('expiré'), findsOneWidget);
      expect(app.groupById(groupId), isNull);
    });
  });

  testWidgets('the invite dialog\'s "Lien / QR" tab fits a small phone screen', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final seeded = _buildSeededState();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: seeded.state, child: const MaterialApp(home: GroupsPage())),
    );
    seeded.auth.debugSignIn(_lea);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_horiz).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inviter un ami'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lien / QR'));
    await tester.pumpAndSettle();

    expect(find.text('Partager un lien'), findsOneWidget);
    expect(find.text('ou sur place'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(find.byType(QrImageView), findsOneWidget);
    // The QR is scanned with the phone's own camera, so it holds the https link.
    final link = seeded.state.groupInviteLink(seeded.state.groupById('bandits')!);
    expect(link, startsWith(kInviteLinkPage));
    expect(GroupInviteCode.tryParse(link)?.groupId, 'bandits');
    await tester.pump(const Duration(milliseconds: 2700));
  });

  testWidgets('"Rejoindre" joins from a pasted invite link, and rejects anything else', (tester) async {
    final seeded = _buildSeededState();
    final other = await seeded.state.groupsRepo.createGroup(name: 'Soirée jeux', emoji: '🎲', emojiBg: 0xFFFFE9E1, ownerId: 'tom');
    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: seeded.state, child: const MaterialApp(home: GroupsPage())),
    );
    seeded.auth.debugSignIn(_lea);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rejoindre'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'https://example.com/pas-une-invitation');
    await tester.tap(find.widgetWithText(PrimaryButton, 'Rejoindre'));
    await tester.pumpAndSettle();
    expect(find.text("Ce n'est pas un lien d'invitation Podium."), findsOneWidget);

    final link = inviteLinkFor(GroupInviteCode(groupId: other.id, name: other.name, emoji: other.emoji).encode());
    await tester.enterText(find.byType(TextField), '  $link  ');
    await tester.tap(find.widgetWithText(PrimaryButton, 'Rejoindre'));
    await tester.pumpAndSettle();

    expect(seeded.state.groupById(other.id)!.memberIds, contains('lea'));
    expect(find.byType(TextField), findsNothing, reason: 'the dialog closes once joined');
    await tester.pump(const Duration(milliseconds: 2700));
  });
}
