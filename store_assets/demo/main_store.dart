// Play Store demo entry point: the real app on the store demo world (see
// demo_data.dart), held in the app's in-memory Fake* repositories — no
// Firebase, nothing written anywhere. Signs in as Léa, or as the Bandit
// named by DEMO_AS (Chloé follows tonight's Skyjo live from home):
//   flutter build apk --debug -t store_assets/demo/main_store.dart [--dart-define=DEMO_AS=chloe]
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:podium/repositories/fakes.dart';
import 'package:podium/repositories/game_library_repository.dart';
import 'package:podium/repositories/guests_repository.dart';
import 'package:podium/repositories/users_repository.dart';
import 'package:podium/screens/auth/auth_gate.dart';
import 'package:podium/state/app_state.dart';
import 'package:podium/state/session_manager.dart';
import 'package:podium/theme/app_theme.dart';
import 'package:podium/widgets/appearance_scope.dart';
import 'package:provider/provider.dart';

import 'demo_data.dart';

const _signedInAs = String.fromEnvironment('DEMO_AS', defaultValue: 'lea');

void main() {
  final data = DemoData.build(DateTime.now(), liveSkyjo: _signedInAs != 'lea');

  final users = FakeUsersRepository(data.users)..rosters.addAll(data.rosters);
  final auth = FakeAuthRepository(seedUsers: data.users);
  final matches = FakeMatchesRepository(seed: data.groupMatches);
  if (data.liveSkyjo case final live?) {
    matches.liveSessionsByGroup[kBandits] = [live];
    // A session nobody has updated for a few minutes stops showing as live:
    // Léa's phone keeps it going.
    Timer.periodic(const Duration(minutes: 1), (_) {
      matches.updateLiveSession(rootGroupId: kBandits, sessionId: live.id, entries: live.entries, timeline: live.timeline, inputMode: live.inputMode);
    });
  }
  final events = FakeEventsRepository()..byServer.addAll(data.events);

  final state = AppState(
    authRepo: auth,
    groupsRepo: FakeGroupsRepository(seedGroups: data.groups, users: users),
    gamesRepo: FakeGamesRepository(seed: data.groupGames),
    matchesRepo: matches,
    tournamentsRepo: FakeTournamentsRepository(seed: data.groupTournaments),
    usersRepo: users,
    guestsRepo: FakeGuestsRepository(),
    gameLibraryRepo: FakeGameLibraryRepository(seed: data.library),
    serversRepo: FakeServersRepository(seedServers: data.servers, seedSalons: data.salons, users: users),
    serverGamesRepo: FakeGamesRepository(seed: data.serverGames),
    serverMatchesRepo: FakeMatchesRepository(seed: data.serverMatches),
    serverTournamentsRepo: FakeTournamentsRepository(),
    eventsRepo: events,
    messagesRepo: FakeMessagesRepository(seed: data.groupMessages),
    serverMessagesRepo: FakeMessagesRepository(seed: data.serverMessages),
  );
  final me = data.users[_signedInAs]!;

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: state),
      ChangeNotifierProvider<SessionManager>.value(value: SessionManager.single(state)),
    ],
    child: ListenableBuilder(
      listenable: state,
      builder: (context, _) => MaterialApp(
        title: 'Cador',
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
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (state.currentUser == null) auth.debugSignIn(me);
          });
          return AppearanceScope(child: child!);
        },
      ),
    ),
  ));
}
