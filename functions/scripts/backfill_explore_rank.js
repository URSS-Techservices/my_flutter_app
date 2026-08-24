/**
 * One-time backfill of exploreRankScore + trendingVelocity on posts.
 *
 * Prerequisites:
 *   npx firebase-tools login
 *
 * Usage:
 *   cd functions
 *   node scripts/backfill_explore_rank.js
 *
 * Env:
 *   MAX_DOCS=500        — posts per page (default 400, max 500)
 *   START_AFTER_ID=...  — resume after this post document id
 *   DRY_RUN=1           — log only, no writes
 */
const admin = require('firebase-admin');
const { computeGlobalExploreScores } = require('../explore_ranking');

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

async function fetchPage(fs, cursorId) {
  let q = fs.collection('posts').orderBy('timestamp', 'desc').limit(maxDocs);
  if (cursorId) {
    const cursorSnap = await fs.collection('posts').doc(cursorId).get();
    if (cursorSnap.exists) {
      q = q.startAfter(cursorSnap);
    } else {
      console.warn(`[backfill_explore_rank] START_AFTER_ID not found: ${cursorId}`);
    }
  }
  return q.get();
}

async function backfillPage(snap) {
  const fs = admin.firestore();
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
    const scores = computeGlobalExploreScores(data);
    const prevRank = Number(data.exploreRankScore || 0);
    const prevVel = Number(data.trendingVelocity || 0);
    const same =
      Math.abs(prevRank - scores.exploreRankScore) < 1e-6 &&
      Math.abs(prevVel - scores.trendingVelocity) < 1e-6;
    if (same && data.exploreRankUpdatedAt) {
      skipped++;
      continue;
    }

    if (dryRun) {
      console.log(
        `[dry-run] ${doc.id} rank ${prevRank.toFixed(4)} -> ${scores.exploreRankScore.toFixed(4)}`,
      );
      updated++;
      continue;
    }

    batch.set(
      doc.ref,
      {
        exploreRankScore: scores.exploreRankScore,
        trendingVelocity: scores.trendingVelocity,
        exploreRankUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
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
  console.log(
    `[backfill_explore_rank] project=${projectId} maxDocs=${maxDocs} ` +
      `dryRun=${dryRun} startAfter=${startAfterId || '(none)'}`,
  );

  let cursor = startAfterId;
  let totalScanned = 0;
  let totalUpdated = 0;
  let totalSkipped = 0;
  let pages = 0;

  while (true) {
    const snap = await fetchPage(fs, cursor);
    if (snap.empty) break;

    const result = await backfillPage(snap);
    totalScanned += result.scanned;
    totalUpdated += result.updated;
    totalSkipped += result.skipped;
    pages++;
    console.log(
      `[backfill_explore_rank] page ${pages}: scanned=${result.scanned} ` +
        `updated=${result.updated} skipped=${result.skipped} lastId=${result.lastId}`,
    );

    if (snap.size < maxDocs) break;
    cursor = result.lastId;
    if (!cursor) break;
  }

  console.log(
    `[backfill_explore_rank] done pages=${pages} scanned=${totalScanned} ` +
      `updated=${totalUpdated} skipped=${totalSkipped}`,
  );
  if (cursor && totalScanned >= maxDocs) {
    console.log(
      `[backfill_explore_rank] resume with: START_AFTER_ID=${cursor} node scripts/backfill_explore_rank.js`,
    );
  }
}

main().catch((e) => {
  console.error('[backfill_explore_rank] failed', e);
  process.exit(1);
});
