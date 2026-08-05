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

// Fires when a client starts scoring a new match — see
// MatchesRepository.announceMatchStart / lib/state/app_state.dart's
// _announceMatchStartIfNeeded. Pushes "Une partie de X a été débutée par Y"
// to the rest of the root community.
exports.onMatchSessionCreated = onDocumentCreated("groups/{rootId}/matchSessions/{sessionId}", async (event) => {
  const session = event.data?.data();
  if (!session) return;
  const { rootId } = event.params;

  const [rootSnap, gameSnap] = await Promise.all([
    db.collection("groups").doc(rootId).get(),
    db.collection("groups").doc(rootId).collection("games").doc(session.gameId).get(),
  ]);
  if (!rootSnap.exists) return;

  const gameName = gameSnap.exists ? gameSnap.data().name : "une partie";
  const allMemberIds = rootSnap.data().allMemberIds || [];
  const tokens = await tokensFor(allMemberIds, session.startedBy);
  if (tokens.length === 0) return;

  await sendToTokens(tokens, {
    title: "Partie en cours",
    body: `Une partie de ${gameName} a été débutée par ${session.startedByName || "un joueur"}.`,
  });
  logger.info(`match-started push sent for ${gameName} in root ${rootId} to ${tokens.length} device(s)`);
});

// Fires when a match is recorded (not when it's later updated/resumed — an
// onCreate trigger only fires once per doc). Pushes "X a gagné la partie de
// Y !" to the rest of the root community.
exports.onMatchCreated = onDocumentCreated("groups/{rootId}/matches/{matchId}", async (event) => {
  const match = event.data?.data();
  if (!match) return;
  const { rootId } = event.params;

  const [rootSnap, gameSnap] = await Promise.all([
    db.collection("groups").doc(rootId).get(),
    db.collection("groups").doc(rootId).collection("games").doc(match.gameId).get(),
  ]);
  if (!rootSnap.exists) return;

  const gameName = gameSnap.exists ? gameSnap.data().name : "une partie";
  const winnerIds = computeWinnerIds(match);
  const winnerUids = [...new Set(winnerIds)];

  const winnerSnaps = await Promise.all(winnerUids.map((uid) => db.collection("users").doc(uid).get()));
  const winnerNames = winnerSnaps.filter((s) => s.exists).map((s) => s.data().displayName || "Joueur");

  const body = winnerNames.length > 0
    ? `${winnerNames.join(", ")} ${winnerNames.length > 1 ? "ont" : "a"} gagné la partie de ${gameName} !`
    : `La partie de ${gameName} est terminée.`;

  const allMemberIds = rootSnap.data().allMemberIds || [];
  const tokens = await tokensFor(allMemberIds, match.createdByUid);
  if (tokens.length === 0) return;

  await sendToTokens(tokens, { title: "Partie terminée", body });
  logger.info(`match-finished push sent for ${gameName} in root ${rootId} to ${tokens.length} device(s)`);
});

// Fires whenever a group's (root or subgroup) roster changes — pushes
// "vous avez été ajouté à X" to whichever account(s) are newly listed in
// `memberIds`. Covers every way someone ends up in a group uniformly (added
// by e-mail, added straight by uid from the inviter's friends list, or a
// self-service QR join) since they all boil down to the same memberIds
// write — see GroupsRepository. onDocumentUpdated only fires on an existing
// doc changing, so a brand new group's owner (set at creation) never
// triggers this.
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

// Mirrors GameMatch.winnerIds() in lib/models/match.dart — keep in sync.
function computeWinnerIds(match) {
  const entries = Array.isArray(match.entries) ? match.entries : [];
  if (entries.length === 0) return [];

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
