import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podium/models/app_user.dart';
import 'package:podium/models/group.dart';
import 'package:podium/repositories/fakes.dart';
import 'package:podium/repositories/games_repository.dart';
import 'package:podium/repositories/users_repository.dart';
import 'package:podium/repositories/guests_repository.dart';
import 'package:podium/repositories/game_library_repository.dart';
import 'package:podium/screens/new_game/game_actions_sheet.dart';
import 'package:podium/state/app_state.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regression: the default bottom sheet stops at ~56% of the screen and
/// doesn't scroll, which left "Supprimer" off-screen on a phone.
void main() {
  testWidgets('on a phone, the game menu scrolls down to "Supprimer" instead of cutting it off', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    const lea = AppUser(uid: 'lea', email: 'lea@test.fr', displayName: 'Léa', color: 0xFFFF5B34);
    final users = FakeUsersRepository({'lea': lea});
    final auth = FakeAuthRepository(seedUsers: {'lea': lea});
    final state = AppState(
      authRepo: auth,
      groupsRepo: FakeGroupsRepository(seedGroups: {'g': const Group(id: 'g', name: 'G', emoji: '🎲', emojiBg: 0, memberIds: ['lea'], ownerId: 'lea')}, users: users),
      gamesRepo: FakeGamesRepository(seed: {'g': List.of(kDefaultGames)}),
      matchesRepo: FakeMatchesRepository(),
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
    auth.debugSignIn(lea);
    await tester.pumpWidget(ChangeNotifierProvider.value(value: state, child: MaterialApp(home: Scaffold(body: Builder(builder: (c) => TextButton(onPressed: () => showGameActionsSheet(c, state, state.games.first), child: const Text('open')))))));
    await tester.pumpAndSettle();
    expect(state.canManageGameCatalog, isTrue);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final del = find.text('Supprimer');
    expect(del, findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'no overflow');
    await tester.ensureVisible(del);
    await tester.pumpAndSettle();
    await tester.tap(del);
    await tester.pumpAndSettle();
    expect(find.text('Supprimer « ${state.games.first.name} » ?'), findsOneWidget);
  });
}
