// The library's downloads, matches played and likes: how counts are written,
// how the app reads them, and liking a game from its page — shown at once,
// never counted twice once the Cloud Function has tallied it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:podium/logic/count_format.dart';
import 'package:podium/models/app_user.dart';
import 'package:podium/models/game.dart';
import 'package:podium/models/group.dart';
import 'package:podium/models/library_game_stats.dart';
import 'package:podium/repositories/fakes.dart';
import 'package:podium/repositories/game_library_repository.dart';
import 'package:podium/repositories/games_repository.dart';
import 'package:podium/repositories/guests_repository.dart';
import 'package:podium/repositories/users_repository.dart';
import 'package:podium/screens/new_game/game_library_browser.dart';
import 'package:podium/screens/new_game/library_game_preview_screen.dart';
import 'package:podium/state/app_state.dart';
import 'package:podium/widgets/library_stats.dart';

const _lea = AppUser(uid: 'lea', email: 'lea@test.fr', displayName: 'Léa', color: 0xFFFF5B34);
const _tom = AppUser(uid: 'tom', email: 'tom@test.fr', displayName: 'Tom', color: 0xFF5B4BE8);

final _wonders = Game.simple(id: 'wonders', name: '7 Wonders', emoji: '🏛️', category: 'Société', countType: CountType.highWins, minPlayers: 3, maxPlayers: 7);
final _azul = Game.simple(id: 'azul', name: 'Azul', emoji: '🟦', category: 'Société', countType: CountType.highWins, minPlayers: 2, maxPlayers: 4);

/// A like that never reaches the server.
class _OfflineLibrary extends FakeGameLibraryRepository {
  _OfflineLibrary({super.seed, super.stats});

  @override
  Future<void> setLiked({required String uid, required String gameId, required bool liked}) async => throw Exception('offline');
}

({AppState state, FakeAuthRepository auth, FakeGameLibraryRepository library}) _seed({FakeGameLibraryRepository? library}) {
  final usersMap = {'lea': _lea, 'tom': _tom};
  final users = FakeUsersRepository(usersMap);
  final auth = FakeAuthRepository(seedUsers: usersMap);
  final group = Group(id: 'bandits', name: 'Les Bandits', emoji: '🃏', emojiBg: 0xFFFFE9E1, memberIds: const ['lea', 'tom'], ownerId: 'lea');
  final repo = library ??
      FakeGameLibraryRepository(
        seed: [_wonders, _azul],
        stats: {'wonders': const LibraryGameStats(gameId: 'wonders', downloads: 3, plays: 1234, likes: 2)},
      );
  final state = AppState(
    authRepo: auth,
    groupsRepo: FakeGroupsRepository(seedGroups: {'bandits': group}, users: users),
    gamesRepo: FakeGamesRepository(seed: {'bandits': List.of(kDefaultGames)}),
    matchesRepo: FakeMatchesRepository(),
    tournamentsRepo: FakeTournamentsRepository(),
    usersRepo: users,
    guestsRepo: FakeGuestsRepository(),
    gameLibraryRepo: repo,
    serversRepo: FakeServersRepository(users: users),
    serverGamesRepo: FakeGamesRepository(),
    serverMatchesRepo: FakeMatchesRepository(),
    serverTournamentsRepo: FakeTournamentsRepository(),
    eventsRepo: FakeEventsRepository(),
    messagesRepo: FakeMessagesRepository(),
    serverMessagesRepo: FakeMessagesRepository(),
  );
  return (state: state, auth: auth, library: repo);
}

/// [child] in an app signed in as Léa.
Future<AppState> _pump(WidgetTester tester, Widget child, {FakeGameLibraryRepository? library}) async {
  final seeded = _seed(library: library);
  seeded.auth.debugSignIn(_lea);
  await tester.pumpWidget(ChangeNotifierProvider.value(value: seeded.state, child: MaterialApp(home: child)));
  await tester.pumpAndSettle();
  return seeded.state;
}

Finder _likeButton() => find.bySemanticsLabel(RegExp("^J'aime"));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('counts are shortened past a thousand, never rounded up', () {
    expect(compactCount(0), '0');
    expect(compactCount(999), '999');
    expect(compactCount(1000), '1 k');
    expect(compactCount(1234), '1,2 k');
    expect(compactCount(1999), '1,9 k');
    expect(compactCount(10500), '10 k');
    expect(compactCount(999999), '999 k');
    expect(compactCount(2500000), '2,5 M');
  });

  test('stats read from Firestore default to zero and never go below it', () {
    final s = LibraryGameStats.fromDoc('catan', {'downloads': 4, 'plays': -1});
    expect((s.gameId, s.downloads, s.plays, s.likes), ('catan', 4, 0, 0));
    expect(LibraryGameStats.fromDoc('x', const {}).isEmpty, isTrue);
  });

  testWidgets("a library game's page shows its counts, and likes it at once", (tester) async {
    final app = await _pump(tester, LibraryGamePreviewScreen(game: _wonders));
    final library = app.gameLibraryRepo as FakeGameLibraryRepository;

    expect(find.text('3'), findsOneWidget);
    expect(find.text('téléchargements'), findsOneWidget);
    expect(find.text('1,2 k'), findsOneWidget);
    expect(find.text('parties jouées'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.byIcon(Icons.thumb_up_off_alt_rounded), findsOneWidget);

    await tester.tap(_likeButton());
    await tester.pumpAndSettle();
    expect(app.likedLibraryGames, contains('wonders'));
    expect(library.likes['lea'], contains('wonders'), reason: 'saved to her own list');
    expect(find.byIcon(Icons.thumb_up_alt_rounded), findsOneWidget);
    expect(find.text('3'), findsNWidgets(2), reason: '2 likes + hers, next to the 3 downloads');

    // Tallied server-side since: fetched again, hers is not counted twice.
    expect(library.stats['wonders']!.likes, 3);
    await app.signOut();
    await tester.pump();
    final auth = app.authRepo as FakeAuthRepository;
    auth.debugSignIn(_lea);
    await tester.pump();
    await app.refreshLibraryStats();
    await tester.pumpAndSettle();
    expect(app.libraryStatsOf('wonders').likes, 3);
    expect(app.likedLibraryGames, contains('wonders'));

    // And taken back.
    await tester.tap(_likeButton());
    await tester.pumpAndSettle();
    expect(app.libraryStatsOf('wonders').likes, 2);
    expect(library.likes['lea'], isNot(contains('wonders')));
    expect(find.byIcon(Icons.thumb_up_off_alt_rounded), findsOneWidget);
  });

  testWidgets('a game nobody counted yet shows zeros in the singular', (tester) async {
    await _pump(tester, LibraryGamePreviewScreen(game: _azul));
    expect(find.text('0'), findsNWidgets(3));
    expect(find.text('téléchargement'), findsOneWidget);
    expect(find.text('partie jouée'), findsOneWidget);
  });

  testWidgets("a like that can't be saved is taken back, with a toast", (tester) async {
    final app = await _pump(tester, LibraryGamePreviewScreen(game: _wonders), library: _OfflineLibrary(seed: [_wonders], stats: {'wonders': const LibraryGameStats(gameId: 'wonders', likes: 2)}));
    await tester.tap(_likeButton());
    await tester.pump();
    await tester.pump();
    expect(app.likedLibraryGames, isEmpty);
    expect(app.libraryStatsOf('wonders').likes, 2);
    expect(app.toast, "Votre « J'aime » n'a pas pu être enregistré.");
    await tester.pump(const Duration(seconds: 3)); // let the toast expire
  });

  testWidgets('the library lists each game with the counts it has', (tester) async {
    final app = await _pump(tester, const Scaffold(body: SingleChildScrollView(child: GameLibraryBrowser())));
    await app.startBrowsingLibrary();
    await app.toggleLibraryLike('wonders');
    await tester.pumpAndSettle();

    // Only 7 Wonders has counts; Azul's row has none.
    expect(find.byType(LibraryStatsLine), findsOneWidget);
    final line = find.byType(LibraryStatsLine);
    expect(find.descendant(of: line, matching: find.text('3')), findsNWidgets(2), reason: 'downloads, and likes with hers');
    expect(find.descendant(of: line, matching: find.text('1,2 k')), findsOneWidget);
    expect(find.descendant(of: line, matching: find.byIcon(Icons.thumb_up_alt_rounded)), findsOneWidget, reason: 'she likes it');
  });
}
