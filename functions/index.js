const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { getAuth } = require("firebase-admin/auth");
const { onDocumentCreated, onDocumentUpdated, onDocumentWritten } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions");
const { isDeepStrictEqual } = require("node:util");

initializeApp();

const db = getFirestore();
const messaging = getMessaging();

/** Which uid each FCM token was read from (see tokensFor) — lets sendToTokens prune a stale token straight from its owner's doc. */
const tokenOwners = new Map();

/** The owner-only doc holding an account's e-mail, friends and FCM tokens (see lib/repositories/users_repository.dart). */
function privateAccountRef(uid) {
  return db.collection("users").doc(uid).collection("private").doc("account");
}

/**
 * Fetches distinct FCM tokens for every uid in `uids`, skipping `excludeUid`.
 * Also reads the legacy public `users/{uid}.fcmTokens`, for accounts not yet
 * migrated to the private doc (see tool/migrate_private_user_fields.js).
 */
async function tokensFor(uids, excludeUid) {
  const targets = uids.filter((uid) => uid !== excludeUid && !uid.startsWith("guest:"));
  if (targets.length === 0) return [];
  const refs = targets.flatMap((uid) => [privateAccountRef(uid), db.collection("users").doc(uid)]);
  const snaps = await db.getAll(...refs);
  const tokens = new Set();
  snaps.forEach((snap, i) => {
    const list = snap.exists ? snap.data().fcmTokens : null;
    if (!Array.isArray(list)) return;
    for (const t of list) {
      if (typeof t !== "string") continue;
      tokens.add(t);
      tokenOwners.set(t, targets[Math.floor(i / 2)]);
    }
  });
  return [...tokens];
}

/**
 * Sends `notification` to `tokens` on Android channel `channelId`, pruning any
 * that come back invalid/unregistered — 500 at a time, the most a multicast
 * takes.
 */
async function sendToTokens(tokens, notification, channelId = "podium_matches") {
  const stale = [];
  for (let start = 0; start < tokens.length; start += 500) {
    const chunk = tokens.slice(start, start + 500);
    const res = await messaging.sendEachForMulticast({
      tokens: chunk,
      notification,
      android: { priority: "high", notification: { channelId } },
    });
    res.responses.forEach((r, i) => {
      if (!r.success && ["messaging/registration-token-not-registered", "messaging/invalid-registration-token"].includes(r.error?.code)) {
        stale.push(chunk[i]);
      }
    });
  }
  await Promise.all(
    stale.map(async (token) => {
      const uid = tokenOwners.get(token);
      if (!uid) return;
      tokenOwners.delete(token);
      const remove = { fcmTokens: FieldValue.arrayRemove(token) };
      await Promise.all([
        privateAccountRef(uid).set(remove, { merge: true }),
        db.collection("users").doc(uid).update(remove).catch(() => {}),
      ]);
    }),
  );
}

/**
 * A friend Group's catalog/matches live under `groups/{rootId}`, a Server's
 * Salon ones under `servers/{rootId}` (see
 * lib/repositories/*_repository.dart's `rootCollection`) — same doc shape
 * either way, so `onMatchWritten`/`onMatchSessionCreated` below use one
 * wildcarded trigger for both instead of two near-identical exports. The
 * one real difference is *who* to notify: a Group match's audience is the
 * whole root doc's `memberIds`; a Salon match's is just that specific
 * Salon's `memberIds` (see `doc.salonId`) — a Server can hold several
 * unrelated Salons, and someone in "Blind test et quiz" shouldn't be pinged
 * for a "Loup-Garous" match. This resolves whichever doc actually holds the
 * right audience for a given match/session doc.
 */
function membershipRef(root, rootId, doc) {
  if (root === "servers" && doc.salonId) {
    return db.collection("servers").doc(rootId).collection("salons").doc(doc.salonId);
  }
  return db.collection(root).doc(rootId);
}

/**
 * Above this many accounts (guests have no phone to notify), a group or salon
 * only pushes match and chat news to whoever it concerns — a match's players,
 * the people @mentioned — rather than to everyone: in a game café's salon,
 * every member would otherwise get each table's every match, a few hundred
 * pushes a day. Smaller ones, friend groups, still notify everybody.
 */
const LARGE_AUDIENCE = 30;

function isLargeAudience(memberIds) {
  return memberIds.filter((uid) => !uid.startsWith("guest:")).length > LARGE_AUDIENCE;
}

// Fires when a client starts scoring a new match — see
// MatchesRepository.startLiveSession / lib/state/app_state.dart's
// _startLiveSessionIfNeeded. Pushes "Une partie de X a été débutée par Y" to
// the rest of the root community (see membershipRef for who that is).
exports.onMatchSessionCreated = onDocumentCreated("{root}/{rootId}/matchSessions/{sessionId}", async (event) => {
  const { root, rootId } = event.params;
  if (root !== "groups" && root !== "servers") return;
  const session = event.data?.data();
  if (!session) return;
  if (root === "servers" && !session.salonId) return;

  const [memberSnap, gameSnap] = await Promise.all([
    membershipRef(root, rootId, session).get(),
    db.collection(root).doc(rootId).collection("games").doc(session.gameId).get(),
  ]);
  if (!memberSnap.exists) return;

  const memberIds = memberSnap.data().memberIds || [];
  // Its players are at the table already, and nobody else in a big room
  // needs a push for every match that starts there.
  if (isLargeAudience(memberIds)) return;
  const gameName = gameSnap.exists ? gameSnap.data().name : "une partie";
  const tokens = await tokensFor(memberIds, session.startedBy);
  if (tokens.length === 0) return;

  await sendToTokens(tokens, {
    title: "Partie en cours",
    body: `Une partie de ${gameName} a été débutée par ${session.startedByName || "un joueur"}.`,
  });
  logger.info(`match-started push sent for ${gameName} in ${root}/${rootId} to ${tokens.length} device(s)`);
});

// Fires on every write to a match. Keeps the scope's win tally in step (see
// updateWinsTally) and stamps `updatedAt` when an older app left it out (see
// stampUpdatedAt). When the match was just recorded (not updated/resumed
// later, nor deleted), also pushes "X a gagné la partie de Y !" to the rest
// of the root community (see membershipRef) — to its players only in a big
// one (see LARGE_AUDIENCE) — and, best effort, drops an auto-generated
// highlight into the discussion thread if this match made someone's win
// streak or the leaderboard notable (see postMatchHighlights).
exports.onMatchWritten = onDocumentWritten("{root}/{rootId}/matches/{matchId}", async (event) => {
  const { root, rootId, matchId } = event.params;
  if (root !== "groups" && root !== "servers") return;
  const before = event.data?.before?.data();
  const match = event.data?.after?.data();
  await stampUpdatedAt(event.data);
  let lead = null;
  try {
    lead = await updateWinsTally({ root, rootId, eventId: event.id, before, after: match });
  } catch (e) {
    logger.warn(`updateWinsTally failed for ${root}/${rootId}/matches/${matchId}: ${e}`);
  }
  if (before || !match || match.deleted) return;
  if (root === "servers" && !match.salonId) return;

  const [memberSnap, gameSnap] = await Promise.all([
    membershipRef(root, rootId, match).get(),
    db.collection(root).doc(rootId).collection("games").doc(match.gameId).get(),
  ]);
  if (!memberSnap.exists) return;

  const gameName = gameSnap.exists ? gameSnap.data().name : "une partie";
  const winnerIds = computeWinnerIds(match);
  const winnerUids = [...new Set(winnerIds)];

  const winnerSnaps = await Promise.all(winnerUids.map((uid) => db.collection("users").doc(uid).get()));
  const winnerNames = new Map(winnerSnaps.filter((s) => s.exists).map((s) => [s.id, s.data().displayName || "Joueur"]));

  const body = winnerNames.size > 0
    ? `${[...winnerNames.values()].join(", ")} ${winnerNames.size > 1 ? "ont" : "a"} gagné la partie de ${gameName} !`
    : `La partie de ${gameName} est terminée.`;

  const memberIds = memberSnap.data().memberIds || [];
  const audience = isLargeAudience(memberIds) ? [...new Set((match.entries || []).map((e) => e.playerId))].filter((uid) => memberIds.includes(uid)) : memberIds;
  const tokens = await tokensFor(audience, match.createdByUid);
  if (tokens.length > 0) {
    await sendToTokens(tokens, { title: "Partie terminée", body });
    logger.info(`match-finished push sent for ${gameName} in ${root}/${rootId} to ${tokens.length} device(s)`);
  }

  try {
    await postMatchHighlights({ root, rootId, match, gameName, winnerUids, winnerNames, lead });
  } catch (e) {
    // Best-effort, same reasoning as AppState's own flowError catches on the
    // Dart side — a highlight is a nice-to-have, never worth losing the
    // already-saved match or the push notification above over.
    logger.warn(`postMatchHighlights failed for ${root}/${rootId}/matches/${matchId}: ${e}`);
  }
});

/**
 * Mirrors GameMatch.winnerIds() — used to tell a sole leaderboard leader
 * from a tie. Same reasoning as computeWinnerIds(): keep in sync with the
 * Dart side (lib/state/player_row.dart's computeRows).
 */
function computeWinsMap(matchDocs) {
  const wins = {};
  for (const m of matchDocs) {
    for (const uid of winnersOf(m)) wins[uid] = (wins[uid] || 0) + 1;
  }
  return wins;
}

/** Each player credited with a win by `match` (once each), none for a missing or deleted one. */
function winnersOf(match) {
  return match && !match.deleted ? [...new Set(computeWinnerIds(match))] : [];
}

/**
 * Keeps `{root}/{rootId}/stats/{wins|wins-<salonId>}` — every player's win
 * count over the scope's matches (the whole group, or one salon) and how many
 * there are — in step with each match write, so seeing whether a new match
 * handed someone the lead no longer means re-reading the scope's whole
 * history every time. Built from that history once, the first time a scope's
 * match is written. Returns the sole leader before and after this write and
 * the scope's match count, or null for a write already counted (a retried
 * event).
 */
async function updateWinsTally({ root, rootId, eventId, before, after }) {
  const doc = after || before;
  if (!doc) return null;
  const salonId = root === "servers" ? doc.salonId : null;
  if (root === "servers" && !salonId) return null;
  const ref = db.collection(root).doc(rootId).collection("stats").doc(salonId ? `wins-${salonId}` : "wins");
  const counted = (m) => (m && !m.deleted ? 1 : 0);
  // Confirmations, stamps, edits that don't change who won: nothing to count.
  if (before && after && counted(before) === counted(after) && isDeepStrictEqual(winnersOf(before).sort(), winnersOf(after).sort())) return null;
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) {
      let scope = db.collection(root).doc(rootId).collection("matches");
      if (salonId) scope = scope.where("salonId", "==", salonId);
      const history = await tx.get(scope.select("entries", "mode", "lowWins", "deleted"));
      const matches = history.docs.map((d) => d.data()).filter((m) => !m.deleted);
      const wins = computeWinsMap(matches);
      // `history` already includes this write: the tally before it is the
      // same without this match's winners, with its previous ones back.
      const previous = { ...wins };
      for (const uid of winnersOf(after)) previous[uid] = (previous[uid] || 0) - 1;
      for (const uid of winnersOf(before)) previous[uid] = (previous[uid] || 0) + 1;
      tx.set(ref, { wins, count: matches.length, events: [eventId] });
      return { before: soleLeader(previous), after: soleLeader(wins), count: matches.length };
    }
    const data = snap.data();
    const events = data.events || [];
    if (events.includes(eventId)) return null;
    const wins = { ...(data.wins || {}) };
    const leaderBefore = soleLeader(wins);
    for (const uid of winnersOf(before)) wins[uid] = (wins[uid] || 0) - 1;
    for (const uid of winnersOf(after)) wins[uid] = (wins[uid] || 0) + 1;
    for (const uid of Object.keys(wins)) {
      if (wins[uid] <= 0) delete wins[uid];
    }
    const count = Math.max(0, (data.count || 0) + counted(after) - counted(before));
    tx.set(ref, { wins, count, events: [...events, eventId].slice(-20) });
    return { before: leaderBefore, after: soleLeader(wins), count };
  });
}

/** The single player with strictly more wins than everyone else, or null (no matches yet, or a tie for first). */
function soleLeader(wins) {
  const entries = Object.entries(wins).sort((a, b) => b[1] - a[1]);
  if (entries.length === 0 || entries[0][1] <= 0) return null;
  if (entries.length > 1 && entries[1][1] === entries[0][1]) return null;
  return entries[0][0];
}

/**
 * Best-effort highlights for the discussion thread (see
 * lib/screens/chat/group_chat_screen.dart) — posted as `system: true`
 * messages, attributed to authorId `'system'` (a value no real Firebase Auth
 * uid can ever be, and the one firestore.rules' `messages` create rule
 * rejects from any client — see isPollVote()'s doc comment there for the
 * update-side equivalent). Two kinds, both scoped to keep costs bounded as a
 * group's history grows:
 *   - a win streak (>= 3 in a row) at this specific game, from the last 25
 *     matches of that game only;
 *   - the root's (or, in a Server, the salon's) overall leaderboard gaining
 *     a new sole leader — `lead`, from the running win tally (see
 *     updateWinsTally), and only once there are at least 3 matches (too
 *     early to mean anything before).
 */
async function postMatchHighlights({ root, rootId, match, gameName, winnerUids, winnerNames, lead }) {
  if (winnerUids.length === 0) return;
  const highlights = [];
  const matchesCol = db.collection(root).doc(rootId).collection("matches");

  // Win streak at this game.
  let gameHistoryQuery = matchesCol.where("gameId", "==", match.gameId);
  if (root === "servers") gameHistoryQuery = gameHistoryQuery.where("salonId", "==", match.salonId);
  const gameHistorySnap = await gameHistoryQuery.orderBy("createdAt", "desc").limit(25).select("entries", "mode", "lowWins").get();
  const gameHistory = gameHistorySnap.docs.map((d) => d.data());

  const streakByUid = new Map();
  for (const uid of winnerUids) {
    let streak = 0;
    for (const m of gameHistory) {
      if (!computeWinnerIds(m).includes(uid)) break;
      streak++;
    }
    if (streak >= 3) streakByUid.set(uid, streak);
  }
  // Group players who share the same streak length into one highlight (the
  // common case for a team/coop win, where every winner's streak moves in
  // lockstep) instead of posting one near-identical line per player.
  const byStreakLength = new Map();
  for (const [uid, count] of streakByUid) {
    if (!byStreakLength.has(count)) byStreakLength.set(count, []);
    byStreakLength.get(count).push(uid);
  }
  for (const [count, uids] of byStreakLength) {
    const names = uids.map((uid) => winnerNames.get(uid)).filter(Boolean);
    if (names.length === 0) continue;
    highlights.push(`${names.join(" et ")} enchaîne${names.length > 1 ? "nt" : ""} ${count} victoires d'affilée à ${gameName} 🔥`);
  }

  // Overall leaderboard: did this match hand the sole lead to someone new?
  if (lead && lead.count >= 3 && lead.after && lead.after !== lead.before && winnerNames.has(lead.after)) {
    highlights.push(`${winnerNames.get(lead.after)} prend la tête du classement 👑`);
  }

  if (highlights.length === 0) return;
  const messagesCol = db.collection(root).doc(rootId).collection("messages");
  for (const text of highlights) {
    const doc = { authorId: "system", system: true, text, createdAt: FieldValue.serverTimestamp() };
    if (match.salonId) doc.salonId = match.salonId;
    await messagesCol.add(doc);
  }
}

/** The poster's current display name, or a generic fallback (e.g. their account was since deleted). */
async function authorName(uid) {
  if (!uid) return "Un membre";
  const snap = await db.collection("users").doc(uid).get();
  return (snap.exists && snap.data().displayName) || "Un membre";
}

// Fires whenever a message (plain text, a poll, or a `system` highlight —
// see lib/models/message.dart) is posted to a group's/salon's discussion
// thread. Pushes a WhatsApp-style "Sender: preview" to the rest of the
// audience (see membershipRef) on its own "podium_chat" Android channel, so
// it can be muted independently of match/roster pushes. The sender never
// gets their own push (see tokensFor) — for a `system` highlight there's no
// real sender to exclude, so it goes to every member, author included.
// Anyone `@mentioned` (see GroupMessage.mentionedUids) is pulled out of that
// general audience and pushed a louder, dedicated notification instead (see
// below) — on its own "podium_mentions" channel, so it still gets through
// even if they've muted "podium_chat".
exports.onMessageCreated = onDocumentCreated("{root}/{rootId}/messages/{messageId}", async (event) => {
  const { root, rootId } = event.params;
  if (root !== "groups" && root !== "servers") return;
  const message = event.data?.data();
  if (!message || !message.text) return;
  if (root === "servers" && !message.salonId) return;

  const memberSnap = await membershipRef(root, rootId, message).get();
  if (!memberSnap.exists) return;

  const mentionedUids = Array.isArray(message.mentionedUids) ? message.mentionedUids : [];
  const memberIds = memberSnap.data().memberIds || [];
  // In a big room, only the people @mentioned hear about a message.
  const generalIds = isLargeAudience(memberIds) ? [] : memberIds.filter((uid) => !mentionedUids.includes(uid));
  if (generalIds.length === 0 && mentionedUids.length === 0) return;
  const author = await authorName(message.authorId);

  let title;
  let body = message.text;
  if (message.system) {
    title = "Podium";
  } else if (Array.isArray(message.pollGameIds) && message.pollGameIds.length > 0) {
    title = "Nouveau sondage";
    body = `${author} : ${message.text}`;
  } else {
    title = author;
  }

  const tokens = await tokensFor(generalIds, message.authorId);
  if (tokens.length > 0) {
    await sendToTokens(tokens, { title, body }, "podium_chat");
    logger.info(`chat push sent in ${root}/${rootId} to ${tokens.length} device(s)`);
  }

  if (mentionedUids.length > 0) {
    const mentionTokens = await tokensFor(mentionedUids, message.authorId);
    if (mentionTokens.length > 0) {
      await sendToTokens(mentionTokens, { title: `${author} vous a mentionné`, body: message.text }, "podium_mentions");
      logger.info(`mention push sent in ${root}/${rootId} to ${mentionTokens.length} device(s)`);
    }
  }
});

// Fires whenever a group's roster changes — pushes
// "vous avez été ajouté à X" to whichever account(s) are newly listed in
// `memberIds`. Covers every way someone ends up in a group uniformly (added
// by e-mail, added straight by uid from the inviter's friends list, or a
// self-service QR join) since they all boil down to the same memberIds
// write — see GroupsRepository. onDocumentUpdated only fires on an existing
// doc changing, so a brand new group's owner (set at creation) never
// triggers this.
//
// Deliberately NOT merged with onSalonMemberAdded below the way the two
// triggers above are: a Group's own membership lives directly on
// `groups/{groupId}`, but a Server's *Salon* membership (the one that
// actually matters here — see membershipRef's doc comment) lives one level
// deeper, on `servers/{serverId}/salons/{salonId}`. Different document
// shape and depth, not just a different collection name, so a single
// wildcarded trigger doesn't apply the way it does for matches/sessions.
exports.onGroupMemberAdded = onDocumentUpdated("groups/{groupId}", async (event) => {
  const before = event.data?.before?.data();
  const after = event.data?.after?.data();
  if (!before || !after) return;

  const beforeIds = new Set(before.memberIds || []);
  const newMemberIds = (after.memberIds || []).filter((uid) => !beforeIds.has(uid));
  if (newMemberIds.length === 0) return;

  const tokens = await tokensFor(newMemberIds, null);
  if (tokens.length === 0) return;

  await sendToTokens(
    tokens,
    { title: "Nouveau groupe", body: `Vous avez été ajouté au groupe « ${after.name || "Podium"} ».` },
    "podium_groups",
  );
  logger.info(`group-member-added push sent for group ${event.params.groupId} to ${tokens.length} device(s)`);
});

// Salon equivalent of onGroupMemberAdded — see its doc comment for why this
// stays a separate trigger instead of being merged into one.
exports.onSalonMemberAdded = onDocumentUpdated("servers/{serverId}/salons/{salonId}", async (event) => {
  const before = event.data?.before?.data();
  const after = event.data?.after?.data();
  if (!before || !after) return;

  const beforeIds = new Set(before.memberIds || []);
  const newMemberIds = (after.memberIds || []).filter((uid) => !beforeIds.has(uid));
  if (newMemberIds.length === 0) return;

  const tokens = await tokensFor(newMemberIds, null);
  if (tokens.length === 0) return;

  await sendToTokens(
    tokens,
    { title: "Nouveau salon", body: `Vous avez été ajouté au salon « ${after.name || "Podium"} ».` },
    "podium_groups",
  );
  logger.info(`salon-member-added push sent for salon ${event.params.salonId} to ${tokens.length} device(s)`);
});

// Pushes an edited `gameLibrary` game onto every group/server catalog copy
// still following it — the ones imported from the library and never edited
// since, which keep its id in `libraryId` (see Game.libraryId in
// lib/models/game.dart; editing a copy drops that field). Each copy is
// replaced wholesale by the library version, keeping only its own
// `salonId`/`libraryId` — and, for a copy in someone's "Mon espace solo"
// (exactly 1 player, see Game.asSolo), its player count. Re-checked inside
// a transaction so a copy edited by its group while this runs is left
// alone.
//
// The collection-group query needs the `games.libraryId` field override in
// firestore.indexes.json.
exports.onGameLibraryUpdated = onDocumentUpdated("gameLibrary/{libraryId}", async (event) => {
  const before = event.data?.before?.data();
  const after = event.data?.after?.data();
  if (!before || !after) return;
  // The game itself, without its sync stamp (see stampUpdatedAt).
  const { updatedAt: _stamp, ...game } = after;
  const { updatedAt: _previousStamp, ...previous } = before;
  if (isDeepStrictEqual(previous, game)) return;
  await stampUpdatedAt(event.data);

  const { libraryId } = event.params;
  const copies = await db.collectionGroup("games").where("libraryId", "==", libraryId).get();
  let updated = 0;
  for (const copy of copies.docs) {
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(copy.ref);
      if (!snap.exists || snap.get("libraryId") !== libraryId) return;
      const salonId = snap.get("salonId");
      const solo = snap.get("minPlayers") === 1 && snap.get("maxPlayers") === 1;
      tx.set(copy.ref, {
        ...game,
        libraryId,
        ...(salonId != null && { salonId }),
        ...(solo && { minPlayers: 1, maxPlayers: 1 }),
        updatedAt: FieldValue.serverTimestamp(),
      });
      updated++;
    });
  }
  logger.info(`library game ${libraryId} synced to ${updated} catalog copie(s)`);
});

// Catalog games, tournaments and a salon's events are synced too (see
// GamesRepository.watchGames, TournamentsRepository.watchTournaments,
// EventsRepository.watchEvents): one written by an app from before
// `updatedAt` gets it stamped here.
exports.onGameWritten = onDocumentWritten("{root}/{rootId}/games/{gameId}", async (event) => {
  const { root } = event.params;
  if (root !== "groups" && root !== "servers") return;
  await stampUpdatedAt(event.data);
});

exports.onTournamentWritten = onDocumentWritten("{root}/{rootId}/tournaments/{tournamentId}", async (event) => {
  const { root } = event.params;
  if (root !== "groups" && root !== "servers") return;
  await stampUpdatedAt(event.data);
});

exports.onEventWritten = onDocumentWritten("servers/{serverId}/events/{eventId}", (event) => stampUpdatedAt(event.data));

/**
 * Synced collections (matches, catalog games, tournaments, events, the game
 * library — see lib/repositories/synced_query.dart) only download what was
 * written since the newest `updatedAt` a device holds, so every write must
 * stamp it. App versions from before that don't: a write that left it
 * missing or unchanged gets it stamped here, or other devices would never
 * see that change. The stamp itself is a write too, but one that changes
 * `updatedAt`, so the trigger it sets off again stops here.
 */
async function stampUpdatedAt(change) {
  const before = change?.before?.data();
  const after = change?.after?.data();
  if (!after) return;
  const stamp = after.updatedAt;
  if (stamp && !(before?.updatedAt && stamp.isEqual(before.updatedAt))) return;
  await change.after.ref.update({ updatedAt: FieldValue.serverTimestamp() }).catch((e) => {
    logger.warn(`could not stamp ${change.after.ref.path}: ${e}`);
  });
}

/** Runs `ops` (each adds one write to a batch) in batches under Firestore's 500-write cap. */
async function commitAll(ops) {
  for (let i = 0; i < ops.length; i += 450) {
    const batch = db.batch();
    for (const op of ops.slice(i, i + 450)) op(batch);
    await batch.commit();
  }
}

// ---- Rosters ----
//
// Every group and server keeps a copy of its members' public profiles in its
// `members` subcollection (see UsersRepository.watchRoster), which each
// device syncs — downloading a member's profile once, then only when it
// changes — instead of reading every member's `users/{uid}` doc on every
// launch: a thousand reads each time for a thousand-member game café.
// Entries stay once someone leaves, so their name still shows on the matches
// they played; an account's are tombstoned when it's deleted.

/** Fields of a `users/{uid}` doc only its owner may see — still there on accounts not migrated yet (see tool/migrate_private_user_fields.js), never copied into a roster. */
const PRIVATE_USER_FIELDS = ["email", "friendIds", "fcmTokens"];

/**
 * Bumped whenever rosters need rebuilding: a group or server written while
 * its `rosterVersion` is behind gets every member's entry (re)written, which
 * is also how rosters fill in for groups that existed before them.
 */
const ROSTER_VERSION = 1;

function publicProfile(data) {
  const out = { ...data };
  for (const key of PRIVATE_USER_FIELDS) delete out[key];
  return out;
}

function rosterEntry(uid, profile) {
  return { ...profile, uid, updatedAt: FieldValue.serverTimestamp() };
}

/** `[id, roster profile]` for every account or guest (`guest:` ids) in `ids` that still exists. */
async function rosterProfiles(ids) {
  const out = [];
  for (let i = 0; i < ids.length; i += 300) {
    const chunk = ids.slice(i, i + 300);
    const snaps = await db.getAll(...chunk.map((id) => (id.startsWith("guest:") ? db.collection("guests").doc(id.slice("guest:".length)) : db.collection("users").doc(id))));
    snaps.forEach((snap, j) => {
      if (!snap.exists) return;
      const id = chunk[j];
      const data = snap.data();
      out.push([id, id.startsWith("guest:") ? { displayName: data.displayName || "Invité", color: data.color ?? null } : publicProfile(data)]);
    });
  }
  return out;
}

// A profile changed (or its account was deleted): every roster holding it
// follows. The collection-group query needs the `members.uid` field override
// in firestore.indexes.json.
exports.syncProfileToRosters = onDocumentWritten("users/{uid}", async (event) => {
  const { uid } = event.params;
  const before = event.data?.before?.data();
  const after = event.data?.after?.data();
  if (before && after && isDeepStrictEqual(publicProfile(before), publicProfile(after))) return;
  const [held, groups, servers] = await Promise.all([
    db.collectionGroup("members").where("uid", "==", uid).get(),
    after ? db.collection("groups").where("memberIds", "array-contains", uid).get() : null,
    after ? db.collection("servers").where("memberIds", "array-contains", uid).get() : null,
  ]);
  const refs = new Map(held.docs.map((d) => [d.ref.path, d.ref]));
  for (const root of [...(groups?.docs ?? []), ...(servers?.docs ?? [])]) {
    if (root.get("personal")) continue;
    const ref = root.ref.collection("members").doc(uid);
    refs.set(ref.path, ref);
  }
  const entry = after ? rosterEntry(uid, publicProfile(after)) : { uid, deleted: true, updatedAt: FieldValue.serverTimestamp() };
  await commitAll([...refs.values()].map((ref) => (batch) => batch.set(ref, entry)));
});

/** Adds whoever just joined `event`'s group or server to its roster — everyone, when it's behind ROSTER_VERSION. */
async function syncRoster(event) {
  const before = event.data?.before?.data();
  const after = event.data?.after?.data();
  if (!after) {
    // Deleted: so are its roster and win tallies (the app deletes the rest).
    const ref = event.data.before.ref;
    await Promise.all([db.recursiveDelete(ref.collection("members")), db.recursiveDelete(ref.collection("stats"))]);
    return;
  }
  if (after.personal) return;
  const ref = event.data.after.ref;
  const rebuild = after.rosterVersion !== ROSTER_VERSION;
  const known = new Set(rebuild ? [] : before?.memberIds ?? []);
  const joined = (after.memberIds || []).filter((id) => !known.has(id));
  const profiles = await rosterProfiles(joined);
  await commitAll(profiles.map(([id, profile]) => (batch) => batch.set(ref.collection("members").doc(id), rosterEntry(id, profile))));
  if (rebuild) await ref.update({ rosterVersion: ROSTER_VERSION });
  if (profiles.length > 0) logger.info(`roster of ${ref.path}: ${profiles.length} entr${profiles.length > 1 ? "ies" : "y"} written`);
}

exports.syncGroupRoster = onDocumentWritten("groups/{groupId}", syncRoster);
exports.syncServerRoster = onDocumentWritten("servers/{serverId}", syncRoster);

// Mirrors GameMatch.winnerIds() in lib/models/match.dart — keep in sync.
function computeWinnerIds(match) {
  const entries = Array.isArray(match.entries) ? match.entries : [];
  if (entries.length === 0) return [];

  if (match.mode === "coop") {
    // Every entry shares the same points value by construction (see
    // AppState.setCoopPoints) — a positive shared value (or any lowWins
    // match, where a lower score is the better one) counts everyone as a
    // winner, zero counts as a shared loss.
    if (match.lowWins || (entries[0].points || 0) > 0) return entries.map((e) => e.playerId);
    return [];
  }

  if (match.mode === "team") {
    const sums = {};
    for (const e of entries) {
      const team = e.teamId || "A";
      sums[team] = (sums[team] || 0) + (e.points || 0);
    }
    // In a lowWins game (Skyjo, golf…) the team with the lowest total wins.
    let bestTeam = null;
    let bestVal = match.lowWins ? Infinity : -Infinity;
    for (const [team, val] of Object.entries(sums)) {
      if (match.lowWins ? val < bestVal : val > bestVal) {
        bestVal = val;
        bestTeam = team;
      }
    }
    return entries.filter((e) => (e.teamId || "A") === bestTeam).map((e) => e.playerId);
  }

  const points = entries.map((e) => e.points || 0);
  const best = match.lowWins ? Math.min(...points) : Math.max(...points);
  return entries.filter((e) => (e.points || 0) === best).map((e) => e.playerId);
}

/**
 * Callable from the public "supprimer mes données" web page (see
 * public/app.js) as the browser-based equivalent of AppState.deleteAccount
 * in the Flutter app. Runs with Admin SDK privileges (bypasses
 * firestore.rules entirely) so it can use recursiveDelete to wipe every
 * subcollection of an owned group/server — games, matches, tournaments,
 * live sessions, scheduled events, whatever exists — without having to
 * enumerate each one by hand like the Dart client does.
 */
exports.deleteMyAccount = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Vous devez être connecté.");

  const [userSnap, privateSnap] = await db.getAll(db.collection("users").doc(uid), privateAccountRef(uid));
  const email = (privateSnap.exists && privateSnap.data().email) || (userSnap.exists && userSnap.data().email) || request.auth.token.email || "";

  // Groups: owned outright -> delete with all their history; otherwise just
  // leave the roster.
  const groupsSnap = await db.collection("groups").where("memberIds", "array-contains", uid).get();
  for (const doc of groupsSnap.docs) {
    if (doc.data().ownerId === uid) {
      await db.recursiveDelete(doc.ref);
    } else {
      await doc.ref.update({ memberIds: FieldValue.arrayRemove(uid) });
    }
  }

  // Servers: same idea, plus scrub salon membership on servers left behind.
  const serversSnap = await db.collection("servers").where("memberIds", "array-contains", uid).get();
  for (const doc of serversSnap.docs) {
    if (doc.data().ownerId === uid) {
      await db.recursiveDelete(doc.ref);
      continue;
    }
    await doc.ref.update({
      memberIds: FieldValue.arrayRemove(uid),
      adminIds: FieldValue.arrayRemove(uid),
    });
    const salonsSnap = await doc.ref.collection("salons").where("memberIds", "array-contains", uid).get();
    for (const salonDoc of salonsSnap.docs) {
      await salonDoc.ref.update({ memberIds: FieldValue.arrayRemove(uid) });
    }
  }

  const batch = db.batch();
  batch.delete(privateAccountRef(uid));
  batch.delete(db.collection("users").doc(uid));
  if (email) batch.delete(db.collection("emailIndex").doc(email.trim().toLowerCase()));
  await batch.commit();

  // Last: once the Auth user is gone, request.auth no longer exists to
  // authorize anything above, so the Firestore cleanup has to come first.
  await getAuth().deleteUser(uid);

  return { ok: true };
});
