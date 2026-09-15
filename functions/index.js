const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { logger } = require("firebase-functions");

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
// Y !" to the rest of the root community (see membershipRef).
exports.onMatchCreated = onDocumentCreated("{root}/{rootId}/matches/{matchId}", async (event) => {
  const { root, rootId } = event.params;
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
  const winnerNames = winnerSnaps.filter((s) => s.exists).map((s) => s.data().displayName || "Joueur");

  const body = winnerNames.length > 0
    ? `${winnerNames.join(", ")} ${winnerNames.length > 1 ? "ont" : "a"} gagné la partie de ${gameName} !`
    : `La partie de ${gameName} est terminée.`;

  const memberIds = memberSnap.data().memberIds || [];
  const tokens = await tokensFor(memberIds, match.createdByUid);
  if (tokens.length === 0) return;

  await sendToTokens(tokens, { title: "Partie terminée", body });
  logger.info(`match-finished push sent for ${gameName} in ${root}/${rootId} to ${tokens.length} device(s)`);
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
