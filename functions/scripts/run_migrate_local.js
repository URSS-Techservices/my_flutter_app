/**
 * Run legacy video migration locally (uses Firebase Application Default Credentials).
 *
 * Prerequisites:
 *   npx firebase-tools login
 *
 * Usage:
 *   cd functions
 *   node scripts/run_migrate_local.js
 */
const admin = require('firebase-admin');

const projectId = process.env.GCLOUD_PROJECT || 'halo-fb212';
const maxDocs = Math.min(
  Math.max(parseInt(process.env.MAX_DOCS || '200', 10), 1),
  500,
);

if (!admin.apps.length) {
  admin.initializeApp({ projectId });
}

const STUCK_PROCESSING_MS = 2 * 60 * 60 * 1000;

function collectRawCandidates(collection, data) {
  const out = [];
  const push = (v) => {
    const s = (v || '').toString().trim();
    if (s) out.push(s);
  };
  push(data.rawVideoUrl);
  push(data.videoUrl);
  if (Array.isArray(data.media)) {
    for (const m of data.media) {
      if (!m || typeof m !== 'object') continue;
      push(m.rawVideoUrl);
      push(m.videoUrl);
      push(m.url);
    }
  }
  return out;
}

function extractStoragePathFromUrl(url) {
  if (!url || typeof url !== 'string') return null;
  try {
    const u = new URL(url);
    const m = u.pathname.match(/\/o\/(.+)$/);
    if (!m) return null;
    return decodeURIComponent(m[1]);
  } catch (_) {
    return null;
  }
}

async function migrateOneCollection(collection) {
  const fs = admin.firestore();
  const snap = await fs
    .collection(collection)
    .where('processed', '==', false)
    .limit(maxDocs)
    .get();

  let queued = 0;
  let skipped = 0;
  const batch = fs.batch();
  let pending = 0;

  for (const doc of snap.docs) {
    const data = doc.data() || {};
    if (data.processing === true) {
      skipped++;
      continue;
    }
    const candidates = collectRawCandidates(collection, data);
    if (!candidates.some((u) => extractStoragePathFromUrl(u))) {
      skipped++;
      continue;
    }
    batch.set(
      doc.ref,
      {
        legacyRawFallback: true,
        requestedTranscodeAt: admin.firestore.FieldValue.serverTimestamp(),
        requeuedAt: admin.firestore.FieldValue.delete(),
      },
      { merge: true },
    );
    queued++;
    pending++;
    if (pending >= 400) {
      await batch.commit();
      pending = 0;
    }
  }
  if (pending > 0) await batch.commit();
  return { scanned: snap.size, queued, skipped };
}

async function migrateStuckProcessing(collection) {
  const fsDb = admin.firestore();
  const snap = await fsDb
    .collection(collection)
    .where('processing', '==', true)
    .limit(maxDocs)
    .get();

  const cutoffMs = Date.now() - STUCK_PROCESSING_MS;
  let queued = 0;
  let skipped = 0;
  const batch = fsDb.batch();
  let pending = 0;

  for (const doc of snap.docs) {
    const data = doc.data() || {};
    if (data.processed === true) {
      skipped++;
      continue;
    }
    const started = data.transcodeStartedAt;
    const startedMs =
      started && typeof started.toMillis === 'function'
        ? started.toMillis()
        : null;
    if (startedMs != null && startedMs > cutoffMs) {
      skipped++;
      continue;
    }
    const candidates = collectRawCandidates(collection, data);
    if (!candidates.some((u) => extractStoragePathFromUrl(u))) {
      skipped++;
      continue;
    }
    batch.set(
      doc.ref,
      {
        legacyRawFallback: true,
        requestedTranscodeAt: admin.firestore.FieldValue.serverTimestamp(),
        requeuedAt: admin.firestore.FieldValue.delete(),
        transcodeError: admin.firestore.FieldValue.delete(),
      },
      { merge: true },
    );
    queued++;
    pending++;
    if (pending >= 400) {
      await batch.commit();
      pending = 0;
    }
  }
  if (pending > 0) await batch.commit();
  return { scanned: snap.size, queued, skipped };
}

async function main() {
  console.log(`[run_migrate_local] project=${projectId} maxDocs=${maxDocs}`);
  const result = {
    posts: await migrateOneCollection('posts'),
    reels: await migrateOneCollection('reels'),
    stuck: {
      posts: await migrateStuckProcessing('posts'),
      reels: await migrateStuckProcessing('reels'),
    },
  };
  console.log('[run_migrate_local] done', JSON.stringify(result, null, 2));
}

main().catch((e) => {
  console.error('[run_migrate_local] failed', e);
  process.exit(1);
});
