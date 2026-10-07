// What keeps a big community cheap to load: synced copies that only take
// what changed, member profiles from rosters, the discussion thread a page
// at a time, and salons a plain member can actually read.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:podium/models/app_user.dart';
import 'package:podium/models/group.dart';
import 'package:podium/models/match.dart';
import 'package:podium/models/message.dart';
import 'package:podium/models/salon.dart';
import 'package:podium/models/server.dart';
import 'package:podium/repositories/fakes.dart';
import 'package:podium/repositories/game_library_repository.dart';
import 'package:podium/repositories/games_repository.dart';
import 'package:podium/repositories/guests_repository.dart';
import 'package:podium/repositories/messages_repository.dart';
import 'package:podium/repositories/synced_query.dart';
import 'package:podium/repositories/users_repository.dart';
import 'package:podium/screens/auth/auth_gate.dart';
import 'package:podium/state/app_state.dart';

const _lea = AppUser(uid: 'lea', email: 'lea@test.fr', displayName: 'Léa', color: 0xFFFF5B34);
const _tom = AppUser(uid: 'tom', email: 'tom@test.fr', displayName: 'Tom', color: 0xFF5B4BE8);
const _ana = AppUser(uid: 'ana', email: 'ana@test.fr', displayName: 'Ana', color: 0xFF1F9D57);

class _Seeded {
  final AppState state;
  final FakeAuthRepository auth;
  final FakeUsersRepository users;
  final FakeMessagesRepository messages;
  _Seeded(this.state, this.auth, this.users, this.messages);
}

_Seeded _seed({
  Map<String, AppUser> extraUsers = const {},
  Map<String, Server> servers = const {},
  Map<String, Salon> salons = const {},
  Map<String, List<GroupMessage>> messages = const {},
}) {
  final usersMap = {'lea': _lea, 'tom': _tom, 'ana': _ana, ...extraUsers};
  final users = FakeUsersRepository(usersMap);
  final auth = FakeAuthRepository(seedUsers: usersMap);
  final group = Group(id: 'bandits', name: 'Les Bandits', emoji: '🃏', emojiBg: 0xFFFFE9E1, memberIds: const ['lea', 'tom', 'ana'], ownerId: 'lea');
  final thread = FakeMessagesRepository(seed: {for (final e in messages.entries) e.key: List.of(e.value)});
  final state = AppState(
    authRepo: auth,
    groupsRepo: FakeGroupsRepository(seedGroups: {'bandits': group}, users: users),
    gamesRepo: FakeGamesRepository(seed: {'bandits': List.of(kDefaultGames)}),
    matchesRepo: FakeMatchesRepository(),
    tournamentsRepo: FakeTournamentsRepository(),
    usersRepo: users,
    guestsRepo: FakeGuestsRepository(),
    gameLibraryRepo: FakeGameLibraryRepository(),
    serversRepo: FakeServersRepository(seedServers: Map.of(servers), seedSalons: Map.of(salons), users: users),
    serverGamesRepo: FakeGamesRepository(),
    serverMatchesRepo: FakeMatchesRepository(),
    serverTournamentsRepo: FakeTournamentsRepository(),
    eventsRepo: FakeEventsRepository(),
    messagesRepo: thread,
    serverMessagesRepo: FakeMessagesRepository(),
  );
  return _Seeded(state, auth, users, thread);
}

Future<void> _signIn(WidgetTester tester, _Seeded seeded, AppUser user) async {
  await tester.pumpWidget(ChangeNotifierProvider.value(value: seeded.state, child: const MaterialApp(home: AuthGate())));
  await tester.pump();
  seeded.auth.debugSignIn(user);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('SyncedDocs', () {
    SyncedDocs<String> docs() => SyncedDocs<String>((id, data) => '$id:${data['v']}', compare: (a, b) => a.compareTo(b));

    test('shows every document but the deleted ones, which still count', () {
      final d = docs()
        ..put('b', {'v': 2})
        ..put('a', {'v': 1})
        ..put('c', {'v': 3, kDeleted: true});
      expect(d.visible, ['a:1', 'b:2']);
      expect(d.length, 3, reason: 'a server-side count() includes tombstones too');
    });

    test('resumes from the newest stamp it holds', () {
      final d = docs()
        ..put('a', {'v': 1, kUpdatedAt: Timestamp(100, 0)})
        ..put('b', {'v': 2, kUpdatedAt: Timestamp(300, 0)})
        ..put('c', {'v': 3});
      expect(d.newest, Timestamp(300, 0));
      d.put('b', {'v': 4});
      expect(d.newest, Timestamp(100, 0), reason: 'an edit still waiting for its server stamp has none');
      d.remove('a');
      expect(d.newest, isNull);
      expect(docs().newest, isNull, reason: 'nothing written since updatedAt existed');
    });

    test('a later write replaces the copy, and a tombstone hides it', () {
      final d = docs()..put('a', {'v': 1});
      d.put('a', {'v': 2});
      expect(d.visible, ['a:2']);
      d.put('a', {kDeleted: true});
      expect(d.visible, isEmpty);
      d.clear();
      expect(d.length, 0);
    });

    test('a checked copy is trusted for a week, unless it shrank', () {
      final checkedAt = DateTime(2026, 10, 1);
      bool trusted(DateTime now, {int held = 100}) => trustSyncedCopy(checkedAt: checkedAt, checkedCount: 100, held: held, now: now);
      expect(trusted(DateTime(2026, 10, 3)), isTrue);
      expect(trusted(DateTime(2026, 10, 3), held: 140), isTrue, reason: 'grown through deltas');
      expect(trusted(DateTime(2026, 10, 3), held: 99), isFalse, reason: 'tombstones never shrink a copy: the cache lost some');
      expect(trusted(DateTime(2026, 10, 9)), isFalse, reason: 'checked again after kSyncVerifyEvery');
      expect(trustSyncedCopy(checkedAt: null, checkedCount: 0, held: 100), isFalse);
    });

    test('every write and tombstone carries a fresh stamp', () {
      expect(stamped({'v': 1}).keys, containsAll(['v', kUpdatedAt]));
      final t = tombstone({'salonId': 's'});
      expect(t['salonId'], 's');
      expect(t[kDeleted], isTrue);
      expect(t.keys, contains(kUpdatedAt));
    });
  });

  group('member profiles', () {
    testWidgets('come from the roster, with no read per member', (tester) async {
      final seeded = _seed();
      seeded.users.rosters['bandits'] = ['tom', 'ana'];
      await _signIn(tester, seeded, _lea);

      expect(seeded.state.playerById('tom')?.displayName, 'Tom');
      expect(seeded.state.playerById('ana')?.displayName, 'Ana');
      expect(seeded.users.fetchedIds, isNot(contains('tom')));
      expect(seeded.users.fetchedIds, isNot(contains('ana')));
    });

    testWidgets('missing from the roster are fetched on their own, once', (tester) async {
      final seeded = _seed();
      seeded.users.rosters['bandits'] = ['tom'];
      await _signIn(tester, seeded, _lea);

      expect(seeded.state.playerById('ana')?.displayName, 'Ana');
      expect(seeded.users.fetchedIds.where((id) => id == 'ana'), hasLength(1));
      expect(seeded.users.fetchedIds, isNot(contains('tom')));
    });

    testWidgets('of a thousand-member server load from its roster', (tester) async {
      final crowd = {for (var i = 0; i < 1000; i++) 'p$i': AppUser(uid: 'p$i', email: '', displayName: 'Joueur $i', color: 0xFF2AA8B0)};
      final server = Server(id: 'kfee', name: 'Kfée des jeux', emoji: '🎲', emojiBg: 0, ownerId: 'tom', adminIds: const [], memberIds: ['tom', 'lea', ...crowd.keys]);
      final seeded = _seed(extraUsers: crowd, servers: {'kfee': server});
      seeded.users.rosters['kfee'] = ['tom', ...crowd.keys.take(999)];
      await _signIn(tester, seeded, _lea);

      expect(seeded.state.playerById('p0')?.displayName, 'Joueur 0');
      expect(seeded.state.playerById('p999')?.displayName, 'Joueur 999', reason: 'the one the roster lacks is fetched');
      expect(seeded.users.fetchedIds.where((id) => id.startsWith('p')), ['p999']);
    });
  });

  group('discussion thread', () {
    List<GroupMessage> thread(int n) => [
          for (var i = 1; i <= n; i++)
            GroupMessage(id: 'm$i', authorId: i.isEven ? 'tom' : 'lea', text: 'Message $i', createdAt: DateTime(2026, 9, 1).add(Duration(minutes: i))),
        ];

    testWidgets('loads the latest page, then older ones on demand', (tester) async {
      final seeded = _seed(messages: {'bandits': thread(kMessagesPage + 10)});
      await _signIn(tester, seeded, _lea);
      final state = seeded.state;

      expect(state.messages, hasLength(kMessagesPage));
      expect(state.messages.first.text, 'Message 11');
      expect(state.hasOlderMessages, isTrue);

      state.setTab(AppTab.games);
      await tester.pumpAndSettle();
      expect(find.text('Message ${kMessagesPage + 10}'), findsOneWidget, reason: 'opens on the newest message');

      await tester.dragUntilVisible(find.text('Messages précédents'), find.byType(ListView), const Offset(0, 400));
      await tester.tap(find.text('Messages précédents'));
      await tester.pumpAndSettle();

      expect(state.messages, hasLength(kMessagesPage + 10));
      expect(state.messages.first.text, 'Message 1');
      expect(state.hasOlderMessages, isFalse);
      expect(find.text('Messages précédents'), findsNothing);
    });

    testWidgets('a short thread offers no older page', (tester) async {
      final seeded = _seed(messages: {'bandits': thread(3)});
      await _signIn(tester, seeded, _lea);
      seeded.state.setTab(AppTab.games);
      await tester.pumpAndSettle();

      expect(seeded.state.hasOlderMessages, isFalse);
      expect(find.text('Messages précédents'), findsNothing);
      expect(find.text('Message 3'), findsOneWidget);
    });

    testWidgets('follows a new message even once the page is full', (tester) async {
      final seeded = _seed(messages: {'bandits': thread(kMessagesPage + 10)});
      await _signIn(tester, seeded, _lea);
      seeded.state.setTab(AppTab.games);
      await tester.pumpAndSettle();

      await seeded.messages.sendMessage('bandits', authorId: 'tom', text: 'Tout frais');
      await tester.pumpAndSettle();
      expect(seeded.state.messages, hasLength(kMessagesPage), reason: 'still one page');
      expect(find.text('Tout frais'), findsOneWidget);
    });
  });

  group('in the background', () {
    GameMatch played(String id) => GameMatch(
          id: id,
          gameId: 'catan',
          groupId: 'bandits',
          mode: 'ffa',
          unit: 'points',
          lowWins: false,
          entries: const [MatchEntry(playerId: 'lea', points: 10), MatchEntry(playerId: 'tom', points: 8)],
          timeline: const [],
          createdAt: DateTime.now(),
        );

    testWidgets('listeners pause after a minute and catch up on return', (tester) async {
      final seeded = _seed();
      await _signIn(tester, seeded, _lea);
      final state = seeded.state;
      final matches = state.matchesRepo as FakeMatchesRepository;

      state.handleAppLifecycleChange(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 30));
      await matches.addMatch('bandits', played(''));
      await tester.pump();
      expect(state.matches, hasLength(1), reason: 'still listening during a quick app switch');

      await tester.pump(AppState.syncPauseAfter);
      await matches.addMatch('bandits', played(''));
      await tester.pump();
      expect(state.matches, hasLength(1), reason: 'paused: nothing is read in the background');

      state.handleAppLifecycleChange(AppLifecycleState.resumed);
      expect(state.groupDataFullyLoaded, isTrue, reason: 'the data stays on screen while it catches up');
      await tester.pumpAndSettle();
      expect(state.matches, hasLength(2));
      expect(state.groupDataFullyLoaded, isTrue);
    });

    testWidgets('coming back within the minute changes nothing', (tester) async {
      final seeded = _seed();
      await _signIn(tester, seeded, _lea);
      final state = seeded.state;

      state.handleAppLifecycleChange(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 20));
      state.handleAppLifecycleChange(AppLifecycleState.resumed);
      await tester.pump(AppState.syncPauseAfter);
      await (state.matchesRepo as FakeMatchesRepository).addMatch('bandits', played(''));
      await tester.pump();
      expect(state.matches, hasLength(1), reason: 'never paused, so still live');
    });

    testWidgets('a groups-list update keeps the data loaded', (tester) async {
      final seeded = _seed();
      await _signIn(tester, seeded, _lea);
      final state = seeded.state;
      expect(state.groupDataFullyLoaded, isTrue);

      await state.groupsRepo.addMemberId(groupId: 'bandits', memberId: 'guest:9');
      await tester.pump();
      expect(state.groupDataFullyLoaded, isTrue, reason: 'same group: nothing to reload');
      await tester.pumpAndSettle();
    });
  });

  group('salons', () {
    final server = Server(id: 'kfee', name: 'Kfée des jeux', emoji: '🎲', emojiBg: 0, ownerId: 'tom', adminIds: const [], memberIds: const ['tom', 'lea', 'ana']);
    final salons = {
      'jeudi': Salon(id: 'jeudi', serverId: 'kfee', name: 'Jeudi', emoji: '🎲', emojiBg: 0, memberIds: const ['lea', 'tom']),
      'tournoi': Salon(id: 'tournoi', serverId: 'kfee', name: 'Tournoi', emoji: '🏆', emojiBg: 0, memberIds: const ['ana', 'tom']),
    };

    testWidgets('a plain member only lists the ones they belong to', (tester) async {
      final seeded = _seed(servers: {'kfee': server}, salons: salons);
      await _signIn(tester, seeded, _lea);
      seeded.state.selectServer('kfee');
      await tester.pumpAndSettle();

      expect(seeded.state.salons.map((s) => s.id), ['jeudi']);
    });

    testWidgets('the owner lists them all', (tester) async {
      final seeded = _seed(servers: {'kfee': server}, salons: salons);
      await _signIn(tester, seeded, _tom);
      seeded.state.selectServer('kfee');
      await tester.pumpAndSettle();

      expect(seeded.state.salons.map((s) => s.id), unorderedEquals(['jeudi', 'tournoi']));
    });
  });

  test('a guest roster entry reads back as a guest', () {
    final guest = rosterProfile('guest:k1', {'displayName': 'Invité K', 'color': 0xFF8B5CF6, 'uid': 'guest:k1'});
    expect(guest.isGuest, isTrue);
    expect(guest.displayName, 'Invité K');
    expect(isGuestId(guest.uid), isTrue);
    final account = rosterProfile('ana', {'displayName': 'Ana', 'color': 0xFF1F9D57, 'uid': 'ana'});
    expect(account.isGuest, isFalse);
    expect(account.displayName, 'Ana');
  });
}
