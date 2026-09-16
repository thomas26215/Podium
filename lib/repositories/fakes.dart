import 'dart:async';

import '../models/app_user.dart';
import '../models/game.dart';
import '../models/group.dart';
import '../models/match.dart';
import '../models/salon.dart';
import '../models/scheduled_event.dart';
import '../models/server.dart';
import '../models/tournament.dart';
import 'auth_repository.dart';
import 'events_repository.dart';
import 'games_repository.dart';
import 'groups_repository.dart';
import 'matches_repository.dart';
import 'servers_repository.dart';
import 'tournaments_repository.dart';
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
  Future<void> sendPasswordResetEmail(String email) async {
    if (!email.contains('@')) throw AuthException('Adresse e-mail invalide.');
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
    return _controller.stream.map((all) => all.where((g) => g.memberIds.contains(uid)).toList());
  }

  @override
  Future<Group> createGroup({required String name, required String emoji, required int emojiBg, required String ownerId, bool temporary = false}) async {
    final id = 'g${groups.length + 1}';
    final group = Group(id: id, name: name, emoji: emoji, emojiBg: emojiBg, memberIds: [ownerId], ownerId: ownerId, temporary: temporary);
    groups[id] = group;
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
    groups.remove(groupId);
    _emit();
  }

  @override
  Future<void> joinGroup({required String groupId, required String uid}) async {
    final g = groups[groupId];
    if (g == null) throw InviteException('Groupe introuvable.');
    if (g.closed) throw InviteException('Ce groupe est clos et n\'accepte plus de nouveaux membres.');
    final expiresAt = g.inviteExpiresAt;
    if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
      throw InviteException("Ce code d'invitation a expiré — demandez-en un nouveau.");
    }
    if (!g.memberIds.contains(uid)) {
      groups[groupId] = g.copyWith(memberIds: [...g.memberIds, uid]);
    }
    _emit();
  }

  @override
  Future<void> deleteAllUserData(String uid) async {
    final owned = groups.values.where((g) => g.ownerId == uid).toList();
    for (final g in owned) {
      groups.remove(g.id);
    }
    for (final id in groups.keys.toList()) {
      final g = groups[id];
      if (g == null || g.ownerId == uid) continue;
      groups[id] = g.copyWith(memberIds: g.memberIds.where((m) => m != uid).toList());
    }
    _emit();
  }

  @override
  Future<void> reassignMember({required String groupId, required String oldUid, required String newUid}) async {
    final g = groups[groupId];
    if (g == null || !g.memberIds.contains(oldUid)) return;
    groups[groupId] = g.copyWith(memberIds: [...g.memberIds.where((m) => m != oldUid), newUid]);
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

class FakeServersRepository implements ServersRepository {
  final Map<String, Server> servers;
  final Map<String, Salon> salons;
  final UsersRepository users;
  final _serversController = StreamController<List<Server>>.broadcast();
  final _salonsControllers = <String, StreamController<List<Salon>>>{};

  FakeServersRepository({Map<String, Server>? seedServers, Map<String, Salon>? seedSalons, required this.users})
      : servers = seedServers ?? {},
        salons = seedSalons ?? {};

  void _emitServers() => _serversController.add(servers.values.toList());
  StreamController<List<Salon>> _salonsCtrl(String serverId) => _salonsControllers.putIfAbsent(serverId, () => StreamController.broadcast());
  void _emitSalons(String serverId) => _salonsCtrl(serverId).add(salons.values.where((s) => s.serverId == serverId).toList());

  @override
  Stream<List<Server>> watchMyServers(String uid) {
    Future.microtask(_emitServers);
    return _serversController.stream.map((all) => all.where((s) => s.memberIds.contains(uid)).toList());
  }

  @override
  Future<Server> createServer({required String name, required String emoji, required int emojiBg, required String ownerId}) async {
    final id = 'srv${servers.length + 1}';
    final server = Server(id: id, name: name, emoji: emoji, emojiBg: emojiBg, ownerId: ownerId, adminIds: const [], memberIds: [ownerId]);
    servers[id] = server;
    _emitServers();
    return server;
  }

  @override
  Future<void> addMemberByEmail({required String serverId, required String email}) async {
    final user = await users.getByEmail(email);
    if (user == null) throw InviteException('Aucun compte trouvé avec cet e-mail.');
    await addMemberId(serverId: serverId, memberId: user.uid);
  }

  @override
  Future<void> addMemberId({required String serverId, required String memberId}) async {
    final s = servers[serverId];
    if (s == null) return;
    if (!s.memberIds.contains(memberId)) {
      servers[serverId] = s.copyWith(memberIds: [...s.memberIds, memberId]);
      _emitServers();
    }
  }

  @override
  Future<void> setAdmin({required String serverId, required String uid, required bool admin}) async {
    final s = servers[serverId];
    if (s == null) return;
    servers[serverId] = s.copyWith(adminIds: admin ? [...s.adminIds, uid] : s.adminIds.where((a) => a != uid).toList());
    _emitServers();
  }

  @override
  Future<void> deleteServer(String serverId) async {
    servers.remove(serverId);
    salons.removeWhere((_, s) => s.serverId == serverId);
    _emitServers();
    _emitSalons(serverId);
  }

  @override
  Future<void> joinServer({required String serverId, required String uid}) async {
    final s = servers[serverId];
    if (s == null) throw InviteException('Serveur introuvable.');
    if (s.closed) throw InviteException("Ce serveur est clos et n'accepte plus de nouveaux membres.");
    if (!s.memberIds.contains(uid)) {
      servers[serverId] = s.copyWith(memberIds: [...s.memberIds, uid]);
      _emitServers();
    }
  }

  @override
  Future<void> setServerClosed({required String serverId, required bool closed}) async {
    final s = servers[serverId];
    if (s == null) return;
    servers[serverId] = s.copyWith(closed: closed, closedAt: closed ? DateTime.now() : null);
    _emitServers();
  }

  @override
  Future<void> refreshServerInviteWindow(String serverId) async {
    final s = servers[serverId];
    if (s == null) return;
    servers[serverId] = s.copyWith(inviteExpiresAt: DateTime.now().add(const Duration(minutes: 30)));
    _emitServers();
  }

  @override
  Stream<List<Salon>> watchSalons(String serverId) {
    Future.microtask(() => _emitSalons(serverId));
    return _salonsCtrl(serverId).stream;
  }

  @override
  Future<Salon> createSalon({required String serverId, required String name, required String emoji, required int emojiBg}) async {
    final id = 'sal${salons.length + 1}';
    final salon = Salon(id: id, serverId: serverId, name: name, emoji: emoji, emojiBg: emojiBg, memberIds: const []);
    salons[id] = salon;
    _emitSalons(serverId);
    return salon;
  }

  @override
  Future<void> addSalonMemberId({required String serverId, required String salonId, required String memberId}) async {
    final s = salons[salonId];
    if (s == null) return;
    if (!s.memberIds.contains(memberId)) {
      salons[salonId] = s.copyWith(memberIds: [...s.memberIds, memberId]);
      _emitSalons(serverId);
    }
  }

  @override
  Future<void> addSalonMemberByEmail({required String serverId, required String salonId, required String email}) async {
    final user = await users.getByEmail(email);
    if (user == null) throw InviteException('Aucun compte trouvé avec cet e-mail.');
    await addSalonMemberId(serverId: serverId, salonId: salonId, memberId: user.uid);
  }

  @override
  Future<void> deleteSalon({required String serverId, required String salonId}) async {
    salons.remove(salonId);
    _emitSalons(serverId);
  }

  @override
  Future<void> joinSalon({required String serverId, required String salonId, required String uid}) async {
    final salon = salons[salonId];
    if (salon == null) throw InviteException('Salon introuvable.');
    if (salon.closed) throw InviteException("Ce salon est clos et n'accepte plus de nouveaux membres.");
    if (!salon.memberIds.contains(uid)) {
      salons[salonId] = salon.copyWith(memberIds: [...salon.memberIds, uid]);
      _emitSalons(serverId);
    }
    await addMemberId(serverId: serverId, memberId: uid);
  }

  @override
  Future<void> setSalonClosed({required String serverId, required String salonId, required bool closed}) async {
    final s = salons[salonId];
    if (s == null) return;
    salons[salonId] = s.copyWith(closed: closed, closedAt: closed ? DateTime.now() : null);
    _emitSalons(serverId);
  }

  @override
  Future<void> refreshSalonInviteWindow({required String serverId, required String salonId}) async {
    final s = salons[salonId];
    if (s == null) return;
    salons[salonId] = s.copyWith(inviteExpiresAt: DateTime.now().add(const Duration(minutes: 30)));
    _emitSalons(serverId);
  }

  @override
  Future<void> deleteAllUserData(String uid) async {
    final owned = servers.values.where((s) => s.ownerId == uid).toList();
    for (final s in owned) {
      await deleteServer(s.id);
    }
    for (final id in servers.keys.toList()) {
      final s = servers[id];
      if (s == null || s.ownerId == uid) continue;
      servers[id] = s.copyWith(
        memberIds: s.memberIds.where((m) => m != uid).toList(),
        adminIds: s.adminIds.where((m) => m != uid).toList(),
      );
    }
    for (final id in salons.keys.toList()) {
      final s = salons[id];
      if (s == null || !s.memberIds.contains(uid)) continue;
      salons[id] = s.copyWith(memberIds: s.memberIds.where((m) => m != uid).toList());
    }
    _emitServers();
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
    required List<GameRule> rules,
    String? salonId,
  }) async {
    final list = byGroup.putIfAbsent(rootGroupId, () => []);
    final game = Game(
      id: 'game${list.length + 1}',
      name: name,
      emoji: emoji,
      category: category,
      rules: rules,
      salonId: salonId,
    );
    list.add(game);
    _ctrl(rootGroupId).add(list);
    return game;
  }

  @override
  Future<Game> importGame(String rootGroupId, Game source, {String? salonId}) async {
    final list = byGroup.putIfAbsent(rootGroupId, () => []);
    final game = Game(
      id: 'game${list.length + 1}',
      name: source.name,
      emoji: source.emoji,
      category: source.category,
      rules: source.rules,
      salonId: salonId,
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

  // Keyed by rootGroupId + groupIds + bySalon, not just rootGroupId — unlike
  // most other Fake*Repository broadcast controllers, a single root can be
  // watched under several different filters at once (e.g. a server's
  // several salons), and every write below needs to re-filter each of
  // those independently rather than pushing the same raw, unfiltered list
  // to whichever controller happens to be keyed by that root id.
  final _controllers = <String, StreamController<List<GameMatch>>>{};
  final _filters = <String, (String rootGroupId, List<String> groupIds, bool bySalon)>{};

  FakeMatchesRepository({Map<String, List<GameMatch>>? seed}) : byGroup = seed ?? {};

  String _key(String rootGroupId, List<String> groupIds, bool bySalon) => '$rootGroupId $bySalon ${groupIds.join(' ')}';

  StreamController<List<GameMatch>> _ctrl(String key) => _controllers.putIfAbsent(key, () => StreamController.broadcast());

  List<GameMatch> _filtered(String rootGroupId, List<String> groupIds, bool bySalon) {
    final all = byGroup[rootGroupId] ?? const [];
    return all.where((m) => groupIds.contains(bySalon ? m.salonId : m.groupId)).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Re-pushes freshly-filtered data to every live subscription watching
  /// `rootGroupId`, under whichever filter each one was created with.
  void _emitAll(String rootGroupId) {
    for (final entry in _filters.entries) {
      final (root, groupIds, bySalon) = entry.value;
      if (root != rootGroupId) continue;
      _ctrl(entry.key).add(_filtered(root, groupIds, bySalon));
    }
  }

  @override
  Stream<List<GameMatch>> watchMatches(String rootGroupId, List<String> groupIds, {bool bySalon = false}) {
    final key = _key(rootGroupId, groupIds, bySalon);
    _filters[key] = (rootGroupId, groupIds, bySalon);
    final c = _ctrl(key);
    Future.microtask(() => c.add(_filtered(rootGroupId, groupIds, bySalon)));
    return c.stream;
  }

  @override
  Future<int> countMatches(String rootGroupId, List<String> groupIds, {bool bySalon = false}) async {
    return _filtered(rootGroupId, groupIds, bySalon).length;
  }

  int _counter = 0;

  @override
  Future<GameMatch> addMatch(String rootGroupId, GameMatch match) async {
    final list = byGroup.putIfAbsent(rootGroupId, () => []);
    final saved = match.copyWithId('match${++_counter}');
    list.insert(0, saved);
    _emitAll(rootGroupId);
    return saved;
  }

  @override
  Future<void> updateMatch(String rootGroupId, GameMatch match) async {
    final list = byGroup.putIfAbsent(rootGroupId, () => []);
    final i = list.indexWhere((m) => m.id == match.id);
    if (i == -1) return;
    list[i] = match;
    _emitAll(rootGroupId);
  }

  @override
  Future<void> deleteMatch(String rootGroupId, String matchId) async {
    final list = byGroup[rootGroupId];
    if (list == null) return;
    list.removeWhere((m) => m.id == matchId);
    _emitAll(rootGroupId);
  }

  @override
  Future<void> confirmMatch({required String rootId, required String matchId, required String uid}) async {
    final list = byGroup[rootId];
    if (list == null) return;
    final i = list.indexWhere((m) => m.id == matchId);
    if (i == -1) return;
    final m = list[i];
    list[i] = m.copyWith(confirmedBy: [...?m.confirmedBy, uid]);
    _emitAll(rootId);
  }

  @override
  Future<void> rejectMatch({required String rootId, required String matchId, required String uid}) async {
    final list = byGroup[rootId];
    if (list == null) return;
    final i = list.indexWhere((m) => m.id == matchId);
    if (i == -1) return;
    list[i] = list[i].copyWith(rejectedBy: uid);
    _emitAll(rootId);
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
    _emitAll(rootGroupId);
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
    String? salonId,
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
      salonId: salonId,
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
  Stream<List<LiveMatchSession>> watchLiveSessions(String rootGroupId, List<String> groupIds, {bool bySalon = false}) {
    final c = _sessionCtrl(rootGroupId);
    Future.microtask(() {
      final all = liveSessionsByGroup[rootGroupId] ?? const [];
      c.add(all.where((s) => groupIds.contains(bySalon ? s.salonId : s.groupId)).toList());
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
      salonId: old.salonId,
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
      salonId: old.salonId,
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

class FakeTournamentsRepository implements TournamentsRepository {
  final Map<String, List<Tournament>> byGroup;
  final _controllers = <String, StreamController<List<Tournament>>>{};

  FakeTournamentsRepository({Map<String, List<Tournament>>? seed}) : byGroup = seed ?? {};

  StreamController<List<Tournament>> _ctrl(String id) => _controllers.putIfAbsent(id, () => StreamController.broadcast());

  @override
  Stream<List<Tournament>> watchTournaments(String rootGroupId, List<String> groupIds, {bool bySalon = false}) {
    final c = _ctrl(rootGroupId);
    Future.microtask(() {
      final all = byGroup[rootGroupId] ?? const [];
      c.add(all.where((t) => groupIds.contains(bySalon ? t.salonId : t.groupId)).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt)));
    });
    return c.stream;
  }

  int _counter = 0;

  @override
  Future<Tournament> addTournament(String rootGroupId, Tournament tournament) async {
    final list = byGroup.putIfAbsent(rootGroupId, () => []);
    final saved = Tournament.fromDoc('tournament${++_counter}', tournament.toMap());
    list.insert(0, saved);
    _ctrl(rootGroupId).add(list);
    return saved;
  }

  @override
  Future<void> updateTournament(String rootGroupId, Tournament tournament) async {
    final list = byGroup.putIfAbsent(rootGroupId, () => []);
    final i = list.indexWhere((t) => t.id == tournament.id);
    if (i == -1) return;
    list[i] = tournament;
    _ctrl(rootGroupId).add(list);
  }

  @override
  Future<void> deleteTournament(String rootGroupId, String tournamentId) async {
    final list = byGroup[rootGroupId];
    if (list == null) return;
    list.removeWhere((t) => t.id == tournamentId);
    _ctrl(rootGroupId).add(list);
  }
}

class FakeEventsRepository implements EventsRepository {
  final Map<String, List<ScheduledEvent>> byServer = {};
  final _controllers = <String, StreamController<List<ScheduledEvent>>>{};
  int _counter = 0;

  StreamController<List<ScheduledEvent>> _ctrl(String key) => _controllers.putIfAbsent(key, () => StreamController.broadcast());

  @override
  Stream<List<ScheduledEvent>> watchEvents(String serverId, String salonId) {
    final key = '$serverId $salonId';
    final c = _ctrl(key);
    Future.microtask(() {
      final all = byServer[serverId] ?? const [];
      final filtered = all.where((e) => e.salonId == salonId).toList()..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
      c.add(filtered);
    });
    return c.stream;
  }

  void _emitAll(String serverId) {
    final all = byServer[serverId] ?? const [];
    for (final key in _controllers.keys.where((k) => k.startsWith('$serverId '))) {
      final salonId = key.substring(serverId.length + 1);
      final filtered = all.where((e) => e.salonId == salonId).toList()..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
      _ctrl(key).add(filtered);
    }
  }

  @override
  Future<ScheduledEvent> addEvent(String serverId, ScheduledEvent event) async {
    final list = byServer.putIfAbsent(serverId, () => []);
    final saved = ScheduledEvent.fromDoc('event${++_counter}', event.toMap());
    list.add(saved);
    _emitAll(serverId);
    return saved;
  }

  @override
  Future<void> updateEvent(String serverId, ScheduledEvent event) async {
    final list = byServer.putIfAbsent(serverId, () => []);
    final i = list.indexWhere((e) => e.id == event.id);
    if (i == -1) return;
    list[i] = event;
    _emitAll(serverId);
  }

  @override
  Future<void> deleteEvent(String serverId, String eventId) async {
    final list = byServer[serverId];
    if (list == null) return;
    list.removeWhere((e) => e.id == eventId);
    _emitAll(serverId);
  }

  @override
  Future<void> register({required String serverId, required String eventId, required String uid}) async {
    final list = byServer[serverId];
    if (list == null) return;
    final i = list.indexWhere((e) => e.id == eventId);
    if (i == -1) return;
    if (list[i].signups.contains(uid)) return;
    list[i] = list[i].copyWith(signups: [...list[i].signups, uid]);
    _emitAll(serverId);
  }

  @override
  Future<void> unregister({required String serverId, required String eventId, required String uid}) async {
    final list = byServer[serverId];
    if (list == null) return;
    final i = list.indexWhere((e) => e.id == eventId);
    if (i == -1) return;
    list[i] = list[i].copyWith(signups: list[i].signups.where((id) => id != uid).toList());
    _emitAll(serverId);
  }
}
