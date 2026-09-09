// Local preview entry point — runs the whole app against the in-memory
// Fake* repositories (seeded with sample data) instead of Firebase, so you
// can look at every screen before a real Firebase project is connected.
//
// Run with: flutter run -d chrome -t lib/main_preview.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'models/app_user.dart';
import 'models/group.dart';
import 'models/match.dart';
import 'repositories/fakes.dart';
import 'repositories/game_library_repository.dart';
import 'repositories/games_repository.dart';
import 'repositories/guests_repository.dart';
import 'repositories/users_repository.dart';
import 'screens/auth/auth_gate.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

const _lea = AppUser(uid: 'lea', email: 'lea@podium.dev', displayName: 'Léa', color: 0xFFFF5B34);
const _tom = AppUser(uid: 'tom', email: 'tom@podium.dev', displayName: 'Tom', color: 0xFF5B4BE8);
const _nina = AppUser(uid: 'nina', email: 'nina@podium.dev', displayName: 'Nina', color: 0xFF1F9D57);
const _karim = AppUser(uid: 'karim', email: 'karim@podium.dev', displayName: 'Karim', color: 0xFFE8A93B);
const _sofia = AppUser(uid: 'sofia', email: 'sofia@podium.dev', displayName: 'Sofia', color: 0xFFE5537B);

void main() {
  // If you're running this in a network-restricted sandbox (no access to
  // fonts.gstatic.com), `import 'package:google_fonts/google_fonts.dart'`
  // and set `GoogleFonts.config.allowRuntimeFetching = false;` here to fall
  // back to the platform default typeface instead of hanging on a blocked
  // font fetch.

  final usersMap = {'lea': _lea, 'tom': _tom, 'nina': _nina, 'karim': _karim, 'sofia': _sofia};
  final users = FakeUsersRepository(usersMap);
  final auth = FakeAuthRepository(seedUsers: usersMap);

  final root = Group(
    id: 'bandits',
    name: 'Les Bandits',
    emoji: '🃏',
    emojiBg: 0xFFFFE9E1,
    memberIds: const ['tom', 'karim'],
    ownerId: 'tom',
  );
  final work = Group(
    id: 'bandits-work',
    name: 'Bureau',
    emoji: '💼',
    emojiBg: 0xFFE7EBFF,
    memberIds: const ['tom', 'lea', 'nina'],
    ownerId: 'tom',
  );
  final ext = Group(
    id: 'bandits-ext',
    name: 'Ext. soirée',
    emoji: '🌙',
    emojiBg: 0xFFFFE9D6,
    memberIds: const ['tom', 'sofia'],
    ownerId: 'tom',
  );
  final groups = FakeGroupsRepository(seedGroups: {'bandits': root, 'bandits-work': work, 'bandits-ext': ext}, users: users);

  final games = FakeGamesRepository(seed: {
    'bandits': List.of(kDefaultGames),
    'bandits-work': List.of(kDefaultGames),
    'bandits-ext': List.of(kDefaultGames),
  });

  GameMatch m(String id, String gameId, String groupId, List<MatchEntry> entries, {String mode = 'ffa', Duration ago = Duration.zero}) {
    return GameMatch(
      id: id,
      gameId: gameId,
      groupId: groupId,
      mode: mode,
      unit: 'points',
      lowWins: false,
      entries: entries,
      timeline: const [],
      createdAt: DateTime.now().subtract(ago),
    );
  }

  final matches = FakeMatchesRepository(seed: {
    'bandits': [
      m('m1', 'catan', 'bandits', const [MatchEntry(playerId: 'tom', points: 10), MatchEntry(playerId: 'karim', points: 8)]),
      m('m3', 'mk', 'bandits', const [MatchEntry(playerId: 'karim', points: 60), MatchEntry(playerId: 'tom', points: 45)], ago: const Duration(days: 3)),
    ],
    'bandits-work': [
      m('m2', 'skyjo', 'bandits-work', const [MatchEntry(playerId: 'lea', points: 24), MatchEntry(playerId: 'nina', points: 45)]),
    ],
    'bandits-ext': [
      m('m6', 'petanque', 'bandits-ext', const [MatchEntry(playerId: 'tom', points: 13, teamId: 'A'), MatchEntry(playerId: 'sofia', points: 13, teamId: 'A'), MatchEntry(playerId: 'karim', points: 9, teamId: 'B')], mode: 'team', ago: const Duration(days: 23)),
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

  runApp(ChangeNotifierProvider.value(
    value: state,
    child: MaterialApp(
      title: 'Podium (preview)',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      locale: const Locale('fr'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('fr')],
      home: const AuthGate(),
      builder: (context, child) {
        // Auto sign-in as Tom so the preview lands straight on the app.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (state.currentUser == null) auth.debugSignIn(_tom);
        });
        return child!;
      },
    ),
  ));
}
