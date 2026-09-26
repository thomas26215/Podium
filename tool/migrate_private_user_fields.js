// Moves `email`, `friendIds` and `fcmTokens` off every public `users/{uid}`
// doc (readable by any signed-in account) into its owner-only
// `users/{uid}/private/account` doc. The app does the same for an account
// the first time it signs in (see UsersRepository._migrateLegacyPrivateFields)
// — this script covers the accounts that never open the app again.
//
// Safe to re-run: accounts already migrated are skipped.
//
// Usage (from the repo root, reusing functions/node_modules):
//   GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json \
//     node tool/migrate_private_user_fields.js [--dry-run]
//
// The service account key comes from Firebase console → Project settings →
// Service accounts → Generate new private key. Never commit it.

const path = require('path');
const admin = require(path.join(__dirname, '..', 'functions', 'node_modules', 'firebase-admin'));

const dryRun = process.argv.includes('--dry-run');
const PRIVATE_KEYS = ['email', 'friendIds', 'fcmTokens'];

async function main() {
  admin.initializeApp({ projectId: 'podium-9b4bf' });
  const db = admin.firestore();
  const { FieldValue } = admin.firestore;

  const users = await db.collection('users').get();
  const legacy = users.docs.filter((d) => PRIVATE_KEYS.some((k) => k in d.data()));
  console.log(`${users.size} comptes, ${legacy.length} à migrer`);
  if (dryRun) {
    for (const d of legacy) console.log(`  ${d.id} — ${d.data().displayName || '?'}`);
    return;
  }

  // Two writes per account; a Firestore batch holds at most 500.
  for (let i = 0; i < legacy.length; i += 200) {
    const batch = db.batch();
    for (const d of legacy.slice(i, i + 200)) {
      const data = d.data();
      const priv = {};
      if (typeof data.email === 'string') priv.email = data.email;
      if (Array.isArray(data.friendIds) && data.friendIds.length) priv.friendIds = FieldValue.arrayUnion(...data.friendIds);
      if (Array.isArray(data.fcmTokens) && data.fcmTokens.length) priv.fcmTokens = FieldValue.arrayUnion(...data.fcmTokens);
      batch.set(d.ref.collection('private').doc('account'), priv, { merge: true });
      batch.update(d.ref, Object.fromEntries(PRIVATE_KEYS.map((k) => [k, FieldValue.delete()])));
    }
    await batch.commit();
    console.log(`  ${Math.min(i + 200, legacy.length)}/${legacy.length}`);
  }
  console.log('Terminé.');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
