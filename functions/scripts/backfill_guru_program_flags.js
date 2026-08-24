/**
 * Sync hasActivePrograms / activeProgramCount on guru user docs.
 *
 * Usage:
 *   cd functions
 *   npm run backfill:guru-program-flags
 *
 * Env:
 *   MAX_USERS=200
 *   DRY_RUN=1
 */
const admin = require('firebase-admin');

const projectId = process.env.GCLOUD_PROJECT || 'halo-fb212';
const maxUsers = Math.min(
  Math.max(parseInt(process.env.MAX_USERS || '200', 10), 1),
  500,
);
const dryRun = process.env.DRY_RUN === '1';

if (!admin.apps.length) {
  admin.initializeApp({ projectId });
}

function isGuru(data) {
  const t = (
    data.accountType ||
    data.category ||
    data.profileType ||
    ''
  )
    .toString()
    .toLowerCase();
  return t.includes('guru') || t.includes('coach');
}

async function main() {
  const fs = admin.firestore();
  console.log(
    `[backfill_guru_program_flags] project=${projectId} maxUsers=${maxUsers} dryRun=${dryRun}`,
  );

  const snap = await fs
    .collection('users')
    .where('category', '==', 'Guru')
    .limit(maxUsers)
    .get();

  let updated = 0;
  let skipped = 0;

  for (const userDoc of snap.docs) {
    const data = userDoc.data() || {};
    if (!isGuru(data)) {
      skipped++;
      continue;
    }

    const programsSnap = await fs
      .collection('users')
      .doc(userDoc.id)
      .collection('programs')
      .get();
    const activeCount = programsSnap.docs.filter(
      (d) => d.data().isActive !== false,
    ).length;

    const patch = {
      hasActivePrograms: activeCount > 0,
      activeProgramCount: activeCount,
      programsSyncedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (dryRun) {
      console.log(`[dry-run] ${userDoc.id}`, patch);
      updated++;
      continue;
    }

    await userDoc.ref.set(patch, { merge: true });
    updated++;
  }

  console.log(
    `[backfill_guru_program_flags] scanned=${snap.size} updated=${updated} skipped=${skipped}`,
  );
}

main().catch((e) => {
  console.error('[backfill_guru_program_flags] failed', e);
  process.exit(1);
});
