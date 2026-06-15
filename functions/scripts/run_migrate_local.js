/**
 * Run legacy video migration locally (uses Firebase Application Default Credentials).
 *
 * Prerequisites:
 *   npx firebase-tools login
 *
 * Usage:
 *   cd functions
 *   node scripts/run_migrate_local.js
 *
 * Env:
 *   MAX_DOCS=200
 *   RETRY_PERMANENT=1   — reset and re-queue permanent failures
 */
const admin = require('firebase-admin');

const projectId = process.env.GCLOUD_PROJECT || 'halo-fb212';
const maxDocs = Math.min(
  Math.max(parseInt(process.env.MAX_DOCS || '200', 10), 1),
  500,
);
const retryPermanentFailures = process.env.RETRY_PERMANENT === '1';

const MAX_REQUEUE_ATTEMPTS = 12;
const STUCK_PROCESSING_MS = 2 * 60 * 60 * 1000;

if (!admin.apps.length) {
  admin.initializeApp({ projectId });
}

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

function parseUploadContext(rawPath) {
  const filePath = (rawPath || '').replace(/^\/+/, '');
  if (!filePath) return null;
  const postMatch = filePath.match(
    /^users\/([^/]+)\/posts\/([^/]+)\/(video(?:_(\d+))?)\.(mp4|mov|m4v|webm)$/i,
  );
  if (postMatch) {
    return { kind: 'post', storagePath: filePath };
  }
  const legacyFlat = filePath.match(
    /^users\/([^/]+)\/posts\/(.+)-(\d+)\.(mp4|mov|m4v|webm)$/i,
  );
  if (legacyFlat) {
    return { kind: 'post', storagePath: filePath };
  }
  const legacyRoot = filePath.match(/^posts\/(.+)-(\d+)\.(mp4|mov|m4v|webm)$/i);
  if (legacyRoot) {
    return { kind: 'post', storagePath: filePath };
  }
  const reelMatch = filePath.match(/^videos\/raw\/(.+\.(mp4|mov|m4v|webm))$/i);
  if (reelMatch) {
    return { kind: 'reel', storagePath: filePath };
  }
  return null;
}

function hasAdaptiveProcessedHls(doc) {
  const isMaster = (u) =>
    typeof u === 'string' &&
    u.length > 0 &&
    u.toLowerCase().includes('master.m3u8');
  if (isMaster(doc.hlsUrl)) return true;
  if (Array.isArray(doc.media)) {
    for (const m of doc.media) {
      if (m && isMaster(m.hlsUrl)) return true;
    }
  }
  return false;
}

function hasTranscodableRawSource(doc, collection) {
  return collectRawCandidates(collection, doc).some((u) => {
    const p = extractStoragePathFromUrl(u);
    return p && parseUploadContext(p);
  });
}

async function migrateOneCollection(collection) {
  const fs = admin.firestore();
  const seen = new Set();
  let scanned = 0;
  let queued = 0;
  let skipped = 0;
  let batch = fs.batch();
  let pending = 0;

  const tryQueueDoc = (docRef, data) => {
    if (seen.has(docRef.id)) return;
    seen.add(docRef.id);
    scanned++;

    if (data.processing === true) {
      skipped++;
      return;
    }
    const isPermanentFailure =
      data.transcodeError && data.transcodeErrorCategory === 'permanent';
    if (isPermanentFailure && !retryPermanentFailures) {
      skipped++;
      return;
    }
    if (Number(data.transcodeAttemptCount || 0) >= MAX_REQUEUE_ATTEMPTS) {
      skipped++;
      return;
    }
    if (data.transcodeRequeueExhausted === true) {
      skipped++;
      return;
    }
    if (data.processed === true || hasAdaptiveProcessedHls(data)) {
      skipped++;
      return;
    }
    if (!hasTranscodableRawSource(data, collection)) {
      skipped++;
      return;
    }

    const patch = {
      legacyRawFallback: true,
      requestedTranscodeAt: admin.firestore.FieldValue.serverTimestamp(),
      requeuedAt: admin.firestore.FieldValue.delete(),
      processed: false,
    };
    if (isPermanentFailure && retryPermanentFailures) {
      patch.transcodeError = admin.firestore.FieldValue.delete();
      patch.transcodeErrorCategory = admin.firestore.FieldValue.delete();
      patch.transcodeErrorAt = admin.firestore.FieldValue.delete();
      patch.transcodeRequeueExhausted = admin.firestore.FieldValue.delete();
      patch.transcodeAttemptCount = 0;
    }
    batch.set(docRef, patch, { merge: true });
    queued++;
    pending++;
  };

  const commitIfNeeded = async (force = false) => {
    if (pending >= 400 || (force && pending > 0)) {
      await batch.commit();
      batch = fs.batch();
      pending = 0;
    }
  };

  const snapProcessedFalse = await fs
    .collection(collection)
    .where('processed', '==', false)
    .limit(maxDocs)
    .get();
  for (const doc of snapProcessedFalse.docs) {
    tryQueueDoc(doc.ref, doc.data() || {});
    if (pending >= 400) await commitIfNeeded(true);
  }

  if (seen.size < maxDocs) {
    const snapIsVideo = await fs
      .collection(collection)
      .where('isVideo', '==', true)
      .limit(maxDocs)
      .get();
    for (const doc of snapIsVideo.docs) {
      if (seen.size >= maxDocs) break;
      tryQueueDoc(doc.ref, doc.data() || {});
      if (pending >= 400) await commitIfNeeded(true);
    }
  }

  if (seen.size < maxDocs) {
    for (const orderField of ['timestamp', 'createdAt']) {
      try {
        const snapRecent = await fs
          .collection(collection)
          .orderBy(orderField, 'desc')
          .limit(maxDocs)
          .get();
        for (const doc of snapRecent.docs) {
          if (seen.size >= maxDocs) break;
          tryQueueDoc(doc.ref, doc.data() || {});
          if (pending >= 400) await commitIfNeeded(true);
        }
        break;
      } catch (_) {
        /* try next order field */
      }
    }
  }

  await commitIfNeeded(true);
  return { scanned, queued, skipped };
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
  let batch = fsDb.batch();
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
    if (!hasTranscodableRawSource(data, collection)) {
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
        processed: false,
      },
      { merge: true },
    );
    queued++;
    pending++;
    if (pending >= 400) {
      await batch.commit();
      batch = fsDb.batch();
      pending = 0;
    }
  }
  if (pending > 0) await batch.commit();
  return { scanned: snap.size, queued, skipped };
}

async function main() {
  console.log(
    `[run_migrate_local] project=${projectId} maxDocs=${maxDocs} ` +
      `retryPermanent=${retryPermanentFailures}`,
  );
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
