import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';
import '../models/app_user.dart';
import '../models/saved_account.dart';
import '../repositories/auth_repository.dart';
import '../repositories/events_repository.dart';
import '../repositories/game_library_repository.dart';
import '../repositories/games_repository.dart';
import '../repositories/groups_repository.dart';
import '../repositories/guests_repository.dart';
import '../repositories/matches_repository.dart';
import '../repositories/servers_repository.dart';
import '../repositories/tournaments_repository.dart';
import '../repositories/users_repository.dart';
import '../services/notifications_service.dart';
import 'app_state.dart';

/// Builds the exact repo bundle `main.dart` used to build once for the
/// default Firebase app, but pointed at any [app] instead — the shared
/// factory both the default session and every secondary one (see
/// [SessionManager]) go through, so there's only one place that wires up
/// all 13 repos.
///
/// [FirebaseGroupsRepository]/[FirebaseServersRepository] each default their
/// own `users` dependency to a *default-app* [FirebaseUsersRepository] if
/// not given one explicitly — for any non-default [app] that would silently
/// leak back to the wrong Firebase session, so this always passes `users`
/// through explicitly instead of relying on that fallback.
AppState buildFirebaseAppState(FirebaseApp app) {
  final db = FirebaseFirestore.instanceFor(app: app);
  final auth = fb.FirebaseAuth.instanceFor(app: app);
  final usersRepo = FirebaseUsersRepository(db: db);
  return AppState(
    authRepo: FirebaseAuthRepository(auth: auth, db: db),
    groupsRepo: FirebaseGroupsRepository(db: db, users: usersRepo),
    gamesRepo: FirebaseGamesRepository(db: db),
    matchesRepo: FirebaseMatchesRepository(db: db),
    tournamentsRepo: FirebaseTournamentsRepository(db: db),
    usersRepo: usersRepo,
    guestsRepo: FirebaseGuestsRepository(db: db),
    gameLibraryRepo: FirebaseGameLibraryRepository(db: db),
    serversRepo: FirebaseServersRepository(db: db, users: usersRepo),
    serverGamesRepo: FirebaseGamesRepository(db: db, rootCollection: 'servers'),
    serverMatchesRepo: FirebaseMatchesRepository(db: db, rootCollection: 'servers'),
    serverTournamentsRepo: FirebaseTournamentsRepository(db: db, rootCollection: 'servers'),
    eventsRepo: FirebaseEventsRepository(db: db),
    // Deliberately not wired here — a session's own auth firing would
    // otherwise register/unregister push on its own, even while it's just
    // sitting open in the background. SessionManager drives push itself,
    // for whichever session is actually active. See _syncPushRegistration.
    notificationsService: null,
  );
}

class SessionEntry {
  /// Null only for [SessionManager.single]'s preview/test stand-in, which
  /// never touches real Firebase.
  final FirebaseApp? app;
  final AppState state;
  SessionEntry({this.app, required this.state});
}

/// Coordinates every Firebase-backed account signed into this app run at
/// once — the piece that makes tapping an already-open saved account switch
/// to it instantly, with no password, Gmail-style.
///
/// Each account gets its own secondary named [FirebaseApp] (see
/// [_namedAppFor]), which is the only way the Firebase SDKs support more than
/// one concurrently signed-in, independently persisted identity — the
/// default app can only ever hold one. Every [AppState] built here is
/// otherwise a completely ordinary, self-contained instance (own
/// subscriptions, own repos) — switching accounts is just changing which
/// one is exposed as [active]; the other keeps running in the background
/// exactly as it was.
class SessionManager extends ChangeNotifier {
  /// Null for [SessionManager.single] (preview/tests) — real
  /// [NotificationsService] touches `FirebaseMessaging.instance` in its own
  /// field initializer, which needs Firebase to actually be initialized.
  final NotificationsService? notificationsService;
  final Map<String, SessionEntry> _sessions = {};

  /// The bootstrap (default-app) session before its uid is known yet — see
  /// [bootstrapDefault]. Becomes a normal entry in [_sessions] the moment
  /// its own sign-in/restore resolves.
  SessionEntry? _pending;
  String? _activeUid;

  SessionManager({this.notificationsService});

  /// A trivial single-session stand-in for previews/tests that don't go
  /// through Firebase at all (see lib/main_preview.dart) — wraps an
  /// already-built [AppState] so screens that read [SessionManager] (like
  /// the saved-accounts chips or the "changer de compte" dialog) don't need
  /// Firebase to exist. `switchTo` is a harmless no-op here (nothing else
  /// is ever in [_sessions] to switch to). `openSession`/`closeSession`
  /// are NOT safe to actually invoke in this mode — they still try to talk
  /// to real Firebase — so previews should only ever exercise the "show
  /// the dialog" path, not actually submit its form.
  factory SessionManager.single(AppState state) {
    final manager = SessionManager();
    manager._pending = SessionEntry(state: state);
    return manager;
  }

  bool _disposed = false;

  AppState get active => (_activeUid != null ? _sessions[_activeUid] : null)?.state ?? _pending!.state;

  bool hasOpenSession(String uid) => _sessions.containsKey(uid);

  /// Every account actually signed in this run (background ones included) —
  /// what a "changer de compte" picker shows, as opposed to [savedAccounts]
  /// on [AppState], which is just remembered metadata and may include
  /// accounts with no live session at all right now.
  List<AppUser> get openAccounts => _sessions.values.map((e) => e.state.currentUser).whereType<AppUser>().toList(growable: false);

  bool busy = false;
  String? lastError;

  /// Builds the very first session, against the already-initialized default
  /// [app] — called once from `main.dart` before `runApp`. Doesn't block on
  /// it: also kicks off [_restoreOtherSavedAccounts] in the background, so
  /// every other saved account with a still-valid session quietly comes
  /// back too, without whoever's using the app having to do anything.
  Future<void> bootstrapDefault(FirebaseApp app) async {
    final state = buildFirebaseAppState(app);
    final entry = SessionEntry(app: app, state: state);
    _pending = entry;
    state.addListener(() => _onSessionStateChanged(entry));
    unawaited(_restoreOtherSavedAccounts(state));
  }

  /// Silently reconnects every *other* saved account whose named
  /// [FirebaseApp] still has a valid persisted session — the piece that
  /// makes more than one account available in "changer de compte" again
  /// after fully quitting and reopening the app, not just within a single
  /// run. Waits for the default session (`after`) to resolve first so it
  /// can skip that account (no point opening a second, redundant session
  /// for whoever's already the default), then tries the rest concurrently.
  /// Never prompts for a password and never surfaces an error — an account
  /// that isn't restorable (never used on this device yet, or its session
  /// expired/was revoked) just doesn't show up as open, exactly as before
  /// this ran.
  Future<void> _restoreOtherSavedAccounts(AppState after) async {
    await _waitUntilResolved(after);
    final skipUid = after.currentUser?.uid;
    final accounts = await _readSavedAccounts();
    await Future.wait(
      accounts.where((a) => a.uid.isNotEmpty && a.uid != skipUid).map((a) => tryRestore(a.email, a.uid)),
    );
  }

  static const _savedAccountsKey = 'saved_accounts_v1';

  /// Reads the same persisted list [AppState] keeps (see
  /// `AppState._loadSavedAccounts`) directly, rather than waiting on a
  /// particular [AppState] instance's own async load to finish — every
  /// session loads an identical copy from the same SharedPreferences key,
  /// so there's nothing session-specific to coordinate with here.
  Future<List<SavedAccount>> _readSavedAccounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_savedAccountsKey) ?? const <String>[];
      return raw.map((r) => SavedAccount.fromJson(Map<String, dynamic>.from(jsonDecode(r) as Map))).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Instantly switches to an account already open this run — no network
  /// call, no password, just changing which [AppState] is exposed.
  void switchTo(String uid) {
    if (_activeUid == uid || !_sessions.containsKey(uid)) return;
    _activeUid = uid;
    _syncPushRegistration();
    notifyListeners();
  }

  /// Signs into `email`/`password` under a fresh (or reused, if already
  /// created this run) named [FirebaseApp], and makes the result active.
  /// Used for a saved account that isn't open yet, or a brand new sign-in.
  Future<bool> openSession({required String email, required String password}) async {
    busy = true;
    lastError = null;
    notifyListeners();
    final app = await _namedAppFor(email);
    final state = buildFirebaseAppState(app);
    try {
      final ok = await _signInAndWait(state, email, password);
      if (!ok) {
        lastError = state.flowError;
        state.dispose();
        await app.delete().catchError((_) {});
        return false;
      }
      final uid = state.currentUser!.uid;
      final entry = SessionEntry(app: app, state: state);
      _sessions[uid] = entry;
      _activeUid = uid;
      state.addListener(() => _onSessionStateChanged(entry));
      _syncPushRegistration();
      return true;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// [AppState.signIn] resolves once the Firebase network call completes,
  /// but [AppState.currentUser] itself is only populated a moment later, by
  /// the separate `authStateChanges()` listener inside [AppState] — so a
  /// success can briefly look like neither success nor failure right after
  /// `await`. Wait one more tick for [AppState] to settle either way rather
  /// than racing it.
  Future<bool> _signInAndWait(AppState state, String email, String password) async {
    await state.signIn(email, password);
    if (state.currentUser != null) return true;
    if (state.flowError != null) return false;
    final completer = Completer<bool>();
    void listener() {
      if (state.currentUser != null || state.flowError != null) {
        completer.complete(state.currentUser != null);
      }
    }

    state.addListener(listener);
    try {
      return await completer.future.timeout(const Duration(seconds: 10), onTimeout: () => state.currentUser != null);
    } finally {
      state.removeListener(listener);
    }
  }

  /// Tries to silently pick back up `email`'s own persisted session under
  /// its named [FirebaseApp], with no password — returns whether that
  /// actually resulted in a signed-in session for `expectedUid`. Used both
  /// proactively at startup (see [_restoreOtherSavedAccounts]) and as an
  /// on-tap fallback from the login screen, in case a saved account's
  /// background restore hadn't finished yet by the time it was tapped.
  /// Safe to call more than once for the same account — a no-op if it's
  /// already open.
  Future<bool> tryRestore(String email, String expectedUid) async {
    if (_sessions.containsKey(expectedUid)) return true;
    final app = await _namedAppFor(email);
    final state = buildFirebaseAppState(app);
    final signedIn = await _waitUntilResolved(state);
    if (!signedIn || state.currentUser?.uid != expectedUid || _sessions.containsKey(expectedUid)) {
      state.dispose();
      await app.delete().catchError((_) {});
      return false;
    }
    final entry = SessionEntry(app: app, state: state);
    _sessions[expectedUid] = entry;
    state.addListener(() => _onSessionStateChanged(entry));
    if (!_disposed) notifyListeners();
    return true;
  }

  /// Waits for [state]'s *first* `authStateChanges()` resolution (no sign-in
  /// call involved) — for a freshly created named app, that first event is
  /// either a persisted user (session restored) or null (never signed in
  /// here, or it expired), decided by Firebase itself before this ever
  /// touches the network for anything else.
  Future<bool> _waitUntilResolved(AppState state) async {
    if (!state.authLoading) return state.currentUser != null;
    final completer = Completer<void>();
    void listener() {
      if (!state.authLoading) completer.complete();
    }

    state.addListener(listener);
    try {
      await completer.future.timeout(const Duration(seconds: 8), onTimeout: () {});
    } finally {
      state.removeListener(listener);
    }
    return state.currentUser != null;
  }

  /// Drops `uid`'s session — used when its saved account is forgotten (✕ in
  /// the login screen). Leaves the active session alone if `uid` isn't it,
  /// so removing a *different* saved account never disturbs what the user
  /// is currently doing.
  Future<void> closeSession(String uid) async {
    final entry = _sessions.remove(uid);
    if (entry == null) return;
    if (_activeUid == uid) _activeUid = null;
    // Cancel its subscriptions synchronously first so nothing can call
    // notifyListeners() on it after dispose (a plain signOut() races its
    // own authStateChanges callback against the dispose below).
    entry.state.dispose();
    await entry.app?.delete().catchError((_) {});
    notifyListeners();
  }

  void _onSessionStateChanged(SessionEntry entry) {
    final uid = entry.state.currentUser?.uid;
    if (uid != null && !_sessions.containsKey(uid)) {
      _sessions[uid] = entry;
      if (identical(_pending, entry)) _pending = null;
      _activeUid = uid;
      _syncPushRegistration();
    } else if (uid == null && identical(_sessions[_activeUid], entry)) {
      // The active session signed itself out (e.g. Profil > Se déconnecter)
      // — fall back to showing it (now signed-out) rather than leaving
      // `active` pointed at nothing, so AuthGate still has something to
      // read `currentUser == null` from.
      _sessions.remove(_activeUid);
      _activeUid = null;
      _pending = entry;
      unawaited(notificationsService?.unregister());
    }
    if (!_disposed) notifyListeners();
  }

  void _syncPushRegistration() {
    final service = notificationsService;
    final uid = _activeUid;
    if (service == null || uid == null) return;
    service.usersRepo = active.usersRepo;
    unawaited(service.registerForUser(uid));
  }

  /// A deterministic, sanitized app name derived straight from the e-mail
  /// (rather than e.g. `.hashCode`, which Dart doesn't guarantee is stable
  /// across SDK versions/platforms) — the same address always maps to the
  /// same named app, run after run, so its persisted native session keeps
  /// getting found.
  Future<FirebaseApp> _namedAppFor(String email) async {
    final sanitized = email.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    final name = 'session_$sanitized';
    final existing = Firebase.apps.where((a) => a.name == name);
    if (existing.isNotEmpty) return existing.first;
    return Firebase.initializeApp(name: name, options: DefaultFirebaseOptions.currentPlatform);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
