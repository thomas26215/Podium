// Fills in the member rosters (`groups/{id}/members`, `servers/{id}/members`
// — see UsersRepository.watchRoster) of every group and server that existed
// before them. The syncGroupRoster/syncServerRoster Cloud Functions rebuild a
// roster whenever its group or server is written while its `rosterVersion`
// is behind, so this only sets that field back to 0 and lets them do the
// rest — run it once the functions are deployed. Until a roster is filled,
// the app fetches its members one by one, as before.
//
// Safe to re-run: a rebuild just rewrites the same entries.
//
// Usage (from the repo root, reusing functions/node_modules):
//   GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json \
//     node tool/backfill_rosters.js [--dry-run]
//
// The service account key comes from Firebase console → Project settings →
// Service accounts → Generate new private key. Never commit it.

const path = require('path');
const admin = require(path.join(__dirname, '..', 'functions', 'node_modules', 'firebase-admin'));

const dryRun = process.argv.includes('--dry-run');

async function main() {
  admin.initializeApp({ projectId: 'podium-9b4bf' });
  const db = admin.firestore();

  const roots = [];
  for (const name of ['groups', 'servers']) {
    const snap = await db.collection(name).get();
    roots.push(...snap.docs.filter((d) => !d.get('personal')));
  }
  console.log(`${roots.length} groupes et serveurs`);
  if (dryRun) {
    for (const d of roots) console.log(`  ${d.ref.path} — ${d.get('name') || '?'} (${(d.get('memberIds') || []).length} membres)`);
    return;
  }

  for (let i = 0; i < roots.length; i += 400) {
    const batch = db.batch();
    for (const d of roots.slice(i, i + 400)) batch.update(d.ref, { rosterVersion: 0 });
    await batch.commit();
  }
  console.log('Terminé — les Cloud Functions remplissent les annuaires.');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
