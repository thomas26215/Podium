import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'repositories/users_repository.dart';
import 'screens/auth/auth_gate.dart';
import 'services/notifications_service.dart';
import 'state/app_state.dart';
import 'state/session_manager.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!isFirebaseConfigured) {
    runApp(const _FirebaseSetupNeededApp());
    return;
  }

  final defaultApp = await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final notificationsService = NotificationsService(usersRepo: FirebaseUsersRepository());
  unawaited(notificationsService.init());

  final sessionManager = SessionManager(notificationsService: notificationsService);
  await sessionManager.bootstrapDefault(defaultApp);

  runApp(PodiumApp(sessionManager: sessionManager));
}

class PodiumApp extends StatelessWidget {
  final SessionManager sessionManager;

  const PodiumApp({super.key, required this.sessionManager});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SessionManager>.value(
      value: sessionManager,
      // Rebuilds whenever SessionManager changes (switching/opening/closing
      // an account) and re-exposes sessionManager.active as a plain
      // AppState via `.value` — NOT `ChangeNotifierProxyProvider`, which
      // would call .dispose() on the outgoing AppState every time `active`
      // changes identity (confirmed in provider's source: it disposes the
      // previous value whenever `update` returns a different instance).
      // That would kill a still-open background session's subscriptions
      // the moment you switch away from it. `.value` providers never
      // dispose what they're given, so switching accounts is safe — every
      // existing screen's context.watch<AppState>() keeps working
      // unchanged either way.
      child: ListenableBuilder(
        listenable: sessionManager,
        builder: (context, child) => ChangeNotifierProvider<AppState>.value(
          value: sessionManager.active,
          child: child,
        ),
        child: const _ThemedMaterialApp(),
      ),
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
