// ---- Library stats ----
//
// Downloads, matches played and likes of each `gameLibrary` game, shown in
// the app's library (see lib/models/library_game_stats.dart). They live in
// `gameLibraryStats/{libraryId}` — `{downloads, plays, likes, updatedAt}`,
// readable by every signed-in player, written only from here.
//
// Counted from the day these functions went live, never back in time: each
// copy of a library game taken into a catalog adds a download, each match
// recorded with it adds a play, and neither count ever goes back down — not
// even when the copy, the match or the whole group is deleted later. Likes
// follow what each player likes now, so they go up and down. Ledgers keep
// every count exact — an event retried or delivered twice never counts
// twice — and none of them is ever exposed to the app.

const { getFirestore, FieldValue } = require("firebase-admin/firestore");

/** Most library games one write to a player's like list is tallied for — the app changes one at a time. */
const MAX_LIKES_PER_WRITE = 50;

/** How many times a write is tried when others hold the same documents (see withContentionRetries). */
const CONTENTION_ATTEMPTS = 6;

/** How long an instance trusts what it read of the library (see libraryHas). */
const LIBRARY_CACHE_MS = 10 * 60 * 1000;

/** Whether `id` can name a document: a non-empty string, never a path. */
function isPlainId(id) {
  return typeof id === "string" && id.length > 0 && id.length <= 200 && !id.includes("/") && id !== "." && id !== ".." && !/^__.*__$/.test(id);
}

function statsRef(libraryId) {
  return getFirestore().collection("gameLibraryStats").doc(libraryId);
}

/** The player's own list of the library games they like, written by the app (see GameLibraryRepository.setLiked). */
function likesListRef(uid) {
  return getFirestore().collection("users").doc(uid).collection("private").doc("libraryLikes");
}

/** A catalog game, `{root}/{rootId}/games/{gameId}`, as a ledger entry id. */
function catalogGameKey(root, rootId, gameId) {
  return `${root}:${rootId}:${gameId}`;
}

/** The library game a catalog game was last taken from (see libraryGameOf). */
function linkRef(root, rootId, gameId) {
  return getFirestore().collection("gameLibraryLinks").doc(catalogGameKey(root, rootId, gameId));
}

const libraryCache = new Map();

/** Whether library game `id` exists — kept a few minutes per instance: the library hardly ever changes. */
async function libraryHas(id) {
  const hit = libraryCache.get(id);
  if (hit && hit.until > Date.now()) return hit.exists;
  const exists = (await getFirestore().collection("gameLibrary").doc(id).get()).exists;
  if (libraryCache.size > 5000) libraryCache.clear();
  libraryCache.set(id, { exists, until: Date.now() + LIBRARY_CACHE_MS });
  return exists;
}

/** Runs `attempt` again, after a random pause growing each time, when it collides with others on the same documents (ABORTED). */
async function withContentionRetries(attempt) {
  for (let i = 1; ; i++) {
    try {
      return await attempt();
    } catch (e) {
      if (e.code !== 10 || i >= CONTENTION_ATTEMPTS) throw e;
      await new Promise((resolve) => setTimeout(resolve, Math.random() * 250 * 2 ** i));
    }
  }
}

/**
 * Adds `delta` (`{downloads|plays|likes: n}`) to `libraryId`'s counts within
 * `writer` (a batch or a transaction), with a fresh `updatedAt` so the app's
 * synced copy picks it up (see lib/repositories/synced_query.dart).
 */
function bump(writer, libraryId, delta) {
  const update = { updatedAt: FieldValue.serverTimestamp() };
  for (const [field, n] of Object.entries(delta)) {
    if (n) update[field] = FieldValue.increment(n);
  }
  writer.set(statsRef(libraryId), update, { merge: true });
}

/**
 * Adds `delta` to `libraryId`'s counts, once only: in the same write as
 * `ledgerRef`, the entry naming what is counted, which can only be created
 * — a second try at the same thing (a retried or duplicated event) fails
 * whole, and is let go.
 */
async function countOnce(ledgerRef, libraryId, delta) {
  await withContentionRetries(async () => {
    const batch = getFirestore().batch();
    batch.create(ledgerRef, { at: FieldValue.serverTimestamp() });
    bump(batch, libraryId, delta);
    try {
      await batch.commit();
    } catch (e) {
      // ALREADY_EXISTS: counted already.
      if (e.code !== 6) throw e;
    }
  });
}

/**
 * The library game catalog game `{root}/{rootId}/games/{gameId}` stands for:
 * the one it follows (`libraryId`), else the one it was last taken from — a
 * copy edited since import drops `libraryId` (see Game.libraryId in
 * lib/models/game.dart) but is still that game — else the one sharing its
 * very id, like the default catalog's (see kDefaultGames). Null for a game
 * made by hand.
 */
async function libraryGameOf(root, rootId, gameId) {
  if (!isPlainId(gameId)) return null;
  const db = getFirestore();
  const [game, link] = await db.getAll(db.collection(root).doc(rootId).collection("games").doc(gameId), linkRef(root, rootId, gameId));
  const candidates = [game.exists && !game.get("deleted") ? game.get("libraryId") : null, link.exists ? link.get("libraryId") : null, gameId];
  for (const id of candidates) {
    if (isPlainId(id) && (await libraryHas(id))) return id;
  }
  return null;
}

/**
 * Counts catalog game `{root}/{rootId}/games/{gameId}` taken from library
 * game `libraryId` — imported, or replaced by it — as a download of it,
 * once: importing the game again makes another copy, so another download.
 * Also remembers which library game it stands for, for its matches once an
 * edit has unlinked it (see libraryGameOf).
 */
async function countLibraryDownload(root, rootId, gameId, libraryId) {
  if (!isPlainId(libraryId) || !(await libraryHas(libraryId))) return;
  await countOnce(statsRef(libraryId).collection("downloads").doc(catalogGameKey(root, rootId, gameId)), libraryId, { downloads: 1 });
  // Unless it has been linked to another one since.
  const game = await getFirestore().collection(root).doc(rootId).collection("games").doc(gameId).get();
  if (game.get("libraryId") === libraryId) await linkRef(root, rootId, gameId).set({ libraryId });
}

/** Counts match `{root}/{rootId}/matches/{matchId}`, just recorded with catalog game `gameId`, as a play of the library game it stands for — once. */
async function countLibraryPlay(root, rootId, matchId, gameId) {
  const libraryId = await libraryGameOf(root, rootId, gameId);
  if (!libraryId) return;
  await countOnce(statsRef(libraryId).collection("plays").doc(`${root}:${rootId}:${matchId}`), libraryId, { plays: 1 });
}

/**
 * Tallies player `uid`'s like of library game `libraryId`, or its removal,
 * exactly once: their own list says what they like, a ledger
 * (`gameLibraryStats/{libraryId}/likes/{uid}`) what was counted. Both are
 * read fresh rather than taken from the event, so in whatever order the
 * events come, the count ends on the list's latest state.
 */
async function reconcileLibraryLike(uid, libraryId) {
  if (!isPlainId(uid) || !isPlainId(libraryId)) return;
  const inLibrary = await libraryHas(libraryId);
  const markerRef = statsRef(libraryId).collection("likes").doc(uid);
  await withContentionRetries(() =>
    getFirestore().runTransaction(async (tx) => {
      const [list, marker] = await tx.getAll(likesListRef(uid), markerRef);
      const ids = list.exists ? list.get("gameIds") : null;
      const likes = inLibrary && Array.isArray(ids) && ids.includes(libraryId);
      if (likes === marker.exists) return;
      if (likes) {
        tx.set(markerRef, { at: FieldValue.serverTimestamp() });
      } else {
        tx.delete(markerRef);
      }
      bump(tx, libraryId, { likes: likes ? 1 : -1 });
    }),
  );
}

/**
 * Follows a write to a catalog game: one newly linked to a library game is
 * a download of it (see countLibraryDownload). Stamps, resyncs from the
 * library, edits and deletions count nothing — nor take anything back.
 */
async function onCatalogGameWritten({ root, rootId, gameId, before, after }) {
  const linkOf = (game) => (game && !game.deleted && isPlainId(game.libraryId) ? game.libraryId : null);
  const link = linkOf(after);
  if (link && link !== linkOf(before)) await countLibraryDownload(root, rootId, gameId, link);
}

/** Follows a write to a match: one just recorded is a play (see countLibraryPlay). Edits and deletions count nothing — nor take anything back. */
async function onCatalogMatchWritten({ root, rootId, matchId, before, after }) {
  if (before || !after || after.deleted) return;
  await countLibraryPlay(root, rootId, matchId, after.gameId);
}

/** Follows a write to player `uid`'s like list (`change`): each library game it added or removed is tallied (see reconcileLibraryLike). */
async function onLikesListWritten(uid, change) {
  const idsOf = (snap) => {
    const ids = snap?.exists ? snap.get("gameIds") : null;
    return new Set(Array.isArray(ids) ? ids.filter(isPlainId) : []);
  };
  const before = idsOf(change?.before);
  const after = idsOf(change?.after);
  const changed = [...[...after].filter((id) => !before.has(id)), ...[...before].filter((id) => !after.has(id))];
  for (const libraryId of changed.slice(0, MAX_LIKES_PER_WRITE)) await reconcileLibraryLike(uid, libraryId);
}

module.exports = {
  likesListRef,
  onCatalogGameWritten,
  onCatalogMatchWritten,
  onLikesListWritten,
};
