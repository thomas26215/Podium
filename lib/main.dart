import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'repositories/auth_repository.dart';
import 'repositories/game_library_repository.dart';
import 'repositories/games_repository.dart';
import 'repositories/groups_repository.dart';
import 'repositories/guests_repository.dart';
import 'repositories/matches_repository.dart';
import 'repositories/servers_repository.dart';
import 'repositories/tournaments_repository.dart';
import 'repositories/users_repository.dart';
import 'screens/auth/auth_gate.dart';
import 'services/notifications_service.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!isFirebaseConfigured) {
    runApp(const _FirebaseSetupNeededApp());
    return;
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final usersRepo = FirebaseUsersRepository();
  final notificationsService = NotificationsService(usersRepo: usersRepo);
  unawaited(notificationsService.init());

  runApp(PodiumApp(usersRepo: usersRepo, notificationsService: notificationsService));
}

class PodiumApp extends StatelessWidget {
  final UsersRepository usersRepo;
  final NotificationsService notificationsService;

  const PodiumApp({super.key, required this.usersRepo, required this.notificationsService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AppState(
            authRepo: FirebaseAuthRepository(),
            groupsRepo: FirebaseGroupsRepository(),
            gamesRepo: FirebaseGamesRepository(),
            matchesRepo: FirebaseMatchesRepository(),
            tournamentsRepo: FirebaseTournamentsRepository(),
            usersRepo: usersRepo,
            guestsRepo: FirebaseGuestsRepository(),
            gameLibraryRepo: FirebaseGameLibraryRepository(),
            serversRepo: FirebaseServersRepository(),
            serverGamesRepo: FirebaseGamesRepository(rootCollection: 'servers'),
            serverMatchesRepo: FirebaseMatchesRepository(rootCollection: 'servers'),
            notificationsService: notificationsService,
          ),
        ),
      ],
      child: const _ThemedMaterialApp(),
    );
  }
}

/// Rebuilds [MaterialApp]'s theme whenever the theme mode/accent changes
/// (AppState.setThemeMode/setAccentPreset), and also when the OS-level
/// light/dark setting flips while following "Système".
class _ThemedMaterialApp extends StatefulWidget {
  const _ThemedMaterialApp();

  @override
  State<_ThemedMaterialApp> createState() => _ThemedMaterialAppState();
}

class _ThemedMaterialAppState extends State<_ThemedMaterialApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    context.read<AppState>().refreshSystemBrightness();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    context.read<AppState>().handleAppLifecycleChange(state);
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppState>();
    return MaterialApp(
      title: 'Podium',
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
    );
  }
}

/// Shown instead of the real app until `flutterfire configure` has been run
/// against a real Firebase project — see lib/firebase_options.dart.
class _FirebaseSetupNeededApp extends StatelessWidget {
  const _FirebaseSetupNeededApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.local_fire_department_outlined, size: 40, color: AppColors.accent),
                  const SizedBox(height: 16),
                  Text('Connectez votre projet Firebase', textAlign: TextAlign.center, style: dispFont(size: 20, weight: FontWeight.w700, color: AppColors.ink)),
                  const SizedBox(height: 12),
                  Text(
                    "Podium a besoin d'un projet Firebase (Auth + Firestore).\n\n"
                    "1. Créez un projet sur console.firebase.google.com\n"
                    "2. Activez Authentication (E-mail/Mot de passe) et Firestore\n"
                    "3. Depuis ce dossier, lancez :\n"
                    "   dart pub global activate flutterfire_cli\n"
                    "   flutterfire configure\n"
                    "4. Déployez firestore.rules fourni à la racine du projet\n\n"
                    "Relancez l'app une fois configurée.",
                    textAlign: TextAlign.center,
                    style: bodyFont(size: 13.5, weight: FontWeight.w600, color: AppColors.ink2, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
