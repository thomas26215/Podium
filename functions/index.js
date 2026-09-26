const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { getAuth } = require("firebase-admin/auth");
const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions");
const { isDeepStrictEqual } = require("node:util");

initializeApp();

const db = getFirestore();
const messaging = getMessaging();

/** Fetches distinct FCM tokens for every uid in `uids`, skipping `excludeUid`. */
async function tokensFor(uids, excludeUid) {
  const targets = uids.filter((uid) => uid !== excludeUid);
  if (targets.length === 0) return [];
  const snaps = await Promise.all(targets.map((uid) => db.collection("users").doc(uid).get()));
  const tokens = new Set();
  for (const snap of snaps) {
    const list = snap.exists ? snap.data().fcmTokens : null;
    if (Array.isArray(list)) list.forEach((t) => typeof t === "string" && tokens.add(t));
  }
  return [...tokens];
}

/** Sends `notification` to `tokens` on Android channel `channelId`, pruning any that come back invalid/unregistered. */
async function sendToTokens(tokens, notification, channelId = "podium_matches") {
  if (tokens.length === 0) return;
  const res = await messaging.sendEachForMulticast({
    tokens,
    notification,
    android: { priority: "high", notification: { channelId } },
  });
  const stale = [];
  res.responses.forEach((r, i) => {
    if (!r.success && ["messaging/registration-token-not-registered", "messaging/invalid-registration-token"].includes(r.error?.code)) {
      stale.push(tokens[i]);
    }
  });
  await Promise.all(
    stale.map(async (token) => {
      const owner = await db.collection("users").where("fcmTokens", "array-contains", token).limit(1).get();
      if (!owner.empty) await owner.docs[0].ref.update({ fcmTokens: FieldValue.arrayRemove(token) });
    }),
  );
}

/**
 * A friend Group's catalog/matches live under `groups/{rootId}`, a Server's
 * Salon ones under `servers/{rootId}` (see
 * lib/repositories/*_repository.dart's `rootCollection`) — same doc shape
 * either way, so `onMatchCreated`/`onMatchSessionCreated` below use one
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

  const gameName = gameSnap.exists ? gameSnap.data().name : "une partie";
  const memberIds = memberSnap.data().memberIds || [];
  const tokens = await tokensFor(memberIds, session.startedBy);
  if (tokens.length === 0) return;

  await sendToTokens(tokens, {
    title: "Partie en cours",
    body: `Une partie de ${gameName} a été débutée par ${session.startedByName || "un joueur"}.`,
  });
  logger.info(`match-started push sent for ${gameName} in ${root}/${rootId} to ${tokens.length} device(s)`);
});

// Fires when a match is recorded (not when it's later updated/resumed — an
// onCreate trigger only fires once per doc). Pushes "X a gagné la partie de
// Y !" to the rest of the root community (see membershipRef), and — best
// effort — drops an auto-generated highlight into the discussion thread if
// this match made someone's win streak or the group's leaderboard notable
// (see postMatchHighlights).
exports.onMatchCreated = onDocumentCreated("{root}/{rootId}/matches/{matchId}", async (event) => {
  const { root, rootId, matchId } = event.params;
  if (root !== "groups" && root !== "servers") return;
  const match = event.data?.data();
  if (!match) return;
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
  const tokens = await tokensFor(memberIds, match.createdByUid);
  if (tokens.length > 0) {
    await sendToTokens(tokens, { title: "Partie terminée", body });
    logger.info(`match-finished push sent for ${gameName} in ${root}/${rootId} to ${tokens.length} device(s)`);
  }

  try {
    await postMatchHighlights({ root, rootId, matchId, match, gameName, winnerUids, winnerNames });
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
    for (const uid of computeWinnerIds(m)) wins[uid] = (wins[uid] || 0) + 1;
  }
  return wins;
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
 *     a new sole leader — a full read of that scope's matches, but skipped
 *     entirely once there are fewer than 3 (too early to mean anything) so a
 *     brand new group's first couple of matches don't pay for it.
 */
async function postMatchHighlights({ root, rootId, matchId, match, gameName, winnerUids, winnerNames }) {
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
  let scopeQuery = matchesCol;
  if (root === "servers") scopeQuery = scopeQuery.where("salonId", "==", match.salonId);
  const scopeSnap = await scopeQuery.select("entries", "mode", "lowWins").get();
  if (scopeSnap.size >= 3) {
    const beforeDocs = scopeSnap.docs.filter((d) => d.id !== matchId).map((d) => d.data());
    const afterDocs = scopeSnap.docs.map((d) => d.data());
    const beforeLeader = soleLeader(computeWinsMap(beforeDocs));
    const afterLeader = soleLeader(computeWinsMap(afterDocs));
    if (afterLeader && afterLeader !== beforeLeader && winnerNames.has(afterLeader)) {
      highlights.push(`${winnerNames.get(afterLeader)} prend la tête du classement 👑`);
    }
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

  const memberIds = memberSnap.data().memberIds || [];
  const generalIds = memberIds.filter((uid) => !mentionedUids.includes(uid));
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
// `salonId`/`libraryId`. Re-checked inside a transaction so a copy edited
// by its group while this runs is left alone.
//
// The collection-group query needs the `games.libraryId` field override in
// firestore.indexes.json.
exports.onGameLibraryUpdated = onDocumentUpdated("gameLibrary/{libraryId}", async (event) => {
  const before = event.data?.before?.data();
  const after = event.data?.after?.data();
  if (!before || !after || isDeepStrictEqual(before, after)) return;

  const { libraryId } = event.params;
  const copies = await db.collectionGroup("games").where("libraryId", "==", libraryId).get();
  let updated = 0;
  for (const copy of copies.docs) {
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(copy.ref);
      if (!snap.exists || snap.get("libraryId") !== libraryId) return;
      const salonId = snap.get("salonId");
      tx.set(copy.ref, { ...after, libraryId, ...(salonId != null && { salonId }) });
      updated++;
    });
  }
  logger.info(`library game ${libraryId} synced to ${updated} catalog copie(s)`);
});

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
    let bestTeam = null;
    let bestVal = -Infinity;
    for (const [team, val] of Object.entries(sums)) {
      if (val > bestVal) {
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

  const userSnap = await db.collection("users").doc(uid).get();
  const email = (userSnap.exists && userSnap.data().email) || request.auth.token.email || "";

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
  batch.delete(db.collection("users").doc(uid));
  if (email) batch.delete(db.collection("emailIndex").doc(email.trim().toLowerCase()));
  await batch.commit();

  // Last: once the Auth user is gone, request.auth no longer exists to
  // authorize anything above, so the Firestore cleanup has to come first.
  await getAuth().deleteUser(uid);

  return { ok: true };
});
