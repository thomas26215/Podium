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
import '../models/match.dart';
import '../models/saved_account.dart';
import '../repositories/auth_repository.dart';
import '../repositories/game_library_repository.dart';
import '../repositories/games_repository.dart';
import '../repositories/groups_repository.dart';
import '../repositories/guests_repository.dart';
import '../repositories/matches_repository.dart';
import '../repositories/users_repository.dart';
import '../services/notifications_service.dart';
import '../theme/app_theme.dart';
import 'new_game_draft.dart';
import 'player_row.dart';

/// Which of the 5 tabs is showing.
enum AppTab { home, ranking, history, profile, groups }

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
  final UsersRepository usersRepo;
  final GuestsRepository guestsRepo;
  final GameLibraryRepository gameLibraryRepo;
  final NotificationsService? notificationsService;

  AppState({
    required this.authRepo,
    required this.groupsRepo,
    required this.gamesRepo,
    required this.matchesRepo,
    required this.usersRepo,
    required this.guestsRepo,
    required this.gameLibraryRepo,
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
  final Set<String> expandedGroups = {};

  // ---- games / matches (scoped to currentRootId) ----
  List<Game> games = [];
  List<GameMatch> matches = [];
  StreamSubscription? _gamesSub;
  StreamSubscription? _matchesSub;

  // ---- live sessions (matches currently being scored, scoped to currentRootId) ----
  List<LiveMatchSession> liveSessions = [];
  StreamSubscription? _liveSessionsSub;

  // Flips to true the moment each subscription's first snapshot arrives for
  // the current group — Firestore can take a moment after sign-in/switching
  // groups, so the UI shows "X/3 récupérées" in the meantime instead of
  // silently looking empty (see groupDataFetchedCount/groupDataFullyLoaded).
  bool gamesLoaded = false;
  bool matchesLoaded = false;
  bool liveSessionsLoaded = false;
  static const groupDataTotalCount = 3;
  int get groupDataFetchedCount => (gamesLoaded ? 1 : 0) + (matchesLoaded ? 1 : 0) + (liveSessionsLoaded ? 1 : 0);
  bool get groupDataFullyLoaded => groupDataFetchedCount == groupDataTotalCount;

  // A live session doc is considered abandoned (app crashed/killed mid-score
  // without a chance to clean up) once it hasn't been touched in this long —
  // hidden client-side rather than left showing "en cours" forever.
  static const _liveSessionStaleAfter = Duration(hours: 4);

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

  // ---- connectivity (drives whether the live session mirrors to Firebase) ----
  bool isOnline = true;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  // ---- local draft persistence (survives an app kill mid-match) ----
  static const _localDraftKey = 'local_draft_v1';
  // Forgiving compared to _liveSessionStaleAfter (4h) — this is only ever
  // shown to the one person who abandoned it, on their own device, so
  // there's little harm in still offering it the next day.
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
    _gamesSub?.cancel();
    _matchesSub?.cancel();
    _liveSessionsSub?.cancel();
    _currentUserSub?.cancel();
    groups = [];
    games = [];
    matches = [];
    liveSessions = [];
    friends = [];
    gamesLoaded = false;
    matchesLoaded = false;
    liveSessionsLoaded = false;
    currentGroupId = null;
    if (user != null) {
      _memberCache[user.uid] = user;
      profileId = user.uid;
      groupsLoading = true;
      unawaited(_rememberAccount(user));
      _groupsSub = groupsRepo.watchMyGroups(user.uid).listen(_onGroupsChanged);
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
      final roots = groups.where((g) => g.isRoot).toList();
      currentGroupId = roots.isNotEmpty ? roots.first.id : (groups.isNotEmpty ? groups.first.id : null);
    }
    unawaited(_ensureMembersLoaded());
    _resubscribeGroupData();
    unawaited(refreshGroupPartyCounts());
    notifyListeners();
  }

  Group? _findGroup(String id) {
    for (final g in groups) {
      if (g.id == id) return g;
    }
    return null;
  }

  Group? get currentGroup => currentGroupId == null ? null : _findGroup(currentGroupId!);

  Group? groupById(String id) => _findGroup(id);

  /// Walk up parentId chain to find the top-level community this group
  /// belongs to — that's the Firestore doc that owns the games/matches
  /// subcollections.
  String? get currentRootId {
    var g = currentGroup;
    final seen = <String>{};
    while (g != null && g.parentId != null && seen.add(g.id)) {
      g = _findGroup(g.parentId!);
    }
    return g?.id;
  }

  List<String> getAllGroupIds(String groupId) {
    final g = _findGroup(groupId);
    if (g == null) return [];
    final result = <String>[groupId];
    for (final sub in g.subGroupIds) {
      result.addAll(getAllGroupIds(sub));
    }
    return result;
  }

  /// A group's own roster plus everything layered in by its subgroups
  /// (recursively) — subgroups only store the *additional* players they
  /// bring, so this reconstructs the full effective roster.
  List<String> getGroupMemberIds(String groupId) {
    final g = _findGroup(groupId);
    if (g == null) return [];
    final ids = <String>{...g.memberIds};
    for (final sub in g.subGroupIds) {
      ids.addAll(getGroupMemberIds(sub));
    }
    return ids.toList();
  }

  // Per-group match tallies for the groups list (see GroupsScreen), keyed by
  // group id (root or subgroup). `matches` itself only ever holds the
  // CURRENTLY selected root's matches (see _resubscribeGroupData below) —
  // deliberately, to avoid pulling every group's whole history just because
  // it's rendered somewhere — so a screen listing every group the user
  // belongs to needs its own one-time tally instead of reusing `matches`.
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
    final roots = groups.where((g) => g.isRoot).toList();
    final futures = <Future<void>>[];
    for (final root in roots) {
      futures.add(_refreshOneGroupPartyCount(root.id, root.id, getAllGroupIds(root.id)));
      for (final subId in root.subGroupIds) {
        futures.add(_refreshOneGroupPartyCount(root.id, subId, [subId]));
      }
    }
    await Future.wait(futures);
    notifyListeners();
  }

  void _resubscribeGroupData() {
    final root = currentRootId;
    _gamesSub?.cancel();
    _matchesSub?.cancel();
    _liveSessionsSub?.cancel();
    gamesLoaded = false;
    matchesLoaded = false;
    liveSessionsLoaded = false;
    if (root == null) {
      games = [];
      matches = [];
      liveSessions = [];
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
    _liveSessionsSub = matchesRepo.watchLiveSessions(root, getAllGroupIds(root)).listen((ss) {
      liveSessionsLoaded = true;
      final now = DateTime.now();
      liveSessions = ss.where((s) => now.difference(s.updatedAt) < _liveSessionStaleAfter).toList();
      notifyListeners();
    });
  }

  Future<void> _ensureMembersLoaded() async {
    final allIds = <String>{};
    for (final g in groups) {
      allIds.addAll(g.memberIds);
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
    return ids.map((id) => _memberCache[id]).whereType<AppUser>().toList();
  }

  void selectGroup(String groupId) {
    currentGroupId = groupId;
    tab = AppTab.home;
    _resubscribeGroupData();
    notifyListeners();
  }

  void toggleGroupExpand(String groupId) {
    if (!expandedGroups.remove(groupId)) expandedGroups.add(groupId);
    notifyListeners();
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

  Future<void> createSubGroup({required String parentId, required String name, required String emoji, required int emojiBg}) async {
    final uid = currentUser?.uid;
    if (uid == null || name.trim().isEmpty) return;
    if (_rejectIfGroupClosed(parentId)) return;
    busy = true;
    flowError = null;
    notifyListeners();
    try {
      await groupsRepo.createSubGroup(parentId: parentId, name: name.trim(), emoji: emoji, emojiBg: emojiBg, ownerId: uid);
      expandedGroups.add(parentId);
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

  /// Whether `group` (root or subgroup) is currently closed — a subgroup's
  /// status always follows its root's, since subgroups don't carry their own
  /// [Group.closed] (only a root can be closed/reopened, see [setGroupClosed]).
  bool isGroupClosed(Group group) {
    if (group.isRoot) return group.closed;
    final parent = group.parentId != null ? groupById(group.parentId!) : null;
    return parent?.closed ?? false;
  }

  bool isGroupIdClosed(String groupId) {
    final g = groupById(groupId);
    return g != null && isGroupClosed(g);
  }

  bool get currentGroupClosed => currentGroup != null && isGroupClosed(currentGroup!);

  /// Only a root community's own owner can close/reopen it — mirrors
  /// [canManageGameCatalog] (same "who's in charge of the season" scope).
  bool canCloseGroup(Group group) {
    final uid = currentUser?.uid;
    if (uid == null || !group.isRoot) return false;
    return group.ownerId == uid;
  }

  /// Closes (or reopens) a ROOT group — see [Group.closed]. A closed group
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

  /// Whether the signed-in user is allowed to delete `group`: its own owner,
  /// or (for a subgroup) the owner of its root community.
  bool canDeleteGroup(Group group) {
    final uid = currentUser?.uid;
    if (uid == null) return false;
    if (group.ownerId == uid) return true;
    if (group.parentId != null) {
      final parent = groupById(group.parentId!);
      if (parent != null && parent.ownerId == uid) return true;
    }
    return false;
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

  /// Hands `oldUid`'s slot in `rootGroupId`'s whole tree over to whichever
  /// account `newEmail` belongs to: every group in the tree that lists
  /// `oldUid` as a member gets `newEmail`'s account instead, and every past
  /// match referencing `oldUid` is rewritten to reference the new account —
  /// e.g. someone was originally invited/scored under the wrong address.
  ///
  /// A guest (see [isGuestId]/[knownGuests]) is handled differently: since
  /// its whole point is being the same shared identity across every group
  /// it was added to, getting a real account replaces it everywhere it's a
  /// member — every root community visible to the caller, not just
  /// `rootGroupId` — instead of leaving disconnected guest copies behind in
  /// the others.
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
        await groupsRepo.reassignMember(rootId: rootGroupId, oldUid: oldUid, newUid: newUser.uid);
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
      final roots = groups.where((g) => g.isRoot && getGroupMemberIds(g.id).contains(oldUid)).toList();
      var touched = 0;
      var skippedClosed = 0;
      for (final root in roots) {
        if (isGroupClosed(root)) {
          skippedClosed++;
          continue;
        }
        if (getGroupMemberIds(root.id).contains(newUser.uid)) continue;
        await groupsRepo.reassignMember(rootId: root.id, oldUid: oldUid, newUid: newUser.uid);
        await matchesRepo.reassignPlayer(rootGroupId: root.id, oldPlayerId: oldUid, newPlayerId: newUser.uid);
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

  /// Whether the signed-in user can remove a game from the shared catalog
  /// — restricted to the root community's owner, since it also wipes every
  /// match ever recorded for that game anywhere in the tree.
  bool get canManageGameCatalog {
    final root = currentRootId;
    final uid = currentUser?.uid;
    if (root == null || uid == null) return false;
    return groupById(root)?.ownerId == uid;
  }

  Future<bool> deleteGame(String gameId) async {
    final root = currentRootId;
    if (root == null) return false;
    if (_rejectIfGroupClosed(root)) return false;
    if (variantsOf(gameId).isNotEmpty) {
      // Deleting the parent would silently orphan its variants (they'd keep
      // pointing at a gameId that no longer exists and vanish from the
      // picker, since they're not top-level) — require deleting the
      // variants first instead of guessing what the user wants.
      flowError = "Supprimez d'abord ses variantes avant de supprimer ce jeu.";
      notifyListeners();
      return false;
    }
    busy = true;
    flowError = null;
    notifyListeners();
    var ok = false;
    try {
      await gamesRepo.deleteGame(root, gameId);
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
    final root = currentRootId;
    if (root == null) return false;
    if (_rejectIfGroupClosed(root)) return false;
    busy = true;
    flowError = null;
    notifyListeners();
    var ok = false;
    try {
      await gamesRepo.updateGame(root, game.copyWith(ruleSections: sections));
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
      await groupsRepo.joinGroup(groupId: invite.groupId, rootId: invite.rootId, uid: uid);
      ok = true;
      selectGroup(invite.groupId);
      showToast('Vous avez rejoint ${invite.name}.');
    } catch (e) {
      flowError = "Impossible de rejoindre ce groupe (il n'existe peut-être plus).";
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

  /// Matches within the currently-viewed group's own subtree (not
  /// necessarily the whole root) — a drill-down into a subgroup only
  /// counts that subgroup and its descendants, matching the prototype's
  /// `getGroupMatches`.
  List<GameMatch> get viewMatches {
    if (currentGroupId == null) return const [];
    final ids = getAllGroupIds(currentGroupId!).toSet();
    return matches.where((m) => ids.contains(m.groupId)).toList();
  }

  List<String> get viewPlayerIds => currentGroupId == null ? const [] : getGroupMemberIds(currentGroupId!);

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

  /// Games shown as their own card in the picker grid — variants are
  /// grouped under their parent instead (see [variantsOf]).
  List<Game> get topLevelGames => games.where((g) => g.parentGameId == null).toList();

  List<Game> variantsOf(String gameId) => games.where((g) => g.parentGameId == gameId).toList();

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
    _liveSessionId = null;
    _draftHasProgress = false;
    _justSaved = false;
    notifyListeners();
  }

  /// Runs whenever the sheet closes, however it closed — save, back out
  /// through the steps, or the header's close button (see `showNewGameSheet`).
  /// A match left mid-score without being saved is kept as a resumable local
  /// draft (already backed up on disk by `_persistDraftLocally`) and offered
  /// right back on the home screen instead of only resurfacing at the next
  /// sign-in; anything else (saved, or never actually scored) clears it.
  void closeSheet() {
    sheetOpen = false;
    final root = currentRootId;
    final groupId = currentGroupId;
    if (!_justSaved && _editingMatchId == null && _draftHasProgress && root != null && groupId != null) {
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
    _liveSessionId = null; // resuming never starts/re-fires a live session

    final playerIds = match.entries.map((e) => e.playerId).toList();
    final team = <String, String>{for (final e in match.entries) e.playerId: e.teamId ?? 'A'};
    final points = <String, int>{for (final e in match.entries) e.playerId: e.points};
    final teamCount = team.values.toSet().length.clamp(2, 4);
    // Best-to-worst order, reconstructed from final scores — exact for
    // single-ranking ranks matches (points already encode rank order) and a
    // sane starting point for the next round otherwise.
    final rankOrder = [...playerIds]..sort((a, b) => (points[b] ?? 0).compareTo(points[a] ?? 0));

    // The match may have been recorded as round-synced under a game
    // definition that has since had "Manches multiples" turned off — the
    // input-mode picker wouldn't offer that option anymore, so fall back to
    // the closest still-available mode instead of leaving the UI stuck
    // showing a mode selector that doesn't match the rendered body.
    var inputMode = match.resolvedInputMode;
    if (inputMode == 'rounds' && !game.multiRound) {
      inputMode = 'quick';
    }

    draft = NewGameDraft(
      gameId: match.gameId,
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
    step = 3;
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
    draft = pending.draft;
    step = 3;
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
      // actually looking at — end it. Advancing back to step 3 starts a
      // fresh one via primaryAction/_startLiveSessionIfNeeded.
      if (step == 3) _endLiveSession();
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
      if (sheetOpen && step == 3 && _editingMatchId == null) {
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
    if (sheetOpen && step == 3) _holdLiveSession();
  }

  void startNewGame({String? parentGameId}) {
    creatingGame = true;
    _editingGameId = null;
    gameForm = GameFormDraft.initial(parentGameId: parentGameId);
    notifyListeners();
  }

  /// Opens the same form as [startNewGame], pre-filled with an existing
  /// game's settings — saving overwrites it in place instead of creating a
  /// new doc (see [createGame]).
  void startEditingGame(Game game) {
    creatingGame = true;
    _editingGameId = game.id;
    gameForm = GameFormDraft(
      name: game.name,
      emoji: game.emoji,
      category: game.category,
      countType: game.countType,
      pointLimit: game.pointLimit?.toString() ?? '',
      topRoles: (game.topRoles == null || game.topRoles!.isEmpty) ? null : List.of(game.topRoles!),
      bottomRoles: (game.bottomRoles == null || game.bottomRoles!.isEmpty) ? null : List.of(game.bottomRoles!),
      scoreFields: (game.scoreFields == null || game.scoreFields!.isEmpty) ? null : List.of(game.scoreFields!),
      multiRound: game.multiRound,
      parentGameId: game.parentGameId,
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
    final root = currentRootId;
    if (root == null) return;
    busy = true;
    flowError = null;
    notifyListeners();
    try {
      final game = await gamesRepo.importGame(root, libraryGame);
      draft.gameId = game.id;
      draft.unit = game.defaultUnit;
      draft.inputMode = 'quick';
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
      final otherRoots = groups.where((g) => g.isRoot && g.id != currentRoot).toList();
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
      draft.gameId = game.id;
      draft.unit = game.defaultUnit;
      draft.inputMode = 'quick';
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

  Future<void> createGame() async {
    final root = currentRootId;
    if (root == null || !gameForm.isValid) return;
    if (_rejectIfGroupClosed(root)) return;
    busy = true;
    flowError = null;
    notifyListeners();
    try {
      final isRanks = gameForm.countType == CountType.ranks;
      final isPointGame = gameForm.countType == CountType.highWins || gameForm.countType == CountType.lowWins;
      // No numeric score at all for a rounds-won tally, a ranks-based
      // classement, or a plain win/loss mark — a point limit only makes
      // sense when there's actually a running point total.
      final noPointLimit = gameForm.countType == CountType.wins || isRanks || gameForm.countType == CountType.winLoss;
      final scoreFields = isPointGame
          ? gameForm.scoreFields.where((field) => field.label.trim().isNotEmpty).map((field) => field.copyWith(label: field.label.trim())).toList()
          : null;
      final multiRound = scoreFields != null && scoreFields.isNotEmpty ? false : gameForm.multiRound;
      final Game game;
      if (_editingGameId != null) {
        game = Game(
          id: _editingGameId!,
          name: gameForm.name.trim(),
          emoji: gameForm.emoji,
          category: gameForm.category,
          countType: gameForm.countType,
          pointLimit: noPointLimit ? null : gameForm.parsedPointLimit,
          topRoles: isRanks ? gameForm.cleanTopRoles : null,
          bottomRoles: isRanks ? gameForm.cleanBottomRoles : null,
          topPoints: isRanks ? gameForm.derivedTopPoints : null,
          bottomPoints: isRanks ? gameForm.derivedBottomPoints : null,
          multiRound: multiRound,
          parentGameId: gameForm.parentGameId,
          scoreFields: scoreFields,
        );
        await gamesRepo.updateGame(root, game);
        showToast('Jeu mis à jour.');
        _editingGameId = null;
      } else {
        game = await gamesRepo.createGame(
          root,
          name: gameForm.name.trim(),
          emoji: gameForm.emoji,
          category: gameForm.category,
          countType: gameForm.countType,
          pointLimit: noPointLimit ? null : gameForm.parsedPointLimit,
          topRoles: isRanks ? gameForm.cleanTopRoles : null,
          bottomRoles: isRanks ? gameForm.cleanBottomRoles : null,
          topPoints: isRanks ? gameForm.derivedTopPoints : null,
          bottomPoints: isRanks ? gameForm.derivedBottomPoints : null,
          multiRound: multiRound,
          parentGameId: gameForm.parentGameId,
          scoreFields: scoreFields,
        );
      }
      draft.gameId = game.id;
      draft.unit = game.defaultUnit;
      draft.inputMode = 'quick';
      _syncDetailedScores();
      creatingGame = false;
    } catch (e) {
      flowError = e.toString();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  void pickGame(String id) {
    final g = gameById(id);
    draft.gameId = id;
    draft.unit = g?.defaultUnit ?? 'points';
    // Reset the input mode so a stale 'rounds' choice from a previous
    // multi-round game selection can't leak into a game that doesn't
    // support it (its option wouldn't even be shown).
    draft.inputMode = 'quick';
    // Ranks and win/loss games are always solo scoring — force it so a
    // stale 'team' choice from a previously-picked game can't leak in
    // (their step-2 UI never shows the mode/team pickers to change it back).
    if (g != null && (g.isRanks || g.isWinLoss)) draft.mode = 'ffa';
    draft.scoreBreakdown.clear();
    _syncDetailedScores();
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
    final game = gameById(draft.gameId ?? '');
    if (game != null && u != game.defaultUnit) return;
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
      final g = gameById(draft.gameId ?? '');
      if (g != null && g.hasScoreFields) {
        draft.scoreBreakdown[uid] = {for (final field in g.scoreFields!) field.id: 0};
      }
    }
    notifyListeners();
  }

  List<GameScoreField> get draftScoreFields => gameById(draft.gameId ?? '')?.scoreFields ?? const [];

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
    scores[fieldId] = value;
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
      final v = ((draft.points[uid] ?? 0) + delta).clamp(0, 1 << 30);
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
  /// into per-player points via [Game.rankPoints] and accumulates them
  /// through [addRound], exactly like the plain "rounds" points mode.
  void submitRankRound() {
    final game = gameById(draft.gameId ?? '');
    if (game == null || draft.rankOrder.isEmpty) return;
    final deltas = <String, int>{
      for (final (i, uid) in draft.rankOrder.indexed) uid: game.rankPoints(i, draft.rankOrder.length),
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
    final low = draft.unit == 'wins' ? false : (gameById(draft.gameId ?? '')?.lowWins ?? false);
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

  bool get canProceed {
    if (browsingLibrary || browsingOtherGroups) return false;
    if (creatingGame) return gameForm.isValid;
    if (step == 1) return draft.gameId != null;
    if (step == 2) return draft.playerIds.length >= 2 && draftTeamsValid;
    if (step == 3) {
      final g = gameById(draft.gameId ?? '');
      // Both a CountType.winLoss game and the generic "Manches gagnées"
      // unit share the same round-by-round "one winner per manche" input
      // (see _WinLossRoundsInput) and the same guard against saving a
      // nonsensical all-zero tally.
      if (g?.isWinLoss == true || draft.unit == 'wins') {
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
    }
    return true;
  }

  Future<void> primaryAction() async {
    if (creatingGame) {
      await createGame();
      return;
    }
    if (step == 3) {
      await saveGame();
      return;
    }
    step += 1;
    if (step == 3) unawaited(_startLiveSessionIfNeeded());
    notifyListeners();
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
    if (_editingMatchId != null || _liveSessionId != null || !isOnline) return;
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
        lowWins: gameById(gameId)?.lowWins ?? false,
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
      if (sheetOpen && step == 3 && _editingMatchId == null && _liveSessionId == null) {
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
  /// since that's already durably stored in Firestore.
  Future<void> _persistDraftLocally() async {
    final uid = currentUser?.uid;
    final root = currentRootId;
    final groupId = currentGroupId;
    if (uid == null || root == null || groupId == null || draft.gameId == null || _editingMatchId != null) return;
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
  /// unfinished match) and drops ones stale enough nobody would recognize
  /// them anymore.
  Future<void> _loadPendingLocalDraft(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_localDraftKey);
      if (raw == null) return;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['uid'] != uid) return;
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
    final g = gameById(draft.gameId ?? '');
    if (g?.isRanks == true && draft.inputMode == 'rounds') {
      return [for (final id in draft.playerIds) MatchEntry(playerId: id, points: draft.points[id] ?? 0)];
    }
    if (g?.isRanks == true) {
      return [
        for (final (i, id) in draft.rankOrder.indexed)
          MatchEntry(playerId: id, points: g!.rankPoints(i, draft.rankOrder.length), role: g.rankRole(i, draft.rankOrder.length)),
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
    final root = currentRootId;
    final groupId = currentGroupId;
    if (root == null || groupId == null || draft.gameId == null) return;
    if (_rejectIfGroupClosed(groupId)) return;
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
    final g = gameById(draft.gameId!);
    final entries = _currentDraftEntries();
    final now = DateTime.now();
    // Backdated (draft.playedAt set) keeps that calendar day but still uses
    // the actual save time-of-day, so multiple matches recorded under the
    // same backdated day still order sensibly; otherwise just "now".
    final playedAt = draft.playedAt;
    final createdAt = _editingMatchCreatedAt ??
        (playedAt == null ? now : DateTime(playedAt.year, playedAt.month, playedAt.day, now.hour, now.minute, now.second, now.millisecond));
    final match = GameMatch(
      id: _editingMatchId ?? '', // assigned by the repository when creating
      gameId: draft.gameId!,
      groupId: groupId,
      mode: draft.mode,
      unit: draft.unit,
      lowWins: (g?.isRanks == true || g?.isWinLoss == true) ? false : (draft.unit == 'wins' ? false : (g?.lowWins ?? false)),
      entries: entries,
      timeline: draft.timeline,
      createdAt: createdAt,
      scoreFields: g?.scoreFields,
      inputMode: draft.inputMode,
      createdByUid: currentUser?.uid,
      seriesId: _editingMatchId != null ? _editingMatchSeriesId : (isNewSeries ? draft.seriesId : null),
      seriesGame: _editingMatchId != null ? _editingMatchSeriesGame : (isNewSeries ? draft.seriesLegIndex : null),
      seriesLength: _editingMatchId != null ? _editingMatchSeriesLength : (isNewSeries ? draft.bestOf : null),
    );
    try {
      if (_editingMatchId != null) {
        await matchesRepo.updateMatch(root, match);
        showToast('Partie mise à jour ! Classement mis à jour.');
      } else {
        await matchesRepo.addMatch(root, match);
        if (isNewSeries && !isFinalLeg) {
          showToast('Partie ${draft.seriesLegIndex} enregistrée — gagnée par ${legWinnerLabel(match)}. Partie suivante !');
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

  /// Whether the signed-in user can delete `match`: the root community's
  /// owner, or (mirrors [canDeleteGroup]) the owner of the specific
  /// subgroup it was recorded in.
  bool canDeleteMatch(GameMatch match) {
    final uid = currentUser?.uid;
    if (uid == null) return false;
    final root = currentRootId;
    if (root != null && groupById(root)?.ownerId == uid) return true;
    return groupById(match.groupId)?.ownerId == uid;
  }

  /// Permanently deletes a single recorded match — one leg of a "best of N"
  /// series, or a standalone match. See [deleteMatchSeries] to remove every
  /// leg of a series at once.
  Future<bool> deleteMatch(GameMatch match) async {
    final root = currentRootId;
    if (root == null || !canDeleteMatch(match)) return false;
    busy = true;
    flowError = null;
    notifyListeners();
    var ok = false;
    try {
      await matchesRepo.deleteMatch(root, match.id);
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
    final root = currentRootId;
    if (root == null || !canDeleteMatch(legs.first)) return false;
    busy = true;
    flowError = null;
    notifyListeners();
    var ok = false;
    try {
      for (final leg in legs) {
        await matchesRepo.deleteMatch(root, leg.id);
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
}
