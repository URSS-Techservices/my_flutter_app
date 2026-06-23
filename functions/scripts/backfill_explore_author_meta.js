/**
 * Backfill denormalized author fields on posts for Explore ranking.
 *
 * Usage:
 *   cd functions
 *   npm run backfill:explore-author-meta
 *
 * Env:
 *   MAX_DOCS=400
 *   START_AFTER_ID=...
 *   DRY_RUN=1
 */
const admin = require('firebase-admin');

const projectId = process.env.GCLOUD_PROJECT || 'halo-fb212';
const maxDocs = Math.min(
  Math.max(parseInt(process.env.MAX_DOCS || '400', 10), 1),
  500,
);
const startAfterId = (process.env.START_AFTER_ID || '').trim();
const dryRun = process.env.DRY_RUN === '1';

if (!admin.apps.length) {
  admin.initializeApp({ projectId });
}

function stringList(raw) {
  if (!Array.isArray(raw)) return [];
  return raw.map((v) => String(v).trim()).filter(Boolean);
}

function authorSpecsFromUser(data) {
  const out = [];
  out.push(...stringList(data.areas_of_specialization));
  out.push(...stringList(data.specialties));
  const profession = (data.profession || '').toString().trim();
  if (profession) out.push(profession);
  return [...new Set(out)];
}

function accountTypeFromUser(data) {
  return (
    data.accountType ||
    data.category ||
    data.profileType ||
    ''
  )
    .toString()
    .toLowerCase();
}

async function fetchPage(fs, cursorId) {
  let q = fs.collection('posts').orderBy('timestamp', 'desc').limit(maxDocs);
  if (cursorId) {
    const cursorSnap = await fs.collection('posts').doc(cursorId).get();
    if (cursorSnap.exists) q = q.startAfter(cursorSnap);
  }
  return q.get();
}

async function backfillPage(fs, snap, userCache) {
  let batch = fs.batch();
  let pending = 0;
  let updated = 0;
  let skipped = 0;

  const commit = async () => {
    if (pending === 0) return;
    if (!dryRun) await batch.commit();
    batch = fs.batch();
    pending = 0;
  };

  for (const doc of snap.docs) {
    const data = doc.data() || {};
    const userId = (data.userId || '').toString().trim();
    if (!userId) {
      skipped++;
      continue;
    }

    let userData = userCache.get(userId);
    if (!userData) {
      const userSnap = await fs.collection('users').doc(userId).get();
      userData = userSnap.exists ? userSnap.data() || {} : {};
      userCache.set(userId, userData);
    }

    const specs = authorSpecsFromUser(userData);
    const accountType = accountTypeFromUser(userData);
    const lat = userData.lastKnownLatitude;
    const lng = userData.lastKnownLongitude;

    const patch = {};
    if (specs.length > 0) patch.authorSpecializations = specs;
    if (accountType) patch.authorAccountType = accountType;
    if (typeof lat === 'number') patch.authorLatitude = lat;
    if (typeof lng === 'number') patch.authorLongitude = lng;

    if (Object.keys(patch).length === 0) {
      skipped++;
      continue;
    }

    const needsWrite =
      JSON.stringify(data.authorSpecializations || []) !==
        JSON.stringify(patch.authorSpecializations || data.authorSpecializations || []) ||
      (patch.authorAccountType &&
        (data.authorAccountType || '').toString().toLowerCase() !==
          patch.authorAccountType) ||
      (patch.authorLatitude != null &&
        Number(data.authorLatitude) !== Number(patch.authorLatitude)) ||
      (patch.authorLongitude != null &&
        Number(data.authorLongitude) !== Number(patch.authorLongitude));

    if (!needsWrite) {
      skipped++;
      continue;
    }

    if (dryRun) {
      console.log(`[dry-run] ${doc.id}`, patch);
      updated++;
      continue;
    }

    batch.set(doc.ref, patch, { merge: true });
    updated++;
    pending++;
    if (pending >= 400) await commit();
  }

  await commit();
  const lastId = snap.docs.length > 0 ? snap.docs[snap.docs.length - 1].id : null;
  return { scanned: snap.size, updated, skipped, lastId };
}

async function main() {
  const fs = admin.firestore();
  const userCache = new Map();
  console.log(
    `[backfill_explore_author_meta] project=${projectId} maxDocs=${maxDocs} dryRun=${dryRun}`,
  );

  let cursor = startAfterId;
  let totalUpdated = 0;
  let totalSkipped = 0;
  let totalScanned = 0;
  let pages = 0;

  while (true) {
    const snap = await fetchPage(fs, cursor);
    if (snap.empty) break;

    const result = await backfillPage(fs, snap, userCache);
    totalScanned += result.scanned;
    totalUpdated += result.updated;
    totalSkipped += result.skipped;
    pages++;
    console.log(
      `[backfill_explore_author_meta] page ${pages}: scanned=${result.scanned} ` +
        `updated=${result.updated} skipped=${result.skipped}`,
    );

    if (snap.size < maxDocs) break;
    cursor = result.lastId;
    if (!cursor) break;
  }

  console.log(
    `[backfill_explore_author_meta] done pages=${pages} scanned=${totalScanned} ` +
      `updated=${totalUpdated} skipped=${totalSkipped}`,
  );
}

main().catch((e) => {
  console.error('[backfill_explore_author_meta] failed', e);
  process.exit(1);
});
