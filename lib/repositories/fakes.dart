import 'dart:async';

import '../models/app_user.dart';
import '../models/game.dart';
import '../models/group.dart';
import '../models/match.dart';
import 'auth_repository.dart';
import 'games_repository.dart';
import 'groups_repository.dart';
import 'matches_repository.dart';
import 'users_repository.dart';

/// In-memory stand-ins for the Firebase-backed repositories, used by widget
/// tests and local previews so the UI can be exercised without a live
/// Firebase project.
class FakeAuthRepository implements AuthRepository {
  final Map<String, String> _passwords = {};
  final Map<String, AppUser> users;
  final _controller = StreamController<AppUser?>.broadcast();
  AppUser? _current;

  FakeAuthRepository({Map<String, AppUser>? seedUsers}) : users = seedUsers ?? {};

  @override
  AppUser? get currentUser => _current;

  @override
  Stream<AppUser?> authStateChanges() async* {
    // Mirrors FirebaseAuth.authStateChanges(), which replays the current
    // session to a fresh listener instead of only emitting on the next
    // change — AppState's single subscription relies on that.
    yield _current;
    yield* _controller.stream;
  }

  @override
  Future<AppUser> signIn({required String email, required String password}) async {
    final match = users.values.where((u) => u.email == email.trim().toLowerCase());
    if (match.isEmpty || _passwords[email.trim().toLowerCase()] != password) {
      throw AuthException('E-mail ou mot de passe incorrect.');
    }
    _current = match.first;
    _controller.add(_current);
    return _current!;
  }

  @override
  Future<AppUser> signUp({required String email, required String password, required String displayName}) async {
    final key = email.trim().toLowerCase();
    if (users.values.any((u) => u.email == key)) {
      throw AuthException('Un compte existe déjà avec cet e-mail.');
    }
    final uid = 'u${users.length + 1}';
    final user = AppUser(uid: uid, email: key, displayName: displayName, color: colorForUid(uid));
    users[uid] = user;
    _passwords[key] = password;
    _current = user;
    _controller.add(_current);
    return user;
  }

  @override
  Future<void> signOut() async {
    _current = null;
    _controller.add(null);
  }

  @override
  Future<void> reauthenticate(String password) async {
    final current = _current;
    if (current == null) throw AuthException('Aucun utilisateur connecté.');
    if (_passwords[current.email] != password) {
      throw AuthException('E-mail ou mot de passe incorrect.');
    }
  }

  @override
  Future<void> deleteAccount() async {
    final current = _current;
    if (current == null) throw AuthException('Aucun utilisateur connecté.');
    users.remove(current.uid);
    _passwords.remove(current.email);
    _current = null;
    _controller.add(null);
  }

  /// Test-only helper: jump straight to "signed in as this user" without
  /// going through the signup/signin form, for widget tests that seed a
  /// specific uid (so it lines up with pre-seeded groups/matches).
  void debugSignIn(AppUser user) {
    users[user.uid] = user;
    _current = user;
    _controller.add(user);
  }
}

class FakeGroupsRepository implements GroupsRepository {
  final Map<String, Group> groups;
  final UsersRepository users;
  final _controller = StreamController<List<Group>>.broadcast();

  FakeGroupsRepository({Map<String, Group>? seedGroups, required this.users}) : groups = seedGroups ?? {};

  void _emit() => _controller.add(groups.values.toList());

  @override
  Stream<List<Group>> watchMyGroups(String uid) {
    Future.microtask(_emit);
    return _controller.stream.map((all) => all.where((g) => _visibleTo(g, uid, all)).toList());
  }

  bool _visibleTo(Group g, String uid, List<Group> all) {
    if (g.memberIds.contains(uid)) return true;
    if (g.isRoot) {
      return g.subGroupIds.any((sid) {
        final sg = all.where((x) => x.id == sid);
        return sg.isNotEmpty && sg.first.memberIds.contains(uid);
      });
    }
    final parent = all.where((x) => x.id == g.parentId);
    return parent.isNotEmpty && parent.first.memberIds.contains(uid);
  }

  @override
  Future<Group> createGroup({required String name, required String emoji, required int emojiBg, required String ownerId, bool temporary = false}) async {
    final id = 'g${groups.length + 1}';
    final group = Group(id: id, name: name, emoji: emoji, emojiBg: emojiBg, parentId: null, memberIds: [ownerId], subGroupIds: const [], allMemberIds: [ownerId], ownerId: ownerId, temporary: temporary);
    groups[id] = group;
    _emit();
    return group;
  }

  @override
  Future<Group> createSubGroup({required String parentId, required String name, required String emoji, required int emojiBg, required String ownerId}) async {
    final id = 'g${groups.length + 1}';
    final group = Group(id: id, name: name, emoji: emoji, emojiBg: emojiBg, parentId: parentId, memberIds: [ownerId], subGroupIds: const [], allMemberIds: const [], ownerId: ownerId);
    groups[id] = group;
    final parent = groups[parentId];
    if (parent != null) {
      groups[parentId] = parent.copyWith(subGroupIds: [...parent.subGroupIds, id], allMemberIds: [...parent.allMemberIds, ownerId]);
    }
    _emit();
    return group;
  }

  @override
  Future<void> addMemberByEmail({required String groupId, required String email}) async {
    final user = await users.getByEmail(email);
    if (user == null) throw InviteException('Aucun compte trouvé avec cet e-mail.');
    await addMemberId(groupId: groupId, memberId: user.uid);
  }

  @override
  Future<void> addMemberId({required String groupId, required String memberId}) async {
    final g = groups[groupId];
    if (g == null) return;
    if (!g.memberIds.contains(memberId)) {
      groups[groupId] = g.copyWith(memberIds: [...g.memberIds, memberId]);
      _emit();
    }
  }

  @override
  Future<void> deleteGroup(String groupId) async {
    final g = groups[groupId];
    if (g == null) return;
    if (g.isRoot) {
      for (final subId in g.subGroupIds) {
        groups.remove(subId);
      }
      groups.remove(groupId);
    } else {
      groups.remove(groupId);
      final parent = g.parentId != null ? groups[g.parentId] : null;
      if (parent != null) {
        final remainingSubIds = parent.subGroupIds.where((id) => id != groupId).toList();
        final allMemberIds = <String>{
          ...parent.memberIds,
          for (final sid in remainingSubIds) ...?groups[sid]?.memberIds,
        };
        groups[parent.id] = parent.copyWith(subGroupIds: remainingSubIds, allMemberIds: allMemberIds.toList());
      }
    }
    _emit();
  }

  @override
  Future<void> joinGroup({required String groupId, required String rootId, required String uid}) async {
    final root0 = groups[rootId];
    if (root0 == null) throw InviteException('Groupe introuvable.');
    if (root0.closed) throw InviteException('Ce groupe est clos et n\'accepte plus de nouveaux membres.');
    final g = groups[groupId];
    if (g == null) return;
    final expiresAt = g.inviteExpiresAt;
    if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
      throw InviteException("Ce code d'invitation a expiré — demandez-en un nouveau.");
    }
    if (!g.memberIds.contains(uid)) {
      groups[groupId] = g.copyWith(memberIds: [...g.memberIds, uid]);
    }
    final root = groups[rootId];
    if (root != null && !root.allMemberIds.contains(uid)) {
      groups[rootId] = root.copyWith(allMemberIds: [...root.allMemberIds, uid]);
    }
    _emit();
  }

  @override
  Future<void> deleteAllUserData(String uid) async {
    final owned = groups.values.where((g) => g.ownerId == uid).toList();
    for (final g in owned) {
      if (!groups.containsKey(g.id)) continue;
      await deleteGroup(g.id);
    }
    for (final id in groups.keys.toList()) {
      final g = groups[id];
      if (g == null || g.ownerId == uid) continue;
      groups[id] = g.copyWith(
        memberIds: g.memberIds.where((m) => m != uid).toList(),
        allMemberIds: g.allMemberIds.where((m) => m != uid).toList(),
      );
    }
    _emit();
  }

  @override
  Future<void> reassignMember({required String rootId, required String oldUid, required String newUid}) async {
    final root = groups[rootId];
    if (root == null) return;
    for (final id in [rootId, ...root.subGroupIds]) {
      final g = groups[id];
      if (g == null || !g.memberIds.contains(oldUid)) continue;
      groups[id] = g.copyWith(memberIds: [...g.memberIds.where((m) => m != oldUid), newUid]);
    }
    final refreshedRoot = groups[rootId];
    if (refreshedRoot != null) {
      final allIds = <String>{
        ...refreshedRoot.memberIds,
        for (final sid in refreshedRoot.subGroupIds) ...?groups[sid]?.memberIds,
      };
      groups[rootId] = refreshedRoot.copyWith(allMemberIds: allIds.toList());
    }
    _emit();
  }

  @override
  Future<void> setGroupClosed({required String groupId, required bool closed}) async {
    final g = groups[groupId];
    if (g == null) return;
    groups[groupId] = g.copyWith(closed: closed, closedAt: closed ? DateTime.now() : null);
    _emit();
  }

  @override
  Future<void> refreshInviteWindow(String groupId) async {
    final g = groups[groupId];
    if (g == null) return;
    groups[groupId] = g.copyWith(inviteExpiresAt: DateTime.now().add(const Duration(minutes: 30)));
    _emit();
  }
}

class FakeGamesRepository implements GamesRepository {
  final Map<String, List<Game>> byGroup;
  final _controllers = <String, StreamController<List<Game>>>{};

  FakeGamesRepository({Map<String, List<Game>>? seed}) : byGroup = seed ?? {};

  StreamController<List<Game>> _ctrl(String id) => _controllers.putIfAbsent(id, () => StreamController.broadcast());

  @override
  Stream<List<Game>> watchGames(String rootGroupId) {
    final c = _ctrl(rootGroupId);
    Future.microtask(() => c.add(byGroup[rootGroupId] ?? const []));
    return c.stream;
  }

  @override
  Future<List<Game>> fetchGames(String rootGroupId) async => List.of(byGroup[rootGroupId] ?? const []);

  @override
  Future<Game> createGame(
    String rootGroupId, {
    required String name,
    required String emoji,
    required String category,
    required CountType countType,
    int? pointLimit,
    List<String>? topRoles,
    List<String>? bottomRoles,
    List<int>? topPoints,
    List<int>? bottomPoints,
    bool multiRound = false,
    String? parentGameId,
    List<GameScoreField>? scoreFields,
  }) async {
    final list = byGroup.putIfAbsent(rootGroupId, () => []);
    final game = Game(
      id: 'game${list.length + 1}',
      name: name,
      emoji: emoji,
      category: category,
      countType: countType,
      pointLimit: pointLimit,
      topRoles: topRoles,
      bottomRoles: bottomRoles,
      topPoints: topPoints,
      bottomPoints: bottomPoints,
      multiRound: multiRound,
      parentGameId: parentGameId,
      scoreFields: scoreFields,
    );
    list.add(game);
    _ctrl(rootGroupId).add(list);
    return game;
  }

  @override
  Future<Game> importGame(String rootGroupId, Game source) async {
    final list = byGroup.putIfAbsent(rootGroupId, () => []);
    final game = Game(
      id: 'game${list.length + 1}',
      name: source.name,
      emoji: source.emoji,
      category: source.category,
      countType: source.countType,
      pointLimit: source.pointLimit,
      topRoles: source.topRoles,
      bottomRoles: source.bottomRoles,
      topPoints: source.topPoints,
      bottomPoints: source.bottomPoints,
      multiRound: source.multiRound,
      scoreFields: source.scoreFields,
    );
    list.add(game);
    _ctrl(rootGroupId).add(list);
    return game;
  }

  @override
  Future<void> updateGame(String rootGroupId, Game game) async {
    final list = byGroup.putIfAbsent(rootGroupId, () => []);
    final i = list.indexWhere((g) => g.id == game.id);
    if (i == -1) return;
    list[i] = game;
    _ctrl(rootGroupId).add(list);
  }

  @override
  Future<void> seedDefaultCatalog(String rootGroupId) async {
    byGroup[rootGroupId] = List.of(kDefaultGames);
    _ctrl(rootGroupId).add(byGroup[rootGroupId]!);
  }

  @override
  Future<void> deleteGame(String rootGroupId, String gameId) async {
    final list = byGroup[rootGroupId];
    if (list == null) return;
    list.removeWhere((g) => g.id == gameId);
    _ctrl(rootGroupId).add(list);
  }
}

class FakeMatchesRepository implements MatchesRepository {
  final Map<String, List<GameMatch>> byGroup;
  final _controllers = <String, StreamController<List<GameMatch>>>{};

  FakeMatchesRepository({Map<String, List<GameMatch>>? seed}) : byGroup = seed ?? {};

  StreamController<List<GameMatch>> _ctrl(String id) => _controllers.putIfAbsent(id, () => StreamController.broadcast());

  @override
  Stream<List<GameMatch>> watchMatches(String rootGroupId, List<String> groupIds) {
    final c = _ctrl(rootGroupId);
    Future.microtask(() {
      final all = byGroup[rootGroupId] ?? const [];
      c.add(all.where((m) => groupIds.contains(m.groupId)).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt)));
    });
    return c.stream;
  }

  @override
  Future<int> countMatches(String rootGroupId, List<String> groupIds) async {
    final all = byGroup[rootGroupId] ?? const [];
    return all.where((m) => groupIds.contains(m.groupId)).length;
  }

  int _counter = 0;

  @override
  Future<GameMatch> addMatch(String rootGroupId, GameMatch match) async {
    final list = byGroup.putIfAbsent(rootGroupId, () => []);
    final saved = match.copyWithId('match${++_counter}');
    list.insert(0, saved);
    _ctrl(rootGroupId).add(list);
    return saved;
  }

  @override
  Future<void> updateMatch(String rootGroupId, GameMatch match) async {
    final list = byGroup.putIfAbsent(rootGroupId, () => []);
    final i = list.indexWhere((m) => m.id == match.id);
    if (i == -1) return;
    list[i] = match;
    _ctrl(rootGroupId).add(list);
  }

  @override
  Future<void> deleteMatch(String rootGroupId, String matchId) async {
    final list = byGroup[rootGroupId];
    if (list == null) return;
    list.removeWhere((m) => m.id == matchId);
    _ctrl(rootGroupId).add(list);
  }

  @override
  Future<void> reassignPlayer({required String rootGroupId, required String oldPlayerId, required String newPlayerId}) async {
    final list = byGroup[rootGroupId];
    if (list == null) return;
    for (var i = 0; i < list.length; i++) {
      final m = list[i];
      if (!m.entries.any((e) => e.playerId == oldPlayerId) && !m.timeline.any((t) => t.playerId == oldPlayerId)) continue;
      list[i] = GameMatch(
        id: m.id,
        gameId: m.gameId,
        groupId: m.groupId,
        mode: m.mode,
        unit: m.unit,
        lowWins: m.lowWins,
        entries: m.entries.map((e) => e.playerId == oldPlayerId ? MatchEntry(playerId: newPlayerId, points: e.points, teamId: e.teamId, role: e.role) : e).toList(),
        timeline: m.timeline.map((t) => t.playerId == oldPlayerId ? TimelinePoint(playerId: newPlayerId, val: t.val, delta: t.delta, time: t.time) : t).toList(),
        createdAt: m.createdAt,
        inputMode: m.inputMode,
        createdByUid: m.createdByUid,
      );
    }
    _ctrl(rootGroupId).add(list);
  }

  final List<Map<String, String>> announcedStarts = [];
  final Map<String, List<LiveMatchSession>> liveSessionsByGroup = {};
  final _sessionControllers = <String, StreamController<List<LiveMatchSession>>>{};
  int _sessionCounter = 0;

  StreamController<List<LiveMatchSession>> _sessionCtrl(String id) =>
      _sessionControllers.putIfAbsent(id, () => StreamController.broadcast());

  @override
  Future<String> startLiveSession({
    required String rootGroupId,
    required String groupId,
    required String gameId,
    required String startedByUid,
    required String startedByName,
    required String mode,
    required String unit,
    required bool lowWins,
  }) async {
    announcedStarts.add({'rootGroupId': rootGroupId, 'groupId': groupId, 'gameId': gameId, 'startedByUid': startedByUid, 'startedByName': startedByName});
    final now = DateTime.now();
    final session = LiveMatchSession(
      id: 'session${++_sessionCounter}',
      gameId: gameId,
      groupId: groupId,
      startedByUid: startedByUid,
      startedByName: startedByName,
      mode: mode,
      unit: unit,
      lowWins: lowWins,
      entries: const [],
      timeline: const [],
      createdAt: now,
      updatedAt: now,
    );
    final list = liveSessionsByGroup.putIfAbsent(rootGroupId, () => []);
    list.insert(0, session);
    _sessionCtrl(rootGroupId).add(list);
    return session.id;
  }

  @override
  Stream<List<LiveMatchSession>> watchLiveSessions(String rootGroupId, List<String> groupIds) {
    final c = _sessionCtrl(rootGroupId);
    Future.microtask(() {
      final all = liveSessionsByGroup[rootGroupId] ?? const [];
      c.add(all.where((s) => groupIds.contains(s.groupId)).toList());
    });
    return c.stream;
  }

  @override
  Future<void> updateLiveSession({
    required String rootGroupId,
    required String sessionId,
    required List<MatchEntry> entries,
    required List<TimelinePoint> timeline,
    String? inputMode,
    bool held = false,
  }) async {
    final list = liveSessionsByGroup[rootGroupId];
    if (list == null) return;
    final i = list.indexWhere((s) => s.id == sessionId);
    if (i == -1) return;
    final old = list[i];
    list[i] = LiveMatchSession(
      id: old.id,
      gameId: old.gameId,
      groupId: old.groupId,
      startedByUid: old.startedByUid,
      startedByName: old.startedByName,
      mode: old.mode,
      unit: old.unit,
      lowWins: old.lowWins,
      entries: entries,
      timeline: timeline,
      inputMode: inputMode ?? old.inputMode,
      held: held,
      createdAt: old.createdAt,
      updatedAt: DateTime.now(),
    );
    _sessionCtrl(rootGroupId).add(list);
  }

  @override
  Future<void> endLiveSession({required String rootGroupId, required String sessionId}) async {
    final list = liveSessionsByGroup[rootGroupId];
    if (list == null) return;
    list.removeWhere((s) => s.id == sessionId);
    _sessionCtrl(rootGroupId).add(list);
  }

  @override
  Future<void> setLiveSessionHeld({required String rootGroupId, required String sessionId, required bool held}) async {
    final list = liveSessionsByGroup[rootGroupId];
    if (list == null) return;
    final i = list.indexWhere((s) => s.id == sessionId);
    if (i == -1) return;
    final old = list[i];
    list[i] = LiveMatchSession(
      id: old.id,
      gameId: old.gameId,
      groupId: old.groupId,
      startedByUid: old.startedByUid,
      startedByName: old.startedByName,
      mode: old.mode,
      unit: old.unit,
      lowWins: old.lowWins,
      entries: old.entries,
      timeline: old.timeline,
      inputMode: old.inputMode,
      held: held,
      createdAt: old.createdAt,
      updatedAt: old.updatedAt,
    );
    _sessionCtrl(rootGroupId).add(list);
  }
}
