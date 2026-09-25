// Pushes tool/game_library.json into the shared `gameLibrary` Firestore
// collection (see lib/repositories/game_library_repository.dart). The app
// can only read that collection, so this is how the library is managed.
//
// Each JSON key is the document id: re-running the script updates existing
// games in place and never duplicates them. Games removed from the JSON are
// left in Firestore unless --prune is passed.
//
// Usage (from the repo root, reusing functions/node_modules):
//   GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json \
//     node tool/seed_game_library.js [--dry-run] [--prune]
//
// The service account key comes from Firebase console → Project settings →
// Service accounts → Generate new private key. Never commit it.

const path = require('path');
const admin = require(path.join(__dirname, '..', 'functions', 'node_modules', 'firebase-admin'));
const games = require('./game_library.json');

const dryRun = process.argv.includes('--dry-run');
const prune = process.argv.includes('--prune');

async function main() {
  const ids = Object.keys(games);
  console.log(`${ids.length} jeux dans game_library.json`);
  if (dryRun) {
    for (const id of ids) console.log(`  ${id} — ${games[id].name}`);
    return;
  }

  admin.initializeApp({ projectId: 'podium-9b4bf' });
  const db = admin.firestore();
  const col = db.collection('gameLibrary');

  // A Firestore batch holds at most 500 writes.
  const ops = ids.map((id) => (b) => b.set(col.doc(id), games[id]));
  if (prune) {
    const existing = await col.get();
    for (const doc of existing.docs) {
      if (!(doc.id in games)) {
        console.log(`  suppression de ${doc.id}`);
        ops.push((b) => b.delete(doc.ref));
      }
    }
  }
  for (let i = 0; i < ops.length; i += 400) {
    const batch = db.batch();
    for (const op of ops.slice(i, i + 400)) op(batch);
    await batch.commit();
  }
  console.log(`gameLibrary à jour (${ids.length} jeux écrits).`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
