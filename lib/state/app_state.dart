import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show AppLifecycleState, ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';
import '../models/game.dart';
import '../models/group.dart';
import '../models/group_invite_code.dart';
import '../logic/tournament_bracket.dart';
import '../models/match.dart';
import '../models/salon.dart';
import '../models/saved_account.dart';
import '../models/server.dart';
import '../models/server_invite_code.dart';
import '../models/tournament.dart';
import '../repositories/auth_repository.dart';
import '../repositories/game_library_repository.dart';
import '../repositories/games_repository.dart';
import '../repositories/groups_repository.dart';
import '../repositories/guests_repository.dart';
import '../repositories/matches_repository.dart';
import '../repositories/servers_repository.dart';
import '../repositories/tournaments_repository.dart';
import '../repositories/users_repository.dart';
import '../services/notifications_service.dart';
import '../theme/app_theme.dart';
import 'new_game_draft.dart';
import 'player_row.dart';

/// Which of the 5 tabs is showing.
enum AppTab { home, ranking, history, profile, groups }

/// Which kind of "place to record matches" is currently active — a friend
/// [Group] (the original, freely-editable model) or a [Salon] within a
/// [Server] (rigid roles + match confirmation). Mutually exclusive: switching
/// one clears the other (see [AppState.selectGroup]/[AppState.selectSalon]).
/// `games`/`matches`/`tournaments` always reflect whichever is active —
/// there's only ever one live subscription set at a time, so read call sites
/// don't need to branch on this themselves.
enum ActiveContextKind { group, salon }

/// What a given position in the new-game sheet's step sequence is currently
/// showing — see [AppState.stepSequence]. The sequence's length (and which
/// kinds appear) varies with [AppState.isTournamentFlow] and whether the
/// picked game has more than one rule, so `step` (a plain 1-based index)
/// alone doesn't say what's on screen.
enum WizardStepKind { kind, tournamentFormat, game, rule, players, scores }

/// A game found in one of the user's *other* root groups, paired with the
/// group it came from so the browser UI can label it — see
/// [AppState.startBrowsingOtherGroups].
class OtherGroupGame {
  final Game game;
  final String groupId;
  final String groupName;
  const OtherGroupGame({required this.game, required this.groupId, required this.groupName});
}

/// Central app state — the Flutter/Firebase counterpart of the prototype's
/// single `Component` class: it owns the repositories, the derived
/// standings math, and the new-game / group-management flows, and notifies
/// widgets on every change.
class AppState extends ChangeNotifier {
  final AuthRepository authRepo;
  final GroupsRepository groupsRepo;
  final GamesRepository gamesRepo;
  final MatchesRepository matchesRepo;
  final TournamentsRepository tournamentsRepo;
  final UsersRepository usersRepo;
  final GuestsRepository guestsRepo;
  final GameLibraryRepository gameLibraryRepo;
  final ServersRepository serversRepo;

  /// Same shape as [gamesRepo]/[matchesRepo] but rooted under `servers/`
  /// instead of `groups/` — used only while [activeContext] is
  /// [ActiveContextKind.salon]. See [FirebaseGamesRepository.rootCollection].
  final GamesRepository serverGamesRepo;
  final MatchesRepository serverMatchesRepo;
  final NotificationsService? notificationsService;

  AppState({
    required this.authRepo,
    required this.groupsRepo,
    required this.gamesRepo,
    required this.matchesRepo,
    required this.tournamentsRepo,
    required this.usersRepo,
    required this.guestsRepo,
    required this.gameLibraryRepo,
    required this.serversRepo,
    required this.serverGamesRepo,
    required this.serverMatchesRepo,
    this.notificationsService,
  }) {
    _applyTheme();
    unawaited(_loadThemePrefs());
    unawaited(_initConnectivity());
    _savedAccountsReady = _loadSavedAccounts();
    _authSub = authRepo.authStateChanges().listen(_onAuthChanged);
  }

  // ---- theme / personalization ----
  ThemeMode themeMode = ThemeMode.system;
  AccentPreset accentPreset = AccentPreset.orange;
  DashboardStyle dashboardStyle = DashboardStyle.complete;

  static const _themeModeKey = 'theme_mode';
  static const _accentKey = 'accent_preset';
  static const _dashboardStyleKey = 'dashboard_style';

  bool get isDark => switch (themeMode) {
        ThemeMode.light => false,
        ThemeMode.dark => true,
        ThemeMode.system => ui.PlatformDispatcher.instance.platformBrightness == ui.Brightness.dark,
      };

  void _applyTheme() {
    AppColors.configure(dark: isDark, accent: accentPreset);
  }

  Future<void> _loadThemePrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeStr = prefs.getString(_themeModeKey);
      if (modeStr != null) {
        themeMode = ThemeMode.values.firstWhere((m) => m.name == modeStr, orElse: () => ThemeMode.system);
      }
      final accentStr = prefs.getString(_accentKey);
      if (accentStr != null) {
        accentPreset = AccentPreset.values.firstWhere((a) => a.name == accentStr, orElse: () => AccentPreset.orange);
      }
      final dashboardStyleStr = prefs.getString(_dashboardStyleKey);
      if (dashboardStyleStr != null) {
        dashboardStyle = DashboardStyle.values.firstWhere((d) => d.name == dashboardStyleStr, orElse: () => DashboardStyle.complete);
      }
      _applyTheme();
      notifyListeners();
    } catch (_) {
      // No persisted preference yet (or platform without shared_preferences
      // support, e.g. some test harnesses) — keep the defaults already applied.
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    _applyTheme();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeModeKey, mode.name);
    } catch (_) {}
  }

  Future<void> setAccentPreset(AccentPreset preset) async {
    accentPreset = preset;
    _applyTheme();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_accentKey, preset.name);
    } catch (_) {}
  }

  Future<void> setDashboardStyle(DashboardStyle style) async {
    dashboardStyle = style;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_dashboardStyleKey, style.name);
    } catch (_) {}
  }

  /// Called when the OS-level light/dark setting changes while
  /// [themeMode] is [ThemeMode.system] — see the observer in main.dart.
  void refreshSystemBrightness() {
    if (themeMode != ThemeMode.system) return;
    _applyTheme();
    notifyListeners();
  }

  // ---- auth ----
  AppUser? currentUser;
  bool authLoading = true;
  String? authError;
  StreamSubscription? _authSub;
  static const _savedAccountsKey = 'saved_accounts_v1';
  late final Future<void> _savedAccountsReady;
  List<SavedAccount> savedAccounts = [];

  // ---- friends (see AppUser.friendIds) ----
  // Live-watches the signed-in user's own doc so `currentUser.friendIds` (and
  // any other Firestore-backed profile field) stays fresh — authStateChanges()
  // itself only fires on sign-in/out, not on later doc edits.
  StreamSubscription<AppUser?>? _currentUserSub;
  List<AppUser> friends = [];

  // ---- groups ----
  List<Group> groups = [];
  bool groupsLoading = true;
  String? currentGroupId;
  final Map<String, AppUser> _memberCache = {};
  StreamSubscription? _groupsSub;

  // ---- servers / salons ----
  List<Server> servers = [];
  bool serversLoading = true;
  StreamSubscription? _serversSub;

  /// The server currently being viewed/managed (server detail screen) —
  /// independent from which salon (if any) is the active recording context,
  /// see [currentSalonId].
  String? currentServerId;

  /// Salons of [currentServerId], for the server detail screen.
  List<Salon> salons = [];
  StreamSubscription? _salonsSub;

  ActiveContextKind activeContext = ActiveContextKind.group;

  /// The salon that's the active recording context (mutually exclusive with
  /// [currentGroupId] — see [ActiveContextKind]), and the server it belongs
  /// to (kept alongside since a salon alone doesn't say which server's
  /// catalog/roles apply).
  String? currentSalonId;
  String? currentSalonServerId;

  // ---- games / matches (scoped to currentRootId, or to the active salon) ----
  List<Game> games = [];
  List<GameMatch> matches = [];
  StreamSubscription? _gamesSub;
  StreamSubscription? _matchesSub;

  // ---- live sessions (matches currently being scored, scoped to currentRootId) ----
  StreamSubscription? _liveSessionsSub;
  // Unfiltered snapshot from Firestore — [liveSessions] filters this against
  // [liveSessionStaleAfter] fresh on every read (a getter, not a field
  // re-filtered only when a new snapshot arrives) precisely because a
  // session nobody is updating anymore never triggers a new snapshot on its
  // own: a one-time filter computed only inside the `.listen` callback would
  // leave it sitting in the list forever past its actual staleness cutoff —
  // including while offline, where no snapshot can arrive at all to force a
  // re-check. A getter needs nothing more than the normal rebuild traffic
  // any running app already has to eventually reflect a session crossing
  // that cutoff, without needing a dedicated polling `Timer` (which would
  // also outlive `AppState` in tests, since `ChangeNotifierProvider.value`
  // deliberately never disposes an externally-owned notifier).
  List<LiveMatchSession> _rawLiveSessions = [];
  List<LiveMatchSession> get liveSessions {
    final now = DateTime.now();
    return _rawLiveSessions.where((s) => now.difference(s.updatedAt) < liveSessionStaleAfter).toList();
  }

  // ---- tournaments (scoped to currentRootId) ----
  List<Tournament> tournaments = [];
  StreamSubscription? _tournamentsSub;

  // Flips to true the moment each subscription's first snapshot arrives for
  // the current group — Firestore can take a moment after sign-in/switching
  // groups, so the UI shows "X/4 récupérées" in the meantime instead of
  // silently looking empty (see groupDataFetchedCount/groupDataFullyLoaded).
  // HomeScreen hides its whole data-dependent body (stat counts, "dernières
  // parties", tournaments…) behind [groupDataFullyLoaded] rather than
  // rendering it with zero/empty placeholders that would otherwise pop to
  // their real values a beat later.
  bool gamesLoaded = false;
  bool matchesLoaded = false;
  bool liveSessionsLoaded = false;
  bool tournamentsLoaded = false;
  static const groupDataTotalCount = 4;
  int get groupDataFetchedCount => (gamesLoaded ? 1 : 0) + (matchesLoaded ? 1 : 0) + (liveSessionsLoaded ? 1 : 0) + (tournamentsLoaded ? 1 : 0);
  bool get groupDataFullyLoaded => groupDataFetchedCount == groupDataTotalCount;

  // A live session doc is considered abandoned (app crashed/killed mid-score
  // without a chance to clean up) once it hasn't been touched in this long —
  // hidden client-side rather than left showing "en cours" forever. Public
  // so `LiveMatchScreen` can show it next to how long a held session has
  // already been offline (see [LiveMatchSession.updatedAt]).
  static const liveSessionStaleAfter = Duration(minutes: 5);

  // ---- nav / view state ----
  AppTab tab = AppTab.home;
  String rankMode = 'wins'; // wins | points | ratio | avg
  String? gameFilter;

  // Restricts the ranking to matches involving specific players — either
  // matches where they're merely among the participants ("contains", other
  // players may also be in it) or matches with exactly that participant set
  // and no one else ("exact"). Empty list = no restriction.
  List<String> rankingPlayerFilter = [];
  bool rankingPlayerFilterExact = false;

  String? profileId;
  String toast = '';
  Timer? _toastTimer;

  // ---- new-game sheet ----
  bool sheetOpen = false;
  int step = 1;
  bool creatingGame = false;
  GameFormDraft gameForm = GameFormDraft.initial();
  NewGameDraft draft = NewGameDraft.initial();

  // Set while `creatingGame`'s form is editing an existing game's settings
  // rather than creating a brand new one — see startEditingGame/createGame.
  String? _editingGameId;
  bool get isEditingGame => _editingGameId != null;
  bool savingMatch = false;

  // Set while resuming an already-saved match (see resumeMatch) — saveGame()
  // overwrites that match in place instead of creating a new one, and keeps
  // its original date.
  String? _editingMatchId;
  DateTime? _editingMatchCreatedAt;
  bool get isEditingMatch => _editingMatchId != null;

  // The series tags (if any) of the match being edited via resumeMatch() —
  // saveGame() writes these straight back so editing one leg of a past
  // "best of N" series doesn't sever it from its siblings.
  String? _editingMatchSeriesId;
  int? _editingMatchSeriesGame;
  int? _editingMatchSeriesLength;

  // Set by startTournamentMatch() while the scores step is filling in the
  // result of one specific bracket node — read back by saveGame() to tag the
  // saved GameMatch (see GameMatch.tournamentId/tournamentMatchId) and by
  // _recordTournamentResult() to advance the bracket once it's saved.
  String? _activeTournamentId;
  String? _activeTournamentMatchId;

  // Id of the live session this device started for the match currently
  // being scored (null if none was started — e.g. offline, or resuming an
  // already-saved match). Guards the "match started" push/live doc so it
  // only fires once per new match, not on every revisit of the scores step.
  String? _liveSessionId;
  Timer? _liveUpdateDebounce;

  // Grace window for _holdLiveSession: leaving a live match (backgrounding,
  // closing the sheet without saving) doesn't tear the Firestore session
  // down right away — it stays visible in case the player comes straight
  // back. Only past this window is it actually removed.
  static const _liveSessionGrace = Duration(seconds: 5);
  // Set by _holdLiveSession while the grace window is running (null once
  // it's cancelled by a resume, or once it has actually expired).
  DateTime? _liveSessionHeldAt;
  Timer? _liveSessionHoldTimer;

  // Set the moment any score-changing action fires (bump/addPoints/addRound/…
  // via _pushLiveUpdate) — lets closeSheet() tell "left mid-score, unsaved"
  // apart from "closed without ever touching a score" so it only offers a
  // resume banner when there's actually something to resume.
  bool _draftHasProgress = false;
  // Set right before a successful saveGame() closes the sheet, so closeSheet()
  // doesn't mistake "just saved" for "abandoned mid-score" and re-offer an
  // already-saved match as a local draft.
  bool _justSaved = false;

  // Set by [_finishTournamentCreation] on success — consumed by
  // `NewGameSheet` (see [takeJustCreatedTournament]) to navigate to the new
  // bracket instead of just closing.
  Tournament? _justCreatedTournament;

  // ---- connectivity (drives whether the live session mirrors to Firebase) ----
  bool isOnline = true;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  // ---- local draft persistence (survives an app kill mid-match) ----
  static const _localDraftKey = 'local_draft_v1';
  // Much more forgiving than liveSessionStaleAfter (5 min) — this is only
  // ever shown to the one person who abandoned it, on their own device, so
  // there's little harm in still offering it the next day, unlike a stale
  // "live" broadcast the whole group can see.
  static const _localDraftStaleAfter = Duration(hours: 24);
  PendingLocalDraft? pendingLocalDraft;

  // ---- online game library (import games with special rules) ----
  bool browsingLibrary = false;
  bool libraryLoading = false;
  List<Game> gameLibrary = [];
  String librarySearch = '';

  // ---- browse games from the user's other groups ----
  bool browsingOtherGroups = false;
  bool otherGroupsLoading = false;
  List<OtherGroupGame> otherGroupsGames = [];
  String otherGroupsSearch = '';

  // ---- create group / invite ----
  bool busy = false;
  String? flowError;

  @override
  void dispose() {
    _authSub?.cancel();
    _currentUserSub?.cancel();
    _groupsSub?.cancel();
    _gamesSub?.cancel();
    _matchesSub?.cancel();
    _liveSessionsSub?.cancel();
    _tournamentsSub?.cancel();
    _toastTimer?.cancel();
    _liveUpdateDebounce?.cancel();
    _liveSessionHoldTimer?.cancel();
    _connectivitySub?.cancel();
    super.dispose();
  }

  // ============================== AUTH ==============================

  void _onAuthChanged(AppUser? user) {
    currentUser = user;
    authLoading = false;
    _groupsSub?.cancel();
    _serversSub?.cancel();
    _salonsSub?.cancel();
    _gamesSub?.cancel();
    _matchesSub?.cancel();
    _liveSessionsSub?.cancel();
    _tournamentsSub?.cancel();
    _currentUserSub?.cancel();
    groups = [];
    servers = [];
    salons = [];
    games = [];
    matches = [];
    _rawLiveSessions = [];
    tournaments = [];
    friends = [];
    gamesLoaded = false;
    matchesLoaded = false;
    liveSessionsLoaded = false;
    tournamentsLoaded = false;
    currentGroupId = null;
    currentServerId = null;
    currentSalonId = null;
    currentSalonServerId = null;
    activeContext = ActiveContextKind.group;
    if (user != null) {
      _memberCache[user.uid] = user;
      profileId = user.uid;
      groupsLoading = true;
      serversLoading = true;
      unawaited(_rememberAccount(user));
      _groupsSub = groupsRepo.watchMyGroups(user.uid).listen(_onGroupsChanged);
      _serversSub = serversRepo.watchMyServers(user.uid).listen(_onServersChanged);
      _currentUserSub = usersRepo.watchById(user.uid).listen(_onCurrentUserDocChanged);
      unawaited(notificationsService?.registerForUser(user.uid));
      unawaited(_loadPendingLocalDraft(user.uid));
    } else {
      unawaited(notificationsService?.unregister());
      pendingLocalDraft = null;
    }
    notifyListeners();
  }

  /// Fires on sign-in and on every later change to the signed-in user's own
  /// `users/{uid}` doc (see [_currentUserSub]) — keeps [currentUser] (and
  /// [friends], resolved from its `friendIds`) in sync with Firestore
  /// instead of frozen at the moment of sign-in.
  void _onCurrentUserDocChanged(AppUser? fresh) {
    if (fresh == null) return;
    currentUser = fresh;
    _memberCache[fresh.uid] = fresh;
    unawaited(_resolveFriends(fresh.friendIds));
    notifyListeners();
  }

  /// Resolves each friend id to a full [AppUser] (via the shared member
  /// cache — friends are looked up the same way group members are, see
  /// [playerById]) and publishes the result as [friends].
  Future<void> _resolveFriends(List<String> friendIds) async {
    for (final id in friendIds) {
      if (_memberCache.containsKey(id)) continue;
      final u = await usersRepo.getById(id);
      if (u != null) _memberCache[id] = u;
    }
    friends = friendIds.map((id) => _memberCache[id]).whereType<AppUser>().toList();
    notifyListeners();
  }

  Future<void> signIn(String email, String password) async {
    flowError = null;
    busy = true;
    notifyListeners();
    try {
      final user = await authRepo.signIn(email: email, password: password);
      unawaited(_rememberAccount(user));
    } catch (e) {
      flowError = e.toString();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> signUp(String email, String password, String displayName) async {
    flowError = null;
    busy = true;
    notifyListeners();
    try {
      final user = await authRepo.signUp(email: email, password: password, displayName: displayName);
      unawaited(_rememberAccount(user));
    } catch (e) {
      flowError = e.toString();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> signOut() => authRepo.signOut();

  Future<void> _loadSavedAccounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawAccounts = prefs.getStringList(_savedAccountsKey) ?? const <String>[];
      savedAccounts = rawAccounts
          .map((raw) => SavedAccount.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map)))
          .where((account) => account.email.isNotEmpty)
          .toList();
      notifyListeners();
    } catch (_) {
      // Best-effort cache only.
    }
  }

  Future<void> _persistSavedAccounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_savedAccountsKey, savedAccounts.map((account) => jsonEncode(account.toJson())).toList());
    } catch (_) {}
  }

  Future<void> _rememberAccount(AppUser user) async {
    await _savedAccountsReady;
    final remembered = SavedAccount(email: user.email.trim().toLowerCase(), displayName: user.displayName, color: user.color);
    savedAccounts = [
      remembered,
      for (final account in savedAccounts)
        if (account.email != remembered.email) account,
    ];
    if (savedAccounts.length > 5) {
      savedAccounts = savedAccounts.take(5).toList();
    }
    await _persistSavedAccounts();
    notifyListeners();
  }

  Future<void> removeSavedAccount(String email) async {
    await _savedAccountsReady;
    final normalized = email.trim().toLowerCase();
    savedAccounts = savedAccounts.where((account) => account.email != normalized).toList();
    await _persistSavedAccounts();
    notifyListeners();
  }

  // ============================== GROUPS ==============================

  void _onGroupsChanged(List<Group> gs) {
    groups = gs;
    groupsLoading = false;
    if (currentGroupId == null || groups.every((g) => g.id != currentGroupId)) {
      currentGroupId = groups.isNotEmpty ? groups.first.id : null;
    }
    unawaited(_ensureMembersLoaded());
    // Only actually (re)subscribe games/matches/tournaments if a Group is
    // the active context — otherwise this would clobber a Salon's data
    // every time the background groups list updates. See [selectSalon].
    if (activeContext == ActiveContextKind.group) _resubscribeGroupData();
    unawaited(refreshGroupPartyCounts());
    notifyListeners();
  }

  // ============================== SERVERS / SALONS ==============================

  void _onServersChanged(List<Server> ss) {
    servers = ss;
    serversLoading = false;
    if (currentServerId == null || servers.every((s) => s.id != currentServerId)) {
      currentServerId = servers.isNotEmpty ? servers.first.id : null;
    }
    unawaited(_ensureMembersLoaded());
    _resubscribeSalons();
    notifyListeners();
  }

  void _resubscribeSalons() {
    _salonsSub?.cancel();
    salons = [];
    final serverId = currentServerId;
    if (serverId == null) return;
    _salonsSub = serversRepo.watchSalons(serverId).listen((ss) {
      salons = ss;
      notifyListeners();
    });
  }

  /// Selects `serverId` as the server currently being viewed/managed (server
  /// detail screen) — independent from the active recording context, see
  /// [selectSalon].
  void selectServer(String serverId) {
    currentServerId = serverId;
    _resubscribeSalons();
    notifyListeners();
  }

  Future<void> createServer({required String name, required String emoji, required int emojiBg}) async {
    final uid = currentUser?.uid;
    if (uid == null || name.trim().isEmpty) return;
    busy = true;
    flowError = null;
    notifyListeners();
    try {
      final server = await serversRepo.createServer(name: name.trim(), emoji: emoji, emojiBg: emojiBg, ownerId: uid);
      await serverGamesRepo.seedDefaultCatalog(server.id);
      currentServerId = server.id;
    } catch (e) {
      flowError = e.toString();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  bool isServerAdmin(Server server) {
    final uid = currentUser?.uid;
    return uid != null && server.isAdmin(uid);
  }

  bool canDeleteServer(Server server) => currentUser?.uid != null && server.ownerId == currentUser!.uid;

  /// Admin/owner-only (unlike a Group's free-for-all invite by email) — see
  /// [ActiveContextKind] doc comment on why Servers are more rigid. Anyone
  /// can still self-join via the QR invite code, same as a Group.
  Future<bool> addServerMemberByEmail({required String serverId, required String email}) async {
    final server = serverById(serverId);
    if (server == null || !isServerAdmin(server)) return false;
    busy = true;
    flowError = null;
    notifyListeners();
    var ok = false;
    try {
      await serversRepo.addMemberByEmail(serverId: serverId, email: email);
      ok = true;
      showToast('Membre ajouté au serveur.');
    } catch (e) {
      flowError = e.toString();
    } finally {
      busy = false;
      notifyListeners();
    }
    return ok;
  }

  /// Adds an already-known account or guest (typically picked from [friends]/
  /// [knownGuests]) to `serverId` straight by uid — admin/owner-only, same
  /// reasoning as [addServerMemberByEmail].
  Future<bool> addServerMemberByUid({required String serverId, required String uid}) async {
    final server = serverById(serverId);
    if (server == null || !isServerAdmin(server)) return false;
    busy = true;
    flowError = null;
    notifyListeners();
    var ok = false;
    try {
      await serversRepo.addMemberId(serverId: serverId, memberId: uid);
      ok = true;
      showToast('Membre ajouté au serveur.');
    } catch (e) {
      flowError = e.toString();
    } finally {
      busy = false;
      notifyListeners();
    }
    return ok;
  }

  /// Adds a player with no real account to `serverId` — e.g. a walk-in
  /// customer at a game café. Admin/owner-only, same reasoning as
  /// [addServerMemberByEmail]. See [addGuest] (the Group equivalent) for how
  /// the shared `guest:` identity works.
  Future<bool> addServerGuest({required String serverId, required String displayName}) async {
    final server = serverById(serverId);
    if (server == null || !isServerAdmin(server)) return false;
    final name = displayName.trim();
    if (name.isEmpty) return false;
    final me = currentUser;
    if (me == null) return false;
    final alreadyIn = server.memberIds.map(playerById).whereType<AppUser>();
    if (alreadyIn.any((p) => p.displayName.trim().toLowerCase() == name.toLowerCase())) {
      flowError = 'Il y a déjà un joueur nommé « $name » dans ce serveur.';
      notifyListeners();
      return false;
    }
    busy = true;
    flowError = null;
    notifyListeners();
    var ok = false;
    try {
      final guest = await guestsRepo.createGuest(displayName: name, createdBy: me.uid);
      await serversRepo.addMemberId(serverId: serverId, memberId: guest.uid);
      _memberCache[guest.uid] = guest;
      ok = true;
      showToast('Joueur ajouté au serveur.');
    } catch (e) {
      flowError = e.toString();
    } finally {
      busy = false;
      notifyListeners();
    }
    return ok;
  }

  /// Promotes/demotes `uid` to/from admin of `server` — owner-only (see
  /// [Server.ownerId]; revalidated by firestore.rules).
  Future<void> setServerAdmin({required Server server, required String uid, required bool admin}) async {
    if (currentUser?.uid != server.ownerId) return;
    try {
      await serversRepo.setAdmin(serverId: server.id, uid: uid, admin: admin);
      showToast(admin ? 'Membre promu admin.' : 'Droits admin retirés.');
    } catch (e) {
      flowError = e.toString();
      notifyListeners();
    }
  }

  Future<bool> deleteServer(String serverId) async {
    busy = true;
    flowError = null;
    notifyListeners();
    var ok = false;
    try {
      await serversRepo.deleteServer(serverId);
      ok = true;
      showToast('Serveur supprimé.');
    } catch (e) {
      flowError = e.toString();
    } finally {
      busy = false;
      notifyListeners();
    }
    return ok;
  }

  Future<void> setServerClosed(String serverId, bool closed) async {
    busy = true;
    flowError = null;
    notifyListeners();
    try {
      await serversRepo.setServerClosed(serverId: serverId, closed: closed);
      showToast(closed ? 'Serveur clos.' : 'Serveur rouvert.');
    } catch (e) {
      flowError = e.toString();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> refreshServerInviteWindow(String serverId) async {
    try {
      await serversRepo.refreshServerInviteWindow(serverId);
    } catch (_) {}
  }

  /// Joins the server encoded in a scanned QR invite code.
  Future<bool> joinServerByCode(String rawCode) async {
    final invite = ServerInviteCode.tryParse(rawCode);
    final uid = currentUser?.uid;
    if (invite == null || uid == null) {
      flowError = 'Code QR invalide.';
      notifyListeners();
      return false;
    }
    if (servers.any((s) => s.id == invite.serverId)) {
      selectServer(invite.serverId);
      showToast('Vous êtes déjà membre de ce serveur.');
      return true;
    }
    busy = true;
    flowError = null;
    notifyListeners();
    var ok = false;
    try {
      await serversRepo.joinServer(serverId: invite.serverId, uid: uid);
      ok = true;
      selectServer(invite.serverId);
      showToast('Vous avez rejoint ${invite.name}.');
    } catch (e) {
      flowError = e is InviteException ? e.message : "Impossible de rejoindre ce serveur (il n'existe peut-être plus).";
    } finally {
      busy = false;
      notifyListeners();
    }
    return ok;
  }

  // ---- salons ----

  bool canManageSalons(Server server) => isServerAdmin(server);

  Future<void> createSalon({required String serverId, required String name, required String emoji, required int emojiBg}) async {
    final server = serverById(serverId);
    if (server == null || !isServerAdmin(server)) return;
    busy = true;
    flowError = null;
    notifyListeners();
    try {
      await serversRepo.createSalon(serverId: serverId, name: name.trim(), emoji: emoji, emojiBg: emojiBg);
    } catch (e) {
      flowError = e.toString();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Admin/owner-only, same reasoning as [addServerMemberByEmail] — anyone
  /// can still self-join a salon via its QR invite code.
  Future<bool> addSalonMemberByEmail({required String serverId, required String salonId, required String email}) async {
    final server = serverById(serverId);
    if (server == null || !isServerAdmin(server)) return false;
    busy = true;
    flowError = null;
    notifyListeners();
    var ok = false;
    try {
      await serversRepo.addSalonMemberByEmail(serverId: serverId, salonId: salonId, email: email);
      ok = true;
      showToast('Membre ajouté au salon.');
    } catch (e) {
      flowError = e.toString();
    } finally {
      busy = false;
      notifyListeners();
    }
    return ok;
  }

  /// Adds an already-known account or guest (typically picked from [friends]/
  /// [knownGuests]) to a salon straight by uid — admin/owner-only, same
  /// reasoning as [addSalonMemberByEmail]. Also adds them to the parent
  /// server if they aren't already a member (mirrors [ServersRepository.joinSalon]).
  Future<bool> addSalonMemberByUid({required String serverId, required String salonId, required String uid}) async {
    final server = serverById(serverId);
    if (server == null || !isServerAdmin(server)) return false;
    busy = true;
    flowError = null;
    notifyListeners();
    var ok = false;
    try {
      await serversRepo.addSalonMemberId(serverId: serverId, salonId: salonId, memberId: uid);
      if (!server.memberIds.contains(uid)) {
        await serversRepo.addMemberId(serverId: serverId, memberId: uid);
      }
      ok = true;
      showToast('Membre ajouté au salon.');
    } catch (e) {
      flowError = e.toString();
    } finally {
      busy = false;
      notifyListeners();
    }
    return ok;
  }

  /// Adds a player with no real account to a salon — e.g. a walk-in customer
  /// signing up for this specific event. Admin/owner-only, same reasoning as
  /// [addSalonMemberByEmail]. See [addGuest] (the Group equivalent) for how
  /// the shared `guest:` identity works.
  Future<bool> addSalonGuest({required String serverId, required String salonId, required String displayName}) async {
    final server = serverById(serverId);
    if (server == null || !isServerAdmin(server)) return false;
    final name = displayName.trim();
    if (name.isEmpty) return false;
    final me = currentUser;
    if (me == null) return false;
    final salon = salons.where((s) => s.id == salonId).firstOrNull;
    final alreadyIn = (salon?.memberIds ?? const []).map(playerById).whereType<AppUser>();
    if (alreadyIn.any((p) => p.displayName.trim().toLowerCase() == name.toLowerCase())) {
      flowError = 'Il y a déjà un joueur nommé « $name » dans ce salon.';
      notifyListeners();
      return false;
    }
    busy = true;
    flowError = null;
    notifyListeners();
    var ok = false;
    try {
      final guest = await guestsRepo.createGuest(displayName: name, createdBy: me.uid);
      await serversRepo.addSalonMemberId(serverId: serverId, salonId: salonId, memberId: guest.uid);
      if (!server.memberIds.contains(guest.uid)) {
        await serversRepo.addMemberId(serverId: serverId, memberId: guest.uid);
      }
      _memberCache[guest.uid] = guest;
      ok = true;
      showToast('Joueur ajouté au salon.');
    } catch (e) {
      flowError = e.toString();
    } finally {
      busy = false;
      notifyListeners();
    }
    return ok;
  }

  Future<bool> deleteSalon({required String serverId, required String salonId}) async {
    final server = serverById(serverId);
    if (server == null || !isServerAdmin(server)) return false;
    busy = true;
    flowError = null;
    notifyListeners();
    var ok = false;
    try {
      await serversRepo.deleteSalon(serverId: serverId, salonId: salonId);
      ok = true;
      showToast('Salon supprimé.');
      if (currentSalonId == salonId) {
        final fallbackGroupId = currentGroupId ?? (groups.isNotEmpty ? groups.first.id : null);
        if (fallbackGroupId != null) {
          selectGroup(fallbackGroupId);
        } else {
          currentSalonId = null;
          currentSalonServerId = null;
          activeContext = ActiveContextKind.group;
          games = [];
          matches = [];
        }
      }
    } catch (e) {
      flowError = e.toString();
    } finally {
      busy = false;
      notifyListeners();
    }
    return ok;
  }

  Future<void> setSalonClosed({required String serverId, required String salonId, required bool closed}) async {
    try {
      await serversRepo.setSalonClosed(serverId: serverId, salonId: salonId, closed: closed);
      showToast(closed ? 'Salon clos.' : 'Salon rouvert.');
      notifyListeners();
    } catch (e) {
      flowError = e.toString();
      notifyListeners();
    }
  }

  Future<void> refreshSalonInviteWindow({required String serverId, required String salonId}) async {
    try {
      await serversRepo.refreshSalonInviteWindow(serverId: serverId, salonId: salonId);
    } catch (_) {}
  }

  /// Joins the salon (and, if needed, its server) encoded in a scanned QR
  /// invite code — see [ServersRepository.joinSalon].
  Future<bool> joinSalonByCode(String rawCode) async {
    final invite = SalonInviteCode.tryParse(rawCode);
    final uid = currentUser?.uid;
    if (invite == null || uid == null) {
      flowError = 'Code QR invalide.';
      notifyListeners();
      return false;
    }
    busy = true;
    flowError = null;
    notifyListeners();
    var ok = false;
    try {
      await serversRepo.joinSalon(serverId: invite.serverId, salonId: invite.salonId, uid: uid);
      ok = true;
      selectSalon(invite.serverId, invite.salonId);
      showToast('Vous avez rejoint ${invite.name}.');
    } catch (e) {
      flowError = e is InviteException ? e.message : "Impossible de rejoindre ce salon (il n'existe peut-être plus).";
    } finally {
      busy = false;
      notifyListeners();
    }
    return ok;
  }

  Group? _findGroup(String id) {
    for (final g in groups) {
      if (g.id == id) return g;
    }
    return null;
  }

  Group? get currentGroup => currentGroupId == null ? null : _findGroup(currentGroupId!);

  Group? groupById(String id) => _findGroup(id);

  /// The Firestore doc that owns the games/matches subcollections for the
  /// currently selected group.
  String? get currentRootId => currentGroupId;

  List<String> getAllGroupIds(String groupId) => [groupId];

  List<String> getGroupMemberIds(String groupId) => _findGroup(groupId)?.memberIds ?? [];

  // Per-group match tallies for the groups list (see GroupsScreen). `matches`
  // itself only ever holds the CURRENTLY selected group's matches (see
  // _resubscribeGroupData below) — deliberately, to avoid pulling every
  // group's whole history just because it's rendered somewhere — so a screen
  // listing every group the user belongs to needs its own one-time tally
  // instead of reusing `matches`.
  final Map<String, int> _groupPartyCounts = {};
  int groupPartyCount(String groupId) => _groupPartyCounts[groupId] ?? 0;

  /// Best-effort: fetches `groupId`'s count and caches it, leaving whatever
  /// was cached before untouched on failure — never throws, so it's always
  /// safe to await alongside every other group's fetch in [Future.wait].
  Future<void> _refreshOneGroupPartyCount(String rootId, String groupId, List<String> matchGroupIds) async {
    try {
      _groupPartyCounts[groupId] = await matchesRepo.countMatches(rootId, matchGroupIds);
    } catch (_) {}
  }

  /// Refreshes [groupPartyCount] for every group currently in [groups] —
  /// called whenever the groups list itself changes, and again whenever the
  /// groups screen is opened (a match played elsewhere since the last
  /// refresh would otherwise look stale there).
  Future<void> refreshGroupPartyCounts() async {
    final futures = <Future<void>>[for (final g in groups) _refreshOneGroupPartyCount(g.id, g.id, [g.id])];
    await Future.wait(futures);
    notifyListeners();
  }

  void _resubscribeGroupData() {
    final root = currentRootId;
    _gamesSub?.cancel();
    _matchesSub?.cancel();
    _liveSessionsSub?.cancel();
    _tournamentsSub?.cancel();
    gamesLoaded = false;
    matchesLoaded = false;
    liveSessionsLoaded = false;
    tournamentsLoaded = false;
    if (root == null) {
      games = [];
      matches = [];
      _rawLiveSessions = [];
      tournaments = [];
      return;
    }
    _gamesSub = gamesRepo.watchGames(root).listen((gs) {
      games = gs;
      gamesLoaded = true;
      // null means "tous les jeux" — a real, intentional state now (see
      // RankingScreen), so only clear a filter that's become invalid,
      // never silently pick a different game as a fallback default.
      if (gameFilter != null && !gs.any((g) => g.id == gameFilter)) {
        gameFilter = null;
      }
      notifyListeners();
    });
    _matchesSub = matchesRepo.watchMatches(root, getAllGroupIds(root)).listen((ms) {
      matches = ms;
      matchesLoaded = true;
      notifyListeners();
    });
    _tournamentsSub = tournamentsRepo.watchTournaments(root, getAllGroupIds(root)).listen((ts) {
      tournaments = ts;
      tournamentsLoaded = true;
      notifyListeners();
    });
    _liveSessionsSub = matchesRepo.watchLiveSessions(root, getAllGroupIds(root)).listen((ss) {
      liveSessionsLoaded = true;
      _rawLiveSessions = ss;
      notifyListeners();
    });
  }

  /// Mirrors [_resubscribeGroupData] but for the active Salon (see
  /// [currentSalonId]/[currentSalonServerId]) — populates the exact same
  /// `games`/`matches`/`tournaments` fields, so every read call site written
  /// against those keeps working unchanged regardless of which context is
  /// active. Live sessions and tournaments aren't supported in a Salon yet,
  /// so those two are just left empty/"loaded".
  void _resubscribeSalonData() {
    _gamesSub?.cancel();
    _matchesSub?.cancel();
    _liveSessionsSub?.cancel();
    _tournamentsSub?.cancel();
    gamesLoaded = false;
    matchesLoaded = false;
    tournaments = [];
    tournamentsLoaded = true;
    _rawLiveSessions = [];
    liveSessionsLoaded = true;
    final serverId = currentSalonServerId;
    final salonId = currentSalonId;
    if (serverId == null || salonId == null) {
      games = [];
      matches = [];
      return;
    }
    _gamesSub = serverGamesRepo.watchGames(serverId).listen((gs) {
      games = gs;
      gamesLoaded = true;
      if (gameFilter != null && !gs.any((g) => g.id == gameFilter)) {
        gameFilter = null;
      }
      notifyListeners();
    });
    _matchesSub = serverMatchesRepo.watchMatches(serverId, [salonId]).listen((ms) {
      matches = ms;
      matchesLoaded = true;
      notifyListeners();
    });
  }

  Future<void> _ensureMembersLoaded() async {
    final allIds = <String>{};
    for (final g in groups) {
      allIds.addAll(g.memberIds);
    }
    for (final s in servers) {
      allIds.addAll(s.memberIds);
    }
    final missing = allIds.where((id) => !_memberCache.containsKey(id)).toList();
    if (missing.isEmpty) return;
    for (final id in missing) {
      final u = isGuestId(id) ? await guestsRepo.getById(id) : await usersRepo.getById(id);
      if (u != null) _memberCache[id] = u;
    }
    notifyListeners();
  }

  AppUser? playerById(String uid) => _memberCache[uid];

  /// Guests (see [isGuestId]) already added somewhere across every group you
  /// belong to — suggested when adding someone "sans compte" to a
  /// *different* group, so the same person keeps a single, shared identity
  /// (and eventually a single unified match history — see [reassignMember])
  /// instead of getting a fresh, disconnected guest record every time.
  List<AppUser> get knownGuests {
    final ids = <String>{};
    for (final g in groups) {
      ids.addAll(g.memberIds.where(isGuestId));
    }
    // Servers' memberIds already include everyone in any of their salons
    // (see ServersRepository.joinSalon/addSalonMemberId), so this alone
    // covers guests added anywhere in a Server too.
    for (final s in servers) {
      ids.addAll(s.memberIds.where(isGuestId));
    }
    return ids.map((id) => _memberCache[id]).whereType<AppUser>().toList();
  }

  void selectGroup(String groupId) {
    currentGroupId = groupId;
    currentSalonId = null;
    currentSalonServerId = null;
    activeContext = ActiveContextKind.group;
    tab = AppTab.home;
    _resubscribeGroupData();
    notifyListeners();
  }

  /// Makes `salonId` (under `serverId`) the active recording context —
  /// mutually exclusive with [selectGroup]. `games`/`matches` switch to this
  /// salon's; a match saved from here goes through [saveGame]'s
  /// [ActiveContextKind.salon] branch (pending confirmation instead of
  /// instantly final).
  void selectSalon(String serverId, String salonId) {
    currentSalonServerId = serverId;
    currentSalonId = salonId;
    activeContext = ActiveContextKind.salon;
    tab = AppTab.home;
    // Keeps [salons] (read by [currentSalon]) in sync with whichever server
    // the active salon belongs to, even if the server list/detail screen was
    // last showing a different one.
    if (currentServerId != serverId) {
      currentServerId = serverId;
      _resubscribeSalons();
    }
    _resubscribeSalonData();
    notifyListeners();
  }

  Salon? get currentSalon => currentSalonId == null ? null : salons.where((s) => s.id == currentSalonId).firstOrNull;
  Server? get currentSalonServer => currentSalonServerId == null ? null : servers.where((s) => s.id == currentSalonServerId).firstOrNull;
  Server? serverById(String id) => servers.where((s) => s.id == id).firstOrNull;

  // ---- generic "active context" accessors — let game-catalog/match write
  // paths work unchanged for both a Group and a Salon context, instead of
  // duplicating every method (see ActiveContextKind doc comment). ----

  GamesRepository get _activeGamesRepo => activeContext == ActiveContextKind.salon ? serverGamesRepo : gamesRepo;
  MatchesRepository get _activeMatchesRepo => activeContext == ActiveContextKind.salon ? serverMatchesRepo : matchesRepo;

  /// The Firestore root id backing the active context — a group id, or (for
  /// a Salon) the server id its catalog/matches actually live under.
  String? get _activeRootId => activeContext == ActiveContextKind.salon ? currentSalonServerId : currentRootId;

  /// Whether the active context (Group or Salon) is currently closed to new
  /// activity — used both internally (see [_rejectIfActiveContextClosed])
  /// and by UI that needs to know regardless of which kind is active (e.g.
  /// [showGameActionsSheet]), instead of reading [currentGroupClosed]
  /// directly and getting it wrong while a Salon is active.
  bool get activeContextClosed => activeContext == ActiveContextKind.salon
      ? ((currentSalon?.closed ?? false) || (currentSalonServer?.closed ?? false))
      : currentGroupClosed;

  /// Rejects a mutating action against the active context if it's closed,
  /// surfacing why via [flowError] — the Salon/Server equivalent of
  /// [_rejectIfGroupClosed], used by the shared catalog/match write paths.
  bool _rejectIfActiveContextClosed() {
    if (!activeContextClosed) return false;
    flowError = activeContext == ActiveContextKind.salon
        ? 'Ce salon est clos — plus aucune action n\'est possible.'
        : 'Ce groupe est clos — plus aucune action n\'est possible.';
    notifyListeners();
    return true;
  }

  Future<void> createGroup({required String name, required String emoji, required int emojiBg, bool temporary = false}) async {
    final uid = currentUser?.uid;
    if (uid == null || name.trim().isEmpty) return;
    busy = true;
    flowError = null;
    notifyListeners();
    try {
      final group = await groupsRepo.createGroup(name: name.trim(), emoji: emoji, emojiBg: emojiBg, ownerId: uid, temporary: temporary);
      await gamesRepo.seedDefaultCatalog(group.id);
      currentGroupId = group.id;
      tab = AppTab.home;
    } catch (e) {
      flowError = e.toString();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> addMemberByEmail({required String groupId, required String email}) async {
    if (_rejectIfGroupClosed(groupId)) return false;
    busy = true;
    flowError = null;
    notifyListeners();
    var ok = false;
    try {
      await groupsRepo.addMemberByEmail(groupId: groupId, email: email);
      ok = true;
      showToast('Membre ajouté au groupe.');
    } catch (e) {
      flowError = e.toString();
    } finally {
      busy = false;
      notifyListeners();
    }
    return ok;
  }

  /// Adds an already-known account (typically picked from [friends]) to
  /// `groupId` straight by uid — skips the email round-trip [addMemberByEmail]
  /// needs since the uid is already in hand.
  Future<bool> addMemberByUid({required String groupId, required String uid}) async {
    if (_rejectIfGroupClosed(groupId)) return false;
    busy = true;
    flowError = null;
    notifyListeners();
    var ok = false;
    try {
      await groupsRepo.addMemberId(groupId: groupId, memberId: uid);
      ok = true;
      showToast('Membre ajouté au groupe.');
    } catch (e) {
      flowError = e.toString();
    } finally {
      busy = false;
      notifyListeners();
    }
    return ok;
  }

  /// Adds a player with no real account to `groupId` — e.g. a friend playing
  /// on someone else's phone. Its `guest:` id slots into `memberIds` exactly
  /// like a real uid, so it shows up in the player picker and standings right
  /// away; linking it to a real account later is a separate flow.
  Future<bool> addGuest({required String groupId, required String displayName}) async {
    final name = displayName.trim();
    if (name.isEmpty) return false;
    final me = currentUser;
    if (me == null) return false;
    if (_rejectIfGroupClosed(groupId)) return false;
    final alreadyIn = getGroupMemberIds(groupId).map(playerById).whereType<AppUser>();
    if (alreadyIn.any((p) => p.displayName.trim().toLowerCase() == name.toLowerCase())) {
      flowError = 'Il y a déjà un joueur nommé « $name » dans ce groupe.';
      notifyListeners();
      return false;
    }
    busy = true;
    flowError = null;
    notifyListeners();
    var ok = false;
    try {
      final guest = await guestsRepo.createGuest(displayName: name, createdBy: me.uid);
      await groupsRepo.addMemberId(groupId: groupId, memberId: guest.uid);
      _memberCache[guest.uid] = guest;
      ok = true;
      showToast('Joueur ajouté au groupe.');
    } catch (e) {
      flowError = e.toString();
    } finally {
      busy = false;
      notifyListeners();
    }
    return ok;
  }

  bool isGroupClosed(Group group) => group.closed;

  bool isGroupIdClosed(String groupId) {
    final g = groupById(groupId);
    return g != null && isGroupClosed(g);
  }

  bool get currentGroupClosed => currentGroup != null && isGroupClosed(currentGroup!);

  /// Only a group's own owner can close/reopen it — mirrors
  /// [canManageGameCatalog] (same "who's in charge of the season" scope).
  bool canCloseGroup(Group group) {
    final uid = currentUser?.uid;
    return uid != null && group.ownerId == uid;
  }

  /// Closes (or reopens) a group — see [Group.closed]. A closed group
  /// stays fully visible (history, rankings) but rejects any new activity;
  /// nothing is deleted, and it can be reopened any time.
  Future<bool> setGroupClosed(String rootGroupId, bool closed) async {
    busy = true;
    flowError = null;
    notifyListeners();
    var ok = false;
    try {
      await groupsRepo.setGroupClosed(groupId: rootGroupId, closed: closed);
      showToast(closed ? 'Groupe clos.' : 'Groupe rouvert.');
      ok = true;
    } catch (e) {
      flowError = e.toString();
    } finally {
      busy = false;
      notifyListeners();
    }
    return ok;
  }

  /// Opens (or extends) `groupId`'s QR self-join window — call whenever the
  /// invite dialog's QR tab is shown. Best-effort: a failure here just means
  /// the shown code keeps whatever window it already had, so it's silent
  /// rather than surfaced as a [flowError].
  Future<void> refreshInviteWindow(String groupId) async {
    try {
      await groupsRepo.refreshInviteWindow(groupId);
    } catch (_) {}
  }

  /// Rejects a mutating action targeting `groupId` if its group is closed,
  /// surfacing why via [flowError] (rendered inline wherever that action's
  /// own dialog/sheet already shows it) instead of failing silently. Returns
  /// true when the action should be aborted.
  bool _rejectIfGroupClosed(String? groupId) {
    if (groupId == null || !isGroupIdClosed(groupId)) return false;
    flowError = 'Ce groupe est clos — plus aucune action n\'est possible.';
    notifyListeners();
    return true;
  }

  /// Whether the signed-in user is allowed to delete `group`: its own owner.
  bool canDeleteGroup(Group group) {
    final uid = currentUser?.uid;
    return uid != null && group.ownerId == uid;
  }

  Future<bool> deleteGroup(String groupId) async {
    busy = true;
    flowError = null;
    notifyListeners();
    var ok = false;
    try {
      await groupsRepo.deleteGroup(groupId);
      ok = true;
      showToast('Groupe supprimé.');
    } catch (e) {
      flowError = e.toString();
    } finally {
      busy = false;
      notifyListeners();
    }
    return ok;
  }

  /// Hands `oldUid`'s slot in `rootGroupId` over to whichever account
  /// `newEmail` belongs to: the group's member list gets `newEmail`'s account
  /// instead, and every past match referencing `oldUid` is rewritten to
  /// reference the new account — e.g. someone was originally invited/scored
  /// under the wrong address.
  ///
  /// A guest (see [isGuestId]/[knownGuests]) is handled differently: since
  /// its whole point is being the same shared identity across every group
  /// it was added to, getting a real account replaces it everywhere it's a
  /// member — every group visible to the caller, not just `rootGroupId` —
  /// instead of leaving disconnected guest copies behind in the others.
  Future<bool> reassignMember({required String rootGroupId, required String oldUid, required String newEmail}) async {
    if (!isGuestId(oldUid)) {
      if (_rejectIfGroupClosed(rootGroupId)) return false;
      busy = true;
      flowError = null;
      notifyListeners();
      var ok = false;
      try {
        final newUser = await usersRepo.getByEmail(newEmail);
        if (newUser == null) {
          throw Exception('Aucun compte trouvé avec cet e-mail.');
        }
        if (newUser.uid == oldUid) {
          throw Exception('Ce compte est déjà celui du joueur.');
        }
        if (getGroupMemberIds(rootGroupId).contains(newUser.uid)) {
          throw Exception('Ce compte est déjà membre du groupe.');
        }
        await groupsRepo.reassignMember(groupId: rootGroupId, oldUid: oldUid, newUid: newUser.uid);
        await matchesRepo.reassignPlayer(rootGroupId: rootGroupId, oldPlayerId: oldUid, newPlayerId: newUser.uid);
        _memberCache[newUser.uid] = newUser;
        ok = true;
        showToast('Membre réassigné.');
      } catch (e) {
        flowError = e.toString();
      } finally {
        busy = false;
        notifyListeners();
      }
      return ok;
    }

    busy = true;
    flowError = null;
    notifyListeners();
    var ok = false;
    try {
      final newUser = await usersRepo.getByEmail(newEmail);
      if (newUser == null) {
        throw Exception('Aucun compte trouvé avec cet e-mail.');
      }
      final targets = groups.where((g) => getGroupMemberIds(g.id).contains(oldUid)).toList();
      var touched = 0;
      var skippedClosed = 0;
      for (final g in targets) {
        if (isGroupClosed(g)) {
          skippedClosed++;
          continue;
        }
        if (getGroupMemberIds(g.id).contains(newUser.uid)) continue;
        await groupsRepo.reassignMember(groupId: g.id, oldUid: oldUid, newUid: newUser.uid);
        await matchesRepo.reassignPlayer(rootGroupId: g.id, oldPlayerId: oldUid, newPlayerId: newUser.uid);
        touched++;
      }
      if (touched == 0) {
        throw Exception(skippedClosed > 0 ? 'Tous les groupes concernés sont clos.' : 'Ce compte est déjà membre partout où ce joueur apparaissait.');
      }
      _memberCache[newUser.uid] = newUser;
      ok = true;
      showToast(
        'Membre réassigné dans $touched groupe${touched > 1 ? 's' : ''}'
        '${skippedClosed > 0 ? ' ($skippedClosed clos ignoré${skippedClosed > 1 ? 's' : ''})' : ''}.',
      );
    } catch (e) {
      flowError = e.toString();
    } finally {
      busy = false;
      notifyListeners();
    }
    return ok;
  }

  /// Whether the signed-in user can manage the active context's game
  /// catalog — a Group's own owner, or (for a Salon) the owner/admins of its
  /// Server, since it also wipes every match ever recorded for that game.
  bool get canManageGameCatalog {
    final uid = currentUser?.uid;
    if (uid == null) return false;
    if (activeContext == ActiveContextKind.salon) {
      return currentSalonServer?.isAdmin(uid) ?? false;
    }
    final root = currentRootId;
    if (root == null) return false;
    return groupById(root)?.ownerId == uid;
  }

  Future<bool> deleteGame(String gameId) async {
    final root = _activeRootId;
    if (root == null) return false;
    if (_rejectIfActiveContextClosed()) return false;
    busy = true;
    flowError = null;
    notifyListeners();
    var ok = false;
    try {
      await _activeGamesRepo.deleteGame(root, gameId);
      ok = true;
      showToast('Jeu supprimé.');
    } catch (e) {
      flowError = e.toString();
    } finally {
      busy = false;
      notifyListeners();
    }
    return ok;
  }

  /// Replaces a game's rules reminders (see [GameRuleSection]) — purely
  /// informational, doesn't touch anything scoring-related. Returns true on
  /// success so the editor screen knows it can pop.
  Future<bool> updateGameRules(Game game, List<GameRuleSection> sections) async {
    final root = _activeRootId;
    if (root == null) return false;
    if (_rejectIfActiveContextClosed()) return false;
    busy = true;
    flowError = null;
    notifyListeners();
    var ok = false;
    try {
      await _activeGamesRepo.updateGame(root, game.copyWith(ruleSections: sections));
      showToast('Règles enregistrées.');
      ok = true;
    } catch (e) {
      flowError = e.toString();
    } finally {
      busy = false;
      notifyListeners();
    }
    return ok;
  }

  /// Joins the group encoded in a scanned QR invite code. Returns true on
  /// success (including the "already a member" case, which just switches to
  /// that group instead of writing anything).
  Future<bool> joinGroupByCode(String rawCode) async {
    final invite = GroupInviteCode.tryParse(rawCode);
    final uid = currentUser?.uid;
    if (invite == null || uid == null) {
      flowError = 'Code QR invalide.';
      notifyListeners();
      return false;
    }
    if (groups.any((g) => g.id == invite.groupId)) {
      selectGroup(invite.groupId);
      showToast('Vous êtes déjà membre de ce groupe.');
      return true;
    }
    busy = true;
    flowError = null;
    notifyListeners();
    var ok = false;
    try {
      await groupsRepo.joinGroup(groupId: invite.groupId, uid: uid);
      ok = true;
      selectGroup(invite.groupId);
      showToast('Vous avez rejoint ${invite.name}.');
    } catch (e) {
      flowError = e is InviteException ? e.message : "Impossible de rejoindre ce groupe (il n'existe peut-être plus).";
    } finally {
      busy = false;
      notifyListeners();
    }
    return ok;
  }

  /// Permanently deletes the signed-in account: leaves/deletes every group
  /// it's involved with (cascading its own groups' full history), removes
  /// its Firestore user record, then deletes the Firebase Auth account
  /// itself. Requires the current password to re-prove a recent login.
  Future<bool> deleteAccount(String password) async {
    final uid = currentUser?.uid;
    final email = currentUser?.email;
    if (uid == null) return false;
    busy = true;
    flowError = null;
    notifyListeners();
    var ok = false;
    try {
      await authRepo.reauthenticate(password);
      await groupsRepo.deleteAllUserData(uid);
      await serversRepo.deleteAllUserData(uid);
      await usersRepo.deleteUser(uid: uid, email: email ?? '');
      await authRepo.deleteAccount();
      ok = true;
    } catch (e) {
      flowError = e.toString();
    } finally {
      busy = false;
      notifyListeners();
    }
    return ok;
  }

  // ============================== FRIENDS ==============================

  /// Looks up `email` and adds the matching account to [friends]. Surfaces
  /// "not found" the same way [addMemberByEmail] does (via [flowError]) so
  /// the caller falls back to inviting straight by e-mail instead — this is
  /// deliberately the *only* way to add a friend, mirroring how a group
  /// member is normally added.
  Future<bool> addFriendByEmail(String email) async {
    final me = currentUser;
    if (me == null) return false;
    busy = true;
    flowError = null;
    notifyListeners();
    var ok = false;
    try {
      final user = await usersRepo.getByEmail(email);
      if (user == null) {
        throw Exception('Aucun compte trouvé avec cet e-mail.');
      }
      if (user.uid == me.uid) {
        throw Exception('Vous ne pouvez pas vous ajouter vous-même.');
      }
      if (me.friendIds.contains(user.uid)) {
        throw Exception('Déjà dans vos amis.');
      }
      await usersRepo.addFriend(uid: me.uid, friendUid: user.uid);
      _memberCache[user.uid] = user;
      // Optimistic — _onCurrentUserDocChanged will reconcile once the
      // watchById stream picks up the write, but that shouldn't leave the
      // list looking like nothing happened in the meantime.
      if (!friends.any((f) => f.uid == user.uid)) friends = [...friends, user];
      ok = true;
      showToast('${user.displayName} ajouté à vos amis.');
    } catch (e) {
      flowError = e.toString();
    } finally {
      busy = false;
      notifyListeners();
    }
    return ok;
  }

  Future<void> removeFriend(String friendUid) async {
    final me = currentUser;
    if (me == null) return;
    friends = friends.where((f) => f.uid != friendUid).toList();
    notifyListeners();
    try {
      await usersRepo.removeFriend(uid: me.uid, friendUid: friendUid);
    } catch (e) {
      flowError = e.toString();
      notifyListeners();
    }
  }

  // ============================== VIEW SCOPE ==============================

  /// Matches recorded in the currently-viewed group/salon — for a Salon,
  /// only ones every player has confirmed (see GameMatch.status): a pending
  /// or rejected match shouldn't count toward stats/rankings/history yet,
  /// even though it already lives in [matches] (read directly by
  /// HomeScreen's "à confirmer" section for a Salon).
  List<GameMatch> get viewMatches {
    if (activeContext == ActiveContextKind.salon) {
      return matches.where((m) => m.isConfirmed).toList();
    }
    if (currentGroupId == null) return const [];
    final ids = getAllGroupIds(currentGroupId!).toSet();
    return matches.where((m) => ids.contains(m.groupId)).toList();
  }

  /// Tournaments recorded in the currently-viewed group — Salons don't
  /// support the bracket-tournament feature (yet), so always empty there.
  List<Tournament> get viewTournaments {
    if (activeContext == ActiveContextKind.salon) return const [];
    if (currentGroupId == null) return const [];
    final ids = getAllGroupIds(currentGroupId!).toSet();
    return tournaments.where((t) => ids.contains(t.groupId)).toList();
  }

  List<String> get viewPlayerIds => activeContext == ActiveContextKind.salon
      ? (currentSalon?.memberIds ?? const [])
      : (currentGroupId == null ? const [] : getGroupMemberIds(currentGroupId!));

  List<AppUser> get viewPlayers => viewPlayerIds.map(playerById).whereType<AppUser>().toList();

  Map<String, int> get groupStats {
    final jeux = viewMatches.map((m) => m.gameId).toSet().length;
    return {
      'parties': viewMatches.length,
      'jeux': jeux,
      'joueurs': viewPlayerIds.length,
    };
  }

  Game? gameById(String id) {
    for (final g in games) {
      if (g.id == id) return g;
    }
    return null;
  }

  // ============================== STANDINGS ==============================

  /// [gameFilterId] null means "tous les jeux" (no game restriction).
  /// [participantFilter], when non-empty, further restricts to matches
  /// involving those players — every one of them among the participants
  /// (other players may also be in it), or, with [participantFilterExact],
  /// matches whose participant set is exactly that list and no one else.
  List<PlayerRow> computeRows(
    String? gameFilterId, {
    List<GameMatch>? matchesOverride,
    List<String>? playerIdsOverride,
    List<String>? participantFilter,
    bool participantFilterExact = false,
  }) {
    final all = matchesOverride ?? viewMatches;
    var mm = gameFilterId == null ? all : all.where((m) => m.gameId == gameFilterId).toList();
    if (participantFilter != null && participantFilter.isNotEmpty) {
      final want = participantFilter.toSet();
      mm = mm.where((m) {
        final have = m.entries.map((e) => e.playerId).toSet();
        return participantFilterExact ? setEquals(have, want) : want.every(have.contains);
      }).toList();
    }
    final pids = playerIdsOverride ?? viewPlayerIds;
    return pids.map((pid) {
      final p = playerById(pid);
      if (p == null) return null;
      var wins = 0, played = 0, points = 0;
      for (final m in mm) {
        MatchEntry? e;
        for (final entry in m.entries) {
          if (entry.playerId == pid) {
            e = entry;
            break;
          }
        }
        if (e == null) continue;
        played++;
        points += e.points;
        if (m.winnerIds().contains(pid)) wins++;
      }
      return PlayerRow(
        player: p,
        wins: wins,
        played: played,
        points: points,
        ratio: played > 0 ? wins / played : 0,
        avg: played > 0 ? points / played : null,
        gamesPlayedOfFilter: played,
      );
    }).whereType<PlayerRow>().toList();
  }

  List<PlayerRow> standings(
    String mode, {
    String? gameFilterId,
    List<GameMatch>? matchesOverride,
    List<String>? playerIdsOverride,
    List<String>? participantFilter,
    bool participantFilterExact = false,
  }) {
    final rows = computeRows(
      gameFilterId,
      matchesOverride: matchesOverride,
      playerIdsOverride: playerIdsOverride,
      participantFilter: participantFilter,
      participantFilterExact: participantFilterExact,
    );
    switch (mode) {
      case 'wins':
        rows.sort((a, b) => b.wins != a.wins ? b.wins - a.wins : b.ratio.compareTo(a.ratio));
        return rows;
      case 'points':
        rows.sort((a, b) => b.points - a.points);
        return rows;
      case 'ratio':
        rows.sort((a, b) => b.ratio != a.ratio ? b.ratio.compareTo(a.ratio) : b.wins - a.wins);
        return rows;
      case 'avg':
      default:
        // Averaging across every game at once would mix incompatible point
        // scales — unlike the other modes, "tous les jeux" isn't a valid
        // choice here, so require an actual game to be picked.
        if (gameFilterId == null) return const [];
        final filtered = rows.where((r) => r.gamesPlayedOfFilter > 0).toList();
        filtered.sort((a, b) => (b.avg ?? 0).compareTo(a.avg ?? 0));
        return filtered;
    }
  }

  RankMetric metricFor(PlayerRow r, String mode) {
    switch (mode) {
      case 'wins':
        return RankMetric('${r.wins}', 'victoires', '${r.played} parties · ${(r.ratio * 100).round()}%');
      case 'points':
        return RankMetric('${r.points}', 'points', '${r.played} parties');
      case 'ratio':
        return RankMetric('${(r.ratio * 100).round()}%', 'winrate', '${r.wins} V / ${r.played} P');
      case 'avg':
      default:
        return RankMetric(r.avg != null ? r.avg!.toStringAsFixed(1) : '—', 'pts', '${r.gamesPlayedOfFilter} parties');
    }
  }

  /// Per-game breakdown for a player's profile tab: only games they've
  /// actually played, each with played/wins/average score.
  List<ProfileGameStat> profileGameBreakdown(String uid) {
    final out = <ProfileGameStat>[];
    for (final g in games) {
      var played = 0, wins = 0, pts = 0;
      for (final m in viewMatches) {
        if (m.gameId != g.id) continue;
        MatchEntry? e;
        for (final entry in m.entries) {
          if (entry.playerId == uid) {
            e = entry;
            break;
          }
        }
        if (e == null) continue;
        played++;
        pts += e.points;
        if (m.winnerIds().contains(uid)) wins++;
      }
      if (played > 0) {
        out.add(ProfileGameStat(game: g, played: played, wins: wins, avg: pts / played));
      }
    }
    return out;
  }

  // ============================== NAV ==============================

  void setTab(AppTab t) {
    tab = t;
    notifyListeners();
  }

  void openProfile(String uid) {
    profileId = uid;
    tab = AppTab.profile;
    notifyListeners();
  }

  void setRankMode(String m) {
    rankMode = m;
    notifyListeners();
  }

  void setGameFilter(String? id) {
    gameFilter = id;
    notifyListeners();
  }

  void toggleRankingPlayerFilter(String uid) {
    if (!rankingPlayerFilter.remove(uid)) rankingPlayerFilter.add(uid);
    notifyListeners();
  }

  void setRankingPlayerFilterExact(bool exact) {
    rankingPlayerFilterExact = exact;
    notifyListeners();
  }

  void clearRankingPlayerFilter() {
    rankingPlayerFilter = [];
    notifyListeners();
  }

  void showToast(String msg) {
    toast = msg;
    _toastTimer?.cancel();
    notifyListeners();
    _toastTimer = Timer(const Duration(milliseconds: 2600), () {
      toast = '';
      notifyListeners();
    });
  }

  // ============================== NEW GAME SHEET ==============================

  void openSheet() {
    sheetOpen = true;
    step = 1;
    creatingGame = false;
    browsingLibrary = false;
    browsingOtherGroups = false;
    busy = false;
    savingMatch = false;
    flowError = null;
    draft = NewGameDraft.initial();
    _editingMatchId = null;
    _editingMatchCreatedAt = null;
    _editingMatchSeriesId = null;
    _editingMatchSeriesGame = null;
    _editingMatchSeriesLength = null;
    _editingGameId = null;
    _activeTournamentId = null;
    _activeTournamentMatchId = null;
    _liveSessionId = null;
    _draftHasProgress = false;
    _justSaved = false;
    _justCreatedTournament = null;
    notifyListeners();
  }

  /// Runs whenever the sheet closes, however it closed — save, back out
  /// through the steps, or the header's close button (see `showNewGameSheet`).
  /// A match left mid-score without being saved is kept as a resumable local
  /// draft (already backed up on disk by `_persistDraftLocally`) and offered
  /// right back on the home screen instead of only resurfacing at the next
  /// sign-in; anything else (saved, or never actually scored) clears it. A
  /// tournament match (`_activeTournamentId != null`) is never offered this
  /// way — same reasoning as `_startLiveSessionIfNeeded` not broadcasting it
  /// live: the bracket screen is already the place to pick it back up,
  /// tapping the same match again there.
  void closeSheet() {
    sheetOpen = false;
    final root = currentRootId;
    final groupId = currentGroupId;
    if (!_justSaved && _editingMatchId == null && _activeTournamentId == null && _draftHasProgress && root != null && groupId != null) {
      // Left mid-score without saving — hold the live session (grace
      // window) rather than ending it outright, and offer the draft back
      // right away instead of only at the next sign-in.
      _holdLiveSession();
      pendingLocalDraft = PendingLocalDraft(
        rootGroupId: root,
        groupId: groupId,
        draft: draft,
        updatedAt: DateTime.now(),
        liveSessionId: _liveSessionId,
        liveSessionHeldAt: _liveSessionHeldAt,
        tournamentId: _activeTournamentId,
        tournamentMatchId: _activeTournamentMatchId,
      );
    } else {
      _endLiveSession();
      unawaited(_clearLocalDraft());
    }
    _justSaved = false;
    _draftHasProgress = false;
    notifyListeners();
  }

  /// Ends the live session started for the match just left, if any — the
  /// single cleanup point reached whether the match was just saved or
  /// scoring was abandoned (both close the sheet). Fire-and-forget: nothing
  /// in the UI depends on this having finished.
  void _endLiveSession() {
    _liveSessionHoldTimer?.cancel();
    _liveSessionHoldTimer = null;
    _liveSessionHeldAt = null;
    final root = currentRootId;
    final sessionId = _liveSessionId;
    _liveSessionId = null;
    if (root == null || sessionId == null) return;
    unawaited(matchesRepo.endLiveSession(rootGroupId: root, sessionId: sessionId));
  }

  /// Puts the current live session "on hold" instead of ending it outright
  /// — used when leaving a match that might still be resumed (backgrounding
  /// the app, closing the sheet without saving): the last scores stay
  /// visible to the group for [_liveSessionGrace], removed only if nobody
  /// comes back in time. [_liveSessionId] itself is left untouched so
  /// resuming can reattach to the very same Firestore doc.
  void _holdLiveSession() {
    final root = currentRootId;
    final sessionId = _liveSessionId;
    if (root == null || sessionId == null) return;
    _liveSessionHeldAt = DateTime.now();
    unawaited(_persistDraftLocally());
    unawaited(matchesRepo.setLiveSessionHeld(rootGroupId: root, sessionId: sessionId, held: true));
    _liveSessionHoldTimer?.cancel();
    _liveSessionHoldTimer = Timer(_liveSessionGrace, () {
      _liveSessionHoldTimer = null;
      if (_liveSessionId != sessionId) return; // already resumed, or superseded
      _liveSessionHeldAt = null;
      _liveSessionId = null;
      unawaited(_persistDraftLocally());
      unawaited(matchesRepo.endLiveSession(rootGroupId: root, sessionId: sessionId));
    });
  }

  /// Cancels a pending hold because the player came back in time — the
  /// existing [_liveSessionId] keeps being used as-is.
  void _cancelLiveSessionHold() {
    _liveSessionHoldTimer?.cancel();
    _liveSessionHoldTimer = null;
    _liveSessionHeldAt = null;
  }

  /// Reopens an already-saved match for editing — straight to the scores
  /// step, pre-filled with its players/scores/timeline so you can correct a
  /// mistake or (for a multi-round match) keep adding rounds. Saving writes
  /// back to the same match doc instead of creating a new one.
  void resumeMatch(GameMatch match, Game game) {
    sheetOpen = true;
    creatingGame = false;
    browsingLibrary = false;
    browsingOtherGroups = false;
    busy = false;
    savingMatch = false;
    flowError = null;
    _editingMatchId = match.id;
    _editingMatchCreatedAt = match.createdAt;
    _editingMatchSeriesId = match.seriesId;
    _editingMatchSeriesGame = match.seriesGame;
    _editingMatchSeriesLength = match.seriesLength;
    // Carries over from the match's own tags (see GameMatch.tournamentId) —
    // not just whoever is calling resumeMatch — so a tournament-linked
    // match re-syncs its bracket node on save (see
    // AppState._recordTournamentResult) however it was reopened: tapping it
    // on the bracket screen, or "Modifier" from its regular history card.
    _activeTournamentId = match.tournamentId;
    _activeTournamentMatchId = match.tournamentMatchId;
    _liveSessionId = null; // resuming never starts/re-fires a live session

    final playerIds = match.entries.map((e) => e.playerId).toList();
    final team = <String, String>{for (final e in match.entries) e.playerId: e.teamId ?? 'A'};
    final points = <String, int>{for (final e in match.entries) e.playerId: e.points};
    final teamCount = team.values.toSet().length.clamp(2, 4);
    // Best-to-worst order, reconstructed from final scores — exact for
    // single-ranking ranks matches (points already encode rank order) and a
    // sane starting point for the next round otherwise.
    final rankOrder = [...playerIds]..sort((a, b) => (points[b] ?? 0).compareTo(points[a] ?? 0));

    // The match may have been recorded under a rule that's since had
    // "Manches multiples" turned off — the input-mode picker wouldn't offer
    // that option anymore, so fall back to the closest still-available mode
    // instead of leaving the UI stuck showing a mode selector that doesn't
    // match the rendered body.
    final rule = game.resolveRule(match.ruleId);
    var inputMode = match.resolvedInputMode;
    if (inputMode == 'rounds' && !rule.multiRound) {
      inputMode = 'quick';
    }

    draft = NewGameDraft(
      gameId: match.gameId,
      ruleId: match.ruleId,
      mode: match.mode,
      unit: match.unit,
      teamCount: teamCount,
      playerIds: playerIds,
      team: team,
      points: points,
      inputMode: inputMode,
      timeline: List.of(match.timeline),
      rankOrder: rankOrder,
    );
    // Only a plain match ever gets resumed this way (isTournamentFlow stays
    // false) — jump straight to its last step, "scores".
    step = stepSequence.length;
    notifyListeners();
  }

  /// Restores a match found on this device (see [pendingLocalDraft]) that
  /// was still being scored when the app was killed — straight to the
  /// scores step, exactly where the player left off. Unlike [openSheet],
  /// this must NOT reset [draft]. The local storage entry itself is left in
  /// place (only [closeSheet] clears it) so a crash right after resuming
  /// still leaves something to offer next time.
  void resumeLocalDraft() {
    final pending = pendingLocalDraft;
    if (pending == null) return;
    sheetOpen = true;
    creatingGame = false;
    browsingLibrary = false;
    browsingOtherGroups = false;
    busy = false;
    savingMatch = false;
    flowError = null;
    _editingMatchId = null;
    _editingMatchCreatedAt = null;
    _activeTournamentId = pending.tournamentId;
    _activeTournamentMatchId = pending.tournamentMatchId;
    draft = pending.draft;
    step = 4;
    _draftHasProgress = true;
    _justSaved = false;
    _liveSessionHoldTimer?.cancel();
    _liveSessionHoldTimer = null;
    _liveSessionHeldAt = null;
    // Still within the grace window this session was held for? Reattach to
    // the same Firestore doc instead of starting a fresh one — otherwise
    // treat it as gone (it may already have been cleaned up, or will be by
    // whichever device's timer got to run first — either way, not ours to
    // reuse anymore).
    final heldAt = pending.liveSessionHeldAt;
    final withinGrace = pending.liveSessionId != null && heldAt != null && DateTime.now().difference(heldAt) <= _liveSessionGrace;
    if (!withinGrace && pending.liveSessionId != null) {
      // The app may have been killed before its own hold timer could fire —
      // clean up the stale session now that we're back, so it doesn't sit
      // around looking "live" to the rest of the group.
      final staleRoot = pending.rootGroupId;
      unawaited(matchesRepo.endLiveSession(rootGroupId: staleRoot, sessionId: pending.liveSessionId!));
    }
    _liveSessionId = withinGrace ? pending.liveSessionId : null;
    if (groups.any((g) => g.id == pending.groupId)) {
      currentGroupId = pending.groupId;
      _resubscribeGroupData();
    }
    pendingLocalDraft = null;
    notifyListeners();
    if (withinGrace) {
      _pushLiveUpdate(immediate: true);
    } else {
      unawaited(_startLiveSessionIfNeeded());
    }
  }

  /// Drops a match found on this device without resuming it — the player
  /// explicitly doesn't want to continue it.
  void discardLocalDraft() {
    pendingLocalDraft = null;
    unawaited(_clearLocalDraft());
    notifyListeners();
  }

  void sheetBack() {
    if (browsingLibrary) {
      browsingLibrary = false;
    } else if (browsingOtherGroups) {
      browsingOtherGroups = false;
    } else if (creatingGame) {
      creatingGame = false;
      _editingGameId = null;
    } else if (step > 1) {
      // Leaving the scores step (even just stepping back to "Qui joue ?")
      // means the live session no longer reflects a screen anyone is
      // actually looking at — end it. Advancing back to it starts a fresh
      // one via primaryAction/_startLiveSessionIfNeeded. Only the "partie
      // simple" flow ever reaches a scores step — a tournament's last step
      // is "qui joue ?", not scores (see isTournamentFlow).
      if (currentStepKind == WizardStepKind.scores) _endLiveSession();
      step -= 1;
    } else {
      sheetOpen = false;
      _endLiveSession();
    }
    notifyListeners();
  }

  /// Called by the root widget's [WidgetsBindingObserver] whenever the app
  /// moves to/from the foreground. The live session is meant to mirror the
  /// scores screen actually being on someone's screen, so leaving the app
  /// while scoring ends it exactly like navigating away within the sheet
  /// does — and coming back to it resumes broadcasting.
  void handleAppLifecycleChange(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (sheetOpen && !isTournamentFlow && step == 4 && _editingMatchId == null) {
        if (_liveSessionId != null) {
          // Still within the grace window (or never actually held) — pick
          // the same session back up rather than starting a new one.
          _cancelLiveSessionHold();
          _pushLiveUpdate(immediate: true);
        } else {
          // The connectivity stream can miss transitions that happened
          // while backgrounded on some platforms — re-seed the snapshot
          // before deciding whether to start a fresh session.
          unawaited(_refreshConnectivitySnapshot().then((_) {
            notifyListeners();
            return _startLiveSessionIfNeeded();
          }));
        }
      }
      return;
    }
    // Leaving the app doesn't end the session outright — see
    // _holdLiveSession — so a quick app-switch or a notification check
    // doesn't drop the match from spectators' view.
    if (sheetOpen && !isTournamentFlow && step == 4) _holdLiveSession();
  }

  void startNewGame() {
    creatingGame = true;
    _editingGameId = null;
    gameForm = GameFormDraft.initial();
    notifyListeners();
  }

  /// Opens the same form as [startNewGame], pre-filled with an existing
  /// game's settings (identity + every one of its rules) — saving overwrites
  /// it in place instead of creating a new doc (see [createGame]). Also how
  /// a new rule gets added to an existing game: this same form's "+ Ajouter
  /// une règle" just appends a blank [GameRuleFormDraft].
  void startEditingGame(Game game) {
    creatingGame = true;
    _editingGameId = game.id;
    gameForm = GameFormDraft(
      name: game.name,
      emoji: game.emoji,
      category: game.category,
      rules: game.rules.map(GameRuleFormDraft.fromRule).toList(),
    );
    notifyListeners();
  }

  Future<void> startBrowsingLibrary() async {
    browsingLibrary = true;
    librarySearch = '';
    notifyListeners();
    if (gameLibrary.isEmpty) {
      libraryLoading = true;
      notifyListeners();
      try {
        gameLibrary = await gameLibraryRepo.fetchLibrary();
      } catch (e) {
        flowError = e.toString();
      } finally {
        libraryLoading = false;
        notifyListeners();
      }
    }
  }

  void setLibrarySearch(String q) {
    librarySearch = q;
    notifyListeners();
  }

  List<Game> get filteredLibrary {
    final q = librarySearch.trim().toLowerCase();
    if (q.isEmpty) return gameLibrary;
    return gameLibrary.where((g) => g.name.toLowerCase().contains(q) || g.category.toLowerCase().contains(q)).toList();
  }

  /// Imports a library game into the current group's own catalog and
  /// selects it as the match being created — one tap from "browse" straight
  /// to "playing it".
  Future<void> importLibraryGame(Game libraryGame) async {
    final root = _activeRootId;
    if (root == null) return;
    busy = true;
    flowError = null;
    notifyListeners();
    try {
      final game = await _activeGamesRepo.importGame(root, libraryGame);
      // Not `pickGame(game.id)`: the watchGames stream may not have caught
      // up with this just-created doc yet, so `gameById` could still miss
      // it — apply its (already known) default rule directly instead.
      draft.gameId = game.id;
      draft.ruleId = null;
      if (!game.hasMultipleRules) _applyRule(game.defaultRule);
      browsingLibrary = false;
      showToast('« ${game.name} » ajouté à votre catalogue.');
    } catch (e) {
      flowError = e.toString();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Fetches the game catalogs of every other root group the user belongs
  /// to, so one can be picked and copied into the current group — the
  /// cross-group equivalent of [startBrowsingLibrary].
  Future<void> startBrowsingOtherGroups() async {
    browsingOtherGroups = true;
    otherGroupsSearch = '';
    otherGroupsLoading = true;
    otherGroupsGames = [];
    notifyListeners();
    try {
      final currentRoot = currentRootId;
      final otherRoots = groups.where((g) => g.id != currentRoot).toList();
      final results = <OtherGroupGame>[];
      for (final root in otherRoots) {
        final games = await gamesRepo.fetchGames(root.id);
        results.addAll(games.map((g) => OtherGroupGame(game: g, groupId: root.id, groupName: root.name)));
      }
      otherGroupsGames = results;
    } catch (e) {
      flowError = e.toString();
    } finally {
      otherGroupsLoading = false;
      notifyListeners();
    }
  }

  void setOtherGroupsSearch(String q) {
    otherGroupsSearch = q;
    notifyListeners();
  }

  List<OtherGroupGame> get filteredOtherGroupsGames {
    final q = otherGroupsSearch.trim().toLowerCase();
    if (q.isEmpty) return otherGroupsGames;
    return otherGroupsGames.where((og) => og.game.name.toLowerCase().contains(q) || og.groupName.toLowerCase().contains(q)).toList();
  }

  /// Copies a game found in another group into the current group's own
  /// catalog and selects it as the match being created — mirrors
  /// [importLibraryGame].
  Future<void> importOtherGroupGame(OtherGroupGame source) async {
    final root = currentRootId;
    if (root == null) return;
    busy = true;
    flowError = null;
    notifyListeners();
    try {
      final game = await gamesRepo.importGame(root, source.game);
      // See importLibraryGame for why this doesn't just call pickGame.
      draft.gameId = game.id;
      draft.ruleId = null;
      if (!game.hasMultipleRules) _applyRule(game.defaultRule);
      browsingOtherGroups = false;
      showToast('« ${game.name} » ajouté à votre catalogue.');
    } catch (e) {
      flowError = e.toString();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  void setGameForm(GameFormDraft Function(GameFormDraft) patch) {
    gameForm = patch(gameForm);
    notifyListeners();
  }

  /// Builds a persisted [GameRule] from one of the form's editable blocks —
  /// shared by [createGame]'s new-game and edit-in-place paths.
  GameRule _ruleFromForm(GameRuleFormDraft f) {
    final isRanks = f.countType == CountType.ranks;
    final isPointGame = f.countType == CountType.highWins || f.countType == CountType.lowWins;
    // No numeric score at all for a rounds-won tally, a ranks-based
    // classement, or a plain win/loss mark — a point limit only makes sense
    // when there's actually a running point total.
    final noPointLimit = f.countType == CountType.wins || isRanks || f.countType == CountType.winLoss;
    final scoreFields = isPointGame
        ? f.scoreFields.where((field) => field.label.trim().isNotEmpty).map((field) => field.copyWith(label: field.label.trim())).toList()
        : null;
    final multiRound = scoreFields != null && scoreFields.isNotEmpty ? false : f.multiRound;
    return GameRule(
      id: f.id,
      name: f.name.trim(),
      countType: f.countType,
      pointLimit: noPointLimit ? null : f.parsedPointLimit,
      topRoles: isRanks ? f.cleanTopRoles : null,
      bottomRoles: isRanks ? f.cleanBottomRoles : null,
      topPoints: isRanks ? f.derivedTopPoints : null,
      bottomPoints: isRanks ? f.derivedBottomPoints : null,
      multiRound: multiRound,
      scoreFields: scoreFields,
    );
  }

  Future<void> createGame() async {
    final root = _activeRootId;
    if (root == null || !gameForm.isValid) return;
    if (_rejectIfActiveContextClosed()) return;
    busy = true;
    flowError = null;
    notifyListeners();
    try {
      final rules = gameForm.rules.map(_ruleFromForm).toList();
      final Game game;
      if (_editingGameId != null) {
        game = Game(
          id: _editingGameId!,
          name: gameForm.name.trim(),
          emoji: gameForm.emoji,
          category: gameForm.category,
          rules: rules,
        );
        await _activeGamesRepo.updateGame(root, game);
        showToast('Jeu mis à jour.');
        _editingGameId = null;
      } else {
        game = await _activeGamesRepo.createGame(
          root,
          name: gameForm.name.trim(),
          emoji: gameForm.emoji,
          category: gameForm.category,
          rules: rules,
        );
      }
      // Not `pickGame(game.id)`: the watchGames stream may not have caught
      // up with this just-created/edited doc yet, so `gameById` could still
      // miss it — apply its (already known) default rule directly instead.
      draft.gameId = game.id;
      draft.ruleId = null;
      if (!game.hasMultipleRules) {
        _applyRule(game.defaultRule);
      } else {
        _syncDetailedScores();
      }
      creatingGame = false;
    } catch (e) {
      flowError = e.toString();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// The rule actually in effect for the draft's current game — resolves
  /// [NewGameDraft.ruleId] against the picked game's rules, falling back to
  /// its one default rule when nothing's been explicitly chosen (a game
  /// with just one rule never shows the "Quelle règle ?" step at all).
  GameRule? get draftRule => gameById(draft.gameId ?? '')?.resolveRule(draft.ruleId);

  /// Applies a rule's config to the draft — shared by [pickGame] (when the
  /// game has only one rule, so there's nothing to ask) and [pickRule]
  /// (once the "Quelle règle ?" step answers it).
  void _applyRule(GameRule? rule) {
    draft.unit = rule?.defaultUnit ?? 'points';
    // Reset the input mode so a stale 'rounds' choice from a previous
    // multi-round rule can't leak into one that doesn't support it (its
    // option wouldn't even be shown).
    draft.inputMode = 'quick';
    // Ranks and win/loss rules are always solo scoring — force it so a
    // stale 'team' choice from a previously-picked rule can't leak in
    // (their step-2 UI never shows the mode/team pickers to change it back).
    if (rule != null && (rule.isRanks || rule.isWinLoss)) draft.mode = 'ffa';
    draft.scoreBreakdown.clear();
    _syncDetailedScores();
  }

  void pickGame(String id) {
    final g = gameById(id);
    draft.gameId = id;
    draft.ruleId = null;
    // A game with several rules defers _applyRule until pickRule answers
    // the dedicated step — nothing to apply yet.
    if (g != null && !g.hasMultipleRules) _applyRule(g.defaultRule);
    notifyListeners();
  }

  /// Answers the "Quelle règle ?" step, shown right after "Quel jeu ?" only
  /// when the picked game has more than one rule (see [Game.hasMultipleRules]).
  void pickRule(String ruleId) {
    final g = gameById(draft.gameId ?? '');
    draft.ruleId = ruleId;
    _applyRule(g?.ruleById(ruleId));
    notifyListeners();
  }

  /// Whether the sheet is currently building a tournament rather than a
  /// single match (see [NewGameDraft.creationKind]) — everything from the
  /// step sequence to what the primary button does branches on this.
  bool get isTournamentFlow => draft.creationKind == 'tournament';

  /// What each 1-based `step` index currently means — a plain match is
  /// `kind · game · [rule] · players · scores`, a tournament is `kind ·
  /// tournamentFormat · game · [rule] · players`. `rule` only appears once a
  /// game is picked and it actually has more than one (see
  /// [Game.hasMultipleRules]), exactly like the old variant-picker sheet
  /// only ever appeared for a game that had variants. [NewGameSheet]'s
  /// titles/subtitles/progress dots and [canProceed]/[primaryAction]/
  /// [sheetBack] all key off this instead of hard-coded step numbers, so the
  /// sheet doesn't need separate bookkeeping for "does this game need a
  /// rule step".
  List<WizardStepKind> get stepSequence {
    final needsRuleStep = gameById(draft.gameId ?? '')?.hasMultipleRules ?? false;
    if (isTournamentFlow) {
      return [
        WizardStepKind.kind,
        WizardStepKind.tournamentFormat,
        WizardStepKind.game,
        if (needsRuleStep) WizardStepKind.rule,
        WizardStepKind.players,
      ];
    }
    return [
      WizardStepKind.kind,
      WizardStepKind.game,
      if (needsRuleStep) WizardStepKind.rule,
      WizardStepKind.players,
      WizardStepKind.scores,
    ];
  }

  int get totalSteps => stepSequence.length;

  /// The kind of step currently on screen — `step` is 1-based.
  WizardStepKind get currentStepKind => stepSequence[(step - 1).clamp(0, stepSequence.length - 1)];

  /// True while the sheet is scoring or correcting one specific tournament
  /// bracket match (see [startTournamentMatch], or [resumeMatch] reopening
  /// an already-played one) — as opposed to [isTournamentFlow], which is
  /// true while *building* a new tournament. The game and players are fixed
  /// by the bracket node here, not something to step back and revisit, so
  /// `NewGameSheet` uses this to show a plain close button instead of the
  /// usual back-through-the-wizard-steps arrow.
  bool get isEditingTournamentMatch => _activeTournamentId != null;

  /// Answers the sheet's very first step: "Partie simple" or "Tournoi" —
  /// see [isTournamentFlow].
  void setCreationKind(String kind) {
    draft.creationKind = kind;
    notifyListeners();
  }

  void setTournamentFormat(TournamentFormat format) {
    draft.tournamentFormat = format;
    notifyListeners();
  }

  void setTournamentGroupsCount(int n) {
    draft.tournamentGroupsCount = n;
    notifyListeners();
  }

  void setTournamentQualifiersPerGroup(int n) {
    draft.tournamentQualifiersPerGroup = n;
    notifyListeners();
  }

  void setMode(String mode) {
    draft.mode = mode;
    notifyListeners();
  }

  void setTeamCount(int n) {
    final maxLabel = String.fromCharCode(65 + n - 1);
    draft.team.updateAll((uid, t) => t.compareTo(maxLabel) > 0 ? 'A' : t);
    draft.teamCount = n;
    notifyListeners();
  }

  /// Switches team-mode "Saisie rapide" between one score per team
  /// ('global') and one per player ('perPlayer', the default) — clears
  /// whatever's on the board for the mode being left, same reasoning as
  /// [setInputMode] (the two don't share a meaningful running total).
  void setTeamScoreMode(String mode) {
    if (draft.teamScoreMode == mode) return;
    draft.teamScoreMode = mode;
    draft.points = {for (final id in draft.playerIds) id: 0};
    draft.teamPoints = {};
    _pushLiveUpdate();
    notifyListeners();
  }

  /// "Manches gagnées" only ever makes sense scored round-by-round, one
  /// declared winner per manche (see [_WinLossRoundsInput]/`addRound`) — a
  /// free-form "Saisie rapide"/"En direct" counter has no way to guarantee
  /// the tally it produces actually corresponds to the manches played (you
  /// could bump the same player's count several times for what's supposed
  /// to be a single manche). So switching to it always forces round-based
  /// input, and the score board resets — the two don't share a meaningful
  /// running total.
  void setUnit(String u) {
    final rule = draftRule;
    if (rule != null && u != rule.defaultUnit) return;
    if (draft.unit == u) return;
    draft.unit = u;
    draft.inputMode = u == 'wins' ? 'rounds' : 'quick';
    draft.points = {for (final id in draft.playerIds) id: 0};
    draft.timeline = [];
    _pushLiveUpdate();
    notifyListeners();
  }

  /// Sets the "best of N" format (1 = single match, otherwise 3/5/7 legs) —
  /// locked once the series has actually started (its first leg saved) so
  /// switching format mid-series can't happen.
  void setBestOf(int n) {
    if (draft.seriesId != null) return;
    draft.bestOf = n;
    notifyListeners();
  }

  /// Backdates the match being created to `date` (its calendar day is what
  /// matters — see [effectivePlayedAt]) — e.g. "hier", "avant-hier", or any
  /// date picked from the calendar. Pass null to go back to the default
  /// ("aujourd'hui", using the real save time).
  void setPlayedAt(DateTime? date) {
    draft.playedAt = date == null ? null : DateTime(date.year, date.month, date.day);
    notifyListeners();
  }

  /// The date the draft is currently set to be recorded under — today
  /// (the default) unless backdated via [setPlayedAt].
  DateTime get effectivePlayedAt {
    final now = DateTime.now();
    return draft.playedAt ?? DateTime(now.year, now.month, now.day);
  }

  /// Switches how scores are entered (Saisie rapide/En direct/Par manche —
  /// or Une manche/Plusieurs manches for ranks games). Scores from the
  /// previous mode are cleared: "rounds" tracks a running timeline that
  /// "quick" doesn't touch, so letting the two mix would desync the
  /// displayed total from the chart/round history.
  void setInputMode(String m) {
    final next = m == 'rounds' ? 'rounds' : 'quick';
    if (draft.inputMode == next) return;
    draft.inputMode = next;
    draft.points = {for (final id in draft.playerIds) id: 0};
    draft.timeline = [];
    _pushLiveUpdate();
    notifyListeners();
  }

  void togglePlayer(String uid) {
    final has = draft.playerIds.contains(uid);
    if (has) {
      draft.playerIds.remove(uid);
      draft.rankOrder.remove(uid);
      draft.scoreBreakdown.remove(uid);
    } else {
      draft.playerIds.add(uid);
      draft.team.putIfAbsent(uid, () => 'A');
      draft.points.putIfAbsent(uid, () => 0);
      draft.rankOrder.add(uid);
      final rule = draftRule;
      if (rule != null && rule.hasScoreFields) {
        draft.scoreBreakdown[uid] = {for (final field in rule.scoreFields!) field.id: 0};
      }
    }
    notifyListeners();
  }

  List<GameScoreField> get draftScoreFields => draftRule?.scoreFields ?? const [];

  void _syncDetailedScores() {
    final fields = draftScoreFields;
    if (fields.isEmpty) {
      draft.scoreBreakdown.clear();
      return;
    }
    final fieldIds = fields.map((f) => f.id).toSet();
    draft.scoreBreakdown.removeWhere((uid, _) => !draft.playerIds.contains(uid));
    for (final uid in draft.playerIds) {
      final scores = draft.scoreBreakdown.putIfAbsent(uid, () => <String, int>{});
      scores.removeWhere((fieldId, _) => !fieldIds.contains(fieldId));
      for (final field in fields) {
        scores.putIfAbsent(field.id, () => 0);
      }
      draft.points[uid] = scores.values.fold<int>(0, (sum, value) => sum + value);
    }
  }

  void setDetailedScore(String uid, String fieldId, int value) {
    final scores = draft.scoreBreakdown.putIfAbsent(uid, () => <String, int>{});
    // Unlike setPoints/bump/addRound, a category breakdown can legitimately
    // go negative (e.g. military losses in 7 Wonders) — clamped to a wide
    // but finite range rather than [0, 1<<30] to still block a stray
    // "999999999999" typo from ending up saved into a real match.
    scores[fieldId] = value.clamp(-(1 << 20), 1 << 20);
    draft.points[uid] = scores.values.fold<int>(0, (sum, current) => sum + current);
    _pushLiveUpdate();
    notifyListeners();
  }

  /// Moves `uid` one place better (toward 1st) in the ranks-mode finishing
  /// order.
  void moveRankUp(String uid) {
    final i = draft.rankOrder.indexOf(uid);
    if (i <= 0) return;
    draft.rankOrder.removeAt(i);
    draft.rankOrder.insert(i - 1, uid);
    _pushLiveUpdate();
    notifyListeners();
  }

  /// Moves `uid` one place worse (toward last) in the ranks-mode finishing
  /// order.
  void moveRankDown(String uid) {
    final i = draft.rankOrder.indexOf(uid);
    if (i == -1 || i >= draft.rankOrder.length - 1) return;
    draft.rankOrder.removeAt(i);
    draft.rankOrder.insert(i + 1, uid);
    _pushLiveUpdate();
    notifyListeners();
  }

  void setPlayerTeam(String uid, String team) {
    draft.team[uid] = team;
    notifyListeners();
  }

  void bump(String uid, int delta) {
    final v = ((draft.points[uid] ?? 0) + delta).clamp(0, 1 << 30);
    draft.points[uid] = v;
    _pushLiveUpdate();
    notifyListeners();
  }

  /// Sets a player's score directly (typed in), instead of stepping by ±1.
  void setPoints(String uid, int value) {
    draft.points[uid] = value.clamp(0, 1 << 30);
    _pushLiveUpdate();
    notifyListeners();
  }

  /// "Par équipe" quick scoring (see [setTeamScoreMode]) — team-id keyed
  /// equivalents of [bump]/[setPoints].
  void bumpTeam(String teamId, int delta) {
    final v = ((draft.teamPoints[teamId] ?? 0) + delta).clamp(0, 1 << 30);
    draft.teamPoints[teamId] = v;
    _pushLiveUpdate();
    notifyListeners();
  }

  void setTeamPoints(String teamId, int value) {
    draft.teamPoints[teamId] = value.clamp(0, 1 << 30);
    _pushLiveUpdate();
    notifyListeners();
  }

  /// Adds `delta` (any positive or negative amount, not just +1) to a
  /// player's live-mode score and records the new cumulative total in the
  /// timeline.
  void addPoints(String uid, int delta) {
    final v = ((draft.points[uid] ?? 0) + delta).clamp(0, 1 << 30);
    draft.points[uid] = v;
    draft.timeline.add(TimelinePoint(playerId: uid, val: v, delta: delta, time: DateTime.now()));
    _pushLiveUpdate();
    notifyListeners();
  }

  void undoPoint() {
    if (draft.timeline.isEmpty) return;
    draft.timeline.removeLast();
    final pts = <String, int>{for (final id in draft.playerIds) id: 0};
    for (final e in draft.timeline) {
      pts[e.playerId] = e.val;
    }
    draft.points = pts;
    _pushLiveUpdate();
    notifyListeners();
  }

  /// Adds one full round of scores at once ("rounds" input mode): one delta
  /// per player, recorded together so [draftRounds]/the evolution chart can
  /// treat them as a single round for everyone.
  void addRound(Map<String, int> roundDeltas) {
    for (final uid in draft.playerIds) {
      final delta = roundDeltas[uid] ?? 0;
      // Unlike bump/setPoints (quick mode, never negative), a round's
      // cumulative total can legitimately go negative — e.g. Président's
      // "trou du cul" role costs points round after round — so this only
      // guards against an absurd runaway value, not zero.
      final v = ((draft.points[uid] ?? 0) + delta).clamp(-(1 << 30), 1 << 30);
      draft.points[uid] = v;
      draft.timeline.add(TimelinePoint(playerId: uid, val: v, delta: delta, time: DateTime.now()));
    }
    _pushLiveUpdate();
    notifyListeners();
  }

  /// Undoes the most recently added round — removes the last entry for
  /// every player, since [addRound] always adds exactly one per player.
  void undoRound() {
    if (draft.timeline.isEmpty) return;
    final n = draft.playerIds.isEmpty ? 1 : draft.playerIds.length;
    final keep = draft.timeline.length > n ? draft.timeline.length - n : 0;
    draft.timeline = draft.timeline.sublist(0, keep);
    final pts = <String, int>{for (final id in draft.playerIds) id: 0};
    for (final e in draft.timeline) {
      pts[e.playerId] = e.val;
    }
    draft.points = pts;
    _pushLiveUpdate();
    notifyListeners();
  }

  /// Groups a rounds-mode timeline back into rounds (chunks of `playerCount`
  /// consecutive entries) for display — shared by [draftRounds] and the
  /// read-only live-session viewer, which chunks a spectated session's
  /// timeline the same way.
  List<List<TimelinePoint>> roundsFromTimeline(List<TimelinePoint> timeline, int playerCount) {
    if (playerCount == 0) return const [];
    final rounds = <List<TimelinePoint>>[];
    for (var i = 0; i < timeline.length; i += playerCount) {
      rounds.add(timeline.sublist(i, (i + playerCount).clamp(0, timeline.length)));
    }
    return rounds;
  }

  List<List<TimelinePoint>> get draftRounds => roundsFromTimeline(draft.timeline, draft.playerIds.length);

  /// Submits the current [NewGameDraft.rankOrder] as one round of a
  /// multi-round ranks game (e.g. a Président hand): converts the ranking
  /// into per-player points via [GameRule.rankPoints] and accumulates them
  /// through [addRound], exactly like the plain "rounds" points mode.
  void submitRankRound() {
    final rule = draftRule;
    if (rule == null || draft.rankOrder.isEmpty) return;
    final deltas = <String, int>{
      for (final (i, uid) in draft.rankOrder.indexed) uid: rule.rankPoints(i, draft.rankOrder.length),
    };
    addRound(deltas);
  }

  /// Player(s) currently in the lead within the draft, for the "EN TÊTE"
  /// highlight during quick/live scoring.
  List<String> get draftLeaderIds {
    if (draft.playerIds.isEmpty || !draft.playerIds.any((id) => (draft.points[id] ?? 0) != 0)) {
      return const [];
    }
    if (draft.mode == 'team') {
      final sums = <String, int>{};
      for (final id in draft.playerIds) {
        final t = draft.team[id] ?? 'A';
        sums[t] = (sums[t] ?? 0) + (draft.points[id] ?? 0);
      }
      String? bestTeam;
      var bestVal = -1 << 31;
      sums.forEach((t, v) {
        if (v > bestVal) {
          bestVal = v;
          bestTeam = t;
        }
      });
      return draft.playerIds.where((id) => (draft.team[id] ?? 'A') == bestTeam).toList();
    }
    final low = draft.unit == 'wins' ? false : (draftRule?.lowWins ?? false);
    String? bestId;
    var best = low ? 1 << 30 : -(1 << 30);
    for (final id in draft.playerIds) {
      final v = draft.points[id] ?? 0;
      if (low ? v < best : v > best) {
        best = v;
        bestId = id;
      }
    }
    return bestId == null ? const [] : [bestId];
  }

  /// Legs of the series currently being played, already saved, sorted
  /// 1st-to-latest — used by the scores step to show a running "manche X/N"
  /// recap while a "best of N" series is in progress.
  List<GameMatch> get draftSeriesLegs {
    final sid = draft.seriesId;
    if (sid == null) return const [];
    final legs = matches.where((m) => m.seriesId == sid).toList();
    legs.sort((a, b) => (a.seriesGame ?? 0).compareTo(b.seriesGame ?? 0));
    return legs;
  }

  /// Short "who won this leg" label — the same winnerIds() logic as
  /// [matchResultLine] but name-only, used for the series recap banner/toast.
  String legWinnerLabel(GameMatch leg) {
    final winners = leg.winnerIds();
    if (winners.isEmpty) return 'Égalité';
    if (leg.isTeam) {
      final teamId = leg.entries.where((e) => winners.contains(e.playerId)).firstOrNull?.teamId ?? 'A';
      return 'Équipe $teamId';
    }
    return winners.map((id) => playerById(id)?.displayName ?? '?').join(' & ');
  }

  /// True once one player/team of the series currently in progress has won
  /// a strict majority of legs (`bestOf ~/ 2 + 1`) — mathematically
  /// impossible for anyone else to catch up, however many legs remain.
  /// Drives the "cette série est déjà jouée d'avance" prompt shown after
  /// saving a leg (see [draftSeriesLeaderLabel]/`endSeriesEarly`).
  bool get draftSeriesDecided {
    if (draft.bestOf <= 1) return false;
    final legs = draftSeriesLegs;
    if (legs.isEmpty) return false;
    final majority = (draft.bestOf ~/ 2) + 1;
    return seriesTally(legs).leaderWins >= majority;
  }

  /// Name of the player/team already mathematically assured to win the
  /// series (only meaningful when [draftSeriesDecided] is true — a strict
  /// majority means there's exactly one such leader).
  String get draftSeriesLeaderLabel {
    final t = seriesTally(draftSeriesLegs);
    if (t.leaders.isEmpty) return '';
    final id = t.leaders.first;
    return t.isTeam ? 'L\'équipe $id' : (playerById(id)?.displayName ?? '?');
  }

  /// Stops the "série déjà jouée d'avance" popup from reappearing after
  /// every remaining leg of the current series (see
  /// [NewGameDraft.seriesDecidedPromptDismissed]).
  void dismissSeriesDecidedPrompt() {
    draft.seriesDecidedPromptDismissed = true;
    notifyListeners();
  }

  /// Ends the current "best of N" series right where it stands instead of
  /// playing out every remaining leg — e.g. after the "série déjà jouée
  /// d'avance ?" prompt. Flags every leg already saved as
  /// [GameMatch.seriesEndedEarly] instead of touching [GameMatch.seriesLength]
  /// — the series is still labelled "Best of {bestOf}" (not silently
  /// shrunk to however many legs were actually played), just marked
  /// finished instead of showing "En cours" forever — then finalizes the
  /// sheet exactly like a normal final-leg save.
  Future<void> endSeriesEarly() async {
    final root = currentRootId;
    final sid = draft.seriesId;
    if (root == null || sid == null) return;
    savingMatch = true;
    flowError = null;
    notifyListeners();
    try {
      final legs = draftSeriesLegs;
      for (final leg in legs) {
        if (leg.seriesEndedEarly) continue;
        await matchesRepo.updateMatch(root, leg.copyWith(seriesEndedEarly: true));
      }
      showToast('Série terminée après ${legs.length} partie${legs.length > 1 ? 's' : ''}.');
      _editingMatchId = null;
      _editingMatchCreatedAt = null;
      _editingMatchSeriesId = null;
      _editingMatchSeriesGame = null;
      _editingMatchSeriesLength = null;
      _justSaved = true;
      _endLiveSession();
      unawaited(_clearLocalDraft());
      sheetOpen = false;
      tab = AppTab.history;
    } catch (e) {
      flowError = e.toString();
    } finally {
      savingMatch = false;
      notifyListeners();
    }
  }

  bool get draftTeamsValid {
    if (draft.mode != 'team') return true;
    return draft.playerIds.map((id) => draft.team[id] ?? 'A').toSet().length >= 2;
  }

  /// The sheet's step sequence — see [stepSequence] for what each position
  /// means and how it varies between a plain match and a tournament, and
  /// with whether the picked game has more than one rule.
  bool get canProceed {
    if (browsingLibrary || browsingOtherGroups) return false;
    if (creatingGame) return gameForm.isValid;
    switch (currentStepKind) {
      case WizardStepKind.kind:
        return draft.creationKind != null;
      case WizardStepKind.game:
        return draft.gameId != null;
      case WizardStepKind.rule:
        return draft.ruleId != null;
      case WizardStepKind.players:
        return draft.playerIds.length >= 2 && draftTeamsValid;
      case WizardStepKind.scores:
        final rule = draftRule;
        // Both a CountType.winLoss rule and the generic "Manches gagnées"
        // unit share the same round-by-round "one winner per manche" input
        // (see _WinLossRoundsInput) and the same guard against saving a
        // nonsensical all-zero tally.
        if (rule?.isWinLoss == true || draft.unit == 'wins') {
          // Round-based: each round is already validated before it can be
          // submitted (see the "Valider la manche" button) — just require at
          // least one to have actually been played.
          if (draft.inputMode == 'rounds') return draftRounds.isNotEmpty;
          // Single manche (winLoss only — "Manches gagnées" always forces
          // rounds mode, see setUnit): at least one player must be marked
          // "Victoire", or every score sits at 0 and winnerIds() would
          // nonsensically call it a tie between everyone.
          return draft.points.values.any((v) => v > 0);
        }
        return true;
      case WizardStepKind.tournamentFormat:
        return true;
    }
  }

  Future<void> primaryAction() async {
    if (creatingGame) {
      await createGame();
      return;
    }
    final tournamentFlow = isTournamentFlow;
    if (tournamentFlow && step == totalSteps) {
      await _finishTournamentCreation();
      return;
    }
    if (!tournamentFlow && step == totalSteps) {
      await saveGame();
      return;
    }
    step += 1;
    if (!tournamentFlow && currentStepKind == WizardStepKind.scores) unawaited(_startLiveSessionIfNeeded());
    notifyListeners();
  }

  /// Builds the tournament from the wizard's draft — format chosen on step
  /// 2, game on step 3, participants/teams on step 4 (see
  /// [isTournamentFlow]/[createTournament]) — the tournament-flow
  /// counterpart of [saveGame]. On success, closes the sheet and stashes the
  /// new tournament for `NewGameSheet` to navigate to (see
  /// [takeJustCreatedTournament]) instead of just popping back to wherever
  /// the sheet was opened from.
  Future<void> _finishTournamentCreation() async {
    if (draft.gameId == null || draft.playerIds.length < 2) return;
    final entrantPlayerIds = draft.mode == 'team'
        ? [
            for (var i = 0; i < draft.teamCount; i++)
              draft.playerIds.where((id) => (draft.team[id] ?? 'A') == String.fromCharCode(65 + i)).toList(),
          ].where((team) => team.isNotEmpty).toList()
        : [for (final id in draft.playerIds) [id]];
    final saved = await createTournament(
      name: '',
      gameId: draft.gameId!,
      ruleId: draft.ruleId,
      format: draft.tournamentFormat,
      entrantPlayerIds: entrantPlayerIds,
      groupsCount: draft.tournamentGroupsCount,
      qualifiersPerGroup: draft.tournamentQualifiersPerGroup,
    );
    if (saved != null) {
      _justCreatedTournament = saved;
      _justSaved = true;
      sheetOpen = false;
      notifyListeners();
    }
  }

  /// Consumes the tournament just created via the sheet (see
  /// [_finishTournamentCreation]) — `NewGameSheet` calls this right after
  /// `primaryAction()` to know whether to navigate to the new bracket
  /// instead of just closing.
  Tournament? takeJustCreatedTournament() {
    final t = _justCreatedTournament;
    _justCreatedTournament = null;
    return t;
  }

  /// Starts a live session for the match currently being scored — the
  /// moment you first reach the scores step, or as soon as connectivity
  /// returns if it was unavailable at that moment (see
  /// [_onConnectivityChanged]/[handleAppLifecycleChange]). Never fires while
  /// resuming an already-saved match, and skipped entirely while offline (no
  /// network to push live updates to — the match just plays out locally,
  /// backed by [_persistDraftLocally]). Best-effort otherwise: scoring must
  /// never be blocked or errored out by a failed start.
  Future<void> _startLiveSessionIfNeeded() async {
    // Tournament matches never broadcast as "live" (see AppState.
    // startTournamentMatch) — the bracket screen already shows what's in
    // progress, and surfacing them in the home screen's "Parties en
    // direct"/spectator list too would just be confusing duplication for a
    // match nobody outside the tournament necessarily cares to watch.
    if (_editingMatchId != null || _activeTournamentId != null || _liveSessionId != null || !isOnline) return;
    final root = currentRootId;
    final groupId = currentGroupId;
    final uid = currentUser?.uid;
    final gameId = draft.gameId;
    if (root == null || groupId == null || uid == null || gameId == null) return;
    try {
      _liveSessionId = await matchesRepo.startLiveSession(
        rootGroupId: root,
        groupId: groupId,
        gameId: gameId,
        startedByUid: uid,
        startedByName: currentUser?.displayName ?? 'Un joueur',
        mode: draft.mode,
        unit: draft.unit,
        lowWins: draftRule?.lowWins ?? false,
      );
      // Sync the scores already on the board right away — matters most when
      // this fires on reconnect mid-match, where waiting for the next score
      // change would leave spectators looking at an empty session.
      _pushLiveUpdate(immediate: true);
    } catch (_) {
      // Not critical — the match itself still saves fine either way.
    }
  }

  /// Persists the draft locally (always, regardless of connectivity — the
  /// resumption safety net) and, if a live session is running, pushes the
  /// current scores to it — debounced so a burst of taps (e.g. holding the
  /// +1 button) doesn't fire a write per tap. Pass `immediate: true` to skip
  /// the debounce (used right after (re)starting a live session).
  void _pushLiveUpdate({bool immediate = false}) {
    _draftHasProgress = true;
    _liveUpdateDebounce?.cancel();
    void sync() {
      unawaited(_persistDraftLocally());
      final root = currentRootId;
      final sessionId = _liveSessionId;
      if (root == null || sessionId == null) return;
      unawaited(matchesRepo.updateLiveSession(
        rootGroupId: root,
        sessionId: sessionId,
        entries: _currentDraftEntries(),
        timeline: List.of(draft.timeline),
        inputMode: draft.inputMode,
      ));
    }

    if (immediate) {
      sync();
    } else {
      _liveUpdateDebounce = Timer(const Duration(milliseconds: 500), sync);
    }
  }

  // ============================== CONNECTIVITY ==============================

  Future<void> _initConnectivity() async {
    await _refreshConnectivitySnapshot();
    notifyListeners();
    try {
      _connectivitySub = Connectivity().onConnectivityChanged.listen(_onConnectivityChanged, onError: (_) {});
    } catch (_) {
      // Platform without connectivity_plus support — never fires again, but
      // the initial snapshot above still applies.
    }
  }

  Future<void> _refreshConnectivitySnapshot() async {
    try {
      final result = await Connectivity().checkConnectivity();
      isOnline = result.any((c) => c != ConnectivityResult.none);
    } catch (_) {
      // No platform implementation (e.g. some test harnesses) — default to
      // online so the UI never gets stuck showing a false "hors ligne"
      // badge; the live-session calls themselves stay best-effort regardless.
    }
  }

  /// Keeps the live session mirroring reality as connectivity changes mid
  /// match: reconnecting (re)starts and immediately syncs it, losing
  /// connectivity removes it from Firebase right away — the rest of the
  /// group shouldn't see a "live" match that's actually stalled.
  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final nowOnline = results.any((c) => c != ConnectivityResult.none);
    if (nowOnline == isOnline) return;
    isOnline = nowOnline;
    notifyListeners();
    if (isOnline) {
      if (sheetOpen && !isTournamentFlow && step == 4 && _editingMatchId == null && _liveSessionId == null) {
        unawaited(_startLiveSessionIfNeeded());
      }
    } else if (_liveSessionId != null) {
      _endLiveSession();
    }
  }

  // ============================== LOCAL DRAFT PERSISTENCE ==============================

  /// Writes the in-progress draft to device storage so it survives an app
  /// kill — the resumption safety net independent of connectivity. No-ops
  /// while resuming an already-saved match (`_editingMatchId != null`),
  /// since that's already durably stored in Firestore, and while scoring a
  /// tournament match (`_activeTournamentId != null`) — never offered back
  /// (see `closeSheet`), so there's nothing to gain from persisting it.
  Future<void> _persistDraftLocally() async {
    final uid = currentUser?.uid;
    final root = currentRootId;
    final groupId = currentGroupId;
    if (uid == null || root == null || groupId == null || draft.gameId == null || _editingMatchId != null || _activeTournamentId != null) {
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _localDraftKey,
        jsonEncode({
          'uid': uid,
          'rootGroupId': root,
          'groupId': groupId,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
          'liveSessionId': _liveSessionId,
          'liveSessionHeldAt': _liveSessionHeldAt?.millisecondsSinceEpoch,
          'tournamentId': _activeTournamentId,
          'tournamentMatchId': _activeTournamentMatchId,
          'draft': draft.toJson(),
        }),
      );
    } catch (_) {
      // Best-effort — a failed local write must never block scoring.
    }
  }

  Future<void> _clearLocalDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_localDraftKey);
    } catch (_) {}
  }

  /// Looks for a match left on this device by [uid] and offers it back as
  /// [pendingLocalDraft] — called at sign-in. Leaves entries belonging to a
  /// different uid untouched (a shared device might have another account's
  /// unfinished match), drops ones stale enough nobody would recognize them
  /// anymore, and — defensively, `_persistDraftLocally` no longer writes
  /// these at all — never offers back a tournament match (see `closeSheet`).
  Future<void> _loadPendingLocalDraft(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_localDraftKey);
      if (raw == null) return;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['uid'] != uid) return;
      if (data['tournamentId'] != null) {
        await prefs.remove(_localDraftKey);
        return;
      }
      final updatedAt = DateTime.fromMillisecondsSinceEpoch((data['updatedAt'] as num?)?.toInt() ?? 0);
      if (DateTime.now().difference(updatedAt) > _localDraftStaleAfter) {
        await prefs.remove(_localDraftKey);
        return;
      }
      final heldAtMs = (data['liveSessionHeldAt'] as num?)?.toInt();
      pendingLocalDraft = PendingLocalDraft(
        rootGroupId: data['rootGroupId'] as String,
        groupId: data['groupId'] as String,
        draft: NewGameDraft.fromJson(Map<String, dynamic>.from(data['draft'] as Map)),
        updatedAt: updatedAt,
        liveSessionId: data['liveSessionId'] as String?,
        liveSessionHeldAt: heldAtMs != null ? DateTime.fromMillisecondsSinceEpoch(heldAtMs) : null,
        tournamentId: data['tournamentId'] as String?,
        tournamentMatchId: data['tournamentMatchId'] as String?,
      );
      notifyListeners();
    } catch (_) {
      // Corrupted/unreadable entry — just don't offer a resume, nothing to
      // recover here.
    }
  }

  /// Builds the [MatchEntry] list the draft currently represents — the same
  /// ranks/team/ffa scoring logic [saveGame] uses to build the final match,
  /// reused here so the live session mid-game reflects the exact same
  /// scores the saved match will end up with.
  List<MatchEntry> _currentDraftEntries() {
    final rule = draftRule;
    if (rule?.isRanks == true && draft.inputMode == 'rounds') {
      return [for (final id in draft.playerIds) MatchEntry(playerId: id, points: draft.points[id] ?? 0)];
    }
    if (rule?.isRanks == true) {
      return [
        for (final (i, id) in draft.rankOrder.indexed)
          MatchEntry(playerId: id, points: rule!.rankPoints(i, draft.rankOrder.length), role: rule.rankRole(i, draft.rankOrder.length)),
      ];
    }
    if (draft.mode == 'team' && draft.teamScoreMode == 'global' && draft.inputMode == 'quick') {
      return _teamGlobalEntries();
    }
    return draft.playerIds
        .map((id) => MatchEntry(
              playerId: id,
              points: draft.points[id] ?? 0,
              teamId: draft.mode == 'team' ? (draft.team[id] ?? 'A') : null,
              scoreBreakdown: draft.scoreBreakdown[id],
            ))
        .toList();
  }

  /// "Par équipe" scoring (see [setTeamScoreMode]): each team's single
  /// combined score is split as evenly as possible across its members (any
  /// remainder going to the first few, in team-list order) so per-player
  /// ranking stats (points cumulés, moyenne…) stay meaningful without ever
  /// having tracked who specifically contributed what — while the team's
  /// own total, which is all [GameMatch.winnerIds] actually looks at for
  /// team matches, comes back out exactly as entered.
  List<MatchEntry> _teamGlobalEntries() {
    final entries = <MatchEntry>[];
    for (var i = 0; i < draft.teamCount; i++) {
      final teamId = String.fromCharCode(65 + i);
      final members = draft.playerIds.where((id) => (draft.team[id] ?? 'A') == teamId).toList();
      if (members.isEmpty) continue;
      final total = draft.teamPoints[teamId] ?? 0;
      final base = total ~/ members.length;
      final remainder = total % members.length;
      for (final (j, uid) in members.indexed) {
        entries.add(MatchEntry(playerId: uid, points: base + (j < remainder ? 1 : 0), teamId: teamId));
      }
    }
    return entries;
  }

  Future<void> saveGame() async {
    final inSalon = activeContext == ActiveContextKind.salon;
    final root = _activeRootId;
    final groupId = inSalon ? null : currentGroupId;
    final salonId = inSalon ? currentSalonId : null;
    if (root == null || (inSalon ? salonId == null : groupId == null) || draft.gameId == null) return;
    if (_rejectIfActiveContextClosed()) return;
    if (!isOnline) {
      // Some platforms (e.g. Firestore on web without persistence enabled)
      // would otherwise hang indefinitely trying to write offline. The
      // draft is already safe on-device (_persistDraftLocally) — better to
      // tell the player plainly than to leave "Enregistrement…" spinning.
      flowError = 'Vous êtes hors ligne — la partie reste enregistrée sur cet appareil, réessayez une fois connecté.';
      notifyListeners();
      return;
    }
    // A "best of N" series: every leg after the first shares the id minted
    // when the first one was saved. Editing an existing match (_editingMatchId
    // != null) never (re)enters series mode — see _editingMatchSeriesId.
    final isNewSeries = draft.bestOf > 1 && _editingMatchId == null;
    final isFinalLeg = !isNewSeries || draft.seriesLegIndex >= draft.bestOf;
    if (isNewSeries) {
      draft.seriesId ??= '${DateTime.now().microsecondsSinceEpoch}-${currentUser?.uid ?? 'x'}';
    }

    savingMatch = true;
    flowError = null;
    notifyListeners();
    final rule = draftRule;
    final entries = _currentDraftEntries();
    final now = DateTime.now();
    // Backdated (draft.playedAt set) keeps that calendar day but still uses
    // the actual save time-of-day, so multiple matches recorded under the
    // same backdated day still order sensibly; otherwise just "now".
    final playedAt = draft.playedAt;
    final createdAt = _editingMatchCreatedAt ??
        (playedAt == null ? now : DateTime(playedAt.year, playedAt.month, playedAt.day, now.hour, now.minute, now.second, now.millisecond));
    // A Salon match starts (or, on resubmission after a rejection, restarts)
    // needing every human player's confirmation — except the author, whose
    // own save already counts as their approval.
    final authorUid = currentUser?.uid;
    final initialConfirmedBy = inSalon && authorUid != null && entries.any((e) => e.playerId == authorUid) ? [authorUid] : const <String>[];
    final match = GameMatch(
      id: _editingMatchId ?? '', // assigned by the repository when creating
      gameId: draft.gameId!,
      groupId: groupId ?? '',
      mode: draft.mode,
      unit: draft.unit,
      lowWins: (rule?.isRanks == true || rule?.isWinLoss == true) ? false : (draft.unit == 'wins' ? false : (rule?.lowWins ?? false)),
      entries: entries,
      timeline: draft.timeline,
      createdAt: createdAt,
      scoreFields: rule?.scoreFields,
      ruleId: draft.ruleId,
      inputMode: draft.inputMode,
      createdByUid: currentUser?.uid,
      seriesId: _editingMatchId != null ? _editingMatchSeriesId : (isNewSeries ? draft.seriesId : null),
      seriesGame: _editingMatchId != null ? _editingMatchSeriesGame : (isNewSeries ? draft.seriesLegIndex : null),
      seriesLength: _editingMatchId != null ? _editingMatchSeriesLength : (isNewSeries ? draft.bestOf : null),
      tournamentId: _activeTournamentId,
      tournamentMatchId: _activeTournamentMatchId,
      salonId: salonId,
      confirmedBy: inSalon ? initialConfirmedBy : null,
    );
    try {
      if (_editingMatchId != null) {
        await _activeMatchesRepo.updateMatch(root, match);
        String? tournamentWarning;
        if (_activeTournamentId != null) {
          tournamentWarning = await _recordTournamentResult(match);
        }
        showToast(tournamentWarning == null ? 'Partie mise à jour ! Classement mis à jour.' : 'Partie mise à jour, mais $tournamentWarning.');
      } else {
        final saved = await _activeMatchesRepo.addMatch(root, match);
        if (_activeTournamentId != null) {
          await _recordTournamentResult(saved);
        }
        if (isNewSeries && !isFinalLeg) {
          showToast('Partie ${draft.seriesLegIndex} enregistrée — gagnée par ${legWinnerLabel(match)}. Partie suivante !');
        } else if (inSalon && saved.isPending) {
          showToast('Partie enregistrée — en attente de confirmation des autres joueurs.');
        } else {
          showToast('Partie enregistrée ! Classement mis à jour.');
        }
      }
      if (isFinalLeg) {
        _editingMatchId = null;
        _editingMatchCreatedAt = null;
        _editingMatchSeriesId = null;
        _editingMatchSeriesGame = null;
        _editingMatchSeriesLength = null;
        _activeTournamentId = null;
        _activeTournamentMatchId = null;
        _justSaved = true;
        // Ended right here rather than left to closeSheet() (which only runs
        // once the sheet's closing animation resolves) — a spectator
        // shouldn't be able to see "en direct" for even a moment after the
        // match is actually saved.
        _endLiveSession();
        unawaited(_clearLocalDraft());
        sheetOpen = false;
        tab = AppTab.history;
      } else {
        // More legs to play: keep the sheet open on the scores step, reset
        // just the scoring part of the draft (players/teams/game/format all
        // carry over unchanged) and start a fresh live session for the next
        // leg.
        _endLiveSession();
        draft.seriesLegIndex += 1;
        draft.points = {for (final id in draft.playerIds) id: 0};
        draft.scoreBreakdown = {for (final id in draft.playerIds) id: {for (final field in draftScoreFields) field.id: 0}};
        draft.timeline = [];
        draft.rankOrder = List.of(draft.playerIds);
        unawaited(_startLiveSessionIfNeeded());
        unawaited(_persistDraftLocally());
      }
    } catch (e) {
      flowError = e.toString();
    } finally {
      savingMatch = false;
      notifyListeners();
    }
  }

  /// Whether the signed-in user can delete `match`: the group's owner, or
  /// (for a Salon match — see [GameMatch.isSalonMatch]) the owner/admins of
  /// its Server, the last-resort way to resolve a contested match.
  bool canDeleteMatch(GameMatch match) {
    final uid = currentUser?.uid;
    if (uid == null) return false;
    if (match.isSalonMatch) return currentSalonServer?.isAdmin(uid) ?? false;
    return groupById(match.groupId)?.ownerId == uid;
  }

  /// Permanently deletes a single recorded match — one leg of a "best of N"
  /// series, or a standalone match. See [deleteMatchSeries] to remove every
  /// leg of a series at once.
  Future<bool> deleteMatch(GameMatch match) async {
    final root = _activeRootId;
    if (root == null || !canDeleteMatch(match)) return false;
    busy = true;
    flowError = null;
    notifyListeners();
    var ok = false;
    try {
      await _activeMatchesRepo.deleteMatch(root, match.id);
      showToast('Partie supprimée.');
      ok = true;
    } catch (e) {
      flowError = e.toString();
    } finally {
      busy = false;
      notifyListeners();
    }
    return ok;
  }

  /// Permanently deletes every leg of a "best of N" series at once (see
  /// [GameMatch.seriesId]) — the whole grouped card in history, not just one
  /// manche.
  Future<bool> deleteMatchSeries(List<GameMatch> legs) async {
    if (legs.isEmpty) return false;
    final root = _activeRootId;
    if (root == null || !canDeleteMatch(legs.first)) return false;
    busy = true;
    flowError = null;
    notifyListeners();
    var ok = false;
    try {
      for (final leg in legs) {
        await _activeMatchesRepo.deleteMatch(root, leg.id);
      }
      showToast('Série supprimée.');
      ok = true;
    } catch (e) {
      flowError = e.toString();
    } finally {
      busy = false;
      notifyListeners();
    }
    return ok;
  }

  /// Approves a Salon match `match` is the signed-in user is one of the
  /// players still needing to confirm it (see [GameMatch.requiredConfirmers]
  /// / [GameMatch.status]) — once every player has, it counts toward
  /// history/rankings. A no-op (returns false) for anything else: a Group
  /// match (always implicitly confirmed already), a match the caller didn't
  /// play in, or one they already confirmed.
  Future<bool> confirmMatch(GameMatch match) async {
    final uid = currentUser?.uid;
    final root = _activeRootId;
    if (uid == null || root == null || !match.isSalonMatch) return false;
    if (!match.requiredConfirmers.contains(uid) || (match.confirmedBy ?? const []).contains(uid)) return false;
    try {
      await _activeMatchesRepo.confirmMatch(rootId: root, matchId: match.id, uid: uid);
      return true;
    } catch (e) {
      flowError = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Rejects a Salon match — sends it back to its author (see
  /// [GameMatch.createdByUid]) to edit and resubmit (see [saveGame], which
  /// clears both [GameMatch.confirmedBy] and [GameMatch.rejectedBy] on
  /// resubmission). Same eligibility as [confirmMatch]: only a player still
  /// needing to confirm can reject.
  Future<bool> rejectMatch(GameMatch match) async {
    final uid = currentUser?.uid;
    final root = _activeRootId;
    if (uid == null || root == null || !match.isSalonMatch) return false;
    if (!match.requiredConfirmers.contains(uid)) return false;
    try {
      await _activeMatchesRepo.rejectMatch(rootId: root, matchId: match.id, uid: uid);
      showToast('Partie refusée — renvoyée à son auteur pour correction.');
      return true;
    } catch (e) {
      flowError = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Whether the signed-in user can force-delete `match` as a last resort
  /// for a contested Salon match — owner/admin of its Server. Equivalent to
  /// [canDeleteMatch] for a Salon match; kept as a distinctly-named getter
  /// since it's the one exposed in the confirmation UI (see plan doc).
  bool canForceResolveMatch(GameMatch match) => canDeleteMatch(match);

  /// Whether the signed-in user may reopen a rejected Salon match for
  /// editing (see [resumeMatch]) — only its own author.
  bool canEditRejectedMatch(GameMatch match) => match.isRejected && match.createdByUid == currentUser?.uid;

  // ============================== TOURNAMENTS ==============================

  /// Whether the signed-in user can delete `tournament` — mirrors
  /// [canDeleteMatch]: the group's owner.
  bool canDeleteTournament(Tournament tournament) {
    final uid = currentUser?.uid;
    return uid != null && groupById(tournament.groupId)?.ownerId == uid;
  }

  /// Deletes `tournament` and every match recorded against one of its
  /// bracket nodes (see [GameMatch.tournamentId]) — a full cascade, so a
  /// removed tournament never lingers in the history as orphaned "tournoi
  /// supprimé" entries (see `_TournamentMatchCard`'s fallback, which only
  /// exists for data that predates this cascade). Matches are removed
  /// before the tournament document itself so an interrupted deletion
  /// leaves, at worst, a tournament with dangling match links rather than
  /// stray tournament-tagged matches with nothing to point back to.
  Future<bool> deleteTournament(Tournament tournament) async {
    final root = currentRootId;
    if (root == null || !canDeleteTournament(tournament)) return false;
    busy = true;
    flowError = null;
    notifyListeners();
    var ok = false;
    try {
      final linkedMatches = matches.where((m) => m.tournamentId == tournament.id).toList();
      for (final m in linkedMatches) {
        await matchesRepo.deleteMatch(root, m.id);
      }
      await tournamentsRepo.deleteTournament(root, tournament.id);
      showToast('Tournoi et ses parties supprimés.');
      ok = true;
    } catch (e) {
      flowError = e.toString();
    } finally {
      busy = false;
      notifyListeners();
    }
    return ok;
  }

  /// Creates a new tournament: wraps `entrantPlayerIds` (already grouped
  /// into team-sized chunks by the caller — see [_finishTournamentCreation])
  /// into [TournamentEntrant]s in the given seed order, builds the initial
  /// bracket for `format` (see `lib/logic/tournament_bracket.dart`), and
  /// persists it.
  Future<Tournament?> createTournament({
    required String name,
    required String gameId,
    String? ruleId,
    required TournamentFormat format,
    required List<List<String>> entrantPlayerIds,
    int groupsCount = 1,
    int qualifiersPerGroup = 2,
  }) async {
    final root = currentRootId;
    final groupId = currentGroupId;
    if (root == null || groupId == null || entrantPlayerIds.length < 2) return null;
    if (_rejectIfGroupClosed(groupId)) return null;
    final entrants = [for (final (i, ids) in entrantPlayerIds.indexed) TournamentEntrant(id: 'e$i', playerIds: ids)];
    final entrantIds = entrants.map((e) => e.id).toList();
    final isGroups = format == TournamentFormat.groupsThenElimination;
    final matches = switch (format) {
      TournamentFormat.singleElimination => buildSingleElimination(entrantIds),
      TournamentFormat.doubleElimination => buildDoubleElimination(entrantIds),
      TournamentFormat.groupsThenElimination => buildGroupStage(entrantIds, groupsCount),
    };
    final tournament = Tournament(
      id: '',
      groupId: groupId,
      gameId: gameId,
      ruleId: ruleId,
      name: name.trim().isEmpty ? (gameById(gameId)?.name ?? 'Tournoi') : name.trim(),
      format: format,
      entrants: entrants,
      matches: matches,
      groupsCount: isGroups ? groupsCount : 0,
      qualifiersPerGroup: isGroups ? qualifiersPerGroup : 0,
      createdAt: DateTime.now(),
      createdByUid: currentUser?.uid,
    );
    busy = true;
    flowError = null;
    notifyListeners();
    Tournament? saved;
    try {
      saved = await tournamentsRepo.addTournament(root, tournament);
      showToast('Tournoi créé !');
    } catch (e) {
      flowError = e.toString();
    } finally {
      busy = false;
      notifyListeners();
    }
    return saved;
  }

  /// Opens the new-game sheet already locked onto one bracket match's two
  /// entrants — the bridge from a tap on `TournamentDetailScreen` into the
  /// existing (non-tournament — [isTournamentFlow] stays false, this is
  /// scoring a match, not building a bracket) score-entry flow. The
  /// players/teams are fixed by the bracket rather than chosen by hand, so
  /// this jumps straight to the scores step (step 4 — "qui joue ?" would
  /// have nothing left to decide). See [saveGame]/[_recordTournamentResult]
  /// for how the result flows back onto the bracket once saved.
  void startTournamentMatch(Tournament tournament, BracketMatch match) {
    final entrantA = tournament.entrantById(match.entrantAId);
    final entrantB = tournament.entrantById(match.entrantBId);
    if (entrantA == null || entrantB == null) return;
    openSheet();
    if (currentGroupId != tournament.groupId) {
      currentGroupId = tournament.groupId;
      _resubscribeGroupData();
    }
    _activeTournamentId = tournament.id;
    _activeTournamentMatchId = match.id;
    pickGame(tournament.gameId);
    if (tournament.ruleId != null) pickRule(tournament.ruleId!);
    final isTeam = entrantA.playerIds.length > 1 || entrantB.playerIds.length > 1;
    draft.mode = isTeam ? 'team' : 'ffa';
    draft.teamCount = 2;
    draft.playerIds = [...entrantA.playerIds, ...entrantB.playerIds];
    if (isTeam) {
      draft.team = {
        for (final id in entrantA.playerIds) id: 'A',
        for (final id in entrantB.playerIds) id: 'B',
      };
    }
    draft.points = {for (final id in draft.playerIds) id: 0};
    draft.rankOrder = List.of(draft.playerIds);
    // Non-tournament-flow sheet (isTournamentFlow stays false — see class
    // doc above) scoring one bracket match: jump straight to its last step,
    // "scores".
    step = stepSequence.length;
    notifyListeners();
    unawaited(_startLiveSessionIfNeeded());
  }

  /// Opens the new-game sheet already answered "Tournoi" on step 1 — the
  /// entry point for the "+" in the home screen's "Tournois" section and
  /// `TournamentsListScreen`'s FAB, both of which already know the intent
  /// (no need to ask again). Lands on step 2 (the format step) rather than
  /// step 1.
  void startTournamentCreationFlow() {
    openSheet();
    draft.creationKind = 'tournament';
    step = 2;
    notifyListeners();
  }

  /// Advances the bracket once a tournament-linked match is saved (see
  /// [saveGame]/[startTournamentMatch]): resolves which entrant won from the
  /// real [GameMatch.winnerIds] result, then delegates the actual
  /// advance/loser-drop bookkeeping to [advanceResult].
  /// Returns a warning to fold into the caller's own save toast if the
  /// correction left part of the bracket stale (see [correctResult]) — null
  /// on a clean save, which is always the case the first time a match is
  /// recorded (only a correction can leave a stale downstream match).
  Future<String?> _recordTournamentResult(GameMatch saved) async {
    final root = currentRootId;
    final tournamentId = _activeTournamentId;
    final matchId = _activeTournamentMatchId;
    if (root == null || tournamentId == null || matchId == null) return null;
    final tournament = tournaments.where((t) => t.id == tournamentId).firstOrNull;
    final bracketMatch = tournament?.matchById(matchId);
    if (tournament == null || bracketMatch == null) return null;
    final entrantA = tournament.entrantById(bracketMatch.entrantAId);
    final entrantB = tournament.entrantById(bracketMatch.entrantBId);
    if (entrantA == null || entrantB == null) return null;
    final winnerIds = saved.winnerIds().toSet();
    final winnerEntrantId = entrantA.playerIds.any(winnerIds.contains) ? entrantA.id : entrantB.id;
    final result = correctResult(tournament, matchId: matchId, winnerEntrantId: winnerEntrantId, gameMatchId: saved.id);
    try {
      await tournamentsRepo.updateTournament(root, result.tournament);
    } catch (_) {
      // Best-effort — the match itself is already safely saved either way;
      // worst case the bracket just doesn't reflect this until a retry.
    }
    return result.staleMatchIds.isEmpty
        ? null
        : 'un tour déjà joué avec l\'ancien résultat n\'a pas pu être corrigé automatiquement — vérifiez le bracket';
  }

  /// For a [TournamentFormat.groupsThenElimination] tournament whose group
  /// stage is done (see [groupStageComplete]): ranks each group (see
  /// [computeGroupStandings]), takes [Tournament.qualifiersPerGroup] from
  /// each, and appends the elimination bracket built from them.
  Future<void> generateEliminationStage(Tournament tournament) async {
    final root = currentRootId;
    if (root == null || !groupStageComplete(tournament)) return;
    final qualifiers = [
      for (var g = 0; g < tournament.groupsCount; g++)
        computeGroupStandings(tournament: tournament, groupIndex: g, playedMatches: matches)
            .take(tournament.qualifiersPerGroup)
            .map((s) => s.entrantId)
            .toList(),
    ];
    final updated = tournament.copyWith(matches: [...tournament.matches, ...buildEliminationFromStandings(qualifiers)]);
    busy = true;
    notifyListeners();
    try {
      await tournamentsRepo.updateTournament(root, updated);
    } catch (e) {
      flowError = e.toString();
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
